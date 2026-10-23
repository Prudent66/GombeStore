import 'package:flutter/material.dart';
import '../models/product.dart';

class CartService extends ChangeNotifier {
  final List<Product> _items = [];
  final Map<String, int> _quantities = {}; // Product ID -> Quantity
  final Map<String, double> _remoteFees = {}; // Fees set by admin in Firestore
  final Map<String, String> _variantOf = {}; // Product ID -> selected variant name
  final Map<String, double> _unitPriceOf = {}; // Product ID -> effective unit price

  List<Product> get items => _items;
  Map<String, int> get quantities => _quantities;

  /// Selected variant per product, for checkout/order records.
  Map<String, String> get variantNames => Map.unmodifiable(_variantOf);

  /// Effective unit price per product (variant price when one is selected).
  Map<String, double> get unitPrices => Map.unmodifiable(_unitPriceOf);

  /// The variant chosen for a cart line, or null for plain products.
  String? variantNameOf(String productId) => _variantOf[productId];

  /// Price actually charged per unit: the selected variant's price when it
  /// has one, otherwise the product's main price.
  double unitPriceOf(Product product) {
    final saved = _unitPriceOf[product.id];
    if (saved != null) return saved;
    return product.priceFor(_variantOf[product.id]);
  }

  int get itemCount => _items.length;

  /// Called when fees configured by the admin (settings/shipping) load,
  /// so checkout uses live values instead of the hardcoded defaults.
  void setRemoteFees(Map<String, dynamic> fees) {
    _remoteFees.clear();
    fees.forEach((lga, value) {
      final fee = double.tryParse(value.toString());
      if (fee != null) _remoteFees[lga] = fee;
    });
    notifyListeners();
  }

  // Get the total price of all items (Product Total)
  double get productTotal {
    double total = 0;
    for (var product in _items) {
      total += unitPriceOf(product) * (_quantities[product.id] ?? 1);
    }
    return total;
  }

  // Get the shipping fee based on selected location
  double getShippingFee(String location) {
    // Admin-configured fees from Firestore take priority
    if (_remoteFees.containsKey(location)) {
      return _remoteFees[location]!;
    }
    // Fallback defaults (used before settings load or if never configured)
    final Map<String, double> shippingFees = {
      'Gombe Town': 1000,
      'Kumo': 1500,
      'Bajoga': 2000,
      'Kaltungo': 2000,
      'Nafada': 2500,
      'Yamaltu': 1500,
      'Billiri': 2000,
    };
    return shippingFees[location] ?? 1000.0;
  }

  // Get the final total (Product Total + Shipping Fee)
  double getGrandTotal(String location) {
    return productTotal + getShippingFee(location);
  }

  // Add item to cart (quantity defaults to 1; [variantName] selects an option)
  void addItem(Product product, {int quantity = 1, String? variantName}) {
    final qty = quantity < 1 ? 1 : quantity;
    if (!_items.contains(product)) {
      _items.add(product);
      _quantities[product.id] = qty;
    } else {
      _quantities[product.id] = (_quantities[product.id] ?? 1) + qty;
    }
    // Record the selected variant + its price (adding again from a card
    // without options keeps the existing line's variant).
    if (variantName != null && variantName.isNotEmpty) {
      _variantOf[product.id] = variantName;
      _unitPriceOf[product.id] = product.priceFor(variantName);
    } else {
      _unitPriceOf[product.id] = product.priceFor(_variantOf[product.id]);
    }
    // Never allow more than the available stock.
    if (product.stock > 0 && _quantities[product.id]! > product.stock) {
      _quantities[product.id] = product.stock;
    }
    notifyListeners(); // Tells the UI to update
  }

  /// Increase/decrease a cart line by [delta], clamped between 1 and stock.
  void changeQuantity(Product product, int delta) {
    if (!_items.contains(product)) return;
    final next = (_quantities[product.id] ?? 1) + delta;
    if (next <= 0) {
      removeItem(product);
      return;
    }
    var clamped = next;
    if (product.stock > 0 && clamped > product.stock) clamped = product.stock;
    _quantities[product.id] = clamped;
    notifyListeners();
  }

  // Remove item from cart
  void removeItem(Product product) {
    _items.remove(product);
    _quantities.remove(product.id);
    _variantOf.remove(product.id);
    _unitPriceOf.remove(product.id);
    notifyListeners();
  }

  // Clear cart after successful order
  void clearCart() {
    _items.clear();
    _quantities.clear();
    _variantOf.clear();
    _unitPriceOf.clear();
    notifyListeners();
  }
}