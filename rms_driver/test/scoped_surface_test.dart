import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_driver/src/features/runs/data/delivery_repository.dart';
import 'package:rms_driver/src/features/runs/data/driver_repository.dart';

/// Records the path of every call, so a test can assert which surface the app
/// asks for rather than what it does with the answer.
class _RecordingClient implements ApiClient {
  final gets = <String>[];
  final posts = <String>[];

  Object? nextGet;
  Object? nextPost;

  @override
  Future<dynamic> get(String path) async {
    gets.add(path);
    return nextGet ?? const <dynamic>[];
  }

  @override
  Future<dynamic> post(String path, [Object? body, String? idempotencyKey]) async {
    posts.add(path);
    return nextPost ?? const <String, dynamic>{};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The driver app must talk to the rider's own surface, never the dispatcher's.
///
/// This is a security property, not a style preference. `/restaurant/deliveries`
/// is the branch-wide board guarded by `delivery:dispatch`; the DRIVER role does
/// not hold that permission, and every route under `/restaurant/driver` is
/// filtered server-side to the signed-in rider's own jobs. A call that drifts
/// back to the old paths would 403 for a real rider — and, worse, would silently
/// work for anyone testing with a staff account, which is exactly how the app
/// came to be pointed at the wrong surface in the first place.
void main() {
  group('the rider app uses the scoped surface', () {
    test('the board reads the rider\'s own runs', () async {
      final client = _RecordingClient();
      await DeliveryRepository(client).runs();
      expect(client.gets.single, '/restaurant/driver/runs');
      expect(client.gets.single, isNot(contains('/restaurant/deliveries')));
    });

    test('opening one run reads it from the same surface', () async {
      final client = _RecordingClient()
        ..nextGet = {'id': 'dlv-1', 'status': 'ASSIGNED'};
      await DeliveryRepository(client).fetch('dlv-1');
      expect(client.gets.single, '/restaurant/driver/runs/dlv-1');
    });

    test('every transition posts to the rider surface', () async {
      for (final (from, segment) in <(DeliveryStatus, String)>[
        (DeliveryStatus.assigned, 'pickup'),
        (DeliveryStatus.pickedUp, 'enroute'),
        (DeliveryStatus.enRoute, 'complete'),
      ]) {
        final client = _RecordingClient();
        await DeliveryRepository(client).advance(id: 'dlv-1', from: from, otp: '123456');
        expect(client.posts.single, '/restaurant/driver/runs/dlv-1/$segment');
      }
    });

    test('failing and tracking stay on the rider surface', () async {
      final client = _RecordingClient();
      final repo = DeliveryRepository(client);
      await repo.fail(id: 'dlv-1', reason: 'nobody home');
      await repo.track(id: 'dlv-1', lat: 31.5, lng: 74.3);
      expect(client.posts, [
        '/restaurant/driver/runs/dlv-1/fail',
        '/restaurant/driver/runs/dlv-1/track',
      ]);
    });

    test('duty asks for a status the server will accept', () async {
      // ON_RUN is derived from held work and is not offered here — asking for it
      // would be rejected, and would mean the app was trying to decide something
      // that is the server's to know.
      final client = _RecordingClient()
        ..nextPost = {'id': 'drv-1', 'displayName': 'Bilal', 'dutyStatus': 'AVAILABLE'};
      final profile = await DriverRepository(client).setDuty(onShift: true);
      expect(client.posts.single, '/restaurant/driver/duty');
      expect(profile?.dutyStatus, DutyStatus.available);
    });
  });

  group('DriverProfile', () {
    test('a rider holding work cannot be offered an end-shift button', () {
      final me = DriverProfile.fromJson(const {
        'id': 'drv-1', 'displayName': 'Bilal', 'dutyStatus': 'ON_RUN',
        'liveRuns': 1, 'maxConcurrentRuns': 3, 'deliveredToday': 2,
      });
      expect(me.isOnShift, isTrue);
      expect(me.canEndShift, isFalse);
    });

    test('a rider on shift with nothing in hand may clock off', () {
      final me = DriverProfile.fromJson(const {
        'id': 'drv-1', 'displayName': 'Bilal', 'dutyStatus': 'AVAILABLE',
        'liveRuns': 0, 'maxConcurrentRuns': 3, 'deliveredToday': 4,
      });
      expect(me.canEndShift, isTrue);
    });
  });

  group('Delivery carries who to deliver to', () {
    test('the customer comes through for the rider at the door', () {
      final d = Delivery.fromJson(const {
        'id': 'dlv-1', 'status': 'EN_ROUTE',
        'customer': {'name': 'Ayesha Khan', 'phone': '+923001234567'},
      });
      expect(d.customer?.name, 'Ayesha Khan');
      expect(d.customer?.phone, '+923001234567');
    });

    test('an absent customer is null rather than an empty shell', () {
      final d = Delivery.fromJson(const {'id': 'dlv-1', 'status': 'PENDING'});
      expect(d.customer, isNull);
    });

    test('a customer with no name and no phone is treated as absent', () {
      final d = Delivery.fromJson(const {
        'id': 'dlv-1', 'status': 'PENDING',
        'customer': {'name': null, 'phone': null},
      });
      expect(d.customer, isNull);
    });
  });
}
