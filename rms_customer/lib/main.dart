import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rms_core/rms_core.dart';
import 'src/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
