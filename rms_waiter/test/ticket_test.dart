import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_waiter/src/features/menu/data/menu_repository.dart';
import 'package:rms_waiter/src/features/orders/data/order_repository.dart';
import 'package:rms_waiter/src/features/ticket/data/draft_store.dart';
import 'package:rms_waiter/src/features/ticket/data/pending_send_store.dart';
import 'package:rms_waiter/src/features/ticket/presentation/ticket_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enough of the order API to drive the screen. The call-ordering and
/// resume rules are covered properly in `send_test.dart`; here it only has to
/// let the widgets get somewhere.
class _StubOrders implements OrderRepository {
  _StubOrders({this.existing, this.failSend});

  OrderDetail? existing;

  /// When set, every write fails with it — for the "did not reach the kitchen"
  /// path.
  final ApiException? failSend;

  static OrderDetail order({
    required String status,
    List<Map<String, dynamic>> items = const [],
  }) =>
      OrderDetail.fromJson({
        'id': 'order-1',
        'orderNo': 'ORD-000007',
        'status': status,
        'channel': 'DINE_IN',
        'table': 'D1',
        'guestCount': 4,
        'totals': const {
          'subtotal': {'amountMinor': 120000, 'currency': 'PKR'},
          'tax': {'amountMinor': 19200, 'currency': 'PKR'},
          'total': {'amountMinor': 139200, 'currency': 'PKR'},
        },
        'items': items,
      });

  @override
  Future<OrderDetail?> openOrderForTable(String tableId) async => existing;

  @override
  Future<OrderDetail> fetch(String orderId) async =>
      existing ?? order(status: 'DRAFT');

  @override
  Future<OrderDetail?> create({
    required String tableId,
    required int? guestCount,
    required String idempotencyKey,
  }) async {
    if (failSend != null) throw failSend!;
    return existing = order(status: 'DRAFT');
  }

  @override
  Future<OrderDetail?> addItems({
    required String orderId,
    required List<Map<String, dynamic>> items,
    required String idempotencyKey,
  }) async {
    if (failSend != null) throw failSend!;
    return existing = order(status: 'DRAFT', items: [
      {
        'id': 'line-1',
        'name': 'Garlic Naan',
        'qty': items.first['qty'],
        'unitPrice': const {'amountMinor': 12000, 'currency': 'PKR'},
        'lineTotal': const {'amountMinor': 13920, 'currency': 'PKR'},
      },
    ]);
  }

  @override
  Future<OrderDetail?> place({
    required String orderId,
    required String idempotencyKey,
  }) async {
    if (failSend != null) throw failSend!;
    return existing = order(status: 'CONFIRMED', items: [
      for (final line in existing?.lines ?? <OrderLine>[])
        {
          'id': line.id,
          'name': line.name,
          'qty': line.qty,
          'unitPrice': {'amountMinor': line.unitPrice.minor, 'currency': 'PKR'},
          'lineTotal': {'amountMinor': line.lineTotal.minor, 'currency': 'PKR'},
        },
    ]);
  }

  @override
  Future<OrderDetail?> confirm({
    required String orderId,
    required String idempotencyKey,
  }) async =>
      existing;

  @override
  Future<void> removeLine({
    required String orderId,
    required String lineId,
  }) async {}
}

