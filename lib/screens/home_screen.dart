import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/cart_service.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 1. Mock Data (Fake products for now)
  final List<Product> _allProducts = [
    Product(id: '1', name: 'Fresh Tomatoes (Basket)', description: 'Locally grown fresh tomatoes from Kaltungo.', price: 4500, category: 'Food & Grocery', imageUrl: 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=500', shopName: 'Gombe Fresh Mart', shopId: 's1'),
    Product(id: '2', name: 'Samsung Galaxy A15', description: 'Brand new Samsung A15 with 128GB storage.', price: 185000, category: 'Electronics', imageUrl: 'https://images.unsplash.com/photo-1610945415295-d9bbf067e59c?w=500', shopName: 'Tech Hub Gombe', shopId: 's2'),
    Product(id: '3', name: 'Men\'s Kaftan', description: 'Premium quality Kaftan for special occasions.', price: 12000, category: 'Fashion', imageUrl: 'https://images.unsplash.com/photo-1594938298603-c8148c47e35d?w=500', shopName: 'Zainab Fashion', shopId: 's3'),
    Product(id: '4', name: 'Bag of Rice (50kg)', description: 'Quality local rice, perfect for family meals.', price: 65000, category: 'Food & Grocery', imageUrl: 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=500', shopName: 'Gombe Fresh Mart', shopId: 's1'),
    Product(id: '5', name: 'Wireless Earbuds', description: 'Noise cancelling earbuds with long battery life.', price: 15000, category: 'Electronics', imageUrl: 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=500', shopName: 'Tech Hub Gombe', shopId: 's2'),
    Product(id: '6', name: 'Women\'s Abaya', description: 'Elegant black Abaya with embroidery.', price: 18000, category: 'Fashion', imageUrl: 'https://images.unsplash.com/photo-1596783074918-c84cb06531ca?w=500', shopName: 'Zainab Fashion', shopId: 's3'),
  ];

  List<Product> _filteredProducts = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All', 'Food & Grocery', 'Electronics', 'Fashion', 'Home & Living', 'Health'
  ];

  @override
  void initState() {
    super.initState();
    _filteredProducts = _allProducts; // Show all products initially
  }

  void _filterProducts(String query) {
    setState(() {
      _filteredProducts = _allProducts.where((product) {
        final matchesSearch = product.name.toLowerCase().contains(query.toLowerCase()) ||
                              product.shopName.toLowerCase().contains(query.toLowerCase());
        final matchesCategory = _selectedCategory == 'All' || product.category == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GombeStore'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          // --- NEW CART ICON WITH BADGE ---
          Consumer<CartService>(
            builder: (context, cart, child) => Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
                  },
                ),
                if (cart.itemCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text('${cart.itemCount}', style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
          ),
          // ---------------------------------
        ],
      ),
      body: Column(
        children: [
          // 2. Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterProducts,
              decoration: InputDecoration(
                hintText: 'Search products or stores...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // 3. Category Filter Chips
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = selected ? category : 'All';
                        _filterProducts(_searchController.text);
                      });
                    },
                    selectedColor: const Color(0xFF2E7D32).withOpacity(0.2),
                    checkmarkColor: const Color(0xFF2E7D32),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // 4. Product Grid
          Expanded(
            child: _filteredProducts.isEmpty
                ? const Center(child: Text('No products found.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return _buildProductCard(product);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 5. Product Card Widget
  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  product.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                ),
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.shopName,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₦${product.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
          // 3. Category Filter Chips
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = selected ? category : 'All';
                        _filterProducts(_searchController.text);
                      });
                    },
                    selectedColor: const Color(0xFF2E7D32).withOpacity(0.2),
                    checkmarkColor: const Color(0xFF2E7D32),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // 4. Product Grid
          Expanded(
            child: _filteredProducts.isEmpty
                ? const Center(child: Text('No products found.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return _buildProductCard(product);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 5. Product Card Widget
  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  product.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                ),
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.shopName,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₦${product.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}