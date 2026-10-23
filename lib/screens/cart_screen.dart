import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/cart_service.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
      ),
      body: cart.items.isEmpty
          ? const Center(child: Text('Your cart is empty.'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final product = cart.items[index];
                      final quantity = cart.quantities[product.id] ?? 1;
                      final atMax = product.stock > 0 && quantity >= product.stock;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
                          child: Row(
                            children: [
                              _CartThumb(product: product),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₦${product.price.toStringAsFixed(0)} each',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₦${(product.price * quantity).toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Color(0xFF2E7D32),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Quantity stepper (- qty +), clamped to stock
                              Column(
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.remove_circle_outline),
                                        onPressed: () => cart.changeQuantity(product, -1),
                                      ),
                                      Text(
                                        '$quantity',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.add_circle_outline),
                                        onPressed: atMax ? null : () => cart.changeQuantity(product, 1),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    atMax ? 'max stock ${product.stock}' : 'in stock ${product.stock}',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => cart.removeItem(product),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Total Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, -3))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Product Total:', style: TextStyle(fontSize: 16)),
                          Text('₦${cart.productTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Proceed to Checkout', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Cart thumbnail that supports both hosted URLs and
/// base64-fallback images (used on the Spark plan).
class _CartThumb extends StatelessWidget {
  final Product product;

  const _CartThumb({required this.product});

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.image, size: 28, color: Colors.grey),
        );

    if (product.imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: product.imageUrl,
          width: 55,
          height: 55,
          fit: BoxFit.cover,
          errorWidget: (c, e, s) => placeholder(),
        ),
      );
    }
    if (product.imageData != null && product.imageData!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          base64Decode(product.imageData!),
          width: 55,
          height: 55,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => placeholder(),
        ),
      );
    }
    return placeholder();
  }
}