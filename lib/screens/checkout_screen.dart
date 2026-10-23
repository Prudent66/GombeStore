import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../services/payment_service.dart';
import 'my_orders_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  // Address Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _areaController = TextEditingController();
  final _streetController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _instructionsController = TextEditingController();

  String _selectedLGA = 'Gombe Town'; // Default
  String _paymentMethod = 'Cash on Delivery'; // or 'Paystack'
  bool _isPlacing = false;

  final List<String> _lgas = [
    'Gombe Town', 'Kumo', 'Bajoga', 'Kaltungo', 'Nafada', 'Yamaltu', 'Billiri'
  ];

  @override
  void initState() {
    super.initState();
    _loadShippingFees();
    _prefillProfile();
  }

  // Load admin-configured shipping fees from settings/shipping
  void _loadShippingFees() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('shipping')
          .get()
          .timeout(const Duration(seconds: 5));
      if (doc.exists && mounted) {
        Provider.of<CartService>(context, listen: false).setRemoteFees(doc.data()!);
      }
    } catch (_) {
      // Offline or not configured: CartService falls back to default fees
    }
  }

  // Pre-fill name and phone from the user's profile
  void _prefillProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 5));
      if (doc.exists && mounted) {
        final data = doc.data()!;
        if ((data['fullName'] ?? '').isNotEmpty) {
          _nameController.text = data['fullName'];
        }
        if ((data['phone'] ?? '').isNotEmpty) {
          _phoneController.text = data['phone'];
        }
      }
    } catch (_) {
      // Offline: user can type details manually
    }
  }

  void _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final cart = Provider.of<CartService>(context, listen: false);
    setState(() => _isPlacing = true);

    final createdOrders = await OrderService().placeOrder(
      items: cart.items,
      quantities: cart.quantities,
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      lga: _selectedLGA,
      city: _cityController.text.trim(),
      area: _areaController.text.trim(),
      street: _streetController.text.trim(),
      landmark: _landmarkController.text.trim(),
      instructions: _instructionsController.text.trim(),
      shippingFee: cart.getShippingFee(_selectedLGA),
      paymentMethod: _paymentMethod,
      variantNames: cart.variantNames,
      unitPrices: cart.unitPrices,
    );

    if (!mounted) return;
    setState(() => _isPlacing = false);

    if (createdOrders == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not place order. Check your internet and try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    cart.clearCart();

    if (_paymentMethod == 'Paystack') {
      await _handlePaystackPayments(createdOrders);
      if (!mounted) return;
    }

    _showOrderPlacedDialog();
  }

  /// Walks the customer through Paystack for each vendor order created.
  /// Paystack checkout opens in the browser; when they come back we ask
  /// the backend to verify and update the order's paymentStatus.
  Future<void> _handlePaystackPayments(List<Map<String, dynamic>> orders) async {
    final payment = PaymentService();

    for (final order in orders) {
      final orderId = order['id'] as String;
      final amount = (order['grandTotal'] as num?)?.toDouble() ?? 0;
      final store = order['storeName'] as String? ?? 'Store';

      final payNow = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.payment, color: Color(0xFF2E7D32), size: 48),
          title: Text('Pay ₦${amount.toStringAsFixed(0)}'),
          content: Text(
            'Pay your $store order by card, bank transfer or USSD.\n'
            'You can also pay later with cash on delivery.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Pay cash on delivery'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Pay now', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (!payNow!) continue;

      String? checkoutUrl;
      try {
        checkoutUrl = await payment.startPayment(orderId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not start card payment. You can pay cash on delivery instead.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        continue;
      }

      await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;

      // Ask whether they finished, then verify with Paystack.
      final done = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Finished paying?'),
          content: Text(
            'If you completed the payment in your browser, tap verify.\n\n'
            'Still deciding? The order stays in My Orders as unpaid — '
            'the vendor accepts cash on delivery.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Later')),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Verify my payment', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (done != true) continue;

      bool paid = false;
      try {
        paid = await payment.verifyPayment(orderId);
      } catch (_) {
        paid = false;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paid
                ? 'Payment confirmed ✅ $store will prepare your order.'
                : 'Payment not confirmed yet — you can verify later in My Orders.',
          ),
          backgroundColor: paid ? const Color(0xFF2E7D32) : Colors.orange,
        ),
      );
    }
  }

  void _showOrderPlacedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 60),
        title: const Text('Order Placed!'),
        content: Text(
          _paymentMethod == 'Paystack'
              ? 'Your order has been sent to the store(s).\n'
                  'Track payments and delivery under My Orders.'
              : 'Your order has been sent to the store(s).\nPay with cash on delivery.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.popUntil(context, (route) => route.isFirst);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
              );
            },
            child: const Text('View My Orders'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _streetController.dispose();
    _landmarkController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Delivery Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
              const SizedBox(height: 10),
              _buildField(_nameController, 'Full Name'),
              _buildField(_phoneController, 'Phone Number', keyboard: TextInputType.phone),

              // LGA Dropdown
              DropdownButtonFormField<String>(
                value: _selectedLGA,
                decoration: const InputDecoration(labelText: 'LGA / Town', border: OutlineInputBorder()),
                items: _lgas.map((lga) => DropdownMenuItem(value: lga, child: Text(lga))).toList(),
                onChanged: (val) => setState(() => _selectedLGA = val!),
              ),
              const SizedBox(height: 10),
              _buildField(_cityController, 'City / Town'),
              _buildField(_areaController, 'Area'),
              _buildField(_streetController, 'Street / Address'),
              _buildField(_landmarkController, 'Landmark (Optional)', required: false),
              _buildField(_instructionsController, 'Delivery Instructions (Optional)', required: false, maxLines: 2),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),

              // Order Summary
              const Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
              const SizedBox(height: 10),
              _summaryRow('Product Total', '₦${cart.productTotal.toStringAsFixed(0)}'),
              _summaryRow('Shipping Fee', '₦${cart.getShippingFee(_selectedLGA).toStringAsFixed(0)}'),
              const Divider(),
              _summaryRow('Grand Total', '₦${cart.getGrandTotal(_selectedLGA).toStringAsFixed(0)}', isBold: true),
              const SizedBox(height: 6),
              Text('Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              RadioListTile<String>(
                value: 'Cash on Delivery',
                groupValue: _paymentMethod,
                contentPadding: EdgeInsets.zero,
                dense: true,
                onChanged: (val) => setState(() => _paymentMethod = val!),
                title: const Text('Cash on Delivery'),
                subtitle: const Text('Pay the store when your order arrives', style: TextStyle(fontSize: 12)),
              ),
              RadioListTile<String>(
                value: 'Paystack',
                groupValue: _paymentMethod,
                contentPadding: EdgeInsets.zero,
                dense: true,
                secondary: const Icon(Icons.credit_card, color: Color(0xFF2E7D32)),
                onChanged: (val) => setState(() => _paymentMethod = val!),
                title: const Text('Pay with Paystack'),
                subtitle: const Text('Card, bank transfer or USSD', style: TextStyle(fontSize: 12)),
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPlacing ? null : _placeOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isPlacing
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('Place Order', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, {TextInputType keyboard = TextInputType.text, bool required = true, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: required ? (val) => val!.isEmpty ? 'Required' : null : null,
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? const Color(0xFF2E7D32) : Colors.black)),
        ],
      ),
    );
  }
}
