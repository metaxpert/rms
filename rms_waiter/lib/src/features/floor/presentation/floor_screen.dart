import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:rms_core/rms_core.dart';
import '../../../app/router/app_router.dart';
import '../../ticket/data/draft_store.dart';
import '../../ticket/data/pending_send_store.dart';
import '../data/floor_repository.dart';
import 'table_card.dart';

/// The floor. A waiter's home screen during service.
class FloorScreen extends ConsumerStatefulWidget {
  const FloorScreen({super.key});

  @override
  ConsumerState<FloorScreen> createState() => _FloorScreenState();
}

class _FloorScreenState extends ConsumerState<FloorScreen> {
  String? _selectedAreaId;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(floorSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Floor'),
        actions: [
          const _ConnectionIndicator(),
          IconButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).clearBranch(),
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Switch outlet',
          ),
          IconButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: snapshot.when(
        loading: () => const LoadingView(message: 'Loading floor…'),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(floorSnapshotProvider),
        ),
        data: (floor) => _FloorBody(
          floor: floor,
          // Tables holding an order taken but not yet sent to the kitchen.
          draftTableIds: ref.watch(tablesWithDraftsProvider),
          // Tables whose send stopped part-way. More urgent than a draft: a
          // bill may already exist server-side with nothing behind it.
          pendingSendTableIds: ref.watch(tablesWithPendingSendsProvider),
          selectedAreaId: _selectedAreaId,
          onAreaSelected: (id) => setState(() => _selectedAreaId = id),
          onRefresh: () async => ref.invalidate(floorSnapshotProvider),
        ),
      ),
    );
  }
}

/// Whether the app currently has a live feed, stated plainly.
///
/// Shown because "offline" changes what a waiter should trust: with the socket
/// down, another till's actions only reach this tablet on the next refresh. It
/// is never a blocker — the floor is correct either way, just not as prompt.
class _ConnectionIndicator extends ConsumerWidget {
  const _ConnectionIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(realtimeStatusProvider).valueOrNull ?? RealtimeStatus.idle;

    // A connected socket is the normal case and needs no chrome; only its
    // absence is worth a waiter's attention.
    if (status == RealtimeStatus.live || status == RealtimeStatus.idle) {
      return const SizedBox.shrink();
    }

    final connecting = status == RealtimeStatus.connecting;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Tooltip(
        message: connecting
            ? 'Connecting to live updates'
            : 'Live updates are offline — pull down to refresh',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              connecting ? Icons.sync_rounded : Icons.cloud_off_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              connecting ? 'Connecting' : 'Offline',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _FloorBody extends StatelessWidget {
  const _FloorBody({
    required this.floor,
    required this.draftTableIds,
    required this.pendingSendTableIds,
    required this.selectedAreaId,
    required this.onAreaSelected,
    required this.onRefresh,
  });

  final FloorSnapshot floor;
  final Set<String> draftTableIds;
  final Set<String> pendingSendTableIds;
  final String? selectedAreaId;
  final ValueChanged<String> onAreaSelected;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (floor.areas.isEmpty) {
      return EmptyView(
        icon: Icons.map_outlined,
        title: 'No dining areas',
        message: 'This outlet has no areas or tables set up yet. '
            'A manager can add them in the web console.',
        action: FilledButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Check again'),
        ),
      );
    }

    // Default to the first area rather than forcing a choice before anything
    // is visible.
    final activeId = floor.areas.any((a) => a.id == selectedAreaId)
        ? selectedAreaId!
        : floor.areas.first.id;
    final tables = floor.tablesIn(activeId);

    return Column(
      children: [
        if (floor.isStale) _StaleBanner(readAt: floor.readAt),
        _SummaryBar(floor: floor),
        if (floor.areas.length > 1)
          _AreaSelector(
            floor: floor,
            activeId: activeId,
            onSelected: onAreaSelected,
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: tables.isEmpty
                ? ListView(
                    // Must scroll, or pull-to-refresh cannot fire on an empty area.
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      EmptyView(
                        icon: Icons.table_bar_outlined,
                        title: 'No tables in this area',
                      ),
                    ],
                  )
                : _TableLayout(
                    floor: floor,
                    tables: tables,
                    draftTableIds: draftTableIds,
                    pendingSendTableIds: pendingSendTableIds,
                  ),
          ),
        ),
      ],
    );
  }
}

