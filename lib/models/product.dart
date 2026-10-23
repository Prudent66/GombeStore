import 'package:cloud_firestore/cloud_firestore.dart';

/// A purchasable option of a product (e.g. "8 Port USB", "Red / XL").
/// Price is optional: when null, the customer pays the product's main price.
class Variant {
  final String name;
  final double? price;

  Variant({required this.name, this.price});

  bool get hasPrice => price != null;

  Map<String, dynamic> toMap() => {
        'name': name,
        if (price != null) 'price': price,
      };
}

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
  final int soldCount; // real sales, incremented when an order is placed
  final List<Variant> variants; // purchasable options (e.g. colors/sizes)
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
    this.soldCount = 0,
    this.variants = const [],
    this.ratingAvg,
    this.reviewCount = 0,
  });

  /// Variant options never override the main price unless they carry one.
  double priceFor(String? variantName) {
    if (variantName == null) return price;
    for (final v in variants) {
      if (v.name == variantName && v.hasPrice) return v.price!;
    }
    return price;
  }

  /// Rating shown on product cards when the product has reviews.
  bool get hasReviews => reviewCount > 0 && ratingAvg != null;

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // Defensive numeric coercion: whether a value comes through as int,
    // double, String ("3500") or null, this must never throw — one dirty
    // document used to blank the entire customer catalog.
    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    int toInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    double? toDoubleOrNull(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return Product(
      id: doc.id,
      name: (data['name'] ?? 'Unknown Product').toString(),
      description: (data['description'] ?? '').toString(),
      price: toDouble(data['price']),
      category: (data['category'] ?? 'Other').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      imageData: (data['imageData'] as String?)?.isEmpty == true ? null : data['imageData'] as String?,
      shopName: (data['shopName'] ?? 'Unknown Shop').toString(),
      shopId: data['vendorId']?.toString() ?? '',
      stock: toInt(data['stock']),
      isAvailable: data['isAvailable'] is bool ? data['isAvailable'] as bool : true,
      soldCount: toInt(data['soldCount']),
      variants: _parseVariants(data['variants']),
      ratingAvg: toDoubleOrNull(data['ratingAvg']),
      reviewCount: toInt(data['reviewCount']),
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

  /// Defensive variant parsing: tolerate missing/malformed entries so no
  /// single bad document can blank the catalog.
  static List<Variant> _parseVariants(dynamic raw) {
    final out = <Variant>[];
    if (raw is! List) return out;
    for (final entry in raw) {
      try {
        if (entry is! Map) continue;
        final name = (entry['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final rawPrice = entry['price'];
        final price = rawPrice == null
            ? null
            : (rawPrice is num ? rawPrice.toDouble() : double.tryParse(rawPrice.toString()));
        out.add(Variant(name: name, price: price));
      } catch (_) {
        // Skip malformed entries.
      }
    }
    return out;
  }
}