import 'package:intl/intl.dart';

int _int(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

class Money {
  Money(this.amountMinor, this.currency);
  final int amountMinor;
  final String currency;
  factory Money.from(dynamic j) =>
      j == null ? Money(0, 'PKR') : Money(_int(j['amountMinor']), (j['currency'] as String?) ?? 'PKR');

  static String fmt(int minor, [String currency = 'PKR']) =>
      NumberFormat.currency(symbol: '$currency ', decimalDigits: 0).format(minor / 100);
  String get formatted => fmt(amountMinor, currency);
}

/// A branch/outlet of the restaurant tenant (from GET /restaurant/branches).
class BranchModel {
  BranchModel(this.id, this.name, this.code, this.isHeadOffice, this.configured);
  final String id;
  final String name;
  final String? code;
  final bool isHeadOffice;
  final bool configured;

  factory BranchModel.from(Map<String, dynamic> j) => BranchModel(
        j['id'] as String,
        j['name'] as String,
        j['code'] as String?,
        j['isHeadOffice'] == true,
        j['configured'] == true,
      );
}

class OrderRow {
  OrderRow(this.id, this.orderNo, this.channel, this.status, this.table, this.itemCount, this.total);
  final String id;
  final String orderNo;
  final String channel;
  final String status;
  final String? table;
  final int itemCount;
  final Money total;

  static const openStatuses = ['DRAFT', 'PLACED', 'CONFIRMED', 'IN_PROGRESS', 'READY', 'SERVED'];
  bool get isOpen => openStatuses.contains(status);
  bool get isSettled => status == 'SETTLED' || status == 'CLOSED';

  factory OrderRow.from(Map<String, dynamic> j) => OrderRow(
        j['id'] as String,
        j['orderNo'] as String,
        j['channel'] as String,
        j['status'] as String,
        j['table'] as String?,
        _int(j['itemCount']),
        Money.from(j['total']),
      );
}

class KdsTicket {
  KdsTicket(this.id, this.orderNo, this.station, this.status, this.table, this.elapsedSeconds, this.targetMinutes, this.items);
  final String id;
  final String orderNo;
  final String station;
  final String status;
  final String? table;
  final int elapsedSeconds;
  final int? targetMinutes;
  final List<({int qty, String name})> items;

  bool get overdue => targetMinutes != null && elapsedSeconds > targetMinutes! * 60;

  factory KdsTicket.from(Map<String, dynamic> j) => KdsTicket(
        j['id'] as String,
        j['orderNo'] as String,
        j['stationKey'] as String,
        j['status'] as String,
        j['table'] as String?,
        _int(j['elapsedSeconds']),
        j['targetMinutes'] == null ? null : _int(j['targetMinutes']),
        ((j['items'] as List?) ?? [])
            .map((e) => (qty: _int((e as Map)['qty']), name: e['name'] as String))
            .toList(),
      );
}

/// One fan-out fetch of everything the manager dashboard needs, plus the derived KPIs.
class Snapshot {
  Snapshot({required this.orders, required this.tickets, required this.tables, required this.deliveries, required this.reservations});

  final List<OrderRow> orders;
  final List<KdsTicket> tickets;
  final List<Map<String, dynamic>> tables;
  final List<Map<String, dynamic>> deliveries;
  final List<Map<String, dynamic>> reservations;

  List<OrderRow> get openOrders => orders.where((o) => o.isOpen).toList();
  int get openBills => openOrders.length;
  int get openValueMinor => openOrders.fold(0, (s, o) => s + o.total.amountMinor);
  int get settledCount => orders.where((o) => o.isSettled).length;
  int get settledValueMinor => orders.where((o) => o.isSettled).fold(0, (s, o) => s + o.total.amountMinor);
  int get occupiedTables => tables.where((t) => t['status'] == 'OCCUPIED').length;
  int get totalTables => tables.length;
  int get liveTickets => tickets.length;
  int get activeDeliveries =>
      deliveries.where((d) => const ['PENDING', 'ASSIGNED', 'PICKED_UP', 'EN_ROUTE'].contains(d['status'])).length;
  int get upcomingReservations =>
      reservations.where((r) => const ['BOOKED', 'CONFIRMED', 'WAITLIST'].contains(r['status'])).length;
  String get currency => orders.isNotEmpty ? orders.first.total.currency : 'PKR';
}
