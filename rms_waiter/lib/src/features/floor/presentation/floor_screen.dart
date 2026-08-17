import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:rms_core/rms_core.dart';
import '../../../app/router/app_router.dart';
import '../../../l10n/app_text.dart';
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
    final text = appText(context);

    return HeroScaffold(
      header: AppHeroHeader(
        title: text.floorTitle,
        subtitle: _outletName(ref),
        trailing: const _ConnectionIndicator(),
        actions: [
          HeroIconButton(
            icon: Icons.swap_horiz_rounded,
            tooltip: text.switchOutlet,
            onPressed: () =>
                ref.read(authControllerProvider.notifier).clearBranch(),
          ),
          HeroIconButton(
            icon: Icons.logout_rounded,
            tooltip: text.signOut,
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
        // The two figures that used to live in a grey strip under the app bar:
        // what is still owed on the floor, and what is sitting at the pass going
        // cold. They are the reason a waiter looks at this screen, so they are on
        // the panel rather than in a band below it — and on the gradient they get
        // read at a glance instead of blending into the tables.
        bottom: snapshot.valueOrNull == null
            ? null
            : _ServiceStrip(floor: snapshot.value!),
      ),
      body: snapshot.when(
        loading: () => LoadingView(
          message: text.floorLoading,
          skeleton: const _FloorSkeleton(),
        ),
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

/// The floor, in outline, while the real one loads.
///
/// Shaped like what is coming — a summary strip, the area chips, then the grid
/// — so the screen does not visibly re-assemble when the data lands. On a
/// tablet that reconnects at the start of every shift this is the first thing a
/// waiter sees, and a spinner there looks the same whether the request is in
/// flight or the wifi died thirty seconds ago.
class _FloorSkeleton extends StatelessWidget {
  const _FloorSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            child: const Row(
              children: [
                Skeleton(width: 96, height: 18),
                SizedBox(width: AppSpacing.xl),
                Skeleton(width: 112, height: 18),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Skeleton(width: 108, height: 32, radius: AppRadius.pill),
                SizedBox(width: AppSpacing.sm),
                Skeleton(width: 92, height: 32, radius: AppRadius.pill),
                SizedBox(width: AppSpacing.sm),
                Skeleton(width: 84, height: 32, radius: AppRadius.pill),
              ],
            ),
          ),
          const Expanded(
            child: SkeletonGrid(
              tiles: 12,
              maxCrossAxisExtent: AppSizes.tableCardMin,
              aspectRatio: 0.95,
            ),
          ),
        ],
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
    final text = appText(context);

    // A connected socket is the normal case and needs no chrome; only its
    // absence is worth a waiter's attention.
    if (status == RealtimeStatus.live || status == RealtimeStatus.idle) {
      return const SizedBox.shrink();
    }

    final connecting = status == RealtimeStatus.connecting;
    final theme = Theme.of(context);
    // On the hero gradient now, where `onSurfaceVariant` was a grey smear.
    final ink = AppGradients.ink(theme.colorScheme);

    return Tooltip(
      message: connecting ? text.liveConnectingHint : text.liveOfflineHint,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: ink.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: ink.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              connecting ? Icons.sync_rounded : Icons.cloud_off_rounded,
              size: 14,
              color: ink,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              connecting ? text.liveConnecting : text.liveOffline,
              style: theme.textTheme.labelSmall?.copyWith(color: ink),
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
    final text = appText(context);
    if (floor.areas.isEmpty) {
      return EmptyView(
        icon: Icons.map_outlined,
        title: text.noAreasTitle,
        message: text.noAreasMessage,
        action: FilledButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(text.checkAgain),
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
        // `_SummaryBar` used to sit here. Its two metrics are in the hero header
        // now, where they are the first thing read rather than a grey band
        // between the app bar and the tables.
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
                    children: [
                      const SizedBox(height: 120),
                      EmptyView(
                        icon: Icons.table_bar_outlined,
                        title: text.noTablesInArea,
                      ),
                    ],
                  )
                // One fade for the whole plan rather than a stagger per card:
                // a floor can hold sixty tables, and sixty controllers to make
                // a grid arrive prettily is the kind of polish that shows up as
                // jank on the tablet the restaurant actually owns.
                : FadeIn(
                    child: _TableLayout(
                      floor: floor,
                      tables: tables,
                      draftTableIds: draftTableIds,
                      pendingSendTableIds: pendingSendTableIds,
                    ),
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
    final text = appText(context);

    // Was a full-bleed `errorContainer` band — the loudest surface in the app
    // for a condition where the tables on screen are still correct and only
    // their order state is behind. [AppNotice] states it just as permanently
    // without repainting the top of the floor.
    return AppNotice(
      tone: NoticeTone.warning,
      icon: Icons.wifi_off_rounded,
      title: readAt == null
          ? text.floorStaleUnknown
          : text.floorStaleAt(DateFormat.Hm().format(readAt!)),
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
    );
  }
}

/// The outlet whose floor this is.
String? _outletName(WidgetRef ref) {
  final branchId = ref.watch(sessionProvider).branchId;
  if (branchId == null) return null;
  return ref
      .watch(branchesProvider)
      .valueOrNull
      ?.where((b) => b.id == branchId)
      .map((b) => b.name)
      .firstOrNull;
}

/// The service in two figures, drawn on the hero gradient.
///
/// Replaces `_SummaryBar`, which was the same two numbers in a grey band under
/// the app bar. The numbers did not change; what changed is that they are no
/// longer competing with sixty table cards for the same neutral surface.
///
/// Ink is the header's, not the status palette's. The "ready" cyan was tuned to
/// clear AA against a light card and does not against a saturated teal panel —
/// so the count that needs attention says so with a filled pane behind it and
/// the word beside it, which works in both brightnesses and for a waiter who
/// cannot see colour.
class _ServiceStrip extends StatelessWidget {
  const _ServiceStrip({required this.floor});

  final FloorSnapshot floor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = appText(context);
    final ink = AppGradients.ink(theme.colorScheme);
    final ready = floor.readyCount;

    Widget cell({
      required String label,
      required String value,
      required IconData icon,
      required bool emphasise,
    }) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: ink.withValues(alpha: emphasise ? 0.20 : 0.10),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: ink.withValues(alpha: emphasise ? 0.45 : 0.18),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: ink),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  value,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700, color: ink),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ink.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    // Capped, and aligned to the leading edge. Two cells sharing the full width
    // of a 1194-pixel tablet gave "3 Open bills" six hundred pixels to say four
    // words in, which reads as a layout that has lost its content rather than as
    // a summary. On a phone the cap is wider than the screen and does nothing.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Row(
          children: [
            cell(
              label: text.openBills,
              value: '${floor.openOrderCount}',
              icon: Icons.receipt_long_outlined,
              emphasise: false,
            ),
            const SizedBox(width: AppSpacing.sm),
            cell(
              label: text.readyToServe,
              value: '$ready',
              icon: Icons.room_service_outlined,
              // Only when there is something to do — a permanently emphasised
              // figure stops being noticed within a shift.
              emphasise: ready > 0,
            ),
          ],
        ),
      ),
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
              label: Text(
                  appText(context).areaWithCount(area.name, area.tableCount)),
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
