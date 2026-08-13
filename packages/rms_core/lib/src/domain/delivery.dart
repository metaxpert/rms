import 'package:flutter/material.dart';

import '../l10n/rms_localizations.dart';
import '../theme/app_theme.dart';

/// Delivery job lifecycle, mirroring `DeliveryStatus` in `restaurant.util.ts`.
///
/// Own-fleet flow: `PENDING → ASSIGNED → PICKED_UP → EN_ROUTE → DELIVERED`.
/// A job may FAIL from any live state, or be CANCELLED before pickup.
/// `DELIVERED` / `FAILED` / `CANCELLED` are terminal.
enum DeliveryStatus {
  pending('PENDING'),
  assigned('ASSIGNED'),
  pickedUp('PICKED_UP'),
  enRoute('EN_ROUTE'),
  delivered('DELIVERED'),
  failed('FAILED'),
  cancelled('CANCELLED'),
  unknown('UNKNOWN');

  const DeliveryStatus(this.wire);

  final String wire;

  static DeliveryStatus fromWire(String? value) {
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return DeliveryStatus.unknown;
  }

  bool get isTerminal =>
      this == DeliveryStatus.delivered ||
      this == DeliveryStatus.failed ||
      this == DeliveryStatus.cancelled;

  /// Still on a rider's list of things to do today.
  bool get isActive => !isTerminal && this != DeliveryStatus.unknown;

  String labelIn(RmsLocalizations text) => switch (this) {
        DeliveryStatus.pending => text.deliveryStatusPending,
        DeliveryStatus.assigned => text.deliveryStatusAssigned,
        DeliveryStatus.pickedUp => text.deliveryStatusPickedUp,
        DeliveryStatus.enRoute => text.deliveryStatusEnRoute,
        DeliveryStatus.delivered => text.deliveryStatusDelivered,
        DeliveryStatus.failed => text.deliveryStatusFailed,
        DeliveryStatus.cancelled => text.deliveryStatusCancelled,
        DeliveryStatus.unknown => text.deliveryStatusUnknown,
      };

  /// The single action a rider takes next, or null when nothing is expected.
  /// Drives the one big button on the run screen — riders act one-handed,
  /// often on a bike, so there must never be a choice of several.
  String? nextActionLabelIn(RmsLocalizations text) => switch (this) {
        DeliveryStatus.assigned => text.deliveryActionPickUp,
        DeliveryStatus.pickedUp => text.deliveryActionStart,
        DeliveryStatus.enRoute => text.deliveryActionDeliver,
        _ => null,
      };

  /// Endpoint segment for [nextActionLabel].
  String? get nextActionPath => switch (this) {
        DeliveryStatus.assigned => 'pickup',
        DeliveryStatus.pickedUp => 'enroute',
        DeliveryStatus.enRoute => 'complete',
        _ => null,
      };

  Color get color => switch (this) {
        DeliveryStatus.pending => AppStatusColors.settled,
        DeliveryStatus.assigned => AppStatusColors.ordering,
        DeliveryStatus.pickedUp => AppStatusColors.preparing,
        DeliveryStatus.enRoute => AppStatusColors.ready,
        DeliveryStatus.delivered => AppStatusColors.available,
        DeliveryStatus.failed => AppStatusColors.cancelled,
        DeliveryStatus.cancelled => AppStatusColors.cancelled,
        DeliveryStatus.unknown => AppStatusColors.settled,
      };

  IconData get icon => switch (this) {
        DeliveryStatus.pending => Icons.inbox_outlined,
        DeliveryStatus.assigned => Icons.assignment_ind_outlined,
        DeliveryStatus.pickedUp => Icons.shopping_bag_outlined,
        DeliveryStatus.enRoute => Icons.two_wheeler_outlined,
        DeliveryStatus.delivered => Icons.check_circle_outline,
        DeliveryStatus.failed => Icons.error_outline,
        DeliveryStatus.cancelled => Icons.cancel_outlined,
        DeliveryStatus.unknown => Icons.help_outline,
      };
}

