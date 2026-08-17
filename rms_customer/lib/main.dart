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
    flavor: AppFlavor.customer,
    title: 'RMS Guest',
    icon: Icons.restaurant_rounded,
  ));

  // DateFormat throws on a locale whose symbols were never loaded, so this
  // must finish before the first timestamp is rendered.
  await LocaleBinding.ensureInitialised();

  final session = await Session.load();
  // The basket is read synchronously while the menu builds, so preferences
  // cannot be opened lazily.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWithValue(session),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const CustomerApp(),
    ),
  );
}
