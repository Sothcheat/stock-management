import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:uuid/uuid.dart';

import '../../../../design_system.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/domain/category.dart';
import '../../../../core/utils/logger.dart';
import '../../inventory/data/providers/category_provider.dart';
import 'add_variant_dialog.dart';

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
  late TextEditingController _stockController;
  late TextEditingController _lowStockController;
  late TextEditingController _categoryController;

  // Discount
  late ValueNotifier<bool> _discountEnabled;
  late ValueNotifier<DiscountType> _discountType;
  late TextEditingController _discountController;

  File? _imageFile;
  String? _currentImageUrl;
  bool _isLoading = false;

  // Logic to persist initial category if not fully public
  String? _initialCategoryId;

  // Temporary storage for newly created category name (for display before stream updates)
  String? _tempNewCategoryName;

  // Variants
  List<ProductVariant> _variants = [];

  // Dropdown Key to force rebuild on cancel
  int _dropdownKey = 0;

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
    _lowStockController = TextEditingController(
      text: p?.lowStockThreshold.toString() ?? '5',
    );
    _categoryController = TextEditingController(text: p?.categoryId);
    _initialCategoryId = p?.categoryId;

    // Discount Init
    _discountController = TextEditingController(
      text: (p?.discountValue ?? 0) > 0 ? p!.discountValue.toString() : '',
    );

    _discountEnabled = ValueNotifier(false);
    _discountType = ValueNotifier(DiscountType.percentage);

    if (p != null && (p.discountValue ?? 0) > 0) {
      _discountEnabled.value = true;
      _discountType.value = p.discountType;
    }

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
    _lowStockController.dispose();
    _categoryController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final cropped = await ImageCropper()
          .cropImage(
            sourcePath: picked.path,
            uiSettings: [
              AndroidUiSettings(
                toolbarTitle: 'Crop to Square',
                toolbarColor: SoftColors.brandPrimary,
                toolbarWidgetColor: Colors.white,
                initAspectRatio: CropAspectRatioPreset.square,
                lockAspectRatio: true,
                hideBottomControls: true, // Force user to focus on crop
              ),
              IOSUiSettings(
                title: 'Crop to Square',
                aspectRatioLockEnabled: true,
                resetAspectRatioEnabled: false,
              ),
            ],
            aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          )
          .catchError((e) {
            Logger.error("Cropper Error: $e");
            return null;
          });

      if (cropped != null) {
        setState(() {
          _imageFile = File(cropped.path);
        });
      } else {
        // Did they cancel, or did it fail?
        // Usually null means cancelled.
        // We can optionally verify here, but usually silent is fine for cancel.
      }
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

      // Discount Parsing
      double? discountValue;
      if (_discountEnabled.value) {
        discountValue = double.tryParse(_discountController.text);
      }

      // Calculate manual stock
      int? manualStock;
      if (_variants.isEmpty) {
        manualStock = int.tryParse(_stockController.text) ?? 0;
      }

      final product = Product(
        id: widget.product?.id ?? '',
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        categoryId: _categoryController.text.trim(),
        price: price,
        costPrice: costPrice,
        shipmentCost: shipmentCost > 0 ? shipmentCost : null,
        discountValue: discountValue,
        discountType: _discountType.value,
        variants: _variants,
        manualStock: manualStock, // Use manualStock instead of totalStock
        lowStockThreshold: int.tryParse(_lowStockController.text) ?? 5,
        imagePath: _currentImageUrl,
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
          const SnackBar(
            content: Text('Product Saved Successfully'),
            backgroundColor: SoftColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: SoftColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addVariant() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AddVariantDialog(
          onVariantAdded: (newVariant) {
            setState(() {
              _variants.add(newVariant);
            });
          },
        );
      },
    );
  }

  void _editVariant(int index) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AddVariantDialog(
          variant: _variants[index],
          onVariantAdded: (updatedVariant) {
            setState(() {
              _variants[index] = updatedVariant;
            });
          },
        );
      },
    );
  }

  // ... (omitted _addNewCategory and _buildDiscountTypeBtn for brevity, assuming no changes there)
  // Re-include them if they were in the range, but I'll skip to build method changes.
  // Actually, replace_file_content needs exact context.
  // I will target the _saveProduct method specifically first.

  Future<Category?> _addNewCategory() async {
    String newCategoryName = '';
    return showDialog<Category>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: SoftColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SoftColors.cardRadius),
          ),
          title: Text(
            "New Category",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: ModernInput(
            hintText: 'Category Name',
            onChanged: (v) => newCategoryName = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                if (newCategoryName.isNotEmpty) {
                  try {
                    final newCat = Category(
                      id: const Uuid().v4(),
                      name: newCategoryName.trim(),
                      icon: '📦',
                    );
                    await ref
                        .read(categoryRepositoryProvider)
                        .addCategory(newCat);
                    if (context.mounted) {
                      Navigator.pop(context, newCat);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text("Error: $e")));
                    }
                  }
                }
              },
              child: const Text(
                "Add",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDiscountTypeBtn(DiscountType type, String label) {
    return ValueListenableBuilder<DiscountType>(
      valueListenable: _discountType,
      builder: (context, currentType, _) {
        final isSelected = currentType == type;
        return BounceButton(
          onTap: () {
            _discountType.value = type;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? SoftColors.brandPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : SoftColors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }

  double _calculateFinalPrice() {
    double price = double.tryParse(_priceController.text) ?? 0;
    double discountVal = double.tryParse(_discountController.text) ?? 0;

    if (discountVal == 0) return price;

    if (_discountType.value == DiscountType.fixed) {
      return (price - discountVal).clamp(0, double.infinity);
    } else {
      return (price * (1 - discountVal / 100)).clamp(0, double.infinity);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SoftScaffold(
      title: widget.product == null ? 'Add Product' : 'Edit Product',
      showBack: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Picker
              Center(
                child: BounceButton(
                  onTap: _pickImage,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: SoftColors.background,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: SoftColors.textMain.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
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
                        ? Icon(
                            Icons.add_a_photo_rounded,
                            size: 48,
                            color: SoftColors.brandPrimary.withValues(
                              alpha: 0.5,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Text(
                "Product Details",
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: SoftColors.textMain,
                ),
              ),
              const SizedBox(height: 16),

              // SoftCard removed for better contrast
              Column(
                children: [
                  ModernInput(
                    controller: _nameController,
                    hintText: 'Enter product name',
                    labelText: 'Product Name',
                    showClearButton: true,
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  ModernInput(
                    controller: _descController,
                    hintText: 'Enter product description',
                    labelText: 'Description (Optional)',
                    showClearButton: true,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: SoftColors.textMain.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Consumer(
                      builder: (context, ref, child) {
                        final categoriesAsync = ref.watch(categoryListProvider);

                        return categoriesAsync.when(
                          data: (categories) {
                            return ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _categoryController,
                              builder: (context, controllerValue, _) {
                                final currentId = controllerValue.text;

                                // FIX: Deduplicate categories to prevent Dropdown crash
                                final uniqueCategories = {
                                  for (var c in categories) c.id: c,
                                }.values.toList();

                                // Check list against dedicated list
                                final bool isInList = uniqueCategories.any(
                                  (c) => c.id == currentId,
                                );

                                final effectiveValue = currentId.isNotEmpty
                                    ? currentId
                                    : null;

                                return DropdownButtonFormField<String>(
                                  key: ValueKey(
                                    '$effectiveValue-$_dropdownKey',
                                  ),
                                  initialValue: effectiveValue,
                                  decoration: InputDecoration(
                                    labelText: 'Category',
                                    labelStyle: GoogleFonts.outfit(
                                      color: SoftColors.textSecondary,
                                    ),
                                    hintText: 'Choose Category',
                                    hintStyle: GoogleFonts.outfit(
                                      color: SoftColors.textSecondary
                                          .withValues(alpha: 0.7),
                                    ),
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.category_outlined,
                                      color: SoftColors.textSecondary,
                                    ),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: '',
                                      child: Text(
                                        'No Category',
                                        style: GoogleFonts.outfit(
                                          color: SoftColors.textSecondary,
                                          fontStyle: FontStyle.italic,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    // 1. Initial Category (Legacy)
                                    if (_initialCategoryId != null &&
                                        _initialCategoryId!.isNotEmpty &&
                                        !uniqueCategories.any(
                                          (c) => c.id == _initialCategoryId,
                                        ) &&
                                        _initialCategoryId != '__new__')
                                      DropdownMenuItem(
                                        value: _initialCategoryId,
                                        child: Text(
                                          "$_initialCategoryId (Legacy)",
                                          style: GoogleFonts.outfit(
                                            color: SoftColors.textSecondary,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),

                                    // 2. Newly Created / Unknown Value
                                    if (effectiveValue != null &&
                                        !isInList &&
                                        effectiveValue != '__new__' &&
                                        effectiveValue != _initialCategoryId)
                                      DropdownMenuItem(
                                        value: effectiveValue,
                                        child: Text(
                                          _tempNewCategoryName ?? "Loading...",
                                          style: GoogleFonts.outfit(
                                            color: SoftColors.textMain,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),

                                    // 3. Main List (Deduped)
                                    ...uniqueCategories.map(
                                      (c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(
                                          c.name,
                                          style: GoogleFonts.outfit(
                                            color: SoftColors.textMain,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),

                                    DropdownMenuItem(
                                      value: '__new__',
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.add_circle_outline_rounded,
                                            color: SoftColors.brandPrimary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Add New Category',
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              color: SoftColors.brandPrimary,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) async {
                                    if (val == '__new__') {
                                      final newCat = await _addNewCategory();

                                      if (newCat != null) {
                                        // Update state to show name immediately
                                        setState(() {
                                          _tempNewCategoryName = newCat.name;
                                        });
                                        // Update controller with ID
                                        _categoryController.text = newCat.id;
                                      } else {
                                        // Cancelled - Force widget rebuild with new KEY
                                        setState(() {
                                          _dropdownKey++;
                                        });
                                      }
                                    } else if (val != null) {
                                      // UPDATE CONTROLLER ONLY - NO setState!
                                      _categoryController.text = val;
                                    }
                                  },
                                  // Validator removed to make it optional
                                  validator: null,
                                  dropdownColor: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  isExpanded: true,
                                  icon: const Padding(
                                    padding: EdgeInsets.only(right: 16),
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: SoftColors.textSecondary,
                                    ),
                                  ),
                                  style: GoogleFonts.outfit(
                                    color: SoftColors.textMain,
                                    fontSize: 16,
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.all(16),
                            child: LinearProgressIndicator(
                              color: SoftColors.brandPrimary,
                              backgroundColor: SoftColors.bgLight,
                            ),
                          ),
                          error: (e, s) => Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Error loading categories',
                              style: GoogleFonts.outfit(
                                color: SoftColors.error,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Text(
                "Pricing",
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: SoftColors.textMain,
                ),
              ),
              const SizedBox(height: 16),

              // SoftCard removed
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ModernInput(
                          controller: _priceController,
                          hintText: 'Selling Price',
                          labelText: 'Selling Price',
                          prefixText: '\$ ',
                          showClearButton: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          validator: (v) =>
                              v?.isEmpty == true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ModernInput(
                          controller: _costPriceController,
                          hintText: 'Cost Price',
                          labelText: 'Cost Price',
                          prefixText: '\$ ',
                          showClearButton: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          validator: (v) =>
                              v?.isEmpty == true ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ModernInput(
                    controller: _shipmentCostController,
                    hintText: 'Shipment Cost (Optional)',
                    labelText: 'Shipment Cost',
                    prefixText: '\$ ',
                    showClearButton: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // DISCOUNT SECTION
                  ValueListenableBuilder<bool>(
                    valueListenable: _discountEnabled,
                    builder: (context, isEnabled, _) {
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Discount",
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: SoftColors.textMain,
                                ),
                              ),
                              Switch(
                                value: isEnabled,
                                activeThumbColor: Colors.white,
                                activeTrackColor: SoftColors.brandPrimary,
                                inactiveThumbColor: Colors.white,
                                inactiveTrackColor: SoftColors.textSecondary
                                    .withValues(alpha: 0.3),
                                trackOutlineColor:
                                    WidgetStateProperty.resolveWith(
                                      (states) => Colors.transparent,
                                    ),
                                onChanged: (v) {
                                  _discountEnabled.value = v;
                                  if (!v) _discountController.clear();
                                },
                              ),
                            ],
                          ),
                          if (isEnabled) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                // Type Selector
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: SoftColors.textSecondary
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildDiscountTypeBtn(
                                        DiscountType.percentage,
                                        '%',
                                      ),
                                      _buildDiscountTypeBtn(
                                        DiscountType.fixed,
                                        '\$',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ValueListenableBuilder<DiscountType>(
                                    valueListenable: _discountType,
                                    builder: (context, type, _) {
                                      return ModernInput(
                                        controller: _discountController,
                                        hintText: 'Value',
                                        labelText: 'Discount Value',
                                        prefixText: type == DiscountType.fixed
                                            ? '\$ '
                                            : '% ',
                                        showClearButton: true,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d*\.?\d*'),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Final Price Preview
                            AnimatedBuilder(
                              animation: Listenable.merge([
                                _priceController,
                                _discountController,
                                _discountType,
                                _discountEnabled,
                              ]),
                              builder: (context, _) {
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: SoftColors.brandPrimary.withValues(
                                      alpha: 0.05,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: SoftColors.brandPrimary.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Final Selling Price:",
                                        style: GoogleFonts.outfit(
                                          color: SoftColors.textMain,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        "\$${_calculateFinalPrice().toStringAsFixed(2)}",
                                        style: GoogleFonts.outfit(
                                          color: SoftColors.brandPrimary,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Stock & Variants
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Stock & Variants",
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: SoftColors.textMain,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addVariant,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text("Add Variant"),
                    style: TextButton.styleFrom(
                      // Use "Add Item" button style from AddNewOrderScreenish
                      backgroundColor: SoftColors.brandPrimary.withValues(
                        alpha: 0.1,
                      ),
                      foregroundColor: SoftColors.brandPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_variants.isEmpty)
                SoftCard(
                  child: ModernInput(
                    controller: _stockController,
                    hintText: 'Enter total stock',
                    labelText: 'Total Stock',
                    showClearButton: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _variants.length,
                  itemBuilder: (context, index) {
                    final v = _variants[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SoftCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            // Thumbnail
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: SoftColors.bgLight,
                                borderRadius: BorderRadius.circular(12),
                                image: v.imagePath != null
                                    ? DecorationImage(
                                        image:
                                            (v.imagePath!.startsWith('http')
                                                    ? NetworkImage(v.imagePath!)
                                                    : FileImage(
                                                        File(v.imagePath!),
                                                      ))
                                                as ImageProvider,
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: v.imagePath == null
                                  ? const Icon(
                                      Icons.layers_outlined,
                                      size: 24,
                                      color: SoftColors.textSecondary,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    v.name,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: SoftColors.textMain,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Qty: ${v.stockQuantity}',
                                    style: GoogleFonts.outfit(
                                      color: SoftColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => _editVariant(index),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.edit_rounded,
                                      size: 20,
                                      color: SoftColors.brandPrimary.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _variants.removeAt(index);
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 20,
                                      color: SoftColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),
              // LOW STOCK ALERT INPUT
              ModernInput(
                controller: _lowStockController,
                hintText: '5',
                labelText: 'Alert me when stock is below...',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 48),

              SoftButton(
                label: "Save Product",
                onTap: _saveProduct,
                isLoading: _isLoading,
                icon: Icons.save_rounded,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
