import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../services/ai_service.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  /// Variant options the vendor can attach (e.g. "8 Port USB", ₦4500).
  final List<TextEditingController> _variantNameControllers = [];
  final List<TextEditingController> _variantPriceControllers = [];

  String _selectedCategory = 'Food & Grocery';
  bool _isLoading = false;
  File? _pickedImage;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();
  final AiService _ai = AiService();
  bool _aiLoading = false;

  final List<String> _categories = [
    'Food & Grocery', 'Electronics', 'Fashion', 'Home & Living',
    'Health', 'Agriculture', 'Clothing', 'Beauty'
  ];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(source: source);
      if (picked == null) return;

      // Read the file
      final File file = File(picked.path);
      final bytes = await file.readAsBytes();

      // Compress the image to ~150KB by resizing to 600px max
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;

      // Resize to max width 600 (keeps quality decent, file small)
      final resized = img.copyResize(
        decoded,
        width: decoded.width > 600 ? 600 : decoded.width,
      );

      // Encode to JPEG with quality 60
      final compressed = img.encodeJpg(resized, quality: 60);

      setState(() {
        _pickedImage = file;
        _imageBytes = compressed;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF2E7D32)),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF2E7D32)),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Phase 21: let Gemini write the description from the product name
  /// (vendor can always edit the result before saving).
  Future<void> _generateDescription() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type the product name first'), backgroundColor: Colors.red),
      );
      return;
    }
    final replacing = _descriptionController.text.trim().isNotEmpty;
    if (replacing) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Replace description?'),
          content: const Text('Generate an AI description and replace the text you already wrote?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace', style: TextStyle(color: Color(0xFF2E7D32))),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _aiLoading = true);
    try {
      final text = await _ai.generateDescription(
        name: name,
        category: _selectedCategory,
        shopName: 'your store',
      );
      if (!mounted) return;
      if (text == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI not configured yet — add your Gemini key to Firestore settings/ai (field geminiKey).'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      setState(() => _descriptionController.text = text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Description generated — edit it as you like'), backgroundColor: Color(0xFF2E7D32)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a product image'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final shopName = userDoc.data()?['storeName'] ?? 'My Shop';

      // Phase 16b: try Firebase Storage first (small docs, cached URLs).
      // If Storage is unavailable (e.g. the project is on the free Spark
      // plan, which can't create buckets), fall back to embedding the
      // compressed base64 image in Firestore like the legacy products.
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      String imageUrl = '';
      String imageData = '';

      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('products/${user.uid}/$timestamp.jpg');
        final uploadSnapshot = await storageRef.putData(
          _imageBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        imageUrl = await uploadSnapshot.ref.getDownloadURL();
      } catch (storageError) {
        // Free plan / offline / rules denial -> base64 fallback.
        final kb = _imageBytes!.lengthInBytes / 1024;
        if (kb > 900) {
          throw 'Photo is too large to save right now (${kb.toStringAsFixed(0)} KB). '
              'Try a smaller photo and add the product again.';
        }
        imageData = base64Encode(_imageBytes!);
      }

      final productRef = await FirebaseFirestore.instance.collection('products').add({
        'vendorId': user.uid,
        'shopName': shopName,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'category': _selectedCategory,
        'imageUrl': imageUrl, // Firebase Storage URL (empty if fallback)
        'imageData': imageData, // compressed base64 (empty if Storage used)
        'stock': int.parse(_stockController.text.trim()),
        'isAvailable': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Attach variant options directly to the created doc (never blocks).
      try {
        final variants = <Map<String, dynamic>>[];
        for (var i = 0; i < _variantNameControllers.length; i++) {
          final name = _variantNameControllers[i].text.trim();
          if (name.isEmpty) continue;
          final rawPrice = _variantPriceControllers[i].text.trim();
          final price = rawPrice.isEmpty ? null : double.tryParse(rawPrice);
          variants.add({'name': name, if (price != null) 'price': price});
        }
        if (variants.isNotEmpty) {
          await productRef.update({'variants': variants});
        }
      } catch (_) {
        // Non-critical: the product saved fine, options can be added later.
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product Added Successfully!'), backgroundColor: Color(0xFF2E7D32)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Variant options editor: dynamic rows of (option name, price).
  /// Price is optional — an empty price means "same as the main price".
  Widget _buildVariantEditor() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[400]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Options (variants)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          const Text(
            'Optional — e.g. "4 Port USB", "Red", "XL". Leave price blank to use the main price.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _variantNameControllers.length; i++) ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _variantNameControllers[i],
                    decoration: const InputDecoration(
                      labelText: 'Option name',
                      hintText: 'e.g. 8 Port USB',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _variantPriceControllers[i],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Price (₦)',
                      hintText: 'main price',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() {
                    _variantNameControllers[i].dispose();
                    _variantPriceControllers[i].dispose();
                    _variantNameControllers.removeAt(i);
                    _variantPriceControllers.removeAt(i);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          TextButton.icon(
            onPressed: () => setState(() {
              _variantNameControllers.add(TextEditingController());
              _variantPriceControllers.add(TextEditingController());
            }),
            icon: const Icon(Icons.add),
            label: const Text('Add option'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _showImageSourceDialog,
                child: Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2E7D32), width: 2),
                  ),
                  child: _pickedImage == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 50, color: Color(0xFF2E7D32)),
                            SizedBox(height: 8),
                            Text('Tap to add product image', style: TextStyle(color: Color(0xFF2E7D32))),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(_pickedImage!, fit: BoxFit.cover, width: double.infinity),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _aiLoading ? null : _generateDescription,
                  icon: _aiLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_aiLoading ? 'Generating…' : 'Generate with AI'),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price (₦)', border: OutlineInputBorder(), prefixText: '₦ '),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock Quantity', border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),
              const SizedBox(height: 24),
              // Variant options editor (e.g. colors / sizes / capacities)
              _buildVariantEditor(),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Product', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}