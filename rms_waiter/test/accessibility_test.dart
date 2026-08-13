import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_core/src/l10n/rms_localizations_en.dart';
import 'package:rms_waiter/src/features/floor/data/floor_repository.dart';
import 'package:rms_waiter/src/features/floor/presentation/floor_screen.dart';
import 'package:rms_waiter/src/features/floor/presentation/table_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Held against Flutter's own accessibility guidelines rather than a checklist
/// somebody wrote down once.
///
/// The context matters: this is used one-handed, at speed, by staff who may be
/// carrying plates, on shared tablets whose text size somebody else set.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const branchId = 'branch-1';

  RestaurantTable table(
    String code, {
    Map<String, dynamic>? position,
    String status = 'OCCUPIED',
  }) =>
      RestaurantTable.fromJson({
        'id': 'id-$code',
        'areaId': 'a1',
        'area': 'DHA Hall',
        'branchId': branchId,
        'code': code,
        'capacity': 4,
        'shape': 'RECT',
        'status': status,
        'active': true,
        'position': position,
      });

  OrderSummary order(String code, String status) => OrderSummary.fromJson({
        'id': 'o-$code',
        'orderNo': 'ORD-000004',
        'channel': 'DINE_IN',
        'status': status,
        'table': code,
        'total': const {'amountMinor': 153100, 'currency': 'PKR'},
      });

  Future<void> pumpFloor(
    WidgetTester tester,
    FloorSnapshot floor, {
    double textScale = 1.0,
  }) async {
    SharedPreferences.setMockInitialValues({'branch_id': branchId});
    final session = await Session.load(secretStore: InMemorySecretStore());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(session),
          sharedPreferencesProvider
              .overrideWithValue(await SharedPreferences.getInstance()),
          floorSnapshotProvider.overrideWith((ref) => floor),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: const FloorScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the floor meets the platform guidelines', () {
    testWidgets('tap targets, labels and contrast', (tester) async {
      final handle = tester.ensureSemantics();

      await pumpFloor(
        tester,
        FloorSnapshot(
          areas: [
            FloorArea.fromJson(const {
              'id': 'a1',
              'name': 'DHA Hall',
              'sortOrder': 0,
              'tableCount': 3,
            }),
          ],
          tables: [table('D1'), table('D2'), table('D3')],
          openOrdersByTableCode: {'D1': order('D1', 'READY')},
          readAt: DateTime(2026, 8, 13, 20, 30),
        ),
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      handle.dispose();
    });

    testWidgets('survives the largest text this app honours', (tester) async {
      // Shared tablets come with somebody else's text size already set.
      final handle = tester.ensureSemantics();

      await pumpFloor(
        tester,
        FloorSnapshot(
          areas: [
            FloorArea.fromJson(const {
              'id': 'a1',
              'name': 'DHA Hall',
              'sortOrder': 0,
              'tableCount': 2,
            }),
          ],
          tables: [table('D1'), table('D2')],
          openOrdersByTableCode: const {},
        ),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  group('a table reads correctly to a screen reader', () {
    testWidgets('says everything the card shows, in one utterance',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TableCard(
              table: table('D1'),
              order: order('D1', 'READY'),
              hasDraft: true,
              onTap: () {},
            ),
          ),
        ),
      );

      // Three separate labels would be read as three disconnected fragments;
      // a waiter using TalkBack needs the whole story at once.
      expect(
        tester.getSemantics(find.byType(TableCard)),
        matchesSemantics(
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
          label: 'Table D1, Seated, seats 4, order Ready Rs 1,531.00, '
              'food ready, unsent ticket',
        ),
      );
      handle.dispose();
    });

    testWidgets('a merged table is not announced as a button', (tester) async {
      // It cannot be operated independently, and offering it would be a lie.
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TableCard(
              table: RestaurantTable.fromJson(const {
                'id': 't1',
                'code': 'D1',
                'capacity': 4,
                'status': 'OCCUPIED',
                'active': true,
                'mergedIntoId': 't2',
              }),
              order: null,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(TableCard)),
        isNot(matchesSemantics(isButton: true)),
      );
      handle.dispose();
    });
  });

  group('status is never carried by colour alone', () {
    testWidgets('a badge always has a word as well as a colour',
        (tester) async {
      // Roughly one man in twelve cannot separate the ready-green from the
      // cooking-amber. Every status surface pairs the colour with a label.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: StatusBadge(
              label: 'Ready',
              color: AppStatusColors.ready,
              icon: Icons.room_service_outlined,
            ),
          ),
        ),
      );

      expect(find.text('Ready'), findsOneWidget);
      expect(find.byIcon(Icons.room_service_outlined), findsOneWidget);
    });

    testWidgets('every order status has a distinct label and icon', (tester) async {
      final shared = RmsLocalizationsEn();
      final labels = <String>{};
      final icons = <IconData>{};
      for (final status in OrderStatus.values) {
        labels.add(status.labelIn(shared));
        icons.add(status.icon);
      }
      expect(labels.length, OrderStatus.values.length);
      // Cancelled and voided deliberately share an icon; everything else is
      // distinguishable without reading the colour.
      expect(icons.length, greaterThanOrEqualTo(OrderStatus.values.length - 1));
    });
  });

  group('a plan too big for the screen falls back to the grid', () {
    testWidgets('rather than rendering untappable tables', (tester) async {
      final handle = tester.ensureSemantics();

      // A designer canvas 4000 units wide: scaled to a phone, each 88-unit
      // table would be about 8 pixels across.
      await pumpFloor(
        tester,
        FloorSnapshot(
          areas: [
            FloorArea.fromJson(const {
              'id': 'a1',
              'name': 'DHA Hall',
              'sortOrder': 0,
              'tableCount': 2,
            }),
          ],
          tables: [
            table('D1', position: const {
              'x': 0,
              'y': 0,
              'width': 88,
              'height': 64,
            }),
            table('D2', position: const {
              'x': 3900,
              'y': 0,
              'width': 88,
              'height': 64,
            }),
          ],
          openOrdersByTableCode: const {},
        ),
      );

      expect(find.byType(GridView), findsOneWidget,
          reason: 'a waiter who cannot hit the table has no floor plan at all');
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('but keeps the real plan when it fits', (tester) async {
      await pumpFloor(
        tester,
        FloorSnapshot(
          areas: [
            FloorArea.fromJson(const {
              'id': 'a1',
              'name': 'DHA Hall',
              'sortOrder': 0,
              'tableCount': 2,
            }),
          ],
          tables: [
            table('D1', position: const {
              'x': 24,
              'y': 24,
              'width': 120,
              'height': 100,
            }),
            table('D2', position: const {
              'x': 200,
              'y': 24,
              'width': 120,
              'height': 100,
            }),
          ],
          openOrdersByTableCode: const {},
        ),
      );

      // Waiters navigate by spatial memory; the grid is the fallback, not the
      // preference.
      expect(find.byType(GridView), findsNothing);
    });
  });
}