/// The ordering path, driven through the real widgets: open a table, pick a
/// dish, see the ticket and the bill it predicts.
///
/// The menu is injected rather than fetched — the HTTP layer has its own tests,
/// and what matters here is that a tap becomes a line and a line becomes a
/// total the waiter can read out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const branchId = 'branch-1';

  const config = RestaurantConfig(
    currency: 'PKR',
    defaultTaxBp: 1600,
    serviceChargeBp: 0,
    roundingEnabled: true,
    tipEnabled: true,
    autoFireKitchen: true,
  );

  // Prices are the seed's.
  const catalogue = MenuCatalogue(
    categories: [
      MenuCategory(
        id: 'cat-curries',
        name: 'Curries',
        sortOrder: 0,
        active: true,
        itemCount: 1,
      ),
      MenuCategory(
        id: 'cat-breads',
        name: 'Breads',
        sortOrder: 1,
        active: true,
        itemCount: 1,
      ),
    ],
    items: [
      MenuItem(
        id: 'item-karahi',
        name: 'Chicken Karahi',
        price: Money(132000),
        available: true,
        status: 'ACTIVE',
        isCombo: false,
        prepMinutes: 15,
        categoryId: 'cat-curries',
        categoryName: 'Curries',
        taxBp: 1600,
      ),
      MenuItem(
        id: 'item-naan',
        name: 'Garlic Naan',
        price: Money(12000),
        available: true,
        status: 'ACTIVE',
        isCombo: false,
        prepMinutes: 4,
        categoryId: 'cat-breads',
        categoryName: 'Breads',
        taxBp: 1600,
      ),
      MenuItem(
        id: 'item-soldout',
        name: 'Beef Nihari',
        price: Money(115000),
        available: false,
        status: 'ACTIVE',
        isCombo: false,
        prepMinutes: 12,
        categoryId: 'cat-curries',
        categoryName: 'Curries',
        taxBp: 1600,
      ),
    ],
    config: config,
  );

  const table = RestaurantTable(
    id: 'table-1',
    areaId: 'area-1',
    areaName: 'Main hall',
    branchId: branchId,
    code: 'D1',
    capacity: 4,
    shape: 'RECT',
    status: TableStatus.occupied,
    active: true,
  );

  Future<Session> session({Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues({'branch_id': branchId, ...prefs});
    return Session.load(secretStore: InMemorySecretStore());
  }

  /// The dish in the picker grid, not the identically-named line already on the
  /// ticket behind the sheet.
  Finder menuTile(String name) => find.descendant(
        of: find.byType(GridView),
        matching: find.text(name),
      );

  Future<void> pumpTicket(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    bool tenantHasModifiers = false,
    _StubOrders? orders,
  }) async {
    final loaded = await session(prefs: prefs);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(loaded),
          sharedPreferencesProvider
              .overrideWithValue(await SharedPreferences.getInstance()),
          menuCatalogueProvider.overrideWith((ref) => catalogue),
          tenantHasModifiersProvider.overrideWith((ref) => tenantHasModifiers),
          // Without this the screen would reach for a real server on every
          // table open.
          orderRepositoryProvider.overrideWithValue(orders ?? _StubOrders()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const TicketScreen(tableId: 'table-1', table: table),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an untouched table opens an empty ticket', (tester) async {
    await pumpTicket(tester);

    expect(find.text('Table D1'), findsOneWidget);
    expect(find.text('Nothing ordered yet'), findsOneWidget);
    // Nothing to send, and nothing to clear.
    expect(find.byTooltip('Clear this round'), findsNothing);
  });

  testWidgets('picking a dish puts it on the ticket with the right bill',
      (tester) async {
    await pumpTicket(tester);

    await tester.tap(find.text('Open the menu'));
    await tester.pumpAndSettle();
    await tester.tap(menuTile('Chicken Karahi'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Chicken Karahi'), findsOneWidget);
    // 1320.00 + 16% = 1531.20, rounded to the rupee = 1531.00.
    expect(find.text('Rs 1,320.00'), findsWidgets);
    expect(find.text('Rs 211.20'), findsOneWidget);
    expect(find.text('Rs 1,531.00'), findsOneWidget);
  });

  testWidgets('tapping the same dish twice makes one line of two',
      (tester) async {
    await pumpTicket(tester);

    await tester.tap(find.text('Open the menu'));
    await tester.pumpAndSettle();
    await tester.tap(menuTile('Garlic Naan'));
    await tester.pumpAndSettle();
    await tester.tap(menuTile('Garlic Naan'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Garlic Naan'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Rs 240.00'), findsWidgets);
  });

  testWidgets('a sold-out dish is not offered', (tester) async {
    await pumpTicket(tester);

    await tester.tap(find.text('Open the menu'));
    await tester.pumpAndSettle();

    expect(find.text('Beef Nihari'), findsNothing,
        reason: 'the server rejects an unavailable item with 422');
  });

  testWidgets('search finds a dish outside the selected category',
      (tester) async {
    await pumpTicket(tester);

    await tester.tap(find.text('Open the menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Curries'));
    await tester.pumpAndSettle();
    expect(find.text('Garlic Naan'), findsNothing);

    await tester.enterText(find.byType(TextField), 'naan');
    await tester.pumpAndSettle();

    expect(find.text('Garlic Naan'), findsOneWidget,
        reason: 'a waiter typing a dish name wants the dish, not a category '
            'lecture');
  });

  testWidgets('reducing a line to zero removes it', (tester) async {
    await pumpTicket(tester);

    await tester.tap(find.text('Open the menu'));
    await tester.pumpAndSettle();
    await tester.tap(menuTile('Garlic Naan'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Garlic Naan'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing ordered yet'), findsOneWidget);
  });

  testWidgets('an order taken earlier is still there, and says so',
      (tester) async {
    final saved = TicketDraft(
      branchId: branchId,
      tableId: 'table-1',
      tableCode: 'D1',
      updatedAt: DateTime.now().subtract(const Duration(minutes: 20)),
      lines: const [
        DraftLine(
          itemId: 'item-karahi',
          name: 'Chicken Karahi',
          unitPrice: Money(132000),
          taxBp: 1600,
          qty: 2,
        ),
      ],
    );

    await pumpTicket(tester, prefs: {
      DraftStore.keyFor(branchId, 'table-1'): jsonEncode(saved.toJson()),
    });

    expect(find.text('Chicken Karahi'), findsOneWidget);
    expect(find.textContaining('Unsent round from'), findsOneWidget,
        reason: 'the kitchen has no idea this order exists');
  });

  testWidgets('a draft is written to disk as soon as a dish is added',
      (tester) async {
    await pumpTicket(tester);

    await tester.tap(find.text('Open the menu'));
    await tester.pumpAndSettle();
    await tester.tap(menuTile('Chicken Karahi'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Done'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(DraftStore.keyFor(branchId, 'table-1'));

    expect(raw, isNotNull,
        reason: 'the tablet dying between the order and the kitchen must not '
            'lose the order');
    final restored =
        TicketDraft.fromJson(jsonDecode(raw!) as Map<String, dynamic>);
    expect(restored!.lines.single.name, 'Chicken Karahi');
  });

  testWidgets('clearing a ticket asks first', (tester) async {
    await pumpTicket(tester);

    await tester.tap(find.text('Open the menu'));
    await tester.pumpAndSettle();
    await tester.tap(menuTile('Garlic Naan'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Clear this round'));
    await tester.pumpAndSettle();
    expect(find.text('Clear this round?'), findsOneWidget);

    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(find.text('Garlic Naan'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear this round'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing ordered yet'), findsOneWidget);
  });

  group('a dish that takes options', () {
    // No modifier groups exist in the demo seed, so this shape comes from
    // menu.service.ts. The rules are the ones the app must enforce, because
    // `POST /orders/:id/items` does NOT check min/max — it only rejects a
    // modifier that does not exist or is unavailable.
    const spice = ModifierGroup(
      id: 'g-spice',
      name: 'Spice level',
      minSelect: 1,
      maxSelect: 1,
      required: true,
      sortOrder: 0,
      modifiers: [
        Modifier(
          id: 'm-mild',
          name: 'Mild',
          priceDelta: Money(0),
          available: true,
          sortOrder: 0,
        ),
        Modifier(
          id: 'm-hot',
          name: 'Extra hot',
          priceDelta: Money(0),
          available: true,
          sortOrder: 1,
        ),
      ],
    );
    const extras = ModifierGroup(
      id: 'g-extras',
      name: 'Add-ons',
      minSelect: 0,
      maxSelect: 1,
      required: false,
      sortOrder: 1,
      modifiers: [
        Modifier(
          id: 'm-raita',
          name: 'Raita',
          priceDelta: Money(3000),
          available: true,
          sortOrder: 0,
        ),
        Modifier(
          id: 'm-gone',
          name: 'Salad',
          priceDelta: Money(2000),
          available: false,
          sortOrder: 1,
        ),
      ],
    );

    Future<void> pumpWithOptions(WidgetTester tester) async {
      final loaded = await session();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWithValue(loaded),
            sharedPreferencesProvider
                .overrideWithValue(await SharedPreferences.getInstance()),
            menuCatalogueProvider.overrideWith((ref) => catalogue),
            tenantHasModifiersProvider.overrideWith((ref) => true),
            itemModifierGroupsProvider('item-karahi')
                .overrideWith((ref) => const [spice, extras]),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const TicketScreen(tableId: 'table-1', table: table),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open the menu'));
      await tester.pumpAndSettle();
      await tester.tap(menuTile('Chicken Karahi'));
      await tester.pumpAndSettle();
    }

    testWidgets('cannot be added until a required choice is made',
        (tester) async {
      await pumpWithOptions(tester);

      expect(find.text('Choose spice level first'), findsOneWidget);
      final add = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Add 1 · Rs 1,320.00'),
      );
      expect(add.onPressed, isNull);

      await tester.tap(find.text('Mild'));
      await tester.pumpAndSettle();

      expect(find.text('Choose spice level first'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Add 1 · Rs 1,320.00'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('an unavailable option is not shown', (tester) async {
      await pumpWithOptions(tester);

      expect(find.text('Raita  +Rs 30.00'), findsOneWidget);
      expect(find.textContaining('Salad'), findsNothing);
    });

    testWidgets('a paid option is priced per unit and shown on the line',
        (tester) async {
      await pumpWithOptions(tester);

      await tester.tap(find.text('Mild'));
      await tester.tap(find.text('Raita  +Rs 30.00'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('One more'));
      await tester.pumpAndSettle();

      // (1320 + 30) × 2.
      await tester.tap(find.widgetWithText(FilledButton, 'Add 2 · Rs 2,700.00'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Mild · Raita +Rs 30.00'), findsOneWidget);
      expect(find.text('Rs 2,700.00'), findsWidgets);
    });

    testWidgets('a single-choice group swaps rather than stacking',
        (tester) async {
      await pumpWithOptions(tester);

      await tester.tap(find.text('Mild'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Extra hot'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add 1 · Rs 1,320.00'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Extra hot'), findsOneWidget);
      expect(find.textContaining('Mild'), findsNothing,
          reason: 'a dish cannot be both mild and extra hot');
    });
  });

  /// Put one Garlic Naan on the unsent round.
  Future<void> addNaan(WidgetTester tester) async {
    // The empty ticket offers the menu in its centre; once there is anything on
    // screen, the action bar is the way in.
    final entry = find.text('Open the menu');
    await tester.tap(entry.evaluate().isEmpty ? find.text('Add items') : entry);
    await tester.pumpAndSettle();
    await tester.tap(menuTile('Garlic Naan'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Done'));
    await tester.pumpAndSettle();
  }

  group('sending the round', () {
    testWidgets('the round moves onto the bill and the waiter is told',
        (tester) async {
      await pumpTicket(tester);
      await addNaan(tester);

      expect(find.text('NOT SENT YET'), findsOneWidget);

      await tester.tap(find.textContaining('Send · 1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sent to the kitchen'), findsOneWidget);
      expect(find.text('SENT · ORD-000007'), findsOneWidget);
      // The round is gone from the unsent section — keeping it would offer to
      // send the same food twice.
      expect(find.text('NOT SENT YET'), findsNothing);
    });

    testWidgets('a refused send keeps the round and offers to resume',
        (tester) async {
      await pumpTicket(
        tester,
        orders: _StubOrders(
          failSend: ApiException(ApiErrorKind.server, 'Kitchen service down.'),
        ),
      );
      await addNaan(tester);

      await tester.tap(find.textContaining('Send · 1'));
      await tester.pumpAndSettle();

      expect(find.text('This round did not reach the kitchen'), findsOneWidget);
      expect(find.text('Kitchen service down.'), findsOneWidget);
      expect(find.textContaining('Resume'), findsOneWidget);
      // The food the waiter typed is still on the tablet.
      expect(find.text('Garlic Naan'), findsWidgets);
    });

    testWidgets('a round waiting to be resumed cannot be edited',
        (tester) async {
      await pumpTicket(
        tester,
        orders: _StubOrders(
          failSend: ApiException(ApiErrorKind.server, 'Kitchen service down.'),
        ),
      );
      await addNaan(tester);
      await tester.tap(find.textContaining('Send · 1'));
      await tester.pumpAndSettle();

      // The submission carries the payload frozen at the tap, and its
      // idempotency key is only valid for that body. Adding a dish now would
      // either invalidate the key or be dropped by the resume.
      final add = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Add items'),
      );
      expect(add.onPressed, isNull);
      final more = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add_rounded),
      );
      expect(more.onPressed, isNull);
      expect(find.byTooltip('Clear this round'), findsNothing);
    });

    testWidgets('a send interrupted by a restart is offered again',
        (tester) async {
      final interrupted = PendingSend(
        branchId: branchId,
        tableId: 'table-1',
        key: 'abc',
        stage: SendStage.placing,
        items: const [
          {'itemId': 'item-naan', 'qty': 1},
        ],
        startedAt: DateTime.now(),
        orderId: 'order-1',
      );

      await pumpTicket(tester, prefs: {
        PendingSendStore.keyFor(branchId, 'table-1'):
            jsonEncode(interrupted.toJson()),
      });

      expect(
        find.text('This round was not finished sending'),
        findsOneWidget,
      );
      // A bill exists; saying "nothing was sent" would be a lie the kitchen
      // could contradict.
      expect(find.textContaining('A bill is already open'), findsOneWidget);
    });

    testWidgets('an open bill is shown above the round being added',
        (tester) async {
      await pumpTicket(
        tester,
        orders: _StubOrders(
          existing: _StubOrders.order(status: 'PREPARING', items: const [
            {
              'id': 'line-1',
              'name': 'Chicken Karahi',
              'qty': 1,
              'unitPrice': {'amountMinor': 132000, 'currency': 'PKR'},
              'lineTotal': {'amountMinor': 153120, 'currency': 'PKR'},
            },
          ]),
        ),
      );

      expect(find.text('SENT · ORD-000007'), findsOneWidget);
      expect(find.text('Cooking'), findsOneWidget);
      expect(find.text('Bill so far'), findsOneWidget);

      await addNaan(tester);

      // Both are on screen, and it is unambiguous which the kitchen has.
      expect(find.text('THIS ROUND — NOT SENT'), findsOneWidget);
      expect(find.text('Chicken Karahi'), findsOneWidget);
      expect(find.text('Garlic Naan'), findsOneWidget);
    });

    testWidgets('a settled bill takes nothing more, and says why',
        (tester) async {
      await pumpTicket(
        tester,
        orders: _StubOrders(existing: _StubOrders.order(status: 'SETTLED')),
      );

      expect(
        find.textContaining('This bill is settled'),
        findsOneWidget,
        reason: 'the server would refuse it — better to say so than to produce '
            'a 422 a waiter has to interpret',
      );
      final send = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Send · 0'),
      );
      expect(send.onPressed, isNull);
    });
  });
}
