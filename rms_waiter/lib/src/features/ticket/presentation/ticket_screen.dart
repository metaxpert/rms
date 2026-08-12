import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:rms_core/rms_core.dart';
import '../../floor/data/floor_repository.dart';
import '../../menu/data/menu_repository.dart';
import '../../menu/presentation/menu_picker_sheet.dart';
import '../application/ticket_controller.dart';

/// A table's ticket: what is about to be ordered, and what it will cost.
///
/// Everything here is local until it is sent (Phase 5). That is deliberate —
/// the waiter must be able to build a ticket at the table with no signal — but
/// it is also stated on screen, because a waiter who believes the kitchen has
/// the order when it does not is the single worst failure this app can have.
class TicketScreen extends ConsumerWidget {
  const TicketScreen({super.key, required this.tableId, this.table});

  final String tableId;

  /// Passed by the floor screen. Absent after a hot restart or a deep link, in
  /// which case the table is resolved from the floor.
  final RestaurantTable? table;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final known = table;
    if (known != null) return _TicketBody(table: known);

    final floor = ref.watch(floorSnapshotProvider);
    return floor.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          error: error,
          onRetry: () => ref.invalidate(floorSnapshotProvider),
        ),
      ),
      data: (floor) {
        final matches = floor.tables.where((t) => t.id == tableId);
        final resolved = matches.isEmpty ? null : matches.first;
        if (resolved == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyView(
              icon: Icons.table_restaurant_outlined,
              title: 'Table not found',
              message: 'It may have been removed or merged into another table.',
            ),
          );
        }
        return _TicketBody(table: resolved);
      },
    );
  }
}

class _TicketBody extends ConsumerWidget {
  const _TicketBody({required this.table});

  final RestaurantTable table;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchId = ref.watch(sessionProvider).branchId;
    if (branchId == null) {
      // The router guards this; if it is ever reached, saying so beats writing
      // a draft under a branch key that will never be found again.
      return Scaffold(
        appBar: AppBar(title: Text('Table ${table.code}')),
        body: const EmptyView(
          icon: Icons.storefront_outlined,
          title: 'No outlet selected',
          message: 'Choose an outlet before taking orders.',
        ),
      );
    }

    final ticketRef = TicketRef(
      branchId: branchId,
      tableId: table.id,
      tableCode: table.code,
    );
    final draft = ref.watch(ticketControllerProvider(ticketRef));
    final controller = ref.read(ticketControllerProvider(ticketRef).notifier);
    final config = ref.watch(menuCatalogueProvider).valueOrNull?.config;

    return Scaffold(
      appBar: AppBar(
        title: Text('Table ${table.code}'),
        actions: [
          if (draft.isNotEmpty)
            IconButton(
              onPressed: () => _confirmClear(context, controller),
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Clear ticket',
            ),
        ],
      ),
      body: Column(
        children: [
          _TableContext(table: table, restoredAt: controller.restoredAt),
          Expanded(
            child: draft.isEmpty
                ? EmptyView(
                    icon: Icons.receipt_long_outlined,
                    title: 'Nothing ordered yet',
                    message: 'Add dishes from the menu to start this ticket.',
                    action: FilledButton.icon(
                      onPressed: () => _openMenu(context, controller),
                      icon: const Icon(Icons.restaurant_menu_rounded),
                      label: const Text('Open the menu'),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    itemCount: draft.lines.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => _LineTile(
                      line: draft.lines[index],
                      onQtyChanged: (qty) => controller.setQty(index, qty),
                    ),
                  ),
          ),
          if (draft.isNotEmpty)
            _TotalsPanel(
              draft: draft,
              // Until the branch's tax and rounding rules have loaded the
              // totals would be a guess, and a guessed bill is worse than a
              // moment's wait.
              config: config,
            ),
          _ActionBar(
            draft: draft,
            onAddItems: () => _openMenu(context, controller),
          ),
        ],
      ),
    );
  }

