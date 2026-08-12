import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';

/// Everything the manager's screens read, fetched in one fan-out.
///
/// One snapshot rather than a provider per screen because the three tabs are
/// three views of the same moment: a manager who sees 4 open bills on the
/// dashboard and 6 in the sales list would trust neither. It also means
/// switching tabs costs nothing, which matters on a phone being glanced at
/// between other jobs.
@immutable
class ServiceSnapshot {
  const ServiceSnapshot({
    required this.orders,
    required this.board,
    required this.tables,
    required this.deliveries,
    required this.takenAt,
  });

  final List<OrderSummary> orders;
  final KdsBoard board;
  final List<RestaurantTable> tables;
  final List<Delivery> deliveries;

  /// When this was read. Shown, because a dashboard that might be four minutes
  /// stale and does not say so is worse than no dashboard.
  final DateTime takenAt;

  List<OrderSummary> get openOrders =>
      orders.where((o) => o.status.isOpen).toList(growable: false);

  List<OrderSummary> get settledOrders => orders
      .where((o) => o.status == OrderStatus.settled)
      .toList(growable: false);

  String get currency =>
      orders.isEmpty ? 'PKR' : orders.first.total.currency;

  Money get _zero => Money(0, currency);

  /// Money on tables that has not been paid yet.
  Money get openValue =>
      openOrders.fold(_zero, (sum, order) => sum + order.total);

  /// Taken today — or rather, taken across whatever window the API's default
  /// list covers. Deliberately labelled as "settled" rather than "revenue":
  /// revenue is the ledger's word and belongs to the GL, not to a phone.
  Money get settledValue =>
      settledOrders.fold(_zero, (sum, order) => sum + order.total);

  Money get averageBill {
    if (settledOrders.isEmpty) return _zero;
    return Money(settledValue.minor ~/ settledOrders.length, currency);
  }

  /// Orders the kitchen has finished that nobody has taken to a table. The
  /// number a manager can act on immediately by walking to the pass.
  int get readyToServe =>
      openOrders.where((o) => o.status.needsAttention).length;

  int get occupiedTables =>
      tables.where((t) => t.status == TableStatus.occupied).length;

  int get totalTables => tables.length;

  List<Delivery> get activeDeliveries =>
      deliveries.where((d) => d.status.isActive).toList(growable: false);

  int get lateDeliveries => activeDeliveries
      .where((d) => d.status == DeliveryStatus.enRoute && (d.etaMinutes ?? 0) < 0)
      .length;
}

class ServiceRepository {
  ServiceRepository(this._client);

  final ApiClient _client;

  /// Five reads, issued together.
  ///
  /// Sequentially this would be five round trips before anything appears; a
  /// manager checking the kitchen between two other jobs would give up first.
  /// A failure in any one fails the snapshot: a dashboard showing four true
  /// numbers and one silently missing is how a manager stops trusting it.
  Future<ServiceSnapshot> read() async {
    final results = await Future.wait([
      _client.get(_client.branchScoped('/restaurant/orders')),
      _client.get(_client.branchScoped('/restaurant/kds/board')),
      _client.get(_client.branchScoped('/restaurant/tables')),
      _client.get(_client.branchScoped('/restaurant/deliveries')),
    ]);

    return ServiceSnapshot(
      orders: _list(results[0])
          .map(OrderSummary.fromJson)
          .toList(growable: false),
      board: KdsBoard.from(
        _list(results[1]).map(KdsTicket.fromJson).toList(growable: false),
      ),
      tables: _list(results[2])
          .map(RestaurantTable.fromJson)
          .where((t) => t.active)
          .toList(growable: false),
      deliveries:
          _list(results[3]).map(Delivery.fromJson).toList(growable: false),
      takenAt: DateTime.now(),
    );
  }

  static List<Map<String, dynamic>> _list(dynamic data) {
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }
}

final serviceRepositoryProvider = Provider<ServiceRepository>(
  (ref) => ServiceRepository(ref.watch(apiClientProvider)),
);

/// The current state of service.
///
/// Not `autoDispose`: the three tabs share it, and dropping it when the user
/// crosses between them would refetch five endpoints on every tab change.
final serviceSnapshotProvider = FutureProvider<ServiceSnapshot>(
  (ref) => ref.watch(serviceRepositoryProvider).read(),
);
