import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

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

  void _showOrderDetails(BuildContext context, QueryDocumentSnapshot doc) {
    final order = doc.data() as Map<String, dynamic>;
    final status = order['status'] ?? 'Pending';
    final items = (order['items'] as List<dynamic>? ?? [])
        .map((i) => i as Map<String, dynamic>)
        .toList();
    final createdAt = order['createdAt'] as Timestamp?;
    final dateText = createdAt != null
        ? DateFormat.yMMMd().add_jm().format(createdAt.toDate())
        : 'Just now';

    final statuses = ['Pending', 'Confirmed', 'Out for Delivery', 'Delivered', 'Cancelled'];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Order • ${order['storeName'] ?? 'Store'}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Customer: ${order['customerName'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Phone: ${order['customerPhone'] ?? 'N/A'}'),
                Text('Placed: $dateText'),
                Text('Address: ${order['address'] ?? ''}'),
                Text('Payment: ${order['paymentMethod'] ?? 'Cash on Delivery'}'),
                const Divider(height: 20),
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
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
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Grand Total:'),
                    Text('₦${((order['grandTotal'] ?? 0) as num).toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: statuses.contains(status) ? status : 'Pending',
                  decoration: const InputDecoration(
                    labelText: 'Update Status',
                    border: OutlineInputBorder(),
                  ),
                  items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (newStatus) async {
                    if (newStatus == null || newStatus == status) return;
                    await FirebaseFirestore.instance
                        .collection('orders')
                        .doc(doc.id)
                        .update({'status': newStatus});
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Orders')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .orderBy('createdAt', descending: true)
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
                  'No orders yet.\n\nWhen customers place orders, they will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final order = doc.data() as Map<String, dynamic>;
              final status = order['status'] ?? 'Pending';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _statusColor(status).withOpacity(0.15),
                    child: Icon(Icons.receipt_long, color: _statusColor(status)),
                  ),
                  title: Text(order['customerName'] ?? 'Unknown Customer'),
                  subtitle: Text(
                    '${order['storeName'] ?? 'Store'} • ₦${((order['grandTotal'] ?? 0) as num).toStringAsFixed(0)}',
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(status, style: TextStyle(fontSize: 11, color: _statusColor(status), fontWeight: FontWeight.bold)),
                  ),
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
