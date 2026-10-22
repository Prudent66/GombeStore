/**
 * GombeStore push notifications (Firebase Cloud Functions, Node 20).
 *
 * Deploy:
 *   npm install -g firebase-tools
 *   cd functions && npm install
 *   firebase deploy --only functions
 *
 * Sends:
 *  - Vendor push when a customer places an order.
 *  - Customer push when the vendor updates the order status.
 */
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onRequest } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
const db = getFirestore();

const STATUS_MESSAGES = {
  Confirmed: 'Your order was confirmed and is being prepared.',
  Processing: 'Your order is being processed.',
  'Ready for Pickup': 'Your order is ready for pickup.',
  'Out for Delivery': 'Your order is on the way!',
  Delivered: 'Your order was delivered. Enjoy!',
  Cancelled: 'Your order was cancelled.',
};

/**
 * Sends a notification to every registered device of a user.
 * Ignores all errors (notifications must never fail the write).
 */
async function sendToUser(userId, title, body) {
  try {
    if (!userId) return;
    const userDoc = await db.collection('users').doc(userId).get();
    const tokens = (userDoc.data() && userDoc.data().fcmTokens) || [];
    if (tokens.length === 0) return;

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      android: { priority: 'high', notification: { channelId: 'orders' } },
    });

    // Drop expired tokens so the array stays clean.
    if (response.failureCount > 0) {
      const dead = tokens.filter((t) => response.responses.some((r, i) => !r.success && r.error.code === 'messaging/registration-token-not-registered'));
      if (dead.length > 0) {
        await db.collection('users').doc(userId).update({
          fcmTokens: FieldValue.arrayRemove(...dead),
        });
      }
    }
  } catch (error) {
    console.log('sendToUser failed (ignored):', error);
  }
}

// Vendor is notified when a customer places an order.
exports.notifyVendorOnNewOrder = onDocumentCreated('orders/{orderId}', async (event) => {
  const order = event.data && event.data.data();
  if (!order) return;
  await sendToUser(
    order.vendorId,
    'New order! 🛒',
    `${order.customerName || 'A customer'} placed a ₦${Math.round(order.grandTotal || 0)} order in ${order.storeName || 'your store'}.`
  );
});

// Customer is notified when the order status changes.
exports.notifyCustomerOnStatusChange = onDocumentUpdated('orders/{orderId}', async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after || before.status === after.status) return;

  const body = STATUS_MESSAGES[after.status] || `Your order status is now: ${after.status}`;
  await sendToUser(
    after.customerId,
    `Order ${after.status}`,
    `${after.storeName || 'The store'} updated your order. ${body}`
  );
});

// ------------------------------------------------------------------
// Paystack payments. PAYSTACK_SECRET_KEY is stored out of the repo:
//   firebase functions:secrets:set PAYSTACK_SECRET_KEY
// ------------------------------------------------------------------
const PAYSTACK_API = 'https://api.paystack.co';

function paystackHeaders() {
  const key = process.env.PAYSTACK_SECRET_KEY;
  if (!key) {
    throw new HttpsError('failed-precondition', 'Payments are not configured yet. Please pay cash on delivery.');
  }
  return { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' };
}

// App asks for a secure checkout link for one order.
exports.createPaystackPayment = onCall(async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const orderId = req.data && req.data.orderId;
  if (!orderId) throw new HttpsError('invalid-argument', 'Missing orderId.');

  const orderRef = db.collection('orders').doc(orderId);
  const orderSnap = await orderRef.get();
  if (!orderSnap.exists) throw new HttpsError('not-found', 'Order not found.');
  const order = orderSnap.data();
  if (order.customerId !== req.auth.uid) {
    throw new HttpsError('permission-denied', 'This is not your order.');
  }
  if (order.paymentStatus === 'Paid') {
    throw new HttpsError('failed-precondition', 'This order is already paid.');
  }

  // Paystack wants the amount in kobo (₦1 = 100 kobo).
  const amountKobo = Math.round((order.grandTotal || 0) * 100);
  const reference = `order_${orderId}_${Date.now()}`;

  const res = await fetch(`${PAYSTACK_API}/transaction/initialize`, {
    method: 'POST',
    headers: paystackHeaders(),
    body: JSON.stringify({
      email: order.customerEmail || `orders+${order.customerId}@gombestore.app`,
      amount: amountKobo,
      reference,
      currency: 'NGN',
      metadata: { orderId, customerId: order.customerId, storeName: order.storeName },
    }),
  });
  const data = await res.json();
  if (!data.status || !data.data || !data.data.authorization_url) {
    throw new HttpsError('internal', (data && data.message) || 'Could not start payment.');
  }

  await orderRef.update({
    paymentReference: reference,
    paymentMethod: 'Paystack (Cash on Delivery available)',
  });
  return { authorization_url: data.data.authorization_url };
});

