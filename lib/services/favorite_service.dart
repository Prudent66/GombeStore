import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/favorite.dart';
import '../models/product.dart';

class FavoriteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool get _signedIn => FirebaseAuth.instance.currentUser != null;
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<Favorite>> watchFavorites() {
    if (_userId == null) return const Stream<List<Favorite>>.empty();
    return _firestore
        .collection('favorites')
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Favorite.fromFirestore(doc)).toList());
  }

  Stream<bool> watchIsFavorite(String productId) {
    if (_userId == null) return Stream.value(false);
    return _firestore
        .collection('favorites')
        .where('userId', isEqualTo: _userId)
        .where('productId', isEqualTo: productId)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  Future<void> addFavorite(Product product) async {
    if (_userId == null) return;
    await _firestore.collection('favorites').add({
      'userId': _userId,
      'productId': product.id,
      'productName': product.name,
      'price': product.price,
      'imageUrl': product.imageUrl,
      'imageData': product.imageData,
      'shopName': product.shopName,
      'category': product.category,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeFavorite(String productId) async {
    if (_userId == null) return;
    final favorites = await _firestore
        .collection('favorites')
        .where('userId', isEqualTo: _userId)
        .where('productId', isEqualTo: productId)
        .get();
    final batch = _firestore.batch();
    for (final doc in favorites.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
