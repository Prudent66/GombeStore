import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String imageUrl;
  final String shopName;
  final String shopId;
  final int stock;
  final bool isAvailable;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.imageUrl,
    required this.shopName,
    required this.shopId,
    this.stock = 0,
    this.isAvailable = true,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? 'Unknown Product',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      category: data['category'] ?? 'Other',
      imageUrl: data['imageUrl'] ?? '',
      shopName: data['shopName'] ?? 'Unknown Shop',
      shopId: data['vendorId'] ?? '',
      stock: data['stock'] ?? 0,
      isAvailable: data['isAvailable'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'imageUrl': imageUrl,
      'shopName': shopName,
      'vendorId': shopId,
      'stock': stock,
      'isAvailable': isAvailable,
    };
  }
}