@immutable
class GeoPoint {
  const GeoPoint({required this.lat, required this.lng});

  final double lat;
  final double lng;

  static GeoPoint? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return GeoPoint(lat: lat, lng: lng);
  }
}

/// Who the rider is delivering to.
///
/// The name to ask for at the door and the number to ring from the gate — the
/// two things that turn an address into a completed drop. Deliberately does not
/// carry the OTP: the customer says that aloud, and a rider who could read it
/// could complete a delivery without ever arriving.
@immutable
class DeliveryCustomer {
  const DeliveryCustomer({this.name, this.phone});

  final String? name;
  final String? phone;

  bool get isEmpty => (name?.isEmpty ?? true) && (phone?.isEmpty ?? true);

  static DeliveryCustomer? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final customer = DeliveryCustomer(
      name: (json['name'] as String?)?.trim(),
      phone: (json['phone'] as String?)?.trim(),
    );
    return customer.isEmpty ? null : customer;
  }
}

/// A delivery job. Shape verified against `delivery.service.ts`.
///
/// Note there is no `otp` field: the backend returns the code ONLY at creation,
/// so staff can pass it to the customer. The rider must ask the customer for it
/// at the door — which is the point of the check, and why the driver app must
/// never display or cache it.
@immutable
class Delivery {
  const Delivery({
    required this.id,
    required this.deliveryNo,
    required this.orderId,
    required this.orderNo,
    required this.provider,
    required this.status,
    this.branchId,
    this.driverEmployeeId,
    this.driverId,
    this.customerId,
    this.customer,
    this.address,
    this.location,
    this.etaMinutes,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
  });

  final String id;
  final String deliveryNo;
  final String orderId;
  final String orderNo;

  /// `OWN` for own-fleet; anything else is an aggregator, where the rider app
  /// is not the actor and the job is read-only.
  final String provider;
  final DeliveryStatus status;
  final String? branchId;
  final String? driverEmployeeId;

  /// The rider on the roster, as opposed to [driverEmployeeId], which is the HR
  /// record they may not have — a contractor rider has the former and not the
  /// latter.
  final String? driverId;
  final String? customerId;

  /// Present on the rider's own board; absent on a dispatcher's list.
  final DeliveryCustomer? customer;
  final String? address;
  final GeoPoint? location;
  final int? etaMinutes;
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;

  bool get isOwnFleet => provider == 'OWN';

  /// Only own-fleet jobs are driven from this app; an aggregator's rider is
  /// tracked through their platform, so offering buttons would be a lie.
  bool get isActionable => isOwnFleet && status.nextActionPath != null;

  factory Delivery.fromJson(Map<String, dynamic> json) => Delivery(
        id: json['id'] as String,
        deliveryNo: (json['deliveryNo'] as String?) ?? '',
        orderId: (json['orderId'] as String?) ?? '',
        orderNo: (json['orderNo'] as String?) ?? '',
        provider: (json['provider'] as String?) ?? 'OWN',
        status: DeliveryStatus.fromWire(json['status'] as String?),
        branchId: json['branchId'] as String?,
        driverEmployeeId: json['driverEmployeeId'] as String?,
        driverId: json['driverId'] as String?,
        customer: DeliveryCustomer.fromJson(json['customer'] as Map<String, dynamic>?),
        customerId: json['customerId'] as String?,
        address: json['address'] as String?,
        location: GeoPoint.fromJson(json['location'] as Map<String, dynamic>?),
        etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
        assignedAt: _date(json['assignedAt']),
        pickedUpAt: _date(json['pickedUpAt']),
        deliveredAt: _date(json['deliveredAt']),
      );

  /// Timestamps arrive as ISO strings. Parsed to local time for display —
  /// a rider reads "picked up 14:05" against the clock on the wall, not UTC.
  static DateTime? _date(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  @override
  bool operator ==(Object other) => other is Delivery && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
