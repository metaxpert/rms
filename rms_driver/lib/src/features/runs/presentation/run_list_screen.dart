import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:rms_core/rms_core.dart';
import '../../../app/router/app_router.dart';
import '../data/delivery_repository.dart';

/// The rider's board.
///
/// Ordered by how close each job is to a waiting customer, not by when it was
/// created: a bag already on the bike outranks one still on the pass.
class RunListScreen extends ConsumerWidget {
  const RunListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(runBoardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Runs'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).clearBranch(),
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Switch outlet',
          ),
          IconButton(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: board.when(
        loading: () => const LoadingView(message: 'Loading your runs…'),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(runBoardProvider),
        ),
        data: (board) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(runBoardProvider),
          child: board.isEmpty
              ? ListView(
                  // Must scroll or pull-to-refresh cannot fire when empty.
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 100),
                    EmptyView(
                      icon: Icons.two_wheeler_outlined,
                      title: 'Nothing to deliver',
                      message: 'New runs appear here as the kitchen dispatches '
                          'them. Pull down to check again.',
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    if (board.active.isNotEmpty) ...[
                      const _SectionHeader('On the go'),
                      for (final delivery in board.active)
                        _RunTile(delivery: delivery),
                    ],
                    if (board.finished.isNotEmpty) ...[
                      const _SectionHeader('Done today'),
                      for (final delivery in board.finished)
                        _RunTile(delivery: delivery, dimmed: true),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      // Saying so beats a rider assuming a colleague's job is
                      // theirs, or that theirs is missing.
                      'This is the whole outlet\'s board — the server does not '
                      'offer a list of just your own runs.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

class _RunTile extends StatelessWidget {
  const _RunTile({required this.delivery, this.dimmed = false});

  final Delivery delivery;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = delivery.status.color;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => context.push(Routes.run(delivery.id)),
        child: Opacity(
          opacity: dimmed ? 0.65 : 1,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
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
                      label: delivery.status.label,
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
                        delivery.address ?? 'No address on file',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                if (delivery.etaMinutes != null ||
                    delivery.assignedAt != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    [
                      if (delivery.etaMinutes != null)
                        'ETA ${delivery.etaMinutes} min',
                      if (delivery.assignedAt != null)
                        'assigned ${DateFormat.Hm().format(delivery.assignedAt!)}',
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
                    label: '${delivery.provider} — not yours to drive',
                    color: theme.colorScheme.outline,
                    icon: Icons.info_outline,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
