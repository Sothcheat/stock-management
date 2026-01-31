import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../orders/data/firebase_orders_repository.dart';
import '../../orders/domain/order.dart';
import '../../inventory/domain/product.dart';
import '../../products/data/providers/product_provider.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/data/providers/auth_providers.dart';
import '../../../../core/utils/date_utils.dart';

// 1. Dashboard View State (Today/Weekly)
enum DashboardViewType { today, weekly }

final dashboardViewTypeProvider = StateProvider<DashboardViewType>((ref) {
  return DashboardViewType.today;
});

// A wrapper to handle stock items, either product-level or variant-level
class StockAlertItem {
  final Product product;
  final ProductVariant? variant;

  StockAlertItem(this.product, [this.variant]);

  int get currentStock =>
      variant != null ? variant!.stockQuantity : product.totalStock;

  bool get isOutOfStock => currentStock <= 0;
}

// 2. Metrics Logic
class DashboardMetrics {
  final double profit;
  final double sales;
  final int itemsSold;

  DashboardMetrics({
    required this.profit,
    required this.sales,
    required this.itemsSold,
  });

  // Empty state
  static DashboardMetrics empty() =>
      DashboardMetrics(profit: 0, sales: 0, itemsSold: 0);
}

// Helper: Dashboard Orders Stream (Today vs Weekly)
final dashboardOrdersStreamProvider = StreamProvider<List<OrderModel>>((ref) {
  final repo = ref.watch(ordersRepositoryProvider);
  final viewType = ref.watch(dashboardViewTypeProvider);
  final now = DateTime.now();

  if (viewType == DashboardViewType.today) {
    final start = DateTime(now.year, now.month, now.day); // 00:00:00
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return repo.watchCompletedOrders(start, end);
  } else {
    // Weekly
    final start = DateUtilsHelper.getStartOfWeek(now);
    final end = DateUtilsHelper.getEndOfWeek(
      now,
    ).add(const Duration(hours: 23, minutes: 59, seconds: 59));
    return repo.watchCompletedOrders(start, end);
  }
});

// Helper: Weekly Orders Stream (Always Weekly for Highlights)
final weeklyOrdersStreamProvider = StreamProvider<List<OrderModel>>((ref) {
  final repo = ref.watch(ordersRepositoryProvider);
  final now = DateTime.now();
  final start = DateUtilsHelper.getStartOfWeek(now);
  final end = DateUtilsHelper.getEndOfWeek(
    now,
  ).add(const Duration(hours: 23, minutes: 59, seconds: 59));
  return repo.watchCompletedOrders(start, end);
});

final dashboardMetricsProvider = Provider<DashboardMetrics>((ref) {
  final ordersAsync = ref.watch(dashboardOrdersStreamProvider);
  final userRole = ref.watch(currentUserProfileProvider).value?.role;
  final isEmployee = userRole == UserRole.employee;

  return ordersAsync.when(
    data: (orders) {
      double profit = 0;
      double sales = 0;
      int items = 0;

      for (final order in orders) {
        // CRITICAL FIX: Exclude voided orders from sums
        if (order.isVoided) continue;

        sales += order.totalRevenue;
        profit += order.netProfit;
        for (final item in order.items) {
          items += item.quantity;
        }
      }

      // Safeguard: Clamp to zero to never show negative
      sales = sales < 0 ? 0 : sales;
      profit = profit < 0 ? 0 : profit;
      items = items < 0 ? 0 : items;

      if (isEmployee) {
        profit = 0;
      }

      return DashboardMetrics(profit: profit, sales: sales, itemsSold: items);
    },
    loading: () => DashboardMetrics.empty(),
    error: (e, s) => DashboardMetrics.empty(),
  );
});

// 3. Stock Alerts (Priority Sorted) -> UPDATED
final stockAlertsProvider = Provider<List<StockAlertItem>>((ref) {
  final productsAsync = ref.watch(productsProvider);

  return productsAsync.when(
    data: (products) {
      final List<StockAlertItem> alerts = [];

      for (var p in products) {
        if (p.variants.isNotEmpty) {
          // Check each variant
          for (var v in p.variants) {
            if (v.stockQuantity <= p.lowStockThreshold) {
              alerts.add(StockAlertItem(p, v));
            }
          }
        } else {
          // Flatten check
          if (p.totalStock <= p.lowStockThreshold) {
            alerts.add(StockAlertItem(p));
          }
        }
      }

      // Sort: Out of stock first, then ascending stock
      alerts.sort((a, b) {
        if (a.isOutOfStock && !b.isOutOfStock) return -1;
        if (!a.isOutOfStock && b.isOutOfStock) return 1;
        return a.currentStock.compareTo(b.currentStock);
      });

      return alerts;
    },
    loading: () => [],
    error: (e, s) => [],
  );
});

// 4. Active Orders -> UNCHANGED
final activeOrdersProvider = Provider<List<OrderModel>>((ref) {
  final ordersAsync = ref.watch(ordersStreamProvider);

  return ordersAsync.when(
    data: (orders) {
      return orders
          .where(
            (o) =>
                o.status == OrderStatus.prepping ||
                o.status == OrderStatus.delivering,
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    },
    loading: () => [],
    error: (e, s) => [],
  );
});

// 5. Weekly Highlights (DTO) -> UPDATED
class ProductSalesStat {
  final String productName;
  final int quantitySold;
  final double totalRevenue;
  final Product product; // Full product details

  ProductSalesStat(
    this.productName,
    this.quantitySold,
    this.totalRevenue,
    this.product,
  );
}

final weeklyHighlightsProvider = Provider<List<ProductSalesStat>>((ref) {
  final ordersAsync = ref.watch(weeklyOrdersStreamProvider);
  final productsAsync = ref.watch(productsProvider);

  if (ordersAsync.isLoading || productsAsync.isLoading) {
    return [];
  }

  final orders = ordersAsync.valueOrNull ?? [];
  final products = productsAsync.valueOrNull ?? [];

  final Map<String, int> consolidatedRanking = {};

  for (final order in orders) {
    // CRITICAL FIX: Exclude voided orders from ranking
    if (order.isVoided) continue;

    for (final item in order.items) {
      if (item.productId.isNotEmpty) {
        // We aggregate by NAME as per previous logic, but ProductID is safer if available
        // Previous logic used `productRanking` map which had names.
        // Orders have `items` with `name` and `productId`.
        // Let's use name to match previous behavior or productId?
        // Let's use Name for consistency with ProductSalesStat constructor which takes Name.
        final key = item.name;
        consolidatedRanking[key] =
            (consolidatedRanking[key] ?? 0) + item.quantity;
      }
    }
  }

  final list = consolidatedRanking.entries.map((e) {
    // Find product to get details
    final product = products.firstWhere(
      (p) => p.name == e.key,
      orElse: () => Product.empty(),
    );

    return ProductSalesStat(e.key, e.value, e.value * product.price, product);
  }).toList();

  // Filter out where product is not found (empty) if desired, or keep to show legacy data
  final validList = list.where((stat) => stat.product.id.isNotEmpty).toList();

  validList.sort((a, b) => b.quantitySold.compareTo(a.quantitySold));

  return validList.take(10).toList();
});
