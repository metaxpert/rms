import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_driver/src/app/app.dart';
import 'package:rms_driver/src/features/runs/data/delivery_repository.dart';
import 'package:rms_driver/src/features/runs/presentation/run_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

/// Boots the real app, so the auth guard and routing are exercised rather than
/// a stubbed screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Session> session({Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    return Session.load(secretStore: InMemorySecretStore());
  }

  Future<void> pumpApp(WidgetTester tester, Session loaded) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(loaded),
          sharedPreferencesProvider
              .overrideWithValue(await SharedPreferences.getInstance()),
        ],
        child: const DriverApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('signed out lands on the driver sign-in', (tester) async {
    await pumpApp(tester, await session());

    // The shared screen, named for this app: staff share a device pile and
    // need to know which one they picked up.
    expect(find.text('Driver sign in'), findsOneWidget);
  });

  testWidgets('authenticated without a kitchen is held at outlet selection',
      (tester) async {
    final loaded = await session();
    await loaded.saveTokens(
        accessToken: 'header.payload.sig', expiresIn: '15m');

    await pumpApp(tester, loaded);

    // Without one, every branch-scoped read would show another kitchen's runs.
    expect(find.text('Which kitchen?'), findsOneWidget);
  });

  group('the run screen', () {
    Future<void> pumpRun(WidgetTester tester, Delivery delivery) async {
      final loaded = await session(prefs: {'branch_id': 'branch-1'});
      final deliveries = FakeDeliveries()..current = delivery;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWithValue(loaded),
            sharedPreferencesProvider
                .overrideWithValue(await SharedPreferences.getInstance()),
            deliveryRepositoryProvider.overrideWithValue(deliveries),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: RunScreen(deliveryId: delivery.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers exactly one forward action', (tester) async {
      await pumpRun(tester, FakeDeliveries.delivery(status: 'ASSIGNED'));

      // A menu of choices at a doorstep is a menu misread.
      expect(find.text('Picked up'), findsOneWidget);
      expect(find.text('Start delivery'), findsNothing);
      expect(find.text('Deliver with OTP'), findsNothing);
    });

    testWidgets('the action follows the status', (tester) async {
      await pumpRun(tester, FakeDeliveries.delivery(status: 'PICKED_UP'));
      expect(find.text('Start delivery'), findsOneWidget);
    });

    testWidgets('delivering asks for the customer\'s code', (tester) async {
      await pumpRun(tester, FakeDeliveries.delivery(status: 'EN_ROUTE'));

      await tester.tap(find.text('Deliver with OTP'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm the handover'), findsOneWidget);
      // The code is the customer's and is never shown here — a rider who could
      // read it could close a job without arriving.
      expect(find.text('Delivery code'), findsOneWidget);
    });

    testWidgets('an aggregator\'s job offers no buttons', (tester) async {
      await pumpRun(
        tester,
        FakeDeliveries.delivery(status: 'EN_ROUTE', provider: 'FOODPANDA'),
      );

      expect(find.text('Deliver with OTP'), findsNothing);
      expect(find.textContaining('is carrying this one'), findsOneWidget);
    });

    testWidgets('a finished run says so instead of offering an action',
        (tester) async {
      await pumpRun(tester, FakeDeliveries.delivery(status: 'DELIVERED'));

      expect(find.textContaining('This run is delivered'), findsOneWidget);
      expect(find.byType(Switch), findsNothing,
          reason: 'location sharing ends with the run');
    });

    testWidgets('an unassigned run explains the wait', (tester) async {
      await pumpRun(tester, FakeDeliveries.delivery(status: 'PENDING'));

      expect(
        find.textContaining('Waiting for the restaurant'),
        findsOneWidget,
      );
    });
  });
}
