import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_waiter/src/features/menu/data/menu_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The repository against recorded responses from the live Karahi Point API,
/// envelopes and all — the seam the widget tests deliberately stub out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const branchId = 'e9ff122f-6adb-4d44-888a-81a10085c9ba';
  const otherBranchId = 'eee5a18a-a714-440f-b776-c28be346ac8a';

  // Trimmed from GET /restaurant/categories, /items and /config.
  const categoriesBody = '''
  {"data":[
    {"id":"cd43f73b","name":"Curries","parentId":null,"sortOrder":1,"active":true,"imageKey":null,"itemCount":2},
    {"id":"94faee03","name":"BBQ & Grill","parentId":null,"sortOrder":0,"active":true,"imageKey":null,"itemCount":2},
    {"id":"deadbeef","name":"Retired","parentId":null,"sortOrder":9,"active":false,"imageKey":null,"itemCount":0}
  ]}''';

  const itemsBody = '''
  {"data":[
    {"id":"0b47916e","categoryId":"cd43f73b","category":"Curries","sku":"NIH-01","barcode":null,
     "name":"Beef Nihari","basePrice":{"amountMinor":115000,"currency":"PKR"},
     "effectivePrice":{"amountMinor":115000,"currency":"PKR"},"currency":"PKR","taxBp":1600,
     "prepMinutes":12,"stationKey":"HOT_KITCHEN","isCombo":false,
     "imageKey":"https://www.themealdb.com/images/media/meals/uttupv1511815050.jpg",
     "available":true,"status":"ACTIVE"},
    {"id":"70b787fe","categoryId":null,"category":null,"sku":"KAR-01","barcode":null,
     "name":"Biryani","basePrice":{"amountMinor":40000,"currency":"PKR"},
     "effectivePrice":{"amountMinor":40000,"currency":"PKR"},"currency":"PKR","taxBp":null,
     "prepMinutes":10,"stationKey":"Kitchen","isCombo":false,"imageKey":null,
     "available":true,"status":"ACTIVE"}
  ]}''';

  const configBody = '''
  {"data":{"branchId":"$branchId","serviceModel":"DINE_IN",
   "channels":["DINE_IN","TAKEAWAY","DELIVERY"],"currency":"PKR","defaultTaxBp":1600,
   "serviceChargeBp":0,"buffetPrice":null,"autoFireKitchen":true,"tipEnabled":true,
   "roundingEnabled":true,"timezone":"Asia/Karachi"}}''';

  /// Records every path requested, and answers from [routes] by path suffix.
  ///
  /// Routes are matched in insertion order, so a specific path must be
  /// registered before the list endpoint it hangs off.
  Future<({MenuRepository repository, List<String> requests, Session session})>
      subject({
    Map<String, String> routes = const {},
    String branch = branchId,
  }) async {
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add(
        '${request.url.path}${request.url.hasQuery ? '?${request.url.query}' : ''}',
      );
      for (final entry in routes.entries) {
        if (request.url.path.endsWith(entry.key)) {
          return http.Response(entry.value, 200,
              headers: {'content-type': 'application/json'});
        }
      }
      return http.Response('{"detail":"no stub"}', 404);
    });

    SharedPreferences.setMockInitialValues({'branch_id': branch});
    final session = await Session.load(secretStore: InMemorySecretStore());
    return (
      repository:
          MenuRepository(ApiClient(session, httpClient: client), session),
      requests: requests,
      session: session,
    );
  }

  group('catalogue', () {
    test('reads categories, items and config in one pass', () async {
      final s = await subject(routes: {
        '/restaurant/categories': categoriesBody,
        '/restaurant/items': itemsBody,
        '/restaurant/config': configBody,
      });
      final catalogue = await s.repository.catalogue();

      expect(catalogue.items, hasLength(2));
      expect(catalogue.config.defaultTaxBp, 1600);
      expect(catalogue.categories.map((c) => c.name), ['BBQ & Grill', 'Curries'],
          reason: 'sorted by the designer\'s order, and the inactive one is out');
    });

    test('scopes items and config to the chosen outlet', () async {
      final s = await subject(routes: {
        '/restaurant/categories': categoriesBody,
        '/restaurant/items': itemsBody,
        '/restaurant/config': configBody,
      });
      await s.repository.catalogue();

      expect(
        s.requests.where((r) => r.contains('branchId=$branchId')),
        hasLength(2),
        reason: 'prices and tax are per branch; the catalogue itself is not',
      );
    });

    test('is fetched once and reused across tables', () async {
      final s = await subject(routes: {
        '/restaurant/categories': categoriesBody,
        '/restaurant/items': itemsBody,
        '/restaurant/config': configBody,
      });
      await s.repository.catalogue();
      await s.repository.catalogue();

      expect(s.requests, hasLength(3));
    });

    test('a refresh really refetches', () async {
      final s = await subject(routes: {
        '/restaurant/categories': categoriesBody,
        '/restaurant/items': itemsBody,
        '/restaurant/config': configBody,
      });
      await s.repository.catalogue();
      await s.repository.catalogue(forceRefresh: true);

      expect(s.requests, hasLength(6));
    });

    test('switching outlets drops the cache rather than quoting old prices',
        () async {
      final s = await subject(routes: {
        '/restaurant/categories': categoriesBody,
        '/restaurant/items': itemsBody,
        '/restaurant/config': configBody,
      });
      await s.repository.catalogue();
      await s.session.setBranchId(otherBranchId);
      await s.repository.catalogue();

      expect(s.requests, hasLength(6));
      expect(s.requests.last, contains(otherBranchId));
    });

    test('an uncategorised dish is still reachable', () async {
      final s = await subject(routes: {
        '/restaurant/categories': categoriesBody,
        '/restaurant/items': itemsBody,
        '/restaurant/config': configBody,
      });
      final catalogue = await s.repository.catalogue();

      expect(catalogue.hasUncategorised, isTrue);
      expect(catalogue.inCategory(null).single.name, 'Biryani');
      expect(catalogue.search('bir').single.name, 'Biryani');
      expect(catalogue.search('NIH-01').single.name, 'Beef Nihari',
          reason: 'a waiter may know the SKU from the paper menu');
    });
  });

  group('modifier groups', () {
    test('a tenant with none costs exactly one request', () async {
      final s = await subject(routes: {'/restaurant/modifier-groups': '{"data":[]}'});

      expect(await s.repository.modifierGroups(), isEmpty);
      expect(s.requests, hasLength(1));
    });

    test('each group is fetched for its choices, once', () async {
      final s = await subject(routes: {
        '/restaurant/modifier-groups/g1': jsonEncode({
          'data': {
            'id': 'g1',
            'name': 'Spice level',
            'minSelect': 1,
            'maxSelect': 1,
            'required': true,
            'sortOrder': 0,
            'modifiers': [
              {
                'id': 'm1',
                'name': 'Mild',
                'priceDelta': {'amountMinor': 0, 'currency': 'PKR'},
                'sortOrder': 0,
                'available': true,
              }
            ],
          }
        }),
        // Checked after the specific route above, so the list must come last.
        '/restaurant/modifier-groups': jsonEncode({
          'data': [
            {'id': 'g1', 'name': 'Spice level', 'modifierCount': 1}
          ]
        }),
      });

      final groups = await s.repository.modifierGroups();
      await s.repository.modifierGroups();

      expect(groups['g1']!.modifiers.single.name, 'Mild');
      expect(s.requests, hasLength(2), reason: 'cached for the session');
    });

    test('a failed fetch is not remembered as "no options exist"', () async {
      final s = await subject();

      await expectLater(s.repository.modifierGroups(), throwsA(isA<ApiException>()));
      await expectLater(s.repository.modifierGroups(), throwsA(isA<ApiException>()));

      expect(s.requests.length, greaterThan(1),
          reason: 'caching the failure would add every dish unconfigured for '
              'the rest of the shift');
    });
  });

  group('item detail', () {
    const detailBody = '''
    {"data":{"id":"0b47916e","description":null,"calories":null,"allergens":[],
     "tags":[],"modifierGroups":[],"comboComponents":[]}}''';

    test('is fetched per item and cached', () async {
      final s = await subject(routes: {'/restaurant/items/0b47916e': detailBody});

      await s.repository.detail('0b47916e');
      final again = await s.repository.detail('0b47916e');

      expect(again.needsConfiguration, isFalse);
      expect(s.requests, hasLength(1));
      expect(s.requests.single, contains('branchId=$branchId'));
    });
  });
}
