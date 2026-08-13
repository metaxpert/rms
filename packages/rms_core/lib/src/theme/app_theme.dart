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
  static const pill = 999.0;
}

abstract final class AppSizes {
  /// Minimum interactive edge. Material says 48; service staff moving quickly
  /// mis-tap at that size, and a mis-tap here means a wrong dish.
  static const minTouchTarget = 56.0;

  /// Primary actions ("Send to kitchen", "Settle") — deliberately large and
  /// hard to hit by accident, sitting away from destructive controls.
  static const primaryActionHeight = 64.0;

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

/// Depth. Used sparingly: Material 3 prefers tonal surfaces to drop shadows,
/// and a restaurant floor viewed at an angle in dim light reads a border more
/// reliably than a shadow.
///
/// Shadows here are one soft, low-opacity layer rather than the stacked
/// blur/spread of a marketing site — enough to lift a sheet off the page, not
/// enough to become the design.
abstract final class AppElevation {
  static const none = 0.0;
  static const card = 0.0;
  static const raised = 2.0;
  static const sheet = 3.0;

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
  static Color textOn(Color status, [Brightness brightness = Brightness.light]) {
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
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: AppElevation.card,
        margin: EdgeInsets.zero,
        // A tonal surface rather than plain white, so a card reads as a card
        // without needing a shadow to say so.
        color: isLight ? scheme.surfaceContainerLow : scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minTouchTarget),
          // Was xl. A full-width primary action on a 360-pixel phone at the 2x
          // text this product honours has 280 pixels for its label once xl has
          // taken 48 of them, and "Place order" with an icon needs more than
          // that. The button is already 56 tall; the air is not what makes it
          // easy to hit.
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: text.labelLarge?.copyWith(fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: text.labelLarge?.copyWith(fontSize: 16),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minTouchTarget),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
            : scheme.surfaceContainerHigh.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
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
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: AppElevation.sheet,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        elevation: AppElevation.sheet,
        backgroundColor: isLight ? scheme.surface : scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: AppElevation.raised,
        height: 72,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? text.labelMedium?.copyWith(color: scheme.onSurface)
              : text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: AppSpacing.md,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
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
