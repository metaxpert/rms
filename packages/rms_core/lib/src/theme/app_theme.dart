import 'package:flutter/material.dart';

/// Design tokens (brief §24). Nothing styling-related may be hard-coded in a
/// widget — if a value is needed twice, it belongs here.
///
/// Sized for restaurant service rather than general mobile use: a waiter taps
/// with a thumb while holding a tray, often in poor light, sometimes with wet
/// hands. Targets are therefore larger than Material's 48dp minimum and
/// contrast is pushed above the usual defaults.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;

  /// Cards, sheets and fields. The default resting radius of the product.
  ///
  /// Larger than the 12 this used to sit at: at 12 a card on a tinted canvas
  /// reads as a box drawn on the page, and at 20 it reads as an object resting
  /// on it. The corner is doing the same work as the shadow, which is why they
  /// were raised together.
  static const xl = 20.0;

  /// Hero panels — the header a screen opens with, the splash mark.
  static const xxl = 28.0;

  static const pill = 999.0;
}

abstract final class AppSizes {
  /// Minimum interactive edge. Material says 48; service staff moving quickly
  /// mis-tap at that size, and a mis-tap here means a wrong dish.
  static const minTouchTarget = 56.0;

  /// Primary actions ("Send to kitchen", "Settle") — deliberately large and
  /// hard to hit by accident, sitting away from destructive controls.
  static const primaryActionHeight = 64.0;

  /// Chrome: the icon buttons in a header, the outlet switcher.
  ///
  /// The platform's floor, which is what `IconButton` gives by default and what
  /// the hero header's buttons replaced. Not [minTouchTarget] — 56 is for the
  /// controls staff aim at mid-service while holding a tray, and three 56dp
  /// discs in the corner of a 390-pixel header leave the title nowhere to go.
  /// It is not smaller than 48 either: the first version drew 44 and the waiter
  /// app's accessibility suite failed it immediately.
  static const chromeTouchTarget = 48.0;

  /// Floor-plan table cards; fits a 4-across grid on a 10" tablet.
  static const tableCardMin = 150.0;
  static const menuItemMin = 168.0;
}

/// Where a layout changes shape.
///
/// Named for the device class rather than the pixel count, because the pixel
/// count is the thing that keeps changing: these are Material 3's window size
/// classes, so a decision made here matches what the platform does at the same
/// width instead of disagreeing with it by 40 pixels.
abstract final class AppBreakpoints {
  /// Phones in portrait, and the narrow half of a split screen.
  static const compact = 600.0;

  /// Large phones in landscape, small tablets in portrait.
  static const medium = 840.0;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;

  /// Wide enough to hold two columns of content side by side.
  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= medium;

  // Deliberately no `columns(minExtent:, max:)` helper. It reads like the fix
  // for a hard-coded `crossAxisCount` and is the same bug wearing a hat: a
  // column cap on a landscape tablet does not give you more tiles, it gives you
  // wider ones. Where a grid should re-flow, hand Flutter a
  // SliverGridDelegateWithMaxCrossAxisExtent and cap the tile instead.
}

/// Depth.
///
/// The rule used to be "a border, never a shadow": Material 3 prefers tonal
/// surfaces, and a floor tablet viewed at an angle in dim light reads an edge
/// more reliably than a soft gradient. That reasoning holds for the *edge* and
/// was over-applied to the *depth*. A card whose only boundary is a hairline,
/// sitting on a canvas lighter than itself, has no way of reading as an object
/// — it reads as a rectangle drawn on the page, which is what made every one of
/// these screens look like a wireframe of itself.
///
/// So both now: the hairline stays, and a shadow goes under it. The canvas is
/// tinted a step darker than the card, so the card is the lightest thing on
/// screen and the shadow only has to confirm what the tone already said. That
/// ordering is what survives the dim-light-at-an-angle case, because it does
/// not depend on the shadow being visible at all.
///
/// Two layers, never more: a tight contact shadow that grounds the edge, and a
/// wide diffuse one that gives it height. The stacked five-layer blur of a
/// marketing site costs a raster pass per card on a grid of forty tables.
abstract final class AppElevation {
  static const none = 0.0;
  static const card = 0.0;
  static const raised = 2.0;
  static const sheet = 3.0;

