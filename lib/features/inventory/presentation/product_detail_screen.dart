import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../products/data/providers/product_provider.dart';

class ProductDetailScreen extends ConsumerWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);

    // Find the latest version of this product from the provider, or use the passed one
    final currentProduct =
        productsAsync.value?.firstWhere(
          (p) => p.id == product.id,
          orElse: () => product,
        ) ??
        product;

    return SoftScaffold(
      title: 'Product Details',
      showBack: true,
      actions: [
        BounceButton(
          onTap: () => context.go('/inventory/edit', extra: currentProduct),
          child: Container(
            padding: const EdgeInsets.all(
              12,
            ), // Restore to 12 for symmetry with Back button
            decoration: BoxDecoration(
              color: SoftColors.brandPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.edit_rounded,
              color: SoftColors.brandPrimary,
              size: 20,
            ),
          ),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            SoftCard(
              padding: EdgeInsets.zero,
              child: Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: SoftColors.textMain.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(SoftColors.cardRadius),
                ),
                child: currentProduct.imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(
                          SoftColors.cardRadius,
                        ),
                        child: CachedNetworkImage(
                          imageUrl: currentProduct.imagePath!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              color: SoftColors.brandPrimary.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.broken_image_rounded,
                            size: 64,
                            color: SoftColors.textMain.withValues(alpha: 0.2),
                          ),
                        ),
                      )
                    : Icon(
                        Icons.image_not_supported_rounded,
                        size: 64,
                        color: SoftColors.textMain.withValues(alpha: 0.2),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Title & Price
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    currentProduct.name,
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: SoftColors.textMain,
                    ),
                  ),
                ),
                Text(
                  '\$${currentProduct.price.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    color: SoftColors.brandPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Info Grid
            SoftCard(
              child: Row(
                children: [
                  Expanded(
                    child: _DetailItem(
                      "Cost Price",
                      "\$${currentProduct.costPrice}",
                    ),
                  ),
                  _ContainerLine(),
                  Expanded(
                    child: _DetailItem("Stock", "${currentProduct.totalStock}"),
                  ),
                  _ContainerLine(),
                  Expanded(
                    child: _DetailItem(
                      "Category",
                      currentProduct.categoryId.isEmpty
                          ? "N/A"
                          : currentProduct.categoryId,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Description
            Text(
              "Description",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: SoftColors.textMain,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              currentProduct.description.isEmpty
                  ? "No description available."
                  : currentProduct.description,
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: SoftColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Variants
            if (currentProduct.variants.isNotEmpty) ...[
              Text(
                "Variants",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: SoftColors.textMain,
                ),
              ),
              const SizedBox(height: 12),
              ...currentProduct.variants.map(
                (v) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SoftCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Text(
                          v.name,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            color: SoftColors.textMain,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: SoftColors.brandPrimary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${v.stockQuantity} in stock",
                            style: GoogleFonts.outfit(
                              color: SoftColors.brandPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Stock Adjustment Section
            Text(
              "Manage Stock",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: SoftColors.textMain,
              ),
            ),
            const SizedBox(height: 12),
            _StockAdjustmentCard(product: currentProduct),

            const SizedBox(height: 48),

            // Delete Button
            SoftButton(
              label: "Delete Product",
              backgroundColor: SoftColors.error,
              textColor: Colors.white,
              icon: Icons.delete_rounded,
              onTap: () async {
                final shouldDelete = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: SoftColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        SoftColors.cardRadius,
                      ),
                    ),
                    title: Text(
                      "Delete Product?",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                    content: Text(
                      "This cannot be undone. Are you sure you want to delete this product?",
                      style: GoogleFonts.outfit(
                        color: SoftColors.textSecondary,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: Text(
                          "Delete",
                          style: GoogleFonts.outfit(
                            color: SoftColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                if (shouldDelete == true) {
                  // TODO: Use abstract repository once delete is supported
                  await ref
                      .read(inventoryRepositoryProvider)
                      .deleteProduct(currentProduct.id);
                  if (context.mounted) context.pop();
                }
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ContainerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: 1,
      color: SoftColors.textSecondary.withValues(alpha: 0.2),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  const _DetailItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: SoftColors.textSecondary,
            fontSize: 14, // Increased from 12
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: SoftColors.textMain,
            fontWeight: FontWeight.w800, // Increased weight
            fontSize: 18, // Increased from 16
          ),
        ),
      ],
    );
  }
}

class _StockAdjustmentCard extends ConsumerStatefulWidget {
  final Product product;
  const _StockAdjustmentCard({required this.product});

  @override
  ConsumerState<_StockAdjustmentCard> createState() =>
      _StockAdjustmentCardState();
}

class _StockAdjustmentCardState extends ConsumerState<_StockAdjustmentCard> {
  bool _isUpdating = false;

  Future<void> _updateStock(int delta) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    try {
      // Calculate new stock
      final currentStock = widget.product.totalStock;
      final newStock = currentStock + delta; // delta can be negative

      if (newStock < 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Cannot reduce stock below 0",
                style: GoogleFonts.outfit(color: Colors.white),
              ),
              backgroundColor: SoftColors.error,
            ),
          );
        }
        return;
      }

      final updatedProduct = widget.product.copyWith(totalStock: newStock);

      // Use the notifier to update
      await ref.read(productsProvider.notifier).updateProduct(updatedProduct);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              delta > 0
                  ? "Stock increased by $delta"
                  : "Stock reduced by ${delta.abs()}",
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            backgroundColor: SoftColors.success,
            duration: const Duration(milliseconds: 1000),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update stock: $e"),
            backgroundColor: SoftColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showCustomReduceDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SoftColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SoftColors.cardRadius),
        ),
        title: Text(
          "Reduce Stock",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Current Stock: ${widget.product.totalStock}",
              style: GoogleFonts.outfit(color: SoftColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ModernInput(
              controller: controller,
              hintText: "Enter amount (e.g. 10)",
              keyboardType: TextInputType.number,
              prefixIcon: Icons.remove_circle_outline,
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
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) {
                Navigator.pop(context);
                _updateStock(-val);
              }
            },
            child: Text(
              "Reduce",
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: SoftColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SoftColors.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: SoftColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Quick Actions",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: SoftColors.textMain,
                    ),
                  ),
                  Text(
                    "Adjust inventory levels",
                    style: GoogleFonts.outfit(
                      color: SoftColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Quick Reduce 1
              Expanded(
                child: SoftButton(
                  label: "Reduce 1",
                  onTap: () => _updateStock(-1),
                  isLoading: _isUpdating,
                  backgroundColor: SoftColors.brandPrimary.withValues(
                    alpha: 0.1,
                  ),
                  textColor: SoftColors.brandPrimary,
                  icon: Icons.remove_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 12),
              // Custom Reduce
              Expanded(
                child: SoftButton(
                  label: "Custom",
                  onTap: _showCustomReduceDialog,
                  isLoading: _isUpdating, // Also disable this if updating
                  backgroundColor: SoftColors.background,
                  textColor: SoftColors.textMain,
                  icon: Icons.edit_note_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
