import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_surfaces.dart';

/// What the app shows while `main()` is still working.
///
/// There was nothing here before — and "nothing" is not neutral. Every one of
/// these apps does real work before its first frame: the session is read out of
/// the platform keystore, locale symbols are loaded, saved drafts are opened.
/// On a cold start on a mid-range till that is a visible pause, and what filled
/// it was the framework's bare white window. A white flash into a crimson app is
/// the cheapest-looking moment in the whole product, and it is the *first* one.
///
/// Deliberately dependency-free: no Riverpod, no localisation, no repository.
/// It has to render before any of those exist, which is the entire point of it.
/// That is also why the wording is passed in rather than looked up — the l10n
/// delegates are not installed yet.
class SplashScreen extends StatelessWidget {
  const SplashScreen({
    super.key,
    required this.flavor,
    required this.title,
    this.icon = Icons.restaurant_menu_rounded,
  });

  final AppFlavor flavor;

  /// The app's name. Not localised, because this is drawn before the
  /// localisation delegates are installed — and a proper noun would not be
  /// translated anyway.
  final String title;

  final IconData icon;

  /// The whole splash as a standalone app, for the gap in `main()` before the
  /// real one can be constructed.
  ///
  /// Two `runApp` calls rather than a stateful gate inside the real app: the
  /// second call replaces the first, and this way nothing about the running
  /// app's startup — provider overrides, router construction, the auth guard —
  /// has to know that a splash ever existed.
  static Widget app({
    required AppFlavor flavor,
    required String title,
    IconData icon = Icons.restaurant_menu_rounded,
  }) =>
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(flavor: flavor),
        darkTheme: AppTheme.dark(flavor: flavor),
        home: SplashScreen(flavor: flavor, title: title, icon: icon),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = AppGradients.ink(scheme);

    return Scaffold(
      // Full-bleed gradient, no header and no card: the launch image's one job
      // is to put the brand colour on screen before anything else can, so that
      // the app appears to start in its own skin rather than in the platform's.
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AppGradients.hero(scheme)),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppBrandMark(icon: icon, size: 96),
              const SizedBox(height: AppSpacing.xl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(color: ink),
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    // Indeterminate on purpose. The work behind this — a
                    // keystore read, a preferences open — has no progress to
                    // report, and a fake bar that fills at a fixed rate is a
                    // lie the user can time.
                    backgroundColor: ink.withValues(alpha: 0.24),
                    valueColor: AlwaysStoppedAnimation(ink),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
