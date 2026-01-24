import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system.dart';
import '../../auth/data/providers/auth_providers.dart';
import '../../auth/domain/user_model.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/domain/product.dart';
import '../../products/data/providers/product_provider.dart';
import '../data/providers/category_provider.dart';

class ProductDetailScreen extends ConsumerWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoryListProvider);

    final user = ref.watch(currentUserProfileProvider).value;
    final isEmployee = user?.role == UserRole.employee;

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
        if (!isEmployee)
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
            // Image Section
            SoftCard(
              padding: EdgeInsets.zero,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: SoftColors.bgLight, // Clean light background
                    borderRadius: BorderRadius.circular(SoftColors.cardRadius),
                  ),
                  child: currentProduct.imagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(
                            SoftColors.cardRadius,
                          ),
                          child: CachedNetworkImage(
                            imageUrl: currentProduct.imagePath!,
                            fit: BoxFit.contain, // Show full product
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
            ),
            const SizedBox(height: 24),

            // Title, Stock & Price
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentProduct.name,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: SoftColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: currentProduct.totalStock <= 0
                              ? SoftColors.error.withValues(alpha: 0.1)
                              : (currentProduct.totalStock <=
                                        currentProduct.lowStockThreshold
                                    ? SoftColors.warning.withValues(alpha: 0.1)
                                    : SoftColors.success.withValues(
                                        alpha: 0.1,
                                      )),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: currentProduct.totalStock <= 0
                                ? SoftColors.error.withValues(alpha: 0.2)
                                : (currentProduct.totalStock <=
                                          currentProduct.lowStockThreshold
                                      ? SoftColors.warning.withValues(
                                          alpha: 0.2,
                                        )
                                      : SoftColors.success.withValues(
                                          alpha: 0.2,
                                        )),
                          ),
                        ),
                        child: Text(
                          currentProduct.totalStock <= 0
                              ? "Out of stock!"
                              : (currentProduct.totalStock <=
                                        currentProduct.lowStockThreshold
                                    ? "Low stock: ${currentProduct.totalStock}"
                                    : "In stock: ${currentProduct.totalStock}"),
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: currentProduct.totalStock <= 0
                                ? SoftColors.error
                                : (currentProduct.totalStock <=
                                          currentProduct.lowStockThreshold
                                      ? SoftColors.warning
                                      : SoftColors.success),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Pricing Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (currentProduct.hasDiscount) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: SoftColors.brandAccent.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              currentProduct.discountType ==
                                      DiscountType.percentage
                                  ? '-${currentProduct.discountValue}%'
                                  : '-\$${currentProduct.discountValue}',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: SoftColors.brandAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '\$${currentProduct.price.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              decoration: TextDecoration.lineThrough,
                              color: SoftColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '\$${currentProduct.finalPrice.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          color: SoftColors.brandPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ] else
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
              ],
            ),
            const SizedBox(height: 24),

            // Info Grid (2x2)
            SoftCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _DetailItem(
                          "Category",
                          categoriesAsync.valueOrNull
                                  ?.where(
                                    (c) => c.id == currentProduct.categoryId,
                                  )
                                  .firstOrNull
                                  ?.name ??
                              (currentProduct.categoryId.isEmpty
                                  ? "N/A"
                                  : currentProduct.categoryId),
                        ),
                      ),
                      if (!isEmployee) ...[
                        _ContainerLine(),
                        Expanded(
                          child: _DetailItem(
                            "Cost Price",
                            "\$${currentProduct.costPrice}",
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!isEmployee) ...[
                    const SizedBox(height: 16),
                    Container(
                      height: 1,
                      width: double.infinity,
                      color: SoftColors.textSecondary.withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _DetailItem(
                            "Alert Threshold",
                            "${currentProduct.lowStockThreshold}",
                          ),
                        ),
                        _ContainerLine(),
                        Expanded(
                          child: _DetailItem(
                            "Shipment",
                            "\$${(currentProduct.shipmentCost ?? 0).toStringAsFixed(1)}",
                          ),
                        ),
                      ],
                    ),
                  ],
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
            _StockAdjustmentCard(
              product: currentProduct,
              isEmployee: isEmployee,
            ),

            const SizedBox(height: 48),

            // Delete Button
            if (!isEmployee)
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
  final bool isEmployee;
  const _StockAdjustmentCard({required this.product, required this.isEmployee});

  @override
  ConsumerState<_StockAdjustmentCard> createState() =>
      _StockAdjustmentCardState();
}

class _StockAdjustmentCardState extends ConsumerState<_StockAdjustmentCard> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isEmployee) {
      // Employees: View only for Out of Stock
      if (widget.product.totalStock <= 0) {
        return const SizedBox.shrink();
      }
      // Employees: Only see Reduce Stock for Low Stock items
      if (widget.product.totalStock > widget.product.lowStockThreshold) {
        return const SizedBox.shrink();
      }
    }

    if (widget.product.variants.isNotEmpty) {
      return SoftCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: SoftColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Stock is managed via variants.",
                style: GoogleFonts.outfit(
                  color: SoftColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

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

      // Use manualStock for simple products
      final updatedProduct = widget.product.copyWith(manualStock: newStock);

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
}
