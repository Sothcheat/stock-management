import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system.dart';
import '../../auth/data/auth_repository.dart';
import 'widgets/stats_card.dart';
import 'widgets/low_stock_list.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            backgroundColor: SoftColors.background,
            body: Center(child: Text("User not found")),
          );
        }

        final isEmployee = user.role.name == 'employee';

        return SoftScaffold(
          title: "Dashboard",
          actions: [
            BounceButton(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: SoftColors.textMain.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: SoftColors.textMain,
                ),
              ),
            ),
            const SizedBox(width: 12),
            BounceButton(
              onTap: () => ref.read(authRepositoryProvider).signOut(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SoftColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: SoftColors.error,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 24),
          ],
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting Card
                SoftCard(
                  color: SoftColors.brandPrimary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Good Morning,",
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.displayName.isNotEmpty ? user.displayName : "User",
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Stats Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    if (!isEmployee)
                      const StatsCard(
                        title: "Today's Profit",
                        value: "\$450.00",
                        icon: Icons.attach_money_rounded,
                        isPositive: true,
                      ),
                    const StatsCard(
                      title: "Today's Sales",
                      value: "\$1,205",
                      icon: Icons.shopping_bag_outlined,
                      isPositive: true,
                    ),
                    const StatsCard(
                      title: "Low Stock",
                      value: "12 Items",
                      icon: Icons.warning_amber_rounded,
                      isPositive: false,
                    ),
                    const StatsCard(
                      title: "Pending Orders",
                      value: "5",
                      icon: Icons.pending_actions_rounded,
                      isPositive: true,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Low Stock & Highlights
                const LowStockList(),

                const SizedBox(height: 32),
                Text(
                  "Weekly Highlights",
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: SoftColors.textMain,
                  ),
                ),
                const SizedBox(height: 16),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 5,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return SoftCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: SoftColors.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.image_not_supported_rounded,
                              color: SoftColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Logitech G502 Hero $index",
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: SoftColors.textMain,
                                  ),
                                ),
                                Text(
                                  "154 units sold",
                                  style: GoogleFonts.outfit(
                                    color: SoftColors.success,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "\$12,450",
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: SoftColors.textMain,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: SoftColors.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: SoftColors.background,
        body: Center(child: Text("Error: $e")),
      ),
    );
  }
}
