import 'package:flutter/material.dart';

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
      return const SizedBox.shrink(); // Hide if empty
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[800]),
              const SizedBox(width: 8),
              Text(
                "Low Stock Alert",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[900],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140, // Height for horizontal cards
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: dummyLowStock.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = dummyLowStock[index];
              return Container(
                width: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.image_not_supported,
                      size: 40,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['name'],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${item['stock']} left",
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
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
