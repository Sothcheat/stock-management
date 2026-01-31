import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/orders/data/firebase_orders_repository.dart';
import '../router/app_router.dart';
import '../utils/logger.dart';

// Defines the provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref);
});

class NotificationService {
  final Ref ref;

  NotificationService(this.ref);

  Future<void> initialize(
    GlobalKey<ScaffoldMessengerState> messengerKey,
  ) async {
    // 1. Request Permission
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      Logger.log('User declined or has not accepted notification permission');
    }

    // 2. Foreground Message Handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      Logger.log('Got a message whilst in the foreground!');
      Logger.log('Message data: ${message.data}');

      if (message.notification != null) {
        Logger.log(
          'Message also contained a notification: ${message.notification}',
        );

        // Show SnackBar
        messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(message.notification?.title ?? 'New Notification'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                _handleNavigation(message.data);
              },
            ),
          ),
        );
      }
    });

    // 3. Background Message Handler (Open App)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      Logger.log('A new onMessageOpenedApp event was published!');
      _handleNavigation(message.data);
    });

    // 4. Initial Message (Back from terminated)
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNavigation(initialMessage.data);
    }

    // 5. Local Listener for "Reserved" Orders
    ref.read(ordersRepositoryProvider).onReservedOrderAdded().listen((order) {
      // Show SnackBar for Reserved Order
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF9333EA),
          duration: const Duration(seconds: 5),
          content: Row(
            children: [
              const Icon(Icons.bookmark_border_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "New Order Reserved",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "${order.customer.name} - \$${order.totalAmount.toStringAsFixed(2)}",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              debugPrint("Tapped View on SnackBar for order: ${order.id}");
              // Navigate to Order Detail
              final router = ref.read(routerProvider);
              // Use .go to ensure we switch tabs/branches correctly
              router.go('/orders/detail/${order.id}');
            },
          ),
        ),
      );
    });
  }

  void _handleNavigation(Map<String, dynamic> data) {
    if (data.containsKey('orderId')) {
      final orderId = data['orderId'];
      Logger.log("Navigate to order: $orderId");

      final router = ref.read(routerProvider);
      // Use .go to switch branch if needed
      debugPrint("Handling notification navigation for order: $orderId");
      router.go('/orders/detail/$orderId');
    }
  }
}
