import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system.dart';
import '../../auth/data/providers/auth_providers.dart';

import 'widgets/dashboard_performance_card.dart';
import 'widgets/stock_alert_section.dart';
import 'widgets/active_orders_section.dart';
import 'widgets/weekly_highlights_section.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(currentUserProfileProvider);

    if (userProfileAsync.isLoading) {
      return const Scaffold(
        backgroundColor: SoftColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return SoftScaffold(
      title: "Dashboard",
      titleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Good Morning,",
            style: GoogleFonts.outfit(
              color: SoftColors.textSecondary,
              fontSize: 14,
            ),
          ),
          userProfileAsync.when(
            data: (user) {
              final name = user?.name ?? 'User';
              final role = (user?.role.name ?? 'Employee').toUpperCase();

              return Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: SoftColors.textMain,
                        fontSize: 24, // Optimized from 26
                        fontWeight: FontWeight.w800, // Extra Bold
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: SoftColors.brandPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      role,
                      style: GoogleFonts.outfit(
                        color: SoftColors.brandPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox(
              height: 20,
              width: 100,
              child: LinearProgressIndicator(),
            ),
            error: (e, st) => const Text("User"),
          ),
        ],
      ),
      actions: [
        BounceButton(
          onTap: () {}, // TODO: Notifications
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
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Interactive Performance Card
            // Only show for Owner/Admin
            // 1. Interactive Performance Card
            // Logic for data visibility is handled inside the widget
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: DashboardPerformanceCard(),
            ),

            // 2. Intelligent Stock Alerts
            const StockAlertSection(),
            const SizedBox(height: 24),

            // 3. Active Orders
            const ActiveOrdersSection(),
            const SizedBox(height: 24),

            // 4. Weekly Highlights
            const WeeklyHighlightsSection(),
          ],
        ),
      ),
    );
  }
}
