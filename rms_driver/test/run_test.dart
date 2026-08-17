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

  /// Let a multi-step async chain finish.
  ///
  /// `Duration.zero` drains one microtask hop, which is enough for a single send
  /// but not for a queue flush: appending, reading back through the store and then
  /// posting each fix is several hops deep.
  Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('sharing a position', () {
    test('will not start without permission, and says which problem', () async {
      final deliveries = FakeDeliveries();
      final location = FakeLocation(availability: LocationAvailability.blocked);
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

    test('a dropped ping is queued and sent when the signal returns', () async {
      // This test asserted the opposite until live tracking was built, and the
      // reasoning it carried was half right: replaying a stale fix as if it were
      // current WOULD put the bike somewhere it has left. What it missed is that
      // dropping the fix loses the shape of the journey, which is not recoverable
      // — a rider crossing a six-minute dead spot left a trail that jumped from
      // the restaurant to the customer's street in a straight line through
      // buildings.
      //
      // The resolution is not to choose between them: every fix now carries the
      // timestamp the phone took it at, and the server orders the trail by that
      // column. A replayed fix is therefore filed as history rather than mistaken
      // for the present, so it can be both kept and honest.
      final deliveries = FakeDeliveries()
        ..failTrack = ApiException(ApiErrorKind.network, 'No signal.');
      final location = FakeLocation();
      addTearDown(location.close);
      final container = await containerWith(deliveries, location: location);
      final controller = controllerIn(container);

      // The dropped fix is taken 90 seconds ago and the recovery fix now — which
      // is the real shape of a dead spot, and keeps both inside the validator's
      // clock-skew bound. (Dating the second one into the future instead is
      // refused as bad skew, correctly.)
      final now = DateTime.now();
      final t0 = now.subtract(const Duration(seconds: 90));
      await controller.startSharing();
      location.emit(33.7167, 73.0417, at: t0);
      await Future<void>.delayed(Duration.zero);

      // Nothing landed, and the rider can see that it is being held rather than
      // thrown away.
      expect(deliveries.pings, isEmpty);
      expect(stateIn(container).queuedFixes, 1);

      deliveries.failTrack = null;
      // Far enough past the first fix to clear the cadence throttle, which is
      // measured between fix timestamps rather than on the wall clock.
      location.emit(33.7180, 73.0430, at: now);
      // A queue flush is a longer async chain than a single send — append, read
      // back, then one request per fix — so one microtask drain is not enough to
      // settle it.
      await settle();

      // Both fixes, oldest first: a trail is only a trail in the order it
      // happened.
      expect(deliveries.pings, [(33.7167, 73.0417), (33.7180, 73.0430)]);
      expect(stateIn(container).queuedFixes, 0);
    });

    test('a fix the server would refuse is never sent', () async {
      // The server validates too and remains the authority. This copy of the
      // rules is what stops the request being made at all, which is mobile data
      // the rider is paying for and battery on a phone that must last a shift.
      final deliveries = FakeDeliveries();
      final location = FakeLocation();
      addTearDown(location.close);
      final container = await containerWith(deliveries, location: location);

      await controllerIn(container).startSharing();
      // A 2km-radius cell-tower guess is not a position.
      location.emit(33.7167, 73.0417, accuracyM: 2000);
      await Future<void>.delayed(Duration.zero);

      expect(deliveries.pings, isEmpty);
      expect(stateIn(container).queuedFixes, 0);
    });

    test('the phone works harder once the bag is on the bike', () async {
      // Continuous high-accuracy GPS is close to the most expensive thing an app
      // can do to a battery, so the cadence follows the job: a bag still on the
      // pass does not need the fidelity a bike in traffic does.
      final deliveries = FakeDeliveries();
      final location = FakeLocation();
      addTearDown(location.close);
      final container = await containerWith(deliveries, location: location);
      final controller = controllerIn(container);

      await controller.startSharing();
      expect(location.cadences.last, TrackingCadence.idle);

      await controller.advance(FakeDeliveries.delivery(status: 'ASSIGNED'));
      expect(location.cadences.last, TrackingCadence.active);
    });

    test('the background grant is asked for after the foreground one',
        () async {
      // Android 11+ refuses to show both prompts at once and iOS only escalates
      // to "Always" after "When in Use" — so asking in the wrong order is a
      // silent no on both platforms.
      final deliveries = FakeDeliveries();
      final location =
          FakeLocation(background: LocationAvailability.foregroundOnly);
      addTearDown(location.close);
      final container = await containerWith(deliveries, location: location);

      await controllerIn(container).startSharing();

      expect(location.ensureCalls, 1);
      expect(location.backgroundCalls, 1);
      // Tracking still works with the app open, so this is reported rather than
      // treated as a failure — but it is reported, because a customer watching a
      // marker that freezes when the rider pockets the phone deserves better.
      expect(stateIn(container).sharing, isTrue);
      expect(stateIn(container).foregroundOnly, isTrue);
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
