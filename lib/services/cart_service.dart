import 'package:flutter/material.dart';
import '../models/product.dart';

class CartService extends ChangeNotifier {
  final List<Product> _items = [];
  final Map<String, int> _quantities = {}; // Product ID -> Quantity

  List<Product> get items => _items;
  Map<String, int> get quantities => _quantities;

  int get itemCount => _items.length;

  // Get the total price of all items (Product Total)
  double get productTotal {
    double total = 0;
    for (var product in _items) {
      total += product.price * (_quantities[product.id] ?? 1);
    }
    return total;
  }

  // Get the shipping fee based on selected location (Default: Gombe Town = 1000)
  double getShippingFee(String location) {
    // In Phase 5, we will fetch these from Firebase. For now, we hardcode the initial locations.
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