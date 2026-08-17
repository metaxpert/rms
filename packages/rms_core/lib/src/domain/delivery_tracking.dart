import 'package:flutter/foundation.dart';

import 'delivery.dart';

/// A rider's position, with everything needed to decide whether to believe it.
///
/// `at` and `stale` are not decoration. A position with no age cannot be told
/// apart from one that stopped updating twenty minutes ago, and "the marker is
/// frozen" is the single most important thing a live map has to be able to say —
/// a confident dot on a road the bike left is worse than an honest "last seen a
/// few minutes ago".
///
/// `stale` is computed by the **server**, against its own clock, and carried here
/// rather than re-derived. A phone drawing the map may have a worse clock than the
/// phone that produced the fix, and two screens disagreeing about whether the same
/// rider is stale is a bug nobody can reproduce.
@immutable
class TrackedPosition {
  const TrackedPosition({
    required this.lat,
    required this.lng,
    this.at,
    this.ageSeconds,
    this.stale = false,
    this.speedKph,
    this.headingDeg,
  });

  final double lat;
  final double lng;

  /// When the phone took the fix. Not when the server received it.
  final DateTime? at;

  final int? ageSeconds;

  /// The server's judgement that this is no longer where the rider is.
  final bool stale;

  final double? speedKph;

  /// Compass bearing the bike is facing, 0 = north. Null while stationary, or on
  /// a platform that did not report one.
  final double? headingDeg;

  static TrackedPosition? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    // A payload that is out of range is not drawn at all: `0,0` on a map is the
    // Gulf of Guinea, and a rider apparently in the Atlantic is worse than a
    // screen that admits it has no position.
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return TrackedPosition(
      lat: lat,
      lng: lng,
      at: DateTime.tryParse('${json['at']}')?.toLocal(),
      ageSeconds: (json['ageSeconds'] as num?)?.toInt(),
      stale: json['stale'] == true,
      speedKph: (json['speedKph'] as num?)?.toDouble(),
      headingDeg: (json['headingDeg'] as num?)?.toDouble(),
    );
  }

  TrackedPosition copyWith({
    double? lat,
    double? lng,
    DateTime? at,
    int? ageSeconds,
    bool? stale,
    double? speedKph,
    double? headingDeg,
  }) =>
      TrackedPosition(
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        at: at ?? this.at,
        ageSeconds: ageSeconds ?? this.ageSeconds,
        stale: stale ?? this.stale,
        speedKph: speedKph ?? this.speedKph,
        headingDeg: headingDeg ?? this.headingDeg,
      );
}

/// A named place on the map — where the food came from, or where it is going.
@immutable
class TrackedPlace {
  const TrackedPlace({required this.lat, required this.lng, this.label});

  final double lat;
  final double lng;

  /// The address a customer typed, or the outlet's name.
  final String? label;

  static TrackedPlace? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return TrackedPlace(lat: lat, lng: lng, label: json['address'] as String?);
  }
}

/// The outlet an order came from. A name and a street, never a pin.
@immutable
class TrackedOutlet {
  const TrackedOutlet({this.name, this.address});

  final String? name;
  final String? address;

  static TrackedOutlet? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final name = (json['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    return TrackedOutlet(name: name, address: (json['address'] as String?)?.trim());
  }
}

/// Who is carrying the order.
@immutable
class TrackedDriver {
  const TrackedDriver({this.name, this.phone, this.vehicleType});

  final String? name;
  final String? phone;
  final String? vehicleType;

  static TrackedDriver? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final driver = TrackedDriver(
      name: (json['name'] as String?)?.trim(),
      phone: (json['phone'] as String?)?.trim(),
      vehicleType: json['vehicleType'] as String?,
    );
    return (driver.name?.isEmpty ?? true) && (driver.phone?.isEmpty ?? true)
        ? null
        : driver;
  }
}

/// Everything a live map needs for one delivery, from one read.
///
/// Fetched whole rather than assembled from the delivery view plus the trail:
/// two reads at two moments render the rider and the destination from different
/// instants, and the visible artefact of that is a marker that appears to
/// overshoot the house.
///
/// [position] is null until the rider's app has sent its first fix. That is a
/// real and common state — a job assigned but not yet collected — and a map must
/// draw "not reporting yet" rather than a marker at nowhere.
@immutable
class DeliveryTracking {
  const DeliveryTracking({
    required this.deliveryId,
    required this.status,
    this.deliveryNo,
    this.orderId,
    this.etaMinutes,
    this.destination,
    this.origin,
    this.driver,
    this.position,
    this.serverTime,
  });

  final String deliveryId;
  final DeliveryStatus status;
  final String? deliveryNo;
  final String? orderId;

  /// The restaurant's own estimate, set at dispatch. Independent of the
  /// route-based ETA the map computes from the rider's current position; where
  /// both exist the live one is the better answer, and this is the fallback.
  final int? etaMinutes;

  final TrackedPlace? destination;

  /// Where the food came from, by name and street.
  ///
  /// No coordinates, because the schema has none: the `branch` table carries name,
  /// code, address, city and phone and no geometry. So the outlet is named on the
  /// screen rather than pinned on the map — inferring its position from the
  /// delivery's earliest fix would put the restaurant wherever the rider happened
  /// to switch sharing on.
  final TrackedOutlet? origin;
  final TrackedDriver? driver;
  final TrackedPosition? position;

  /// The server's clock at the moment of the read, so a client with a skewed
  /// clock can still age a position correctly.
  final DateTime? serverTime;

  bool get isFinished => status.isTerminal;

  /// Whether there is anything to draw a rider with.
  bool get hasPosition => position != null;

  factory DeliveryTracking.fromJson(Map<String, dynamic> json) =>
      DeliveryTracking(
        deliveryId: (json['deliveryId'] ?? json['id']) as String,
        status: DeliveryStatus.fromWire(json['status'] as String?),
        deliveryNo: json['deliveryNo'] as String?,
        orderId: json['orderId'] as String?,
        etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
        destination:
            TrackedPlace.fromJson(json['destination'] as Map<String, dynamic>?),
        origin: TrackedOutlet.fromJson(json['origin'] as Map<String, dynamic>?),
        driver: TrackedDriver.fromJson(json['driver'] as Map<String, dynamic>?),
        position:
            TrackedPosition.fromJson(json['location'] as Map<String, dynamic>?),
        serverTime: DateTime.tryParse('${json['serverTime']}')?.toLocal(),
      );

  /// Fold a realtime position into a snapshot.
  ///
  /// The socket carries positions only — never the destination or the status — so
  /// an event updates one field and leaves the rest of the snapshot standing.
  /// Anything that changes a delivery's *status* arrives as its own event and is
  /// answered with a refetch, because a position event is not evidence about it.
  ///
  /// An event older than what is already drawn is ignored. Out-of-order delivery
  /// is normal after a reconnect, and letting an older fix win would drag the
  /// marker backwards down the road.
  DeliveryTracking withPosition(TrackedPosition next) {
    final current = position;
    if (current?.at != null && next.at != null && !next.at!.isAfter(current!.at!)) {
      return this;
    }
    return DeliveryTracking(
      deliveryId: deliveryId,
      status: status,
      deliveryNo: deliveryNo,
      orderId: orderId,
      etaMinutes: etaMinutes,
      destination: destination,
      origin: origin,
      driver: driver,
      position: next,
      serverTime: serverTime,
    );
  }
}
