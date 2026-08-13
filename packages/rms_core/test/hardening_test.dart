import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The boundaries. Not business rules — the points at which something quietly
/// goes wrong instead of loudly failing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parsing an amount somebody typed', () {
    test('refuses a number large enough to wrap an int', () {
      // Past roughly 9.2×10^16 minor units an int wraps, and a wrapped total is
      // a wrong bill that looks like a right one. A fat-fingered entry should
      // be a field error, not a negative charge.
      expect(Money.tryParse('100000000000000000000'), isNull);
      expect(Money.tryParse('-100000000000000000000'), isNull);
      expect(Money.tryParse('1e30'), isNull);
    });

    test('accepts anything a restaurant could plausibly charge', () {
      expect(Money.tryParse('1531.20'), const Money(153120));
      expect(Money.tryParse('1,531.20'), const Money(153120));
      expect(Money.tryParse('9999999.99'), const Money(999999999));
    });

    test('refuses junk rather than treating it as zero', () {
      // Silently reading "abc" as 0.00 would settle a bill for nothing.
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('   '), isNull);
      expect(Money.tryParse('NaN'), isNull);
      expect(Money.tryParse('Infinity'), isNull);
    });

    test('rounds half-up symmetrically for charges and refunds', () {
      expect(Money.tryParse('1.005'), const Money(101));
      expect(Money.tryParse('-1.005'), const Money(-101));
    });
  });

  group('the read cache under pressure', () {
    Future<ResponseCache> cache() async {
      SharedPreferences.setMockInitialValues({});
      return ResponseCache(await SharedPreferences.getInstance());
    }

    test('an outsized payload is not written at all', () async {
      // `shared_preferences` rewrites its whole file on commit; a multi-megabyte
      // menu would turn every successful fetch into a long main-thread write on
      // exactly the low-end devices this app targets.
      final store = await cache();
      final huge = List.generate(60000, (i) => {'id': 'item-$i', 'name': 'x' * 20});

      await store.write('cache:menu:b1', huge);

      expect(store.read('cache:menu:b1'), isNull);
    });

    test('an outsized payload also clears any smaller one behind it', () async {
      // Otherwise last week's small menu would be served as though it were the
      // fresh one that was too big to keep.
      final store = await cache();
      await store.write('cache:menu:b1', [
        {'id': 'i1'},
      ]);
      expect(store.read('cache:menu:b1'), isNotNull);

      await store.write(
        'cache:menu:b1',
        List.generate(60000, (i) => {'id': 'item-$i', 'name': 'x' * 20}),
      );

      expect(store.read('cache:menu:b1'), isNull);
    });

    test('a payload just inside the limit is kept', () async {
      final store = await cache();
      await store.write('cache:menu:b1', 'x' * (100 * 1024));
      expect(store.read('cache:menu:b1'), isNotNull);
    });
  });

  group('what the API client will not do', () {
    test('a mutation can be sent deliberately unkeyed', () {
      // Location pings are a stream of distinct facts, not operations to be
      // replayed; keying them would write one idempotency row per ping.
      expect(ApiClient.unkeyed, isEmpty);
    });
  });

  group('tokens never reach anything readable', () {
    test('the session exposes claims but the store keeps the secret', () async {
      // `perms` and `sub` are read client-side for UI gating; the token itself
      // belongs in the keystore, never in preferences a USB cable can read.
      SharedPreferences.setMockInitialValues({});
      final session = await Session.load(secretStore: InMemorySecretStore());
      await session.saveTokens(
        accessToken: 'header.payload.signature',
        refreshToken: 'refresh-me',
        expiresIn: '15m',
      );

      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        final value = prefs.get(key);
        expect(value.toString(), isNot(contains('header.payload.signature')));
        expect(value.toString(), isNot(contains('refresh-me')));
      }
    });

    test('signing out leaves nothing behind to reuse', () async {
      SharedPreferences.setMockInitialValues({});
      final session = await Session.load(secretStore: InMemorySecretStore());
      await session.saveTokens(accessToken: 'a.b.c', refreshToken: 'r');
      await session.setBranchId('branch-1');

      await session.clear();

      expect(session.accessToken, isNull);
      expect(session.refreshToken, isNull);
      // The outlet goes too: the next person on a shared till must choose.
      expect(session.branchId, isNull);
    });
  });
}
