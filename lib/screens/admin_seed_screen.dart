import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSeedScreen extends StatefulWidget {
  const AdminSeedScreen({super.key});

  @override
  State<AdminSeedScreen> createState() => _AdminSeedScreenState();
}

class _AdminSeedScreenState extends State<AdminSeedScreen> {
  bool _isLoading = false;

  final List<Map<String, dynamic>> _sampleProducts = [
    {
      'name': 'Fresh Tomatoes (Basket)',
      'description': 'Locally grown fresh tomatoes from Kaltungo.',
      'price': 4500,
      'category': 'Food & Grocery',
      'imageUrl': 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=500',
      'shopName': 'Gombe Fresh Mart',
      'vendorId': 'seed_vendor_1',
      'stock': 50,
      'isAvailable': true,
    },
    {
      'name': 'Samsung Galaxy A15',
      'description': 'Brand new Samsung A15 with 128GB storage.',
      'price': 185000,
      'category': 'Electronics',
      'imageUrl': 'https://images.unsplash.com/photo-1610945415295-d9bbf067e59c?w=500',
      'shopName': 'Tech Hub Gombe',
      'vendorId': 'seed_vendor_2',
      'stock': 10,
      'isAvailable': true,
    },
    {
      'name': "Men's Kaftan",
      'description': 'Premium quality Kaftan for special occasions.',
      'price': 12000,
      'category': 'Fashion',
      'imageUrl': 'https://images.unsplash.com/photo-1594938298603-c8148c47e35d?w=500',
      'shopName': 'Zainab Fashion',
      'vendorId': 'seed_vendor_3',
      'stock': 25,
      'isAvailable': true,
    },
    {
      'name': 'Bag of Rice (50kg)',
      'description': 'Quality local rice, perfect for family meals.',
      'price': 65000,
      'category': 'Food & Grocery',
      'imageUrl': 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=500',
      'shopName': 'Gombe Fresh Mart',
      'vendorId': 'seed_vendor_1',
      'stock': 30,
      'isAvailable': true,
    },
    {
      'name': 'Wireless Earbuds',
      'description': 'Noise cancelling earbuds with long battery life.',
      'price': 15000,
      'category': 'Electronics',
      'imageUrl': 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=500',
      'shopName': 'Tech Hub Gombe',
      'vendorId': 'seed_vendor_2',
      'stock': 40,
      'isAvailable': true,
    },
    {
      'name': "Women's Abaya",
      'description': 'Elegant black Abaya with embroidery.',
      'price': 18000,
      'category': 'Fashion',
      'imageUrl': 'https://images.unsplash.com/photo-1596783074918-c84cb06531ca?w=500',
      'shopName': 'Zainab Fashion',
      'vendorId': 'seed_vendor_3',
      'stock': 15,
      'isAvailable': true,
    },
    {
      'name': 'Face Moisturizer',
      'description': 'Hydrating face cream for daily use.',
      'price': 3500,
      'category': 'Health',
      'imageUrl': 'https://images.unsplash.com/photo-1556228720-195a672e8a03?w=500',
      'shopName': 'Beauty Corner',
      'vendorId': 'seed_vendor_4',
      'stock': 60,
      'isAvailable': true,
    },
    {
      'name': 'Wooden Dining Chair',
      'description': 'Sturdy wooden chair, perfect for dining sets.',
      'price': 22000,
      'category': 'Home & Living',
      'imageUrl': 'https://images.unsplash.com/photo-1503602642458-232111445657?w=500',
      'shopName': 'Gombe Furniture',
      'vendorId': 'seed_vendor_5',
      'stock': 20,
      'isAvailable': true,
    },
  ];

  Future<void> _seedProducts() async {
    setState(() => _isLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var product in _sampleProducts) {
        final docRef = FirebaseFirestore.instance.collection('products').doc();
        batch.set(docRef, {
          ...product,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully added ${_sampleProducts.length} products!'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clearProducts() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('products').get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All products deleted.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seed Products')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add Sample Products',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 10),
            const Text(
              'This will add 8 sample products to your Firestore database. Only run this once — otherwise you\'ll get duplicates.',
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _sampleProducts.length,
                itemBuilder: (context, index) {
                  final p = _sampleProducts[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Image.network(
                        p['imageUrl'],
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(Icons.image, size: 50),
                      ),
                      title: Text(p['name']),
                      subtitle: Text('${p['category']} • ₦${p['price']}'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _seedProducts,
              icon: const Icon(Icons.cloud_upload),
              label: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('Add ${_sampleProducts.length} Products to Firestore'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _clearProducts,
              icon: const Icon(Icons.delete_forever),
              label: const Text('Delete All Products'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}