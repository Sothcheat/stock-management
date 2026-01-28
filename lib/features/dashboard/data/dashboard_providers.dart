import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../orders/data/firebase_orders_repository.dart';
import '../../orders/domain/order.dart';
import '../../inventory/domain/product.dart';
import '../../products/data/providers/product_provider.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/data/providers/auth_providers.dart';
import '../../reports/data/reports_repository.dart';
import '../../reports/domain/daily_summary.dart';
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

final dashboardMetricsProvider = Provider<DashboardMetrics>((ref) {
  // We need the stream value. To use 'watch' on a stream inside a Provider, we assume we wrap this in a StreamProvider or we use the AsyncValue if we change the return type.
  // The original was a Provider returning DashboardMetrics (sync).
  // But now data is async (Summary Stream).
  // I will change dashboardMetricsProvider to return AsyncValue<DashboardMetrics>
  // OR keep simple and just use `ref.watch(reportsStreamProvider)`.
  // Let's create a stream provider for summaries first?
  // Actually, I can just use `ref.watch(summariesStreamProvider)` if I create one.
  // Let's just define the stream inside.

  // WAIT: The UI expects `DashboardMetrics` directly, accessing `.profit`.
  // If I change to AsyncValue, I break the UI `metrics.profit`.
  // I must check `DashboardPerformanceCard`. It does `final metrics = ref.watch(dashboardMetricsProvider);`.
  // And uses `metrics.profit`. It assumes sync.
  // So `dashboardMetricsProvider` MUST BE `AsyncValue` enabled?
  // The previous implementation used `ordersStreamProvider` which IS AsyncValue<List<Order>>?
  // No, `ordersStreamProvider` is `Stream<List>`.
  // The previous `dashboardMetricsProvider` did `final ordersAsync = ref.watch(ordersStreamProvider);`
  // And returned `ordersAsync.when(...)`.
  // Wait, `ordersAsync.when` returns `DashboardMetrics`?
  // Yes. The provider return type was `Provider<DashboardMetrics>`.
  // So it handles the AsyncValue internally and returns `DashboardMetrics.empty()` on loading.
  // Good style. I will stick to that.

  final summariesAsync = ref.watch(dailySummariesStreamProvider);
  final viewType = ref.watch(dashboardViewTypeProvider); // Today vs Weekly
  final userRole = ref.watch(currentUserProfileProvider).value?.role;
  final isEmployee = userRole == UserRole.employee;

  return summariesAsync.when(
    data: (summaries) {
      final now = DateTime.now();
      final todayKey = now.toIso8601String().substring(0, 10); // YYYY-MM-DD

      double profit = 0;
      double sales = 0;
      int items = 0;

      if (viewType == DashboardViewType.today) {
        // Find today's summary
        final todaySummary = summaries.firstWhere(
          (s) => s.date == todayKey,
          orElse: () => DailySummary(date: todayKey), // Empty
        );
        profit = todaySummary.totalProfit;
        sales = todaySummary.totalRevenue;
        items = todaySummary.itemsSold;
      } else {
        // Weekly: Sum standard week (Sun-Sat)
        final startOfWeek = DateUtilsHelper.getStartOfWeek(now);
        final endOfWeek = DateUtilsHelper.getEndOfWeek(now);

        for (var s in summaries) {
          final date = DateTime.parse(s.date);
          // Check if date is within start/end (inclusive)
          // Start: Sunday 00:00
          // End: Saturday 00:00
          // We want to include Saturday data (which might have time or just date string "YYYY-MM-DD" parsed to 00:00)
          // If parsed from YYYY-MM-DD, it is 00:00.
          // range: >= start && <= end
          if ((date.isAtSameMomentAs(startOfWeek) ||
                  date.isAfter(startOfWeek)) &&
              (date.isAtSameMomentAs(endOfWeek) ||
                  date.isBefore(endOfWeek.add(const Duration(days: 1))))) {
            profit += s.totalProfit;
            sales += s.totalRevenue;
            items += s.itemsSold;
          }
        }
      }

      // Security: Hide profit for employees
      if (isEmployee) {
        profit = 0;
      }

      return DashboardMetrics(profit: profit, sales: sales, itemsSold: items);
    },
    loading: () => DashboardMetrics.empty(),
    error: (e, s) => DashboardMetrics.empty(),
  );
});

// Helper Stream Provider
final dailySummariesStreamProvider = StreamProvider<List<DailySummary>>((ref) {
  return ref.watch(reportsRepositoryProvider).watchSummaries(limit: 7);
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
  final summariesAsync = ref.watch(dailySummariesStreamProvider);
  final productsAsync = ref.watch(productsProvider);

  if (summariesAsync.isLoading || productsAsync.isLoading) {
    return [];
  }

  final summaries = summariesAsync.valueOrNull ?? [];
  final products = productsAsync.valueOrNull ?? [];

  final Map<String, int> consolidatedRanking = {};

  for (var s in summaries) {
    s.productRanking.forEach((key, qty) {
      consolidatedRanking[key] = (consolidatedRanking[key] ?? 0) + qty;
    });
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