  /// The resting shadow under a card.
  ///
  /// Tuned per brightness because they are solving different problems. On light,
  /// a black shadow at low alpha is the whole effect. On dark there is no
  /// darker to go — a shadow under a dark card on a darker canvas is invisible —
  /// so the layer is tightened and deepened to read as a seam rather than a
  /// glow, and the border carries the rest.
  static List<BoxShadow> resting(Brightness brightness) =>
      brightness == Brightness.light
          ? const [
              BoxShadow(
                color: Color(0x0D101828),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
              BoxShadow(
                color: Color(0x14101828),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ]
          : const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ];

  /// For something the user has picked up — a pressed table card, a dragged
  /// sheet, the hero panel of a screen. One step further off the page.
  static List<BoxShadow> raisedShadow(Brightness brightness) =>
      brightness == Brightness.light
          ? const [
              BoxShadow(
                color: Color(0x14101828),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
              BoxShadow(
                color: Color(0x1F101828),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ]
          : const [
              BoxShadow(
                color: Color(0x59000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ];

  /// Under a coloured surface — a gradient header, a primary action.
  ///
  /// Takes its hue from the surface it falls from. A neutral black shadow under
  /// a saturated panel reads as grime; the same shadow in the panel's own hue
  /// reads as light falling past it.
  static List<BoxShadow> tinted(Color source, Brightness brightness) => [
        BoxShadow(
          color: source.withValues(
            alpha: brightness == Brightness.light ? 0.28 : 0.44,
          ),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  /// A resting shadow for surfaces that must read as *above* the page — action
  /// bars pinned over a scrolling list, mostly. Tuned per brightness: the same
  /// black shadow that lifts a white card is invisible on a dark one, where
  /// depth has to come from the border instead.
  static List<BoxShadow> lift(Brightness brightness) =>
      brightness == Brightness.light
          ? const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, -2),
              ),
            ]
          : const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, -2),
              ),
            ];
}

/// Brand surfaces.
///
/// The four apps are told apart by one hue (see [AppFlavor]). A flat fill of
/// that hue across a header is the cheapest possible use of it — it says which
/// app this is and nothing else. A gradient across two tones of the *same*
/// generated scheme says the same thing and also gives the panel a light
/// direction, which is most of what separates a screen that looks designed from
/// one that looks themed.
///
/// Every colour here comes out of the [ColorScheme] the seed already generated.
/// Nothing is hand-picked per app, so adding a fifth flavour needs no new
/// gradients, and the contrast of ink on these surfaces is a property of the
/// scheme rather than of a designer's eye.
abstract final class AppGradients {
  /// The header a screen opens with, and the splash.
  ///
  /// Brightness-aware, and it has to be — this is the trap in building a brand
  /// panel on a Material 3 scheme. In a *light* scheme `primary` is a deep tone
  /// and `onPrimary` is white, which is the panel everyone pictures. In a dark
  /// scheme the roles invert: `primary` is a pale tint meant for text and icons,
  /// so painting the same gradient there produces a bright lavender slab across
  /// the top of an otherwise dark screen, with dark ink on it. It is legible,
  /// and it is unmistakably wrong — the loudest thing in a dark UI ends up being
  /// its chrome.
  ///
  /// So dark mode builds the panel from `primaryContainer`, which is the deep
  /// end of the same tonal palette, and takes its ink from
  /// `onPrimaryContainer`. Same hue, same gradient direction, correct polarity.
  /// Use [ink] for anything drawn on top of this rather than reaching for
  /// `onPrimary` directly.
  static LinearGradient hero(ColorScheme scheme) => scheme.brightness ==
          Brightness.light
      ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            // Lifted at the top-left rather than starting flat at the
            // primary, so the panel has somewhere to travel to. The dark end
            // is a lerp of 18% — at the 28% it started on, three of the four
            // flavours bottomed out in a near-black that read as a smudge
            // rather than as shading.
            Color.lerp(scheme.primary, scheme.primaryContainer, 0.18)!,
            scheme.primary,
            Color.lerp(scheme.primary, const Color(0xFF000000), 0.18)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        )
      : LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            // Deepened from `primaryContainer` outright. That tone measures
            // 0.175 luminance against a 0.007 canvas, which is the correct
            // polarity and still a lamp: on a phone at night the header was the
            // brightest thing on screen and the figures under it were not.
            // Two steps down keeps the hue doing its job and takes white ink
            // from 4.7:1 to about 6:1.
            Color.lerp(scheme.primaryContainer, const Color(0xFF000000), 0.15)!,
            Color.lerp(scheme.primaryContainer, const Color(0xFF000000), 0.28)!,
            Color.lerp(scheme.primaryContainer, const Color(0xFF000000), 0.48)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );

  /// The ink for anything sitting on [hero] or [action].
  ///
  /// The one thing every caller of those two gradients needs and cannot get
  /// from the scheme without knowing the polarity rule above.
  static Color ink(ColorScheme scheme) => scheme.brightness == Brightness.light
      ? scheme.onPrimary
      : scheme.onPrimaryContainer;

  /// A primary action worth looking at. Shorter run, same direction, same
  /// polarity rule as [hero].
  ///
  /// The two brightnesses lighten and darken in *opposite* directions, and that
  /// is not symmetry for its own sake. On light, `primary` is deep and lifting
  /// the top-left toward white is what makes the button look lit. On dark the
  /// base is `primaryContainer`, which is already the light end of what the ink
  /// can sit on — lifting that stop 12% toward white measured 3.77:1 against
  /// `onPrimaryContainer` on the waiter's teal, under AA, and the contrast test
  /// caught it. Dark therefore only ever darkens.
  static LinearGradient action(ColorScheme scheme) {
    if (scheme.brightness == Brightness.light) {
      final base = scheme.primary;
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(base, const Color(0xFFFFFFFF), 0.12)!,
          base,
          Color.lerp(base, const Color(0xFF000000), 0.18)!,
        ],
        stops: const [0.0, 0.5, 1.0],
      );
    }

    final base = scheme.primaryContainer;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(base, const Color(0xFF000000), 0.10)!,
        Color.lerp(base, const Color(0xFF000000), 0.22)!,
        Color.lerp(base, const Color(0xFF000000), 0.38)!,
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  /// A near-invisible wash for a large neutral panel, so a full-bleed surface
  /// is not one dead flat tone. The stops are two steps of the same neutral
  /// ramp; at these alphas it is felt rather than seen.
  static LinearGradient surface(ColorScheme scheme) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [scheme.surfaceContainerLow, scheme.surface],
      );

  /// Paints a status in its own hue as a soft fill — the tinted well behind a
  /// metric, the accent rail down a card. [brightness] resolves the status the
  /// same way [AppStatusColors.of] does, so this can never disagree with a
  /// badge drawn from the same colour.
  static LinearGradient status(Color status, Brightness brightness) {
    final base = AppStatusColors.of(status, brightness);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        base.withValues(alpha: brightness == Brightness.light ? 0.16 : 0.24),
        base.withValues(alpha: brightness == Brightness.light ? 0.06 : 0.10),
      ],
    );
  }
}

