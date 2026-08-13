import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';
import '../l10n/app_localizations.dart';
import 'router/app_router.dart';

class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'RMS',
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
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          // A guest's own phone, with their own accessibility settings. Unlike
          // the staff apps this is not a shared device, so the ceiling is
          // higher: the layouts here are lists, which reflow rather than break.
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 2.0,
            ),
          ),
          // Keeps DateFormat/NumberFormat on the same locale as the
          // strings; see LocaleBinding.
          child: LocaleBinding(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
