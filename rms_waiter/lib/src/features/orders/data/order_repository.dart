import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';

/// Every call the waiter app makes against a server-held order.
///
/// The methods map one-to-one onto the backend's routes rather than inventing a
/// combined "submit" endpoint, because the lifecycle is enforced server-side and
/// each transition can be refused independently (ARCHITECTURE.md §2). A client
/// that pretended the four calls were one would have nowhere to resume from when
/// the third failed.
///
/// **Every mutation takes an [idempotencyKey] from the caller.** The client
/// mints its own key per call, which covers its transport retries but not a
/// waiter tapping "Send" again after a timeout — and a second tap that opened a
/// second bill for the table is the worst outcome this feature has. Keys that
/// outlive the process live in [PendingSendStore].
class OrderRepository {
  OrderRepository(this._client, this._session);

  final ApiClient _client;
  final Session _session;

  /// The open dine-in order on a table, or null when the table has no bill.
  ///
  /// Two round trips: the list endpoint carries only a summary, and the ticket
  /// screen needs the lines. It is issued on every table open rather than
  /// trusting the floor's cache, because a void performed on another till is
  /// **not** bridged to sockets (ARCHITECTURE.md §4) — the only way to know an
  /// order is gone is to ask.
  Future<OrderDetail?> openOrderForTable(String tableId) async {
    final summaries = _list(
      await _client.get(_client.branchScoped('/restaurant/orders?tableId=$tableId')),
    ).map(OrderSummary.fromJson).where((o) => o.status.isOpen && o.isDineIn);

    if (summaries.isEmpty) return null;

    // If a table somehow carries two open orders, prefer the one a waiter must
    // act on, so a READY ticket is never hidden behind a still-cooking one.
    final chosen = summaries.reduce(
      (a, b) => b.status.needsAttention && !a.status.needsAttention ? b : a,
    );
    return fetch(chosen.id);
  }

  Future<OrderDetail> fetch(String orderId) async {
    final json = await _client.get('/restaurant/orders/$orderId');
    return OrderDetail.fromJson(json as Map<String, dynamic>);
  }

  /// Open a bill for a table. The order starts in DRAFT — nothing is with the
  /// kitchen until it is placed and confirmed.
  Future<OrderDetail?> create({
    required String tableId,
    required int? guestCount,
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      '/restaurant/orders',
      {
        'channel': 'DINE_IN',
        'tableId': tableId,
        if (guestCount != null && guestCount > 0) 'guestCount': guestCount,
        if (_session.branchId != null) 'branchId': _session.branchId,
      },
      idempotencyKey,
    );
    return _orderFrom(response);
  }

  /// Add a round to an existing order.
  ///
  /// Takes the already-encoded payload rather than [DraftLine]s so that a
  /// submission resumed after a crash re-sends **byte-identical** items. That
  /// matters: an idempotency key replayed with a different body is a 422, so a
  /// resume that re-encoded from a since-edited draft would fail exactly when
  /// recovery is needed most.
  ///
  /// The server re-prices every line against the branch's current price — the
  /// draft's amounts are a prediction and are deliberately not sent.
  Future<OrderDetail?> addItems({
    required String orderId,
    required List<Map<String, dynamic>> items,
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      '/restaurant/orders/$orderId/items',
      {'items': items},
      idempotencyKey,
    );
    return _orderFrom(response);
  }

  Future<OrderDetail?> place({
    required String orderId,
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      '/restaurant/orders/$orderId/place',
      const <String, dynamic>{},
      idempotencyKey,
    );
    return _orderFrom(response);
  }

  /// Fire the kitchen. On a tenant with `autoFireKitchen` this has already
  /// happened during [place]; see [SendController] for how that is handled.
  Future<OrderDetail?> confirm({
    required String orderId,
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      '/restaurant/orders/$orderId/confirm',
      const <String, dynamic>{},
      idempotencyKey,
    );
    return _orderFrom(response);
  }

  Future<void> removeLine({
    required String orderId,
    required String lineId,
  }) =>
      _client.delete('/restaurant/orders/$orderId/items/$lineId');

  /// A mutation's response, when it is an order.
  ///
  /// Whether these routes echo the updated order was never verified, so nothing
  /// depends on it: a response we cannot read as an order yields null and the
  /// caller refetches. Using it when it IS there saves a round trip per step on
  /// restaurant wifi, which is worth having.
  static OrderDetail? _orderFrom(dynamic response) {
    if (response is! Map<String, dynamic>) return null;
    if (response['id'] is! String) return null;
    try {
      return OrderDetail.fromJson(response);
    } on TypeError {
      return null;
    }
  }

  static List<Map<String, dynamic>> _list(dynamic data) {
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }
}

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionProvider),
  ),
);

/// The server's order for one table, refetched whenever the table is opened.
///
/// `autoDispose` because a tablet may visit fifty tables in a service and
/// holding every order in memory would keep stale bills alive; the ticket screen
/// is the only consumer and it is short-lived.
final tableOrderProvider =
    FutureProvider.autoDispose.family<OrderDetail?, String>(
  (ref, tableId) => ref.watch(orderRepositoryProvider).openOrderForTable(tableId),
);
