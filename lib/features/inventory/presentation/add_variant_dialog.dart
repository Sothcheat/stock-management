import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:uuid/uuid.dart';

import '../../../../design_system.dart';
import '../../inventory/domain/product.dart';

class AddVariantDialog extends StatefulWidget {
  final Function(ProductVariant) onVariantAdded;
  final ProductVariant? variant;

  const AddVariantDialog({
    super.key,
    required this.onVariantAdded,
    this.variant,
  });

  @override
  State<AddVariantDialog> createState() => _AddVariantDialogState();
}

class _AddVariantDialogState extends State<AddVariantDialog> {
  late TextEditingController _nameController;
  late TextEditingController _qtyController;
  File? _imageFile;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.variant?.name);
    _qtyController = TextEditingController(
      text: widget.variant?.stockQuantity.toString(),
    );
    _existingImageUrl = widget.variant?.imagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Variant Image',
            toolbarColor: SoftColors.brandPrimary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Variant Image',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      );

      if (cropped != null) {
        setState(() {
          _imageFile = File(cropped.path);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.variant != null;

    return AlertDialog(
      backgroundColor: SoftColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SoftColors.cardRadius),
      ),
      title: Text(
        isEditing ? "Edit Variant" : "Add Variant",
        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: BounceButton(
              onTap: _pickImage,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: SoftColors.bgLight,
                  borderRadius: BorderRadius.circular(16),
                  image: _imageFile != null
                      ? DecorationImage(
                          image: FileImage(_imageFile!),
                          fit: BoxFit.cover,
                        )
                      : (_existingImageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(_existingImageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null),
                ),
                child: _imageFile == null && _existingImageUrl == null
                    ? const Icon(
                        Icons.add_a_photo,
                        color: SoftColors.textSecondary,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ModernInput(
            controller: _nameController,
            hintText: 'Variant Name (e.g. Red-XL)',
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _nameController,
              builder: (context, value, child) {
                return value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: SoftColors.textSecondary,
                        ),
                        onPressed: _nameController.clear,
                      );
              },
            ),
          ),
          const SizedBox(height: 12),
          ModernInput(
            controller: _qtyController,
            hintText: 'Quantity',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _qtyController,
              builder: (context, value, child) {
                return value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: SoftColors.textSecondary,
                        ),
                        onPressed: _qtyController.clear,
                      );
              },
            ),
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
            if (_nameController.text.isNotEmpty) {
              final newVariant = ProductVariant(
                id: widget.variant?.id ?? const Uuid().v4(),
                name: _nameController.text,
                stockQuantity: int.tryParse(_qtyController.text) ?? 0,
                // Preserve existing URL if no new file is picked
                imagePath: _imageFile?.path ?? _existingImageUrl,
              );
              widget.onVariantAdded(newVariant);
              Navigator.pop(context);
            }
          },
          child: Text(
            isEditing ? "Update" : "Add",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
