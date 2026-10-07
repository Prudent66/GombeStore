import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'admin_approvals_screen.dart';
import 'admin_shipping_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome, Admin', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
            const SizedBox(height: 20),

            // Stats Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _buildStatTile('Vendors', Icons.store, Colors.blue),
                _buildStatTile('Orders', Icons.shopping_bag, Colors.orange),
                _buildStatTile('Customers', Icons.people, Colors.purple),
                _buildStatTile('Revenue', Icons.attach_money, Colors.green),
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
              icon: Icons.local_shipping,
              label: 'Configure Shipping Fees',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminShippingScreen())),
            ),
            _buildMenuItem(
              context,
              icon: Icons.receipt_long,
              label: 'Manage Orders',
              onTap: () {}, // Future
            ),
            _buildMenuItem(
              context,
              icon: Icons.report_problem,
              label: 'Complaints & Refunds',
              onTap: () {}, // Future
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String title, IconData icon, Color color) {
    return Container(
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