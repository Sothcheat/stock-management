import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system.dart';
import '../../auth/data/providers/auth_providers.dart';
import '../../auth/domain/user_model.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/domain/product.dart';
import '../../products/data/providers/product_provider.dart';
import '../../orders/data/firebase_orders_repository.dart';
import '../../orders/domain/order.dart';
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

            // Inventory & Stock Section (Unified)
            if (currentProduct.variants.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Variants & Stock",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: SoftColors.textMain,
                    ),
                  ),
                  Text(
                    "Total: ${currentProduct.totalStock}",
                    style: GoogleFonts.outfit(
                      color: SoftColors.brandPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _UnifiedVariantList(
                product: currentProduct,
                isEmployee: isEmployee,
              ),
            ] else ...[
              // Fallback for non-variant products (Keep existing Manage Stock)
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
            ],

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
  final Map<String, int> _selectedVariantQuantities = {};

  @override
  @override
  Widget build(BuildContext context) {
    if (widget.isEmployee) {
      if (widget.product.totalStock <= 0) {
        return const SizedBox.shrink();
      }
      if (widget.product.totalStock > widget.product.lowStockThreshold) {
        return const SizedBox.shrink();
      }
    }

    if (widget.product.variants.isNotEmpty) {
      final hasSelection = _selectedVariantQuantities.values.any((q) => q > 0);

      return SoftCard(
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: SoftColors.brandPrimary.withValues(
                      alpha: 0.1,
                    ), // Used primary instead of secondary
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: SoftColors.brandPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Quick Sale",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: SoftColors.textMain,
                      ),
                    ),
                    Text(
                      "Select variants to sell",
                      style: GoogleFonts.outfit(
                        color: SoftColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: SoftColors.border.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            ...widget.product.variants.map((v) {
              final qty = _selectedVariantQuantities[v.id] ?? 0;
              final isOutOfStock = v.stockQuantity == 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 24), // Increased spacing
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        // Changed to Row for icon + text group
                        children: [
                          // Thumbnail
                          Container(
                            width: 48, // Bigger
                            height: 48, // Bigger
                            decoration: BoxDecoration(
                              color: SoftColors.bgLight,
                              borderRadius: BorderRadius.circular(
                                12,
                              ), // Increased radius
                              image: v.imagePath != null
                                  ? DecorationImage(
                                      image: NetworkImage(v.imagePath!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: v.imagePath == null
                                ? const Icon(
                                    Icons.layers_outlined,
                                    size: 24,
                                    color: SoftColors.textSecondary,
                                  ) // Bigger icon
                                : null,
                          ),
                          const SizedBox(width: 16), // More breathing room
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  v.name,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold, // Bolder
                                    fontSize: 16, // Bigger
                                    color: isOutOfStock
                                        ? SoftColors.textSecondary.withValues(
                                            alpha: 0.5,
                                          )
                                        : SoftColors.textMain,
                                  ),
                                ),
                                const SizedBox(height: 0), // Spacing
                                Text(
                                  isOutOfStock
                                      ? "Out of Stock"
                                      : "${v.stockQuantity} available",
                                  style: GoogleFonts.outfit(
                                    fontSize: 13, // Slightly bigger
                                    color: isOutOfStock
                                        ? SoftColors.error
                                        : SoftColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isOutOfStock)
                      Container(
                        decoration: BoxDecoration(
                          color: SoftColors.bgLight,
                          borderRadius: BorderRadius.circular(
                            12,
                          ), // Matches thumbnail radius
                        ),
                        child: Row(
                          children: [
                            _QtyBtn(
                              icon: Icons.remove,
                              onTap: () {
                                if (qty > 0) {
                                  setState(() {
                                    _selectedVariantQuantities[v.id] = qty - 1;
                                  });
                                }
                              },
                            ),
                            SizedBox(
                              width: 36, // Slightly wider
                              child: Text(
                                "$qty",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: SoftColors.textMain,
                                ),
                              ),
                            ),
                            _QtyBtn(
                              icon: Icons.add,
                              onTap: () {
                                if (qty < v.stockQuantity) {
                                  setState(() {
                                    _selectedVariantQuantities[v.id] = qty + 1;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }),
            if (hasSelection) ...[
              const SizedBox(height: 12),
              SoftButton(
                label: "Process Sale",
                onTap: _processVariantBatchSale,
                isLoading: _isUpdating,
                backgroundColor: SoftColors.brandPrimary,
                textColor: Colors.white,
                icon: Icons.check_circle_outline,
              ),
            ],
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
              Expanded(
                child: SoftButton(
                  label: "Reduce 1",
                  onTap: () => _updateStock(-1),
                  isLoading: _isUpdating,
                  backgroundColor: SoftColors.brandPrimary.withValues(
                    alpha: 0.9,
                  ),
                  textColor: SoftColors.bgLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SoftButton(
                  label: "Custom",
                  onTap: _showCustomReduceDialog,
                  isLoading: _isUpdating,
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

  Future<void> _processVariantBatchSale() async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    try {
      final List<OrderItem> items = [];
      _selectedVariantQuantities.forEach((variantId, qty) {
        if (qty > 0) {
          final variant = widget.product.variants.firstWhere(
            (v) => v.id == variantId,
          );
          items.add(
            OrderItem(
              productId: widget.product.id,
              name: widget.product.name,
              variantId: variantId,
              variantName: variant.name,
              quantity: qty,
              priceAtSale: widget.product.finalPrice,
              costPriceAtSale: widget.product.costPrice,
              shipmentCostAtSale: widget.product.shipmentCost ?? 0,
            ),
          );
        }
      });

      if (items.isEmpty) return;

      final orderId = await ref
          .read(ordersRepositoryProvider)
          .createBatchQuickSale(items);

      if (mounted) {
        setState(() {
          _selectedVariantQuantities.clear();
        });

        _showUndoSnackBar(
          items.fold<int>(0, (p, c) => p + c.quantity),
          orderId,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sale failed: $e"),
            backgroundColor: SoftColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _updateStock(int delta) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    try {
      final currentStock = widget.product.totalStock;
      final newStock = currentStock + delta;

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

      if (delta < 0) {
        final item = OrderItem(
          productId: widget.product.id,
          name: widget.product.name,
          quantity: delta.abs(),
          priceAtSale: widget.product.finalPrice,
          variantId: null,
          variantName: 'Manual Stock',
        );

        final orderId = await ref
            .read(ordersRepositoryProvider)
            .createBatchQuickSale([item]);

        if (mounted) {
          _showUndoSnackBar(delta.abs(), orderId);
        }
      } else {
        // Increase Manual Stock
        final updatedProduct = widget.product.copyWith(
          manualStock:
              (widget.product.manualStock ?? 0) + delta, // Update Manual Stock
        );
        // We use productProvider to update to preserve UI flow, though direct repo call is also fine.
        // Assuming provider has update method or we use repo.
        // Let's use repo directly to be robust.
        await ref
            .read(inventoryRepositoryProvider)
            .updateProduct(updatedProduct, null);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Stock increased by $delta",
                style: GoogleFonts.outfit(color: Colors.white),
              ),
              backgroundColor: SoftColors.success,
              duration: const Duration(milliseconds: 1000),
            ),
          );
        }
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

  void _showUndoSnackBar(int count, String orderId) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Sold $count items",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: SoftColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: "UNDO",
          textColor: Colors.white,
          onPressed: () async {
            try {
              await ref
                  .read(ordersRepositoryProvider)
                  .revertQuickSaleOrder(orderId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Reverted sale of $count items"),
                    backgroundColor: SoftColors.textMain,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Undo failed: $e"),
                    backgroundColor: SoftColors.error,
                  ),
                );
              }
            }
          },
        ),
      ),
    );
    HapticFeedback.lightImpact();
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

class _UnifiedVariantList extends ConsumerStatefulWidget {
  final Product product;
  final bool isEmployee;
  const _UnifiedVariantList({required this.product, required this.isEmployee});

  @override
  ConsumerState<_UnifiedVariantList> createState() =>
      _UnifiedVariantListState();
}

class _UnifiedVariantListState extends ConsumerState<_UnifiedVariantList> {
  bool _isUpdating = false;
  final Map<String, int> _pendingAdjustments = {};

  void _adjustQuantity(String variantId, int delta) {
    setState(() {
      final current = _pendingAdjustments[variantId] ?? 0;
      final newValue = current + delta;

      // Ensure we don't go below the actual stock available if selling
      // (This is a simplified check, ideally we check against actual variant stock)
      // But user wants "change you want to make".
      // If I want to sell 5, I set -5.
      // Limits: Can't sell more than stock. Can't restock < 0 (wait, restock is positive).
      // Let's just allow free range but validate on process?
      // Creating a "safe" limit:
      final v = widget.product.variants.firstWhere((v) => v.id == variantId);
      if (newValue < 0 && newValue.abs() > v.stockQuantity) {
        // Can't sell more than we have
        return;
      }

      if (newValue == 0) {
        _pendingAdjustments.remove(variantId);
      } else {
        _pendingAdjustments[variantId] = newValue;
      }
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _processAdjustments() async {
    if (_isUpdating || _pendingAdjustments.isEmpty) return;
    setState(() => _isUpdating = true);

    try {
      final salesItems = <OrderItem>[];
      final restockUpdates = <ProductVariant>[];
      final currentVariants = widget.product.variants;

      // Split adjustments
      for (var entry in _pendingAdjustments.entries) {
        final variantId = entry.key;
        final adjustment = entry.value;
        final variant = currentVariants.firstWhere((v) => v.id == variantId);

        if (adjustment < 0) {
          // Selling
          salesItems.add(
            OrderItem(
              productId: widget.product.id,
              name: widget.product.name,
              variantId: variantId,
              variantName: variant.name,
              quantity: adjustment.abs(),
              priceAtSale: widget.product.finalPrice,
              costPriceAtSale: widget.product.costPrice,
              shipmentCostAtSale: widget.product.shipmentCost ?? 0,
            ),
          );
        } else if (adjustment > 0) {
          // Restocking
          restockUpdates.add(
            ProductVariant(
              id: variant.id,
              name: variant.name,
              stockQuantity:
                  variant.stockQuantity + adjustment, // Add the adjustment
              imagePath: variant.imagePath,
            ),
          );
        }
      }

      // 1. Process Sales
      String? saleOrderId;
      if (salesItems.isNotEmpty) {
        saleOrderId = await ref
            .read(ordersRepositoryProvider)
            .createBatchQuickSale(salesItems);
      }

      // 2. Process Restocks
      if (restockUpdates.isNotEmpty) {
        // We need to merge unrelated variants with updated ones
        final mergedVariants = currentVariants.map((v) {
          final updated = restockUpdates.where((u) => u.id == v.id).firstOrNull;
          return updated ?? v;
        }).toList();

        final updatedProduct = widget.product.copyWith(
          variants: mergedVariants,
        );
        await ref
            .read(inventoryRepositoryProvider)
            .updateProduct(updatedProduct, null);
      }

      if (mounted) {
        // Success Feedback
        _pendingAdjustments.clear();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // If we had a sale, show undo
        // If we had mixed or just restock, show generic success
        // Prioritize sale undo for simplicity as requested
        if (saleOrderId != null) {
          final totalSold = salesItems.fold<int>(0, (p, c) => p + c.quantity);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Sold $totalSold items${restockUpdates.isNotEmpty ? ' & Updated Stock' : ''}",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: SoftColors.success,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: "UNDO",
                textColor: Colors.white,
                onPressed: () async {
                  await ref
                      .read(ordersRepositoryProvider)
                      .revertQuickSaleOrder(saleOrderId!);
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Stock updated successfully",
                style: GoogleFonts.outfit(color: Colors.white),
              ),
              backgroundColor: SoftColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Action failed: $e"),
            backgroundColor: SoftColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _deleteVariant(String variantId) async {
    final updatedVariants = widget.product.variants
        .where((v) => v.id != variantId)
        .toList();

    final updatedProduct = widget.product.copyWith(variants: updatedVariants);

    try {
      await ref
          .read(inventoryRepositoryProvider)
          .updateProduct(updatedProduct, null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Variant deleted"),
            backgroundColor: SoftColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to delete variant: $e"),
            backgroundColor: SoftColors.error,
          ),
        );
      }
    }
  }

  void _confirmDeleteVariant(ProductVariant v) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: SoftColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SoftColors.cardRadius),
        ),
        title: Text(
          "Delete Variant?",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to delete '${v.name}'? This cannot be undone.",
          style: GoogleFonts.outfit(color: SoftColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              _deleteVariant(v.id);
            },
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
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...widget.product.variants.map((v) {
          final isLowStock =
              v.stockQuantity <= widget.product.lowStockThreshold;
          final isOutOfStock = v.stockQuantity <= 0;
          final pending = _pendingAdjustments[v.id] ?? 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SoftCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: SoftColors.bgLight,
                          borderRadius: BorderRadius.circular(12),
                          image: v.imagePath != null
                              ? DecorationImage(
                                  image: NetworkImage(v.imagePath!),
                                  fit: BoxFit.cover,
                                )
                              : (widget.product.imagePath != null
                                    ? DecorationImage(
                                        image: NetworkImage(
                                          widget.product.imagePath!,
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : null),
                        ),
                        child:
                            (v.imagePath == null &&
                                widget.product.imagePath == null)
                            ? const Icon(
                                Icons.layers_outlined,
                                size: 24,
                                color: SoftColors.textSecondary,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.name,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: SoftColors.textMain,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isOutOfStock
                                    ? SoftColors.error.withValues(alpha: 0.1)
                                    : (isLowStock
                                          ? SoftColors.warning.withValues(
                                              alpha: 0.1,
                                            )
                                          : SoftColors.brandPrimary.withValues(
                                              alpha: 0.1,
                                            )),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isOutOfStock
                                    ? "Out of stock"
                                    : (isLowStock
                                          ? "Low: ${v.stockQuantity}"
                                          : "${v.stockQuantity} in stock"),
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isOutOfStock
                                      ? SoftColors.error
                                      : (isLowStock
                                            ? SoftColors.warning
                                            : SoftColors.brandPrimary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Delete Icon
                      if (!widget.isEmployee)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: SoftColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => _confirmDeleteVariant(v),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Adjustable Row
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: SoftColors.bgLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          "Adjust Quantity",
                          style: GoogleFonts.outfit(
                            color: SoftColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(4), // Even padding
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _QtyBtn(
                                icon: Icons.remove,
                                onTap: _isUpdating
                                    ? () {}
                                    : () => _adjustQuantity(v.id, -1),
                              ),
                              SizedBox(
                                width: 32, // Smaller width
                                child: Text(
                                  "$pending",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16, // Smaller font
                                    color: pending == 0
                                        ? SoftColors.textMain
                                        : (pending < 0
                                              ? SoftColors.error
                                              : SoftColors.success),
                                  ),
                                ),
                              ),
                              _QtyBtn(
                                icon: Icons.add,
                                onTap: _isUpdating
                                    ? () {}
                                    : () => _adjustQuantity(v.id, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        if (_pendingAdjustments.isNotEmpty) ...[
          const SizedBox(height: 24),
          SoftButton(
            label: "Process Updates",
            onTap: _processAdjustments,
            isLoading: _isUpdating,
            backgroundColor: SoftColors.brandPrimary,
            textColor: Colors.white,
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: 32), // Bottom padding
        ],
      ],
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(10), // Bigger touch target
        child: Icon(icon, size: 20, color: SoftColors.brandPrimary),
      ),
    );
  }
}
