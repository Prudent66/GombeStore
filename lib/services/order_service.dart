import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Places the order: splits the cart by vendor and creates one
  /// Firestore order document per vendor. The shipping fee is charged
  /// once (attached to the first vendor's order) so the sum of all
  /// order grandTotals equals what the customer saw at checkout.
  /// Also deducts the purchased quantity from each product's stock.
  ///
  /// Returns null on success, or an error message on failure.
  Future<String?> placeOrder({
    required List<Product> items,
    required Map<String, int> quantities,
    required String fullName,
    required String phone,
    required String lga,
    required String city,
    required String area,
    required String street,
    required String landmark,
    required String instructions,
    required double shippingFee,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'You must be logged in to place an order.';

      // Group cart items by vendor (each vendor gets their own order)
      final Map<String, List<Product>> byVendor = {};
      for (final product in items) {
        byVendor.putIfAbsent(product.shopId, () => []).add(product);
      }

      final addressParts = [street, area, city, lga].where((p) => p.isNotEmpty).join(', ');
      final fullAddress = landmark.isEmpty ? addressParts : '$addressParts (Landmark: $landmark)';

      final batch = _firestore.batch();
      final ordersRef = _firestore.collection('orders');
      final timestamp = FieldValue.serverTimestamp();

      double remainingShipping = shippingFee;

      for (final entry in byVendor.entries) {
        final vendorId = entry.key;
        final vendorItems = entry.value;

        double productTotal = 0;
        final List<Map<String, dynamic>> itemMaps = [];

        for (final product in vendorItems) {
          final qty = quantities[product.id] ?? 1;
          productTotal += product.price * qty;
          itemMaps.add({
            'productId': product.id,
            'name': product.name,
            'price': product.price,
            'quantity': qty,
            'imageUrl': product.imageUrl,
          });
          // Deduct stock on the product document
          batch.update(
            _firestore.collection('products').doc(product.id),
            {'stock': FieldValue.increment(-qty)},
          );
        }

        // Shipping is charged once, on the first vendor's order
        final double thisShipping = remainingShipping;
        remainingShipping = 0;

        batch.set(ordersRef.doc(), {
          'customerId': user.uid,
          'customerName': fullName,
          'customerPhone': phone,
          'customerEmail': user.email,
          'vendorId': vendorId,
          'storeName': vendorItems.first.shopName,
          'items': itemMaps,
          'productTotal': productTotal,
          'shippingFee': thisShipping,
          'grandTotal': productTotal + thisShipping,
          'address': fullAddress,
          'deliveryAddress': {
            'lga': lga,
            'city': city,
            'area': area,
            'street': street,
            'landmark': landmark,
            'instructions': instructions,
          },
          'paymentMethod': 'Cash on Delivery',
          'status': 'Pending',
          'createdAt': timestamp,
        });
      }

      await batch.commit().timeout(const Duration(seconds: 15));

      // Mark products that just ran out of stock as unavailable
      try {
        for (final product in items) {
          final doc = await _firestore.collection('products').doc(product.id).get();
          final stock = (doc.data()?['stock'] ?? 0) as num;
          if (stock <= 0 && (doc.data()?['isAvailable'] ?? true) == true) {
            await _firestore.collection('products').doc(product.id).update({'isAvailable': false});
          }
        }
      } catch (_) {
        // Non-critical: stock already deducted, availability sync can fail silently
      }

      return null;
    } catch (e) {
      return 'Could not place order. Check your internet and try again.\n($e)';
    }
  }

  /// Moves an order to the next status in its lifecycle.
  /// Pending -> Confirmed -> Out for Delivery -> Delivered
  Future<void> advanceStatus(String orderId, String currentStatus) async {
    const flow = ['Pending', 'Confirmed', 'Out for Delivery', 'Delivered'];
    final index = flow.indexOf(currentStatus);
    if (index < 0 || index >= flow.length - 1) return;
    await _firestore
        .collection('orders')
        .doc(orderId)
        .update({
      'status': flow[index + 1],
      // Keep a timestamped trail so the customer can track the order.
      'statusHistory': FieldValue.arrayUnion([
        {'status': flow[index + 1], 'at': FieldValue.serverTimestamp()},
      ]),
    });
  }

  /// Cancels an order (only makes sense before it is delivered).
  Future<void> cancelOrder(String orderId) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': 'Cancelled',
      'statusHistory': FieldValue.arrayUnion([
        {'status': 'Cancelled', 'at': FieldValue.serverTimestamp()},
      ]),
    });
  }
}
