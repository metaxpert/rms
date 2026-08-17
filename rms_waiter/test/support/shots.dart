import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Support for the screenshot harness: real fonts in a headless test renderer.
///
/// `flutter test` ships a placeholder font that draws every glyph as a filled
/// box, which is fine for layout assertions and useless for a picture somebody
/// has to look at. These load the Roboto and Material Icons the apps actually
/// ship with, out of the SDK's own cache.
/// `flutter test` exports FLUTTER_ROOT; the literal is the fallback for a bare
/// `dart test` run on this machine.
String get _fontDir {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/home/metaxperts/flutter';
  return '$root/bin/cache/artifacts/material_fonts';
}

Future<void> loadRealFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = await File('$_fontDir/$f').readAsBytes();
      loader.addFont(
        Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
      );
    }
    await loader.load();
  }

  await load('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

/// Re-points every text style in a theme at the loaded font.
///
/// `TextTheme.apply` only reaches the theme's own scale. Component themes that
/// captured a style at construction — the app bar title, dialogs, list tiles —
/// keep the null family they were built with, and render as boxes. They are
/// patched here one by one.
ThemeData withRealFont(ThemeData theme) {
  const family = 'Roboto';
  TextStyle? f(TextStyle? s) => s?.copyWith(fontFamily: family);

  WidgetStateProperty<TextStyle?>? state(
    WidgetStateProperty<TextStyle?>? p,
  ) =>
      p == null
          ? null
          : WidgetStateProperty.resolveWith((s) => f(p.resolve(s)));

  // A button's label style lives inside its ButtonStyle, behind the same
  // WidgetStateProperty indirection.
  ButtonStyle? button(ButtonStyle? s) =>
      s?.copyWith(textStyle: state(s.textStyle));

  return theme.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: button(theme.filledButtonTheme.style),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: button(theme.elevatedButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: button(theme.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: button(theme.textButtonTheme.style),
    ),
    segmentedButtonTheme: theme.segmentedButtonTheme.copyWith(
      style: button(theme.segmentedButtonTheme.style),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: button(theme.menuButtonTheme.style),
    ),
    floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
      extendedTextStyle: f(theme.floatingActionButtonTheme.extendedTextStyle),
    ),
    badgeTheme: theme.badgeTheme.copyWith(
      textStyle: f(theme.badgeTheme.textStyle),
    ),
    tooltipTheme: theme.tooltipTheme.copyWith(
      textStyle: f(theme.tooltipTheme.textStyle),
    ),
    popupMenuTheme: theme.popupMenuTheme.copyWith(
      textStyle: f(theme.popupMenuTheme.textStyle),
      labelTextStyle: state(theme.popupMenuTheme.labelTextStyle),
    ),
    expansionTileTheme: theme.expansionTileTheme,
    bottomNavigationBarTheme: theme.bottomNavigationBarTheme.copyWith(
      selectedLabelStyle:
          f(theme.bottomNavigationBarTheme.selectedLabelStyle),
      unselectedLabelStyle:
          f(theme.bottomNavigationBarTheme.unselectedLabelStyle),
    ),
    textTheme: theme.textTheme.apply(fontFamily: family),
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: family),
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: f(theme.appBarTheme.titleTextStyle),
      toolbarTextStyle: f(theme.appBarTheme.toolbarTextStyle),
    ),
    dialogTheme: theme.dialogTheme.copyWith(
      titleTextStyle: f(theme.dialogTheme.titleTextStyle),
      contentTextStyle: f(theme.dialogTheme.contentTextStyle),
    ),
    snackBarTheme: theme.snackBarTheme.copyWith(
      contentTextStyle: f(theme.snackBarTheme.contentTextStyle),
    ),
    listTileTheme: theme.listTileTheme.copyWith(
      titleTextStyle: f(theme.listTileTheme.titleTextStyle),
      subtitleTextStyle: f(theme.listTileTheme.subtitleTextStyle),
      leadingAndTrailingTextStyle:
          f(theme.listTileTheme.leadingAndTrailingTextStyle),
    ),
    navigationBarTheme: theme.navigationBarTheme.copyWith(
      labelTextStyle: state(theme.navigationBarTheme.labelTextStyle),
    ),
    navigationRailTheme: theme.navigationRailTheme.copyWith(
      selectedLabelTextStyle:
          f(theme.navigationRailTheme.selectedLabelTextStyle),
      unselectedLabelTextStyle:
          f(theme.navigationRailTheme.unselectedLabelTextStyle),
    ),
    chipTheme: theme.chipTheme.copyWith(
      labelStyle: f(theme.chipTheme.labelStyle),
      secondaryLabelStyle: f(theme.chipTheme.secondaryLabelStyle),
    ),
    tabBarTheme: theme.tabBarTheme.copyWith(
      labelStyle: f(theme.tabBarTheme.labelStyle),
      unselectedLabelStyle: f(theme.tabBarTheme.unselectedLabelStyle),
    ),
    inputDecorationTheme: theme.inputDecorationTheme.copyWith(
      labelStyle: f(theme.inputDecorationTheme.labelStyle),
      hintStyle: f(theme.inputDecorationTheme.hintStyle),
      helperStyle: f(theme.inputDecorationTheme.helperStyle),
      errorStyle: f(theme.inputDecorationTheme.errorStyle),
      floatingLabelStyle: f(theme.inputDecorationTheme.floatingLabelStyle),
    ),
    bannerTheme: theme.bannerTheme.copyWith(
      contentTextStyle: f(theme.bannerTheme.contentTextStyle),
    ),
    bottomSheetTheme: theme.bottomSheetTheme,
  );
}

/// Shadows are switched off inside `flutter test`, which flattens exactly the
/// elevation a design review is looking at. On for the shot, off again after —
/// and it has to be off again before the test body returns, because the
/// framework checks the flag before any tear-down runs.
void enableShadowsForShot() => debugDisableShadows = false;

void restoreShadowsAfterShot() => debugDisableShadows = true;