/// Motion. Fast, short, and always skippable.
///
/// Restaurant software is used against a queue. An animation that looks
/// considered on a design review looks like lag at the pass, so nothing here
/// runs longer than a third of a second and the durations collapse to zero when
/// the platform asks them to (see [AppMotion.of]).
abstract final class AppMotion {
  /// A colour or opacity change on something already on screen.
  static const fast = Duration(milliseconds: 120);

  /// The default: a card appearing, a section expanding.
  static const normal = Duration(milliseconds: 200);

  /// Reserved for a whole-screen change of state, e.g. a bill settling.
  static const slow = Duration(milliseconds: 320);

  /// Decelerating — things arrive quickly and settle. Material's "emphasized
  /// decelerate" in spirit, without pulling in the full easing set.
  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const standard = Curves.easeInOutCubic;

  /// Whether the platform's "reduce motion" accessibility setting is on.
  ///
  /// Honoured rather than noted: vestibular disorders are not rare, and a
  /// staff member cannot opt out of the app they were handed at the start of a
  /// shift.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or zero when the device has asked for reduced motion.
  static Duration of(BuildContext context, [Duration duration = normal]) =>
      reduced(context) ? Duration.zero : duration;
}

/// Semantic status colours.
///
/// Colour ALONE never conveys state (brief §25) — every status badge pairs
/// these with a label and an icon, because roughly 1 in 12 men has some form of
/// colour-vision deficiency and restaurant staff are not screened for it.
///
/// The constants below are the *identity* of each status and are what the
/// domain layer returns ([OrderStatus.color] and friends), so they stay
/// context-free. They are tuned for a light surface. Rendering them unchanged
/// on a dark one is what made a settled badge dark grey text inside a dark grey
/// pill — legible in a screenshot taken at noon and invisible on the floor at
/// night. [of] and [textOn] resolve a status for the surface it is actually
/// being drawn on; nothing should use the raw constant as a paint colour.
abstract final class AppStatusColors {
  static const available = Color(0xFF2E7D32);
  static const seated = Color(0xFF1565C0);
  static const ordering = Color(0xFF6A1B9A);
  static const preparing = Color(0xFFE65100);
  static const ready = Color(0xFF00838F);
  static const served = Color(0xFF37474F);
  static const billRequested = Color(0xFFAD1457);
  static const settled = Color(0xFF424242);
  static const cancelled = Color(0xFFB71C1C);
  static const reserved = Color(0xFF795548);

