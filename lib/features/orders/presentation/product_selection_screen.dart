import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/domain/product.dart';
import '../domain/order.dart';

class ProductSelectionScreen extends ConsumerStatefulWidget {
  final List<OrderItem>? existingItems;
  const ProductSelectionScreen({super.key, this.existingItems});

  @override
  ConsumerState<ProductSelectionScreen> createState() =>
      _ProductSelectionScreenState();
}

class _ProductSelectionScreenState
    extends ConsumerState<ProductSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Basket State: Map<ProductId, OrderItem>
  // We use ProductId as key for simple items.
  // For variants, we might need composite key, but existing OrderItem has variantId.
  // Ideally key = "${product.id}_${variantId ?? 'base'}"
  final Map<String, OrderItem> _basket = {};

  @override
  void initState() {
    super.initState();
    if (widget.existingItems != null) {
      for (var item in widget.existingItems!) {
        final key = _getItemKey(item.productId, item.variantId);
        _basket[key] = item;
      }
    }
  }

  String _getItemKey(String productId, String? variantId) {
    return "${productId}_${variantId ?? 'base'}";
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addItem(Product product, ProductVariant? variant) {
    HapticFeedback.lightImpact();
    // Default Quantity 1
    final key = _getItemKey(product.id, variant?.id);

    // Check stock
    final maxStock = variant?.stockQuantity ?? product.totalStock;
    if (maxStock <= 0) {
      _showError("Out of Stock");
      return;
    }

    if (_basket.containsKey(key)) {
      // Already in basket, increment? Or just ignore?
      // User explicitly tapped "Add" again? Usually we toggle or increment.
      // Let's increment.
      _updateQuantity(key, _basket[key]!.quantity + 1, maxStock);
    } else {
      setState(() {
        _basket[key] = OrderItem(
          productId: product.id,
          variantId: variant?.id,
          variantName: variant?.name ?? 'Standard',
          priceAtSale: product.finalPrice, // Simplified for now
          quantity: 1,
          name: product.name,
          // We'll need to fetch image URL if we want it in OrderItem,
          // but OrderItem definition usually relies on Product ID lookup for image.
          // Assuming OrderItem struct matches.
        );
      });
    }
  }

  void _updateQuantity(String key, int newQty, int maxStock) {
    if (newQty > maxStock) {
      HapticFeedback.mediumImpact();
      // Tooltip or subtle feedback handled by UI usually, but let's just cap it.
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      if (newQty <= 0) {
        _basket.remove(key);
      } else {
        final item = _basket[key]!;
        _basket[key] = item.copyWith(quantity: newQty);
      }
    });
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _onProductTap(Product product) {
    // If has variants, show variant sheet.
    // If simple, check if in basket.
    // If in basket -> Do nothing? Or scroll to bottom?
    // Actually, usually tapping adds 1 or toggles.
    // Implementation: tap adds 1 if not present. If present, maybe show detailed edit?
    // Let's stick to simple: Tap adds 1 if not present. If present, it just focuses user on the quantity controls on the card.

    if (product.variants.isNotEmpty) {
      _showVariantSelection(product);
      return;
    }

    // Simple Product
    final key = _getItemKey(product.id, null);
    if (!_basket.containsKey(key)) {
      _addItem(product, null);
    }
    // If already exists, user uses +/- buttons on card.
  }

  void _showVariantSelection(Product product) async {
    // 1. Build initial selections from current basket
    final Map<String, int> initialSelections = {};
    for (var v in product.variants) {
      final key = _getItemKey(product.id, v.id);
      if (_basket.containsKey(key)) {
        initialSelections[v.id] = _basket[key]!.quantity;
      }
    }

    final result = await showModalBottomSheet<Map<String, int>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: false,
      builder: (context) => _VariantSelectorSheet(
        product: product,
        initialSelections: initialSelections,
      ),
    );

    if (result != null) {
      // Apply selections (Override/Sync)
      result.forEach((variantId, qty) {
        final variant = product.variants.firstWhere((v) => v.id == variantId);
        final key = _getItemKey(product.id, variantId);

        // SYNC LOGIC:
        // Always update to the returned quantity.
        // If qty is 0, _updateQuantity handles removal (via <= 0 check).

        final maxStock = variant.stockQuantity;
        // Check if basket has it or not to decide add vs update?
        // _updateQuantity handles removal if exists.
        // If doesn't exist and qty > 0, we add.
        // If doesn't exist and qty == 0, we do nothing.

        if (_basket.containsKey(key)) {
          _updateQuantity(key, qty, maxStock);
        } else if (qty > 0) {
          _addItemWithQty(product, variant, qty);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final basketTotal = _basket.values.fold(
      0.0,
      (sum, item) => sum + (item.priceAtSale * item.quantity),
    );
    final basketCount = _basket.values.fold(
      0,
      (sum, item) => sum + item.quantity,
    );

    return SoftScaffold(
      title: 'Select Products',
      showBack: true,

      // Allow custom back behavior? No, default back is fine, implies cancel.
      // But we should probably warn if basket not empty? User requirement said "Navigate back only on Confirm".
      // We'll leave default back for "Cancel" (discard changes).
      body: Stack(
        children: [
          Column(
            children: [
              // Sticky Search Bar
              Container(
                color: SoftColors.background,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: ModernInput(
                  controller: _searchController,
                  hintText: 'Search products...',
                  prefixIcon: Icons.search_rounded,
                  showClearButton: true,
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
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        24,
                        0,
                        24,
                        100,
                      ), // padding for bottom bar
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        // Logic for generic product card
                        // For products with variants, this is tricky as one product line might mean multiple basket items.
                        // We will just show the main product card.
                        // If it has variants, we don't show inline qty controls on the main card easily unless we list variants.
                        // Simplified: If variants, card is "Add Variant" button.
                        // If no variants, card shows inline quantity controls if in basket. // Logic check

                        // Check if simple product is in basket
                        final simpleKey = _getItemKey(product.id, null);
                        final OrderItem? basketItem = product.variants.isEmpty
                            ? _basket[simpleKey]
                            : null;

                        return _buildProductCard(product, basketItem);
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text("Error: $e")),
                ),
              ),
            ],
          ),

          // Basket Preview Bar
          if (basketCount > 0)
            Positioned(
              left: 24,
              right: 24,
              bottom: 24, // Safe Area calculated?
              child: SafeArea(
                child: BounceButton(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    context.pop(_basket.values.toList());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: SoftColors.brandPrimary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: SoftColors.brandPrimary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "$basketCount Items",
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "\$${basketTotal.toStringAsFixed(2)}",
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            setState(() {
                              _basket.clear();
                            });
                          },
                          child: Text(
                            "Clear",
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "Confirm",
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product, OrderItem? basketItem) {
    final hasVariants = product.variants.isNotEmpty;
    final stock = product.totalStock;

    // Inline Controls for Simple Products
    Widget actionWidget;
    if (hasVariants) {
      actionWidget = const Icon(
        Icons.add_circle_outline,
        color: SoftColors.brandPrimary,
      );
    } else {
      if (basketItem != null) {
        // In Basket: Show - Qty +
        actionWidget = Container(
          decoration: BoxDecoration(
            color: SoftColors.brandPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QtyBtn(
                icon: Icons.remove,
                onTap: () => _updateQuantity(
                  _getItemKey(product.id, null),
                  basketItem.quantity - 1,
                  stock,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  "${basketItem.quantity}",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: SoftColors.brandPrimary,
                  ),
                ),
              ),
              _QtyBtn(
                icon: Icons.add,
                onTap: basketItem.quantity < stock
                    ? () => _updateQuantity(
                        _getItemKey(product.id, null),
                        basketItem.quantity + 1,
                        stock,
                      )
                    : () {
                        // Disabled feedback
                      },
              ),
            ],
          ),
        );
      } else {
        // Not in Basket: Show Add Button or Out of Stock
        if (stock > 0) {
          actionWidget = const Icon(
            Icons.add_circle_outline, // Standardized Icon
            color: SoftColors.brandPrimary,
            size: 24,
          );
        } else {
          actionWidget = Text(
            "Out of Stock",
            style: GoogleFonts.outfit(
              color: SoftColors.error,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          );
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BounceButton(
        onTap: () => _onProductTap(product),
        child: SoftCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: SoftColors.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  image: product.imagePath != null
                      ? DecorationImage(
                          image: NetworkImage(product.imagePath!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: product.imagePath == null
                    ? Icon(
                        Icons.inventory_2_outlined,
                        color: SoftColors.brandPrimary.withValues(alpha: 0.5),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "\$${product.finalPrice.toStringAsFixed(2)}",
                      style: GoogleFonts.outfit(
                        color: SoftColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              actionWidget,
            ],
          ),
        ),
      ),
    );
  }

  void _addItemWithQty(Product product, ProductVariant variant, int qty) {
    final key = _getItemKey(product.id, variant.id);
    setState(() {
      _basket[key] = OrderItem(
        productId: product.id,
        variantId: variant.id,
        variantName: variant.name,
        priceAtSale: product.finalPrice,
        quantity: qty,
        name: product.name,
      );
    });
  }
}

class _VariantSelectorSheet extends StatefulWidget {
  final Product product;
  final Map<String, int> initialSelections; // Persistence

  const _VariantSelectorSheet({
    required this.product,
    this.initialSelections = const {},
  });

  @override
  State<_VariantSelectorSheet> createState() => _VariantSelectorSheetState();
}

class _VariantSelectorSheetState extends State<_VariantSelectorSheet> {
  final Map<String, int> _selections = {};

  @override
  void initState() {
    super.initState();
    // Initialize from parent
    _selections.addAll(widget.initialSelections);
  }

  int get totalSelected => _selections.values.fold(0, (sum, q) => sum + q);

  // Helper to know if we are in "Update" mode
  bool get isUpdateMode => widget.initialSelections.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: SoftColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SoftColors.textSecondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Select Variants",
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: SoftColors.textMain,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            "Adjust quantities for ${widget.product.name}",
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: SoftColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          Expanded(
            child: ListView.separated(
              itemCount: widget.product.variants.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final v = widget.product.variants[index];
                final isOutOfStock = v.stockQuantity <= 0;
                final qty = _selections[v.id] ?? 0;

                // UI Feedback: Highlight if already selected (Active in cart originally)
                final wasSelectedOriginally =
                    widget.initialSelections.containsKey(v.id) &&
                    widget.initialSelections[v.id]! > 0;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      // Highlight logic
                      color: wasSelectedOriginally
                          ? SoftColors.brandPrimary
                          : SoftColors.border.withValues(alpha: 0.5),
                      width: wasSelectedOriginally ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Thumbnail Fallback
                      Container(
                        width: 48,
                        height: 48,
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
                                color: SoftColors.textSecondary,
                                size: 20,
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
                                fontWeight: FontWeight.bold,
                                color: isOutOfStock
                                    ? SoftColors.textSecondary
                                    : SoftColors.textMain,
                                decoration: isOutOfStock
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            Text(
                              isOutOfStock
                                  ? "Sold Out"
                                  : "${v.stockQuantity} available",
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: isOutOfStock
                                    ? SoftColors.error
                                    : SoftColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isOutOfStock)
                        Container(
                          decoration: BoxDecoration(
                            color: SoftColors.bgLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              _QtyBtn(
                                icon: Icons.remove,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  if (qty > 0) {
                                    setState(() {
                                      _selections[v.id] = qty - 1;
                                    });
                                  }
                                },
                              ),
                              SizedBox(
                                width: 32,
                                child: Text(
                                  "$qty",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: SoftColors.textMain,
                                  ),
                                ),
                              ),
                              _QtyBtn(
                                icon: Icons.add,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  if (qty < v.stockQuantity) {
                                    setState(() {
                                      _selections[v.id] = qty + 1;
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
              },
            ),
          ),
          const SizedBox(height: 16),
          SafeButton(
            // Dynamic Label
            label: isUpdateMode
                ? "Update Selection ($totalSelected)"
                : "Add Selected ($totalSelected)",
            // Allow update even if 0 if we are in update mode (clearing)
            onTap: (totalSelected > 0 || isUpdateMode)
                ? () => Navigator.pop(context, _selections)
                : null,
            backgroundColor: (totalSelected > 0 || isUpdateMode)
                ? SoftColors.brandPrimary
                : SoftColors.textSecondary.withValues(alpha: 0.2),
            textColor: (totalSelected > 0 || isUpdateMode)
                ? Colors.white
                : SoftColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class SafeButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color textColor;

  const SafeButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (onTap != null) {
      return BounceButton(
        onTap: onTap!,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: textColor,
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: textColor,
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 18, color: SoftColors.brandPrimary),
      ),
    );
  }
}
