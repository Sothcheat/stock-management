import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/domain/product.dart';

class AddEditProductScreen extends ConsumerStatefulWidget {
  final Product? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  ConsumerState<AddEditProductScreen> createState() =>
      _AddEditProductScreenState();
}

class _AddEditProductScreenState extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _costPriceController;
  late TextEditingController _shipmentCostController;
  late TextEditingController _stockController; // For total stock if no variants
  late TextEditingController
  _categoryController; // Simple text for now, should be dropdown

  File? _imageFile;
  String? _currentImageUrl;
  bool _isLoading = false;

  // Variants
  List<ProductVariant> _variants = [];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name);
    _descController = TextEditingController(text: p?.description);
    _priceController = TextEditingController(text: p?.price.toString());
    _costPriceController = TextEditingController(text: p?.costPrice.toString());
    _shipmentCostController = TextEditingController(
      text: p?.shipmentCost?.toString(),
    );
    _stockController = TextEditingController(text: p?.totalStock.toString());
    _categoryController = TextEditingController(text: p?.categoryId);
    _currentImageUrl = p?.imagePath;
    if (p != null) {
      _variants = List.from(p.variants);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _shipmentCostController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final double price = double.tryParse(_priceController.text) ?? 0;
      final double costPrice = double.tryParse(_costPriceController.text) ?? 0;
      final double shipmentCost =
          double.tryParse(_shipmentCostController.text) ?? 0;

      // Calculate total stock from variants if exist, else use controller
      int totalStock = 0;
      if (_variants.isNotEmpty) {
        totalStock = _variants.fold(0, (sum, v) => sum + v.stockQuantity);
      } else {
        totalStock = int.tryParse(_stockController.text) ?? 0;
      }

      final product = Product(
        id:
            widget.product?.id ??
            '', // ID handled by repo for new, kept for update
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        categoryId: _categoryController.text.trim(), // TODO: use ID
        price: price,
        costPrice: costPrice,
        shipmentCost: shipmentCost > 0 ? shipmentCost : null,
        variants: _variants,
        totalStock: totalStock,
        imagePath: _currentImageUrl, // Repo handles update
        createdAt: widget.product?.createdAt ?? DateTime.now(),
      );

      final repo = ref.read(inventoryRepositoryProvider);
      if (widget.product == null) {
        await repo.addProduct(product, _imageFile);
      } else {
        await repo.updateProduct(product, _imageFile);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product Saved Successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addVariant() {
    showDialog(
      context: context,
      builder: (context) {
        String name = '';
        String qty = '0';
        return AlertDialog(
          title: const Text("Add Variant"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Variant Name (e.g. Red-XL)',
                ),
                onChanged: (v) => name = v,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
                onChanged: (v) => qty = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (name.isNotEmpty) {
                  setState(() {
                    _variants.add(
                      ProductVariant(
                        id: const Uuid().v4(),
                        name: name,
                        stockQuantity: int.tryParse(qty) ?? 0,
                      ),
                    );
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add Product' : 'Edit Product'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Picker
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                      image: _imageFile != null
                          ? DecorationImage(
                              image: FileImage(_imageFile!),
                              fit: BoxFit.cover,
                            )
                          : (_currentImageUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(_currentImageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null),
                    ),
                    child: _imageFile == null && _currentImageUrl == null
                        ? const Icon(
                            Icons.add_a_photo,
                            size: 40,
                            color: Colors.grey,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Basic Info
              Text(
                "Basic Information",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Product Name',
                  suffixIcon: ValueListenableBuilder(
                    valueListenable: _nameController,
                    builder: (context, value, child) {
                      return value.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () => _nameController.clear(),
                            );
                    },
                  ),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  suffixIcon: ValueListenableBuilder(
                    valueListenable: _descController,
                    builder: (context, value, child) {
                      return value.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () => _descController.clear(),
                            );
                    },
                  ),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: 'Category',
                  suffixIcon: ValueListenableBuilder(
                    valueListenable: _categoryController,
                    builder: (context, value, child) {
                      return value.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () => _categoryController.clear(),
                            );
                    },
                  ),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Pricing
              Text(
                "Pricing",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Selling Price',
                        prefixText: '\$ ',
                        suffixIcon: ValueListenableBuilder(
                          valueListenable: _priceController,
                          builder: (context, value, child) {
                            return value.text.isEmpty
                                ? const SizedBox.shrink()
                                : IconButton(
                                    icon: Icon(Icons.clear),
                                    onPressed: () => _priceController.clear(),
                                  );
                          },
                        ),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costPriceController,
                      decoration: InputDecoration(
                        labelText: 'Cost Price',
                        prefixText: '\$ ',
                        suffixIcon: ValueListenableBuilder(
                          valueListenable: _costPriceController,
                          builder: (context, value, child) {
                            return value.text.isEmpty
                                ? const SizedBox.shrink()
                                : IconButton(
                                    icon: Icon(Icons.clear),
                                    onPressed: () =>
                                        _costPriceController.clear(),
                                  );
                          },
                        ),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _shipmentCostController,
                decoration: const InputDecoration(
                  labelText: 'Shipment Cost (Optional)',
                  border: OutlineInputBorder(),
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),

              // Stock & Variants
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Stock & Variants",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addVariant,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Variant"),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_variants.isEmpty)
                TextFormField(
                  controller: _stockController,
                  decoration: const InputDecoration(
                    labelText: 'Total Stock',
                    border: OutlineInputBorder(),
                    helperText: 'Enter stock if no variants',
                  ),
                  keyboardType: TextInputType.number,
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _variants.length,
                  itemBuilder: (context, index) {
                    final v = _variants[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(v.name),
                        trailing: Text('Qty: ${v.stockQuantity}'),
                        onTap: () {
                          // Simple delete for now
                          setState(() {
                            _variants.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                ),

              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _isLoading ? null : _saveProduct,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Product"),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
