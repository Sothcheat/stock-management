import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/data/inventory_repository.dart';

class ProductDetailScreen extends ConsumerWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SoftScaffold(
      title: 'Product Details',
      showBack: true,
      actions: [
        BounceButton(
          onTap: () => context.go('/inventory/edit', extra: product),
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
                child: product.imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(
                          SoftColors.cardRadius,
                        ),
                        child: CachedNetworkImage(
                          imageUrl: product.imagePath!,
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
                    product.name,
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: SoftColors.textMain,
                    ),
                  ),
                ),
                Text(
                  '\$${product.price.toStringAsFixed(2)}',
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _DetailItem("Cost Price", "\$${product.costPrice}"),
                  _ContainerLine(),
                  _DetailItem("Stock", "${product.totalStock}"),
                  _ContainerLine(),
                  _DetailItem(
                    "Category",
                    product.categoryId.isEmpty ? "N/A" : product.categoryId,
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
              product.description.isEmpty
                  ? "No description available."
                  : product.description,
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: SoftColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Variants
            if (product.variants.isNotEmpty) ...[
              Text(
                "Variants",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: SoftColors.textMain,
                ),
              ),
              const SizedBox(height: 12),
              ...product.variants.map(
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
                      .deleteProduct(product.id);
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
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: SoftColors.textMain,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
