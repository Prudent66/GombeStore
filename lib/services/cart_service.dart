import 'package:flutter/material.dart';
import '../models/product.dart';

class CartService extends ChangeNotifier {
  final List<Product> _items = [];
  final Map<String, int> _quantities = {}; // Product ID -> Quantity
  final Map<String, double> _remoteFees = {}; // Fees set by admin in Firestore

  List<Product> get items => _items;
  Map<String, int> get quantities => _quantities;

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
      total += product.price * (_quantities[product.id] ?? 1);
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

  // Add item to cart
  void addItem(Product product) {
    if (!_items.contains(product)) {
      _items.add(product);
      _quantities[product.id] = 1;
    } else {
      _quantities[product.id] = (_quantities[product.id] ?? 1) + 1;
    }
    notifyListeners(); // Tells the UI to update
  }

  // Remove item from cart
  void removeItem(Product product) {
    _items.remove(product);
    _quantities.remove(product.id);
    notifyListeners();
  }

  // Clear cart after successful order
  void clearCart() {
    _items.clear();
    _quantities.clear();
    notifyListeners();
  }
}