import 'package:flutter/foundation.dart';

import '../money.dart';
import 'order_status.dart';

/// A whole order as the SERVER holds it — `GET /restaurant/orders/:id`.
///
/// This is the authority. [TicketDraft] predicts what an order will cost; this
/// is what it does cost, priced by the backend against the branch's own prices
/// at the moment the line was added. Where the two disagree, this wins and the
/// draft was wrong.
///
/// Fields verified against the running API (they are what the shipped app read):
/// `id`, `orderNo`, `status`, `channel`, `table`, `guestCount`,
/// `totals.{subtotal,tax,total}`, `items[].{id,name,qty,unitPrice,lineTotal}`.
/// Everything else below is parsed defensively and defaults to absent, so a
/// payload without it renders correctly rather than throwing mid-service.

/// One line of a server-held order.
@immutable
class OrderLine {
  const OrderLine({
    required this.id,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
    this.itemId,
    this.modifierNames = const [],
    this.kitchenNotes,
    this.course,
  });

  /// The ORDER LINE's id, not the menu item's — this is what
  /// `DELETE /restaurant/orders/:id/items/:lineId` takes.
  final String id;

  final String name;
  final int qty;

  /// Price of one unit as the server snapshotted it when the line was added.
  /// A menu price changed since then does not retroactively move a bill.
  final Money unitPrice;

  /// The server's `line_total_minor` — item + modifiers, times qty, plus tax.
  final Money lineTotal;

  final String? itemId;
  final List<String> modifierNames;
  final String? kitchenNotes;
  final int? course;

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
        id: (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? 'Item',
        qty: (json['qty'] as num?)?.toInt() ?? 0,
        unitPrice: _money(json['unitPrice']),
        lineTotal: _money(json['lineTotal']),
        itemId: json['itemId'] as String?,
        modifierNames: _modifierNames(json['modifiers']),
        kitchenNotes: json['kitchenNotes'] as String?,
        course: (json['course'] as num?)?.toInt(),
      );

  /// Modifiers may come back as objects or as bare names depending on the
  /// endpoint; a waiter needs to read "no chilli" either way.
  static List<String> _modifierNames(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((entry) => switch (entry) {
              String name => name,
              Map map => map['name'] as String?,
              _ => null,
            })
        .whereType<String>()
        .toList(growable: false);
  }
}

/// The money summary the server computed, in the order a bill prints.
@immutable
class OrderTotals {
  const OrderTotals({
    required this.subtotal,
    required this.tax,
    required this.serviceCharge,
    required this.discount,
    required this.tip,
    required this.rounding,
    required this.total,
  });

  final Money subtotal;
  final Money tax;
  final Money serviceCharge;
  final Money discount;
  final Money tip;
  final Money rounding;
  final Money total;

  static const empty = OrderTotals(
    subtotal: Money.zero,
    tax: Money.zero,
    serviceCharge: Money.zero,
    discount: Money.zero,
    tip: Money.zero,
    rounding: Money.zero,
    total: Money.zero,
  );

  factory OrderTotals.fromJson(Map<String, dynamic> json) => OrderTotals(
        subtotal: _money(json['subtotal']),
        tax: _money(json['tax']),
        serviceCharge: _money(json['serviceCharge']),
        discount: _money(json['discount']),
        tip: _money(json['tip']),
        rounding: _money(json['rounding']),
        total: _money(json['total']),
      );
}

@immutable
class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.orderNo,
    required this.status,
    required this.channel,
    required this.guestCount,
    required this.totals,
    required this.lines,
    this.branchId,
    this.tableId,
    this.tableCode,
    this.placedAt,
  });

  final String id;

  /// Human reference printed on the ticket — "ORD-000004". What a waiter reads
  /// out to the kitchen when something is wrong with an order.
  final String orderNo;
  final OrderStatus status;

  /// `DINE_IN`, `TAKEAWAY`, `DELIVERY`.
  final String channel;
  final int guestCount;
  final OrderTotals totals;
  final List<OrderLine> lines;

  final String? branchId;
  final String? tableId;
  final String? tableCode;
  final DateTime? placedAt;

  int get itemCount => lines.fold(0, (sum, l) => sum + l.qty);

  bool get isDineIn => channel == 'DINE_IN';

  /// Still occupying a table and owing money.
  bool get isOpen => status.isOpen;

  /// Nothing has reached the kitchen yet: the order exists server-side but has
  /// not been placed.
  bool get isUnplaced => status == OrderStatus.draft;

  /// Whether another round may be added.
  ///
  /// Anything still open takes items — a table that has been served can still
  /// order coffee. A settled, cancelled or voided bill cannot, and offering it
  /// would only produce a 422 the waiter has to interpret.
  bool get canAddItems => isOpen;

  bool get canPlace => status == OrderStatus.draft;

  /// `confirm` is only legal out of PLACED. On a tenant with
  /// `autoFireKitchen`, `place` lands the order straight in CONFIRMED and this
  /// is never true — which is why the send flow treats "already confirmed" as
  /// success rather than an error.
  bool get canConfirm => status == OrderStatus.placed;

  /// The kitchen has it and is cooking, or has finished.
  bool get isWithKitchen => switch (status) {
        OrderStatus.confirmed ||
        OrderStatus.preparing ||
        OrderStatus.ready =>
          true,
        _ => false,
      };

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'];
    return OrderDetail(
      id: json['id'] as String,
      orderNo: (json['orderNo'] as String?) ?? '',
      status: OrderStatus.fromWire(json['status'] as String?),
      channel: (json['channel'] as String?) ?? 'DINE_IN',
      guestCount: (json['guestCount'] as num?)?.toInt() ?? 0,
      totals: totals is Map<String, dynamic>
          ? OrderTotals.fromJson(totals)
          : OrderTotals.empty,
      lines: ((json['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OrderLine.fromJson)
          .toList(growable: false),
      branchId: json['branchId'] as String?,
      tableId: json['tableId'] as String?,
      // The list endpoint sends the table CODE under `table`; the detail
      // endpoint does the same, with `tableId` alongside it when present.
      tableCode: json['table'] as String?,
      placedAt: _time(json['placedAt']),
    );
  }

  static DateTime? _time(dynamic raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  @override
  bool operator ==(Object other) => other is OrderDetail && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// `{amountMinor, currency}`, or zero when the field is absent.
///
/// A missing amount is zero rather than a throw: an order screen that crashes
/// because the server omitted `tip` is worse than one that shows no tip.
Money _money(dynamic raw) {
  if (raw is! Map) return Money.zero;
  return Money(
    (raw['amountMinor'] as num?)?.toInt() ?? 0,
    (raw['currency'] as String?) ?? 'PKR',
  );
}
