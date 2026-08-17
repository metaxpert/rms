import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../l10n/strings.dart';
import '../domain/branch.dart';
import '../theme/app_theme.dart';
import '../widgets/app_surfaces.dart';
import '../widgets/state_views.dart';
import 'branch_repository.dart';

/// Outlet picker. Every branch-scoped read depends on this choice, so it is a
/// gate rather than a setting buried in a menu.
///
/// Shared by all four apps: an outlet means the same thing to a rider as to a
/// waiter, and the consequence of skipping it is the same everywhere — every
/// branch-scoped read silently falls back to another outlet's data.
class BranchSelectionScreen extends ConsumerWidget {
  const BranchSelectionScreen({super.key, this.title});

  /// Defaults to the shared "Choose your outlet"; apps override it where their
  /// own word is clearer ("Which kitchen?" for a rider).
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(branchesProvider);
    final text = strings(context);

    return HeroScaffold(
      // The last step of the sign-in journey, so it carries the same brand panel
      // the sign-in screen behind it does rather than dropping to a plain app bar
      // halfway through.
      header: AppHeroHeader(
        title: title ?? text.chooseOutlet,
        subtitle: text.chooseOutletBlurb,
        actions: [
          HeroIconButton(
            icon: Icons.logout_rounded,
            tooltip: text.signOut,
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      overlap: AppSpacing.md,
      body: branches.when(
        loading: () => LoadingView(message: text.outletsLoading),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(branchesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyView(
              icon: Icons.storefront_outlined,
              title: text.outletsEmptyTitle,
              message: text.outletsEmptyMessage,
              action: FilledButton.icon(
                onPressed: () => ref.invalidate(branchesProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(text.checkAgain),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(branchesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: list.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => _BranchTile(branch: list[index]),
            ),
          );
        },
      ),
    );
  }
}

class _BranchTile extends ConsumerWidget {
  const _BranchTile({required this.branch});

  final Branch branch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectable = branch.isSelectable;

    // Why an outlet cannot be picked, in words a waiter can act on. An
    // unconfigured outlet would accept an order and then fail at settlement,
    // which is far worse than being unavailable up front.
    final text = strings(context);
    final blockedReason = !branch.active
        ? text.outletClosed
        : !branch.configured
            ? text.outletNotConfigured
            : null;

    return AppCard(
      onTap: selectable
          ? () =>
              ref.read(authControllerProvider.notifier).selectBranch(branch.id)
          : null,
      // Composed rather than left to eight separate fragments, so a screen
      // reader announces one outlet and whether it can be picked.
      semanticLabel: [
        branch.name,
        if (branch.code.isNotEmpty) branch.code,
        if (blockedReason != null) blockedReason,
      ].join(', '),
      child: Row(
        children: [
          // The glyph in a tinted well, matching the metric tiles and the
          // rider's duty card: an icon loose against a card edge is the
          // detail that made every one of these lists look unfinished.
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selectable
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                  : theme.colorScheme.surfaceContainerHighest,
            ),
            child: Icon(
              Icons.storefront_rounded,
              size: 26,
              color: selectable
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selectable ? null : theme.colorScheme.outline,
                  ),
                ),
                if (branch.code.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    branch.code,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
                if (blockedReason != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  StatusBadge(
                    label: blockedReason,
                    color: theme.colorScheme.error,
                    icon: Icons.block_rounded,
                  ),
                ],
              ],
            ),
          ),
          if (selectable) const Icon(Icons.chevron_right_rounded, size: 28),
        ],
      ),
    );
  }
}
