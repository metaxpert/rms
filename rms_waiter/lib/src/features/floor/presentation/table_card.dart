import 'package:flutter/material.dart';

import 'package:rms_core/rms_core.dart';

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
    this.compact = false,
  });

  final RestaurantTable table;
  final OrderSummary? order;
  final VoidCallback? onTap;

  /// Spatial layout packs tables tighter than the grid does.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = table.status;
    final needsAttention = order?.status.needsAttention ?? false;

    // A ready ticket outranks the table's own status: the table is still
    // "seated", but the thing the waiter must DO is run the food.
    final accent = needsAttention ? AppStatusColors.ready : status.color;
    final enabled = onTap != null && table.isOperable;

    return Semantics(
      button: enabled,
      // Screen readers get the whole story in one utterance rather than three
      // disconnected labels.
      label: [
        'Table ${table.code}',
        status.label,
        'seats ${table.capacity}',
        if (order != null)
          'order ${order!.status.label} ${order!.total.display}',
        if (needsAttention) 'food ready',
      ].join(', '),
      child: Material(
        color: accent.withValues(alpha: needsAttention ? 0.18 : 0.07),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
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
                        status.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (table.isMerged) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Merged',
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
                          order!.status.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: accent,
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
    );
  }
}
