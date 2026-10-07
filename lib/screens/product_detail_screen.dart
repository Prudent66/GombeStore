import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/cart_service.dart';

class ProductDetailScreen extends StatelessWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Image.network(
              product.imageUrl,
              width: double.infinity,
              height: 300,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 300,
                color: Colors.grey[200],
                child: const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shop Name
                  Text(
                    product.shopName,
                    style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  // Product Name
                  Text(
                    product.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  // Price
                  Text(
                    '₦${product.price.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                  ),
                  const SizedBox(height: 20),
                  // Category
                  Chip(
                    label: Text(product.category),
                    backgroundColor: Colors.grey[200],
                  ),
                  const SizedBox(height: 20),
                  // Description
                  const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(product.description, style: const TextStyle(fontSize: 16, height: 1.5)),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
      // Add to Cart Button (Bottom)
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            // This now adds the product to the global cart
            Provider.of<CartService>(context, listen: false).addItem(product);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Added to Cart!'), backgroundColor: Color(0xFF2E7D32)),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Add to Cart', style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}