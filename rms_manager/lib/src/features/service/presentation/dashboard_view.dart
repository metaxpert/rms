import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:rms_core/rms_core.dart';
import '../data/service_repository.dart';

/// What is happening right now, in the order a manager would ask.
///
/// The tiles are chosen for what can be *acted on* from the floor: food going
/// cold at the pass, money sitting on tables, a run that has not moved. A
/// number nobody would walk anywhere about is not a KPI, it is decoration.
class DashboardView extends StatelessWidget {
  const DashboardView({super.key, required this.snapshot});

  final ServiceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final board = snapshot.board;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (snapshot.readyToServe > 0)
          _CallToAction(
            icon: Icons.room_service_rounded,
            colour: AppStatusColors.ready,
            title: '${snapshot.readyToServe} '
                '${snapshot.readyToServe == 1 ? 'order is' : 'orders are'} '
                'ready to run',
            message: 'Food is up and waiting at the pass.',
          ),
        if (board.overdueCount > 0)
          _CallToAction(
            icon: Icons.local_fire_department_rounded,
            colour: AppStatusColors.cancelled,
            title: '${board.overdueCount} '
                '${board.overdueCount == 1 ? 'ticket is' : 'tickets are'} '
                'past target',
            message: 'The longest has been waiting ${_wait(board.longestWait)}.',
          ),
        _TileGrid(
          tiles: [
            _Kpi(
              label: 'Open bills',
              value: '${snapshot.openOrders.length}',
              detail: snapshot.openValue.display,
              icon: Icons.receipt_long_outlined,
            ),
            _Kpi(
              label: 'Ready to serve',
              value: '${snapshot.readyToServe}',
              detail: snapshot.readyToServe > 0 ? 'go now' : 'nothing waiting',
              icon: Icons.room_service_outlined,
              highlight: snapshot.readyToServe > 0,
            ),
            _Kpi(
              label: 'Kitchen tickets',
              value: '${board.ticketCount}',
              detail: board.ticketCount == 0
                  ? 'kitchen is clear'
                  : 'longest ${_wait(board.longestWait)}',
              icon: Icons.soup_kitchen_outlined,
              highlight: board.overdueCount > 0,
            ),
            _Kpi(
              label: 'Tables in use',
              value: '${snapshot.occupiedTables}/${snapshot.totalTables}',
              detail: snapshot.totalTables == 0
                  ? 'no tables set up'
                  : '${_percent(snapshot.occupiedTables, snapshot.totalTables)} full',
              icon: Icons.table_restaurant_outlined,
            ),
            _Kpi(
              label: 'Settled',
              value: '${snapshot.settledOrders.length}',
              detail: snapshot.settledValue.display,
              icon: Icons.payments_outlined,
            ),
            _Kpi(
              label: 'Deliveries out',
              value: '${snapshot.activeDeliveries.length}',
              detail: snapshot.activeDeliveries.isEmpty
                  ? 'none on the road'
                  : 'on the road',
              icon: Icons.two_wheeler_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          // Every figure here is derived from one read; saying when it was
          // taken is the difference between a dashboard and a guess.
          'Read at ${DateFormat.Hms().format(snapshot.takenAt)}',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  static String _wait(Duration duration) {
    final minutes = duration.inMinutes;
    return minutes < 1 ? 'under a minute' : '$minutes min';
  }

  static String _percent(int part, int whole) =>
      whole == 0 ? '0%' : '${(part * 100 / whole).round()}%';
}

/// Something a manager should get up for, stated before the numbers.
class _CallToAction extends StatelessWidget {
  const _CallToAction({
    required this.icon,
    required this.colour,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color colour;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        border: Border.all(color: colour.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, color: colour, size: 28),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  message,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});

  final List<_Kpi> tiles;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Two across on a phone stays readable at arm's length; a manager is not
      // studying this, they are glancing at it.
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.35,
      children: tiles,
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;

  /// Only when there is something to do. A permanently coloured tile stops
  /// being noticed within a shift.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour =
        highlight ? AppStatusColors.ready : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      label: '$label: $value, $detail',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: highlight
              ? colour.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: highlight
              ? Border.all(color: colour.withValues(alpha: 0.5))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: colour),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(color: colour),
                  ),
                ),
              ],
            ),
            Text(
              value,
              maxLines: 1,
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
