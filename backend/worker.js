/**
 * GombeStore free-tier backend — Cloudflare Worker (no card, no Blaze).
 *
 * Replaces the Firebase Cloud Functions on the Spark plan:
 *   POST /pay/initialize      -> creates a Paystack checkout for an order
 *   POST /pay/verify          -> verifies with Paystack, flips order to Paid
 *   POST /paystack/webhook    -> Paystack pushes payment confirmations here
 *   cron (every minute)       -> sends FCM pushes for new orders / status
 *                                changes / payments (Firestore -> FCM)
 *
 * One-time dashboard setup (see backend/README.md):
 *   Secrets: PAYSTACK_SECRET_KEY, SERVICE_ACCOUNT_JSON, APP_API_KEY
 *   KV binding: KV          Cron trigger: * * * * *
 */

const FIREBASE_PROJECT_ID = 'gombestore-project';
const ORDERS_URL = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents`;
const FCM_URL = `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`;
const STATUS_MESSAGES = {
  Confirmed: 'Your order was confirmed and is being prepared.',
  Processing: 'Your order is being processed.',
  'Ready for Pickup': 'Your order is ready for pickup.',
  'Out for Delivery': 'Your order is on the way!',
  Delivered: 'Your order was delivered. Enjoy!',
  Cancelled: 'Your order was cancelled.',
};

/* ------------------------------ helpers ------------------------------ */

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: { 'content-type': 'application/json' },
  });

function guard(request, env) {
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });
  const key = request.headers.get('x-app-key') || '';
  if (!env.APP_API_KEY || key !== env.APP_API_KEY) {
    return json({ error: 'Unauthorized app key' }, 401);
  }
  return null;
}

/** Parse the service account JSON (accepts raw JSON or base64 of it). */
function serviceAccount(env) {
  let raw = env.SERVICE_ACCOUNT_JSON || '';
  let sa = null;
  try {
    sa = JSON.parse(raw);
  } catch (_) {
    try {
      sa = JSON.parse(atob(raw.trim().replace(/\n/g, '')));
    } catch (e2) {
      return null;
    }
  }
  return sa && sa.private_key && sa.client_email ? sa : null;
}

function b64ToBytes(b64) {
  const bin = atob(b64.replace(/-/g, '+').replace(/_/g, '/').replace(/\s+/g, ''));
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

/** Mints an OAuth 2.0 access token from the service account (cached in KV). */
async function googleAccessToken(env) {
  const cached = await env.KV.get('oauth:token');
  if (cached) return cached;

  const sa = serviceAccount(env);
  if (!sa) throw new Error('SERVICE_ACCOUNT_JSON is missing or invalid');

  const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  const now = Math.floor(Date.now() / 1000);
  const claims = btoa(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3300,
    iat: now,
  })).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

  const key = await crypto.subtle.importKey(
    'pkcs8',
    b64ToBytes(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${header}.${claims}.${sigB64}`,
    }),
  });
  const data = await res.json();
  if (!data.access_token) throw new Error('Google OAuth failed: ' + JSON.stringify(data));
  // 1 hour token; store with a safety margin.
  await env.KV.put('oauth:token', data.access_token, { expirationTtl: 3000 });
  return data.access_token;
}

/** Firestore REST helpers */
async function fstore(env, path, method = 'GET', body = null) {
  const token = await googleAccessToken(env);
  const res = await fetch(`${ORDERS_URL}/${path}`, {
    method,
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`Firestore ${method} ${path}: ${JSON.stringify(data).slice(0, 300)}`);
  return data;
}

const fv = (fields, name) => {
  const v = fields?.[name];
  if (!v) return undefined;
  for (const k of ['stringValue', 'doubleValue', 'integerValue', 'booleanValue', 'timestampValue']) {
    if (k in v) return v[k];
  }
  if ('arrayValue' in v) {
    return (v.arrayValue.values || []).map((x) => x.stringValue).filter(Boolean);
  }
  if ('mapValue' in v) return v.mapValue.fields || {};
  return undefined;
};

async function updateOrder(env, orderId, patch) {
  const updateMask = Object.keys(patch).map((k) => `updateMask.fieldPaths=${encodeURIComponent(k)}`).join('&');
  const fields = {};
  for (const [k, v] of Object.entries(patch)) {
    if (k === 'paidAt') fields[k] = v ? { timestampValue: v } : { nullValue: null };
    else if (typeof v === 'number') { fields[k] = Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v }; }
    else fields[k] = { stringValue: String(v) };
  }
  await fstore(env, `orders/${orderId}?${updateMask}`, 'PATCH', { fields });
}

