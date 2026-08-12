import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_customer/src/features/orders/data/customer_order_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The delivery address, tested against the real repository and a real
/// [ApiClient] — only the socket is faked.
///
/// It has to be at this level: the fallback IS the HTTP behaviour. Faking the
/// repository would have tested the fake.
///
/// Why any of this exists: `POST /restaurant/orders` was only ever observed
/// taking `channel`, `guestCount` and `branchId`. Whether it accepts an
/// `address` is unverified. The app this replaces collected an address and
/// silently dropped it — a customer who typed where they live and got food
/// nowhere. So the address is sent, and if the server refuses the request
/// because of it, the order goes through without and the customer is told.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<CustomerOrderRepository> repositoryOn(
    Future<http.Response> Function(http.Request request) handler,
  ) async {
    SharedPreferences.setMockInitialValues({
      'branch_id': 'branch-1',
      'api_base': 'https://example.test/api',
    });
    final session = await Session.load(secretStore: InMemorySecretStore());
    return CustomerOrderRepository(
      ApiClient(session, httpClient: MockClient(handler)),
      session,
    );
  }

  http.Response created() => http.Response(
        jsonEncode({
          'data': {
            'id': 'order-1',
            'orderNo': 'ORD-000021',
            'status': 'DRAFT',
            'channel': 'DELIVERY',
            'items': [],
          }
        }),
        201,
        headers: {'content-type': 'application/json'},
      );

  test('the address is sent with the order', () async {
    final bodies = <Map<String, dynamic>>[];
    final repository = await repositoryOn((request) async {
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return created();
    });

    final result = await repository.create(
      channel: OrderChannel.delivery,
      address: '12 Street 4, F-7/3',
      idempotencyKey: 'k1',
    );

    expect(bodies.single['address'], '12 Street 4, F-7/3');
    expect(bodies.single['channel'], 'DELIVERY');
    expect(result.addressAccepted, isTrue);
  });

  test('a server that refuses the field still gets the order', () async {
    final bodies = <Map<String, dynamic>>[];
    final repository = await repositoryOn((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      bodies.add(body);
      if (body.containsKey('address')) {
        return http.Response(
          jsonEncode({'detail': 'property address should not exist'}),
          400,
          headers: {'content-type': 'application/problem+json'},
        );
      }
      return created();
    });

    final result = await repository.create(
      channel: OrderChannel.delivery,
      address: '12 Street 4, F-7/3',
      idempotencyKey: 'k1',
    );

    // Degrading loudly beats degrading silently: the order exists, and the
    // caller knows to tell the customer to expect a call.
    expect(bodies.length, 2);
    expect(bodies.first.containsKey('address'), isTrue);
    expect(bodies.last.containsKey('address'), isFalse);
    expect(result.order.id, 'order-1');
    expect(result.addressAccepted, isFalse);
  });

  test('the retry carries a different idempotency key', () async {
    // The interceptor rejects one key replayed with a different body, so
    // reusing it would turn the fallback into a 422.
    final keys = <String?>[];
    final repository = await repositoryOn((request) async {
      keys.add(request.headers['Idempotency-Key']);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body.containsKey('address')) {
        return http.Response('{"detail":"nope"}', 400,
            headers: {'content-type': 'application/json'});
      }
      return created();
    });

    await repository.create(
      channel: OrderChannel.delivery,
      address: 'somewhere',
      idempotencyKey: 'k1',
    );

    expect(keys.first, 'k1');
    expect(keys.last, 'k1:no-address');
  });

  test('a failure that is not about the address is not retried', () async {
    // Retrying a server fault without the address would quietly drop it for a
    // reason that had nothing to do with it.
    var attempts = 0;
    final repository = await repositoryOn((request) async {
      attempts++;
      return http.Response('{"detail":"You may not order here."}', 403,
          headers: {'content-type': 'application/json'});
    });

    await expectLater(
      repository.create(
        channel: OrderChannel.delivery,
        address: 'somewhere',
        idempotencyKey: 'k1',
      ),
      throwsA(isA<ApiException>()),
    );
    expect(attempts, 1);
  });

  test('a collection order sends no address at all', () async {
    final bodies = <Map<String, dynamic>>[];
    final repository = await repositoryOn((request) async {
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return created();
    });

    final result = await repository.create(
      channel: OrderChannel.takeaway,
      idempotencyKey: 'k1',
    );

    expect(bodies.single.containsKey('address'), isFalse);
    // Nothing was dropped, so there is nothing to warn about.
    expect(result.addressAccepted, isFalse);
  });
}