/// The floor could not be read, so this is the last one we had.
///
/// Stated loudly and permanently rather than as a toast: the tables and areas
/// are still right — a dining room does not move — but the ORDER state is the
/// half a waiter acts on, and a stale "Ready" badge sends someone to the pass
/// for food that was run ten minutes ago.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.readAt});

  final DateTime? readAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      color: theme.colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded,
              size: 18, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              readAt == null
                  ? 'Offline — showing the last floor we could load. Order '
                      'status may have changed.'
                  : 'Offline — this floor is from '
                      '${DateFormat.Hm().format(readAt!)}. Order status may '
                      'have changed since.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.floor});

  final FloorSnapshot floor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = floor.readyCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        children: [
          _Metric(
            label: 'Open bills',
            value: '${floor.openOrderCount}',
            icon: Icons.receipt_long_outlined,
          ),
          const SizedBox(width: AppSpacing.xl),
          _Metric(
            label: 'Ready to serve',
            value: '$ready',
            icon: Icons.room_service_outlined,
            // Only emphasised when there is something to do — a permanently
            // coloured badge stops being noticed.
            highlight: ready > 0,
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The fill palette is tuned for borders and icons; small text needs the
    // darker variant to clear WCAG AA.
    final color = highlight
        ? AppStatusColors.textOn(AppStatusColors.ready)
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Text(
          value,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700, color: color),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _AreaSelector extends StatelessWidget {
  const _AreaSelector({
    required this.floor,
    required this.activeId,
    required this.onSelected,
  });

  final FloorSnapshot floor;
  final String activeId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: floor.areas.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final area = floor.areas[index];
          return Center(
            child: ChoiceChip(
              selected: area.id == activeId,
              onSelected: (_) => onSelected(area.id),
              label: Text('${area.name} (${area.tableCount})'),
            ),
          );
        },
      ),
    );
  }
}

/// Renders the designer's actual layout when coordinates exist, and a
/// responsive grid when they do not (brief §7 — use the backend's layout
/// metadata, never invent a second incompatible one).
class _TableLayout extends StatelessWidget {
  const _TableLayout({
    required this.floor,
    required this.tables,
    required this.draftTableIds,
    required this.pendingSendTableIds,
  });

  final FloorSnapshot floor;
  final List<RestaurantTable> tables;
  final Set<String> draftTableIds;
  final Set<String> pendingSendTableIds;

  /// Below this a table is not reliably tappable by someone walking.
  ///
  /// The Material minimum is 48; a waiter is doing this one-handed, at speed,
  /// carrying something in the other hand.
  static const _minTouchTarget = 48.0;

