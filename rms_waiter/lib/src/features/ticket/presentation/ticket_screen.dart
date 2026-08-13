import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:rms_core/rms_core.dart';
import '../../../app/router/app_router.dart';
import '../../floor/data/floor_repository.dart';
import '../../menu/presentation/menu_picker_sheet.dart';
import '../../orders/data/order_repository.dart';
import '../application/send_controller.dart';
import '../application/ticket_controller.dart';

/// A table's ticket: the bill the server already holds, and the round about to
/// join it.
///
/// The two are kept visually separate throughout, because confusing them is the
/// worst failure this screen can have. Lines under "Sent" are with the kitchen
/// and priced by the server; lines under "This round" exist only on this tablet
/// and nobody else can see them.
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
    final send = ref.watch(sendControllerProvider(ticketRef));
    final sender = ref.read(sendControllerProvider(ticketRef).notifier);
    final orderAsync = ref.watch(tableOrderProvider(table.id));
    final config = ref.watch(menuCatalogueProvider).valueOrNull?.config;

    // The fetch is the authority whenever it has an answer; the send's own copy
    // only stands in when the confirming read failed, so a successful send is
    // never displayed as if nothing had happened.
    final order = orderAsync.valueOrNull ?? send.order;

    _announceSends(context, ref, ticketRef);

    // A submission carries the payload frozen when Send was tapped, because the
    // idempotency key it holds is only valid for that exact body. Letting the
    // round be edited while one is outstanding would either invalidate the key
    // or quietly drop the new dishes when the resume re-sent the old payload.
    final locked = send.isSending || send.pending != null;

    // Not a security boundary — the server re-checks (ARCHITECTURE.md §7). It
    // is here so a waiter without ordering rights is not handed a button that
    // comes back 403 at a table, which is a dead end mid-service.
    final mayOrder = ref.watch(permissionsProvider).canTakeOrders;

    return Scaffold(
      appBar: AppBar(
        title: Text('Table ${table.code}'),
        actions: [
          if (order != null && order.isOpen)
            IconButton(
              onPressed: () => context.push(
                Routes.bill(table.id),
                extra: table.code,
              ),
              icon: const Icon(Icons.point_of_sale_rounded),
              tooltip: 'Bill',
            ),
          if (draft.isNotEmpty && !locked)
            IconButton(
              onPressed: () => _confirmClear(context, controller),
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Clear this round',
            ),
        ],
      ),
      body: Column(
        children: [
          _TableContext(
            table: table,
            order: order,
            restoredAt: controller.restoredAt,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(tableOrderProvider(table.id)),
              child: _TicketContent(
                order: order,
                orderAsync: orderAsync,
                draft: draft,
                onQtyChanged: locked || !mayOrder ? null : controller.setQty,
                onOpenMenu: () => _openMenu(context, controller),
              ),
            ),
          ),
          if (send.pending != null || send.isSending)
            _SendStatusPanel(
              send: send,
              onResume: () => sender.send(draft),
              onDiscard: () => _confirmDiscard(context, sender),
            ),
          if (draft.isNotEmpty)
            _TotalsPanel(
              draft: draft,
              // Until the branch's tax and rounding rules have loaded the
              // totals would be a guess, and a guessed bill is worse than a
              // moment's wait.
              config: config,
              order: order,
            ),
          _ActionBar(
            draft: draft,
            send: send,
            order: order,
            locked: locked,
            mayOrder: mayOrder,
            onAddItems: () => _openMenu(context, controller),
            onSend: () => sender.send(draft),
          ),
        ],
      ),
    );
  }

  /// Tell the waiter a send landed, then drop the banner state.
  ///
  /// The order itself is kept — the "Sent" section reads from it while the
  /// refetch is still in flight, so the lines do not blink out and back.
  void _announceSends(BuildContext context, WidgetRef ref, TicketRef ticketRef) {
    ref.listen(sendControllerProvider(ticketRef), (previous, next) {
      if (previous?.phase == next.phase || next.phase != SendPhase.sent) return;
      final orderNo = next.order?.orderNo;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              orderNo == null || orderNo.isEmpty
                  ? 'Sent to the kitchen.'
                  : 'Sent to the kitchen · $orderNo',
            ),
          ),
        );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(sendControllerProvider(ticketRef).notifier).acknowledge();
      });
    });
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
        title: const Text('Clear this round?'),
        content: const Text(
          'Every unsent line will be removed. Anything already sent to the '
          'kitchen stays on the bill — but this round will have to be retaken.',
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

  Future<void> _confirmDiscard(
    BuildContext context,
    SendController sender,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop trying to send?'),
        content: const Text(
          'The round stays on this tablet so you can send it again.\n\n'
          'If a bill was already opened for this table it is NOT cancelled — '
          'check the floor, and ask a manager to void it if it should not be '
          'there.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep trying'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await sender.discard();
  }
}

/// The sent bill and the unsent round, in one scroll view.
class _TicketContent extends StatelessWidget {
  const _TicketContent({
    required this.order,
    required this.orderAsync,
    required this.draft,
    required this.onQtyChanged,
    required this.onOpenMenu,
  });

  final OrderDetail? order;
  final AsyncValue<OrderDetail?> orderAsync;
  final TicketDraft draft;

  /// Null while a send is in flight — editing lines that are being submitted
  /// would change a payload the server has already been given.
  final void Function(int index, int qty)? onQtyChanged;
  final VoidCallback onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final sent = order;

    if (sent == null && draft.isEmpty) {
      // Must still scroll, or pull-to-refresh cannot fire.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (orderAsync.isLoading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: LoadingView(message: 'Checking for an open bill…'),
            )
          else ...[
            const SizedBox(height: 80),
            EmptyView(
              icon: Icons.receipt_long_outlined,
              title: 'Nothing ordered yet',
              message: 'Add dishes from the menu to start this ticket.',
              action: FilledButton.icon(
                onPressed: onOpenMenu,
                icon: const Icon(Icons.restaurant_menu_rounded),
                label: const Text('Open the menu'),
              ),
            ),
          ],
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        if (orderAsync.hasError)
          _OrderLoadWarning(error: orderAsync.error!),
        if (sent != null) _SentSection(order: sent),
        if (draft.isNotEmpty)
          _RoundSection(
            draft: draft,
            hasSentLines: sent != null,
            onQtyChanged: onQtyChanged,
          ),
      ],
    );
  }
}

