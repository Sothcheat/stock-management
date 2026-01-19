import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart'; // Corrected path
import 'widgets/stats_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch current user profile
    final userAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text("User not found"));

          final isEmployee = user.role.name == 'employee';

          return CustomScrollView(
            slivers: [
              // 1. App Bar
              SliverAppBar(
                floating: true,
                pinned: true,
                expandedHeight: 120,
                backgroundColor: AppTheme.primary,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Good Morning,",
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        user.displayName.isEmpty ? "User" : user.displayName,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF3C67AC), Color(0xFF1E3A60)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                    ),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  ),
                ],
              ),

              // 2. Stats Grid
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      if (!isEmployee)
                        const StatsCard(
                          title: "Today's Profit",
                          value: "\$450.00",
                          icon: Icons.attach_money,
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
                        icon: Icons.pending_actions,
                        isPositive: true,
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Low Stock Alert Header (If necessary)
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    "Weekly Highlights",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // 4. Weekly Highlights (Placeholder)
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                    title: Text("Logitech G502 Hero $index"),
                    subtitle: const Text(
                      "154 units sold",
                      style: TextStyle(color: Colors.green),
                    ),
                    trailing: const Text("\$12,450"),
                  );
                }, childCount: 5),
              ),

              const SliverGap(80), // Fab spacing
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text("Error: $e")),
      ),
    );
  }
}

// Simple Gap widget stub if gap package is not used, or use SizedBox
class SliverGap extends StatelessWidget {
  final double height;
  const SliverGap(this.height, {super.key});
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(child: SizedBox(height: height));
  }
}