  /// Each status lifted for a dark surface.
  ///
  /// Same hue, same meaning — a waiter who has learned that cyan means "food
  /// up" must not have to re-learn it when the tablet flips to dark at dusk.
  /// Only the tone changes: roughly Material tone 40 becomes tone 70-80, which
  /// clears 4.5:1 against the dark scheme's surfaces.
  static const _onDark = <int, Color>{
    0xFF2E7D32: Color(0xFF7CC47F), // available
    0xFF1565C0: Color(0xFF8FC1F5), // seated
    0xFF6A1B9A: Color(0xFFCB92DC), // ordering
    0xFFE65100: Color(0xFFFFA95C), // preparing
    0xFF00838F: Color(0xFF52C7D6), // ready
    0xFF37474F: Color(0xFFAEBCC4), // served
    0xFFAD1457: Color(0xFFF08FB2), // billRequested
    0xFF424242: Color(0xFFBFBFBF), // settled
    0xFFB71C1C: Color(0xFFEF9A9A), // cancelled
    0xFF795548: Color(0xFFC0AAA1), // reserved
  };

  /// The same status colour, darkened enough to be legible as small text.
  ///
  /// The palette above is tuned for fills, borders and icons, where a 3:1
  /// contrast is enough. Small text needs 4.5:1 under WCAG AA, and several of
  /// these miss it — `ready` on a light surface measures 3.74:1 at 12px, which
  /// an accessibility test caught rather than a person. Using this for label
  /// text keeps one semantic palette instead of two that drift.
  ///
  /// Only the colours actually used as small text are remapped; the rest pass
  /// already and are returned unchanged.
  static const _asTextOnLight = <int, Color>{
    0xFF00838F: Color(0xFF00595F), // ready
    0xFFE65100: Color(0xFFB33D00), // preparing
    0xFF2E7D32: Color(0xFF256428), // available
    0xFF1565C0: Color(0xFF0D47A1), // seated — 4.49:1 as-is, just under AA
  };

  /// [status] as a fill, border or icon on a surface of [brightness].
  static Color of(Color status, Brightness brightness) =>
      brightness == Brightness.light
          ? status
          : (_onDark[status.toARGB32()] ?? status);

  /// [status] as small text on a surface of [brightness].
  ///
  /// The correction runs in opposite directions by design: on a light surface
  /// the fill colour is too *light* to read at 12px and is darkened; on a dark
  /// one it is too dark, and the already-lifted dark-mode tone is what reads.
  /// Applying the light-mode darkening in dark mode — which is what a single
  /// context-free table did — makes the worst case worse.
  static Color textOn(Color status,
      [Brightness brightness = Brightness.light]) {
    if (brightness == Brightness.dark) return of(status, brightness);
    return _asTextOnLight[status.toARGB32()] ?? status;
  }
}

/// Status colours resolved against the ambient theme.
///
/// Sugar over [AppStatusColors.of], but the kind worth having: the resolution
/// is easy to forget, and forgetting it is silent — the badge still renders,
/// just unreadably. A call that reads `context.statusFill(order.status.color)`
/// is harder to leave half-done than one that reads `order.status.color`.
extension AppStatusContext on BuildContext {
  Color statusFill(Color status) =>
      AppStatusColors.of(status, Theme.of(this).brightness);

  Color statusText(Color status) =>
      AppStatusColors.textOn(status, Theme.of(this).brightness);
}

