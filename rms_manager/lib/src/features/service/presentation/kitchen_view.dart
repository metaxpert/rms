import 'package:flutter/material.dart';

import 'package:rms_core/rms_core.dart';
import '../../../l10n/app_text.dart';
import '../data/service_repository.dart';

/// The kitchen board, grouped by station the way the kitchen is laid out.
///
/// Read-only. The routes that move a ticket along belong to the KDS screen the
/// chefs use; a manager bumping a ticket from a phone would tell the pass that
/// food was away when nobody had plated it. What this is for is knowing where
/// to walk.
class KitchenView extends StatelessWidget {
  const KitchenView({super.key, required this.snapshot});

  final ServiceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final board = snapshot.board;
    final text = appText(context);

    if (board.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          EmptyView(
            icon: Icons.check_circle_outline,
            title: text.kitchenClearTitle,
            message: text.kitchenClearMessage,
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        for (final station in board.stationKeys)
          _Station(
            name: station,
            tickets: board.stations[station]!,
          ),
      ],
    );
  }
}

class _Station extends StatelessWidget {
  const _Station({required this.name, required this.tickets});

  final StationKey name;
  final List<KdsTicket> tickets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = appText(context);
    final overdue = tickets.where((t) => t.isOverdue).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          // Station keys are tenant-defined ("grill", "tandoor"), so they are
          // shown as configured rather than mapped to a list this app made up.
          name,
          trailing: overdue > 0
              ? StatusBadge(
                  label: text.pastTargetCount(overdue),
                  color: AppStatusColors.cancelled,
                  icon: Icons.timer_outlined,
                )
              : Text(
                  text.ticketCount(tickets.length),
                  style: theme.textTheme.bodySmall,
                ),
        ),
        for (final ticket in tickets) _TicketCard(ticket: ticket),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final KdsTicket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = appText(context);
    final shared = strings(context);
    // The fill is resolved by AppCard now, from the same urgency colour.
    // The elapsed time is the one figure a manager reads across the room, and
    // it is small; it needs the corrected variant rather than the fill.
    final ink = context.statusText(ticket.urgencyColor);

    return Semantics(
      // Replaces the children's labels rather than preceding them; otherwise a
      // ticket is read once as a summary and again line by line.
      container: true,
      excludeSemantics: true,
      label: [
        '${text.ticket} ${ticket.orderNo}',
        if (ticket.tableCode != null) text.tableLabel(ticket.tableCode!),
        ticket.elapsedLabelIn(shared),
        if (ticket.isOverdue) text.pastTargetCount(1),
      ].join(', '),
      // Hand-rolled its own tint, radius and border before — the fourth copy of
      // that decoration in this product. `AppCard` resolves the urgency colour
      // for the brightness, adds the rail, and carries the same shadow as every
      // other card, so a kitchen ticket and a run tile finally look related.
      child: AppCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        accent: ticket.urgencyColor,
        raised: ticket.isOverdue,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg + AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      ticket.orderNo.isEmpty ? text.ticket : ticket.orderNo,
                      if (ticket.tableCode != null)
                        text.tableLabel(ticket.tableCode!),
                    ].join(' · '),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.timer_outlined, size: 16, color: ink),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  ticket.elapsedLabelIn(shared),
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: ink, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final item in ticket.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${item.qty}×',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: theme.textTheme.bodyMedium),
                          if (item.notes?.trim().isNotEmpty ?? false)
                            Text(
                              item.notes!.trim(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (ticket.targetMinutes != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                text.targetAndStatus(ticket.targetMinutes!, ticket.status),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
