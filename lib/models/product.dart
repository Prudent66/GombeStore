import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String imageUrl;
  final String? imageData;
  final String shopName;
  final String shopId;
  final int stock;
  final bool isAvailable;
  final double? ratingAvg; // maintained by the recalculateProductRating function
  final int reviewCount;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.imageUrl,
    this.imageData,
    required this.shopName,
    required this.shopId,
    this.stock = 0,
    this.isAvailable = true,
    this.ratingAvg,
    this.reviewCount = 0,
  });

  /// Rating shown on product cards when the product has reviews.
  bool get hasReviews => reviewCount > 0 && ratingAvg != null;

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? 'Unknown Product',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      category: data['category'] ?? 'Other',
      imageUrl: data['imageUrl'] ?? '',
      imageData: data['imageData'],
      shopName: data['shopName'] ?? 'Unknown Shop',
      shopId: data['vendorId'] ?? '',
      stock: data['stock'] ?? 0,
      isAvailable: data['isAvailable'] ?? true,
      ratingAvg: (data['ratingAvg'] is num) ? (data['ratingAvg'] as num).toDouble() : null,
      reviewCount: (data['reviewCount'] ?? 0) is num ? (data['reviewCount'] as num).toInt() : 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'imageUrl': imageUrl,
      'imageData': imageData,
      'shopName': shopName,
      'vendorId': shopId,
      'stock': stock,
      'isAvailable': isAvailable,
    };
  }

  /// Vendor identifier. Firestore stores products with a `vendorId` field,
  /// which is mapped to [shopId] when reading (see [Product.fromFirestore]).
  String get vendorId => shopId;
}