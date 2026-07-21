import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

int _int(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

class Money {
  Money(this.amountMinor, this.currency);
  final int amountMinor;
  final String currency;
  factory Money.from(dynamic j) =>
      j == null ? Money(0, 'PKR') : Money(_int(j['amountMinor']), (j['currency'] as String?) ?? 'PKR');
  static String fmt(int minor, [String c = 'PKR']) =>
      NumberFormat.currency(symbol: '$c ', decimalDigits: 0).format(minor / 100);
  String get formatted => fmt(amountMinor, currency);
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

/// In-memory basket shared across screens; notifies the cart badge + cart screen.
class Cart extends ChangeNotifier {
  Cart._();
  static final Cart instance = Cart._();

  final Map<MenuItem, int> _lines = {};
  Map<MenuItem, int> get lines => Map.unmodifiable(_lines);
  int get count => _lines.values.fold(0, (s, q) => s + q);
  bool get isEmpty => _lines.isEmpty;

  int subtotalMinor() => _lines.entries.fold(0, (s, e) => s + e.key.price.amountMinor * e.value);
  int taxMinor() => (subtotalMinor() * 0.16).round();
  int totalMinor() => subtotalMinor() + taxMinor();
  String get currency => _lines.isEmpty ? 'PKR' : _lines.keys.first.price.currency;

  void add(MenuItem m) {
    _lines.update(m, (q) => q + 1, ifAbsent: () => 1);
    notifyListeners();
  }

  void remove(MenuItem m) {
    final q = (_lines[m] ?? 0) - 1;
    if (q <= 0) {
      _lines.remove(m);
    } else {
      _lines[m] = q;
    }
    notifyListeners();
  }

  int qtyOf(MenuItem m) => _lines[m] ?? 0;

  void clear() {
    _lines.clear();
    notifyListeners();
  }
}

class TrackOrder {
  TrackOrder(this.orderNo, this.status, this.channel, this.total, this.itemNames, this.delivery);
  final String orderNo;
  final String status;
  final String channel;
  final Money total;
  final List<String> itemNames;
  final DeliveryInfo? delivery;

  bool get isSettledOrClosed => status == 'SETTLED' || status == 'CLOSED';

  factory TrackOrder.from(Map<String, dynamic> j, Map<String, dynamic>? d) {
    final t = (j['totals'] as Map<String, dynamic>?) ?? const {};
    return TrackOrder(
      j['orderNo'] as String,
      j['status'] as String,
      j['channel'] as String,
      Money.from(t['total']),
      ((j['items'] as List?) ?? []).map((e) => '${_int((e as Map)['qty'])}× ${e['name']}').toList(),
      d == null ? null : DeliveryInfo.from(d),
    );
  }
}

class DeliveryInfo {
  DeliveryInfo(this.deliveryNo, this.status, this.etaMinutes);
  final String deliveryNo;
  final String status;
  final int? etaMinutes;
  factory DeliveryInfo.from(Map<String, dynamic> j) =>
      DeliveryInfo(j['deliveryNo'] as String, j['status'] as String, j['etaMinutes'] == null ? null : _int(j['etaMinutes']));
}
