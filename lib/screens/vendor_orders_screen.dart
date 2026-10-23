import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/order_service.dart';

class VendorOrdersScreen extends StatelessWidget {
  const VendorOrdersScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Confirmed':
        return Colors.blue;
      case 'Out for Delivery':
        return Colors.purple;
      case 'Delivered':
        return const Color(0xFF2E7D32);
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _nextActionLabel(String status) {
    switch (status) {
      case 'Pending':
        return 'Confirm Order';
      case 'Confirmed':
        return 'Mark Out for Delivery';
      case 'Out for Delivery':
        return 'Mark Delivered';
      default:
        return '';
    }
  }

  void _showOrderDetails(BuildContext context, QueryDocumentSnapshot doc) {
    final order = doc.data() as Map<String, dynamic>;
    final status = order['status'] ?? 'Pending';
    final items = (order['items'] as List<dynamic>? ?? [])
        .map((i) => i as Map<String, dynamic>)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Order Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Customer: ${order['customerName'] ?? 'Customer'}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Phone: ${order['customerPhone'] ?? 'N/A'}'),
              const SizedBox(height: 8),
              Text('Deliver to: ${order['address'] ?? ''}', style: const TextStyle(color: Colors.grey)),
              if ((order['deliveryAddress'] as Map<String, dynamic>?)?['instructions'] != null &&
                  (order['deliveryAddress'] as Map<String, dynamic>)['instructions'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Instructions: ${(order['deliveryAddress'] as Map<String, dynamic>)['instructions']}',
                      style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                ),
              const Divider(height: 24),

              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['variant'] != null && item['variant'].toString().isNotEmpty
                                ? '${item['name']} — ${item['variant']}'
                                : '${item['name']}',
                          ),
                        ),
                        Text('x${item['quantity']}', style: const TextStyle(color: Colors.grey)),
                        const SizedBox(width: 12),
                        Text('₦${((item['price'] ?? 0) as num).toStringAsFixed(0)}'),
                      ],
                    ),
                  )),
              const Divider(height: 24),

              _summaryRow('Product Total', '₦${((order['productTotal'] ?? 0) as num).toStringAsFixed(0)}'),
              _summaryRow('Shipping Fee', '₦${((order['shippingFee'] ?? 0) as num).toStringAsFixed(0)}'),
              _summaryRow('Grand Total', '₦${((order['grandTotal'] ?? 0) as num).toStringAsFixed(0)}', isBold: true),
              _summaryRow('Payment', order['paymentMethod'] ?? 'Cash on Delivery'),
              const SizedBox(height: 20),

              // Status action buttons
              if (_nextActionLabel(status).isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await OrderService().advanceStatus(doc.id, status);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(_nextActionLabel(status)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              if (status == 'Pending') ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: sheetContext,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Cancel this order?'),
                          content: const Text('The customer will be notified that this order is cancelled.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('No')),
                            TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await OrderService().cancelOrder(doc.id);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      }
                    },
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text('Cancel Order', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Incoming Orders')),
      body: StreamBuilder<QuerySnapshot>(
        // Sorted client-side to avoid needing a composite index in Firestore
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('vendorId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No orders yet.\n\nWhen customers order your products, they will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final ta = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              final tb = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              return (tb ?? Timestamp(0, 0)).compareTo(ta ?? Timestamp(0, 0));
            });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final order = doc.data() as Map<String, dynamic>;
              final status = order['status'] ?? 'Pending';
              final items = (order['items'] as List<dynamic>? ?? []);
              final itemCount = items.fold<int>(0, (total, item) => total + (((item as Map<String, dynamic>)['quantity'] ?? 1) as int));

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _statusColor(status).withOpacity(0.15),
                    child: Icon(Icons.shopping_bag, color: _statusColor(status)),
                  ),
                  title: Text(order['customerName'] ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '$itemCount item(s) • ₦${((order['grandTotal'] ?? 0) as num).toStringAsFixed(0)}\n'
                    'Tap to manage • Status: $status',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showOrderDetails(context, doc),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
