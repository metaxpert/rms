import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';

/// How the customer wants the food.
enum OrderChannel {
  delivery('DELIVERY'),
  takeaway('TAKEAWAY');

  const OrderChannel(this.wire);

  final String wire;

  String get label => switch (this) {
        OrderChannel.delivery => 'Delivery',
        OrderChannel.takeaway => 'Collection',
      };

  bool get needsAddress => this == OrderChannel.delivery;
}

/// The result of creating an order, including whether the address stuck.
@immutable
class CreatedOrder {
  const CreatedOrder({required this.order, required this.addressAccepted});

  final OrderDetail order;

  /// False when the server refused the request carrying an address and it had
  /// to be sent without one. The customer is told, because an order placed
  /// without an address is one the restaurant has to phone about.
  final bool addressAccepted;
}

/// The customer's side of the order API.
class CustomerOrderRepository {
  CustomerOrderRepository(this._client, this._session);

  final ApiClient _client;
  final Session _session;

  /// Open an order.
  ///
  /// **The address is unverified.** `POST /restaurant/orders` was only ever
  /// observed taking `channel`, `guestCount` and `branchId`; whether it accepts
  /// an `address` was never confirmed. The app it replaces collected an address
  /// and silently dropped it, which is the worst of both worlds — a customer
  /// who typed where they live and got food nowhere.
  ///
  /// So the address is sent, and if the server refuses the request because of
  /// it, the order is retried without and the caller is told it did not stick.
  /// Degrading loudly beats degrading silently.
  Future<CreatedOrder> create({
    required OrderChannel channel,
    required String idempotencyKey,
    String? address,
  }) async {
    Map<String, dynamic> body({required bool withAddress}) => {
          'channel': channel.wire,
          'guestCount': 1,
          if (_session.branchId != null) 'branchId': _session.branchId,
          if (withAddress && address != null && address.trim().isNotEmpty)
            'address': address.trim(),
        };

    final wantsAddress = address != null && address.trim().isNotEmpty;

    try {
      final response = await _client.post(
        '/restaurant/orders',
        body(withAddress: wantsAddress),
        idempotencyKey,
      );
      return CreatedOrder(
        order: _require(response),
        addressAccepted: wantsAddress,
      );
    } on ApiException catch (error) {
      if (!wantsAddress || error.kind != ApiErrorKind.rejected) rethrow;
      // A different body needs a different key, or the interceptor refuses it
      // as a replay of the first attempt.
      final response = await _client.post(
        '/restaurant/orders',
        body(withAddress: false),
        '$idempotencyKey:no-address',
      );
      return CreatedOrder(order: _require(response), addressAccepted: false);
    }
  }

  Future<void> addItems({
    required String orderId,
    required List<Map<String, dynamic>> items,
    required String idempotencyKey,
  }) =>
      _client.post(
        '/restaurant/orders/$orderId/items',
        {'items': items},
        idempotencyKey,
      );

  /// Send it to the restaurant. Until this, the order exists but nobody is
  /// cooking.
  Future<void> place({
    required String orderId,
    required String idempotencyKey,
  }) =>
      _client.post(
        '/restaurant/orders/$orderId/place',
        const <String, dynamic>{},
        idempotencyKey,
      );

  Future<OrderDetail> fetch(String orderId) async =>
      _require(await _client.get('/restaurant/orders/$orderId'));

  /// The delivery job for an order, when there is one.
  ///
  /// Found by scanning the branch's deliveries, because no endpoint maps an
  /// order to its delivery directly. Failures are swallowed: a customer who can
  /// see their food is being cooked should not be shown an error because the
  /// rider list was unreadable.
  Future<Delivery?> deliveryFor(String orderId) async {
    try {
      final data =
          await _client.get(_client.branchScoped('/restaurant/deliveries'));
      if (data is! List) return null;
      for (final json in data.whereType<Map<String, dynamic>>()) {
        if (json['orderId'] == orderId) return Delivery.fromJson(json);
      }
    } on ApiException {
      return null;
    }
    return null;
  }

  static OrderDetail _require(dynamic response) {
    if (response is! Map<String, dynamic> || response['id'] is! String) {
      throw ApiException(
        ApiErrorKind.unknown,
        'The restaurant\'s server returned something we could not read.',
      );
    }
    return OrderDetail.fromJson(response);
  }
}

final customerOrderRepositoryProvider = Provider<CustomerOrderRepository>(
  (ref) => CustomerOrderRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionProvider),
  ),
);

/// One order, for the tracking screen.
final trackedOrderProvider =
    FutureProvider.autoDispose.family<TrackedOrder, String>((ref, id) async {
  final repository = ref.watch(customerOrderRepositoryProvider);
  final order = await repository.fetch(id);
  return TrackedOrder(
    order: order,
    delivery: order.channel == OrderChannel.delivery.wire
        ? await repository.deliveryFor(id)
        : null,
  );
});

@immutable
class TrackedOrder {
  const TrackedOrder({required this.order, this.delivery});

  final OrderDetail order;
  final Delivery? delivery;
}
