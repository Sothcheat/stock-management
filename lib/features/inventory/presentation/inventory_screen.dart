import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system.dart';
import '../../products/data/providers/product_provider.dart';
import '../../inventory/domain/product.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // SWITCHED TO NEW PROVIDER
    final productsAsync = ref.watch(productsProvider);

    return SoftScaffold(
      title: 'Inventory',
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'inventory_fab',
        onPressed: () {
          context.go('/inventory/add');
        },
        backgroundColor: SoftColors.brandPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          "New Product",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: ModernInput(
              controller: _searchController,
              hintText: 'Search products...',
              prefixIcon: Icons.search,
              suffixIcon: ValueListenableBuilder(
                valueListenable: _searchController,
                builder: (context, value, child) {
                  return value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: SoftColors.textSecondary,
                          ),
                          onPressed: () {
                            _searchController.clear();
                          },
                        );
                },
              ),
              onChanged: (val) => setState(() {}),
            ),
          ),

          // Product Grid
          Expanded(
            child: productsAsync.when(
              data: (products) {
                final query = _searchController.text.toLowerCase();
                final filteredProducts = products.where((p) {
                  return p.name.toLowerCase().contains(query) ||
                      p.id.contains(query);
                }).toList();

                if (filteredProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 60,
                          color: SoftColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No products found",
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            color: SoftColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.70,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filteredProducts.length,
                  // Performance optimization: cacheExtent could be added if list is huge
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return _ProductCard(product: product);
                  },
                );
              },
              // Shimmer Loading State (Performance Test)
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text("Error: $e")),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOutOfStock = product.totalStock <= 0;
    final isLowStock = !isOutOfStock && product.totalStock < 10;

    return BounceButton(
      onTap: () {
        context.go('/inventory/detail', extra: product);
      },
      child: SoftCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Area
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(SoftColors.cardRadius),
                ),
                child: Container(
                  width: double.infinity,
                  color: SoftColors.textSecondary.withValues(alpha: 0.05),
                  child: product.imagePath != null
                      ? CachedNetworkImage(
                          imageUrl: product.imagePath!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: SoftColors.bgLight,
                            child: const Icon(
                              Icons.image,
                              color: SoftColors.textSecondary,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: SoftColors.bgLight,
                            child: Icon(
                              Icons.broken_image_rounded,
                              color: SoftColors.textSecondary.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        )
                      : Icon(
                          Icons.image_not_supported_rounded,
                          color: SoftColors.textSecondary.withValues(
                            alpha: 0.3,
                          ),
                          size: 40,
                        ),
                ),
              ),
            ),
            // Details Area
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: SoftColors.textMain,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Price & Stock Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment:
                        CrossAxisAlignment.center, // Better alignment
                    children: [
                      // Price
                      Flexible(
                        child: Text(
                          '\$${product.price.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: SoftColors.brandPrimary,
                            height: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Stock Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isOutOfStock
                              ? SoftColors.error.withValues(alpha: 0.1)
                              : (isLowStock
                                    ? SoftColors.warning.withValues(alpha: 0.1)
                                    : SoftColors.success.withValues(
                                        alpha: 0.1,
                                      )),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isOutOfStock
                                ? SoftColors.error.withValues(alpha: 0.2)
                                : (isLowStock
                                      ? SoftColors.warning.withValues(
                                          alpha: 0.2,
                                        )
                                      : SoftColors.success.withValues(
                                          alpha: 0.2,
                                        )),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isOutOfStock
                              ? 'No Stock'
                              : (isLowStock
                                    ? 'Low: ${product.totalStock}'
                                    : 'Stock: ${product.totalStock}'),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isOutOfStock
                                ? SoftColors.error
                                : (isLowStock
                                      ? SoftColors.warning
                                      : SoftColors.success),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
