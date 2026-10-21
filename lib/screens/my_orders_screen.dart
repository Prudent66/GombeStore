import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/order_service.dart';

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

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

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Pending':
        return Icons.hourglass_top;
      case 'Confirmed':
        return Icons.check_circle_outline;
      case 'Out for Delivery':
        return Icons.local_shipping;
      case 'Delivered':
        return Icons.task_alt;
      case 'Cancelled':
        return Icons.cancel;
      default:
        return Icons.receipt_long;
    }
  }

  void _cancelOrder(BuildContext context, Map<String, dynamic> order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text('The vendor will be notified and your refund will be processed when they confirm the cancellation.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await OrderService().cancelOrder(order.keys.first);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: StreamBuilder<QuerySnapshot>(
        // Sorted client-side to avoid needing a composite index in Firestore
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: user.uid)
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
                  'No orders yet.\n\nYour orders will appear here after checkout.',
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
              return _buildOrderCard(context, doc.id, order);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, String orderId, Map<String, dynamic> order) {
    final status = order['status'] ?? 'Pending';
    final createdAt = order['createdAt'] as Timestamp?;
    final dateText = createdAt != null
        ? DateFormat.yMMMd().add_jm().format(createdAt.toDate())
        : 'Just now';

    final items = (order['items'] as List<dynamic>? ?? [])
        .map((i) => i as Map<String, dynamic>)
        .toList();

    final canCancel = status == 'Pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store + date + menu row
            Row(
              children: [
                const Icon(Icons.store, size: 18, color: Color(0xFF2E7D32)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order['storeName'] ?? 'Store',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(dateText, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (canCancel)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    tooltip: 'Cancel Order',
                    onPressed: () => _cancelOrder(context, {'$orderId': order}),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Items list
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item['name']}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text('x${item['quantity']}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(width: 12),
                      Text('₦${(item['price'] ?? 0).toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                )),
            const Divider(height: 16),

            // Total + status row
            Row(
              children: [
                Text(
                  '₦${(order['grandTotal'] ?? 0).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status), size: 14, color: _statusColor(status)),
                      const SizedBox(width: 4),
                      Text(status, style: TextStyle(fontSize: 12, color: _statusColor(status), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),

            // Delivery address (collapsed)
            const SizedBox(height: 8),
            Text(
              'Deliver to: ${order['address'] ?? ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              'Payment: ${order['paymentMethod'] ?? 'Cash on Delivery'}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
