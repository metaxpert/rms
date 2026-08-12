import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';

void main() {
  /// The shape the shipped app read back from `GET /restaurant/orders/:id`.
  Map<String, dynamic> orderJson({
    String status = 'CONFIRMED',
    Object? totals,
    Object? items,
  }) =>
      {
        'id': 'o1',
        'orderNo': 'ORD-000004',
        'status': status,
        'channel': 'DINE_IN',
        'table': 'D1',
        'tableId': 't1',
        'branchId': 'b1',
        'guestCount': 2,
        'placedAt': '2026-08-13T09:15:00.000Z',
        'totals': totals ??
            const {
              'subtotal': {'amountMinor': 200000, 'currency': 'PKR'},
              'tax': {'amountMinor': 32000, 'currency': 'PKR'},
              'total': {'amountMinor': 232000, 'currency': 'PKR'},
            },
        'items': items ??
            const [
              {
                'id': 'line-1',
                'itemId': 'item-1',
                'name': 'Chicken Karahi',
                'qty': 2,
                'unitPrice': {'amountMinor': 100000, 'currency': 'PKR'},
                'lineTotal': {'amountMinor': 232000, 'currency': 'PKR'},
              },
            ],
      };

  group('OrderDetail parsing', () {
    test('reads the verified payload', () {
      final order = OrderDetail.fromJson(orderJson());

      expect(order.id, 'o1');
      expect(order.orderNo, 'ORD-000004');
      expect(order.status, OrderStatus.confirmed);
      expect(order.isDineIn, isTrue);
      expect(order.tableCode, 'D1');
      expect(order.tableId, 't1');
      expect(order.guestCount, 2);
      expect(order.totals.total, const Money(232000));
      expect(order.totals.subtotal, const Money(200000));
      expect(order.lines.single.name, 'Chicken Karahi');
      expect(order.itemCount, 2);
    });

    test('the line id is the ORDER line, not the menu item', () {
      // Deleting a line posts to /orders/:id/items/:lineId — sending the menu
      // item id there would remove the wrong thing, or nothing.
      final line = OrderDetail.fromJson(orderJson()).lines.single;
      expect(line.id, 'line-1');
      expect(line.itemId, 'item-1');
    });

    test('placedAt is converted to the tablet\'s local time', () {
      final order = OrderDetail.fromJson(orderJson());
      expect(order.placedAt, isNotNull);
      expect(order.placedAt!.isUtc, isFalse);
    });

    test('totals the server did not send read as zero, not a crash', () {
      // `serviceCharge`, `tip`, `discount` and `rounding` are absent on a plain
      // bill; an order screen that threw on that would be unusable.
      final order = OrderDetail.fromJson(orderJson());
      expect(order.totals.serviceCharge, Money.zero);
      expect(order.totals.tip, Money.zero);
      expect(order.totals.rounding, Money.zero);
      expect(order.totals.discount, Money.zero);
    });

    test('an order with no totals block still loads', () {
      final order = OrderDetail.fromJson(orderJson(totals: 'unexpected'));
      expect(order.totals.total, Money.zero);
    });

    test('an order with no lines yet is empty, not broken', () {
      final order = OrderDetail.fromJson(orderJson(items: const []));
      expect(order.lines, isEmpty);
      expect(order.itemCount, 0);
    });

    test('modifiers read whether they arrive as objects or names', () {
      final order = OrderDetail.fromJson(orderJson(items: const [
        {
          'id': 'l1',
          'name': 'Karahi',
          'qty': 1,
          'modifiers': [
            {'name': 'Extra spicy'},
            'No coriander',
            {'noName': true},
          ],
        },
      ]));
      expect(
        order.lines.single.modifierNames,
        ['Extra spicy', 'No coriander'],
      );
    });

    test('missing optional fields do not throw', () {
      final order = OrderDetail.fromJson(const {'id': 'o9'});
      expect(order.orderNo, '');
      expect(order.status, OrderStatus.unknown);
      expect(order.channel, 'DINE_IN');
      expect(order.tableCode, isNull);
      expect(order.lines, isEmpty);
    });
  });

  group('what the order permits', () {
    OrderDetail at(String status) =>
        OrderDetail.fromJson(orderJson(status: status));

    test('a DRAFT order is the only one that can be placed', () {
      expect(at('DRAFT').canPlace, isTrue);
      expect(at('DRAFT').isUnplaced, isTrue);
      for (final status in ['PLACED', 'CONFIRMED', 'READY', 'SETTLED']) {
        expect(at(status).canPlace, isFalse, reason: status);
      }
    });

    test('only a PLACED order can be confirmed', () {
      // On a tenant with autoFireKitchen, `place` lands straight in CONFIRMED
      // and this is never true — which is why the send flow treats an
      // already-confirmed order as success rather than as a failure.
      expect(at('PLACED').canConfirm, isTrue);
      expect(at('DRAFT').canConfirm, isFalse);
      expect(at('CONFIRMED').canConfirm, isFalse);
    });

    test('any open order takes another round', () {
      // A served table still orders coffee.
      for (final status in [
        'DRAFT',
        'PLACED',
        'CONFIRMED',
        'PREPARING',
        'READY',
        'SERVED',
      ]) {
        expect(at(status).canAddItems, isTrue, reason: status);
      }
    });

    test('a closed bill takes nothing more', () {
      for (final status in ['SETTLED', 'CANCELLED', 'VOID']) {
        expect(at(status).canAddItems, isFalse, reason: status);
        expect(at(status).isOpen, isFalse, reason: status);
      }
    });

    test('an unrecognised status is treated as closed', () {
      // Same reasoning as OrderSummary: offering actions on a status this build
      // does not understand would produce 422s a waiter cannot interpret.
      expect(at('ON_HOLD').canAddItems, isFalse);
    });

    test('knows when the kitchen has it', () {
      expect(at('CONFIRMED').isWithKitchen, isTrue);
      expect(at('PREPARING').isWithKitchen, isTrue);
      expect(at('READY').isWithKitchen, isTrue);
      expect(at('PLACED').isWithKitchen, isFalse);
      expect(at('SERVED').isWithKitchen, isFalse);
    });
  });
}
