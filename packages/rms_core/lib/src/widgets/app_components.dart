import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The pieces that were being written out once per screen.
///
/// Each of these existed already — three or four times over, in three or four
/// apps, with the letter-spacing and the padding *almost* the same. That is the
/// expensive kind of inconsistency: nobody can point at it, everybody can feel
/// it, and fixing one copy leaves the others behind.
///
/// Nothing is extracted here on the strength of being used twice. Each one is
/// something a user is meant to recognise across screens — a section boundary,
/// a figure worth glancing at, a warning worth stopping for — where the
/// recognition IS the feature.

/// A boundary between groups in a list.
///
/// Uppercase and tracked-out rather than large: a section header is scaffolding
/// for the eye, and it should lose to the content under it.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key, this.trailing, this.padding});

  final String label;

  /// A count, a total — whatever makes the section worth skipping or reading.
  final Widget? trailing;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding ??
          const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          if (trailing != null)
            DefaultTextStyle.merge(
              style: theme.textTheme.labelLarge!,
              child: trailing!,
            ),
        ],
      ),
    );
  }
}

/// A figure worth walking somewhere about.
///
/// The hierarchy is fixed on purpose — label, then value, then the one line of
/// context that makes the value actionable — because a grid of tiles that each
/// arrange themselves differently is a grid nobody can scan.
///
/// [highlight] is for tiles that need someone to *do* something. It is not a
/// severity level and it is not decoration: a tile that is always coloured
/// stops being noticed within a shift, which is the failure mode this exists to
/// avoid.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    this.highlight = false,
    this.highlightColor,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? detail;
  final bool highlight;

  /// Which status this tile is calling out, when it is calling one out. Defaults
  /// to the "food is up" cyan, which is what most of them mean.
  final Color? highlightColor;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = highlightColor ?? AppStatusColors.ready;

    // Fills, borders and icons take the status colour as-is for the brightness;
    // the label beside them is small text and needs the corrected variant.
    final fill = context.statusFill(accent);
    final ink = highlight
        ? context.statusText(accent)
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: onTap != null,
      label: [label, value, if (detail != null) detail].join(': '),
      child: Material(
        color: highlight
            ? fill.withValues(alpha: 0.12)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: highlight
                  ? Border.all(color: fill.withValues(alpha: 0.5))
                  : null,
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: ink),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(color: ink),
                      ),
                    ),
                  ],
                ),
                // Scaled down rather than clipped or ellipsised. A KPI tile has
                // one job and it is showing the number: "45,678.90" truncated
                // to "45,67…" is worse than the same figure a few points
                // smaller, and at a 1.3x text scale on a small phone the full
                // size does not fit. Flexible lets it give up height first,
                // FittedBox spends that height on the glyphs.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                ),
                if (detail != null)
                  Flexible(
                    child: Text(
                      detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How loudly a notice speaks.
enum NoticeTone {
  /// Something is true that the reader did not ask about but should know.
  info,

  /// Something is degraded but the screen still works — stale data, a feed
  /// that dropped. The reader can carry on, differently.
  warning,

  /// Something failed, or is about to cost money. Worth stopping for.
  danger,

  /// Something worked, and saying so is worth the space.
  success,
}

/// An inline notice, pinned in the flow rather than floating over it.
///
/// Deliberately not a snackbar. A snackbar is right for "added to the basket"
/// and wrong for "these figures are ten minutes old", because the second one
/// stays true after three seconds and a waiter who looked away has no way to
/// get it back. Anything that remains true is stated in place, and stays.
class AppNotice extends StatelessWidget {
  const AppNotice({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.tone = NoticeTone.info,
    this.accent,
    this.action,
    this.margin,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final NoticeTone tone;

  /// A specific status to paint this in, when the notice is *about* that
  /// status — "four orders are ready to run" belongs in the ready cyan, not in
  /// a generic informational blue, because that is the colour the reader has
  /// already learned means food at the pass.
  final Color? accent;

  final Widget? action;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final accent = this.accent;
    final base = accent != null
        ? context.statusFill(accent)
        : switch (tone) {
            NoticeTone.info => theme.colorScheme.primary,
            NoticeTone.warning => context.statusFill(AppStatusColors.preparing),
            NoticeTone.danger => theme.colorScheme.error,
            NoticeTone.success => context.statusFill(AppStatusColors.available),
          };
    final ink = accent != null
        ? context.statusText(accent)
        : switch (tone) {
            NoticeTone.info => theme.colorScheme.primary,
            NoticeTone.warning => context.statusText(AppStatusColors.preparing),
            NoticeTone.danger => theme.colorScheme.error,
            NoticeTone.success => context.statusText(AppStatusColors.available),
          };
    final glyph = icon ??
        switch (tone) {
          NoticeTone.info => Icons.info_outline_rounded,
          NoticeTone.warning => Icons.warning_amber_rounded,
          NoticeTone.danger => Icons.error_outline_rounded,
          NoticeTone.success => Icons.check_circle_outline_rounded,
        };

    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        border: Border.all(color: base.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(glyph, color: ink, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(color: ink),
                ),
                if (message != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(message!, style: theme.textTheme.bodySmall),
                ],
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A search box that can be emptied.
///
/// The clear button is the whole reason this is shared. Typing five characters
/// and then backspacing them one at a time is a thing people do when there is
/// no cross to tap, and on a menu of two hundred dishes it is done several times
/// a service.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.clearTooltip,
    required this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hintText;

  /// The icon alone says nothing to a screen reader.
  final String clearTooltip;

  final ValueChanged<String> onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        textCapitalization: TextCapitalization.none,
        autocorrect: false,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search_rounded),
          // Collapsed rather than a lighter cross, so the field does not
          // reserve a hole on the right when there is nothing to clear.
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.close_rounded),
                  tooltip: clearTooltip,
                ),
          // Shorter than the form default: this sits above a list and every
          // pixel it takes is a pixel of results.
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),
    );
  }
}

/// Fades and lifts its child in once, on first build.
///
/// Used where content replaces a skeleton, so the arrival reads as the data
/// landing rather than as a flicker. Collapses to nothing when the platform
/// asks for reduced motion, and the travel is 8 pixels — enough to register,
/// too little to wait for.
class FadeIn extends StatefulWidget {
  const FadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 8,
  });

  final Widget child;

  /// A small stagger between siblings reads as one list arriving. More than a
  /// few tens of milliseconds reads as a slow app.
  final Duration delay;

  final double offset;

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return widget.child;

    final curved = CurvedAnimation(parent: _controller, curve: AppMotion.enter);
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.offset * (1 - curved.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Ask before doing something that cannot be taken back.
///
/// Centralised so the button order is the same everywhere: the safe choice on
/// the left as a text button, the committing one on the right as a filled
/// button, and [isDestructive] paints that one in the error colour. Staff build
/// muscle memory for dialogs faster than for anything else on screen, and a
/// dialog that swaps its buttons round is how a round gets cleared by accident.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool isDestructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
