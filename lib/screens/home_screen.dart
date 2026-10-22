import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
import '../widgets/rating_badge.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';
import 'my_orders_screen.dart';
import 'login_screen.dart';
import 'submit_complaint_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';

  final List<String> _categories = [
    'All', 'Food & Grocery', 'Electronics', 'Fashion', 'Home & Living', 'Health'
  ];

  // Phase 16 (quick wins): paginated product feed — the newest 30 products
  // load first and "Load more products" appends older pages. A single
  // orderBy avoids needing a composite index.
  static const int _pageSize = 30;
  List<Product> _pageProducts = [];
  DocumentSnapshot<Object?>? _lastDoc;
  bool _hasMore = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadPage(first: true);
  }

  Future<void> _loadPage({bool first = false}) async {
    if (_loadingMore || (!first && !_hasMore)) return;
    setState(() => _loadingMore = true);
    try {
      Query query = FirebaseFirestore.instance
          .collection('products')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);
      if (!first && _lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }
      final snapshot = await query.get();
      final page = snapshot.docs.map((d) => Product.fromFirestore(d)).toList();
      setState(() {
        if (first) _pageProducts = page;
        else _pageProducts.addAll(page);
        if (snapshot.docs.isNotEmpty) _lastDoc = snapshot.docs.last;
        _hasMore = snapshot.docs.length == _pageSize;
      });
    } catch (_) {
      // Offline: keep whatever we already have; pull-to-refresh retries.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GombeStore'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'My Orders',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MyOrdersScreen()));
            },
          ),
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
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await AuthService().signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } else if (value == 'support') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubmitComplaintScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'support',
                child: Row(
                  children: [
                    const Icon(Icons.help_outline, size: 20),
                    const SizedBox(width: 8),
                    const Text('Help & Support'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    const SizedBox(width: 8),
                    const Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
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
          // Category Filter Chips
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
                      setState(() => _selectedCategory = selected ? category : 'All');
                    },
                    selectedColor: const Color(0xFF2E7D32).withOpacity(0.2),
                    checkmarkColor: const Color(0xFF2E7D32),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Paginated products feed (Phase 16 quick wins)
          Expanded(child: _buildProductArea()),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    final user = FirebaseAuth.instance.currentUser;

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
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: product.imageData != null && product.imageData!.isNotEmpty
                        ? Image.memory(
                            base64Decode(product.imageData!),
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : CachedNetworkImage(
                            imageUrl: product.imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorWidget: (context, error, stackTrace) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported, color: Colors.grey),
                            ),
                          ),
                  ),
                  if (product.stock <= 0)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'SOLD OUT',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  if (user != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('favorites')
                            .where('userId', isEqualTo: user.uid)
                            .where('productId', isEqualTo: product.id)
                            .limit(1)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final isFavorite = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                          return GestureDetector(
                            onTap: () async {
                              if (isFavorite) {
                                for (final doc in snapshot.data!.docs) {
                                  await doc.reference.delete();
                                }
                              } else {
                                await FirebaseFirestore.instance.collection('favorites').add({
                                  'userId': user.uid,
                                  'productId': product.id,
                                  'productName': product.name,
                                  'price': product.price,
                                  'imageUrl': product.imageUrl,
                                  'imageData': product.imageData,
                                  'shopName': product.shopName,
                                  'category': product.category,
                                  'vendorId': product.vendorId,
                                  'description': product.description,
                                  'stock': product.stock,
                                  'createdAt': FieldValue.serverTimestamp(),
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: isFavorite ? Colors.red : Colors.grey[600],
                                size: 18,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                  if (product.hasReviews) ...[
                    const SizedBox(height: 2),
                    RatingBadge(ratingAvg: product.ratingAvg, reviewCount: product.reviewCount),
                  ],
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

  /// Paginated feed UI: current page set + a load-more tile at the end.
  Widget _buildProductArea() {
    final filtered = _pageProducts
        .where((p) => p.isAvailable)
        .where((p) =>
            _searchQuery.isEmpty ||
            p.name.toLowerCase().contains(_searchQuery) ||
            p.shopName.toLowerCase().contains(_searchQuery))
        .where((p) =>
            _selectedCategory == 'All' || p.category == _selectedCategory)
        .toList();

    if (filtered.isEmpty && !_loadingMore && !_hasMore && _pageProducts.isNotEmpty) {
      return const Center(child: Text('No products match your search.'));
    }

    if (!_loadingMore && _pageProducts.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadPage(first: true),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Center(child: Text('No products to show', style: TextStyle(fontSize: 16))),
            const Center(
              child: Text(
                'Check your internet, then pull down or tap here to retry.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => _loadPage(first: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPage(first: true),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: filtered.length + 1,
        itemBuilder: (context, index) {
          if (index == filtered.length) {
            return _buildLoadMoreTile();
          }
          return _buildProductCard(context, filtered[index]);
        },
      ),
    );
  }

  Widget _buildLoadMoreTile() {
    if (!_hasMore) {
      return const Center(
        child: Text('You have seen it all 🎉', style: TextStyle(fontSize: 12, color: Colors.grey)),
      );
    }
    return Center(
      child: _loadingMore
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                height: 26,
                width: 26,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : OutlinedButton(
              onPressed: () => _loadPage(),
              child: const Text('Load more products'),
            ),
    );
  }
}