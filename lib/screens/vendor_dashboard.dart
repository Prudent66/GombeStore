import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'add_product_screen.dart';
import 'manage_products_screen.dart';
import 'vendor_orders_screen.dart';
import 'store_profile_screen.dart';
import 'login_screen.dart';
import 'submit_complaint_screen.dart';

/// Shared brand green for the dashboards.
const Color _brand = Color(0xFF2E7D32);

/// Phase 20: redesigned vendor dashboard — a tabbed shell with a Material
/// bottom navigation bar (Overview / Products / Orders / Store).
class VendorDashboard extends StatefulWidget {
  const VendorDashboard({super.key});

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();

  static void logout(BuildContext context) async {
    await AuthService().signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}

class _VendorDashboardState extends State<VendorDashboard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          _VendorHomeTab(),
          ManageProductsScreen(),
          VendorOrdersScreen(),
          StoreProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        indicatorColor: _brand.withOpacity(0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Store',
          ),
        ],
      ),
    );
  }
}

/// Overview tab: branded header, live stats, quick actions, recent orders.
class _VendorHomeTab extends StatelessWidget {
  const _VendorHomeTab();

  Future<String> _storeName(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return (doc.data()?['storeName'] ?? 'My Store').toString();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Branded header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 20),
              color: _brand,
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.storefront, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back${user?.displayName != null && user!.displayName!.isNotEmpty ? ',' : ''}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          FutureBuilder<String>(
                            future: _storeName(uid),
                            builder: (context, snap) => Text(
                              snap.data ?? 'My Store',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      tooltip: 'Logout',
                      onPressed: () => VendorDashboard.logout(context),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Live stats
                  if (uid.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Products',
                            icon: Icons.inventory_2,
                            color: Colors.blue,
                            stream: FirebaseFirestore.instance
                                .collection('products')
                                .where('vendorId', isEqualTo: uid)
                                .snapshots(),
                            value: (docs) => '${docs!.length}',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            label: 'New Orders',
                            icon: Icons.receipt_long,
                            color: Colors.orange,
                            stream: FirebaseFirestore.instance
                                .collection('orders')
                                .where('vendorId', isEqualTo: uid)
                                .where('status', isEqualTo: 'Pending')
                                .snapshots(),
                            value: (docs) => '${docs!.length}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _StatCard(
                      label: 'Earnings (Delivered orders)',
                      icon: Icons.account_balance_wallet,
                      color: Colors.green,
                      stream: FirebaseFirestore.instance
                          .collection('orders')
                          .where('vendorId', isEqualTo: uid)
                          .where('status', isEqualTo: 'Delivered')
                          .snapshots(),
                      value: (docs) {
                        double total = 0;
                        for (final doc in (docs ?? const [])) {
                          final d = doc.data() as Map<String, dynamic>;
                          final v = d['grandTotal'] ?? d['productTotal'] ?? 0;
                          total += (v is num) ? v.toDouble() : 0;
                        }
                        return '₦${total.toStringAsFixed(0)}';
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  const Text('Quick Actions',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.6,
                    children: [
                      _ActionTile(
                        icon: Icons.add_box,
                        label: 'Add Product',
                        color: _brand,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddProductScreen()),
                        ),
                      ),
                      _ActionTile(
                        icon: Icons.inventory_2,
                        label: 'My Products',
                        color: Colors.blue,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ManageProductsScreen()),
                        ),
                      ),
                      _ActionTile(
                        icon: Icons.receipt_long,
                        label: 'Orders',
                        color: Colors.orange,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const VendorOrdersScreen()),
                        ),
                      ),
                      _ActionTile(
                        icon: Icons.support_agent,
                        label: 'Help & Support',
                        color: Colors.teal,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SubmitComplaintScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Recent orders (latest 3, live)
                  const Text('Recent Orders',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('orders')
                        .where('vendorId', isEqualTo: uid)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final docs = snap.data!.docs.toList()
                        ..sort((a, b) {
                          final ta = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?
                              ?? Timestamp(0, 0);
                          final tb = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?
                              ?? Timestamp(0, 0);
                          return tb.compareTo(ta);
                        });
                      final latest = docs.take(3).toList();
                      if (latest.isEmpty) {
                        return const Text(
                          'No orders yet — sales will appear here.',
                          style: TextStyle(color: Colors.grey),
                        );
                      }
                      return Column(
                        children: latest.map((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          final status = (d['status'] ?? 'Pending').toString();
                          final g = d['grandTotal'] ?? d['productTotal'] ?? 0;
                          final items = (d['items'] as List?) ?? [];
                          final name = items.isNotEmpty
                              ? (items.first as Map)['name']?.toString() ?? 'Order'
                              : 'Order';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.receipt_outlined,
                                color: _statusColor(status),
                              ),
                              title: Text(name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                '₦${g is num ? g.toStringAsFixed(0) : '0'} • ${_timeOf(d['createdAt'])}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: _statusChip(status),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'Delivered':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      case 'Out for Delivery':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  static String _timeOf(dynamic ts) {
    try {
      if (ts is Timestamp) {
        final d = ts.toDate();
        return '${d.hour % 12 == 0 ? 12 : d.hour % 12}:${d.minute.toString().padLeft(2, '0')} '
            '${d.hour < 12 ? 'AM' : 'PM'}';
      }
    } catch (_) {}
    return '';
  }

  static Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor(status).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: _statusColor(status),
        ),
      ),
    );
  }
}

/// Live stat card fed by any Firestore query snapshot.
class _StatCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot>? stream;
  final String Function(List<QueryDocumentSnapshot>?) value;

  const _StatCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.stream,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 6)],
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (context, snap) {
            final v = snap.hasData ? value(snap.data!.docs) : '—';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  v,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          },
        ),
    );
  }
}

/// Quick-action tile with a colored rounded icon.
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 6)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
