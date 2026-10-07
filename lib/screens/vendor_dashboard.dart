import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'add_product_screen.dart';

class VendorDashboard extends StatelessWidget {
  const VendorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Dashboard'),
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
            // Welcome Header
            Text(
              'Welcome back,',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            Text(
              user?.email ?? 'Vendor',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 20),

            // Quick Stats Cards
            Row(
              children: [
                _buildStatCard('Products', '0', Icons.inventory),
                const SizedBox(width: 10),
                _buildStatCard('New Orders', '0', Icons.shopping_bag),
                const SizedBox(width: 10),
                _buildStatCard('Earnings', '₦0', Icons.account_balance_wallet),
              ],
            ),
            const SizedBox(height: 30),

            // Action Buttons
            const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildActionButton(
              context,
              icon: Icons.add_box,
              label: 'Add New Product',
              color: const Color(0xFF2E7D32),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen())),
            ),
            _buildActionButton(
              context,
              icon: Icons.list_alt,
              label: 'Manage My Products',
              color: Colors.blue,
              onTap: () {}, // We will build this in the next step
            ),
            _buildActionButton(
              context,
              icon: Icons.shopping_cart_checkout,
              label: 'Incoming Orders',
              color: Colors.orange,
              onTap: () {},
            ),
            _buildActionButton(
              context,
              icon: Icons.store,
              label: 'My Store Profile',
              color: Colors.purple,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)],
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF2E7D32)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}