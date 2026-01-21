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
                        color: SoftColors.textSecondary.withValues(alpha: 0.3),
                        size: 40,
                      ),
              ),
            ),
            // Details Area
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Price (Dominant)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (product.finalPrice < product.price)
                            Text(
                              '\$${product.price.toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.normal,
                                color: SoftColors.textSecondary,
                                fontSize: 10, // Smaller strikethrough
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          Text(
                            '\$${product.finalPrice.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700, // SemiBold -> Bold
                              color: SoftColors.brandPrimary,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Stock Badge (Secondary)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: product.totalStock <= product.lowStockThreshold
                              ? SoftColors.error.withValues(alpha: 0.1)
                              : SoftColors.textSecondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.totalStock <= product.lowStockThreshold
                              ? 'Low: ${product.totalStock}'
                              : 'Stock: ${product.totalStock}',
                          style: GoogleFonts.outfit(
                            color:
                                product.totalStock <= product.lowStockThreshold
                                ? SoftColors.error
                                : SoftColors.textMain,
                            fontSize: 12, // Increased from 10
                            fontWeight: FontWeight.w600,
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
