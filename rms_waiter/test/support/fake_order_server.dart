import 'package:rms_core/rms_core.dart';
import 'package:rms_waiter/src/features/orders/data/order_repository.dart';

/// A stand-in for the restaurant order API, shared by the send and settle
/// suites.
///
/// The HTTP layer has its own tests. What these suites are about is the ORDER
/// of the calls, what is persisted between them, and what a second attempt
/// does — so the seam is the repository, not JSON.
class FakeOrderServer implements OrderRepository {
  FakeOrderServer({this.autoFireKitchen = false});

  /// When true, `place` lands the order in CONFIRMED, as a tenant with
  /// `autoFireKitchen` does — and `confirm` then becomes an illegal transition.
  final bool autoFireKitchen;

  /// Every call made, in order, for asserting what a resume skipped.
  final calls = <String>[];

  /// Idempotency keys seen per call, so a repeat can be proved to reuse one.
  /// Nulls are recorded too: "this call deliberately carried no key" is itself
  /// something worth asserting, as a reprint does.
  final keys = <String, List<String?>>{};

  /// Steps that should throw once, then succeed — a flaky connection.
  final failOnce = <String, ApiException>{};

  /// Steps that always throw.
  final failAlways = <String, ApiException>{};

  /// Runs when a step is reached, before any failure it is configured to
  /// raise — how another till acting between two of our calls is modelled.
  final onStep = <String, void Function()>{};

  final Map<String, OrderDetail> _orders = {};
  var _nextId = 1;

  OrderDetail? openOrder;

  int get createCount => calls.where((c) => c == 'create').length;

  /// Replace the server's copy of an order.
  void seed(OrderDetail order) {
    _orders[order.id] = order;
    openOrder = order.isOpen ? order : null;
  }

  void _record(String step, [String? key]) {
    calls.add(step);
    (keys[step] ??= []).add(key);
    onStep[step]?.call();
    final once = failOnce.remove(step);
    if (once != null) throw once;
    final always = failAlways[step];
    if (always != null) throw always;
  }

  OrderDetail _build({
    required String id,
    required String status,
    required List<Map<String, dynamic>> items,
  }) =>
      OrderDetail.fromJson({
        'id': id,
        'orderNo': 'ORD-00000$_nextId',
        'status': status,
        'channel': 'DINE_IN',
        'table': 'D1',
        'tableId': 'table-1',
        'guestCount': 4,
        'totals': {
          'subtotal': {'amountMinor': 12000 * items.length, 'currency': 'PKR'},
          'tax': {'amountMinor': 1920 * items.length, 'currency': 'PKR'},
          'total': {'amountMinor': 13920 * items.length, 'currency': 'PKR'},
        },
        'items': [
          for (final item in items)
            {
              'id': 'line-${items.indexOf(item)}',
              'itemId': item['itemId'],
              'name': 'Garlic Naan',
              'qty': item['qty'],
              'unitPrice': {'amountMinor': 12000, 'currency': 'PKR'},
              'lineTotal': {'amountMinor': 13920, 'currency': 'PKR'},
            },
        ],
      });

  @override
  Future<OrderDetail?> openOrderForTable(String tableId) async {
    _record('lookup');
    return openOrder;
  }

  @override
  Future<OrderDetail> fetch(String orderId) async {
    _record('fetch');
    final order = _orders[orderId];
    if (order == null) {
      throw ApiException(ApiErrorKind.notFound, 'No such order.');
    }
    return order;
  }

  @override
  Future<OrderDetail?> create({
    required String tableId,
    required int? guestCount,
    required String idempotencyKey,
  }) async {
    _record('create', idempotencyKey);
    final id = 'order-${_nextId++}';
    final order = _build(id: id, status: 'DRAFT', items: const []);
    _orders[id] = order;
    openOrder = order;
    return order;
  }

  @override
  Future<OrderDetail?> addItems({
    required String orderId,
    required List<Map<String, dynamic>> items,
    required String idempotencyKey,
  }) async {
    _record('addItems', idempotencyKey);
    final current = _orders[orderId]!;
    final order = _build(id: orderId, status: current.status.wire, items: items);
    _orders[orderId] = order;
    openOrder = order;
    return order;
  }

  @override
  Future<OrderDetail?> place({
    required String orderId,
    required String idempotencyKey,
  }) async {
    _record('place', idempotencyKey);
    final current = _orders[orderId]!;
    final order = _build(
      id: orderId,
      status: autoFireKitchen ? 'CONFIRMED' : 'PLACED',
      items: [
        for (final line in current.lines) {'itemId': line.itemId, 'qty': line.qty}
      ],
    );
    _orders[orderId] = order;
    openOrder = order;
    return order;
  }

  @override
  Future<OrderDetail?> confirm({
    required String orderId,
    required String idempotencyKey,
  }) async {
    _record('confirm', idempotencyKey);
    final current = _orders[orderId]!;
    final order = _build(
      id: orderId,
      status: 'CONFIRMED',
      items: [
        for (final line in current.lines) {'itemId': line.itemId, 'qty': line.qty}
      ],
    );
    _orders[orderId] = order;
    openOrder = order;
    return order;
  }

  @override
  Future<void> removeLine({
    required String orderId,
    required String lineId,
  }) async =>
      _record('removeLine');

  /// Tenders accepted, per settle call — a double-charge shows up here as two
  /// entries where there should be one.
  final settlements = <List<Payment>>[];

  @override
  Future<OrderDetail?> settle({
    required String orderId,
    required List<Payment> payments,
    required String idempotencyKey,
  }) async {
    _record('settle', idempotencyKey);
    final current = _orders[orderId]!;
    // The backend refuses a second settle with 422; so does this.
    if (current.status == OrderStatus.settled) {
      throw ApiException(
        ApiErrorKind.rejected,
        'Order is already settled.',
        status: 422,
      );
    }
    settlements.add(payments);
    final order = _build(
      id: orderId,
      status: 'SETTLED',
      items: [
        for (final line in current.lines) {'itemId': line.itemId, 'qty': line.qty}
      ],
    );
    _orders[orderId] = order;
    openOrder = null;
    return order;
  }

  String receiptText = 'RECEIPT\n  Garlic Naan  139.20\n';

  @override
  Future<String?> receipt(String orderId, {int charsPerLine = 32}) async {
    _record('receipt');
    return receiptText;
  }

  /// Print jobs queued, as `reprint` flags — two entries for one tap would mean
  /// a guest handed two slips.
  final printJobs = <bool>[];

  @override
  Future<void> queuePrint({
    required String orderId,
    bool reprint = false,
    String? idempotencyKey,
  }) async {
    _record('print', idempotencyKey);
    printJobs.add(reprint);
  }
}

