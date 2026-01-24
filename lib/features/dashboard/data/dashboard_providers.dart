import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../orders/data/firebase_orders_repository.dart';
import '../../orders/domain/order.dart';
import '../../inventory/domain/product.dart';
import '../../products/data/providers/product_provider.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/data/providers/auth_providers.dart';
import '../../reports/data/reports_repository.dart';
import '../../reports/domain/daily_summary.dart';

// 1. Dashboard View State (Today/Weekly)
enum DashboardViewType { today, weekly }

final dashboardViewTypeProvider = StateProvider<DashboardViewType>((ref) {
  return DashboardViewType.today;
});

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
        // Weekly: Sum last 7 days (the summaries list is already limit:7)
        for (var s in summaries) {
          profit += s.totalProfit;
          sales += s.totalRevenue;
          items += s.itemsSold;
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

// 3. Stock Alerts (Priority Sorted) -> UNCHANGED
final stockAlertsProvider = Provider<List<Product>>((ref) {
  final productsAsync = ref.watch(productsProvider);

  return productsAsync.when(
    data: (products) {
      final lowStock = products
          .where((p) => p.totalStock <= p.lowStockThreshold)
          .toList();

      lowStock.sort((a, b) {
        if (a.totalStock == 0 && b.totalStock != 0) return -1;
        if (a.totalStock != 0 && b.totalStock == 0) return 1;
        return a.totalStock.compareTo(b.totalStock);
      });

      return lowStock;
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
  final double
  totalRevenue; // Not strictly tracked in Rankings (only qty), but we can omit or track separately.
  // The DailySummary `productRanking` is Map<String, int> (Qty only).
  // User req: "productRanking": {"chair": 5}.
  // We don't have revenue per product stored in summary.
  // So for `WeeklyHighlights`, we might only show Quantity.
  // Or we modify ProductSalesStat to remove revenue?
  // UI usually shows "X units sold".
  // Let's modify `ProductSalesStat` to default revenue to 0 if unknown, or just omit.
  // "Update... using the daily_summaries document".
  // Since summary only has Qty, I will use Qty.

  ProductSalesStat(this.productName, this.quantitySold, this.totalRevenue);
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
    // Find product to get current price
    // Note: This relies on product name matching, which is how ranking is stored currently.
    final product = products.firstWhere(
      (p) => p.name == e.key,
      orElse: () => Product.empty(),
    );

    return ProductSalesStat(e.key, e.value, e.value * product.price);
  }).toList();

  list.sort((a, b) => b.quantitySold.compareTo(a.quantitySold));

  return list.take(10).toList();
});
