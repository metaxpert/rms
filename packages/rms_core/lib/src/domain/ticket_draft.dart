import 'package:flutter/foundation.dart';

import '../money.dart';
import 'menu.dart';
import 'restaurant_config.dart';

/// A ticket being built on the device, before any of it reaches the server.
///
/// The waiter app holds the draft locally so that adding a dish is instant and
/// survives a dropped connection — a waiter at a table cannot wait for a round
/// trip per tap, and a wifi blackspot in the far corner of a dining room must
/// not cost an order.
///
/// **The prices here are a faithful prediction, never the authority.** The
/// backend re-prices every line when the order is submitted (`addItems` reads
/// the item's current branch price and snapshots it). This model exists to make
/// the prediction match to the paisa, because a waiter who is quoted one total
/// and hands over a bill showing another stops trusting the app. All arithmetic
/// below mirrors `computeMenuLine` and `recomputeTotals` in the ERP's
/// `restaurant.util.ts` / `order.service.ts`.

/// A chosen modifier, snapshotted so the draft renders without the catalogue.
@immutable
class DraftModifier {
  const DraftModifier({
    required this.modifierId,
    required this.name,
    required this.priceDelta,
    this.qty = 1,
  });

  final String modifierId;
  final String name;

  /// Per unit of the parent line.
  final Money priceDelta;
  final int qty;

  Money get total => priceDelta * qty;

  factory DraftModifier.from(Modifier modifier, {int qty = 1}) => DraftModifier(
        modifierId: modifier.id,
        name: modifier.name,
        priceDelta: modifier.priceDelta,
        qty: qty,
      );

  Map<String, dynamic> toJson() => {
        'modifierId': modifierId,
        'name': name,
        'priceDeltaMinor': priceDelta.minor,
        'currency': priceDelta.currency,
        'qty': qty,
      };

  factory DraftModifier.fromJson(Map<String, dynamic> json) => DraftModifier(
        modifierId: json['modifierId'] as String,
        name: (json['name'] as String?) ?? '',
        priceDelta: Money(
          (json['priceDeltaMinor'] as num?)?.toInt() ?? 0,
          (json['currency'] as String?) ?? 'PKR',
        ),
        qty: (json['qty'] as num?)?.toInt() ?? 1,
      );

  /// The payload `POST /restaurant/orders/:id/items` expects.
  Map<String, dynamic> toApiJson() => {'modifierId': modifierId, 'qty': qty};
}

/// One line of the draft ticket.
@immutable
class DraftLine {
  const DraftLine({
    required this.itemId,
    required this.name,
    required this.unitPrice,
    required this.taxBp,
    required this.qty,
    this.modifiers = const [],
    this.kitchenNotes,
    this.course,
    this.stationKey,
  });

  final String itemId;

  /// Snapshotted so a draft restored after a menu edit still reads sensibly.
  final String name;

  /// The item's branch-effective price, before modifiers.
  final Money unitPrice;

  /// Already resolved against the branch default — never null here, because a
  /// line that does not know its own tax rate cannot be priced.
  final int taxBp;
  final int qty;
  final List<DraftModifier> modifiers;

  /// Free text the kitchen sees on the KOT: "no chilli", "well done".
  final String? kitchenNotes;

  /// Course number, for staged service. Null means the kitchen decides.
  final int? course;
  final String? stationKey;

  String get currency => unitPrice.currency;

  /// Modifier price for ONE unit of this line.
  Money get modifierUnit => modifiers.fold(
        Money(0, currency),
        (sum, m) => sum + m.total,
      );

  /// Item + modifiers, per unit, **unclamped**.
  Money get unitWithModifiers => unitPrice + modifierUnit;

  /// What the server charges per unit: negative modifiers cannot make a line
  /// cost less than nothing (`Math.max(0, …)` in `computeMenuLine`).
  Money get pricedUnit =>
      unitWithModifiers.isNegative ? Money(0, currency) : unitWithModifiers;

  /// The amount tax is charged on.
  Money get taxable => pricedUnit * qty;

  /// Tax, truncated — see [Money.taxAt].
  Money get tax => taxable.taxAt(taxBp);

  /// What the server will store as this line's `line_total_minor`.
  Money get total => taxable + tax;

  /// This line's contribution to the ORDER subtotal, which the server
  /// aggregates as `unit_price × qty + modifier_total` — without the
  /// per-unit clamp it applies to the line total.
  ///
  /// The two differ only when a modifier discount exceeds the item's own price,
  /// which no sane menu does. Mirrored anyway: matching the server exactly is
  /// the entire point of this class, and a divergence invented here would be
  /// invisible until the one ticket where it mattered.
  Money get subtotalGross => unitWithModifiers * qty;

