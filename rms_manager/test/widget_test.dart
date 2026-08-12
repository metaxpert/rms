import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_manager/src/app/app.dart';
import 'package:rms_manager/src/features/service/data/service_repository.dart';
import 'package:rms_manager/src/features/service/presentation/manager_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Session> session({Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    return Session.load(secretStore: InMemorySecretStore());
  }

  ServiceSnapshot snapshotWith({
    List<OrderSummary> orders = const [],
    List<KdsTicket> tickets = const [],
  }) =>
      ServiceSnapshot(
        orders: orders,
        board: KdsBoard.from(tickets),
        tables: const [],
        deliveries: const [],
        takenAt: DateTime(2026, 8, 13, 20, 30),
      );

  OrderSummary order(String status, {int totalMinor = 100000}) =>
      OrderSummary.fromJson({
        'id': 'o-$status-$totalMinor',
        'orderNo': 'ORD-0001',
        'channel': 'DINE_IN',
        'status': status,
        'itemCount': 2,
        'total': {'amountMinor': totalMinor, 'currency': 'PKR'},
      });

  Future<void> pumpShell(WidgetTester tester, ServiceSnapshot snapshot) async {
    final loaded = await session();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(loaded),
          sharedPreferencesProvider
              .overrideWithValue(await SharedPreferences.getInstance()),
          serviceSnapshotProvider.overrideWith((ref) async => snapshot),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ManagerShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('booting', () {
    testWidgets('signed out lands on the manager sign-in', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWithValue(await session()),
            sharedPreferencesProvider
                .overrideWithValue(await SharedPreferences.getInstance()),
            authRequiresBranchProvider.overrideWithValue(false),
          ],
          child: const ManagerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Manager sign in'), findsOneWidget);
    });

    testWidgets('signed in without an outlet goes straight to the dashboard',
        (tester) async {
      // Unlike the waiter and driver apps: comparing outlets is the job, so no
      // outlet means every outlet rather than a locked door.
      final loaded = await session();
      await loaded.saveTokens(
          accessToken: 'header.payload.sig', expiresIn: '15m');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWithValue(loaded),
            sharedPreferencesProvider
                .overrideWithValue(await SharedPreferences.getInstance()),
            authRequiresBranchProvider.overrideWithValue(false),
            serviceSnapshotProvider.overrideWith((ref) async => snapshotWith()),
          ],
          child: const ManagerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Manager sign in'), findsNothing);
      expect(find.text('All outlets'), findsOneWidget);
    });
  });

  group('the dashboard', () {
    testWidgets('leads with what someone should get up for', (tester) async {
      await pumpShell(
        tester,
        snapshotWith(orders: [order('READY'), order('READY')]),
      );

      expect(find.textContaining('2 orders are ready to run'), findsOneWidget);
    });

    testWidgets('says nothing is waiting when nothing is', (tester) async {
      await pumpShell(tester, snapshotWith(orders: [order('PREPARING')]));

      // A permanent banner stops being read within a shift.
      expect(find.textContaining('ready to run'), findsNothing);
      expect(find.text('nothing waiting'), findsOneWidget);
    });

    testWidgets('shows open money and settled money apart', (tester) async {
      await pumpShell(
        tester,
        snapshotWith(orders: [
          order('SETTLED', totalMinor: 200000),
          order('CONFIRMED', totalMinor: 50000),
        ]),
      );

      expect(find.text('Rs 500.00'), findsOneWidget); // open
      expect(find.text('Rs 2,000.00'), findsOneWidget); // settled
    });

    testWidgets('says when the figures were read', (tester) async {
      await pumpShell(tester, snapshotWith());
      await tester.scrollUntilVisible(
        find.textContaining('Read at'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // A dashboard that might be minutes stale and does not say so is worse
      // than no dashboard.
      expect(find.textContaining('Read at'), findsOneWidget);
    });
  });

  group('the kitchen tab', () {
    KdsTicket ticket({
      String station = 'grill',
      int elapsedSeconds = 60,
      int? targetMinutes,
      String id = 't1',
    }) =>
        KdsTicket.fromJson({
          'id': id,
          'orderNo': 'ORD-0007',
          'stationKey': station,
          'status': 'IN_PROGRESS',
          'table': 'D1',
          'elapsedSeconds': elapsedSeconds,
          'targetMinutes': targetMinutes,
          'items': const [
            {'qty': 2, 'name': 'Chicken Karahi', 'kitchenNotes': 'no chilli'},
          ],
        });

    Future<void> openKitchen(WidgetTester tester) async {
      await tester.tap(find.text('Kitchen'));
      await tester.pumpAndSettle();
    }

    testWidgets('groups tickets under their station', (tester) async {
      await pumpShell(
        tester,
        snapshotWith(tickets: [
          ticket(station: 'grill', id: 'a'),
          ticket(station: 'tandoor', id: 'b'),
        ]),
      );
      await openKitchen(tester);

      expect(find.text('GRILL'), findsOneWidget);
      expect(find.text('TANDOOR'), findsOneWidget);
    });

    testWidgets('shows the kitchen note the waiter typed', (tester) async {
      await pumpShell(tester, snapshotWith(tickets: [ticket()]));
      await openKitchen(tester);

      expect(find.text('no chilli'), findsOneWidget);
    });

    testWidgets('calls out a station running past target', (tester) async {
      await pumpShell(
        tester,
        snapshotWith(tickets: [
          ticket(elapsedSeconds: 900, targetMinutes: 10),
        ]),
      );
      await openKitchen(tester);

      expect(find.text('1 past target'), findsOneWidget);
    });

    testWidgets('an empty kitchen says so', (tester) async {
      await pumpShell(tester, snapshotWith());
      await openKitchen(tester);

      expect(find.text('The kitchen is clear'), findsOneWidget);
    });

    testWidgets('offers no way to move a ticket', (tester) async {
      // Chefs bump tickets from the KDS screen. A manager doing it from a phone
      // would tell the pass food was away when nobody had plated it.
      await pumpShell(tester, snapshotWith(tickets: [ticket()]));
      await openKitchen(tester);

      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });
  });

  group('the sales tab', () {
    testWidgets('reports settled bills, not "revenue"', (tester) async {
      await pumpShell(
        tester,
        snapshotWith(orders: [order('SETTLED', totalMinor: 120000)]),
      );
      await tester.tap(find.text('Sales'));
      await tester.pumpAndSettle();

      // Revenue is the ledger's word; recognition, tax and rounding happen
      // there, not on a phone.
      expect(find.text('Settled'), findsWidgets);
      expect(find.textContaining('Revenue'), findsNothing);
      expect(find.text('Average bill'), findsOneWidget);
    });
  });
}
