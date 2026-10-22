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

## Notes

- Android 13+ shows the permission dialog on first app start
  (`POST_NOTIFICATIONS` is declared in the manifest).
- All pushes use the Android channel `orders`.
- Nothing is hard-wired into the Flutter build: pushing happens fully
  server-side, so disabling the functions never breaks checkout.
