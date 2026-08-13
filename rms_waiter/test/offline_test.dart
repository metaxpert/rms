import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_waiter/src/features/floor/data/floor_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a waiter gets in the far corner of a dining room.
///
/// Driven through the real repository and a real [ApiClient] over a mocked
/// socket, because the fallback IS the HTTP behaviour.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const branchId = 'branch-1';

  String bodyFor(String path) {
    if (path.contains('/areas')) {
      return jsonEncode({
        'data': [
          {'id': 'a1', 'name': 'DHA Hall', 'sortOrder': 0, 'tableCount': 1},
        ],
      });
    }
    if (path.contains('/tables')) {
      return jsonEncode({
        'data': [
          {
            'id': 't1',
            'areaId': 'a1',
            'area': 'DHA Hall',
            'branchId': branchId,
            'code': 'D1',
            'capacity': 4,
            'shape': 'RECT',
            'status': 'OCCUPIED',
            'active': true,
          },
        ],
      });
    }
    return jsonEncode({
      'data': [
        {
          'id': 'o1',
          'orderNo': 'ORD-000004',
          'channel': 'DINE_IN',
          'status': 'READY',
          'table': 'D1',
          'total': {'amountMinor': 153100, 'currency': 'PKR'},
        },
      ],
    });
  }

  /// A repository whose connection can be cut, sharing one preferences store so
  /// the cache written before the cut is there after it.
  Future<FloorRepository> floorWith({required bool online}) async {
    final session = await Session.load(secretStore: InMemorySecretStore());
    final client = MockClient((request) async {
      if (!online) throw const SocketExceptionStub();
      return http.Response(
        bodyFor(request.url.path),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    return FloorRepository(
      ApiClient(session, httpClient: client),
      session,
      ResponseCache(await SharedPreferences.getInstance()),
    );
  }

  setUp(() => SharedPreferences.setMockInitialValues({'branch_id': branchId}));

  test('a good read is marked fresh', () async {
    final floor = await (await floorWith(online: true)).snapshot();

    expect(floor.isStale, isFalse);
    expect(floor.readAt, isNotNull);
    expect(floor.tables.single.code, 'D1');
    expect(floor.readyCount, 1);
  });

  test('a dropped connection serves the last floor, marked stale', () async {
    // The dining room has not moved, so this is still useful — but the ORDER
    // state is the half a waiter acts on, and the screen has to say so.
    await (await floorWith(online: true)).snapshot();

    final offline = await (await floorWith(online: false)).snapshot();

    expect(offline.isStale, isTrue);
    expect(offline.tables.single.code, 'D1');
    expect(offline.readAt, isNotNull);
  });

  test('with nothing cached, offline is an honest failure', () async {
    // An empty floor plan that looked real would be far worse than an error a
    // waiter can act on by moving nearer the router.
    await expectLater(
      (await floorWith(online: false)).snapshot(),
      throwsA(isA<ApiException>()),
    );
  });

  test('a fresh read replaces the cached one', () async {
    await (await floorWith(online: true)).snapshot();
    await (await floorWith(online: false)).snapshot();

    final recovered = await (await floorWith(online: true)).snapshot();
    expect(recovered.isStale, isFalse);
  });

  test('another outlet\'s floor is never served from this one\'s cache',
      () async {
    await (await floorWith(online: true)).snapshot();

    // Switching outlet changes the cache key, so there is nothing to fall back
    // on — which is right: showing another branch's tables would be worse than
    // an error.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('branch_id', 'branch-2');

    await expectLater(
      (await floorWith(online: false)).snapshot(),
      throwsA(isA<ApiException>()),
    );
  });
}

/// `MockClient` cannot throw a real `SocketException` without `dart:io` typing
/// getting in the way of the web-safe test runner, and `ApiClient` classifies
/// any `ClientException` as a network failure — which is the case under test.
class SocketExceptionStub implements http.ClientException {
  const SocketExceptionStub();

  @override
  String get message => 'Connection closed';

  @override
  Uri? get uri => null;
}
