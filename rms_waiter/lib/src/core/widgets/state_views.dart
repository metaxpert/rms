import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../api_exception.dart';

/// Shared loading / empty / error surfaces (brief §39 — no blank white screens).
///
/// Centralised so every screen fails the same way: a waiter who has learned what
/// an error looks like on the floor screen should recognise it on the cart
/// screen without re-reading it.

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Error surface that adapts to WHY the call failed.
///
/// A waiter needs different things from "the wifi dropped" (retry) and "you may
/// not do that" (fetch a manager), so the copy and the affordances differ by
/// [ApiErrorKind] rather than showing one generic "something went wrong".
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final api = error is ApiException ? error as ApiException : null;
    final kind = api?.kind ?? ApiErrorKind.unknown;

    final icon = switch (kind) {
      ApiErrorKind.network => Icons.wifi_off_rounded,
      ApiErrorKind.unauthorized => Icons.lock_outline_rounded,
      ApiErrorKind.forbidden => Icons.block_rounded,
      ApiErrorKind.notFound => Icons.search_off_rounded,
      ApiErrorKind.rejected => Icons.report_problem_outlined,
      ApiErrorKind.server => Icons.cloud_off_rounded,
      ApiErrorKind.unknown => Icons.error_outline_rounded,
    };

    final title = switch (kind) {
      ApiErrorKind.network => 'No connection',
      ApiErrorKind.unauthorized => 'Signed out',
      ApiErrorKind.forbidden => 'Not allowed',
      ApiErrorKind.notFound => 'Not found',
      ApiErrorKind.rejected => 'Could not be done',
      ApiErrorKind.server => 'Server problem',
      ApiErrorKind.unknown => 'Something went wrong',
    };

    // Retrying a validation error or a permission denial just fails again and
    // wastes a waiter's time mid-service.
    final canRetry = onRetry != null && (api?.isRetryable ?? true);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              api?.message ?? error.toString(),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (canRetry) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
            if (api?.traceId != null) ...[
              const SizedBox(height: AppSpacing.lg),
              // Support cannot find the request in the API logs without this.
              SelectableText(
                'Ref: ${api!.traceId}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Status badge that never relies on colour alone (brief §25) — always a label,
/// and an icon whenever one is supplied.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