/** Sends an FCM push to all devices registered for a user. */
async function pushToUser(env, userId, title, body) {
  try {
    if (!userId) return;
    const user = await fstore(env, `users/${userId}`);
    const tokens = fv(user.fields, 'fcmTokens') || [];
    const token = await googleAccessToken(env);
    for (const t of tokens) {
      await fetch(FCM_URL, {
        method: 'POST',
        headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
        body: JSON.stringify({
          message: {
            token: t,
            notification: { title, body },
            android: { priority: 'high', notification: { channelId: 'orders' } },
          },
        }),
      });
    }
  } catch (e) {
    console.log('pushToUser failed (ignored):', e.message);
  }
}

/* ------------------------------ Paystack ------------------------------ */

const PAYSTACK_API = 'https://api.paystack.co';

function paystackHeaders(env) {
  if (!env.PAYSTACK_SECRET_KEY) return null;
  return { authorization: `Bearer ${env.PAYSTACK_SECRET_KEY}`, 'content-type': 'application/json' };
}

async function getOrder(env, orderId) {
  const snap = await fstore(env, `orders/${orderId}`);
  return snap.fields || {};
}

/* ------------------------------ routes ------------------------------- */

async function payInitialize(request, env) {
  const { orderId } = await request.json();
  if (!orderId) return json({ error: 'Missing orderId' }, 400);

  const headers = paystackHeaders(env);
  if (!headers) return json({ error: 'Payments are not configured yet. Please pay cash on delivery.' }, 501);

  const order = await getOrder(env, orderId);
  if (fv(order, 'paymentStatus') === 'Paid') return json({ error: 'This order is already paid.' }, 400);

  const grand = Number(fv(order, 'grandTotal') || 0);
  const email = fv(order, 'customerEmail') || `orders+${fv(order, 'customerId') || 'anon'}@gombestore.app`;
  const reference = `order_${orderId}_${Date.now()}`;

  const res = await fetch(`${PAYSTACK_API}/transaction/initialize`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      email,
      amount: Math.round(grand * 100),
      reference,
      currency: 'NGN',
      metadata: { orderId, customerId: fv(order, 'customerId'), storeName: fv(order, 'storeName') },
    }),
  });
  const data = await res.json();
  if (!data.status || !data.data?.authorization_url) {
    return json({ error: (data && data.message) || 'Could not start payment.' }, 502);
  }

  await updateOrder(env, orderId, {
    paymentReference: reference,
    paymentMethod: 'Paystack (Cash on Delivery available)',
    updatedAt: new Date().toISOString(),
  });
  return json({ authorization_url: data.data.authorization_url });
}

async function payVerify(request, env) {
  const { orderId } = await request.json();
  if (!orderId) return json({ error: 'Missing orderId' }, 400);

  const headers = paystackHeaders(env);
  if (!headers) return json({ error: 'Payments are not configured yet.' }, 501);

  const order = await getOrder(env, orderId);
  if (fv(order, 'paymentStatus') === 'Paid') return json({ paid: true });
  const reference = fv(order, 'paymentReference');
  if (!reference) return json({ error: 'This order has no pending payment.' }, 400);

  const res = await fetch(`${PAYSTACK_API}/transaction/verify/${encodeURIComponent(reference)}`, { headers });
  const data = await res.json();
  const paid = !!(data.status && data.data && data.data.status === 'success');

  if (paid) {
    await markPaid(env, orderId, order, data.data && data.data.channel);
    const customerId = fv(order, 'customerId');
    const grand = Number(fv(order, 'grandTotal') || 0);
    const store = fv(order, 'storeName') || 'the store';
    await pushToUser(env, customerId, 'Payment received ✅', `Your ₦${Math.round(grand)} payment to ${store} was confirmed.`);
  }
  return json({ paid });
}

async function markPaid(env, orderId, order, channel) {
  await updateOrder(env, orderId, {
    paymentStatus: 'Paid',
    paidAt: new Date().toISOString(),
    paymentChannel: channel || 'unknown',
    updatedAt: new Date().toISOString(),
  });
  try {
    await env.KV.delete(`order:${orderId}`); // cron re-notifies fresh
  } catch (_) {}
}

async function paystackWebhook(request, env) {
  const raw = await request.text();
  const headers = paystackHeaders(env);
  if (!headers) return new Response('Payments not configured', { status: 501 });

  const signature = request.headers.get('x-paystack-signature') || '';
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(env.PAYSTACK_SECRET_KEY),
    { name: 'HMAC', hash: 'SHA-512' },
    false,
    ['sign'],
  );
  const mac = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(raw));
  const expected = [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, '0')).join('');
  if (signature !== expected) return new Response('bad signature', { status: 401 });

  const event = JSON.parse(raw || '{}');
  if (event.event === 'charge.success' && event.data?.reference) {
    let docEntry = null;
    try {
      const token = await googleAccessToken(env);
      const runQ = await fetch(`${ORDERS_URL}:runQuery`, {
        method: 'POST',
        headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
        body: JSON.stringify({
          structuredQuery: {
            from: [{ collectionId: 'orders' }],
            where: { fieldFilter: { field: { fieldPath: 'paymentReference' }, op: 'EQUAL', value: { stringValue: event.data.reference } } },
            limit: 1,
          },
        }),
      });
      const rd = await runQ.json();
      docEntry = (rd || []).find((x) => x.document);
      if (docEntry) {
        const id = docEntry.document.name.split('/').pop();
        await markPaid(env, id, docEntry.document.fields, event.data.channel);
        const customerId = fv(docEntry.document.fields, 'customerId');
        const grand = Number(fv(docEntry.document.fields, 'grandTotal') || 0);
        const store = fv(docEntry.document.fields, 'storeName') || 'the store';
        await pushToUser(env, customerId, 'Payment received ✅', `Your ₦${Math.round(grand)} payment to ${store} was confirmed.`);
      }
    } catch (e) {
      console.log('webhook order lookup failed (ignored):', e.message);
    }
  }
  return new Response('ok');
}

