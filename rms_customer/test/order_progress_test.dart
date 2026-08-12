import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_customer/src/features/orders/data/customer_order_repository.dart';
import 'package:rms_customer/src/features/tracking/application/order_progress.dart';

/// This is the screen a hungry person stares at. A step that lights up early is
/// somebody standing at their door for nothing; one that lights up late is
/// somebody phoning the restaurant. So every combination is pinned down.
void main() {
  TrackedOrder tracked({
    required String status,
    String channel = 'DELIVERY',
    String? deliveryStatus,
    int? etaMinutes,
  }) =>
      TrackedOrder(
        order: OrderDetail.fromJson({
          'id': 'o1',
          'orderNo': 'ORD-000021',
          'status': status,
          'channel': channel,
          'items': const [],
        }),
        delivery: deliveryStatus == null
            ? null
            : Delivery.fromJson({
                'id': 'd1',
                'orderId': 'o1',
                'status': deliveryStatus,
                'provider': 'OWN',
                'etaMinutes': etaMinutes,
              }),
      );

  int activeIndex(OrderProgress progress) =>
      progress.steps.indexWhere((step) => step.active);

  group('a delivery order', () {
    test('starts at "the restaurant has your order"', () {
      final progress = OrderProgress.of(tracked(status: 'PLACED'));
      expect(activeIndex(progress), 0);
      expect(progress.headline, 'The restaurant has your order.');
    });

    test('moves to cooking once the kitchen has it', () {
      for (final status in ['CONFIRMED', 'PREPARING']) {
        final progress = OrderProgress.of(tracked(status: status));
        expect(activeIndex(progress), 1, reason: status);
        expect(progress.headline, 'Your food is being cooked.');
      }
    });

    test('says the food is waiting for a rider when it is', () {
      final progress = OrderProgress.of(tracked(status: 'READY'));
      expect(activeIndex(progress), 2);
      expect(progress.headline, contains('waiting for a rider'));
    });

    test('the rider outranks the kitchen once they have the bag', () {
      // The kitchen's last word was READY, but the food has left the building.
      final progress = OrderProgress.of(
        tracked(status: 'READY', deliveryStatus: 'EN_ROUTE'),
      );
      expect(activeIndex(progress), 3);
    });

    test('gives an ETA when there is one, and no promise when there is not',
        () {
      expect(
        OrderProgress.of(tracked(
          status: 'SERVED',
          deliveryStatus: 'EN_ROUTE',
          etaMinutes: 12,
        )).headline,
        'On its way — about 12 minutes.',
      );
      expect(
        OrderProgress.of(
          tracked(status: 'SERVED', deliveryStatus: 'EN_ROUTE'),
        ).headline,
        'Your order is on its way.',
      );
    });

    test('a negative or zero ETA is not shown as a promise', () {
      // "about -3 minutes" is worse than saying nothing.
      final progress = OrderProgress.of(tracked(
        status: 'SERVED',
        deliveryStatus: 'EN_ROUTE',
        etaMinutes: -3,
      ));
      expect(progress.headline, 'Your order is on its way.');
    });

    test('finishes only when the rider says so', () {
      final progress = OrderProgress.of(
        tracked(status: 'SERVED', deliveryStatus: 'DELIVERED'),
      );
      expect(progress.headline, 'Delivered. Enjoy.');
      expect(progress.isFinished, isTrue);
    });

    test('a paid bill is not an arrived dinner', () {
      // SETTLED means the money is taken. For a delivery that is usually the
      // moment it was paid for, not the moment it reached the door.
      final progress = OrderProgress.of(
        tracked(status: 'SETTLED', deliveryStatus: 'EN_ROUTE'),
      );
      expect(progress.isFinished, isFalse);
      expect(activeIndex(progress), 3);
    });

    test('a failed delivery does not read as delivered', () {
      final progress = OrderProgress.of(
        tracked(status: 'READY', deliveryStatus: 'FAILED'),
      );
      // Back to what the kitchen knows; the restaurant is sorting it out.
      expect(progress.isFinished, isFalse);
      expect(activeIndex(progress), 2);
    });
  });

  group('a collection order', () {
    test('never mentions a rider', () {
      final progress = OrderProgress.of(
        tracked(status: 'READY', channel: 'TAKEAWAY'),
      );
      expect(progress.steps.map((s) => s.label), isNot(contains('On the way')));
      expect(progress.steps.map((s) => s.label), contains('Ready to collect'));
    });

    test('tells the customer to come to the counter once it is ready', () {
      final progress = OrderProgress.of(
        tracked(status: 'READY', channel: 'TAKEAWAY'),
      );
      expect(progress.headline, contains('come to the counter'));
      expect(progress.isFinished, isFalse);
    });

    test('handing it over is the end — nobody is carrying it anywhere', () {
      final progress = OrderProgress.of(
        tracked(status: 'SERVED', channel: 'TAKEAWAY'),
      );
      expect(progress.headline, 'Collected. Enjoy.');
      expect(progress.isFinished, isTrue);
    });

    test('has no step that can never light up', () {
      // "Ready" and "ready to collect" are the same fact to someone standing in
      // the restaurant, and a permanently dark step makes the rest look stalled.
      final progress = OrderProgress.of(
        tracked(status: 'READY', channel: 'TAKEAWAY'),
      );
      expect(progress.steps.length, 4);
    });

    test('a settled bill completes it', () {
      final progress = OrderProgress.of(
        tracked(status: 'SETTLED', channel: 'TAKEAWAY'),
      );
      expect(progress.isFinished, isTrue);
      expect(progress.headline, 'Collected. Enjoy.');
    });
  });

  group('when something goes wrong', () {
    test('a cancelled order says so and stops', () {
      for (final status in ['CANCELLED', 'VOID']) {
        final progress = OrderProgress.of(tracked(status: status));
        expect(progress.steps, isEmpty, reason: status);
        expect(progress.headline, contains('cancelled'));
        expect(progress.isFinished, isTrue);
      }
    });

    test('a status this build does not know does not skip ahead', () {
      // Lighting a later step than the order has earned is how a customer ends
      // up waiting at a door.
      final progress = OrderProgress.of(tracked(status: 'ON_HOLD'));
      expect(activeIndex(progress), 0);
    });
  });

  group('the words themselves', () {
    test('never show the backend\'s status names', () {
      // CONFIRMED means something precise to a kitchen and nothing to a guest.
      const wire = [
        'DRAFT',
        'PLACED',
        'CONFIRMED',
        'PREPARING',
        'READY',
        'SERVED',
        'SETTLED',
        'EN_ROUTE',
        'PICKED_UP',
      ];
      for (final status in ['PLACED', 'CONFIRMED', 'READY', 'SERVED']) {
        final progress = OrderProgress.of(tracked(status: status));
        final text =
            [progress.headline, ...progress.steps.map((s) => s.label)].join(' ');
        for (final name in wire) {
          expect(text, isNot(contains(name)), reason: '$status leaked $name');
        }
      }
    });

    test('exactly one step is active at a time', () {
      for (final status in ['PLACED', 'CONFIRMED', 'READY', 'SERVED']) {
        final progress = OrderProgress.of(tracked(status: status));
        expect(
          progress.steps.where((s) => s.active).length,
          1,
          reason: status,
        );
      }
    });

    test('everything before the active step is done, and nothing after', () {
      final progress = OrderProgress.of(
        tracked(status: 'SERVED', deliveryStatus: 'EN_ROUTE'),
      );
      final active = activeIndex(progress);
      for (var i = 0; i < progress.steps.length; i++) {
        expect(progress.steps[i].done, i < active, reason: 'step $i');
      }
    });
  });
}