  void _openMenu(BuildContext context, TicketController controller) {
    showMenuPickerSheet(
      context,
      tableCode: table.code,
      onAdd: controller.add,
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    TicketController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear this ticket?'),
        content: const Text(
          'Every line will be removed. Nothing has been sent to the kitchen, '
          'so nothing is cancelled — but the order will have to be retaken.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) controller.clear();
  }
}

/// What the waiter needs to know about this table before adding to it.
class _TableContext extends StatelessWidget {
  const _TableContext({required this.table, required this.restoredAt});

  final RestaurantTable table;
  final DateTime? restoredAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final restored = restoredAt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(
                label: table.status.label,
                color: table.status.color,
                icon: table.status.icon,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Seats ${table.capacity}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          if (restored != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.history_rounded,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    // Someone else may have started this ticket on another
                    // tablet's shift; it has NOT reached the kitchen.
                    'Unsent ticket from ${DateFormat.Hm().format(restored)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line, required this.onQtyChanged});

  final DraftLine line;
  final ValueChanged<int> onQtyChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      for (final modifier in line.modifiers)
        modifier.priceDelta.isZero
            ? modifier.name
            : '${modifier.name} +${modifier.priceDelta.display}',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: theme.textTheme.titleSmall),
                if (details.isNotEmpty)
                  Text(
                    details.join(' · '),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                if (line.kitchenNotes?.trim().isNotEmpty ?? false)
                  Text(
                    line.kitchenNotes!.trim(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _QtyControl(qty: line.qty, onChanged: onQtyChanged),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 96,
            child: Text(
              // Pre-tax, like every line on a printed bill; tax is summarised
              // once at the bottom.
              line.taxable.display,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyControl extends StatelessWidget {
  const _QtyControl({required this.qty, required this.onChanged});

  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          onPressed: () => onChanged(qty - 1),
          // At 1, this removes the line — the icon says so rather than the
          // count silently vanishing at zero.
          icon: Icon(qty > 1 ? Icons.remove_rounded : Icons.delete_outline_rounded),
          tooltip: qty > 1 ? 'One fewer' : 'Remove',
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$qty',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        IconButton.outlined(
          onPressed: qty < 99 ? () => onChanged(qty + 1) : null,
          icon: const Icon(Icons.add_rounded),
          tooltip: 'One more',
        ),
      ],
    );
  }
}

class _TotalsPanel extends StatelessWidget {
  const _TotalsPanel({required this.draft, required this.config});

  final TicketDraft draft;
  final RestaurantConfig? config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = config;

    if (resolved == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: LinearProgressIndicator(),
      );
    }

    final totals = draft.totals(resolved);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Column(
        children: [
          _TotalRow(label: 'Subtotal', amount: totals.subtotal),
          if (!totals.tax.isZero) _TotalRow(label: 'Tax', amount: totals.tax),
          if (!totals.serviceCharge.isZero)
            _TotalRow(label: 'Service charge', amount: totals.serviceCharge),
          if (!totals.rounding.isZero)
            _TotalRow(label: 'Rounding', amount: totals.rounding),
          const Divider(),
          _TotalRow(label: 'Total', amount: totals.total, emphasise: true),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.amount,
    this.emphasise = false,
  });

  final String label;
  final Money amount;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasise
        ? theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(amount.display, style: style),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.draft, required this.onAddItems});

  final TicketDraft draft;
  final VoidCallback onAddItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: AppSizes.primaryActionHeight,
                child: FilledButton.icon(
                  onPressed: onAddItems,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add items'),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SizedBox(
                height: AppSizes.primaryActionHeight,
                child: OutlinedButton(
                  // Sending is Phase 5. A disabled button that explains itself
                  // beats one that looks broken — and beats a button that
                  // appears to fire the kitchen and does not.
                  onPressed: draft.isEmpty
                      ? null
                      : () => ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Sending to the kitchen arrives in the next phase '
                              '— this ticket is saved on the tablet.',
                            ),
                          ),
                        ),
                  child: Text(
                    'Send · ${draft.itemCount}',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
