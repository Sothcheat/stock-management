import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/domain/product.dart';
import '../domain/order.dart';

class ProductSelectionScreen extends ConsumerStatefulWidget {
  const ProductSelectionScreen({super.key});

  @override
  ConsumerState<ProductSelectionScreen> createState() =>
      _ProductSelectionScreenState();
}

class _ProductSelectionScreenState
    extends ConsumerState<ProductSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onProductSelected(Product product) {
    if (product.totalStock <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Item out of stock")));
      return;
    }

    if (product.variants.isEmpty) {
      // No variants, directly add
      _showQuantityDialog(product, null);
    } else {
      // Show variant selection
      _showVariantSelection(product);
    }
  }

  void _showVariantSelection(Product product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SoftColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Select Variant",
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: SoftColors.textMain,
                ),
              ),
              const SizedBox(height: 24),
              ...product.variants.map(
                (v) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BounceButton(
                    onTap: () {
                      if (v.stockQuantity > 0) {
                        Navigator.pop(context);
                        _showQuantityDialog(product, v);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: v.stockQuantity > 0
                            ? Colors.white
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: SoftColors.textSecondary.withValues(
                            alpha: 0.1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            v.name,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: v.stockQuantity > 0
                                  ? SoftColors.textMain
                                  : SoftColors.textSecondary,
                            ),
                          ),
                          Text(
                            v.stockQuantity > 0
                                ? "${v.stockQuantity} available"
                                : "Out of Stock",
                            style: GoogleFonts.outfit(
                              color: v.stockQuantity > 0
                                  ? SoftColors.success
                                  : SoftColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showQuantityDialog(Product product, ProductVariant? variant) {
    int qty = 1;
    final maxStock = variant?.stockQuantity ?? product.totalStock;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: SoftColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SoftColors.cardRadius),
          ),
          title: Text(
            "Select Quantity",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    variant != null
                        ? "${product.name} (${variant.name})"
                        : product.name,
                    style: GoogleFonts.outfit(
                      color: SoftColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      BounceButton(
                        onTap: qty > 1 ? () => setState(() => qty--) : () {},
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: qty > 1
                                ? SoftColors.brandPrimary.withValues(alpha: 0.1)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.remove,
                            color: qty > 1
                                ? SoftColors.brandPrimary
                                : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Text(
                        "$qty",
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: SoftColors.textMain,
                        ),
                      ),
                      const SizedBox(width: 24),
                      BounceButton(
                        onTap: qty < maxStock
                            ? () => setState(() => qty++)
                            : () {},
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: qty < maxStock
                                ? SoftColors.brandPrimary.withValues(alpha: 0.1)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.add,
                            color: qty < maxStock
                                ? SoftColors.brandPrimary
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Max: $maxStock",
                    style: GoogleFonts.outfit(color: SoftColors.textSecondary),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                final item = OrderItem(
                  productId: product.id,
                  variantId: variant?.id,
                  variantName: variant?.name ?? 'Standard',
                  priceAtSale: product.finalPrice,
                  quantity: qty,
                  name: product.name,
                );
                context.pop(item); // Return the item to AddNewOrderScreen
              },
              child: Text(
                "Add",
                style: GoogleFonts.outfit(
                  color: SoftColors.brandPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);

    return SoftScaffold(
      title: 'Select Product',
      showBack: true,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: ModernInput(
              controller: _searchController,
              hintText: 'Search products...',
              prefixIcon: Icons.search_rounded,
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, child) {
                  return value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: SoftColors.textSecondary,
                          ),
                          onPressed: () => _searchController.clear(),
                        );
                },
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: productsAsync.when(
              data: (products) {
                final query = _searchController.text.toLowerCase();
                final filtered = products
                    .where((p) => p.name.toLowerCase().contains(query))
                    .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      "No products found",
                      style: GoogleFonts.outfit(
                        color: SoftColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: BounceButton(
                        onTap: () => _onProductSelected(product),
                        child: SoftCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: SoftColors.textMain.withValues(
                                    alpha: 0.05,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  image: product.imagePath != null
                                      ? DecorationImage(
                                          image: NetworkImage(
                                            product.imagePath!,
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: product.imagePath == null
                                    ? Icon(
                                        Icons.image_not_supported_rounded,
                                        color: SoftColors.textSecondary
                                            .withValues(alpha: 0.5),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: SoftColors.textMain,
                                      ),
                                    ),
                                    Text(
                                      "${product.totalStock} in stock",
                                      style: GoogleFonts.outfit(
                                        color: product.totalStock > 0
                                            ? SoftColors.success
                                            : SoftColors.error,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (product.finalPrice < product.price)
                                    Text(
                                      '\$${product.price.toStringAsFixed(2)}',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.normal,
                                        color: SoftColors.textSecondary,
                                        fontSize: 12,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  Text(
                                    "\$${product.finalPrice.toStringAsFixed(2)}",
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: SoftColors.brandPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text("Error: $e")),
            ),
          ),
        ],
      ),
    );
  }
}
