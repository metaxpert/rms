import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseTtl — the API sends "15m", not seconds', () {
    test('parses each unit', () {
      expect(Session.parseTtl('15m'), const Duration(minutes: 15));
      expect(Session.parseTtl('3600s'), const Duration(seconds: 3600));
      expect(Session.parseTtl('1h'), const Duration(hours: 1));
      expect(Session.parseTtl('7d'), const Duration(days: 7));
    });

    test('a bare number is seconds', () {
      expect(Session.parseTtl('900'), const Duration(seconds: 900));
    });

    test('returns null for junk rather than guessing', () {
      expect(Session.parseTtl(null), isNull);
      expect(Session.parseTtl(''), isNull);
      expect(Session.parseTtl('soon'), isNull);
      expect(Session.parseTtl('15 minutes'), isNull);
    });
  });

  group('token lifecycle', () {
    late Session session;
    late InMemorySecretStore secrets;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      secrets = InMemorySecretStore();
      session = await Session.load(secretStore: secrets);
    });

    test('starts signed out', () {
      expect(session.isAuthenticated, isFalse);
      expect(session.accessTokenExpiring(), isTrue);
    });

    test('tokens go to the secret store, never to preferences', () async {
      await session.saveTokens(
        accessToken: 'access-abc',
        refreshToken: 'refresh-xyz',
        expiresIn: '15m',
      );

      expect(await secrets.read('access_token'), 'access-abc');
      expect(await secrets.read('refresh_token'), 'refresh-xyz');

      // The plaintext store must not hold either token.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNull);
      expect(prefs.getString('refresh_token'), isNull);
      expect(prefs.getString('token'), isNull);
    });

    test('a fresh token is not reported as expiring', () async {
      await session.saveTokens(accessToken: 'a', expiresIn: '15m');
      expect(session.accessTokenExpiring(), isFalse);
    });

    test('expiry skew triggers a refresh before the token actually dies',
        () async {
      // 30s of life left, 60s skew -> refresh now, so the waiter never eats a
      // 401 we could have prevented.
      await session.saveTokens(accessToken: 'a', expiresIn: '30s');
      expect(session.accessTokenExpiring(), isTrue);
      expect(
        session.accessTokenExpiring(skew: const Duration(seconds: 5)),
        isFalse,
      );
    });

    test('unknown lifetime defers to 401 handling instead of refreshing madly',
        () async {
      await session.saveTokens(accessToken: 'a'); // no expiresIn
      expect(session.accessTokenExpiring(), isFalse);
    });

    test('clear() wipes credentials but keeps the server address', () async {
      await session.setBaseUrl('https://rms.metaxperts.net/api');
      await session.saveTokens(accessToken: 'a', refreshToken: 'r');
      await session.setBranchId('branch-1');

      await session.clear();

      expect(session.isAuthenticated, isFalse);
      expect(session.refreshToken, isNull);
      expect(session.branchId, isNull);
      // Staff do not know the API URL; making them retype it is a support call.
      expect(session.baseUrl, 'https://rms.metaxperts.net/api');
    });

    test('setBaseUrl strips trailing slashes so paths do not double up',
        () async {
      await session.setBaseUrl('https://rms.metaxperts.net/api///');
      expect(session.baseUrl, 'https://rms.metaxperts.net/api');
    });
  });

  group('legacy token migration', () {
    test('moves a plaintext token into the keystore and erases it', () async {
      // An older build stored the access token in shared_preferences.
      SharedPreferences.setMockInitialValues({'token': 'legacy-token'});
      final secrets = InMemorySecretStore();

      final session = await Session.load(secretStore: secrets);

      expect(session.accessToken, 'legacy-token');
      expect(await secrets.read('access_token'), 'legacy-token');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('token'), isNull,
          reason: 'the readable copy must not survive the upgrade');
    });
  });

  group('permissions from JWT claims', () {
    late Session session;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      session = await Session.load(secretStore: InMemorySecretStore());
    });

    // header.payload.signature — payload only, unsigned; the app never verifies.
    String tokenWith(String payloadJson) {
      String b64(String s) {
        final encoded = base64Url.encode(s.codeUnits);
        return encoded.replaceAll('=', '');
      }

      return '${b64('{"alg":"none"}')}.${b64(payloadJson)}.sig';
    }

    test('reads perms, sub and tenantId', () async {
      await session.saveTokens(
        accessToken: tokenWith(
          '{"sub":"user-1","tenantId":"tenant-9",'
          '"perms":["restaurant:operate","restaurant:order:write"]}',
        ),
      );

      expect(session.userId, 'user-1');
      expect(session.tenantId, 'tenant-9');
      expect(session.hasPermission('restaurant:order:write'), isTrue);
      expect(session.hasPermission('restaurant:print'), isFalse);
    });

    test('wildcard grants everything (tenant admin)', () async {
      await session.saveTokens(
        accessToken: tokenWith('{"sub":"u","perms":["*"]}'),
      );
      expect(session.hasPermission('restaurant:delivery:dispatch'), isTrue);
    });

    test('a malformed token yields no permissions rather than throwing',
        () async {
      await session.saveTokens(accessToken: 'not-a-jwt');
      expect(session.permissions, isEmpty);
      expect(session.hasPermission('restaurant:operate'), isFalse);
    });
  });
}
