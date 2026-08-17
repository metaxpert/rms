import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rms_core/rms_core.dart';
import 'src/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The brand on screen before anything else, for the length of the work
  // below. That work is not optional and it is not instant — a keystore
  // read and a preferences open on a cold start on a mid-range till — and
  // what used to fill it was the framework's bare white window. The
  // `runApp` below replaces this one; nothing downstream knows it existed.
  runApp(SplashScreen.app(
    flavor: AppFlavor.driver,
    title: 'RMS Rider',
    icon: Icons.delivery_dining_rounded,
  ));

  // DateFormat throws on a locale whose symbols were never loaded, so this
  // must finish before the first timestamp is rendered.
  await LocaleBinding.ensureInitialised();

  // Session.load reads the platform keystore, so it must finish before the
  // first frame — otherwise the router would decide the rider is signed out and
  // bounce them to the login screen on every cold start.
  final session = await Session.load();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWithValue(session),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const DriverApp(),
    ),
  );
}
