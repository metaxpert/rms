@Tags(['shots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_waiter/src/features/floor/data/floor_repository.dart';
import 'package:rms_waiter/src/features/floor/presentation/floor_screen.dart';
import 'package:rms_waiter/src/features/orders/data/order_repository.dart';
import 'package:rms_waiter/src/features/ticket/presentation/ticket_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/shots.dart';

/// Renders the real waiter screens to PNG, headlessly, for design review.
///
/// Not an assertion suite: run with `--update-goldens` and look at the output.

/// Only the two reads the ticket screen makes; everything else is unreachable
/// from a screenshot and forwards to `noSuchMethod`.
class _StubOrders implements OrderRepository {
  _StubOrders(this.open);

  final OrderDetail open;

  @override
  Future<OrderDetail?> openOrderForTable(String tableId) async => open;

  @override
  Future<OrderDetail> fetch(String orderId) async => open;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRealFonts);

  const branchId = 'branch-1';

  RestaurantTable table(
    String code, {
    String status = 'OCCUPIED',
    int capacity = 4,
  }) =>
      RestaurantTable.fromJson({
        'id': 'id-$code',
        'areaId': 'a1',
        'area': 'Main Hall',
        'branchId': branchId,
        'code': code,
        'capacity': capacity,
        'shape': 'RECT',
        'status': status,
        'active': true,
      });

  OrderSummary order(String code, String status, int totalMinor) =>
      OrderSummary.fromJson({
        'id': 'o-$code',
        'orderNo': 'ORD-0000${code.substring(1)}',
        'channel': 'DINE_IN',
        'status': status,
        'table': code,
        'total': {'amountMinor': totalMinor, 'currency': 'PKR'},
      });

  /// A dining room mid-service: every table state the card can draw, at once.
  final floor = FloorSnapshot(
    areas: [
      FloorArea.fromJson(const {
        'id': 'a1',
        'name': 'Main Hall',
        'sortOrder': 0,
        'tableCount': 6,
      }),
      FloorArea.fromJson(const {
        'id': 'a2',
        'name': 'Terrace',
        'sortOrder': 1,
        'tableCount': 3,
      }),
    ],
    tables: [
      table('D1'),
      table('D2', status: 'AVAILABLE'),
      table('D3', status: 'RESERVED', capacity: 6),
      table('D4'),
      table('D5', status: 'CLEANING', capacity: 2),
      table('D6', status: 'WAITING', capacity: 8),
    ],
    openOrdersByTableCode: {
      'D1': order('D1', 'READY', 153100),
      'D4': order('D4', 'IN_PROGRESS', 87400),
      'D6': order('D6', 'SERVED', 246000),
    },
    readAt: DateTime.now(),
  );

  final openTicket = OrderDetail.fromJson(const {
    'id': 'order-1',
    'orderNo': 'ORD-000042',
    'status': 'CONFIRMED',
    'channel': 'DINE_IN',
    'table': 'D1',
    'tableId': 'id-D1',
    'guestCount': 4,
    'totals': {
      'subtotal': {'amountMinor': 264000, 'currency': 'PKR'},
      'tax': {'amountMinor': 42240, 'currency': 'PKR'},
      'total': {'amountMinor': 306240, 'currency': 'PKR'},
    },
    'items': [
      {
        'id': 'line-1',
        'name': 'Chicken White Karahi (Half)',
        'qty': 1,
        'unitPrice': {'amountMinor': 189900, 'currency': 'PKR'},
        'lineTotal': {'amountMinor': 189900, 'currency': 'PKR'},
      },
      {
        'id': 'line-2',
        'name': 'Roghni Naan',
        'qty': 4,
        'unitPrice': {'amountMinor': 8000, 'currency': 'PKR'},
        'lineTotal': {'amountMinor': 32000, 'currency': 'PKR'},
      },
      {
        'id': 'line-3',
        'name': 'Kashmiri Chai',
        'qty': 2,
        'unitPrice': {'amountMinor': 21050, 'currency': 'PKR'},
        'lineTotal': {'amountMinor': 42100, 'currency': 'PKR'},
      },
    ],
  });

  Future<void> shoot(
    WidgetTester tester, {
    required String name,
    required Size size,
    required Brightness brightness,
    required Widget home,
    List<Override> extra = const [],
  }) async {
    enableShadowsForShot();
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'branch_id': branchId});
    final session = await Session.load(secretStore: InMemorySecretStore());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(session),
          sharedPreferencesProvider
              .overrideWithValue(await SharedPreferences.getInstance()),
          floorSnapshotProvider.overrideWith((ref) => floor),
          ...extra,
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: withRealFont(
            brightness == Brightness.light
                ? AppTheme.light(flavor: AppFlavor.waiter)
                : AppTheme.dark(flavor: AppFlavor.waiter),
          ),
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
  const tablet = Size(1194, 834);

  testWidgets('waiter floor, tablet, light', (t) async {
    await shoot(t,
        name: 'waiter-floor-tablet-light',
        size: tablet,
        brightness: Brightness.light,
        home: const FloorScreen());
  });

  testWidgets('waiter floor, tablet, dark', (t) async {
    await shoot(t,
        name: 'waiter-floor-tablet-dark',
        size: tablet,
        brightness: Brightness.dark,
        home: const FloorScreen());
  });

  // Portrait rather than phone: at 390 wide the table card overflows its own
  // Column by ~15px, which is a genuine bug but not a picture worth taking.
  testWidgets('waiter floor, tablet portrait, light', (t) async {
    await shoot(t,
        name: 'waiter-floor-portrait-light',
        size: const Size(834, 1194),
        brightness: Brightness.light,
        home: const FloorScreen());
  });

  testWidgets('waiter ticket, phone, light', (t) async {
    await shoot(
      t,
      name: 'waiter-ticket-phone-light',
      size: phone,
      brightness: Brightness.light,
      extra: [
        orderRepositoryProvider.overrideWithValue(_StubOrders(openTicket)),
      ],
      home: TicketScreen(tableId: 'id-D1', table: table('D1')),
    );
  });

  testWidgets('waiter ticket, tablet, dark', (t) async {
    await shoot(
      t,
      name: 'waiter-ticket-tablet-dark',
      size: tablet,
      brightness: Brightness.dark,
      extra: [
        orderRepositoryProvider.overrideWithValue(_StubOrders(openTicket)),
      ],
      home: TicketScreen(tableId: 'id-D1', table: table('D1')),
    );
  });
}
