import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart'; // Added for HapticFeedback
import '../../../../design_system.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/data/providers/auth_providers.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/domain/category.dart';
import '../data/providers/category_provider.dart';
import 'providers/inventory_filter_provider.dart';
import 'providers/quick_sale_provider.dart';
import 'providers/last_sale_provider.dart';
import '../../orders/data/firebase_orders_repository.dart';
import '../../orders/domain/order.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isProcessingBatch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSortSheet() {
    // ... (Existing implementation kept via partial match or just referenced if unchanged)
    // Actually I can just leave this method alone if I don't target it.
    // I'm replacing the class and build method primarily or just specific sections.
    // Let's use specific replacements.
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

  Future<void> _processBatchSale(
    Map<String, int> cartItems,
    List<Product> products,
  ) async {
    // Stock Validation
    for (final entry in cartItems.entries) {
      final product = products.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => Product(
          id: entry.key,
          name: 'Unknown',
          description: 'Unknown',
          manualStock: 0,
          price: 0,
          costPrice: 0,
          variants: [],
          createdAt: DateTime.now(),
          categoryId: '',
        ),
      );
      if (product.name != 'Unknown' && product.totalStock < entry.value) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Insufficient stock for ${product.name}"),
              backgroundColor: SoftColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    setState(() => _isProcessingBatch = true);
    try {
      final List<OrderItem> batchItems = [];
      for (final entry in cartItems.entries) {
        final product = products.firstWhere(
          (p) => p.id == entry.key,
          orElse: () => Product(
            id: entry.key,
            name: 'Unknown',
            description: 'Unknown',
            manualStock: 0,
            price: 0,
            costPrice: 0,
            variants: [],
            createdAt: DateTime.now(),
            categoryId: '',
          ),
        );
        if (product.name != 'Unknown') {
          batchItems.add(
            OrderItem(
              productId: product.id,
              name: product.name,
              variantName: '',
              quantity: entry.value,
              priceAtSale: product.price,
              costPriceAtSale: product.costPrice,
            ),
          );
        }
      }

      // Execute Sale
      final orderId = await ref
          .read(ordersRepositoryProvider)
          .createBatchQuickSale(batchItems);

      // Update Last Sale Provider
      if (mounted) {
        final desc = batchItems.length == 1
            ? "${batchItems.first.name} x${batchItems.first.quantity}"
            : "${batchItems.first.name} +${batchItems.length - 1} others";
        ref.read(lastSaleProvider.notifier).setLastSale(orderId, desc);
      }

      if (mounted) {
        ref.read(quickSaleCartProvider.notifier).clearCart();

        ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Fix persistence

        // Show Smart Undo SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Sold ${batchItems.length} items",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: SoftColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4), // Explicit duration
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            action: SnackBarAction(
              label: "UNDO",
              textColor: Colors.white,
              onPressed: () async {
                ref
                    .read(lastSaleProvider.notifier)
                    .clear(); // Clear provider if manually undone
                // Trigger Revert
                try {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Reverting order...",
                            style: GoogleFonts.outfit(),
                          ),
                        ],
                      ),
                      backgroundColor: SoftColors.textMain,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2), // Short lived
                    ),
                  );

                  await ref
                      .read(ordersRepositoryProvider)
                      .revertQuickSaleOrder(orderId);

                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Order reversed. Stock restored.",
                          style: GoogleFonts.outfit(),
                        ),
                        backgroundColor: SoftColors.textMain,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Undo failed: $e. Please verify stock manually.",
                          style: GoogleFonts.outfit(),
                        ),
                        backgroundColor: SoftColors.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: SoftColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingBatch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredInventoryAsync = ref.watch(filteredInventoryProvider);
    final selectedCategoryId = ref
        .watch(inventoryFilterProvider)
        .selectedCategoryId;
    final cart = ref.watch(quickSaleCartProvider); // Watch Cart
    final totalQty = ref.read(quickSaleCartProvider.notifier).totalQuantity;

    return SoftScaffold(
      title: 'Inventory',
      floatingActionButton: cart.isNotEmpty
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Clear Button
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton.icon(
                    onPressed: () {
                      if (cart.length > 3) {
                        // Safety Dialog
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              "Clear Cart?",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: const Text(
                              "Are you sure you want to remove all items?",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(quickSaleCartProvider.notifier)
                                      .clearCart();
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                  "Clear All",
                                  style: TextStyle(color: SoftColors.error),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        ref.read(quickSaleCartProvider.notifier).clearCart();
                      }
                    },
                    icon: const Icon(
                      Icons.close,
                      color: SoftColors.textSecondary,
                    ),
                    label: Text(
                      "Clear",
                      style: GoogleFonts.outfit(
                        color: SoftColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      backgroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                FloatingActionButton.extended(
                  heroTag: 'checkout_fab',
                  onPressed: _isProcessingBatch
                      ? null
                      : () {
                          // Need access to products list to map IDs to Objects
                          filteredInventoryAsync.whenData((products) {
                            _processBatchSale(cart, products);
                          });
                        },
                  backgroundColor: SoftColors.brandPrimary,
                  foregroundColor: Colors.white,
                  icon: _isProcessingBatch
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.shopping_cart_checkout_rounded),
                  label: Text(
                    _isProcessingBatch
                        ? "Processing..."
                        : "Process $totalQty Items",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            )
          : (ref.watch(currentUserProfileProvider).value?.role ==
                    UserRole.employee
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
                  )),
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
                          color: SoftColors.textMain.withValues(alpha: 0.05),
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
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
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
                              HapticFeedback.lightImpact();
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
                  error: (error, stack) => const SizedBox.shrink(),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Last Sale Indicator (Safety Net)
          Consumer(
            builder: (context, ref, _) {
              final lastSale = ref.watch(lastSaleProvider);
              if (lastSale == null) return const SizedBox.shrink();

              return GestureDetector(
                onTap: _isProcessingBatch
                    ? null
                    : () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              "Undo Last Sale?",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Text(
                              "Revert: ${lastSale.description}? This will restore stock.",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  ref.read(lastSaleProvider.notifier).clear();
                                  try {
                                    await ref
                                        .read(ordersRepositoryProvider)
                                        .revertQuickSaleOrder(lastSale.orderId);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Undo Successful",
                                            style: GoogleFonts.outfit(),
                                          ),
                                          backgroundColor: SoftColors.success,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text("Undo failed: $e"),
                                          backgroundColor: SoftColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: const Text(
                                  "Confirm Undo",
                                  style: TextStyle(color: SoftColors.error),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: SoftColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: SoftColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.history,
                        size: 16,
                        color: SoftColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Last Sale: ${lastSale.description} (Tap to Undo)",
                        style: GoogleFonts.outfit(
                          color: SoftColors.textMain,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Product Grid
          Expanded(
            child: filteredInventoryAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return Center(
                    child: SoftAnimatedEmpty(
                      icon: Icons.inventory_2_outlined,
                      message: 'No products found',
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
                    return SoftFadeInSlide(
                      index: index,
                      child: _ProductCard(product: product),
                    );
                  },
                );
              },
              loading: () => Center(child: SoftShimmer.productCard()),
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

  void _showQuantitySheet(BuildContext context, WidgetRef ref) {
    // This needs state management for the input.
    // Since ProductCard is stateless, we can just use a StatefulBuilder in standard bottom sheet
    // OR create a simple widget.
    // We already have `ModernInput`.

    final currentQty = ref.read(quickSaleCartProvider)[product.id] ?? 1;
    final controller = TextEditingController(text: currentQty.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                product.name,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    onPressed: () {
                      final v = int.tryParse(controller.text) ?? 1;
                      if (v > 1) {
                        controller.text = (v - 1).toString();
                      }
                    },
                    icon: const Icon(Icons.remove),
                  ),
                  Container(
                    width: 100,
                    height: 70, // Match visual weight of buttons + padding
                    alignment: Alignment.center,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: SoftColors.bgLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      maxLines: 1,
                      style: GoogleFonts.outfit(
                        fontSize: 32, // Slightly larger
                        fontWeight: FontWeight.bold,
                        color: SoftColors.textMain,
                        height: 1.0, // Fix line-height offset
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.zero, // Crucial for true centering
                        isDense: true,
                        isCollapsed: true,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () {
                      final v = int.tryParse(controller.text) ?? 1;
                      controller.text = (v + 1).toString();
                    },
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: SoftButton(
                  label: "Update Quantity",
                  onTap: () {
                    final newQty = int.tryParse(controller.text) ?? 1;
                    if (newQty > product.totalStock) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Insufficient stock (Max: ${product.totalStock})",
                          ),
                          backgroundColor: SoftColors.error,
                        ),
                      );
                      return;
                    }
                    ref
                        .read(quickSaleCartProvider.notifier)
                        .updateQuantity(product.id, newQty);
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOutOfStock = product.totalStock <= 0;
    final isLowStock =
        !isOutOfStock && product.totalStock <= product.lowStockThreshold;

    final cartQty = ref.watch(quickSaleCartProvider)[product.id] ?? 0;
    final isInCart = cartQty > 0;

    return BounceButton(
      onTap: () {
        // Tap -> Toggle Selection if Mode Active OR if user wants to start Mode?
        // "One tap to select, another to deselect."
        // "If Quick Sale Mode is active... tap acts as Add" (Old requirement).
        // New requirement: "Toggle Selection Logic".
        // If Cart is Empty:
        //    Tap -> Open Detail? Or Add (Start Mode)?
        //    Let's check implementation plan: "Use toggleItem on Tap...".
        //    If I Tap and it's not in cart -> Added. Mode Starts.
        //    So Detail Screen is reachable ONLY if I don't tap?
        //    Or Long Press?
        //    Usually, "Selection Mode" is entered via Long Press.
        //    But prompt says "One tap to select...".
        //    If selection is primary, Detail is secondary.
        //    Let's check if Detail is important.
        //    "Update ProductCard: Use toggleItem on Tap."
        //    Okay, I will replace the Detail navigation on Tap with Toggle.
        //    Wait, what if they want seeing details?
        //    User said "If Quick Sale Mode is active...".
        //    Maybe:
        //      If Mode Active -> Tap Toggle.
        //      If Mode Inactive -> Tap Detail?
        //    But "One tap to select" suggests easy selection.
        //    I'll implement:
        //      If Mode Active -> Tap Toggles.
        //      If Mode Inactive -> Tap Details.
        //      Long Press -> Adds to Cart (Starts Mode) & Shows Quantity Sheet.
        //    Actually, "Long-Press Menu... for editing quantities".
        //    So:
        //      Tap: Detail (if inactive), Toggle (if active).
        //      Long Press: Add/Edit Qty (Always starts/edits mode).

        final isBatchMode = ref.read(quickSaleCartProvider).isNotEmpty;

        if (isBatchMode) {
          HapticFeedback.selectionClick();
          ref.read(quickSaleCartProvider.notifier).toggleItem(product);
        } else {
          // Standard Nav
          context.go('/inventory/detail', extra: product);
        }
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        // If not in cart, add it first?
        final currentQty = ref.read(quickSaleCartProvider)[product.id] ?? 0;
        if (currentQty == 0) {
          // Add to cart (select)
          if (product.totalStock > 0) {
            ref.read(quickSaleCartProvider.notifier).addToCart(product);
            // And show sheet?
            _showQuantitySheet(context, ref);
          } else {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("Out of Stock")));
          }
        } else {
          // Already in cart, edit qty
          _showQuantitySheet(context, ref);
        }
      },
      child: Stack(
        children: [
          SoftCard(
            padding: EdgeInsets.zero,
            child: Container(
              foregroundDecoration: isInCart
                  ? BoxDecoration(
                      color: SoftColors.brandPrimary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(
                        SoftColors.cardRadius,
                      ),
                      border: Border.all(
                        color: SoftColors.brandPrimary,
                        width: 2,
                      ),
                    )
                  : null,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '\$${product.price.toStringAsFixed(2)}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            decoration:
                                                TextDecoration.lineThrough,
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
                                          ? SoftColors.warning.withValues(
                                              alpha: 0.1,
                                            )
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
          ),

          // Selection Badge Overlay
          if (isInCart)
            Positioned(
              top: 8,
              right: 8,
              child: AnimatedScale(
                scale: 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: SoftColors.brandPrimary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        "$cartQty",
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
