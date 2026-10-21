import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'admin_approvals_screen.dart';
import 'admin_shipping_screen.dart';
import 'admin_seed_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_complaints_screen.dart';
import 'submit_complaint_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_revenue_screen.dart';
import 'login_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  void _logout(BuildContext context) async {
    await AuthService().signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome, Admin',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
            const SizedBox(height: 20),

            // Stats Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _buildStatTile('Vendors', Icons.store, Colors.blue, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalsScreen()));
                }),
                _buildStatTile('Orders', Icons.shopping_bag, Colors.orange, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOrdersScreen()));
                }),
                _buildStatTile('Customers', Icons.people, Colors.purple, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCustomersScreen()));
                }),
                _buildStatTile('Revenue', Icons.attach_money, Colors.green, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminRevenueScreen()));
                }),
              ],
            ),
            const SizedBox(height: 30),

            const Text('Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildMenuItem(
              context,
              icon: Icons.verified_user,
              label: 'Vendor Approvals',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalsScreen())),
            ),
            _buildMenuItem(
              context,
              icon: Icons.cloud_upload,
              label: 'Seed Sample Products',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSeedScreen())),
            ),
            _buildMenuItem(
              context,
              icon: Icons.local_shipping,
              label: 'Configure Shipping Fees',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminShippingScreen())),
            ),
            _buildMenuItem(
              context,
              icon: Icons.receipt_long,
              label: 'Manage Orders',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOrdersScreen())),
            ),
            _buildMenuItem(
              context,
              icon: Icons.report_problem,
              label: 'Complaints & Refunds',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminComplaintsScreen())),
            ),
            _buildMenuItem(
              context,
              icon: Icons.support_agent,
              label: 'Submit Complaint',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubmitComplaintScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF2E7D32)),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}