/// The bill could not be read. Shown inline rather than replacing the screen:
/// the unsent round is still perfectly usable, and hiding it behind an error
/// would cost the waiter the order they just took.
class _OrderLoadWarning extends StatelessWidget {
  const _OrderLoadWarning({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message =
        error is ApiException ? (error as ApiException).message : '$error';

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              "Couldn't check this table's bill. $message",
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// What the server holds. Read-only here — changing a sent line means voiding
/// it, which is a manager's action and belongs to a later phase.
class _SentSection extends StatelessWidget {
  const _SentSection({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: order.orderNo.isEmpty ? 'Sent' : 'Sent · ${order.orderNo}',
          trailing: StatusBadge(
            label: order.status.label,
            color: order.status.color,
            icon: order.status.icon,
          ),
        ),
        if (order.lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              'This bill is open but has no items on it yet.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          for (final line in order.lines)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: _SentLineTile(line: line),
            ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bill so far',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              Text(
                order.totals.total.display,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _SentLineTile extends StatelessWidget {
  const _SentLineTile({required this.line});

  final OrderLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      ...line.modifierNames,
      if (line.kitchenNotes?.trim().isNotEmpty ?? false) line.kitchenNotes!.trim(),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Text(
            '${line.qty}×',
            style: theme.textTheme.titleSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.name, style: theme.textTheme.bodyLarge),
              if (details.isNotEmpty)
                Text(
                  details.join(' · '),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(line.lineTotal.display, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

/// The round being built on this tablet.
class _RoundSection extends StatelessWidget {
  const _RoundSection({
    required this.draft,
    required this.hasSentLines,
    required this.onQtyChanged,
  });

  final TicketDraft draft;
  final bool hasSentLines;
  final void Function(int index, int qty)? onQtyChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: hasSentLines ? 'This round — not sent' : 'Not sent yet',
          trailing: Icon(
            Icons.edit_note_rounded,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
        for (var index = 0; index < draft.lines.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                _LineTile(
                  line: draft.lines[index],
                  onQtyChanged: onQtyChanged == null
                      ? null
                      : (qty) => onQtyChanged!(index, qty),
                ),
                if (index < draft.lines.length - 1) const Divider(height: 1),
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// What the waiter needs to know about this table before adding to it.
class _TableContext extends StatelessWidget {
  const _TableContext({
    required this.table,
    required this.order,
    required this.restoredAt,
  });

  final RestaurantTable table;
  final OrderDetail? order;
  final DateTime? restoredAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final restored = restoredAt;
    final ready = order?.status.needsAttention ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      color: ready
          ? AppStatusColors.ready.withValues(alpha: 0.16)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
              if (order?.placedAt != null) ...[
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Placed ${DateFormat.Hm().format(order!.placedAt!)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
          if (ready) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.room_service_rounded,
                    size: 18, color: AppStatusColors.ready),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Food is ready to run',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppStatusColors.ready,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          if (restored != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.history_rounded,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    // Someone else may have started this round on another
                    // tablet's shift; it has NOT reached the kitchen.
                    'Unsent round from ${DateFormat.Hm().format(restored)}',
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

/// A submission in flight, or one that stopped part-way.
///
/// An interrupted send is the one state a waiter must not be left to guess at:
/// an order may exist server-side with nothing behind it, and only the person
/// holding the tablet can decide whether to push it through or fetch a manager.
class _SendStatusPanel extends StatelessWidget {
  const _SendStatusPanel({
    required this.send,
    required this.onResume,
    required this.onDiscard,
  });

  final SendState send;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (send.isSending) {
      final stage = send.stage;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                stage == null ? 'Sending…' : sendStageLabel(stage),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final error = send.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 20, color: theme.colorScheme.error),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  send.isInterrupted
                      ? 'This round was not finished sending'
                      : 'This round did not reach the kitchen',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            error?.message ??
                'The app closed part-way through sending. Nothing was lost — '
                    'send it again to finish.',
            style: theme.textTheme.bodySmall,
          ),
          if (send.orderExists) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              // Saying "nothing was sent" here would be a lie the kitchen could
              // contradict, so the screen says exactly what it knows.
              'A bill is already open for this table. Sending again continues '
              'it — it does not start a second one.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            // Explains why the quantity buttons have gone flat, rather than
            // leaving a waiter jabbing at a dead control.
            'The round is held exactly as it was sent. Stop first to change it.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(
                    send.stage == null
                        ? 'Try again'
                        : 'Resume · ${sendStageLabel(send.stage!)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              TextButton(onPressed: onDiscard, child: const Text('Stop')),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line, required this.onQtyChanged});

  final DraftLine line;
  final ValueChanged<int>? onQtyChanged;

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
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = onChanged;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          onPressed: change == null ? null : () => change(qty - 1),
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
          onPressed: change == null || qty >= 99 ? null : () => change(qty + 1),
          icon: const Icon(Icons.add_rounded),
          tooltip: 'One more',
        ),
      ],
    );
  }
}

class _TotalsPanel extends StatelessWidget {
  const _TotalsPanel({
    required this.draft,
    required this.config,
    required this.order,
  });

  final TicketDraft draft;
  final RestaurantConfig? config;
  final OrderDetail? order;

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
    final isAddition = order != null;

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
          // Rounding applies to a whole bill, not to one round of it. Showing it
          // on an addition would predict a figure the server will not produce.
          if (!isAddition && !totals.rounding.isZero)
            _TotalRow(label: 'Rounding', amount: totals.rounding),
          const Divider(),
          _TotalRow(
            label: isAddition ? 'This round' : 'Total',
            amount: isAddition ? totals.subtotal + totals.tax : totals.total,
            emphasise: true,
          ),
          if (isAddition)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                // No invented grand total: the server re-totals and re-rounds
                // the whole bill when this round lands, and a figure that
                // disagreed with the printed bill would cost the app its
                // credibility at exactly the wrong moment.
                'The bill is re-totalled by the server when this round is sent.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
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
  const _ActionBar({
    required this.draft,
    required this.send,
    required this.order,
    required this.locked,
    required this.mayOrder,
    required this.onAddItems,
    required this.onSend,
  });

  final TicketDraft draft;
  final SendState send;
  final OrderDetail? order;

  /// A submission is in flight or waiting to be resumed. The panel above owns
  /// the decision at that point, so this bar stays out of the way.
  final bool locked;

  /// The token carries `restaurant:order:write`.
  final bool mayOrder;

  final VoidCallback onAddItems;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    // A closed bill takes nothing more; the server would refuse, so the button
    // says why instead of producing a 422 the waiter has to interpret.
    final closed = order != null && !order!.canAddItems;
    final canSend = draft.isNotEmpty && !locked && !closed && mayOrder;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mayOrder)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  // Names what is missing, so a manager can fix it rather than
                  // guess why the tablet "does not work".
                  'Your sign-in cannot take orders. Ask a manager for the '
                  'order permission.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              )
            else if (closed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'This bill is ${order!.status.label.toLowerCase()}. '
                  'Nothing more can be added to it.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: AppSizes.primaryActionHeight,
                    child: OutlinedButton.icon(
                      onPressed:
                          locked || closed || !mayOrder ? null : onAddItems,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add items'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: SizedBox(
                    height: AppSizes.primaryActionHeight,
                    child: FilledButton.icon(
                      onPressed: canSend ? onSend : null,
                      icon: send.isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        send.isSending
                            ? 'Sending…'
                            : 'Send · ${draft.itemCount}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
