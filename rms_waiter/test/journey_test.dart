import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_waiter/src/app/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The whole shift, through the real app.
///
/// Every other suite tests one seam. This one boots `WaiterApp` — real router,
/// real guards, real controllers — against a fake HTTP layer and walks a table
/// from sign-in to a settled bill. It is the test that would catch two
/// correct-looking pieces that do not fit together.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeApi api;

  Future<void> bootApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'api_base': 'https://rms.test/api'});
    final session = await Session.load(secretStore: InMemorySecretStore());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(session),
          sharedPreferencesProvider
              .overrideWithValue(await SharedPreferences.getInstance()),
          apiClientProvider.overrideWith(
            (ref) => ApiClient(session, httpClient: api.client),
          ),
        ],
        child: const WaiterApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => api = _FakeApi());

  testWidgets('sign in, take an order, fire it, settle the bill',
      (tester) async {
    await bootApp(tester);

    // ── Sign in ────────────────────────────────────────────────────────────
    expect(find.text('Waiter sign in'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'waiter@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'correct horse',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // ── Choose an outlet ───────────────────────────────────────────────────
    // The guard holds here: a floor read without a branch would silently show
    // another outlet's tables.
    expect(find.text('Choose your outlet'), findsOneWidget);
    await tester.tap(find.text('DHA Phase 5'));
    await tester.pumpAndSettle();

    // ── The floor ──────────────────────────────────────────────────────────
    expect(find.text('Floor'), findsOneWidget);
    expect(find.text('D1'), findsOneWidget);
    await tester.tap(find.text('D1'));
    await tester.pumpAndSettle();

    // ── Take an order ──────────────────────────────────────────────────────
    expect(find.text('Table D1'), findsOneWidget);
    await tester.tap(find.text('Open the menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(GridView),
      matching: find.text('Chicken Karahi'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Done'));
    await tester.pumpAndSettle();

    // The ticket predicts the bill before anything is sent: 1320.00 + 16% =
    // 1531.20, rounded to the rupee.
    expect(find.text('Rs 1,531.00'), findsOneWidget);

    // ── Fire it ────────────────────────────────────────────────────────────
    await tester.tap(find.textContaining('Send · 1'));
    await tester.pumpAndSettle();

    expect(api.calls, containsAllInOrder([
      'POST /restaurant/orders',
      'POST /restaurant/orders/order-1/items',
      'POST /restaurant/orders/order-1/place',
    ]));
    expect(find.textContaining('Sent to the kitchen'), findsOneWidget);
    expect(find.text('SENT · ORD-000001'), findsOneWidget);

    // ── Settle ─────────────────────────────────────────────────────────────
    // Let the "sent" snack bar retire; it floats over the action bar.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Bill'));
    await tester.pumpAndSettle();

    expect(find.text('Total due'), findsOneWidget);
    await tester.tap(find.textContaining('Settle'));
    await tester.pumpAndSettle();

    expect(find.text('Bill settled'), findsOneWidget);
    expect(api.settlements, hasLength(1));
    expect(api.settlements.single['payments'], [
      {'method': 'CASH', 'amountMinor': 153100},
    ]);
  });

  testWidgets('a session that expires mid-service refreshes instead of ending',
      (tester) async {
    // The defect that made this rewrite necessary: the old client had no
    // refresh, so a waiter was signed out fifteen minutes into a shift.
    await bootApp(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'waiter@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'correct horse',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DHA Phase 5'));
    await tester.pumpAndSettle();

    // Every request from here answers 401 once, as an expired token would.
    api.expireNextAccessToken = true;
    await tester.tap(find.text('D1'));
    await tester.pumpAndSettle();

    expect(api.calls, contains('POST /auth/refresh'));
    expect(find.text('Table D1'), findsOneWidget,
        reason: 'the waiter should never see the sign-in screen for this');
  });

  testWidgets('a refused sign-in says what the server said', (tester) async {
    api.rejectSignIn = true;
    await bootApp(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'waiter@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'wrong',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Those details were not recognised.'), findsOneWidget);
    expect(find.text('Waiter sign in'), findsOneWidget);
  });
}

/// A restaurant API, in memory.
///
/// Routed by path rather than mocked per-call, so the test exercises the real
/// sequence the app chooses rather than a sequence the test dictated.
class _FakeApi {
  final calls = <String>[];
  final settlements = <Map<String, dynamic>>[];

  bool rejectSignIn = false;
  bool expireNextAccessToken = false;

  String _orderStatus = 'DRAFT';
  bool _hasItems = false;

  late final http.Client client = MockClient((request) async {
    final path = request.url.path.replaceFirst('/api', '');
    calls.add('${request.method} $path');

    if (path == '/auth/login') {
      if (rejectSignIn) {
        return _problem(401, 'Those details were not recognised.');
      }
      return _ok({
        'accessToken': 'access.token.one',
        'refreshToken': 'refresh.token.one',
        'expiresIn': '15m',
      });
    }
    if (path == '/auth/refresh') {
      return _ok({
        'accessToken': 'access.token.two',
        'refreshToken': 'refresh.token.two',
        'expiresIn': '15m',
      });
    }

    if (expireNextAccessToken) {
      expireNextAccessToken = false;
      return _problem(401, 'Token expired.');
    }

    if (path == '/restaurant/branches') {
      return _ok([
        {
          'id': 'branch-1',
          'name': 'DHA Phase 5',
          'code': 'DHA5',
          'active': true,
          'configured': true,
        },
      ]);
    }
    if (path == '/restaurant/areas') {
      return _ok([
        {'id': 'a1', 'name': 'DHA Hall', 'sortOrder': 0, 'tableCount': 1},
      ]);
    }
    if (path == '/restaurant/tables') {
      return _ok([
        {
          'id': 'table-1',
          'areaId': 'a1',
          'area': 'DHA Hall',
          'branchId': 'branch-1',
          'code': 'D1',
          'capacity': 4,
          'shape': 'RECT',
          'status': 'AVAILABLE',
          'active': true,
        },
      ]);
    }
    if (path == '/restaurant/categories') {
      return _ok([
        {'id': 'c1', 'name': 'Curries', 'sortOrder': 0, 'active': true},
      ]);
    }
    if (path == '/restaurant/items') {
      return _ok([
        {
          'id': 'item-karahi',
          'name': 'Chicken Karahi',
          'effectivePrice': {'amountMinor': 132000, 'currency': 'PKR'},
          'available': true,
          'status': 'ACTIVE',
          'categoryId': 'c1',
          'category': 'Curries',
          'taxBp': 1600,
          'prepMinutes': 15,
        },
      ]);
    }
    if (path == '/restaurant/config') {
      return _ok({
        'currency': 'PKR',
        'defaultTaxBp': 1600,
        'serviceChargeBp': 0,
        'roundingEnabled': true,
        'autoFireKitchen': true,
      });
    }
    if (path == '/restaurant/modifier-groups') return _ok([]);
    if (path == '/restaurant/items/item-karahi') {
      // The only endpoint that says whether a dish takes options. This one
      // takes none, so the picker adds on a single tap.
      return _ok({
        'id': 'item-karahi',
        'name': 'Chicken Karahi',
        'effectivePrice': {'amountMinor': 132000, 'currency': 'PKR'},
        'available': true,
        'status': 'ACTIVE',
        'taxBp': 1600,
        'modifierGroups': <Map<String, dynamic>>[],
      });
    }

    if (path == '/restaurant/orders' && request.method == 'GET') {
      return _ok(_hasItems ? [_orderJson()] : []);
    }
    if (path == '/restaurant/orders' && request.method == 'POST') {
      return _ok(_orderJson());
    }
    if (path == '/restaurant/orders/order-1/items') {
      _hasItems = true;
      return _ok(_orderJson());
    }
    if (path == '/restaurant/orders/order-1/place') {
      // This tenant has autoFireKitchen, so placing confirms in one step —
      // which is why the app must treat a skipped `confirm` as success.
      _orderStatus = 'CONFIRMED';
      return _ok(_orderJson());
    }
    if (path == '/restaurant/orders/order-1/settle') {
      settlements.add(jsonDecode(request.body) as Map<String, dynamic>);
      _orderStatus = 'SETTLED';
      return _ok(_orderJson());
    }
    if (path == '/restaurant/orders/order-1') return _ok(_orderJson());

    return _problem(404, 'No stub for $path');
  });

  Map<String, dynamic> _orderJson() => {
        'id': 'order-1',
        'orderNo': 'ORD-000001',
        'status': _orderStatus,
        'channel': 'DINE_IN',
        'table': 'D1',
        'tableId': 'table-1',
        'guestCount': 4,
        'totals': {
          'subtotal': {'amountMinor': 132000, 'currency': 'PKR'},
          'tax': {'amountMinor': 21120, 'currency': 'PKR'},
          'total': {'amountMinor': 153100, 'currency': 'PKR'},
        },
        'items': _hasItems
            ? [
                {
                  'id': 'line-1',
                  'itemId': 'item-karahi',
                  'name': 'Chicken Karahi',
                  'qty': 1,
                  'unitPrice': {'amountMinor': 132000, 'currency': 'PKR'},
                  'lineTotal': {'amountMinor': 153120, 'currency': 'PKR'},
                },
              ]
            : <Map<String, dynamic>>[],
      };

  static http.Response _ok(Object data) => http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json'},
      );

  static http.Response _problem(int status, String detail) => http.Response(
        jsonEncode({'detail': detail}),
        status,
        headers: {'content-type': 'application/problem+json'},
      );
}
