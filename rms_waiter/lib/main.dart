import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app/app.dart';
import 'package:rms_core/rms_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Session.load reads the platform keystore, so it must complete before the
  // first frame — otherwise the router would briefly decide the user is signed
  // out and bounce a signed-in waiter to the login screen on every cold start.
  final session = await Session.load();

  // Saved ticket drafts are read synchronously while the floor screen builds,
  // so the store cannot be opened lazily. `getInstance` is cached — Session has
  // already paid for it.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWithValue(session),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const WaiterApp(),
    ),
  );
}
