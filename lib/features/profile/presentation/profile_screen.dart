import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system.dart';
import '../../auth/data/auth_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(currentUserProfileProvider);

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
                  color: SoftColors.textSecondary,
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
                    color: SoftColors.brandPrimary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: SoftColors.brandPrimary.withValues(alpha: 0.2),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: SoftColors.brandPrimary.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.outfit(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: SoftColors.brandPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Name & Role
                Text(
                  user.displayName,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: SoftColors.textMain,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: SoftColors.textSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.role.name.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 12,
                      color: SoftColors.textSecondary,
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
                          color: SoftColors.textSecondary.withValues(
                            alpha: 0.1,
                          ),
                          height: 1,
                        ),
                      ),
                      _ProfileItem(
                        title: "User ID",
                        value: user.uid,
                        icon: Icons.badge_outlined,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Logout Button
                SoftButton(
                  label: "Sign Out",
                  icon: Icons.logout_rounded,
                  backgroundColor: SoftColors.error.withValues(alpha: 0.1),
                  textColor: SoftColors.error,
                  onTap: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    // Router should handle redirect via authStateChanges
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
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SoftColors.bgLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: SoftColors.textSecondary, size: 24),
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
                  color: SoftColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: SoftColors.textMain,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
