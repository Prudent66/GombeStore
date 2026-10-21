import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubmitComplaintScreen extends StatefulWidget {
  const SubmitComplaintScreen({super.key});

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _orderIdController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Order Issue',
    'Product Quality',
    'Delivery Delay',
    'Refund Request',
    'Payment Problem',
    'Other',
  ];

  String _selectedCategory = 'Other';
  bool _orderRelated = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _orderIdController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('complaints').add({
        'userId': user.uid,
        'userName': user.displayName ?? (user.email?.split('@').first ?? 'Anonymous'),
        'userEmail': user.email,
        'category': _selectedCategory,
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        'orderId': _orderRelated ? _orderIdController.text.trim() : null,
        'isResolved': false,
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 10));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complaint submitted successfully!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit complaint: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Complaint')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How can we help?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
              const SizedBox(height: 16),

              // Category selector
              const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final selected = _selectedCategory == cat;
                  return FilterChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (val) => setState(() => _selectedCategory = cat),
                    selectedColor: const Color(0xFF2E7D32).withOpacity(0.25),
                    checkmarkColor: const Color(0xFF2E7D32),
                    labelStyle: TextStyle(
                      color: selected ? const Color(0xFF2E7D32) : Colors.black,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Order related toggle
              SwitchListTile(
                title: const Text('Is this related to a specific order?'),
                value: _orderRelated,
                onChanged: (val) => setState(() => _orderRelated = val),
              ),
              if (_orderRelated) ...[
                TextFormField(
                  controller: _orderIdController,
                  decoration: const InputDecoration(
                    labelText: 'Order ID',
                    hintText: 'Paste the order ID from your order details',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.receipt_long),
                  ),
                  validator: (val) => val!.isEmpty ? 'Please enter the order ID' : null,
                ),
                const SizedBox(height: 16),
              ],

              // Subject
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'Brief summary of your issue',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.subject),
                ),
                maxLines: 1,
                validator: (val) => val!.isEmpty ? 'Please enter a subject' : null,
              ),
              const SizedBox(height: 16),

              // Message
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe what happened and what we can do to fix it',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 6,
                validator: (val) => val!.isEmpty ? 'Please describe your issue' : null,
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('Submit Complaint', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
