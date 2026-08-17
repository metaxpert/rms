@Tags(['shots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_manager/src/features/service/data/service_repository.dart';
import 'package:rms_manager/src/features/service/presentation/manager_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/shots.dart';

/// Renders the real manager screens to PNG, headlessly, for design review.
///
/// Not an assertion suite: run with `--update-goldens` and look at the output.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRealFonts);

  OrderSummary order(String status, {int totalMinor = 1234567}) =>
      OrderSummary.fromJson({
        'id': 'o-$status-$totalMinor',
        'orderNo': 'ORD-000123',
        'channel': 'DINE_IN',
        'status': status,
        'itemCount': 4,
        'total': {'amountMinor': totalMinor, 'currency': 'PKR'},
      });

  // One clock for the whole fixture. The board reads a ticket's age against
  // the snapshot's own `takenAt`, so a fixture whose two halves disagree draws
  // every ticket as "just now" and hides the urgency colours entirely.
  final now = DateTime.now();

  KdsTicket ticket(int minutesAgo, String name) => KdsTicket.fromJson({
        'id': 'k-$minutesAgo',
        'orderNo': 'ORD-0001$minutesAgo',
        'station': 'tandoor',
        'status': 'PREPARING',
        'targetMinutes': 12,
        'firedAt':
            now.subtract(Duration(minutes: minutesAgo)).toIso8601String(),
        'items': [
          {'qty': 2, 'name': name, 'notes': 'extra spicy'},
        ],
      });

  final busy = ServiceSnapshot(
    orders: [
      order('READY'),
      order('READY', totalMinor: 9876543),
      order('IN_PROGRESS'),
      order('SERVED'),
      order('SETTLED', totalMinor: 45678900),
    ],
    board: KdsBoard.from([
      ticket(3, 'Chicken Karahi (Half)'),
      ticket(25, 'Mutton Handi (Full)'),
      ticket(40, 'Seekh Kebab Platter'),
    ]),
    tables: const [],
    deliveries: const [],
    takenAt: now,
  );

  Future<void> shoot(
    WidgetTester tester, {
    required String name,
    required Size size,
    required Brightness brightness,
    int tab = 0,
  }) async {
    enableShadowsForShot();
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final session = await Session.load(secretStore: InMemorySecretStore());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(session),
          sharedPreferencesProvider
              .overrideWithValue(await SharedPreferences.getInstance()),
          serviceSnapshotProvider.overrideWith((ref) async => busy),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: withRealFont(
            brightness == Brightness.light
                ? AppTheme.light(flavor: AppFlavor.manager)
                : AppTheme.dark(flavor: AppFlavor.manager),
          ),
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: const ManagerShell(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    if (tab > 0) {
      await tester.tap(find.byType(NavigationDestination).at(tab));
      await tester.pumpAndSettle();
    }

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/$name.png'),
    );
    restoreShadowsAfterShot();
  }

  const phone = Size(390, 844);
  const tablet = Size(1194, 834);

  testWidgets('manager dashboard, phone, light', (t) async {
    await shoot(t,
        name: 'manager-dashboard-phone-light',
        size: phone,
        brightness: Brightness.light);
  });

  testWidgets('manager dashboard, phone, dark', (t) async {
    await shoot(t,
        name: 'manager-dashboard-phone-dark',
        size: phone,
        brightness: Brightness.dark);
  });

  testWidgets('manager dashboard, tablet, light', (t) async {
    await shoot(t,
        name: 'manager-dashboard-tablet-light',
        size: tablet,
        brightness: Brightness.light);
  });

  testWidgets('manager kitchen, phone, dark', (t) async {
    await shoot(t,
        name: 'manager-kitchen-phone-dark',
        size: phone,
        brightness: Brightness.dark,
        tab: 1);
  });

  testWidgets('manager kitchen, tablet, light', (t) async {
    await shoot(t,
        name: 'manager-kitchen-tablet-light',
        size: tablet,
        brightness: Brightness.light,
        tab: 1);
  });

  testWidgets('manager sales, phone, light', (t) async {
    await shoot(t,
        name: 'manager-sales-phone-light',
        size: phone,
        brightness: Brightness.light,
        tab: 2);
  });
}
