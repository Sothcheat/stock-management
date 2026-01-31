import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart'; // For HapticFeedback

import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/providers/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final themeMode = ref.watch(themeControllerProvider);
    final colors = context.softColors;
    final isDark = themeMode == ThemeMode.dark;

    return SoftScaffold(
      title: 'Profile',
      showBack: false,
      body: userProfileAsync.when(
        data: (user) {
          if (user == null) {
            return Center(
              child: Text(
                "User not found",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  color: colors.textSecondary,
                ),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Avatar
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: colors.brandPrimary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.brandPrimary.withValues(alpha: 0.2),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.brandPrimary.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: GoogleFonts.outfit(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: colors.brandPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Name & Role
                Text(
                  user.name,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colors.textMain,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.role.name.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Info Section
                SoftCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _ProfileItem(
                        title: "Email",
                        value: user.email,
                        icon: Icons.email_outlined,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Divider(
                          color: colors.textSecondary.withValues(alpha: 0.1),
                          height: 1,
                        ),
                      ),
                      Consumer(
                        builder: (context, ref, _) {
                          final staffIdAsync = ref.watch(userStaffIdProvider);
                          return staffIdAsync.when(
                            data: (id) => _ProfileItem(
                              title: "User ID",
                              value: id ?? user.uid, // Fallback to UID
                              icon: Icons.badge_outlined,
                            ),
                            loading: () => const SizedBox(height: 50),
                            error: (e, s) => _ProfileItem(
                              title: "User ID",
                              value: user.uid,
                              icon: Icons.badge_outlined,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Theme Toggle
                SoftCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.bgLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isDark
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          color: colors.brandPrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "Dark Mode",
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.textMain,
                          ),
                        ),
                      ),
                      Switch(
                        value: isDark,
                        activeTrackColor: colors.brandPrimary,
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          ref
                              .read(themeControllerProvider.notifier)
                              .setThemeMode(
                                val ? ThemeMode.dark : ThemeMode.light,
                              );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Logout Button
                SoftButton(
                  label: "Sign Out",
                  icon: Icons.logout_rounded,
                  backgroundColor: colors.error.withValues(alpha: 0.9),
                  textColor: Colors.white,
                  onTap: () {
                    showSoftDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: colors.surface,
                        title: Text(
                          "Sign Out",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: colors.textMain,
                          ),
                        ),
                        content: Text(
                          "Are you sure you want to sign out?",
                          style: GoogleFonts.outfit(color: colors.textMain),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              "Cancel",
                              style: GoogleFonts.outfit(
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context); // Close dialog
                              await ref.read(authRepositoryProvider).signOut();
                            },
                            child: Text(
                              "Sign Out",
                              style: GoogleFonts.outfit(
                                color: colors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text("Error: $e")),
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ProfileItem({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.softColors;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.bgLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colors.textSecondary, size: 24),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textMain,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