  /// Identity for merging repeat taps. Two lines of the same dish with the same
  /// options, notes and course are one line of qty 2 — a waiter tapping naan
  /// three times means three naan, not three lines to read back.
  String get signature {
    final mods = modifiers.map((m) => '${m.modifierId}:${m.qty}').toList()
      ..sort();
    return [
      itemId,
      mods.join(','),
      kitchenNotes?.trim() ?? '',
      course?.toString() ?? '',
    ].join('|');
  }

  DraftLine copyWith({int? qty, String? kitchenNotes, int? course}) => DraftLine(
        itemId: itemId,
        name: name,
        unitPrice: unitPrice,
        taxBp: taxBp,
        qty: qty ?? this.qty,
        modifiers: modifiers,
        kitchenNotes: kitchenNotes ?? this.kitchenNotes,
        course: course ?? this.course,
        stationKey: stationKey,
      );

  /// Build a line from the catalogue, resolving the branch tax fallback once so
  /// no later code has to remember that a null `taxBp` is not zero-rated.
  factory DraftLine.fromMenuItem(
    MenuItem item, {
    required RestaurantConfig config,
    int qty = 1,
    List<DraftModifier> modifiers = const [],
    String? kitchenNotes,
    int? course,
  }) =>
      DraftLine(
        itemId: item.id,
        name: item.name,
        unitPrice: item.price,
        taxBp: item.resolvedTaxBp(config.defaultTaxBp),
        qty: qty,
        modifiers: modifiers,
        kitchenNotes: kitchenNotes,
        course: course,
        stationKey: item.stationKey,
      );

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'name': name,
        'unitPriceMinor': unitPrice.minor,
        'currency': unitPrice.currency,
        'taxBp': taxBp,
        'qty': qty,
        'modifiers': modifiers.map((m) => m.toJson()).toList(),
        if (kitchenNotes != null) 'kitchenNotes': kitchenNotes,
        if (course != null) 'course': course,
        if (stationKey != null) 'stationKey': stationKey,
      };

  factory DraftLine.fromJson(Map<String, dynamic> json) {
    final currency = (json['currency'] as String?) ?? 'PKR';
    return DraftLine(
      itemId: json['itemId'] as String,
      name: (json['name'] as String?) ?? 'Item',
      unitPrice: Money((json['unitPriceMinor'] as num?)?.toInt() ?? 0, currency),
      taxBp: (json['taxBp'] as num?)?.toInt() ?? 0,
      qty: (json['qty'] as num?)?.toInt() ?? 1,
      modifiers: ((json['modifiers'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DraftModifier.fromJson)
          .toList(growable: false),
      kitchenNotes: json['kitchenNotes'] as String?,
      course: (json['course'] as num?)?.toInt(),
      stationKey: json['stationKey'] as String?,
    );
  }

  /// The payload `POST /restaurant/orders/:id/items` expects (Phase 5).
  Map<String, dynamic> toApiJson() => {
        'itemId': itemId,
        'qty': qty,
        if (course != null) 'course': course,
        if (kitchenNotes != null && kitchenNotes!.trim().isNotEmpty)
          'kitchenNotes': kitchenNotes!.trim(),
        if (modifiers.isNotEmpty)
          'modifiers': modifiers.map((m) => m.toApiJson()).toList(),
      };
}

/// The money summary of a draft, in the same order a bill prints.
@immutable
class DraftTotals {
  const DraftTotals({
    required this.subtotal,
    required this.tax,
    required this.serviceCharge,
    required this.rounding,
    required this.total,
  });

  final Money subtotal;
  final Money tax;
  final Money serviceCharge;

  /// Signed adjustment to the nearest rupee; zero when rounding is disabled.
  final Money rounding;
  final Money total;
}

/// Price a set of lines the way the server will, mirroring `recomputeTotals`.
///
/// Free of any notion of a table, because a customer's basket and a waiter's
/// ticket are the same arithmetic on the same backend: the moment those two
/// disagree by a paisa, one of the two screens is lying about a bill.
///
/// Tip and order-level discount are settlement concerns and are always zero
/// here; rounding is not, because the server rounds the total on every write,
/// so an unrounded total would disagree with the order the moment it is
/// created.
DraftTotals computeDraftTotals(
  List<DraftLine> lines,
  RestaurantConfig config,
) {
  final currency = lines.isEmpty ? config.currency : lines.first.currency;
  final zero = Money(0, currency);

  final subtotal = lines.fold(zero, (sum, l) => sum + l.subtotalGross);
  final tax = lines.fold(zero, (sum, l) => sum + l.tax);
  // Floor, like the backend's service charge — not [Money.applyBp].
  final serviceCharge = subtotal.taxAt(config.serviceChargeBp);
  final preRound = subtotal + tax + serviceCharge;
  final total =
      config.roundingEnabled ? preRound.roundedToNearest(100) : preRound;

  return DraftTotals(
    subtotal: subtotal,
    tax: tax,
    serviceCharge: serviceCharge,
    rounding: total - preRound,
    total: total,
  );
}

/// A whole ticket in progress for one table.
@immutable
class TicketDraft {
  const TicketDraft({
    required this.branchId,
    required this.tableId,
    required this.tableCode,
    required this.lines,
    required this.updatedAt,
    this.guestCount,
  });

  final String branchId;
  final String tableId;

  /// What staff call the table. Kept so a restored draft can be shown by name
  /// without another floor fetch.
  final String tableCode;
  final List<DraftLine> lines;
  final DateTime updatedAt;
  final int? guestCount;

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;
  int get itemCount => lines.fold(0, (sum, l) => sum + l.qty);

  static TicketDraft empty({
    required String branchId,
    required String tableId,
    required String tableCode,
    required DateTime now,
    int? guestCount,
  }) =>
      TicketDraft(
        branchId: branchId,
        tableId: tableId,
        tableCode: tableCode,
        lines: const [],
        updatedAt: now,
        guestCount: guestCount,
      );

  /// Totals, mirroring `recomputeTotals`.
  DraftTotals totals(RestaurantConfig config) =>
      computeDraftTotals(lines, config);

  /// Add a line, merging into an identical one rather than repeating it.
  TicketDraft add(DraftLine line, {required DateTime now}) {
    final signature = line.signature;
    final index = lines.indexWhere((l) => l.signature == signature);
    final next = [...lines];
    if (index >= 0) {
      next[index] = next[index].copyWith(qty: next[index].qty + line.qty);
    } else {
      next.add(line);
    }
    return _with(next, now);
  }

  /// Set a line's quantity; zero or less removes it.
  TicketDraft setQty(int index, int qty, {required DateTime now}) {
    if (index < 0 || index >= lines.length) return this;
    final next = [...lines];
    if (qty <= 0) {
      next.removeAt(index);
    } else {
      next[index] = next[index].copyWith(qty: qty);
    }
    return _with(next, now);
  }

  TicketDraft removeAt(int index, {required DateTime now}) =>
      setQty(index, 0, now: now);

  TicketDraft clearLines({required DateTime now}) => _with(const [], now);

  TicketDraft withGuestCount(int? guests, {required DateTime now}) =>
      TicketDraft(
        branchId: branchId,
        tableId: tableId,
        tableCode: tableCode,
        lines: lines,
        updatedAt: now,
        guestCount: guests,
      );

  TicketDraft _with(List<DraftLine> next, DateTime now) => TicketDraft(
        branchId: branchId,
        tableId: tableId,
        tableCode: tableCode,
        lines: List.unmodifiable(next),
        updatedAt: now,
        guestCount: guestCount,
      );

  /// A draft older than this is from a previous service, not the table in front
  /// of the waiter. Restoring it would risk firing yesterday's order at today's
  /// guests, so it is discarded on load.
  static const maxAge = Duration(hours: 12);

  bool isStaleAt(DateTime now) => now.difference(updatedAt) > maxAge;

  static const schemaVersion = 1;

  Map<String, dynamic> toJson() => {
        'version': schemaVersion,
        'branchId': branchId,
        'tableId': tableId,
        'tableCode': tableCode,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        if (guestCount != null) 'guestCount': guestCount,
        'lines': lines.map((l) => l.toJson()).toList(),
      };

  /// Returns null for anything this build cannot faithfully restore — a future
  /// schema version, or malformed storage. A half-restored ticket is worse than
  /// a fresh one: the waiter would not know which dishes were dropped.
  static TicketDraft? fromJson(Map<String, dynamic> json) {
    if ((json['version'] as num?)?.toInt() != schemaVersion) return null;
    final tableId = json['tableId'];
    final branchId = json['branchId'];
    final updatedAt = DateTime.tryParse((json['updatedAt'] as String?) ?? '');
    if (tableId is! String || branchId is! String || updatedAt == null) {
      return null;
    }
    try {
      return TicketDraft(
        branchId: branchId,
        tableId: tableId,
        tableCode: (json['tableCode'] as String?) ?? '',
        updatedAt: updatedAt.toLocal(),
        guestCount: (json['guestCount'] as num?)?.toInt(),
        lines: List.unmodifiable(((json['lines'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(DraftLine.fromJson)
            .toList()),
      );
    } on TypeError {
      return null;
    }
  }
}
