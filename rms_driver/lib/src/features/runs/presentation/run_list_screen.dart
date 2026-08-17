import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:rms_core/rms_core.dart';
import '../../../app/router/app_router.dart';
import '../../../l10n/app_text.dart';
import '../data/delivery_repository.dart';
import '../data/driver_repository.dart';

/// The rider's board.
///
/// Ordered by how close each job is to a waiting customer, not by when it was
/// created: a bag already on the bike outranks one still on the pass.
class RunListScreen extends ConsumerWidget {
  const RunListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(runBoardProvider);
    final text = appText(context);

    return HeroScaffold(
      header: AppHeroHeader(
        title: text.runsTitle,
        // The outlet the rider is collecting from — not `yourRunsOnly`, which is
        // a two-line explanation that ellipsised to "These are your runs only. A
        // job you cann…" in a header, and which is still stated in full at the
        // foot of the board where there is room for it.
        subtitle: _outletName(ref),
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
      ),
      // The duty card is pulled up over the header's edge. It is the most
      // important control in this app — a rider who has not clocked on gets no
      // work at all — and as a tinted strip welded under an app bar it read as a
      // notification about the screen rather than as the switch that turns it on.
      overlap: AppSpacing.lg,
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _DutyBar(),
          ),
          Expanded(child: _board(context, ref, board)),
        ],
      ),
    );
  }

  Widget _board(
      BuildContext context, WidgetRef ref, AsyncValue<RunBoard> board) {
    final text = appText(context);
    return board.when(
      loading: () => LoadingView(
        message: text.runsLoading,
        // A rider opens this at a kerb with one hand. Cards forming says the
        // phone found the server; a spinner says nothing either way.
        skeleton: const SkeletonList(rows: 4, rowHeight: 148),
      ),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(runBoardProvider),
      ),
      data: (board) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(runBoardProvider);
          ref.invalidate(driverProfileProvider);
        },
        child: board.isEmpty
            ? ListView(
                // Must scroll or pull-to-refresh cannot fire when empty.
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  EmptyView(
                    icon: Icons.two_wheeler_outlined,
                    title: text.nothingToDeliverTitle,
                    message: text.nothingToDeliverMessage,
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (board.active.isNotEmpty) ...[
                    SectionHeader(text.sectionOnTheGo),
                    for (final delivery in board.active)
                      _RunTile(delivery: delivery),
                  ],
                  if (board.finished.isNotEmpty) ...[
                    SectionHeader(text.sectionDoneToday),
                    for (final delivery in board.finished)
                      _RunTile(delivery: delivery, dimmed: true),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    // Was "this is the whole outlet's board", which stopped
                    // being true when the server began scoping runs to the
                    // signed-in rider. A rider seeing only their own work
                    // needs to know that is deliberate, or a quiet shift
                    // reads as a broken app.
                    text.yourRunsOnly,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}

/// The outlet this rider is collecting from, or null while the branch list is
/// still in flight.
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

/// The shift control, pinned above the board.
///
/// A rider who has not started their shift gets no work — dispatch cannot assign
/// to someone off duty — so the state of that switch is the first thing the
/// screen has to answer, before the (correctly) empty list below it prompts the
/// wrong question.
class _DutyBar extends ConsumerWidget {
  const _DutyBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(driverProfileProvider);
    final theme = Theme.of(context);
    final text = appText(context);

    return profile.when(
      loading: () =>
          const SizedBox(height: 4, child: LinearProgressIndicator()),
      // A rider whose login is not linked to a roster record cannot be helped by
      // retrying, so they are told who can help instead.
      error: (error, _) => AppNotice(
        tone: NoticeTone.danger,
        icon: Icons.badge_outlined,
        title: error is ApiException && error.kind == ApiErrorKind.forbidden
            ? text.riderNotLinked
            : text.riderProfileUnavailable,
        margin: EdgeInsets.zero,
      ),
      data: (me) {
        final busy = ref.watch(_dutyBusyProvider);
        final onShift = me.isOnShift;

        return AnimatedContainer(
          // Clocking on is the one thing that changes what the rest of this
          // screen means; the card changing colour under the thumb is the
          // confirmation, so it is worth animating rather than snapping.
          duration: AppMotion.of(context),
          curve: AppMotion.standard,
          child: AppCard(
            // Green while on shift, plain while off — the accent rail and the
            // tint come from the same "available" status the rest of the product
            // uses for "ready to work", resolved for the brightness by AppCard.
            accent: onShift ? AppStatusColors.available : null,
            raised: true,
            child: Row(
              children: [
                // The rider, at the size a person's own name deserves on the
                // device they were handed at the start of a shift. This is the
                // closest thing this app has to a profile, so it says who is
                // signed in, whether they are clocked on, and what they have
                // done today.
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: onShift
                        ? context
                            .statusFill(AppStatusColors.available)
                            .withValues(alpha: 0.18)
                        : theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: Icon(
                    onShift
                        ? Icons.two_wheeler_rounded
                        : Icons.bedtime_outlined,
                    size: 22,
                    color: onShift
                        ? context.statusText(AppStatusColors.available)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        me.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        onShift
                            ? text.onShiftSummary(
                                me.liveRuns, me.deliveredToday)
                            : text.offShift,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (busy)
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (onShift)
                  TextButton(
                    // Refused server-side while holding work, so it is disabled
                    // here rather than offered and then rejected.
                    onPressed:
                        me.canEndShift ? () => _setDuty(ref, false) : null,
                    child: Text(text.endShift),
                  )
                else
                  FilledButton(
                    onPressed: () => _setDuty(ref, true),
                    child: Text(text.startShift),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _setDuty(WidgetRef ref, bool onShift) async {
    ref.read(_dutyBusyProvider.notifier).state = true;
    try {
      await ref.read(driverRepositoryProvider).setDuty(onShift: onShift);
      ref.invalidate(driverProfileProvider);
      ref.invalidate(runBoardProvider);
    } finally {
      ref.read(_dutyBusyProvider.notifier).state = false;
    }
  }
}

final _dutyBusyProvider = StateProvider<bool>((ref) => false);

class _RunTile extends StatelessWidget {
  const _RunTile({required this.delivery, this.dimmed = false});

  final Delivery delivery;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = appText(context);
    final accent = delivery.status.color;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      onTap: () => context.push(Routes.run(delivery.id)),
      // The rail down the leading edge carries the run's status in the one place
      // a rider glancing at the board while holding a bag will actually see it.
      // Not on finished runs: a column of coloured rails where most of them are
      // history is a column of rails nobody reads.
      accent: dimmed ? null : delivery.status.color,
      padding: EdgeInsets.only(
        // Clear of the rail.
        left: dimmed ? AppSpacing.lg : AppSpacing.lg + AppSpacing.xs,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg,
      ),
      child: Opacity(
        opacity: dimmed ? 0.65 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    delivery.orderNo.isEmpty
                        ? delivery.deliveryNo
                        : delivery.orderNo,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusBadge(
                  label: delivery.status.labelIn(strings(context)),
                  color: accent,
                  icon: delivery.status.icon,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    delivery.address ?? text.noAddress,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if (delivery.etaMinutes != null || delivery.assignedAt != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  if (delivery.etaMinutes != null)
                    text.etaMinutes(delivery.etaMinutes!),
                  if (delivery.assignedAt != null)
                    text.assignedAt(
                        DateFormat.Hm().format(delivery.assignedAt!)),
                ].join(' · '),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (!delivery.isOwnFleet) ...[
              const SizedBox(height: AppSpacing.sm),
              StatusBadge(
                // An aggregator's rider is tracked through their platform;
                // offering buttons here would be a lie.
                label: text.notYours(delivery.provider),
                color: theme.colorScheme.outline,
                icon: Icons.info_outline,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
