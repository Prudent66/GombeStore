import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminRevenueScreen extends StatelessWidget {
  const AdminRevenueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Revenue Reports')),
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
                  'No orders yet.\n\nRevenue will appear here once customers start ordering.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          final orders = snapshot.data!.docs
              .map((d) => d.data() as Map<String, dynamic>)
              .toList();

          // ---- Aggregates ----
          double deliveredRevenue = 0;
          double pendingRevenue = 0;
          double shippingCollected = 0;
          int deliveredCount = 0;
          int activeCount = 0;
          int cancelledCount = 0;
          final Map<String, double> revenueByLga = {};
          final Map<String, double> revenueByStore = {};
          final Map<String, int> ordersByStatus = {};

          for (final o in orders) {
            final status = o['status'] ?? 'Pending';
            final grandTotal = ((o['grandTotal'] ?? 0) as num).toDouble();
            final shipping = ((o['shippingFee'] ?? 0) as num).toDouble();
            final lga = (o['deliveryAddress'] as Map<String, dynamic>?)?['lga'] ?? 'Unknown';
            final store = o['storeName'] ?? 'Unknown Store';

            ordersByStatus[status] = (ordersByStatus[status] ?? 0) + 1;

            if (status == 'Cancelled') {
              cancelledCount++;
              continue;
            }
            if (status == 'Delivered') {
              deliveredRevenue += grandTotal;
              shippingCollected += shipping;
              deliveredCount++;
              revenueByLga[lga] = (revenueByLga[lga] ?? 0) + grandTotal;
              revenueByStore[store] = (revenueByStore[store] ?? 0) + grandTotal;
            } else {
              pendingRevenue += grandTotal;
              activeCount++;
            }
          }

          final avgOrder = deliveredCount > 0 ? deliveredRevenue / deliveredCount : 0.0;
          final now = DateTime.now();
          final monthStart = DateTime(now.year, now.month, 1);
          double thisMonthRevenue = 0;
          for (final o in orders) {
            final ts = o['createdAt'] as Timestamp?;
            if (ts == null) continue;
            if ((o['status'] ?? '') == 'Delivered' && ts.toDate().isAfter(monthStart)) {
              thisMonthRevenue += ((o['grandTotal'] ?? 0) as num).toDouble();
            }
          }

          final topStores = revenueByStore.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Headline: total delivered revenue
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text('Total Revenue (Delivered)', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(
                      '₦${_fmt(deliveredRevenue)}',
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text('$deliveredCount delivered orders • Avg ₦${_fmt(avgOrder)} per order',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Secondary stats
              Row(
                children: [
                  _statCard('This Month', '₦${_fmt(thisMonthRevenue)}', Colors.green, Icons.calendar_month),
                  const SizedBox(width: 10),
                  _statCard('In Progress ($activeCount)', '₦${_fmt(pendingRevenue)}', Colors.orange, Icons.pending_actions),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _statCard('Shipping Collected', '₦${_fmt(shippingCollected)}', Colors.blue, Icons.local_shipping),
                  const SizedBox(width: 10),
                  _statCard('Cancelled', '$cancelledCount', Colors.red, Icons.cancel),
                ],
              ),
              const SizedBox(height: 24),

              // Revenue by LGA
              if (revenueByLga.isNotEmpty) ...[
                const Text('Revenue by Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...(revenueByLga.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value)))
                    .map((e) => _breakdownRow(Icons.location_on, e.key, e.value)),
                const SizedBox(height: 24),
              ],

              // Top stores
              if (topStores.isNotEmpty) ...[
                const Text('Top Stores', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...topStores.take(5).map((e) => _breakdownRow(Icons.store, e.key, e.value)),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _fmt(double v) => NumberFormat.decimalPattern().format(v);

  Widget _statCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow(IconData icon, String label, double value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: const Color(0xFF2E7D32), size: 22),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: Text('₦${_fmt(value)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
      ),
    );
  }
}
