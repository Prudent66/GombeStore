import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/review_service.dart' show showReviewDialog;
import '../models/product.dart';
import '../services/cart_service.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            product.imageData != null && product.imageData!.isNotEmpty
    ? Image.memory(
        base64Decode(product.imageData!),
        width: double.infinity,
        height: 300,
        fit: BoxFit.cover,
      )
    : CachedNetworkImage(
        imageUrl: product.imageUrl,
        width: double.infinity,
        height: 300,
        fit: BoxFit.cover,
        errorWidget: (context, error, stackTrace) => Container(
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
                  // Quantity selector (clamped to available stock)
                  Row(
                    children: [
                      const Text('Quantity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        onPressed: _qty <= 1 ? null : () => setState(() => _qty--),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$_qty',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: _qty >= product.stock ? null : () => setState(() => _qty++),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'of ${product.stock} in stock',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Description
                  const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(product.description, style: const TextStyle(fontSize: 16, height: 1.5)),
                  const SizedBox(height: 30),
                  _buildReviewsSection(context),
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
          onPressed: product.stock <= 0
              ? null
              : () {
                  // Adds the selected quantity to the global cart
                  Provider.of<CartService>(context, listen: false).addItem(product, quantity: _qty);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added $_qty × ${product.name} to Cart!'),
                      backgroundColor: const Color(0xFF2E7D32),
                    ),
                  );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            disabledBackgroundColor: Colors.grey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            product.stock <= 0 ? 'Out of Stock' : 'Add $_qty to Cart • ₦${(product.price * _qty).toStringAsFixed(0)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsSection(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .snapshots(),
      builder: (context, productSnap) {
        final data = productSnap.data?.data() ?? const {};
        final ratingAvg = data['ratingAvg'] as num?;
        final reviewCount = (data['reviewCount'] ?? 0) as int;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('products')
              .doc(product.id)
              .collection('reviews')
              .orderBy('createdAt', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, reviewsSnap) {
            if (reviewsSnap.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }
            final reviews = reviewsSnap.data?.docs ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (reviewCount > 0) ...[
                      const Icon(Icons.star, size: 18, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${ratingAvg?.toStringAsFixed(1) ?? '-'} ($reviewCount)',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async => showReviewDialog(
                      context,
                      productId: product.id,
                      productName: product.name,
                    ),
                    icon: const Icon(Icons.edit_note),
                    label:
                        Text(reviewCount == 0 ? 'Be the first to review' : 'Write / edit your review'),
                  ),
                ),
                const SizedBox(height: 12),
                if (reviews.isEmpty)
                  const Text(
                    'No reviews yet.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  )
                else
                  ...reviews.map((r) {
                    final map = r.data();
                    final stars = ((map['rating'] as num?) ?? 0).toInt();
                    final createdAt = map['createdAt'] as Timestamp?;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                (map['userName'] ?? 'Customer') as String,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const Spacer(),
                              if (createdAt != null)
                                Text(
                                  DateFormat.yMMMd().format(createdAt.toDate()),
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (i) => Icon(
                                  i < stars ? Icons.star : Icons.star_border,
                                  size: 14,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                          if (((map['comment'] ?? '') as String).isNotEmpty)
                            Text((map['comment']) as String, style: const TextStyle(fontSize: 13, height: 1.3)),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 10),
              ],
            );
          },
        );
      },
    );
  }
}