/* --------------------- cron: Firestore -> FCM pushes --------------------- */

const POLL_LIMIT = 8; // keeps each run inside the 50-subrequest free limit

async function cronNotify(env) {
  const cursorMeta = await env.KV.get('cron:cursor');
  const cursor = cursorMeta ? new Date(cursorMeta) : new Date(Date.now() - 10 * 60 * 1000);

  const token = await googleAccessToken(env);
  const scan = await fetch(`${ORDERS_URL}:runQuery`, {
    method: 'POST',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'orders' }],
        where: { fieldFilter: { field: { fieldPath: 'updatedAt' }, op: 'GREATER_THAN', value: { timestampValue: cursor.toISOString() } } },
        orderBy: [{ field: { fieldPath: 'updatedAt' }, direction: 'ASCENDING' }],
        limit: POLL_LIMIT,
      },
    }),
  }).then((r) => r.json());

  const docs = (scan || []).filter((x) => x.document).map((x) => x.document);
  let newest = cursor;

  for (const doc of docs) {
    const id = doc.name.split('/').pop();
    const updated = doc.updateTime || fv(doc.fields, 'updatedAt');
    if (updated && new Date(updated) > newest) newest = new Date(updated);

    const current = {
      status: fv(doc.fields, 'status') || 'Pending',
      paymentStatus: fv(doc.fields, 'paymentStatus') || '',
      createdAt: fv(doc.fields, 'createdAt') || '',
    };
    const prevRaw = await env.KV.get(`order:${id}`);
    const prev = prevRaw ? JSON.parse(prevRaw) : null;

    if (!prev) {
      // First time we see this order (created since last scan) -> vendor push
      await pushToUser(
        env,
        fv(doc.fields, 'vendorId'),
        'New order! 🛒',
        `${fv(doc.fields, 'customerName') || 'A customer'} placed a ₦${Math.round(Number(fv(doc.fields, 'grandTotal') || 0))} order in ${fv(doc.fields, 'storeName') || 'your store'}.`,
      );
    } else {
      if (prev.status !== current.status) {
        const body = STATUS_MESSAGES[current.status] || `Your order status is now: ${current.status}`;
        await pushToUser(
          env,
          fv(doc.fields, 'customerId'),
          `Order ${current.status}`,
          `${fv(doc.fields, 'storeName') || 'The store'} updated your order. ${body}`,
        );
      }
      if (prev.paymentStatus !== current.paymentStatus && current.paymentStatus === 'Paid') {
        const grand = Number(fv(doc.fields, 'grandTotal') || 0);
        await pushToUser(
          env,
          fv(doc.fields, 'customerId'),
          'Payment received ✅',
          `Your ₦${Math.round(grand)} payment to ${fv(doc.fields, 'storeName') || 'the store'} was confirmed.`,
        );
      }
    }

    await env.KV.put(`order:${id}`, JSON.stringify(current));
  }

  if (docs.length > 0) {
    await env.KV.put('cron:cursor', newest.toISOString());
  }
}

/* --------------------------- worker entry --------------------------- */

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, '');

    if (path === '' || path === '/') return new Response('GombeStore API is running ✅');

    if (path === '/pay/initialize') {
      const guardResponse = guard(request, env);
      if (guardResponse) return guardResponse;
      try {
        return await payInitialize(request, env);
      } catch (e) {
        return json({ error: e.message || 'Server error' }, 500);
      }
    }

    if (path === '/pay/verify') {
      const guardResponse = guard(request, env);
      if (guardResponse) return guardResponse;
      try {
        return await payVerify(request, env);
      } catch (e) {
        return json({ error: e.message || 'Server error' }, 500);
      }
    }

    if (path === '/paystack/webhook') {
      // Paystack has no app key; authenticated by the HMAC signature instead.
      try {
        return await paystackWebhook(request, env);
      } catch (e) {
        return new Response('ok'); // never make Paystack retry forever
      }
    }

    return new Response('Not found', { status: 404 });
  },

  async scheduled(event, env, ctx) {
    ctx.waitUntil(cronNotify(env).catch((e) => console.log('cron failed (ignored):', e.message)));
  },
};
