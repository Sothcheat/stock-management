import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../design_system.dart';
import 'order_list_screen.dart'; // Import exposed widgets
import 'providers/order_history_controller.dart';

class ArchivedOrdersScreen extends ConsumerWidget {
  const ArchivedOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the "Archived" family instance
    final archivedState = ref.watch(orderHistoryProvider(isArchived: true));

    return SoftScaffold(
      title: 'Archived Orders',
      showBack: true,
      body: Column(
        children: [
          // Filter Chips (Optional: Reusing similar filter logic if needed,
          // but for Archive maybe just List is enough for MVP.
          // User asked for "Archive Folder" icon, implying a simple list.
          // Getting filters for free if we want them, but let's stick to simple list first.)
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref
                    .read(orderHistoryProvider(isArchived: true).notifier)
                    .refresh();
              },
              child: OrderListView(
                state: archivedState,
                isEmptyMessage: "No archived orders found",
                isHistory: true, // Group by date
                isArchived: true, // Enable Restore actions
              ),
            ),
          ),
        ],
      ),
    );
  }
}
