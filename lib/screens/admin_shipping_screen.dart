import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminShippingScreen extends StatefulWidget {
  const AdminShippingScreen({super.key});

  @override
  State<AdminShippingScreen> createState() => _AdminShippingScreenState();
}

class _AdminShippingScreenState extends State<AdminShippingScreen> {
  final List<String> _lgas = [
    'Gombe Town', 'Kumo', 'Bajoga', 'Kaltungo', 'Nafada', 'Yamaltu', 'Billiri'
  ];

  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    for (var lga in _lgas) {
      _controllers[lga] = TextEditingController();
    }
    _loadFees();
  }

  void _loadFees() async {
    // Load current fees from Firestore
    final doc = await FirebaseFirestore.instance.collection('settings').doc('shipping').get();
    if (doc.exists) {
      final data = doc.data()!;
      for (var lga in _lgas) {
        if (data.containsKey(lga)) {
          _controllers[lga]!.text = data[lga].toString();
        }
      }
    } else {
      // Defaults if no config exists yet
      _controllers['Gombe Town']!.text = '1000';
      _controllers['Kumo']!.text = '1500';
      _controllers['Bajoga']!.text = '2000';
      _controllers['Kaltungo']!.text = '2000';
      _controllers['Nafada']!.text = '2500';
      _controllers['Yamaltu']!.text = '1500';
      _controllers['Billiri']!.text = '2000';
    }
    setState(() => _isLoading = false);
  }

  void _saveFees() async {
    setState(() => _isLoading = true);
    Map<String, dynamic> updates = {};
    for (var lga in _lgas) {
      updates[lga] = double.tryParse(_controllers[lga]!.text.trim()) ?? 0.0;
    }
    await FirebaseFirestore.instance.collection('settings').doc('shipping').set(updates);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shipping fees updated!'), backgroundColor: Color(0xFF2E7D32)),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configure Shipping Fees')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Set delivery fee for each LGA:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  ..._lgas.map((lga) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextField(
                      controller: _controllers[lga],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: lga,
                        prefixText: '₦ ',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  )),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveFees,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Save Fees', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}