// App asks whether Paystack has confirmed the payment yet.
exports.verifyPaystackPayment = onCall(async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const orderId = req.data && req.data.orderId;
  if (!orderId) throw new HttpsError('invalid-argument', 'Missing orderId.');

  const orderRef = db.collection('orders').doc(orderId);
  const orderSnap = await orderRef.get();
  if (!orderSnap.exists) throw new HttpsError('not-found', 'Order not found.');
  const order = orderSnap.data();
  if (order.customerId !== req.auth.uid) {
    throw new HttpsError('permission-denied', 'This is not your order.');
  }
  if (order.paymentStatus === 'Paid') return { paid: true };
  if (!order.paymentReference) throw new HttpsError('failed-precondition', 'This order has no pending payment.');

  const res = await fetch(
    `${PAYSTACK_API}/transaction/verify/${encodeURIComponent(order.paymentReference)}`,
    { headers: paystackHeaders() }
  );
  const data = await res.json();
  const paid = !!(data.status && data.data && data.data.status === 'success');

  await markOrderPaid(orderRef, order, paid, data.data);
  return { paid };
});

// Paystack also calls us directly (webhook) so payment confirmation is
// guaranteed even if the customer closes the app before verifying.
exports.paystackWebhook = onRequest(async (req, res) => {
  try {
    const crypto = require('crypto');
    const signature = req.get('x-paystack-signature') || '';
    const raw = req.rawBody ? req.rawBody.toString() : '';
    const expected = crypto.createHmac('sha512', process.env.PAYSTACK_SECRET_KEY || '').update(raw).digest('hex');
    if (!signature || signature !== expected) {
      res.status(401).send('bad signature');
      return;
    }
    const event = req.body || {};
    if (event.event === 'charge.success' && event.data && event.data.reference) {
      const snap = await db.collection('orders')
        .where('paymentReference', '==', event.data.reference).limit(1).get();
      if (!snap.empty) {
        const orderRef = snap.docs[0].ref;
        await markOrderPaid(orderRef, snap.docs[0].data(), true, event.data);
      }
    }
    res.sendStatus(200);
  } catch (error) {
    console.log('paystackWebhook error (ignored):', error);
    res.sendStatus(200); // always 200 so Paystack does not retry forever
  }
});

// Shared: flip paymentStatus and notify the customer when it changes.
async function markOrderPaid(orderRef, order, paid, paystackData) {
  const newStatus = paid ? 'Paid' : 'Unpaid';
  if (order.paymentStatus === newStatus) return;
  await orderRef.update({
    paymentStatus: newStatus,
    paidAt: paid ? FieldValue.serverTimestamp() : null,
    paymentChannel: (paystackData && paystackData.channel) || null,
  });
  if (paid) {
    await sendToUser(
      order.customerId,
      'Payment received ✅',
      `Your ₦${Math.round(order.grandTotal || 0)} payment to ${order.storeName || 'the store'} was confirmed.`
    );
  }
}
