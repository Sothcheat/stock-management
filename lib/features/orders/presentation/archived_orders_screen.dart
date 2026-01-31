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
    final archivedAsync = ref.watch(orderHistoryProvider(true));
    final archivedState = archivedAsync.value;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(orderHistoryProvider(true).notifier).refresh();
      },
      child: SoftSliverScaffold(
        title: 'Archived Orders',
        showBack: true,
        slivers: [
          archivedAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, s) =>
                SliverToBoxAdapter(child: Center(child: Text("Error: $e"))),
            data: (state) => SliverOrderList(
              state: state,
              isEmptyMessage: "No archived orders found",
              isHistory: true, // Group by date
              isArchived: true, // Enable Restore actions
            ),
          ),
        ],
        bottomSheet: (archivedState?.isSelectionMode ?? false)
            ? const SelectionToolbar(isArchived: true)
            : null,
      ),
    );
  }
}
