import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:rms_core/rms_core.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_text.dart';
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
    final text = appText(context);
    final board = snapshot.board;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (snapshot.readyToServe > 0)
          AppNotice(
            icon: Icons.room_service_rounded,
            // The colour a manager has already learned means food at the pass.
            accent: AppStatusColors.ready,
            title: text.ordersReadyToRun(snapshot.readyToServe),
            message: text.foodUpAtPass,
          ),
        if (board.overdueCount > 0)
          AppNotice(
            icon: Icons.local_fire_department_rounded,
            tone: NoticeTone.danger,
            title: text.ticketsPastTarget(board.overdueCount),
            message: text.longestWaiting(_wait(text, board.longestWait)),
          ),
        _TileGrid(
          tiles: [
            MetricTile(
              label: text.kpiOpenBills,
              value: '${snapshot.openOrders.length}',
              detail: snapshot.openValue.display,
              icon: Icons.receipt_long_outlined,
            ),
            MetricTile(
              label: text.kpiReadyToServe,
              value: '${snapshot.readyToServe}',
              detail: snapshot.readyToServe > 0 ? text.goNow : text.nothingWaiting,
              icon: Icons.room_service_outlined,
              highlight: snapshot.readyToServe > 0,
            ),
            MetricTile(
              label: text.kpiKitchenTickets,
              value: '${board.ticketCount}',
              detail: board.ticketCount == 0
                  ? text.kitchenClear
                  : text.longestIs(_wait(text, board.longestWait)),
              icon: Icons.soup_kitchen_outlined,
              highlight: board.overdueCount > 0,
              // Overdue tickets are a problem, not an opportunity; the tile
              // should not borrow the "go now" cyan for it.
              highlightColor: AppStatusColors.cancelled,
            ),
            MetricTile(
              label: text.kpiTablesInUse,
              value: '${snapshot.occupiedTables}/${snapshot.totalTables}',
              detail: snapshot.totalTables == 0
                  ? text.noTablesSetUp
                  : text.percentFull(
                      _percent(snapshot.occupiedTables, snapshot.totalTables)),
              icon: Icons.table_restaurant_outlined,
            ),
            MetricTile(
              label: text.kpiSettled,
              value: '${snapshot.settledOrders.length}',
              detail: snapshot.settledValue.display,
              icon: Icons.payments_outlined,
            ),
            MetricTile(
              label: text.kpiDeliveriesOut,
              value: '${snapshot.activeDeliveries.length}',
              detail: snapshot.activeDeliveries.isEmpty
                  ? text.noneOnTheRoad
                  : text.onTheRoad,
              icon: Icons.two_wheeler_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          // Every figure here is derived from one read; saying when it was
          // taken is the difference between a dashboard and a guess.
          text.readAt(DateFormat.Hms().format(snapshot.takenAt)),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  static String _wait(AppText text, Duration duration) {
    final minutes = duration.inMinutes;
    return minutes < 1 ? text.underAMinute : text.minutesShort(minutes);
  }

  static String _percent(int part, int whole) =>
      whole == 0 ? '0%' : '${(part * 100 / whole).round()}%';
}

/// The KPI grid, in as many columns as the device can hold.
///
/// Was a fixed two. Two is right on a phone — a manager glances at this between
/// two other jobs, and a tile narrower than about half a phone stops being
/// legible at arm's length — but it is wrong on the 10" tablet propped by the
/// till, where it produced two tiles the size of playing cards and a column of
/// dead space down each side.
/// The KPI grid, in as many columns as the device can hold.
///
/// Was a fixed two. Two is right on a phone — a manager glances at this between
/// two other jobs — but it was wrong on the 10" tablet propped by the till,
/// where it produced two tiles the size of playing cards and a column of dead
/// space down each side.
///
/// The lever is the tile's maximum width, not the column count. Capping columns
/// looks like the same thing and is not: a four-column cap on a landscape
/// tablet just makes each tile 280 pixels wide, which is a bigger playing card.
/// Capping the extent keeps a tile the size a tile should be and spends the
/// extra width on more of them.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});

  final List<MetricTile> tiles;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: kpiGridDelegate,
      itemCount: tiles.length,
      itemBuilder: (context, index) => tiles[index],
    );
  }
}

/// Shared with the loading skeleton, so the placeholder grid and the real one
/// cannot disagree about how many columns are about to appear.
const kpiGridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  // Wide enough for "12/40" and a label at the largest text size this app
  // honours; narrow enough that a landscape tablet gets more tiles rather than
  // fatter ones.
  maxCrossAxisExtent: 240,
  mainAxisSpacing: AppSpacing.md,
  crossAxisSpacing: AppSpacing.md,
  childAspectRatio: 1.35,
);