  @override
  Widget build(BuildContext context) {
    final positioned = tables.where((t) => t.position != null).toList();

    // Mixed data (some tables never dragged onto the canvas) would render a
    // misleading half-plan, so the grid is used unless every table is placed.
    final useSpatial =
        positioned.length == tables.length && positioned.isNotEmpty;

    if (!useSpatial) {
      return _TableGrid(
        floor: floor,
        tables: tables,
        draftTableIds: draftTableIds,
        pendingSendTableIds: pendingSendTableIds,
      );
    }

    // A designer's canvas can be far wider than a tablet. Scaled to fit, a
    // table on a big plan can end up a few pixels across — spatially faithful
    // and completely untappable. Where that happens the grid wins: a waiter who
    // cannot hit the table has no floor plan at all.
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _scaleFor(tables, constraints.maxWidth);
        final smallest = tables
            .map((t) => t.position!)
            .map((p) => (p.width < p.height ? p.width : p.height) * scale)
            .reduce((a, b) => a < b ? a : b);

        if (smallest < _minTouchTarget) {
          return _TableGrid(
            floor: floor,
            tables: tables,
            draftTableIds: draftTableIds,
            pendingSendTableIds: pendingSendTableIds,
          );
        }
        return _SpatialFloorPlan(
          floor: floor,
          tables: tables,
          draftTableIds: draftTableIds,
          pendingSendTableIds: pendingSendTableIds,
        );
      },
    );
  }

  /// The uniform scale that fits the designer's canvas into [width].
  ///
  /// Shared with [_SpatialFloorPlan] so the decision to fall back and the
  /// layout that follows it cannot disagree.
  static double _scaleFor(List<RestaurantTable> tables, double width) {
    var maxX = 0.0;
    for (final table in tables) {
      final p = table.position!;
      if (p.x + p.width > maxX) maxX = p.x + p.width;
    }
    maxX += 24;
    return (width / maxX).clamp(0.1, 3.0);
  }
}

class _SpatialFloorPlan extends StatelessWidget {
  const _SpatialFloorPlan({
    required this.floor,
    required this.tables,
    required this.draftTableIds,
    required this.pendingSendTableIds,
  });

  final FloorSnapshot floor;
  final List<RestaurantTable> tables;
  final Set<String> draftTableIds;
  final Set<String> pendingSendTableIds;

  @override
  Widget build(BuildContext context) {
    // Bounding box of the designer's canvas for this area.
    var maxY = 0.0;
    for (final table in tables) {
      final p = table.position!;
      if (p.y + p.height > maxY) maxY = p.y + p.height;
    }
    // Breathing room so edge tables are not flush against the frame.
    maxY += 24;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Uniform scale preserves the room's proportions — a waiter navigates
        // by spatial memory, so stretching the plan to fill the screen would
        // actively mislead.
        final scale = _TableLayout._scaleFor(tables, constraints.maxWidth);
        final height = maxY * scale;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height:
                height < constraints.maxHeight ? constraints.maxHeight : height,
            child: Stack(
              children: [
                for (final table in tables)
                  Positioned(
                    left: table.position!.x * scale,
                    top: table.position!.y * scale,
                    width: table.position!.width * scale,
                    height: table.position!.height * scale,
                    child: Transform.rotate(
                      angle: table.position!.rotation * 3.1415926535 / 180,
                      child: TableCard(
                        table: table,
                        order: floor.orderFor(table),
                        hasDraft: draftTableIds.contains(table.id),
                        hasPendingSend: pendingSendTableIds.contains(table.id),
                        compact: true,
                        onTap: () => _openTable(context, table),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TableGrid extends StatelessWidget {
  const _TableGrid({
    required this.floor,
    required this.tables,
    required this.draftTableIds,
    required this.pendingSendTableIds,
  });

  final FloorSnapshot floor;
  final List<RestaurantTable> tables;
  final Set<String> draftTableIds;
  final Set<String> pendingSendTableIds;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        // Responsive rather than a fixed column count, so a phone and a 10"
        // tablet both get sensibly sized targets (brief §23/§37).
        maxCrossAxisExtent: AppSizes.tableCardMin,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.95,
      ),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final table = tables[index];
        return TableCard(
          table: table,
          order: floor.orderFor(table),
          hasDraft: draftTableIds.contains(table.id),
          hasPendingSend: pendingSendTableIds.contains(table.id),
          onTap: () => _openTable(context, table),
        );
      },
    );
  }
}

/// Open the table's ticket.
///
/// The table travels as `extra` so the ticket screen does not have to wait on a
/// floor fetch it already has the answer to; the id in the path is what makes
/// the route survive without it.
void _openTable(BuildContext context, RestaurantTable table) {
  context.push(Routes.ticket(table.id), extra: table);
}
