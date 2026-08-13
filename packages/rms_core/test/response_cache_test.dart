import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The read cache is what lets a waiter in a wifi blackspot still read a menu.
/// It is also the thing most likely to show somebody the wrong data, so what it
/// refuses to do matters as much as what it does.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ResponseCache> cache([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    return ResponseCache(await SharedPreferences.getInstance());
  }

  group('storage', () {
    test('round-trips a payload with the time it was read', () async {
      final store = await cache();
      await store.write('cache:menu:b1', [
        {'id': 'i1', 'name': 'Naan'},
      ]);

      final read = store.read('cache:menu:b1');
      expect(read!.json, [
        {'id': 'i1', 'name': 'Naan'},
      ]);
      expect(
        DateTime.now().difference(read.cachedAt).inSeconds,
        lessThan(5),
      );
    });

    test('an absent key reads as nothing', () async {
      expect((await cache()).read('cache:menu:b1'), isNull);
    });

    test('unreadable storage is discarded rather than retried forever',
        () async {
      final store = await cache({
        'cache:menu:b1': 'not json at all',
        'cache:menu:b1:at': DateTime.now().millisecondsSinceEpoch,
      });
      expect(store.read('cache:menu:b1'), isNull);
    });

    test('a payload with no timestamp is not trusted', () async {
      // Without one there is no way to tell a waiter how old it is, and an
      // undated cache presented as current is the failure this exists to avoid.
      final store = await cache({'cache:menu:b1': '[]'});
      expect(store.read('cache:menu:b1'), isNull);
    });

    test('keys are scoped per outlet', () async {
      // One outlet's prices must never be served for another.
      expect(
        ResponseCache.keyFor('menu', 'b1'),
        isNot(ResponseCache.keyFor('menu', 'b2')),
      );
      expect(ResponseCache.keyFor('menu', null), contains('all'));
    });

    test('clearing all leaves non-cache preferences alone', () async {
      // Signing out clears the cache; it must not take the server address or
      // the remembered email with it.
      final store = await cache({
        'cache:menu:b1': '[]',
        'cache:menu:b1:at': 1,
        'api_base': 'https://rms.example.com/api',
        'last_email': 'waiter@example.com',
      });

      await store.clearAll();
      final prefs = await SharedPreferences.getInstance();

      expect(store.read('cache:menu:b1'), isNull);
      expect(prefs.getString('api_base'), 'https://rms.example.com/api');
      expect(prefs.getString('last_email'), 'waiter@example.com');
    });
  });

  group('read-through', () {
    test('a successful fetch is returned and remembered', () async {
      final store = await cache();
      final result = await readThroughCache<int>(
        cache: store,
        key: 'cache:x:b1',
        fetch: () async => 41,
        parse: (json) => (json as int) + 1,
      );

      expect(result.value, 42);
      expect(result.isFresh, isTrue);
      expect(store.read('cache:x:b1')!.json, 41);
    });

    test('a dropped connection falls back to the last good read', () async {
      final store = await cache();
      await store.write('cache:x:b1', 41);

      final result = await readThroughCache<int>(
        cache: store,
        key: 'cache:x:b1',
        fetch: () async =>
            throw ApiException(ApiErrorKind.network, 'No wifi.'),
        parse: (json) => (json as int) + 1,
      );

      expect(result.value, 42);
      expect(result.isFresh, isFalse,
          reason: 'the screen has to be able to say this is not current');
    });

    test('a refusal is NOT answered from the cache', () async {
      // A 403 is the server telling us something true. Serving stale data over
      // it would hide a permission change behind yesterday's menu.
      final store = await cache();
      await store.write('cache:x:b1', 41);

      await expectLater(
        readThroughCache<int>(
          cache: store,
          key: 'cache:x:b1',
          fetch: () async =>
              throw ApiException(ApiErrorKind.forbidden, 'Not allowed.'),
          parse: (json) => (json as int) + 1,
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('a server fault is not answered from the cache either', () async {
      final store = await cache();
      await store.write('cache:x:b1', 41);

      await expectLater(
        readThroughCache<int>(
          cache: store,
          key: 'cache:x:b1',
          fetch: () async => throw ApiException(ApiErrorKind.server, 'Boom.'),
          parse: (json) => (json as int) + 1,
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('a dropped connection with nothing cached still fails', () async {
      // Better an honest error than an empty menu that looks like a real one.
      await expectLater(
        readThroughCache<int>(
          cache: await cache(),
          key: 'cache:x:b1',
          fetch: () async =>
              throw ApiException(ApiErrorKind.network, 'No wifi.'),
          parse: (json) => json as int,
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('the age reported is the age of the DATA, not of the read', () async {
      final store = await cache({
        'cache:x:b1': '41',
        'cache:x:b1:at': DateTime.now()
            .subtract(const Duration(minutes: 30))
            .millisecondsSinceEpoch,
      });

      final result = await readThroughCache<int>(
        cache: store,
        key: 'cache:x:b1',
        fetch: () async =>
            throw ApiException(ApiErrorKind.network, 'No wifi.'),
        parse: (json) => json as int,
      );

      expect(result.age(DateTime.now()).inMinutes, 30);
    });
  });
}
