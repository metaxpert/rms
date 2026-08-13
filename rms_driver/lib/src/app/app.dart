import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';
import '../l10n/app_localizations.dart';
import 'live_sync.dart';
import 'router/app_router.dart';

class DriverApp extends ConsumerWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'RMS Driver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: ref.watch(routerProvider),
      // English today, Urdu proven end to end — including right-to-left
      // layout, which is the part that breaks silently if nobody exercises it.
      // The remaining screens still read English literals; see the l10n note
      // in rms_core.
      localizationsDelegates: const [
        RmsLocalizations.delegate,
        AppText.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppText.supportedLocales,
      scaffoldMessengerKey: ref.watch(scaffoldMessengerKeyProvider),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            // A rider reads this outdoors, at arm's length, in motion. Larger
            // text is honoured further than on the till apps, and the floor is
            // raised rather than lowered.
            textScaler: media.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.5,
            ),
          ),
          child: LiveSync(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
