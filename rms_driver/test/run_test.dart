import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_driver/src/features/location/data/location_source.dart';
import 'package:rms_driver/src/features/runs/application/run_controller.dart';
import 'package:rms_driver/src/features/runs/data/delivery_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

/// A rider acts one-handed, outdoors, in a hurry. These tests are about the
/// two things that go wrong when that is not respected: asking the server for a
/// transition the job cannot make, and reporting a position that is not true.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const deliveryId = 'dlv-1';

  Future<ProviderContainer> containerWith(
    FakeDeliveries deliveries, {
    FakeLocation? location,
  }) async {
    SharedPreferences.setMockInitialValues({'branch_id': 'branch-1'});
    final session = await Session.load(secretStore: InMemorySecretStore());
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWithValue(session),
        sharedPreferencesProvider
            .overrideWithValue(await SharedPreferences.getInstance()),
        deliveryRepositoryProvider.overrideWithValue(deliveries),
        if (location != null)
          locationSourceProvider.overrideWithValue(location),
      ],
    );
    addTearDown(container.dispose);
    // autoDispose providers need a listener to survive between reads.
    container.listen(runControllerProvider(deliveryId), (_, __) {});
    return container;
  }

  RunController controllerIn(ProviderContainer c) =>
      c.read(runControllerProvider(deliveryId).notifier);

  RunState stateIn(ProviderContainer c) =>
      c.read(runControllerProvider(deliveryId));

  group('the board', () {
    test('puts the job closest to a waiting customer first', () {
      // A bag already on the bike outranks one still on the pass.
      final board = RunBoard.from([
        FakeDeliveries.delivery(id: 'a', status: 'ASSIGNED'),
        FakeDeliveries.delivery(id: 'b', status: 'EN_ROUTE'),
        FakeDeliveries.delivery(id: 'c', status: 'PICKED_UP'),
      ]);

      expect(board.active.map((d) => d.id).toList(), ['b', 'c', 'a']);
    });

    test('separates finished runs from live ones', () {
      final board = RunBoard.from([
        FakeDeliveries.delivery(id: 'a', status: 'DELIVERED'),
        FakeDeliveries.delivery(id: 'b', status: 'EN_ROUTE'),
        FakeDeliveries.delivery(id: 'c', status: 'FAILED'),
        FakeDeliveries.delivery(id: 'd', status: 'CANCELLED'),
      ]);

      expect(board.active.map((d) => d.id).toList(), ['b']);
      expect(board.finished.length, 3);
    });

    test('an unassigned job is still shown, just not urgent', () {
      // Dispatch is a manager's permission; a rider waiting to be given a job
      // should still see it exists.
      final board = RunBoard.from([
        FakeDeliveries.delivery(id: 'a', status: 'PENDING'),
        FakeDeliveries.delivery(id: 'b', status: 'ASSIGNED'),
      ]);
      expect(board.active.map((d) => d.id).toList(), ['b', 'a']);
    });
  });

  group('advancing a run', () {
    test('asks for the transition the current status allows', () async {
      final deliveries = FakeDeliveries();
      final container = await containerWith(deliveries);

      await controllerIn(container)
          .advance(FakeDeliveries.delivery(status: 'ASSIGNED'));

      // The button and the request come from the same source, so the app
      // cannot ask for a transition the server will refuse.
      expect(deliveries.advances.single.$1, DeliveryStatus.assigned);
      expect(stateIn(container).delivery!.status, DeliveryStatus.pickedUp);
    });

    test('completion carries the customer\'s code', () async {
      final deliveries = FakeDeliveries();
      final container = await containerWith(deliveries);

      await controllerIn(container).advance(
        FakeDeliveries.delivery(status: 'EN_ROUTE'),
        otp: '4821',
      );

      expect(deliveries.advances.single, (DeliveryStatus.enRoute, '4821'));
      expect(stateIn(container).delivery!.status, DeliveryStatus.delivered);
    });

    test('a refusal is surfaced and the job left alone', () async {
      final deliveries = FakeDeliveries()
        ..failAdvance = ApiException(ApiErrorKind.rejected, 'Wrong code.');
      final container = await containerWith(deliveries);

      await controllerIn(container).advance(
        FakeDeliveries.delivery(status: 'EN_ROUTE'),
        otp: '0000',
      );

      expect(stateIn(container).error!.message, 'Wrong code.');
      expect(stateIn(container).delivery, isNull,
          reason: 'nothing was delivered, so nothing should look delivered');
    });

    test('a second tap while one is in flight is ignored', () async {
      final deliveries = FakeDeliveries();
      final container = await containerWith(deliveries);
      final delivery = FakeDeliveries.delivery(status: 'ASSIGNED');

      await Future.wait([
        controllerIn(container).advance(delivery),
        controllerIn(container).advance(delivery),
      ]);

      expect(deliveries.advances.length, 1);
    });

    test('failing a run records the reason', () async {
      final deliveries = FakeDeliveries();
      final container = await containerWith(deliveries);

      await controllerIn(container).markFailed(
        FakeDeliveries.delivery(status: 'EN_ROUTE'),
        'Nobody at the address',
      );

      expect(deliveries.failures.single, 'Nobody at the address');
      expect(stateIn(container).delivery!.status, DeliveryStatus.failed);
    });
  });

  group('sharing a position', () {
    test('will not start without permission, and says which problem', () async {
      final deliveries = FakeDeliveries();
      final location =
          FakeLocation(availability: LocationAvailability.blocked);
      addTearDown(location.close);
      final container = await containerWith(deliveries, location: location);

      await controllerIn(container).startSharing();

      expect(stateIn(container).sharing, isFalse);
      // Each problem has a different remedy, so they are not collapsed into a
      // single "location unavailable".
      expect(stateIn(container).locationProblem, LocationAvailability.blocked);
      expect(deliveries.pings, isEmpty);
    });

    test('reports positions once started', () async {
      final deliveries = FakeDeliveries();
      final location = FakeLocation();
      addTearDown(location.close);
      final container = await containerWith(deliveries, location: location);

      await controllerIn(container).startSharing();
      location.emit(33.7167, 73.0417);
      await Future<void>.delayed(Duration.zero);

      expect(deliveries.pings.single, (33.7167, 73.0417));
      expect(stateIn(container).sharing, isTrue);
      expect(stateIn(container).pingsSent, 1);
    });

    test('throttles a fast bike down to something a map can use', () async {
      final deliveries = FakeDeliveries();
      final location = FakeLocation();
      addTearDown(location.close);
      final container = await containerWith(deliveries, location: location);

      await controllerIn(container).startSharing();
      location.emit(33.7167, 73.0417);
      await Future<void>.delayed(Duration.zero);
      location.emit(33.7170, 73.0420);
      await Future<void>.delayed(Duration.zero);

      // A battery has to last a shift; the customer's map does not need
      // sub-second updates.
      expect(deliveries.pings.length, 1);
    });

    test('a dropped ping is not queued, and does not block the next', () async {
      final deliveries = FakeDeliveries()
        ..failTrack = ApiException(ApiErrorKind.network, 'No signal.');
      final location = FakeLocation();
      addTearDown(location.close);
      final container = await containerWith(deliveries, location: location);

      await controllerIn(container).startSharing();
      location.emit(33.7167, 73.0417);
      await Future<void>.delayed(Duration.zero);

      deliveries.failTrack = null;
      location.emit(33.7180, 73.0430);
      await Future<void>.delayed(Duration.zero);

      // Replaying the stale fix would put the bike somewhere it has left; the
      // throttle must not have been armed by the failure either.
      expect(deliveries.pings.single, (33.7180, 73.0430));
    });

    test('finishing the run stops the sharing', () async {
      final deliveries = FakeDeliveries();
      final location = FakeLocation();
      addTearDown(location.close);
      final container = await containerWith(deliveries, location: location);
      final controller = controllerIn(container);

      await controller.startSharing();
      await controller.advance(FakeDeliveries.delivery(status: 'EN_ROUTE'),
          otp: '1234');

      location.emit(33.9, 73.9);
      await Future<void>.delayed(Duration.zero);

      // A rider's whereabouts is the restaurant's business while they carry an
      // order, and not a minute longer.
      expect(deliveries.pings, isEmpty);
    });

    test('turning it off stops it too', () async {
      final deliveries = FakeDeliveries();
      final location = FakeLocation();
      addTearDown(location.close);
      final container = await containerWith(deliveries, location: location);
      final controller = controllerIn(container);

      await controller.startSharing();
      controller.stopSharing();
      location.emit(33.9, 73.9);
      await Future<void>.delayed(Duration.zero);

      expect(stateIn(container).sharing, isFalse);
      expect(deliveries.pings, isEmpty);
    });
  });
}
