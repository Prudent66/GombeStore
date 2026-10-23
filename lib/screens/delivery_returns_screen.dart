import 'package:flutter/material.dart';

/// Static Delivery & Returns policy page, opened from the product detail
/// delivery card. Update the text here as the platform's policies evolve.
class DeliveryReturnsScreen extends StatelessWidget {
  const DeliveryReturnsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery & Returns'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _PolicySection(
            title: '🚚 Delivery',
            items: [
              'Orders are delivered within 2 – 4 days anywhere in Gombe State.',
              'Cost of delivery depends on your Local Government Area and is shown before you place an order.',
              'A rider or store agent may call you on the number you provide — please keep your phone reachable.',
              'Multi-store carts are packed separately; each shop delivers its own items.',
            ],
          ),
          _PolicySection(
            title: '📦 Returns',
            items: [
              'You may return a product within 3 days of delivery if it is damaged, wrong, or not as described.',
              'Perishables (e.g. fresh food) cannot be returned once accepted, but will be refunded if spoiled on arrival.',
              'Returned items should be unused and in their original packaging where possible.',
            ],
          ),
          _PolicySection(
            title: '💵 Refunds',
            items: [
              'Approved refunds go back to the payment method you used, usually within 5 working days.',
              'For cash-on-delivery orders, refunds are arranged directly with the store.',
              'Delivery fees are refunded only when the return is not the customer\'s fault.',
            ],
          ),
          _PolicySection(
            title: '🛡 Security & Privacy',
            items: [
              'Payments are processed by Paystack — we never see or store your card details.',
              'Your address and phone are shared with the selling store only for delivery of your order.',
              'You can request deletion of your account data at any time via the Account tab.',
            ],
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final List<String> items;

  const _PolicySection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $t', style: const TextStyle(fontSize: 14, height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}
