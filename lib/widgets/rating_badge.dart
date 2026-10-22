import 'package:flutter/material.dart';

/// Compact "⭐ 4.5 (12)" badge used on product cards. Hides itself
/// completely for products with no reviews.
class RatingBadge extends StatelessWidget {
  final double? ratingAvg;
  final int reviewCount;

  const RatingBadge({super.key, required this.ratingAvg, required this.reviewCount});

  @override
  Widget build(BuildContext context) {
    if (ratingAvg == null || reviewCount <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star, size: 12, color: Colors.amber),
        const SizedBox(width: 2),
        Text(
          '${ratingAvg!.toStringAsFixed(1)} ($reviewCount)',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}
