import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/auth_repository.dart'; // Changed from auth_controller
import '../../features/auth/data/providers/auth_providers.dart';
import '../../features/auth/domain/user_model.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/inventory/presentation/add_edit_product_screen.dart';
import '../../features/inventory/presentation/product_detail_screen.dart';
import '../../features/inventory/domain/product.dart';
import '../../features/orders/presentation/order_list_screen.dart';
import '../../features/orders/presentation/add_new_order_screen.dart';
import '../../features/orders/presentation/product_selection_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/archived_orders_screen.dart';
import '../../features/orders/domain/order.dart';
import '../../features/reports/presentation/report_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../../design_system.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final userProfileAsync = ref.watch(currentUserProfileProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      final hasError = authState.hasError;
      final isAuthenticated = authState.value != null;

      final isLoginRoute = state.uri.toString() == '/login';

      if (isLoading || hasError) return null;

      if (!isAuthenticated) return isLoginRoute ? null : '/login';
      if (isLoginRoute) return '/';

      // Role Guard for Restricted Routes
      final user = userProfileAsync.value;
      if (user?.role == UserRole.employee) {
        final restrictedRoutes = [
          '/reports',
          '/inventory/add',
          '/inventory/edit',
          '/orders/new-order',
        ];

        // Check if current path starts with any restricted route
        // We use check against URI path to catch sub-routes if any
        final currentPath = state.uri.path;
        if (restrictedRoutes.any((route) => currentPath.startsWith(route))) {
          return '/';
        }
      }

      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Dashboard (Home)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          // Branch 1: Inventory
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inventory',
                builder: (context, state) => const InventoryScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => CustomTransitionPage(
                      child: const AddEditProductScreen(),
                      transitionDuration: slideTransitionDuration,
                      reverseTransitionDuration: slideTransitionDuration,
                      transitionsBuilder: slideLeftTransitionsBuilder,
                    ),
                  ),
                  GoRoute(
                    path: 'edit',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => CustomTransitionPage(
                      child: AddEditProductScreen(
                        product: state.extra as Product?,
                      ),
                      transitionDuration: slideTransitionDuration,
                      reverseTransitionDuration: slideTransitionDuration,
                      transitionsBuilder: slideLeftTransitionsBuilder,
                    ),
                  ),
                  GoRoute(
                    path: 'detail',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => CustomTransitionPage(
                      child: ProductDetailScreen(
                        product: state.extra as Product,
                      ),
                      transitionDuration: scaleUpTransitionDuration,
                      reverseTransitionDuration: scaleUpTransitionDuration,
                      transitionsBuilder: scaleUpTransitionsBuilder,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 2: Orders
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                builder: (context, state) => const OrderListScreen(),
                routes: [
                  GoRoute(
                    path: 'new-order',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => CustomTransitionPage(
                      child: const AddNewOrderScreen(),
                      opaque: false,
                      barrierDismissible: true,
                      barrierColor: Colors.black54,
                      transitionDuration: const Duration(milliseconds: 350),
                      reverseTransitionDuration: const Duration(
                        milliseconds: 250,
                      ),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            final curvedAnimation = CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutBack, // Bounce at top
                              reverseCurve: Curves.easeInCubic,
                            );

                            // Slide up from bottom like a modal sheet
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 1), // Start from bottom
                                end: Offset.zero,
                              ).animate(curvedAnimation),
                              child: child,
                            );
                          },
                    ),
                  ),
                  GoRoute(
                    path: 'product-selection',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => CustomTransitionPage(
                      child: ProductSelectionScreen(
                        existingItems: state.extra as List<OrderItem>?,
                      ),
                      transitionDuration: slideTransitionDuration,
                      reverseTransitionDuration: slideTransitionDuration,
                      transitionsBuilder: slideLeftTransitionsBuilder,
                    ),
                  ),
                  GoRoute(
                    path: 'detail/:orderId',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => CustomTransitionPage(
                      child: OrderDetailScreen(
                        orderId: state.pathParameters['orderId']!,
                      ),
                      transitionDuration: scaleUpTransitionDuration,
                      reverseTransitionDuration: scaleUpTransitionDuration,
                      transitionsBuilder: scaleUpTransitionsBuilder,
                    ),
                  ),
                  GoRoute(
                    path: 'archived',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => CustomTransitionPage(
                      child: const ArchivedOrdersScreen(),
                      transitionDuration: slideTransitionDuration,
                      reverseTransitionDuration: slideTransitionDuration,
                      transitionsBuilder: slideLeftTransitionsBuilder,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 3: Reports (Guarded)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) => const ReportScreen(),
              ),
            ],
          ),
          // Branch 4: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    ],
  );
});

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class ScaffoldWithNavBar extends ConsumerWidget {
  const ScaffoldWithNavBar({required this.navigationShell, Key? key})
    : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRole = ref.watch(currentUserProfileProvider).value?.role;
    final isEmployee = userRole == UserRole.employee;

    // Define destinations with their corresponding branch index
    final destinations = <_NavBarItem>[
      _NavBarItem(
        branchIndex: 0,
        destination: const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
      ),
      _NavBarItem(
        branchIndex: 1,
        destination: const NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: 'Inventory',
        ),
      ),
      _NavBarItem(
        branchIndex: 2,
        destination: const NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Orders',
        ),
      ),
      if (!isEmployee)
        _NavBarItem(
          branchIndex: 3,
          destination: const NavigationDestination(
            icon: Icon(Icons.insert_chart_outlined_outlined),
            selectedIcon: Icon(Icons.insert_chart),
            label: 'Reports',
          ),
        ),
      _NavBarItem(
        branchIndex: 4,
        destination: const NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ),
    ];

    // Find the current UI index based on the active branch
    // If the active branch is not in our list (shouldn't happen), default to 0
    final currentBranchIndex = navigationShell.currentIndex;
    final currentUiIndex = destinations.indexWhere(
      (item) => item.branchIndex == currentBranchIndex,
    );
    final selectedIndex = currentUiIndex >= 0 ? currentUiIndex : 0;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          HapticFeedback.selectionClick();
          final branchIndex = destinations[index].branchIndex;
          navigationShell.goBranch(
            branchIndex,
            initialLocation: branchIndex == navigationShell.currentIndex,
          );
        },
        destinations: destinations.map((e) => e.destination).toList(),
      ),
    );
  }
}

class _NavBarItem {
  final int branchIndex;
  final NavigationDestination destination;
  _NavBarItem({required this.branchIndex, required this.destination});
}
