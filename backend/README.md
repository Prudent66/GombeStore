# GombeStore backend on Cloudflare Workers (FREE, no card, deploy from phone)

Replaces Firebase Cloud Functions on the Spark (free) plan. Two jobs:

1. **Paystack** — `/pay/initialize`, `/pay/verify`, `/paystack/webhook`
2. **Push notifications** — a cron that watches Firestore every minute and
   sends FCM pushes to vendors (new orders) and customers (status changes,
   payments) using your project's service account.

> Free-tier capacity is plenty: 100k requests/day, cron every minute,
> tiny KV storage for change-tracking. If the project later upgrades to
> Blaze, the original `functions/` folder still works as a native Firebase
> alternative — the two do not conflict (disable one when enabling the other).

## Setup (10 minutes, phone browser only)

### 1. Create the Worker
1. Go to **dash.cloudflare.com** and sign up (email only — **no card**).
2. Left menu → **Workers & Pages** → **Create Worker**.
3. Name it `gombestore-api` → **Deploy** (default code is fine for now).
4. On the worker page → **Edit code** → delete everything →
   paste the contents of **`backend/worker.js`** (from this repo) → **Deploy**.
   Note your URL: `https://gombestore-api.<your-subdomain>.workers.dev`

### 2. Create the KV namespace (push notification tracking)
1. Left menu → **Storage & Databases → KV** → **Create a namespace**
   → name: `gombestore-kv`.
2. Back on the **gombestore-api** worker → **Settings → Bindings/Templates → Add**
   → **KV namespace** → variable name: **`KV`** → pick `gombestore-kv` → Deploy.

### 3. Add your secrets (Variables)
Worker → **Settings → Variables and Secrets** → add these as **Secret** type:

| Name | Value | Where to get it |
|---|---|---|
| `PAYSTACK_SECRET_KEY` | `sk_test_...` / `sk_live_...` | Paystack dashboard → Settings → API Keys & Webhooks |
| `APP_API_KEY` | a long random string you invent, e.g. 40 hex chars | You create it (random password generator works) |
| `SERVICE_ACCOUNT_JSON` | the whole service-account JSON (or its base64) | Firebase Console → ⚙️ Project settings → **Service accounts** → *Generate new private key* → downloads a `.json` to your phone → open it in Acode → copy **everything** |

> Tip: if the dashboard refuses multiline text (newlines inside the key),
> encode the whole JSON as base64 (e.g. via base64encode.org or by passing it
> through any online encoder) and paste the **base64 text** instead — the
> Worker auto-detects either form.

### 4. Enable the cron (push notifications)
Worker → **Triggers → Cron Triggers** → use the cloud editor to add:

```
* * * * *
```

(fires every minute; the Worker polls Firestore for changed orders and
sends pushes — it is cheaper than it sounds and inside free limits.)

### 5. Tell the app where the backend is
Firebase Console → **Firestore Database → Start collection**:

- Collection ID: `settings`
- Document ID: `backend`
- Field `url` (string): `https://gombestore-api.<your-subdomain>.workers.dev`
- Field `key` (string): the same `APP_API_KEY` value from step 3

The app reads this at runtime — **no code change or rebuild needed** if you
ever change the URL or key.

### 6. Paystack webhook (optional but recommended)
Paystack dashboard → Settings → API Keys & Webhooks → Webhook URL:

```
https://gombestore-api.<your-subdomain>.workers.dev/paystack/webhook
```

This confirms payments server-to-server even if the customer closes the app.

## How the app uses it
Checkout → "Pay with Paystack" → order created → app calls
`/pay/initialize` → opens Paystack in the browser → back in the app,
"Verify my payment" calls `/pay/verify` → order becomes `Paid` (✅ in
My Orders), customer gets the push. Vendors get "New order!" pushes from
the cron regardless of payment method.

## Troubleshooting
- **Worker test:** open `https://<your-worker>.workers.dev/` in the browser —
  should say "GombeStore API is running ✅".
- **401 from the app:** the `x-app-key` the app sends (settings/backend `key`)
  and the worker's `APP_API_KEY` must match exactly.
- **501 "not configured":** `PAYSTACK_SECRET_KEY` secret missing.
- **No pushes:** check `SERVICE_ACCOUNT_JSON`; the cron trigger exists; the
  user's `fcmTokens` field exists in Firestore (it is saved on app login);
  worker → Logs tab shows per-run output.
- **Firebase Service accounts console path:** Project settings → Service
  accounts → Firebase Admin SDK → "Generate new private key" button.
