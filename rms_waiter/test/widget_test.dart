import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_waiter/src/app/app.dart';
import 'package:rms_core/rms_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Boots the real app with an in-memory session, so routing and the auth guard
/// are exercised rather than a stubbed screen.
Future<Session> _session({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  return Session.load(secretStore: InMemorySecretStore());
}

Future<void> _pumpApp(WidgetTester tester, Session session) async {
  await tester.pumpWidget(
    ProviderScope(
      // Both overrides that `main()` installs, so the harness cannot pass on a
      // dependency the real app would be missing.
      overrides: [
        sessionProvider.overrideWithValue(session),
        sharedPreferencesProvider
            .overrideWithValue(await SharedPreferences.getInstance()),
      ],
      child: const WaiterApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signed out lands on sign in', (tester) async {
    await _pumpApp(tester, await _session());

    expect(find.text('Waiter sign in'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('sign-in form validates before calling the server',
      (tester) async {
    await _pumpApp(tester, await _session());

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // Empty fields must be caught locally — a round trip to fail on a blank
    // password wastes a waiter's time on a weak connection.
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('remembered email is pre-filled', (tester) async {
    await _pumpApp(
      tester,
      await _session(prefs: {'last_email': 'waiter@example.com'}),
    );

    expect(find.text('waiter@example.com'), findsOneWidget);
  });

  testWidgets('server settings sheet opens and shows the current address',
      (tester) async {
    final session =
        await _session(prefs: {'api_base': 'https://demo.test/api'});
    await _pumpApp(tester, session);

    await tester.tap(find.text('Server settings'));
    await tester.pumpAndSettle();

    expect(find.text('Server settings'), findsWidgets);
    expect(find.text('https://demo.test/api'), findsOneWidget);
  });

  testWidgets('password visibility can be toggled', (tester) async {
    await _pumpApp(tester, await _session());

    expect(find.byTooltip('Show password'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('authenticated without an outlet is held at outlet selection',
      (tester) async {
    // A token with no branch chosen: the guard must not let this through to the
    // floor, or branch-scoped reads would return another outlet's tables.
    final session = await _session();
    await session.saveTokens(
        accessToken: 'header.payload.sig', expiresIn: '15m');

    await _pumpApp(tester, session);

    expect(find.text('Choose your outlet'), findsOneWidget);
    expect(find.text('Waiter sign in'), findsNothing);
  });
}
