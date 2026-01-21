import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../../design_system.dart';
import '../../inventory/domain/product.dart';

class AddVariantDialog extends StatefulWidget {
  final Function(ProductVariant) onVariantAdded;

  const AddVariantDialog({super.key, required this.onVariantAdded});

  @override
  State<AddVariantDialog> createState() => _AddVariantDialogState();
}

class _AddVariantDialogState extends State<AddVariantDialog> {
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: SoftColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SoftColors.cardRadius),
      ),
      title: Text(
        "Add Variant",
        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                id: const Uuid().v4(),
                name: _nameController.text,
                stockQuantity: int.tryParse(_qtyController.text) ?? 0,
              );
              widget.onVariantAdded(newVariant);
              Navigator.pop(context);
            }
          },
          child: const Text(
            "Add",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
