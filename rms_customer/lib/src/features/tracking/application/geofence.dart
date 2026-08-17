import 'package:flutter/foundation.dart';
import 'package:rms_core/rms_core.dart';

import '../data/route_service.dart';

/// How close counts as close.
///
/// Three rings rather than one, because "your food is nearby" means different
/// things at 1.5km and at the gate, and a customer acts on them differently: one
/// is "stop what you are doing", the next is "find your shoes", the last is "open
/// the door".
///
/// The distances are straight-line, deliberately. A road distance would be more
/// accurate and would also mean a routing request per fix to decide whether to
/// notify — and the failure mode of that is a notification that never fires
/// because the router was rate-limited. A geofence should not depend on a network
/// service.
///
/// Configurable because a dense Lahore neighbourhood and a Bahria Town phase are
/// not the same problem: 1.5km of Gulberg traffic is twenty minutes, and 1.5km of
/// empty ring road is three.
@immutable
class GeofenceRings {
  const GeofenceRings({
    this.nearbyM = 1500,
    this.almostThereM = 400,
    this.arrivedM = 80,
  });

  /// Minutes away.
  final double nearbyM;

  /// Streets away.
  final double almostThereM;

  /// Close enough that "arrived" is credible — roughly the length of a street,
  /// which is as accurate as consumer GPS gets between buildings.
  final double arrivedM;

  /// The innermost ring [metres] falls inside, or null if outside them all.
  DeliveryAlert? ringFor(double metres) {
    if (metres <= arrivedM) return DeliveryAlert.arrived;
    if (metres <= almostThereM) return DeliveryAlert.almostThere;
    if (metres <= nearbyM) return DeliveryAlert.nearby;
    return null;
  }
}

/// Which alerts a tracking snapshot has earned.
///
/// Returns the full set the journey has reached rather than only the newest, and
/// the dedupe ledger decides what has already been said. That ordering matters: a
/// customer who opens the app for the first time when the rider is already at the
/// gate should be told they are at the gate, not walked through three
/// notifications they have missed the point of.
///
/// Ordered outermost-first so that if several do fire together they arrive in the
/// sequence the journey took.
List<DeliveryAlert> alertsFor(
  DeliveryTracking tracking, {
  GeofenceRings rings = const GeofenceRings(),
}) {
  final earned = <DeliveryAlert>[];

  // Lifecycle first. These come from the delivery's own status and need no
  // geometry, so they work for a delivery whose rider has never reported a fix.
  switch (tracking.status) {
    case DeliveryStatus.assigned:
      earned.add(DeliveryAlert.assigned);
    case DeliveryStatus.pickedUp:
      earned
        ..add(DeliveryAlert.assigned)
        ..add(DeliveryAlert.pickedUp);
    case DeliveryStatus.enRoute:
      earned
        ..add(DeliveryAlert.assigned)
        ..add(DeliveryAlert.pickedUp)
        ..add(DeliveryAlert.onTheWay);
    case DeliveryStatus.delivered:
      earned.add(DeliveryAlert.completed);
    case DeliveryStatus.pending:
    case DeliveryStatus.failed:
    case DeliveryStatus.cancelled:
    case DeliveryStatus.unknown:
      break;
  }

  // Proximity, only while the rider is actually carrying it. A geofence crossing
  // on a delivered order is the rider riding home past the customer's street, and
  // "your food is nearby" half an hour after eating it is the kind of alert that
  // gets notifications switched off.
  final position = tracking.position;
  final destination = tracking.destination;
  final live = tracking.status == DeliveryStatus.pickedUp ||
      tracking.status == DeliveryStatus.enRoute;

  if (live && position != null && destination != null && !position.stale) {
    final metres = metresBetween(
      TrackedPlace(lat: position.lat, lng: position.lng),
      destination,
    );
    // Every ring crossed, not just the innermost: a customer who was not watching
    // still wants "nearby" in their history, and the ledger will have suppressed
    // any they already had.
    if (metres <= rings.nearbyM) earned.add(DeliveryAlert.nearby);
    if (metres <= rings.almostThereM) earned.add(DeliveryAlert.almostThere);
    if (metres <= rings.arrivedM) earned.add(DeliveryAlert.arrived);
  }

  return earned;
}

/// How far the rider still has to go, straight-line, or null if unknown.
double? remainingMetres(DeliveryTracking tracking) {
  final position = tracking.position;
  final destination = tracking.destination;
  if (position == null || destination == null) return null;
  return metresBetween(
    TrackedPlace(lat: position.lat, lng: position.lng),
    destination,
  );
}
