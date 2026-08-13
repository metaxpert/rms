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

/// Semantic status colours.
///
/// Colour ALONE never conveys state (brief §25) — every status badge pairs
/// these with a label and an icon, because roughly 1 in 12 men has some form of
/// colour-vision deficiency and restaurant staff are not screened for it.
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
  static Color textOn(Color status) => switch (status.toARGB32()) {
        0xFF00838F => const Color(0xFF00595F), // ready
        0xFFE65100 => const Color(0xFFB33D00), // preparing
        0xFF2E7D32 => const Color(0xFF256428), // available
        _ => status,
      };
}

abstract final class AppTheme {
  static const _seed = Color(0xFF00695C);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
      // Restaurant lighting is often dim and tablets are frequently viewed at
      // an angle; the extra contrast is a legibility decision, not a stylistic
      // one (brief §23/§25).
      contrastLevel: 0.3,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minTouchTarget),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
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
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: AppSpacing.md,
      ),
    );
  }
}
