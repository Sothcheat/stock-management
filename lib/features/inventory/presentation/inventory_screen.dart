import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/data/providers/auth_providers.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/domain/category.dart';
import '../data/providers/category_provider.dart';
import 'providers/inventory_filter_provider.dart';

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

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final currentSort = ref.watch(inventoryFilterProvider).sortOption;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Sort By",
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: SoftColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSortOption(
                    context,
                    ref,
                    "Default (Stock Priority)",
                    InventorySortOption.defaultSort,
                    currentSort,
                  ),
                  _buildSortOption(
                    context,
                    ref,
                    "Name (A-Z)",
                    InventorySortOption.nameAsc,
                    currentSort,
                  ),
                  _buildSortOption(
                    context,
                    ref,
                    "Price (High - Low)",
                    InventorySortOption.priceHighLow,
                    currentSort,
                  ),
                  _buildSortOption(
                    context,
                    ref,
                    "Price (Low - High)",
                    InventorySortOption.priceLowHigh,
                    currentSort,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortOption(
    BuildContext context,
    WidgetRef ref,
    String label,
    InventorySortOption option,
    InventorySortOption current,
  ) {
    final isSelected = option == current;
    return InkWell(
      onTap: () {
        ref.read(inventoryFilterProvider.notifier).setSortOption(option);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? SoftColors.brandPrimary
                  : SoftColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? SoftColors.textMain
                    : SoftColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredInventoryAsync = ref.watch(filteredInventoryProvider);
    final selectedCategoryId = ref
        .watch(inventoryFilterProvider)
        .selectedCategoryId;

    return SoftScaffold(
      title: 'Inventory',
      floatingActionButton:
          ref.watch(currentUserProfileProvider).value?.role == UserRole.employee
          ? null
          : FloatingActionButton.extended(
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
      body: Column(
        children: [
          // Search Bar & Sort Button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: ModernInput(
                    controller: _searchController,
                    hintText: 'Search products...',
                    prefixIcon: Icons.search,
                    onChanged: (val) {
                      ref
                          .read(inventoryFilterProvider.notifier)
                          .setSearchQuery(val);
                    },
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: SoftColors.textSecondary,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(inventoryFilterProvider.notifier)
                                  .setSearchQuery('');
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                BounceButton(
                  onTap: _showSortSheet,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: SoftColors.textMain.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.filter_list_rounded,
                      color: SoftColors.brandPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Category Chips
          SizedBox(
            height: 50,
            child: Consumer(
              builder: (context, ref, child) {
                final categoriesAsync = ref.watch(categoryListProvider);
                return categoriesAsync.when(
                  data: (categories) {
                    final allCategories = [
                      // "All" pseudo-category
                      Category(id: 'all', name: 'All', icon: ''),
                      ...categories,
                    ];

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      scrollDirection: Axis.horizontal,
                      itemCount: allCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = allCategories[index];
                        final isAll = cat.id == 'all';
                        final isSelected = isAll
                            ? selectedCategoryId == null
                            : selectedCategoryId == cat.id;

                        return ChoiceChip(
                          showCheckmark: true,
                          checkmarkColor: Colors.white,
                          label: Text(cat.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              ref
                                  .read(inventoryFilterProvider.notifier)
                                  .selectCategory(isAll ? null : cat.id);
                            }
                          },
                          selectedColor: SoftColors.brandPrimary,
                          backgroundColor: Colors.white,
                          labelStyle: GoogleFonts.outfit(
                            color: isSelected
                                ? Colors.white
                                : SoftColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.transparent
                                  : SoftColors.textSecondary.withValues(
                                      alpha: 0.1,
                                    ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Product Grid
          Expanded(
            child: filteredInventoryAsync.when(
              data: (products) {
                if (products.isEmpty) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _ProductCard(product: product);
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

class _ProductCard extends ConsumerWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOutOfStock = product.totalStock <= 0;
    final isLowStock =
        !isOutOfStock && product.totalStock <= product.lowStockThreshold;

    return BounceButton(
      onTap: () {
        context.go('/inventory/detail', extra: product);
      },
      child: SoftCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Area (Square)
            AspectRatio(
              aspectRatio: 1,
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
                        child: product.hasDiscount
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '\$${product.price.toStringAsFixed(2)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.lineThrough,
                                      color: SoftColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '\$${product.finalPrice.toStringAsFixed(2)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: SoftColors.brandPrimary,
                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
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
