import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The surfaces a screen is built out of.
///
/// [app_components.dart] holds the pieces that carry *information* — a metric, a
/// notice, a section boundary. This file holds the things those sit on: the card
/// with a shadow under it, the header a screen opens with, the mark that says
/// which of the four apps you are holding.
///
/// The split matters because these are the pieces with a brightness-dependent
/// paint job. A card has to know whether its depth comes from a shadow (light)
/// or from tone and a seam (dark); a header has to know that white ink on a
/// gradient is legible in both. Getting that wrong is invisible in a review
/// screenshot taken at noon and unreadable on the floor at nine.

/// A raised surface.
///
/// `Card` with the theme's shadow already resolved for the brightness, plus the
/// two things nearly every card in this product needed and hand-rolled its own
/// version of: an optional status rail down the leading edge, and a tap target
/// that covers the whole surface rather than one row inside it.
///
/// Use this over a bare `Container(decoration: BoxDecoration(...))`. The custom
/// containers are what let card corners drift between 8, 12 and 16 across four
/// apps, and they are why several cards had no shadow at all in dark mode.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.accent,
    this.selected = false,
    this.raised = false,
    this.margin,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// A status colour to run down the leading edge, and to tint the fill with.
  ///
  /// The status's *identity* — `OrderStatus.color` and friends — resolved here
  /// rather than by the caller, for the same reason [StatusBadge] resolves its
  /// own: a caller who forgets fails silently, and the card still renders.
  final Color? accent;

  /// Picked out from its neighbours — the open table, the chosen category.
  final bool selected;

  /// One step further off the page, for something being acted on.
  final bool raised;

  final EdgeInsetsGeometry? margin;

  /// Set this when the card reads as one thing, so a screen reader says one
  /// thing. Composing it is the caller's job; they are the only ones who know
  /// what order the facts belong in.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final radius = BorderRadius.circular(AppRadius.xl);

    final accent = this.accent;
    final fill = accent == null ? null : context.statusFill(accent);

    final Color background;
    final Color border;
    if (fill != null) {
      // A tint of the status, not the status. The card still has to read as a
      // card first and a state second — a fully coloured card is a card nobody
      // can put text on.
      background = Color.alphaBlend(
        fill.withValues(alpha: isLight ? 0.07 : 0.13),
        isLight ? scheme.surface : scheme.surfaceContainerHigh,
      );
      border = fill.withValues(alpha: isLight ? 0.34 : 0.42);
    } else if (selected) {
      background = Color.alphaBlend(
        scheme.primary.withValues(alpha: isLight ? 0.07 : 0.14),
        isLight ? scheme.surface : scheme.surfaceContainerHigh,
      );
      border = scheme.primary.withValues(alpha: 0.6);
    } else {
      background = isLight ? scheme.surface : scheme.surfaceContainerHigh;
      border = scheme.outlineVariant.withValues(alpha: isLight ? 0.7 : 0.5);
    }

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        border: Border.all(
          color: border,
          // A selected card says so with its edge as well as its fill, because
          // the fill is a 7% tint and a tint alone does not survive glare.
          width: selected || accent != null ? 1.5 : 1,
        ),
        boxShadow: raised
            ? AppElevation.raisedShadow(theme.brightness)
            : AppElevation.resting(theme.brightness),
      ),
      child: Material(
        // The shadow is drawn by the decoration above; this layer exists only
        // to host the ink splash, so it must not paint a second background.
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (fill != null) {
      // The rail is the accessible half of the accent: a 7% fill is a hint, and
      // a 4px bar of the full status colour is a statement. Colour is never the
      // only signal, but it is allowed to be the fastest one.
      surface = Stack(
        children: [
          surface,
          PositionedDirectional(
            top: 0,
            bottom: 0,
            start: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadiusDirectional.horizontal(
                  start: Radius.circular(AppRadius.xl),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (margin != null) surface = Padding(padding: margin!, child: surface);

    if (semanticLabel != null) {
      surface = Semantics(
        container: true,
        excludeSemantics: true,
        button: onTap != null,
        label: semanticLabel,
        child: surface,
      );
    }

    return surface;
  }
}

/// The mark that says which of the four apps this is.
///
/// A rounded tile in the flavour's gradient with the app's glyph knocked out of
/// it. There is no logo asset in this repo and inventing one in code would be
/// worse than not having one — this is the honest version: the brand hue, a
/// deliberate shape, and the icon the app already uses for itself.
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({
    super.key,
    required this.icon,
    this.size = 72,
    this.onBrand = true,
  });

  final IconData icon;
  final double size;

  /// Whether this is being drawn on the brand gradient (the splash, a hero
  /// header) or on a neutral surface.
  ///
  /// It has to be told, because the two need opposite treatments and the wrong
  /// one is invisible rather than ugly: the first version of this painted the
  /// brand gradient on the mark itself, which on a gradient header is a dark
  /// tile on a dark panel — the shape vanished and only the glyph survived.
  /// On the brand it is a pane of frosted white; on a neutral surface it is the
  /// gradient it could not be on top of itself.
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = AppGradients.ink(scheme);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onBrand ? ink.withValues(alpha: 0.16) : null,
        gradient: onBrand ? null : AppGradients.action(scheme),
        // Proportional rather than a token: the mark is drawn at 44 on a login
        // screen and 96 on the splash, and a fixed 20 looks like a different
        // shape at each size.
        borderRadius: BorderRadius.circular(size * 0.28),
        border: onBrand
            ? Border.all(
                color: ink.withValues(alpha: 0.32),
                width: 1.5,
              )
            : null,
        boxShadow: onBrand
            ? null
            : AppElevation.tinted(scheme.primary, theme.brightness),
      ),
      child: Icon(icon, size: size * 0.5, color: ink),
    );
  }
}

