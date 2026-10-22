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
