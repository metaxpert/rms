import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_driver/src/features/runs/data/delivery_repository.dart';
import 'package:rms_driver/src/features/runs/presentation/run_screen.dart';
import 'package:rms_driver/src/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

/// The visual QA pass for the app that is read outdoors.
///
/// The driver app honours a *higher* text floor and ceiling than the till apps —
/// 1.0x to 1.5x — because a rider reads it at arm's length, in motion, often in
/// sunlight, and cannot stop to squint. That range is the one that has to hold,
/// on the small cheap phone a rider is most likely to be carrying.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const devices = <String, Size>{
    // The realistic worst case: an entry-level Android in a handlebar mount.
    'small phone': Size(360, 640),
    'large phone': Size(430, 932),
  };

  Future<void> pumpRun(
    WidgetTester tester,
    Delivery delivery, {
    required Size size,
    required Brightness brightness,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'branch_id': 'branch-1'});
    final session = await Session.load(secretStore: InMemorySecretStore());
    final deliveries = FakeDeliveries()..current = delivery;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(session),
          sharedPreferencesProvider
              .overrideWithValue(await SharedPreferences.getInstance()),
          deliveryRepositoryProvider.overrideWithValue(deliveries),
        ],
        child: MaterialApp(
          theme: brightness == Brightness.light
              ? AppTheme.light(flavor: AppFlavor.driver)
              : AppTheme.dark(flavor: AppFlavor.driver),
          localizationsDelegates: const [
            RmsLocalizations.delegate,
            AppText.delegate,
          ],
          supportedLocales: AppText.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: RunScreen(deliveryId: delivery.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('a run holds its shape', () {
    for (final status in ['ASSIGNED', 'PICKED_UP', 'EN_ROUTE', 'DELIVERED']) {
      for (final brightness in Brightness.values) {
        testWidgets('$status, ${brightness.name}', (tester) async {
          await pumpRun(
            tester,
            FakeDeliveries.delivery(status: status),
            size: devices['small phone']!,
            brightness: brightness,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('across the whole text range this app honours', (tester) async {
      for (final scale in [1.0, 1.25, 1.5]) {
        for (final device in devices.values) {
          await pumpRun(
            tester,
            // The longest state: an address that wraps, plus the sharing card
            // and its switch.
            FakeDeliveries.delivery(
              status: 'PICKED_UP',
              address: 'House 212-B, Street 41, Sector F-11/3, '
                  'near Jamia Masjid, Islamabad',
            ),
            size: device,
            brightness: Brightness.light,
            textScale: scale,
          );
          expect(tester.takeException(), isNull, reason: '$device at ${scale}x');
        }
      }
    });
  });

  group('the one action stays the biggest thing on screen', () {
    testWidgets('and is comfortably bigger than the minimum', (tester) async {
      // A rider presses this with a thumb, wearing a glove, holding a bag.
      await pumpRun(
        tester,
        FakeDeliveries.delivery(status: 'ASSIGNED'),
        size: devices['small phone']!,
        brightness: Brightness.light,
      );

      final action = find.widgetWithText(FilledButton, 'Picked up');
      expect(action, findsOneWidget);
      expect(tester.getSize(action).height, greaterThanOrEqualTo(64));
    });

    testWidgets('and survives the largest text without shrinking',
        (tester) async {
      await pumpRun(
        tester,
        FakeDeliveries.delivery(status: 'ASSIGNED'),
        size: devices['small phone']!,
        brightness: Brightness.light,
        textScale: 1.5,
      );

      expect(tester.takeException(), isNull);
      final action = find.widgetWithText(FilledButton, 'Picked up');
      expect(tester.getSize(action).height, greaterThanOrEqualTo(64));
    });
  });

  group('dark mode', () {
    testWidgets('the run status reads against a dark card', (tester) async {
      await pumpRun(
        tester,
        FakeDeliveries.delivery(status: 'DELIVERED'),
        size: devices['small phone']!,
        brightness: Brightness.dark,
      );

      // The badge label takes the resolved status colour; on a dark surface
      // that has to be lighter than the surface, not the near-black the light
      // palette defines.
      final label = tester.widget<Text>(find.text('Delivered'));
      final surface = AppTheme.dark(flavor: AppFlavor.driver).colorScheme.surface;
      expect(
        label.style!.color!.computeLuminance(),
        greaterThan(surface.computeLuminance()),
      );
    });
  });
}
