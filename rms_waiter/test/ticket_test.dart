import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_waiter/src/features/menu/data/menu_repository.dart';
import 'package:rms_waiter/src/features/ticket/data/draft_store.dart';
import 'package:rms_waiter/src/features/ticket/presentation/ticket_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    expect(find.byTooltip('Clear ticket'), findsNothing);
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
    expect(find.textContaining('Unsent ticket from'), findsOneWidget,
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

    await tester.tap(find.byTooltip('Clear ticket'));
    await tester.pumpAndSettle();
    expect(find.text('Clear this ticket?'), findsOneWidget);

    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(find.text('Garlic Naan'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear ticket'));
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

  testWidgets('sending is not pretended to work yet', (tester) async {
    await pumpTicket(tester);

    await tester.tap(find.text('Open the menu'));
    await tester.pumpAndSettle();
    await tester.tap(menuTile('Garlic Naan'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Send · 1'));
    await tester.pump();

    expect(find.textContaining('next phase'), findsOneWidget,
        reason: 'a button that looks like it fired the kitchen and did not is '
            'the worst possible lie this app could tell');
  });
}
