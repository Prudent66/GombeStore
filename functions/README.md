# GombeStore Notifications (Cloud Functions)

Two Push notification flows, powered by Firebase Cloud Messaging (FCM):

| Trigger | Who gets notified |
|---|---|
| New order placed (`orders` doc created) | The vendor of that store |
| Order status changed (`status` field updated) | The customer who ordered |

Devices register themselves: when the app starts (or a user logs in),
`NotificationService` asks for notification permission and saves the FCM
token at `users/{uid}.fcmTokens` in Firestore. The functions read that
field and push to every registered device, cleaning up expired tokens.

## One-time setup on your machine

1. Install the Firebase CLI (any computer, or Termux):
   ```bash
   npm install -g firebase-tools
   ```
2. Log in and connect to your project (the project ID is in
   `android/app/google-services.json` — check `"project_id"`):
   ```bash
   cd GombeStore1
   firebase login
   firebase use --add   # pick your project, name it e.g. "default"
   ```
   (`firebase.json`, shipped in this repo, wires up Storage rules,
   Firestore rules and this `functions/` folder.)

3. Make sure **Cloud Messaging API (V1)** is enabled:
   Firebase Console → ⚙️ Project settings → Cloud Messaging → check the
   "Cloud Messaging API (V1)" tile is present (it is by default now).

## Deploy

```bash
cd functions
npm install
firebase deploy --only functions
```

You should then see `notifyVendorOnNewOrder` and
`notifyCustomerOnStatusChange` in the Firebase Console → Functions.

## Testing without a second person

- Log in on the app (this saves your push token).
- Place an order in another account/simulator, or in the Firebase
  Console change an order's `status` field — you should get a push.
- If nothing arrives: Console → Functions → Logs, we ignore failures
  on purpose so a broken notification can never block checkout.

## Paystack payments (Phase 14)

To offer card/bank-transfer/USSD checkout:

1. Create a Paystack account (paystack.com) and copy your **Secret key**
   from Dashboard → Settings → API Keys & Webhooks.
2. Store it as a Cloud Function secret — never in the repo:
   ```bash
   firebase functions:secrets:set PAYSTACK_SECRET_KEY
   ```
3. Redeploy to pick the secret up:
   ```bash
   firebase deploy --only functions
   ```
4. Console → your Paystack dashboard → Settings → API Keys & Webhooks →
   set the webhook URL to:
   ```
   https://paystackwebhook-<your-project-hash>-<region>.a.run.app
   ```
   (the exact URL is printed by `firebase deploy --only functions`)
5. Done. Checkout now shows "Pay with Paystack" alongside cash on
   delivery. The order is confirmed `Paid` by either the webhook or the
   customer tapping "Verify my payment", whichever comes first, and the
   money lands in your Paystack account.

Money flow: all Paystack orders are charged once per vendor order in
the shop's main account. If you later want automatic splits to vendors,
connect each vendor as a Paystack Subaccount and set `subaccount_code`
in `createPaystackPayment`.

## Notes

- Android 13+ shows the permission dialog on first app start
  (`POST_NOTIFICATIONS` is declared in the manifest).
- All pushes use the Android channel `orders`.
- Nothing is hard-wired into the Flutter build: pushing happens fully
  server-side, so disabling the functions never breaks checkout.
