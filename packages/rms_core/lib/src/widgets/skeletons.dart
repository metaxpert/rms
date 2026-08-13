import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Placeholders shaped like the content that is coming.
///
/// A centred spinner tells someone that *something* is happening. A skeleton
/// tells them what — and on a floor screen that matters more than it sounds,
/// because a waiter who can see three table cards forming knows the tablet
/// found the branch, whereas a spinner looks identical whether the request is
/// in flight or the wifi died thirty seconds ago.
///
/// The sweep is drawn once, at the group, rather than per box. One shader over
/// the whole placeholder subtree is both cheaper — a screen of twenty tiles
/// runs one animation, not twenty — and better looking, since the highlight
/// crosses the layout as a single band instead of every tile pulsing on its own
/// clock.

/// Animates a highlight across every [Skeleton] beneath it.
///
/// Falls back to flat boxes when the platform asks for reduced motion, which is
/// a real setting on a shared device somebody else configured.
class SkeletonGroup extends StatefulWidget {
  const SkeletonGroup({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonGroup> createState() => _SkeletonGroupState();
}

class _SkeletonGroupState extends State<SkeletonGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (AppMotion.reduced(context)) {
      _controller.stop();
      return widget.child;
    }

    // Excluded from semantics wholesale: a screen reader announcing eight
    // nameless boxes is worse than it announcing nothing, and the screen that
    // owns the skeleton is responsible for saying what is loading.
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            // Travels from fully off one edge to fully off the other, so the
            // band never appears to start or stop mid-screen.
            final slide = _controller.value * 3 - 1;
            return LinearGradient(
              begin: Alignment(slide - 1, -0.3),
              end: Alignment(slide + 1, 0.3),
              colors: [
                scheme.surfaceContainerHighest,
                scheme.surfaceContainerHigh,
                scheme.surfaceContainerHighest,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: child,
        ),
      ),
    );
  }
}

/// One placeholder block.
///
/// Sized by the caller to match the real thing: a skeleton whose proportions
/// are invented produces a visible jump when the content lands, which is the
/// problem it was meant to solve.
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppRadius.sm,
  }) : _fractional = false;

  /// A line of text, [widthFactor] of the space available.
  ///
  /// Fractional rather than absolute because ragged line lengths are what make
  /// a block read as prose rather than as a stack of identical bars.
  const Skeleton.line({
    super.key,
    required double widthFactor,
    this.height = 14,
  })  : width = widthFactor,
        radius = AppRadius.sm,
        _fractional = true;

  /// A card- or thumbnail-shaped block. Height is required: a placeholder that
  /// guesses its own size is what produces the jump when the content lands.
  const Skeleton.box({
    super.key,
    this.width,
    required this.height,
    this.radius = AppRadius.md,
  }) : _fractional = false;

  /// Fills whatever the parent gives it — for grid tiles, where the delegate
  /// has already decided the size.
  const Skeleton.fill({super.key, this.radius = AppRadius.md})
      : width = null,
        height = double.infinity,
        _fractional = false;

  final double? width;
  final double height;
  final double radius;

  /// Whether [width] is a fraction of the parent rather than a pixel count.
  final bool _fractional;

  @override
  Widget build(BuildContext context) {
    final block = DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(
        height: height.isFinite ? height : null,
        width: _fractional ? null : width,
      ),
    );

    if (!_fractional) {
      return height.isFinite ? block : SizedBox.expand(child: block);
    }
    return FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: width,
      child: block,
    );
  }
}

/// A stack of placeholder rows, for a list whose row height is known.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.rows = 5,
    this.rowHeight = 88,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final int rows;
  final double rowHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SkeletonGroup(
      child: ListView.separated(
        // Non-interactive, and scrolling a placeholder is meaningless.
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        itemCount: rows,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, __) => Skeleton.box(height: rowHeight),
      ),
    );
  }
}

/// A grid of placeholder tiles, sized from the same extent the real grid uses
/// so the columns do not re-flow when the data arrives.
class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({
    super.key,
    this.tiles = 8,
    required this.maxCrossAxisExtent,
    this.aspectRatio = 1,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final int tiles;
  final double maxCrossAxisExtent;
  final double aspectRatio;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SkeletonGroup(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxCrossAxisExtent,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: aspectRatio,
        ),
        itemCount: tiles,
        itemBuilder: (_, __) => const Skeleton.fill(),
      ),
    );
  }
}

/// The shape most of this product's lists actually have: a leading block, two
/// lines of text, and a trailing figure.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key, this.hasLeading = true, this.lines = 2});

  final bool hasLeading;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasLeading) ...[
            const Skeleton.box(width: 56, height: 56),
            const SizedBox(width: AppSpacing.lg),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Skeleton.line(widthFactor: 0.62, height: 16),
                for (var i = 1; i < lines; i++) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Skeleton.line(widthFactor: 0.4 - i * 0.05),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          const Skeleton(width: 64, height: 16),
        ],
      ),
    );
  }
}
