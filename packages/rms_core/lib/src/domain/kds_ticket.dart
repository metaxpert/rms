import 'package:flutter/material.dart';

import '../l10n/rms_localizations.dart';
import '../theme/app_theme.dart';

/// Where in the kitchen a ticket is cooked. Stations are tenant-defined
/// (`grill`, `tandoor`, `cold`), so nothing may be hard-coded against them.
typedef StationKey = String;

/// A line on a kitchen ticket.
@immutable
class KdsItem {
  const KdsItem({required this.qty, required this.name, this.notes});

  final int qty;
  final String name;

  /// What the waiter typed for the kitchen — "no chilli", "well done".
  final String? notes;

  factory KdsItem.fromJson(Map<String, dynamic> json) => KdsItem(
        qty: (json['qty'] as num?)?.toInt() ?? 1,
        name: (json['name'] as String?) ?? 'Item',
        notes: json['kitchenNotes'] as String? ?? json['notes'] as String?,
      );
}

/// A ticket on the kitchen board — `GET /restaurant/kds/board`.
///
/// The board is the kitchen's own view of an order, split by station: one order
/// for a grill item and a dessert is two tickets. That is why a ticket carries
/// its order's number rather than being identified by it.
@immutable
class KdsTicket {
  const KdsTicket({
    required this.id,
    required this.orderNo,
    required this.stationKey,
    required this.status,
    required this.items,
    required this.elapsed,
    this.tableCode,
    this.targetMinutes,
  });

  final String id;
  final String orderNo;
  final StationKey stationKey;

  /// The backend's ticket status, kept verbatim. Not mapped to an enum: the KDS
  /// vocabulary was not verified the way the order lifecycle was, and inventing
  /// names for it is exactly what the brief warns against.
  final String status;

  final List<KdsItem> items;

  /// How long this ticket has been waiting.
  final Duration elapsed;

  final String? tableCode;

  /// The kitchen's own target for this ticket, when it has one.
  final int? targetMinutes;

  int get itemCount => items.fold(0, (sum, item) => sum + item.qty);

  /// Past the kitchen's own target — the only thing on the board that needs a
  /// manager to walk over and ask.
  ///
  /// A ticket with no target is never overdue. Inventing a default would put
  /// half the board in red on a busy night and teach everyone to ignore it.
  bool get isOverdue =>
      targetMinutes != null && elapsed.inSeconds > targetMinutes! * 60;

  /// "14:05" against a wall clock is no use to a chef; time *waiting* is.
  String elapsedLabelIn(RmsLocalizations text) {
    final minutes = elapsed.inMinutes;
    if (minutes < 1) return text.waitJustNow;
    if (minutes < 60) return text.waitMinutes(minutes);
    final hours = elapsed.inHours;
    return text.waitHoursMinutes(hours, minutes - hours * 60);
  }

  Color get urgencyColor => isOverdue
      ? AppStatusColors.cancelled
      : elapsed.inMinutes >= 10
          ? AppStatusColors.preparing
          : AppStatusColors.ordering;

  factory KdsTicket.fromJson(Map<String, dynamic> json) => KdsTicket(
        id: json['id'] as String,
        orderNo: (json['orderNo'] as String?) ?? '',
        stationKey: (json['stationKey'] as String?) ?? 'kitchen',
        status: (json['status'] as String?) ?? 'UNKNOWN',
        items: ((json['items'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(KdsItem.fromJson)
            .toList(growable: false),
        elapsed: Duration(seconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0),
        tableCode: json['table'] as String?,
        targetMinutes: (json['targetMinutes'] as num?)?.toInt(),
      );

  @override
  bool operator ==(Object other) => other is KdsTicket && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The board, grouped the way a kitchen is actually laid out.
@immutable
class KdsBoard {
  const KdsBoard({required this.stations});

  /// Station key → its tickets, longest-waiting first.
  final Map<StationKey, List<KdsTicket>> stations;

  static KdsBoard from(List<KdsTicket> tickets) {
    final grouped = <StationKey, List<KdsTicket>>{};
    for (final ticket in tickets) {
      (grouped[ticket.stationKey] ??= []).add(ticket);
    }
    for (final list in grouped.values) {
      // Oldest at the top: the ticket that has been waiting longest is the one
      // a chef should pick up next, and the one a manager should ask about.
      list.sort((a, b) => b.elapsed.compareTo(a.elapsed));
    }
    return KdsBoard(stations: Map.unmodifiable(grouped));
  }

  List<StationKey> get stationKeys => stations.keys.toList(growable: false)
    ..sort();

  List<KdsTicket> get allTickets =>
      stations.values.expand((tickets) => tickets).toList(growable: false);

  int get ticketCount => allTickets.length;

  int get overdueCount => allTickets.where((t) => t.isOverdue).length;

  bool get isEmpty => stations.isEmpty;

  /// The longest anything has been waiting, which is the one number a manager
  /// glancing at a busy kitchen actually wants.
  Duration get longestWait => allTickets.fold(
        Duration.zero,
        (worst, ticket) => ticket.elapsed > worst ? ticket.elapsed : worst,
      );
}
