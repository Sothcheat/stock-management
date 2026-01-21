import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system.dart';

class LowStockList extends StatelessWidget {
  const LowStockList({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder list for now
    final List<Map<String, dynamic>> dummyLowStock = [
      {'name': 'ATK Mouse (White)', 'stock': 2, 'image': ''},
      {'name': 'Mechanical Keycaps', 'stock': 4, 'image': ''},
      {'name': 'USB-C Cable', 'stock': 1, 'image': ''},
    ];

    if (dummyLowStock.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: SoftColors.warning,
              ),
              const SizedBox(width: 8),
              Text(
                "Low Stock Alert",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: SoftColors.textMain,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: dummyLowStock.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final item = dummyLowStock[index];
              return Container(
                width: 130,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: SoftColors.warning.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: SoftColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported_rounded,
                      size: 32,
                      color: SoftColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        item['name'],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: SoftColors.textMain,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: SoftColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${item['stock']} left",
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: SoftColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
