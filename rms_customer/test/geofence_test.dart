import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_customer/src/features/tracking/application/geofence.dart';

/// When a customer is worth interrupting, and — mostly — when they are not.
void main() {
  // A house in F-11/3, Islamabad.
  const home = TrackedPlace(lat: 33.6844, lng: 73.0479, label: 'House 212-B');

  /// A rider [metres] north of the house, give or take.
  ///
  /// One degree of latitude is about 111.32km anywhere on earth, which makes north
  /// the one direction where a distance can be faked without trigonometry.
  TrackedPosition riderNorthOf(double metres, {bool stale = false}) =>
      TrackedPosition(
        lat: home.lat + metres / 111320,
        lng: home.lng,
        at: DateTime.now(),
        stale: stale,
      );

  DeliveryTracking tracking({
    required DeliveryStatus status,
    TrackedPosition? position,
    TrackedPlace? destination = home,
  }) =>
      DeliveryTracking(
        deliveryId: 'd-1',
        status: status,
        destination: destination,
        position: position,
      );

  group('the rings', () {
    const rings = GeofenceRings();

    test('name the innermost ring a distance falls inside', () {
      expect(rings.ringFor(40), DeliveryAlert.arrived);
      expect(rings.ringFor(300), DeliveryAlert.almostThere);
      expect(rings.ringFor(1200), DeliveryAlert.nearby);
      expect(rings.ringFor(4000), isNull);
    });

    test('are configurable, because a Gulberg kilometre is not a ring-road one', () {
      const tight = GeofenceRings(nearbyM: 400, almostThereM: 150, arrivedM: 30);
      expect(tight.ringFor(300), DeliveryAlert.nearby);
      expect(tight.ringFor(1200), isNull);
    });
  });

  group('what a snapshot has earned', () {
    test('a job just assigned earns only that', () {
      final earned = alertsFor(tracking(status: DeliveryStatus.assigned));
      expect(earned, [DeliveryAlert.assigned]);
    });

    test('the lifecycle accumulates, so a late arrival still gets the story', () {
      // A customer who opens the app for the first time when the food is already on
      // the way should not be walked through three notifications — but the ledger
      // decides that, not this. Here every stage reached is reported.
      final earned = alertsFor(tracking(status: DeliveryStatus.enRoute));
      expect(earned, [
        DeliveryAlert.assigned,
        DeliveryAlert.pickedUp,
        DeliveryAlert.onTheWay,
      ]);
    });

    test('works with no position at all', () {
      // A rider who has not started sharing still produces lifecycle alerts. This
      // is the case that would crash a version of this that assumed geometry.
      final earned = alertsFor(tracking(status: DeliveryStatus.pickedUp));
      expect(earned, contains(DeliveryAlert.pickedUp));
    });

    test('crossing a ring adds it, outermost first', () {
      final earned = alertsFor(tracking(
        status: DeliveryStatus.enRoute,
        position: riderNorthOf(300),
      ));
      // Both rings crossed, in journey order.
      expect(earned.sublist(earned.length - 2), [
        DeliveryAlert.nearby,
        DeliveryAlert.almostThere,
      ]);
    });

    test('at the door, all three', () {
      final earned = alertsFor(tracking(
        status: DeliveryStatus.enRoute,
        position: riderNorthOf(30),
      ));
      expect(earned, contains(DeliveryAlert.arrived));
      expect(earned, contains(DeliveryAlert.almostThere));
      expect(earned, contains(DeliveryAlert.nearby));
    });

    test('a rider still miles out crosses nothing', () {
      final earned = alertsFor(tracking(
        status: DeliveryStatus.enRoute,
        position: riderNorthOf(6000),
      ));
      expect(earned, isNot(contains(DeliveryAlert.nearby)));
    });

    test('a stale position never triggers a ring', () {
      // The marker is frozen; where it was frozen is not where the rider is, and
      // "your rider is at your door" on a four-minute-old fix is a lie that sends
      // somebody outside.
      final earned = alertsFor(tracking(
        status: DeliveryStatus.enRoute,
        position: riderNorthOf(30, stale: true),
      ));
      expect(earned, isNot(contains(DeliveryAlert.arrived)));
      expect(earned, isNot(contains(DeliveryAlert.nearby)));
    });

    test('a delivered order does not announce proximity', () {
      // The rider riding home past the customer's street half an hour later is not
      // news, and "your food is nearby" after it was eaten is how notifications get
      // switched off.
      final earned = alertsFor(tracking(
        status: DeliveryStatus.delivered,
        position: riderNorthOf(30),
      ));
      expect(earned, [DeliveryAlert.completed]);
    });

    test('a cancelled job says nothing at all', () {
      expect(alertsFor(tracking(status: DeliveryStatus.cancelled)), isEmpty);
      expect(alertsFor(tracking(status: DeliveryStatus.failed)), isEmpty);
    });

    test('no destination means no proximity, and no crash', () {
      // A delivery dispatched without coordinates — the address was typed as prose.
      final earned = alertsFor(tracking(
        status: DeliveryStatus.enRoute,
        position: riderNorthOf(30),
        destination: null,
      ));
      expect(earned, isNot(contains(DeliveryAlert.arrived)));
    });
  });

  group('remaining distance', () {
    test('measures rider to door', () {
      final metres = remainingMetres(tracking(
        status: DeliveryStatus.enRoute,
        position: riderNorthOf(500),
      ));
      expect(metres, isNotNull);
      expect(metres!, closeTo(500, 10));
    });

    test('is unknown without both ends', () {
      expect(remainingMetres(tracking(status: DeliveryStatus.enRoute)), isNull);
      expect(
        remainingMetres(tracking(
          status: DeliveryStatus.enRoute,
          position: riderNorthOf(500),
          destination: null,
        )),
        isNull,
      );
    });
  });
}
