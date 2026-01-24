import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../products/data/providers/product_provider.dart';
import '../../../inventory/domain/product.dart';

part 'inventory_filter_provider.g.dart';

enum InventorySortOption {
  defaultSort, // Priority: OutOfStock > LowStock > Name
  nameAsc,
  priceHighLow,
  priceLowHigh,
}

class InventoryFilterState {
  final String searchQuery;
  final String? selectedCategoryId; // null means 'All'
  final InventorySortOption sortOption;

  const InventoryFilterState({
    this.searchQuery = '',
    this.selectedCategoryId,
    this.sortOption = InventorySortOption.defaultSort,
  });

  InventoryFilterState copyWith({
    String? searchQuery,
    String? selectedCategoryId,
    InventorySortOption? sortOption,
  }) {
    return InventoryFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryId:
          selectedCategoryId ??
          this.selectedCategoryId, // Treat null as specific value if passed? No, copying null is tricky.
      // Actually, for copyWith, we usually want to allow setting to null.
      // But here simpler: if argument is absent, keep old.
      // To set null, we might need a specific sentinel or just use a specialized method.
      // For simplicity, let's assume selectedCategoryId is usually set explicitly.
      // We'll handle nullable update carefully.
      sortOption: sortOption ?? this.sortOption,
    );
  }
}

@riverpod
class InventoryFilter extends _$InventoryFilter {
  @override
  InventoryFilterState build() {
    return const InventoryFilterState();
  }

  void setSearchQuery(String query) {
    state = InventoryFilterState(
      searchQuery: query,
      selectedCategoryId: state.selectedCategoryId,
      sortOption: state.sortOption,
    );
  }

  void selectCategory(String? categoryId) {
    state = InventoryFilterState(
      searchQuery: state.searchQuery,
      selectedCategoryId: categoryId,
      sortOption: state.sortOption,
    );
  }

  void setSortOption(InventorySortOption option) {
    state = InventoryFilterState(
      searchQuery: state.searchQuery,
      selectedCategoryId: state.selectedCategoryId,
      sortOption: option,
    );
  }
}

@riverpod
AsyncValue<List<Product>> filteredInventory(Ref ref) {
  final allProductsAsync = ref.watch(productsProvider);
  final filterState = ref.watch(inventoryFilterProvider);

  return allProductsAsync.whenData((products) {
    // 1. Filter
    var filtered = products.where((p) {
      // Search
      final query = filterState.searchQuery.toLowerCase();
      final matchesSearch =
          p.name.toLowerCase().contains(query) ||
          p.id.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      // Category
      if (filterState.selectedCategoryId != null) {
        if (p.categoryId != filterState.selectedCategoryId) return false;
      }

      return true;
    }).toList();

    // 2. Sort
    filtered.sort((a, b) {
      switch (filterState.sortOption) {
        case InventorySortOption.nameAsc:
          return a.name.compareTo(b.name);

        case InventorySortOption.priceHighLow:
          if (b.price != a.price) return b.price.compareTo(a.price);
          return 0;

        case InventorySortOption.priceLowHigh:
          if (a.price != b.price) return a.price.compareTo(b.price);
          return 0;

        case InventorySortOption.defaultSort:
          // Fallthrough is explicit manual logic here, but switch must be exhaustive or default.
          // Since we cover all cases (enum has 4 values), we can remove default if we cover all.
          // But `default` is safe. The lint says "default clause is covered by previous cases" implying I covered all ENUMS explicitly?
          // Ah, `defaultSort` IS the last one.
          // So `case defaultSort:` IS the handler. `default:` is redundant.
          // Remove `default:`.
          // Priority Logic:
          // 1. Out of Stock (stock <= 0)
          final aOut = a.totalStock <= 0;
          final bOut = b.totalStock <= 0;
          if (aOut && !bOut) return -1;
          if (!aOut && bOut) return 1;

          // 2. Low Stock (stock <= threshold)
          final aLow = !aOut && a.totalStock <= a.lowStockThreshold;
          final bLow = !bOut && b.totalStock <= b.lowStockThreshold;
          if (aLow && !bLow) return -1;
          if (!aLow && bLow) return 1;

          // 3. Alphabetical Fallback
          return a.name.compareTo(b.name);
      }
    });

    return filtered;
  });
}
