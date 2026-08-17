@Tags(['shots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_driver/src/features/runs/data/delivery_repository.dart';
import 'package:rms_driver/src/features/runs/data/driver_repository.dart';
import 'package:rms_driver/src/features/runs/presentation/run_list_screen.dart';
import 'package:rms_driver/src/features/runs/presentation/run_screen.dart';
import 'package:rms_driver/src/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';
import 'support/shots.dart';

/// Renders the real rider screens to PNG, headlessly, for design review.
///
/// Not an assertion suite: run with `--update-goldens` and look at the output.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRealFonts);

  DriverProfile profile({
    required DutyStatus duty,
    int liveRuns = 0,
    int deliveredToday = 6,
  }) =>
      DriverProfile(
        id: 'drv-1',
        displayName: 'Bilal Ahmed',
        dutyStatus: duty,
        liveRuns: liveRuns,
        maxConcurrentRuns: 3,
        deliveredToday: deliveredToday,
        driverCode: 'RID-014',
        vehicleType: 'BIKE',
      );

  // Built here rather than through the fake's factory, which pins one order
  // number — three identical ORD numbers on a board reads as a bug.
  Delivery run(String id, String no, String status, String address) =>
      Delivery.fromJson({
        'id': id,
        'deliveryNo': 'DLV-0000$id',
        'orderId': 'order-$id',
        'orderNo': no,
        'provider': 'OWN',
        'status': status,
        'address': address,
      });

  final board = [
    run('1', 'ORD-000118', 'EN_ROUTE',
        'House 212-B, Street 41, Sector F-11/3, Islamabad'),
    run('2', 'ORD-000121', 'PICKED_UP', '7 Margalla Road, F-7/2, Islamabad'),
    run('3', 'ORD-000124', 'ASSIGNED',
        'Flat 4, Silver Oaks Apartments, F-10 Markaz'),
  ];

  Future<void> shoot(
    WidgetTester tester, {
    required String name,
    required Size size,
    required Brightness brightness,
    required Widget home,
    required List<Override> extra,
  }) async {
    enableShadowsForShot();
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'branch_id': 'branch-1'});
    final session = await Session.load(secretStore: InMemorySecretStore());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(session),
          sharedPreferencesProvider
              .overrideWithValue(await SharedPreferences.getInstance()),
          ...extra,
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: withRealFont(
            brightness == Brightness.light
                ? AppTheme.light(flavor: AppFlavor.driver)
                : AppTheme.dark(flavor: AppFlavor.driver),
          ),
          localizationsDelegates: const [
            RmsLocalizations.delegate,
            AppText.delegate,
          ],
          supportedLocales: AppText.supportedLocales,
          home: MediaQuery(data: MediaQueryData(size: size), child: home),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/$name.png'),
    );
    restoreShadowsAfterShot();
  }

  const phone = Size(390, 844);

  List<Override> runsWith(DriverProfile p, List<Delivery> runs) => [
        deliveryRepositoryProvider
            .overrideWithValue(FakeDeliveries(board: runs)),
        driverProfileProvider.overrideWith((ref) async => p),
      ];

  testWidgets('driver run list on shift, light', (t) async {
    await shoot(t,
        name: 'driver-runs-onshift-light',
        size: phone,
        brightness: Brightness.light,
        home: const RunListScreen(),
        extra: runsWith(
          profile(duty: DutyStatus.onRun, liveRuns: 3),
          board,
        ));
  });

  testWidgets('driver run list on shift, dark', (t) async {
    await shoot(t,
        name: 'driver-runs-onshift-dark',
        size: phone,
        brightness: Brightness.dark,
        home: const RunListScreen(),
        extra: runsWith(
          profile(duty: DutyStatus.onRun, liveRuns: 3),
          board,
        ));
  });

  // The switch off duty, with nothing held — the empty board that used to be
  // the only thing this app ever showed.
  testWidgets('driver run list off shift, light', (t) async {
    await shoot(t,
        name: 'driver-runs-offduty-light',
        size: phone,
        brightness: Brightness.light,
        home: const RunListScreen(),
        extra: runsWith(profile(duty: DutyStatus.offDuty), const []));
  });

  for (final status in ['ASSIGNED', 'PICKED_UP', 'EN_ROUTE']) {
    testWidgets('driver run $status, light', (t) async {
      final delivery = FakeDeliveries.delivery(
        status: status,
        address: 'House 212-B, Street 41, Sector F-11/3, Islamabad',
      );
      await shoot(t,
          name: 'driver-run-${status.toLowerCase()}-light',
          size: phone,
          brightness: Brightness.light,
          home: RunScreen(deliveryId: delivery.id),
          extra: [
            deliveryRepositoryProvider
                .overrideWithValue(FakeDeliveries()..current = delivery),
            driverProfileProvider.overrideWith(
              (ref) async => profile(duty: DutyStatus.onRun, liveRuns: 1),
            ),
          ]);
    });
  }
}
