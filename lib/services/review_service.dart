import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Writes customer reviews into products/{productId}/reviews/{uid}.
/// One review per signed-in user per product (rewriting updates it).
/// The average/count on the product document are recomputed by the
/// `recalculateProductRating` Cloud Function.
class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> leaveReview({
    required String productId,
    required String productName,
    required double rating,
    required String comment,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in to leave a review');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userName =
        (userDoc.data()?['fullName'] as String?)?.isNotEmpty == true
            ? userDoc.data()!['fullName'] as String
            : user.displayName ?? 'Customer';

    await _firestore
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .doc(user.uid)
        .set({
      'userId': user.uid,
      'userName': userName,
      'rating': rating.round(),
      'comment': comment.trim(),
      'productName': productName,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Loads the signed-in user's existing review (to prefill the editor).
  Future<Map<String, dynamic>?> myReview(String productId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await _firestore
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .doc(user.uid)
        .get();
    return doc.exists ? doc.data() : null;
  }
}

/// Star entry + comment dialog used from the product detail screen.
Future<void> showReviewDialog(
  BuildContext context, {
  required String productId,
  required String productName,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      bool loading = true;
      double stars = 5;
      final controller = TextEditingController();
      final reviewService = ReviewService();

      return FutureBuilder<Map<String, dynamic>?>(
        future: reviewService.myReview(productId),
        builder: (context, snapshot) {
          if (loading) {
            final existing = snapshot.data;
            if (snapshot.connectionState != ConnectionState.waiting &&
                existing != null) {
              loading = false;
              stars = ((existing['rating'] as num?) ?? 5).toDouble();
              controller.text = (existing['comment'] ?? '') as String;
            }
          }

          return StatefulBuilder(
            builder: (context, setSheetState) => Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review "$productName"',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        iconSize: 34,
                        onPressed: () => setSheetState(() => stars = index + 1.0),
                        icon: Icon(
                          index < stars ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                      );
                    }),
                  ),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      labelText: 'How was the product?',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: snapshot.connectionState == ConnectionState.waiting
                          ? null
                          : () async {
                              final navigator = Navigator.of(sheetContext);
                              try {
                                await reviewService.leaveReview(
                                  productId: productId,
                                  productName: productName,
                                  rating: stars,
                                  comment: controller.text,
                                );
                                navigator.pop(true);
                                // ignore: avoid_catches_without_on_clauses
                              } catch (e) {
                                navigator.pop(false);
                              }
                            },
                      child: const Text('Submit Review'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
