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

    return Scaffold(
      appBar: AppBar(
        title: Text(appText(context).yourOrder),
        leading: IconButton(
          onPressed: () => context.go(Routes.home),
          icon: const Icon(Icons.restaurant_menu_rounded),
          tooltip: appText(context).backToMenu,
        ),
      ),
      body: tracked.when(
        loading: () => LoadingView(message: appText(context).findingOrder),
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
        Text(
          progress.headline,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          order.orderNo.isEmpty ? text.orderPlaced : order.orderNo,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        if (unsentAddress != null) _AddressWarning(address: unsentAddress!),
        const SizedBox(height: AppSpacing.xl),
        for (final step in progress.steps) _Step(step: step),
        const SizedBox(height: AppSpacing.xl),
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

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_in_talk_rounded,
                  color: theme.colorScheme.error, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  text.addressWillCallTitle,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            text.addressCouldNotAttach,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(address, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.step});

  final ProgressStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = step.active
        ? theme.colorScheme.primary
        : step.done
            ? AppStatusColors.available
            : theme.colorScheme.outline;

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: appText(context).semanticsStep(
        step.label,
        step.active
            ? appText(context).semanticsHappeningNow
            : step.done
                ? appText(context).semanticsDone
                : appText(context).semanticsToCome,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
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
            const SizedBox(width: AppSpacing.lg),
            Expanded(
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(appText(context).whatYouOrdered, style: theme.textTheme.titleSmall),
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
    );
  }
}
