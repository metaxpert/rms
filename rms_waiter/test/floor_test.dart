import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_waiter/src/features/floor/data/floor_repository.dart';

void main() {
  group('TableStatus wire mapping', () {
    test('maps every backend value', () {
      expect(TableStatus.fromWire('AVAILABLE'), TableStatus.available);
      expect(TableStatus.fromWire('RESERVED'), TableStatus.reserved);
      expect(TableStatus.fromWire('WAITING'), TableStatus.waiting);
      expect(TableStatus.fromWire('OCCUPIED'), TableStatus.occupied);
      expect(TableStatus.fromWire('CLEANING'), TableStatus.cleaning);
    });

    test('an unrecognised status degrades instead of crashing the floor', () {
      // A status added server-side later must not take the floor screen down
      // in the middle of service.
      expect(TableStatus.fromWire('SANITISING'), TableStatus.unknown);
      expect(TableStatus.fromWire(null), TableStatus.unknown);
    });
  });

  group('table transitions mirror the backend state machine', () {
    test('legal moves', () {
      expect(
        canTransitionTable(TableStatus.available, TableStatus.occupied),
        isTrue,
      );
      expect(
        canTransitionTable(TableStatus.occupied, TableStatus.cleaning),
        isTrue,
      );
      expect(
        canTransitionTable(TableStatus.cleaning, TableStatus.available),
        isTrue,
      );
    });

    test('illegal jumps are refused', () {
      // Seating a table straight out of cleaning skips the reset the backend
      // requires; the server rejects it, so the UI must not offer it.
      expect(
        canTransitionTable(TableStatus.cleaning, TableStatus.occupied),
        isFalse,
      );
      expect(
        canTransitionTable(TableStatus.occupied, TableStatus.reserved),
        isFalse,
      );
    });

    test('same-status is always allowed', () {
      expect(
        canTransitionTable(TableStatus.occupied, TableStatus.occupied),
        isTrue,
      );
    });

    test('an unknown source defers to the server rather than blocking staff',
        () {
      expect(
        canTransitionTable(TableStatus.unknown, TableStatus.occupied),
        isTrue,
      );
    });
  });

  group('OrderStatus.isOpen', () {
    test('live statuses are open', () {
      for (final status in [
        OrderStatus.draft,
        OrderStatus.placed,
        OrderStatus.confirmed,
        OrderStatus.inProgress,
        OrderStatus.ready,
        OrderStatus.served,
      ]) {
        expect(status.isOpen, isTrue, reason: '${status.wire} should be open');
      }
    });

    test('terminal statuses are not open', () {
      for (final status in [
        OrderStatus.settled,
        OrderStatus.cancelled,
        OrderStatus.voided,
      ]) {
        expect(status.isOpen, isFalse,
            reason: '${status.wire} should be closed');
      }
    });

    test('unknown is treated as closed, not open', () {
      // Showing a phantom bill on a free table is worse than missing a badge.
      expect(OrderStatus.unknown.isOpen, isFalse);
    });

    test('only READY demands attention', () {
      expect(OrderStatus.ready.needsAttention, isTrue);
      expect(OrderStatus.inProgress.needsAttention, isFalse);
      expect(OrderStatus.served.needsAttention, isFalse);
    });
  });

  group('RestaurantTable parsing', () {
    Map<String, dynamic> tableJson({
      Object? position,
      String status = 'OCCUPIED',
      Object? mergedIntoId,
    }) =>
        {
          'id': 't1',
          'areaId': 'a1',
          'area': 'DHA Hall',
          'branchId': 'b1',
          'code': 'D1',
          'capacity': 6,
          'shape': 'RECT',
          'status': status,
          'active': true,
          'position': position,
          'mergedIntoId': mergedIntoId,
        };

    test('reads the verified payload', () {
      final table = RestaurantTable.fromJson(tableJson(
        position: {'x': 24, 'y': 24, 'width': 88, 'height': 64, 'rotation': 0},
      ));

      expect(table.code, 'D1');
      expect(table.capacity, 6);
      expect(table.areaName, 'DHA Hall');
      expect(table.status, TableStatus.occupied);
      expect(table.position!.x, 24);
      expect(table.position!.width, 88);
      expect(table.isOperable, isTrue);
    });

    test('accepts ints or doubles for coordinates', () {
      // Designer drags produce doubles; seeded fixtures produce ints.
      final table = RestaurantTable.fromJson(tableJson(
        position: {'x': 24.5, 'y': 10, 'width': 88.25, 'height': 64},
      ));
      expect(table.position!.x, 24.5);
      expect(table.position!.width, 88.25);
      expect(table.position!.rotation, 0, reason: 'missing rotation defaults');
    });

    test('a table with no position still loads (grid fallback)', () {
      final table = RestaurantTable.fromJson(tableJson(position: null));
      expect(table.position, isNull);
      expect(table.code, 'D1');
    });

    test('a merged table is not independently operable', () {
      final table = RestaurantTable.fromJson(tableJson(mergedIntoId: 't2'));
      expect(table.isMerged, isTrue);
      expect(table.isOperable, isFalse);
    });

    test('missing optional fields do not throw', () {
      final table = RestaurantTable.fromJson(const {'id': 't9'});
      expect(table.code, '?');
      expect(table.capacity, 0);
      expect(table.status, TableStatus.unknown);
    });
  });

  group('OrderSummary parsing', () {
    test('reads the verified list payload', () {
      final order = OrderSummary.fromJson(const {
        'id': 'o1',
        'orderNo': 'ORD-000004',
        'branchId': 'b1',
        'channel': 'DINE_IN',
        'status': 'CONFIRMED',
        'table': 'D1',
        'guestCount': 2,
        'itemCount': 2,
        'total': {'amountMinor': 168200, 'currency': 'PKR'},
      });

      expect(order.orderNo, 'ORD-000004');
      expect(order.tableCode, 'D1');
      expect(order.isDineIn, isTrue);
      expect(order.status, OrderStatus.confirmed);
      expect(order.total, const Money(168200));
      expect(order.total.display, 'Rs 1,682.00');
    });

    test('a delivery order carries no table', () {
      final order = OrderSummary.fromJson(const {
        'id': 'o2',
        'channel': 'DELIVERY',
        'status': 'CONFIRMED',
        'table': null,
        'total': {'amountMinor': 46400, 'currency': 'PKR'},
      });
      expect(order.tableCode, isNull);
      expect(order.isDineIn, isFalse);
    });

    test('a missing total is zero rather than a crash', () {
      final order = OrderSummary.fromJson(const {'id': 'o3'});
      expect(order.total, Money.zero);
    });
  });

  group('FloorSnapshot', () {
    RestaurantTable table(String code, String areaId) =>
        RestaurantTable.fromJson({
          'id': 'id-$code',
          'areaId': areaId,
          'area': 'Hall',
          'branchId': 'b1',
          'code': code,
          'capacity': 4,
          'shape': 'RECT',
          'status': 'OCCUPIED',
          'active': true,
        });

    OrderSummary order(String code, String status) => OrderSummary.fromJson({
          'id': 'o-$code-$status',
          'channel': 'DINE_IN',
          'status': status,
          'table': code,
          'total': const {'amountMinor': 1000, 'currency': 'PKR'},
        });

    test('filters tables by area', () {
      final floor = FloorSnapshot(
        areas: const [],
        tables: [table('A1', 'area-1'), table('B1', 'area-2')],
        openOrdersByTableCode: const {},
      );
      expect(floor.tablesIn('area-1').single.code, 'A1');
    });

    test('joins an open order to its table by code', () {
      final floor = FloorSnapshot(
        areas: const [],
        tables: [table('A1', 'area-1')],
        openOrdersByTableCode: {'A1': order('A1', 'READY')},
      );
      expect(floor.orderFor(table('A1', 'area-1'))!.status, OrderStatus.ready);
      expect(floor.orderFor(table('Z9', 'area-1')), isNull);
    });

    test('counts open bills and tickets needing service', () {
      final floor = FloorSnapshot(
        areas: const [],
        tables: const [],
        openOrdersByTableCode: {
          'A1': order('A1', 'READY'),
          'A2': order('A2', 'IN_PROGRESS'),
          'A3': order('A3', 'READY'),
        },
      );
      expect(floor.openOrderCount, 3);
      expect(floor.readyCount, 2);
    });
  });
}
