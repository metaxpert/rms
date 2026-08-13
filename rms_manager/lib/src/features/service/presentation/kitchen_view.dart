import 'package:flutter/material.dart';

import 'package:rms_core/rms_core.dart';
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

    if (board.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 100),
          EmptyView(
            icon: Icons.check_circle_outline,
            title: 'The kitchen is clear',
            message: 'Nothing is waiting to be cooked.',
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
    final overdue = tickets.where((t) => t.isOverdue).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  // Station keys are tenant-defined ("grill", "tandoor"), so
                  // they are shown as configured rather than mapped to a list
                  // this app made up.
                  name.toUpperCase(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (overdue > 0)
                StatusBadge(
                  label: '$overdue past target',
                  color: AppStatusColors.cancelled,
                  icon: Icons.timer_outlined,
                )
              else
                Text(
                  '${tickets.length} '
                  '${tickets.length == 1 ? 'ticket' : 'tickets'}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
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
    final colour = ticket.urgencyColor;

    return Semantics(
      // Replaces the children's labels rather than preceding them; otherwise a
      // ticket is read once as a summary and again line by line.
      container: true,
      excludeSemantics: true,
      label: [
        'Ticket ${ticket.orderNo}',
        if (ticket.tableCode != null) 'table ${ticket.tableCode}',
        'waiting ${ticket.elapsedLabel}',
        if (ticket.isOverdue) 'past target',
      ].join(', '),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: ticket.isOverdue ? 0.14 : 0.06),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: colour.withValues(alpha: 0.5),
            width: ticket.isOverdue ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      ticket.orderNo.isEmpty ? 'Ticket' : ticket.orderNo,
                      if (ticket.tableCode != null) 'Table ${ticket.tableCode}',
                    ].join(' · '),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.timer_outlined, size: 16, color: colour),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  ticket.elapsedLabel,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: colour, fontWeight: FontWeight.w700),
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
                'Target ${ticket.targetMinutes} min · ${ticket.status}',
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
