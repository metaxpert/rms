import 'package:flutter/foundation.dart';

/// The restaurant events the backend actually bridges to sockets.
///
/// This is the complete list from the gateway's `BRIDGED_TYPES` (see
/// ARCHITECTURE.md §4) — not every event the backend emits. Notably
/// `RESTAURANT_ORDER_VOIDED` is defined server-side but **not** bridged, so a
/// void performed on another till never arrives here. Nothing in the app may
/// therefore treat "no event" as "nothing changed"; the socket accelerates
/// refreshes, it does not replace them.
enum RestaurantEventType {
  orderPlaced('restaurant.order_placed.v1'),
  orderConfirmed('restaurant.order_confirmed.v1'),
  kdsTicketReady('restaurant.kds_ticket_ready.v1'),
  orderServed('restaurant.order_served.v1'),
  billSettled('restaurant.bill_settled.v1'),
  deliveryAssigned('restaurant.delivery_assigned.v1'),
  deliveryCompleted('restaurant.delivery_completed.v1'),
  reservationCreated('restaurant.reservation_created.v1'),

  /// A type this build does not know. Deliberately still delivered: a newer
  /// backend adding an event should make the app refresh, not ignore it.
  unknown('');

  const RestaurantEventType(this.wire);

  final String wire;

  static RestaurantEventType fromWire(String? value) {
    for (final type in values) {
      if (type != RestaurantEventType.unknown && type.wire == value) return type;
    }
    return RestaurantEventType.unknown;
  }

  /// Whether this changes something a waiter is looking at — the floor, a
  /// table's order, or a bill.
  bool get touchesOrders => switch (this) {
        RestaurantEventType.orderPlaced ||
        RestaurantEventType.orderConfirmed ||
        RestaurantEventType.kdsTicketReady ||
        RestaurantEventType.orderServed ||
        RestaurantEventType.billSettled =>
          true,
        // An unknown type is assumed relevant. Refetching needlessly costs one
        // request; ignoring a real change leaves stale food on a screen.
        RestaurantEventType.unknown => true,
        _ => false,
      };

  /// The kitchen→waiter signal: food is up and someone must run it.
  bool get isFoodReady => this == RestaurantEventType.kdsTicketReady;
}

/// One message off the gateway's single `event` channel.
///
/// The backend does not use one Socket.IO event name per domain event — every
/// domain event arrives on the channel literally named `event`, shaped
/// `{ type, payload }`.
@immutable
class RealtimeEvent {
  const RealtimeEvent({required this.type, required this.payload});

  /// The raw wire type, kept verbatim so an unrecognised event can still be
  /// logged and diagnosed rather than disappearing into [RestaurantEventType.unknown].
  final String type;
  final Map<String, dynamic> payload;

  RestaurantEventType get kind => RestaurantEventType.fromWire(type);

  /// Payload keys are **not verified** — the bridge's shape was not inspected.
  /// Everything below is therefore a best-effort narrowing used only to skip
  /// refreshes that provably do not concern us; when a key is missing the app
  /// falls back to refreshing, which is always correct.
  String? get orderId => _string(const ['orderId', 'order_id', 'id']);
  String? get branchId => _string(const ['branchId', 'branch_id']);
  String? get tableCode => _string(const ['table', 'tableCode', 'table_code']);

  String? _string(List<String> keys) {
    for (final key in keys) {
      final value = payload[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  /// True when this event cannot possibly concern [branch].
  ///
  /// Note the double negative: the socket room is tenant-scoped, not
  /// branch-scoped, so a multi-outlet tenant delivers every branch's events to
  /// every tablet. Only a payload that names a DIFFERENT branch is filtered —
  /// an absent `branchId` is never treated as "not mine".
  bool isForeignTo(String? branch) {
    if (branch == null) return false;
    final own = branchId;
    return own != null && own != branch;
  }

  /// Parse one gateway message. Returns null for anything that is not the
  /// documented `{type, payload}` envelope.
  static RealtimeEvent? tryParse(dynamic message) {
    if (message is! Map) return null;
    final type = message['type'];
    if (type is! String || type.isEmpty) return null;
    final payload = message['payload'];
    return RealtimeEvent(
      type: type,
      payload: payload is Map
          ? payload.map((key, value) => MapEntry('$key', value))
          : const {},
    );
  }

  @override
  String toString() => 'RealtimeEvent($type)';
}
