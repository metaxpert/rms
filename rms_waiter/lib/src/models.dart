import 'package:intl/intl.dart';

int _int(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// A `{amountMinor, currency}` money value from the API, formatted for display.
class Money {
  Money(this.amountMinor, this.currency);
  final int amountMinor;
  final String currency;

  factory Money.from(dynamic j) => j == null
      ? Money(0, 'PKR')
      : Money(_int(j['amountMinor']), (j['currency'] as String?) ?? 'PKR');

  String get formatted {
    final f = NumberFormat.currency(symbol: '$currency ', decimalDigits: 2);
    return f.format(amountMinor / 100);
  }
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

class TableModel {
  TableModel(this.id, this.code, this.area, this.capacity, this.status);
  final String id;
  final String code;
  final String? area;
  final int capacity;
  final String status;

  factory TableModel.from(Map<String, dynamic> j) => TableModel(
        j['id'] as String,
        j['code'] as String,
        j['area'] as String?,
        _int(j['capacity']),
        j['status'] as String,
      );
}

class MenuItem {
  MenuItem(this.id, this.name, this.category, this.price, this.imageKey, this.available);
  final String id;
  final String name;
  final String? category;
  final Money price;
  final String? imageKey;
  final bool available;

  factory MenuItem.from(Map<String, dynamic> j) => MenuItem(
        j['id'] as String,
        j['name'] as String,
        j['category'] as String?,
        Money.from(j['effectivePrice']),
        j['imageKey'] as String?,
        j['available'] == true,
      );

  String? get imageUrl {
    final k = imageKey;
    if (k != null && (k.startsWith('http://') || k.startsWith('https://'))) return k;
    return null;
  }
}

class OrderLine {
  OrderLine(this.id, this.name, this.qty, this.unitPrice, this.lineTotal);
  final String id;
  final String name;
  final int qty;
  final Money unitPrice;
  final Money lineTotal;

  factory OrderLine.from(Map<String, dynamic> j) => OrderLine(
        j['id'] as String,
        j['name'] as String,
        _int(j['qty']),
        Money.from(j['unitPrice']),
        Money.from(j['lineTotal']),
      );
}

class OrderDetail {
  OrderDetail({
    required this.id,
    required this.orderNo,
    required this.status,
    required this.channel,
    required this.table,
    required this.guestCount,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.items,
  });

  final String id;
  final String orderNo;
  final String status;
  final String channel;
  final String? table;
  final int guestCount;
  final Money subtotal;
  final Money tax;
  final Money total;
  final List<OrderLine> items;

  bool get isDraft => status == 'DRAFT';
  bool get isSettled => status == 'SETTLED' || status == 'CLOSED';
  bool get canSettle => const ['CONFIRMED', 'IN_PROGRESS', 'READY', 'SERVED'].contains(status);

  factory OrderDetail.from(Map<String, dynamic> j) {
    final t = (j['totals'] as Map<String, dynamic>?) ?? const {};
    return OrderDetail(
      id: j['id'] as String,
      orderNo: j['orderNo'] as String,
      status: j['status'] as String,
      channel: j['channel'] as String,
      table: j['table'] as String?,
      guestCount: _int(j['guestCount']),
      subtotal: Money.from(t['subtotal']),
      tax: Money.from(t['tax']),
      total: Money.from(t['total']),
      items: ((j['items'] as List?) ?? [])
          .map((e) => OrderLine.from(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
