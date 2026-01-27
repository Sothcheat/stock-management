import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LastSaleState {
  final String orderId;
  final String description; // e.g. "iPhone 15 x2"
  final DateTime timestamp;

  LastSaleState({
    required this.orderId,
    required this.description,
    required this.timestamp,
  });
}

class LastSaleNotifier extends StateNotifier<LastSaleState?> {
  Timer? _timer;

  LastSaleNotifier() : super(null);

  void setLastSale(String orderId, String description) {
    _timer?.cancel();
    state = LastSaleState(
      orderId: orderId,
      description: description,
      timestamp: DateTime.now(),
    );

    // Auto-clear after 60 seconds
    _timer = Timer(const Duration(seconds: 60), () {
      state = null;
    });
  }

  void clear() {
    _timer?.cancel();
    state = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final lastSaleProvider =
    StateNotifierProvider<LastSaleNotifier, LastSaleState?>((ref) {
      return LastSaleNotifier();
    });
