import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cart_service.dart';

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

  final List<String> _lgas = [
    'Gombe Town', 'Kumo', 'Bajoga', 'Kaltungo', 'Nafada', 'Yamaltu', 'Billiri'
  ];

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

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      // Here we will eventually send the order to Firestore
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Order Placed! (Demo)'), backgroundColor: Color(0xFF2E7D32)),
                      );
                      cart.clearCart();
                      Navigator.popUntil(context, (route) => route.isFirst);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Place Order', style: TextStyle(fontSize: 18)),
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