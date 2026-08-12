import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../orders/domain/order_summary.dart';
import '../domain/restaurant_table.dart';

/// Everything the floor screen needs, fetched together.
@immutable
class FloorSnapshot {
  const FloorSnapshot({
    required this.areas,
    required this.tables,
    required this.openOrdersByTableCode,
  });

  final List<FloorArea> areas;
  final List<RestaurantTable> tables;

  /// Open dine-in orders keyed by table CODE.
  ///
  /// Code rather than id because the list endpoint only sends the code; that is
  /// safe here because every request is branch-scoped, and codes are unique
  /// within a branch.
  final Map<String, OrderSummary> openOrdersByTableCode;

  List<RestaurantTable> tablesIn(String areaId) =>
      tables.where((t) => t.areaId == areaId).toList(growable: false);

  OrderSummary? orderFor(RestaurantTable table) =>
      openOrdersByTableCode[table.code];

  int get openOrderCount => openOrdersByTableCode.length;

  int get readyCount =>
      openOrdersByTableCode.values.where((o) => o.status.needsAttention).length;
}

class FloorRepository {
  FloorRepository(this._client);

  final ApiClient _client;

  /// One round trip each, issued concurrently — three sequential calls on a
  /// weak restaurant connection is a visibly slow floor screen.
  Future<FloorSnapshot> snapshot() async {
    final results = await Future.wait([
      _client.get(_client.branchScoped('/restaurant/areas')),
      _client.get(_client.branchScoped('/restaurant/tables')),
      _client.get(_client.branchScoped('/restaurant/orders')),
    ]);

    final areas = _list(results[0])
        .map(FloorArea.fromJson)
        .toList(growable: false)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final tables = _list(results[1])
        .map(RestaurantTable.fromJson)
        .where((t) => t.active)
        .toList(growable: false);

    final openOrders = <String, OrderSummary>{};
    for (final json in _list(results[2])) {
      final order = OrderSummary.fromJson(json);
      final code = order.tableCode;
      if (!order.status.isOpen || !order.isDineIn || code == null) continue;
      // If a table somehow has two open orders, prefer the one a waiter must
      // act on, so a READY ticket is never hidden behind a still-cooking one.
      final existing = openOrders[code];
      if (existing == null ||
          (order.status.needsAttention && !existing.status.needsAttention)) {
        openOrders[code] = order;
      }
    }

    return FloorSnapshot(
      areas: areas,
      tables: tables,
      openOrdersByTableCode: openOrders,
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

final floorRepositoryProvider = Provider<FloorRepository>(
  (ref) => FloorRepository(ref.watch(apiClientProvider)),
);

/// The floor, for the currently selected outlet.
///
/// Refreshed by pull-to-refresh today. Live updates arrive in Phase 5 via the
/// Socket.IO gateway (`restaurant.kds_ticket_ready.v1` et al) rather than
/// polling — building a poller now would only be deleted then.
final floorSnapshotProvider = FutureProvider.autoDispose<FloorSnapshot>(
  (ref) => ref.watch(floorRepositoryProvider).snapshot(),
);
