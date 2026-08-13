import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'live_sync.dart';
import 'router/app_router.dart';
import 'package:rms_core/rms_core.dart';
import '../l10n/app_localizations.dart';

class WaiterApp extends ConsumerWidget {
  const WaiterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'RMS Waiter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(flavor: AppFlavor.waiter),
      darkTheme: AppTheme.dark(flavor: AppFlavor.waiter),
      routerConfig: ref.watch(routerProvider),
      // English today, Urdu proven end to end — including right-to-left
      // layout, which is the part that breaks silently if nobody exercises it.
      // The remaining screens still read English literals; see the l10n note
      // in rms_core.
      localizationsDelegates: const [
        // The shared catalogue and this app's own, side by side — core keeps
        // the words all four apps say, this keeps the waiter's.
        RmsLocalizations.delegate,
        AppText.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppText.supportedLocales,
      // Held outside the router so a kitchen alert can reach the waiter on
      // whichever screen they are on, including one pushed over the floor.
      scaffoldMessengerKey: ref.watch(scaffoldMessengerKeyProvider),
      builder: (context, child) {
        // Respect the device's text-size setting for accessibility (brief §25),
        // but clamp the upper end: past ~1.3x the floor grid reflows so far that
        // table numbers start truncating, which is worse than slightly smaller
        // text on a shared tablet.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.3,
            ),
          ),
          // Above the router rather than inside a screen: the socket must
          // outlive any one route, and must be closed on sign-out wherever the
          // waiter was when the session ended.
          // Keeps DateFormat/NumberFormat on the same locale as the
          // strings; see LocaleBinding.
          child: LocaleBinding(child: LiveSync(child: child ?? const SizedBox.shrink())),
        );
      },
    );
  }
}
