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

class VendorDashboard extends StatelessWidget {
  const VendorDashboard({super.key});

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
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back,', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            Text(
              user?.email ?? 'Vendor',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 20),

            // Live stats row
            if (user != null)
              Row(
                children: [
                  _buildStatCard('Products', 'products', user.uid, Icons.inventory),
                  const SizedBox(width: 10),
                  _buildStatCard('New Orders', 'orders_pending', user.uid, Icons.shopping_bag),
                  const SizedBox(width: 10),
                  _buildStatCard('Earnings', 'earnings', user.uid, Icons.account_balance_wallet),
                ],
              ),
            const SizedBox(height: 30),

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
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageProductsScreen())),
            ),
            _buildActionButton(
              context,
              icon: Icons.shopping_cart_checkout,
              label: 'Incoming Orders',
              color: Colors.orange,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorOrdersScreen())),
            ),
            _buildActionButton(
              context,
              icon: Icons.store,
              label: 'My Store Profile',
              color: Colors.purple,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreProfileScreen())),
            ),
            _buildActionButton(
              context,
              icon: Icons.help_outline,
              label: 'Help & Support',
              color: Colors.teal,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubmitComplaintScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String type, String uid, IconData icon) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: type == 'orders_pending'
            ? FirebaseFirestore.instance.collection('orders').where('vendorId', isEqualTo: uid).where('status', isEqualTo: 'Pending').snapshots()
            : type == 'earnings'
                ? FirebaseFirestore.instance.collection('orders').where('vendorId', isEqualTo: uid).where('status', isEqualTo: 'Delivered').snapshots()
                : FirebaseFirestore.instance.collection('products').where('vendorId', isEqualTo: uid).snapshots(),
        builder: (context, snapshot) {
          String displayValue = '—';
          if (snapshot.hasData) {
            if (type == 'earnings') {
              double total = 0;
              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                total += (data['productTotal'] ?? 0).toDouble();
              }
              displayValue = '₦${total.toStringAsFixed(0)}';
            } else {
              displayValue = '${snapshot.data!.docs.length}';
            }
          }
          return Container(
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
                Text(displayValue, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          );
        },
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