import 'package:flutter/material.dart';

import 'package:rms_core/rms_core.dart';
import '../../../l10n/app_text.dart';

/// A table on the floor.
///
/// Reads at a glance from arm's length while walking: the code is the largest
/// element, the status border is thick, and anything a waiter must act on
/// (food ready) is called out rather than left to a colour difference.
class TableCard extends StatelessWidget {
  const TableCard({
    super.key,
    required this.table,
    required this.order,
    required this.onTap,
    this.hasDraft = false,
    this.hasPendingSend = false,
    this.compact = false,
  });

  final RestaurantTable table;
  final OrderSummary? order;
  final VoidCallback? onTap;

  /// An order taken on this tablet that has NOT been sent to the kitchen.
  ///
  /// Shown on the floor because an unsent ticket is invisible to everyone else —
  /// the kitchen has no idea it exists, and a waiter walking past should be
  /// able to see that this table is waiting on them.
  final bool hasDraft;

  /// A send that stopped part-way through. Ranked above [hasDraft] because the
  /// consequences are worse: an order may exist server-side carrying none of
  /// the round, and only someone opening the table can finish or abandon it.
  final bool hasPendingSend;

  /// Spatial layout packs tables tighter than the grid does.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = appText(context);
    final shared = strings(context);
    final status = table.status;
    final needsAttention = order?.status.needsAttention ?? false;

    // A ready ticket outranks the table's own status: the table is still
    // "seated", but the thing the waiter must DO is run the food.
    final accent = needsAttention ? AppStatusColors.ready : status.color;
    final enabled = onTap != null && table.isOperable;

    return Semantics(
      button: enabled,
      // `container` gives the card ONE node. Without it the summary below is
      // read and then every fragment again — "…unsent ticket, D1, 4, Seated,
      // Ready, Rs 1,531.00" — which is exactly the disconnected reading this
      // label exists to prevent.
      //
      // The text is excluded further down rather than here, so that the
      // InkWell's own tap and focus semantics survive: a card that reads
      // beautifully and cannot be activated is worse than the problem.
      container: true,
      label: [
        text.tableSemantics(table.code),
        status.labelIn(shared),
        text.tableSeatsSemantics(table.capacity),
        if (order != null)
          text.tableOrderSemantics(
              order!.status.labelIn(shared), order!.total.display),
        if (needsAttention) text.tableFoodReadySemantics,
        if (hasPendingSend) text.tableSendUnfinished.toLowerCase(),
        if (hasDraft) text.tableUnsentTicket.toLowerCase(),
      ].join(', '),
      child: Material(
        color: accent.withValues(alpha: needsAttention ? 0.18 : 0.07),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: ExcludeSemantics(
            child: Container(
              padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: accent.withValues(alpha: enabled ? 0.9 : 0.35),
                  width: needsAttention ? 3 : 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          table.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (compact
                                  ? theme.textTheme.titleMedium
                                  : theme.textTheme.headlineSmall)
                              ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: enabled ? null : theme.colorScheme.outline,
                          ),
                        ),
                      ),
                      if (hasPendingSend)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: Icon(
                            Icons.sync_problem_rounded,
                            size: compact ? 16 : 20,
                            color: theme.colorScheme.error,
                          ),
                        )
                      else if (hasDraft)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: Icon(
                            Icons.edit_note_rounded,
                            size: compact ? 16 : 20,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      Icon(status.icon, size: compact ? 16 : 20, color: accent),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(Icons.people_outline,
                          size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Text(
                        '${table.capacity}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          status.labelIn(shared),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppStatusColors.textOn(accent),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (hasPendingSend && !compact) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      text.tableSendUnfinished,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ] else if (hasDraft && !compact) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      text.tableUnsentTicket,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (table.isMerged) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      text.tableMerged,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                  if (order != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Divider(height: 1, color: accent.withValues(alpha: 0.3)),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(order!.status.icon, size: 14, color: accent),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            order!.status.labelIn(shared),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppStatusColors.textOn(accent),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order!.total.display,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