/// The panel a screen opens with.
///
/// Replaces the pattern every one of these screens had — an `AppBar` holding a
/// bold word, and nothing else above the content. That is a title bar, not a
/// header: it spends the most valuable strip of the screen saying what the user
/// already knows, and it is the main reason these screens read as a form rather
/// than as a product.
///
/// This puts the flavour's gradient there instead, and gives the space a job:
/// the title, one line of context under it (which outlet, which table, how
/// stale the figures are), the actions that were in the app bar, and an
/// optional row of content that overlaps the boundary below.
///
/// Ink is `onPrimary` throughout. Both gradient stops come from the same tonal
/// palette as the primary, so that contrast is a property of the scheme rather
/// than of the two colours a designer happened to pick.
class AppHeroHeader extends StatelessWidget {
  const AppHeroHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.trailing,
    this.bottom,
    this.padding,
  });

  final String title;

  /// The line that makes the title mean something: which outlet, which table,
  /// what time these figures were read.
  final String? subtitle;

  /// What used to be `AppBar.actions`. Rendered against the gradient, so they
  /// inherit `onPrimary` rather than the app bar's `onSurfaceVariant`.
  final List<Widget> actions;

  final Widget? leading;

  /// A single widget pinned to the trailing edge of the title row, under the
  /// actions — a live indicator, a duty switch.
  final Widget? trailing;

  /// Content below the title block, still inside the gradient. A search field,
  /// a row of filters, a metric strip.
  final Widget? bottom;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = AppGradients.ink(scheme);

    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.hero(scheme),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.xxl),
        ),
        boxShadow: AppElevation.tinted(scheme.primary, theme.brightness),
      ),
      child: SafeArea(
        // The gradient runs up under the status bar — that is the point of it —
        // so only the bottom inset is the header's problem.
        bottom: false,
        child: Padding(
          padding: padding ??
              const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (leading != null) ...[
                    IconTheme.merge(
                      data: IconThemeData(color: ink),
                      child: leading!,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: ink,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              // Not `ink` at full strength: a subtitle that
                              // matches its title in weight and colour is a
                              // second title, and the eye stops treating either
                              // as the answer.
                              color: ink.withValues(alpha: 0.82),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    IconTheme.merge(
                      data: IconThemeData(color: ink),
                      child: DefaultTextStyle.merge(
                        style: TextStyle(color: ink),
                        child: trailing!,
                      ),
                    ),
                  ],
                  if (actions.isNotEmpty)
                    IconTheme.merge(
                      data: IconThemeData(color: ink),
                      child: Row(
                          mainAxisSize: MainAxisSize.min, children: actions),
                    ),
                ],
              ),
              if (bottom != null) ...[
                const SizedBox(height: AppSpacing.lg),
                bottom!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A control that has to sit on the hero gradient.
///
/// `IconButton` inherits the app bar's `onSurfaceVariant`, which on a saturated
/// header is a grey smear. This is the same button with a translucent well
/// behind it so it reads as a control rather than as a glyph printed on the
/// panel.
///
/// 48 square, which is what `IconButton` gives for free and what this replaced.
/// The first version drew a 44 disc because it looked better in a row of three,
/// and the waiter app's accessibility suite failed it on the spot: 44 is under
/// the platform's 48 minimum, and a header button is not exempt for being
/// pretty. The product's own 56 floor applies to the controls staff aim at
/// mid-service — a "send to kitchen", a table card — not to the chrome.
class HeroIconButton extends StatelessWidget {
  const HeroIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;

  /// Required, not optional: an icon-only control says nothing to a screen
  /// reader, and every one of these is a real action.
  final String tooltip;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ink = AppGradients.ink(Theme.of(context).colorScheme);

    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Material(
        color: ink.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Tooltip(
            message: tooltip,
            child: SizedBox(
              width: AppSizes.chromeTouchTarget,
              height: AppSizes.chromeTouchTarget,
              child: Icon(icon, size: 22, color: ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// A screen that is a hero header over a body.
///
/// The composition every screen in this product wants: gradient header, content
/// under it, and the content's first card allowed to overlap the header's
/// bottom edge so the two read as one surface rather than as two stacked
/// rectangles.
///
/// [overlap] is the amount the body is pulled up into the header. Zero for a
/// scrolling list that should start cleanly below it.
class HeroScaffold extends StatelessWidget {
  const HeroScaffold({
    super.key,
    required this.header,
    required this.body,
    this.overlap = 0,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.bottomSheet,
  });

  final AppHeroHeader header;
  final Widget body;
  final double overlap;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Widget? bottomSheet;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      bottomSheet: bottomSheet,
      body: Column(
        children: [
          header,
          Expanded(
            child: overlap > 0
                ? Transform.translate(
                    offset: Offset(0, -overlap),
                    // The pull-up would otherwise leave a strip of scaffold
                    // showing at the bottom of the screen.
                    child: Padding(
                      padding: EdgeInsets.only(bottom: overlap),
                      child: body,
                    ),
                  )
                : body,
          ),
        ],
      ),
    );
  }
}
