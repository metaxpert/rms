import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../authentication/application/auth_controller.dart';
import '../data/floor_repository.dart';
import '../domain/restaurant_table.dart';
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
          selectedAreaId: _selectedAreaId,
          onAreaSelected: (id) => setState(() => _selectedAreaId = id),
          onRefresh: () async => ref.invalidate(floorSnapshotProvider),
        ),
      ),
    );
  }
}

class _FloorBody extends StatelessWidget {
  const _FloorBody({
    required this.floor,
    required this.selectedAreaId,
    required this.onAreaSelected,
    required this.onRefresh,
  });

  final FloorSnapshot floor;
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
                : _TableLayout(floor: floor, tables: tables),
          ),
        ),
      ],
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
    final color =
        highlight ? AppStatusColors.ready : theme.colorScheme.onSurfaceVariant;
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
  const _TableLayout({required this.floor, required this.tables});

  final FloorSnapshot floor;
  final List<RestaurantTable> tables;

  @override
  Widget build(BuildContext context) {
    final positioned = tables.where((t) => t.position != null).toList();

    // Mixed data (some tables never dragged onto the canvas) would render a
    // misleading half-plan, so the grid is used unless every table is placed.
    final useSpatial =
        positioned.length == tables.length && positioned.isNotEmpty;

    return useSpatial
        ? _SpatialFloorPlan(floor: floor, tables: tables)
        : _TableGrid(floor: floor, tables: tables);
  }
}

class _SpatialFloorPlan extends StatelessWidget {
  const _SpatialFloorPlan({required this.floor, required this.tables});

  final FloorSnapshot floor;
  final List<RestaurantTable> tables;

  @override
  Widget build(BuildContext context) {
    // Bounding box of the designer's canvas for this area.
    var maxX = 0.0;
    var maxY = 0.0;
    for (final table in tables) {
      final p = table.position!;
      if (p.x + p.width > maxX) maxX = p.x + p.width;
      if (p.y + p.height > maxY) maxY = p.y + p.height;
    }
    // Breathing room so edge tables are not flush against the frame.
    maxX += 24;
    maxY += 24;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Uniform scale preserves the room's proportions — a waiter navigates
        // by spatial memory, so stretching the plan to fill the screen would
        // actively mislead.
        final scale = (constraints.maxWidth / maxX).clamp(0.1, 3.0);
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
  const _TableGrid({required this.floor, required this.tables});

  final FloorSnapshot floor;
  final List<RestaurantTable> tables;

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
          onTap: () => _openTable(context, table),
        );
      },
    );
  }
}

/// Opening a ticket is Phase 4. Saying so beats a dead tap that leaves a waiter
/// wondering whether the app registered it.
void _openTable(BuildContext context, RestaurantTable table) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content:
            Text('Table ${table.code} — ordering arrives in the next phase'),
      ),
    );
}
