import 'package:flutter/material.dart';

import '../errors/api_exception.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import 'app_components.dart';

/// Shared loading / empty / error surfaces (brief §39 — no blank white screens).
///
/// Centralised so every screen fails the same way: a waiter who has learned what
/// an error looks like on the floor screen should recognise it on the cart
/// screen without re-reading it.

/// Waiting.
///
/// Prefer passing a [skeleton] shaped like the content that is coming. The bare
/// spinner is the fallback for the cases where the shape genuinely is not known
/// yet — resolving which table a deep link points at, say — and not a default
/// worth reaching for.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message, this.skeleton});

  final String? message;

  /// A placeholder in the shape of the real content. When given, it replaces
  /// the spinner entirely rather than sitting beside it.
  final Widget? skeleton;

  @override
  Widget build(BuildContext context) {
    final skeleton = this.skeleton;
    if (skeleton != null) {
      return Semantics(
        // The skeleton itself is excluded from semantics, so this is the only
        // thing that announces the wait.
        liveRegion: true,
        label: message,
        child: skeleton,
      );
    }

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
      child: FadeIn(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            // Empty-state copy set across the full width of a tablet is a
            // single 900-pixel line nobody finishes reading.
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A tinted disc rather than a bare glyph: it gives the icon a
                // deliberate size and keeps an empty screen from reading as a
                // failed one.
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.6),
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
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

    final text = strings(context);
    final title = switch (kind) {
      ApiErrorKind.network => text.errorNoConnectionTitle,
      ApiErrorKind.unauthorized => text.errorSignedOutTitle,
      ApiErrorKind.forbidden => text.errorNotAllowedTitle,
      ApiErrorKind.notFound => text.errorNotFoundTitle,
      ApiErrorKind.rejected => text.errorRejectedTitle,
      ApiErrorKind.server => text.errorServerTitle,
      ApiErrorKind.unknown => text.errorUnknownTitle,
    };

    // Retrying a validation error or a permission denial just fails again and
    // wastes a waiter's time mid-service.
    final canRetry = onRetry != null && (api?.isRetryable ?? true);

    return Center(
      child: FadeIn(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.errorContainer
                        .withValues(alpha: 0.7),
                  ),
                  child: Icon(icon, size: 40, color: theme.colorScheme.error),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  title,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
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
                    label: Text(text.tryAgain),
                  ),
                ],
                if (api?.traceId != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  // Support cannot find the request in the API logs without this.
                  SelectableText(
                    text.errorReference(api!.traceId!),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
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

/// Status badge that never relies on colour alone (brief §25) — always a label,
/// and an icon whenever one is supplied.
///
/// The colour handed in is the status's *identity* (`OrderStatus.color` and
/// friends), which is defined for a light surface. Resolving it here, once, is
/// what stops a settled badge from rendering as dark grey text inside a dark
/// grey pill on a tablet that flipped to dark at dusk — and what gets the
/// label to WCAG AA in light mode, where several of the fill colours miss 4.5:1
/// at this size.
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
    final fill = context.statusFill(color);
    final ink = context.statusText(color);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: fill.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: fill.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: ink),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }
}
