import 'package:flutter/foundation.dart';

import '../money.dart';
import 'order_status.dart';

/// A row from `GET /restaurant/orders`.
///
/// Note what this does NOT carry: `placedAt` exists only on the order *detail*,
/// so the floor cannot show "seated 25 min ago" without one request per table.
/// Elapsed time is optional in the brief (§7) and is deliberately omitted
/// rather than paid for with N round trips during service.
@immutable
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.orderNo,
    required this.branchId,
    required this.channel,
    required this.status,
    required this.guestCount,
    required this.itemCount,
    required this.total,
    this.tableCode,
  });

  final String id;

  /// Human reference printed on the ticket — "ORD-000004".
  final String orderNo;
  final String branchId;

  /// `DINE_IN`, `TAKEAWAY`, `DELIVERY`.
  final String channel;
  final OrderStatus status;
  final int guestCount;
  final int itemCount;
  final Money total;

  /// The list endpoint sends the table CODE ("D1"), not an id — the detail
  /// endpoint is where `tableId` lives. Joining by code is therefore only safe
  /// within one branch, which is how the floor screen scopes it.
  final String? tableCode;

  bool get isDineIn => channel == 'DINE_IN';

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    final total = json['total'];
    return OrderSummary(
      id: json['id'] as String,
      orderNo: (json['orderNo'] as String?) ?? '',
      branchId: (json['branchId'] as String?) ?? '',
      channel: (json['channel'] as String?) ?? 'DINE_IN',
      status: OrderStatus.fromWire(json['status'] as String?),
      guestCount: (json['guestCount'] as num?)?.toInt() ?? 0,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      total: total is Map<String, dynamic>
          ? Money(
              (total['amountMinor'] as num?)?.toInt() ?? 0,
              (total['currency'] as String?) ?? 'PKR',
            )
          : Money.zero,
      tableCode: json['table'] as String?,
    );
  }

  @override
  bool operator ==(Object other) => other is OrderSummary && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
