import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Select Variant",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...product.variants.map(
                (v) => ListTile(
                  title: Text(v.name),
                  trailing: Text("${v.stockQuantity} available"),
                  enabled: v.stockQuantity > 0,
                  onTap: () {
                    Navigator.pop(context);
                    _showQuantityDialog(product, v);
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

  void _showQuantityDialog(Product product, ProductVariant? variant) {
    int qty = 1;
    final maxStock = variant?.stockQuantity ?? product.totalStock;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Select Quantity"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    variant != null
                        ? "${product.name} (${variant.name})"
                        : product.name,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: qty > 1 ? () => setState(() => qty--) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        "$qty",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: qty < maxStock
                            ? () => setState(() => qty++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  Text(
                    "Max: $maxStock",
                    style: const TextStyle(color: Colors.grey),
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
                  priceAtSale: product
                      .price, // Using standard price, could add discount logic later
                  quantity: qty,
                  name: product.name,
                );
                context.pop(item); // Return the item to AddNewOrderScreen
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Product'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    return ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[200],
                        child: product.imagePath != null
                            ? Image.network(
                                product.imagePath!,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.image),
                      ),
                      title: Text(product.name),
                      subtitle: Text(
                        "\$${product.price} • ${product.totalStock} in stock",
                      ),
                      onTap: () => _onProductSelected(product),
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
