import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_approvals_screen.dart';
import 'admin_shipping_screen.dart';
import 'admin_seed_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_complaints_screen.dart';
import 'submit_complaint_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_revenue_screen.dart';

/// Phase 20: redesigned admin dashboard — tabbed shell with a Material
/// bottom navigation bar (Overview / Orders / Approvals / Tools).
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _tab = 0;

  static const _brand = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          _AdminHomeTab(),
          AdminOrdersScreen(),
          AdminApprovalsScreen(),
          _AdminToolsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        indicatorColor: _brand.withOpacity(0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outline),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.verified_outlined),
            selectedIcon: Icon(Icons.verified),
            label: 'Approvals',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Tools',
          ),
        ],
      ),
    );
  }
}

/// Overview tab: live platform stats + quick actions.
class _AdminHomeTab extends StatefulWidget {
  const _AdminHomeTab();

  @override
  State<_AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<_AdminHomeTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {}); // re-runs the stat count queries
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                        child: Icon(Icons.shield, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GombeStore Control Panel',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            Text(
                              'Admin Dashboard',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
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
                    // Platform stats (live)
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.7,
                      children: [
                        _AdminStatTile(
                          label: 'Vendors',
                          icon: Icons.store,
                          color: Colors.blue,
                          future: _count('users', 'role', 'vendor'),
                        ),
                        _AdminStatTile(
                          label: 'Customers',
                          icon: Icons.people,
                          color: Colors.purple,
                          future: _count('users', 'role', 'customer'),
                        ),
                        _AdminStatTile(
                          label: 'All Orders',
                          icon: Icons.receipt_long,
                          color: Colors.orange,
                          future: _ordersCount(),
                        ),
                        _AdminStatTile(
                          label: 'Revenue',
                          icon: Icons.payments,
                          color: Colors.green,
                          future: _revenue(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
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
                          icon: Icons.verified,
                          label: 'Approvals',
                          color: Colors.blue,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AdminApprovalsScreen()),
                          ),
                        ),
                        _ActionTile(
                          icon: Icons.receipt_long,
                          label: 'Orders',
                          color: Colors.orange,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AdminOrdersScreen()),
                          ),
                        ),
                        _ActionTile(
                          icon: Icons.people,
                          label: 'Customers',
                          color: Colors.purple,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AdminCustomersScreen()),
                          ),
                        ),
                        _ActionTile(
                          icon: Icons.payments,
                          label: 'Revenue',
                          color: Colors.green,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AdminRevenueScreen()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Recent orders (latest 3, live)
                    const Text('Latest Orders',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    _recentOrders(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentOrders() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(3)
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
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Text(
            'No orders placed yet.',
            style: TextStyle(color: Colors.grey),
          );
        }
        return Column(
          children: docs.map((doc) {
            final d = doc.data();
            final status = (d['status'] ?? 'Pending').toString();
            final g = (d['grandTotal'] ?? 0) is num ? (d['grandTotal'] as num) : 0;
            final items = (d['items'] as List?) ?? [];
            final name = items.isNotEmpty
                ? ((items.first as Map)['name'] ?? 'Order').toString()
                : 'Order';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                leading: Icon(
                  Icons.receipt_outlined,
                  color: statusColor(status),
                ),
                title: Text((d['storeName'] ?? 'Store').toString(),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '$name • ₦${g.toStringAsFixed(0)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: statusChip(status),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'Delivered':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      case 'Out for Delivery':
        return Colors.blue;
      case 'Confirmed':
        return Colors.indigo;
      default:
        return Colors.orange;
    }
  }

  static Widget statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor(status).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: statusColor(status),
        ),
      ),
    );
  }

  Future<String> _count(String collection, String field, dynamic value) async {
    try {
      final agg = await FirebaseFirestore.instance
          .collection(collection)
          .where(field, isEqualTo: value)
          .count()
          .get();
      return '${agg.count ?? 0}';
    } catch (_) {
      return '—';
    }
  }

  Future<String> _ordersCount() async {
    try {
      final agg = await FirebaseFirestore.instance.collection('orders').count().get();
      return '${agg.count ?? 0}';
    } catch (_) {
      return '—';
    }
  }

  Future<String> _revenue() async {
    try {
      final agg = await FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'Delivered')
          .get();
      double total = 0;
      for (final doc in agg.docs) {
        final v = doc.data()['grandTotal'] ?? doc.data()['productTotal'] ?? 0;
        total += (v is num) ? v.toDouble() : 0;
      }
      return '₦${total.toStringAsFixed(0)}';
    } catch (_) {
      return '—';
    }
  }
}

/// Admin stat tile with a cached count/value.
class _AdminStatTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Future<String> future;

  const _AdminStatTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.future,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          FutureBuilder<String>(
            future: future,
            builder: (context, snap) => Text(
              snap.data ?? '—',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

/// Tools tab: everything admins need beyond overview/orders.
class _AdminToolsTab extends StatelessWidget {
  const _AdminToolsTab();

  @override
  Widget build(BuildContext context) {
    final items = <MenuTileEntry>[
      MenuTileEntry(Icons.local_shipping, 'Configure Shipping Fees',
          const Color(0xFF2E7D32), () => const AdminShippingScreen()),
      MenuTileEntry(Icons.people, 'Customers', Colors.purple,
          () => const AdminCustomersScreen()),
      MenuTileEntry(Icons.payments, 'Revenue', Colors.green,
          () => const AdminRevenueScreen()),
      MenuTileEntry(Icons.cloud_upload, 'Seed Sample Products', Colors.teal,
          () => const AdminSeedScreen()),
      MenuTileEntry(Icons.report_problem, 'Complaints & Refunds', Colors.redAccent,
          () => const AdminComplaintsScreen()),
      MenuTileEntry(Icons.support_agent, 'Submit Complaint', Colors.blue,
          () => const SubmitComplaintScreen()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Tools'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final it = items[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: it.color.withOpacity(0.12),
                child: Icon(it.icon, color: it.color),
              ),
              title: Text(it.label, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: it.builder),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MenuTileEntry {
  final IconData icon;
  final String label;
  final Color color;
  final Widget Function() builder;

  const MenuTileEntry(this.icon, this.label, this.color, this.builder);
}
