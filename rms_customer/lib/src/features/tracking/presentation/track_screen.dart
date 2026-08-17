import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rms_core/rms_core.dart';
import '../../../app/router/app_router.dart';
import '../../../l10n/app_text.dart';
import '../../orders/data/customer_order_repository.dart';
import '../application/order_progress.dart';

/// Following an order from the kitchen to the door.
///
/// The backend's status names never appear here. `CONFIRMED` means something
/// precise to a kitchen and nothing to a guest; "being cooked" is what they are
/// waiting to hear. The translation lives in [OrderProgress] so no screen
/// invents its own version of it.
class TrackScreen extends ConsumerStatefulWidget {
  const TrackScreen({super.key, required this.orderId, this.unsentAddress});

  final String orderId;

  /// Set only when the address could not be attached to the order, so the
  /// customer can be told to expect a call rather than left to wonder.
  final String? unsentAddress;

  @override
  ConsumerState<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends ConsumerState<TrackScreen> {
  Timer? _timer;

  /// A guest watching this screen wants it to move. Fast enough to feel live,
  /// slow enough not to cook a phone battery while somebody waits for dinner.
  static const _interval = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      _interval,
      (_) => ref.invalidate(trackedOrderProvider(widget.orderId)),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracked = ref.watch(trackedOrderProvider(widget.orderId));

    final order = tracked.valueOrNull?.order;

    return HeroScaffold(
      header: AppHeroHeader(
        title: appText(context).yourOrder,
        // The order number, once there is one. The progress headline is a full
        // sentence — "Your food is being cooked." — so it stays in the body
        // where it can take two lines; a hero title is one line and would
        // ellipsise it mid-sentence.
        subtitle: order == null || order.orderNo.isEmpty ? null : order.orderNo,
        leading: HeroIconButton(
          icon: Icons.restaurant_menu_rounded,
          tooltip: appText(context).backToMenu,
          onPressed: () => context.go(Routes.home),
        ),
      ),
      body: tracked.when(
        loading: () => LoadingView(
          message: appText(context).findingOrder,
          skeleton: const _TrackSkeleton(),
        ),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(trackedOrderProvider(widget.orderId)),
        ),
        data: (tracked) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(trackedOrderProvider(widget.orderId)),
          child: _TrackBody(
            tracked: tracked,
            unsentAddress: widget.unsentAddress,
          ),
        ),
      ),
    );
  }
}

/// The tracker's shape while the order is fetched: a headline, then the rail of
/// steps. A guest who has just paid is watching this screen, and a spinner on
/// it is the moment they wonder whether the order went through.
class _TrackSkeleton extends StatelessWidget {
  const _TrackSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonGroup(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Skeleton.line(widthFactor: 0.7, height: 26),
          const SizedBox(height: AppSpacing.sm),
          const Skeleton.line(widthFactor: 0.35),
          const SizedBox(height: AppSpacing.xl),
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.xl),
              child: Row(
                children: [
                  Skeleton(width: 44, height: 44, radius: AppRadius.pill),
                  SizedBox(width: AppSpacing.lg),
                  Expanded(child: Skeleton.line(widthFactor: 0.55, height: 16)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TrackBody extends StatelessWidget {
  const _TrackBody({required this.tracked, required this.unsentAddress});

  final TrackedOrder tracked;
  final String? unsentAddress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = appText(context);
    final progress = OrderProgress.of(tracked, text);
    final order = tracked.order;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // The headline and the rail on one card. They are one thing — a claim
        // about where dinner is, and the evidence for it — and as loose text
        // followed by loose rows they read as two unrelated blocks with the
        // order number stranded between them.
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                progress.headline,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (order.orderNo.isEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                // Only when the header could not show it. With a number, the
                // header has it and repeating it here is noise.
                Text(
                  text.orderPlaced,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              for (var i = 0; i < progress.steps.length; i++)
                _Step(
                  step: progress.steps[i],
                  // The last step has nothing below it to join to.
                  isLast: i == progress.steps.length - 1,
                ),
            ],
          ),
        ),
        if (unsentAddress != null) _AddressWarning(address: unsentAddress!),
        const SizedBox(height: AppSpacing.lg),
        if (order.lines.isNotEmpty) _OrderLines(order: order),
        const SizedBox(height: AppSpacing.lg),
        Text(
          text.updatesAutomatically,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }
}

/// The address never reached the order, so the customer is told plainly rather
/// than left waiting for food that has nowhere to go.
class _AddressWarning extends StatelessWidget {
  const _AddressWarning({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = appText(context);

    // Was a hand-rolled container in `errorContainer` — the fifth inline banner
    // in this product to invent its own padding and radius, and the reason
    // [AppNotice] exists. Same words, same severity, drawn the way every other
    // warning in all four apps is drawn.
    return AppNotice(
      tone: NoticeTone.danger,
      icon: Icons.phone_in_talk_rounded,
      title: text.addressWillCallTitle,
      message: text.addressCouldNotAttach,
      margin: const EdgeInsets.only(top: AppSpacing.lg),
      // Selectable, because a guest on the phone to the restaurant reads this
      // back or pastes it into a message.
      action: SelectableText(address, style: theme.textTheme.bodyMedium),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.step, required this.isLast});

  final ProgressStep step;
  final bool isLast;

  static const _markerSize = 44.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = appText(context);
    final colour = step.active
        ? theme.colorScheme.primary
        : step.done
            ? context.statusFill(AppStatusColors.available)
            : theme.colorScheme.outline;

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: text.semanticsStep(
        step.label,
        step.active
            ? text.semanticsHappeningNow
            : step.done
                ? text.semanticsDone
                : text.semanticsToCome,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                // Animated because this is the one screen a guest sits and
                // watches: the marker filling in as the kitchen moves is the
                // whole point of the page.
                AnimatedContainer(
                  duration: AppMotion.of(context, AppMotion.slow),
                  curve: AppMotion.standard,
                  width: _markerSize,
                  height: _markerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colour.withValues(alpha: step.active ? 0.2 : 0.08),
                    border: Border.all(
                      color: colour.withValues(alpha: step.active ? 1 : 0.4),
                      width: step.active ? 2 : 1,
                    ),
                  ),
                  child: Icon(
                    step.done ? Icons.check_rounded : step.icon,
                    color: colour,
                  ),
                ),
                // A rail joining the markers, so the steps read as one journey
                // rather than as four unrelated rows. Coloured down to where
                // the order has actually got to.
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin:
                          const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      color: step.done
                          ? context
                              .statusFill(AppStatusColors.available)
                              .withValues(alpha: 0.5)
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.md,
                  bottom: AppSpacing.xl,
                ),
                child: Text(
                  step.label,
                  style: step.active
                      ? theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)
                      : theme.textTheme.bodyLarge?.copyWith(
                          color: step.done ? null : theme.colorScheme.outline,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderLines extends StatelessWidget {
  const _OrderLines({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(appText(context).whatYouOrdered,
              style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          for (final line in order.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('${line.qty}×',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ),
                  Expanded(child: Text(line.name)),
                  Text(line.lineTotal.display),
                ],
              ),
            ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(appText(context).total, style: theme.textTheme.titleMedium),
              Text(
                // The restaurant's figure, not the basket's estimate.
                order.totals.total.display,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