/// The type scale.
///
/// Defined explicitly rather than inherited from Material's defaults, because
/// the defaults leave hierarchy to be improvised at each call site — which is
/// how a codebase ends up with `titleMedium.copyWith(fontWeight: w700)` in
/// ninety places and no two headings quite alike.
///
/// Three deliberate departures from the Material baseline, all for the same
/// reason (this is read at arm's length, in motion, in bad light):
///
/// * **Weights run heavier.** Titles are 600 where Material says 500, so a
///   heading survives a glance rather than needing to be read.
/// * **Small text is bigger.** `labelMedium` is 13 rather than 12 and
///   `bodySmall` is 13 rather than 12; the smallest thing on screen is 11 and
///   it is never load-bearing.
/// * **Line height is generous.** 1.4-1.5 on body copy, because Urdu ascenders
///   and descenders collide at Material's tighter defaults, and the same screen
///   has to hold both scripts.
///
/// Sizes only ever go *up* from Material's, never down: the accessibility suite
/// holds every screen to WCAG AA contrast, and the threshold for "large text"
/// (which relaxes 4.5:1 to 3:1) is a size boundary. Shrinking a style is a
/// contrast regression waiting to be discovered by a person rather than a test.
abstract final class AppTypography {
  static TextTheme of(ColorScheme scheme) {
    final ink = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;

    return TextTheme(
      // Reserved for a single hero number: a bill total, a KPI a manager is
      // meant to read across a room.
      displaySmall: TextStyle(
        fontSize: 36,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: ink,
      ),
      headlineLarge: TextStyle(
        fontSize: 30,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        height: 1.23,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: ink,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        height: 1.27,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: ink,
      ),
      // Screen and section titles.
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      // Running text.
      bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: ink),
      bodySmall: TextStyle(fontSize: 13, height: 1.4, color: muted),
      // Buttons, chips, badges, metadata. Heavier than body at the same size,
      // which is what separates a label from the prose around it.
      labelLarge: TextStyle(
        fontSize: 15,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: ink,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: muted,
      ),
    );
  }
}

/// Which app is being themed.
///
/// One ecosystem, four jobs. The shape of the design system — spacing, radii,
/// type scale, status palette, every component — is identical everywhere, so
/// the four apps read as one product and a member of staff who moves between
/// two of them is not re-learning anything. What differs is the primary hue,
/// which is doing one honest job: telling someone which of four apps is open on
/// a device pile at the start of a shift.
///
/// The hues are all deep and saturated so the generated schemes carry weight,
/// and none of them is a status colour: primary is chrome, and status lives in
/// badges that always carry a word and an icon as well.
enum AppFlavor {
  /// Teal. The service floor, and the original palette of the product.
  waiter(Color(0xFF00695C)),

  /// Violet-indigo. Analytical, and distinct from the driver's blue at a
  /// glance on a shelf of charging tablets.
  manager(Color(0xFF4A3B8C)),

  /// Azure. Highest legibility of the four outdoors, which is where it is read.
  driver(Color(0xFF00629E)),

  /// Crimson. The only one a guest sees, and the only one that has to look
  /// like somewhere you would eat.
  customer(Color(0xFFA32638));

  const AppFlavor(this.seed);

  /// The seed the Material 3 scheme is generated from.
  final Color seed;
}

abstract final class AppTheme {
  /// The waiter's teal, kept as the default so that `AppTheme.light()` with no
  /// argument means what it has always meant.
  static ThemeData light({AppFlavor flavor = AppFlavor.waiter}) =>
      _build(Brightness.light, flavor);

  static ThemeData dark({AppFlavor flavor = AppFlavor.waiter}) =>
      _build(Brightness.dark, flavor);

