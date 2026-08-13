import 'package:flutter/material.dart';

import 'package:rms_core/rms_core.dart';
import '../../../l10n/app_text.dart';
import '../data/service_repository.dart';

/// What has been taken, and what is still on tables.
///
/// Note the wording throughout: **settled**, not "revenue". Revenue is the
/// ledger's word and the GL is where it is decided — recognition, tax and
/// rounding all happen there. What a phone can honestly report is which bills
/// were closed and for how much.
class SalesView extends StatelessWidget {
  const SalesView({super.key, required this.snapshot});

  final ServiceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = appText(context);
    final settled = snapshot.settledOrders;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _Summary(snapshot: snapshot),
        const SizedBox(height: AppSpacing.lg),
        if (snapshot.openOrders.isNotEmpty) ...[
          _Header(
            text.stillOpen,
            trailing: snapshot.openValue.display,
          ),
          for (final order in snapshot.openOrders) _OrderRow(order: order),
          const SizedBox(height: AppSpacing.lg),
        ],
        _Header(text.settled, trailing: '${settled.length}'),
        if (settled.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text(
              text.nothingSettled,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          for (final order in settled) _OrderRow(order: order),
        const SizedBox(height: AppSpacing.lg),
        Text(
          // The list endpoint's window was never verified, so the app does not
          // claim these are "today's" figures.
          text.salesFootnote,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.snapshot});

  final ServiceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = appText(context);

    Widget figure(String label, String value, {bool emphasise = false}) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: emphasise
                    ? theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)
                    : theme.textTheme.titleMedium,
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Row(
            children: [
              figure(text.settled, snapshot.settledValue.display,
                  emphasise: true),
              figure(text.stillOnTables, snapshot.openValue.display),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              figure(text.billsClosed, '${snapshot.settledOrders.length}'),
              figure(text.averageBill, snapshot.averageBill.display),
            ],
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.label, {this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          if (trailing != null)
            Text(trailing!, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(order.status.icon, size: 18, color: order.status.color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.orderNo.isEmpty ? order.id : order.orderNo,
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  [
                    if (order.tableCode != null)
                      appText(context).tableLabel(order.tableCode!),
                    if (!order.isDineIn) order.channel,
                    appText(context).itemCount(order.itemCount),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(
            order.total.display,
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
