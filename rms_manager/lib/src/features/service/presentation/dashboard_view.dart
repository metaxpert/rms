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
        // The two figures a manager is actually walking around with: what is
        // still owed on open tables, and what has been taken. Both were already
        // on this screen, as the `detail` line of two tiles in a grid of six —
        // which is to say they were the smallest text on the card holding them.
        // Same numbers, same source, given the size they are worth.
        _TakeSummary(snapshot: snapshot),
        const SizedBox(height: AppSpacing.lg),
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
        SectionHeader(text.sectionRightNow),
        const SizedBox(height: AppSpacing.xs),
        // Open bills and Settled are deliberately NOT here any more. Both were
        // a count with the money as their detail line, and the summary card
        // above now carries the same two figures *with* their counts — at a size
        // worth reading rather than as the smallest text on the card. Keeping
        // the tiles as well put each number on screen twice, which a widget
        // test caught by asking for exactly one "Rs 500.00".
        _TileGrid(
          tiles: [
            MetricTile(
              label: text.kpiReadyToServe,
              value: '${snapshot.readyToServe}',
              detail:
                  snapshot.readyToServe > 0 ? text.goNow : text.nothingWaiting,
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

/// The money, at the size the money deserves.
///
/// One card, two figures, a hairline between them. Both come straight off the
/// same snapshot every other tile on this screen reads — nothing is recomputed
/// here, and nothing new is fetched.
///
/// The figures are set in `headlineMedium` and allowed to scale down rather than
/// ellipsise: "Rs 1,356,802.44" is a number a manager is making a decision on,
/// and "Rs 1,356,8…" is not a smaller version of that decision.
class _TakeSummary extends StatelessWidget {
  const _TakeSummary({required this.snapshot});

  final ServiceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = appText(context);

    Widget half(String label, String value, IconData icon, String count) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  maxLines: 1,
                  style: theme.textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                count,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        );

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          half(
            text.summaryOnTables,
            snapshot.openValue.display,
            Icons.receipt_long_outlined,
            '${snapshot.openOrders.length} · ${text.kpiOpenBills}',
          ),
          Container(
            width: 1,
            height: 72,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            color: theme.colorScheme.outlineVariant,
          ),
          half(
            text.summaryTaken,
            snapshot.settledValue.display,
            Icons.payments_outlined,
            '${snapshot.settledOrders.length} · ${text.kpiSettled}',
          ),
        ],
      ),
    );
  }
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