  static ThemeData _build(Brightness brightness, AppFlavor flavor) {
    final scheme = ColorScheme.fromSeed(
      seedColor: flavor.seed,
      brightness: brightness,
      // Restaurant lighting is often dim and tablets are frequently viewed at
      // an angle; the extra contrast is a legibility decision, not a stylistic
      // one (brief §23/§25).
      contrastLevel: 0.3,
    );
    final text = AppTypography.of(scheme);
    final isLight = brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      // The canvas is a step *darker* than a card, in both brightnesses.
      //
      // It used to be the other way round in light mode — `surface` behind
      // cards of `surfaceContainerLow` — which is a card darker than the page
      // it sits on. Nothing in the physical world does that, so the eye refused
      // to read those rectangles as objects and the whole product looked like a
      // wireframe of itself. Inverting it is the single change that does the
      // most work here: the card becomes the lightest thing on screen, and its
      // shadow only has to confirm what the tone has already said.
      scaffoldBackgroundColor:
          isLight ? scheme.surfaceContainerLow : scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        // Tints toward the primary as content passes under it rather than
        // dropping a shadow, so a scrolled list reads as continuing behind the
        // bar instead of ending in a line.
        scrolledUnderElevation: 3,
        surfaceTintColor: scheme.primary,
        backgroundColor: isLight ? scheme.surfaceContainerLow : scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: text.titleLarge,
        titleSpacing: AppSpacing.lg,
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 24),
        actionsIconTheme:
            IconThemeData(color: scheme.onSurfaceVariant, size: 24),
      ),
      cardTheme: CardThemeData(
        // Was flat with a hairline. The hairline stays — it is what survives a
        // tablet viewed at an angle in dim light — and a shadow goes under it.
        // See the note on [AppElevation].
        elevation: isLight ? 1.5 : 0,
        shadowColor: const Color(0xFF101828),
        // M3 would otherwise wash every card toward the primary as elevation
        // rises, which turns a neutral card faintly teal and reads as a stain.
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        color: isLight ? scheme.surface : scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(
            // Lighter than it was: with a shadow doing the lifting, a full-
            // strength border on top of it reads as two boundaries.
            color: scheme.outlineVariant.withValues(alpha: isLight ? 0.7 : 0.5),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // A primary action carries a shadow in its own hue. Restaurant staff
          // are looking for the commit button, not reading the screen; the lift
          // is how it is found without making it the loudest colour present.
          //
          // Resolved per state rather than fixed, because `styleFrom` applies one
          // number to every state: a disabled "Send · 0" kept the shadow and read
          // as a raised control that simply refused to work.
          elevation: isLight ? 2 : 0,
          shadowColor: scheme.primary.withValues(alpha: 0.5),
          minimumSize: const Size(0, AppSizes.minTouchTarget),
          // Was xl. A full-width primary action on a 360-pixel phone at the 2x
          // text this product honours has 280 pixels for its label once xl has
          // taken 48 of them, and "Place order" with an icon needs more than
          // that. The button is already 56 tall; the air is not what makes it
          // easy to hit.
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: text.labelLarge?.copyWith(fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        ).copyWith(
          elevation: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? 0
                : (isLight ? 2 : 0),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: text.labelLarge?.copyWith(fontSize: 16),
          // 1.5 rather than a hairline. A secondary action sitting next to a
          // filled one with a shadow needs enough edge to read as the same
          // class of control rather than as a disabled version of it.
          side: BorderSide(color: scheme.outline, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minTouchTarget),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // Reads as a well cut into the card rather than a box drawn on it. On
        // light that means a tint a step *below* the card it sits on, which is
        // the same figure/ground logic the canvas uses, one level down.
        fillColor: isLight
            ? scheme.surfaceContainerLow
            : scheme.surfaceContainerHigh.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          // Nearly gone at rest. The fill is already stating where the field
          // is; a full hairline on top of it is the second boundary again.
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        // Comfortably tappable: chips select a floor area or a menu category
        // mid-service, so they are a primary control here, not decoration.
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        // Resolved per state rather than fixed. A chip's label sits on the
        // surface when unselected and on `secondaryContainer` when selected,
        // and `onSurface` against the latter measures 3.7:1 — under AA, and
        // invisible in review because a selected chip still looks fine at a
        // glance.
        labelStyle: text.labelLarge?.copyWith(
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurface,
          ),
        ),
        secondaryLabelStyle: text.labelLarge?.copyWith(
          color: scheme.onSecondaryContainer,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        side: BorderSide(color: scheme.outlineVariant),
        showCheckmark: false,
        selectedColor: scheme.secondaryContainer,
        // Selection is the only state a chip has, so it gets a real one: the
        // selected chip lifts off the row rather than only changing tint.
        elevation: 0,
        pressElevation: 2,
        shadowColor: const Color(0xFF101828),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        contentTextStyle:
            text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 6,
        shadowColor: const Color(0xFF101828),
        surfaceTintColor: Colors.transparent,
        backgroundColor: isLight ? scheme.surface : scheme.surfaceContainerHigh,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        elevation: AppElevation.sheet,
        surfaceTintColor: Colors.transparent,
        backgroundColor: isLight ? scheme.surface : scheme.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: AppElevation.raised,
        // 76 rather than 72. The indicator pill grew, and a label under a
        // 56-wide pill needs the room or it sits on the pill's edge.
        height: 76,
        backgroundColor: isLight ? scheme.surface : scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0xFF101828),
        // The brand hue, not the neutral secondary. This is the one piece of
        // chrome present on every screen of the app, so it is where the flavour
        // earns its keep — and `onSecondaryContainer` was a muddy near-grey on
        // three of the four schemes.
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? text.labelMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                )
              : text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? IconThemeData(size: 26, color: scheme.onPrimaryContainer)
              : IconThemeData(size: 24, color: scheme.onSurfaceVariant),
        ),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: AppSpacing.md,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearMinHeight: 3,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          minimumSize: const WidgetStatePropertyAll(
            Size(0, AppSizes.minTouchTarget),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    );
  }
}
