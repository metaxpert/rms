import 'package:flutter/material.dart';

import 'package:rms_core/rms_core.dart';
import '../../orders/data/customer_order_repository.dart';

/// One rung of the progress the customer sees.
@immutable
class ProgressStep {
  const ProgressStep({
    required this.label,
    required this.icon,
    required this.done,
    required this.active,
  });

  final String label;
  final IconData icon;

  /// Already happened.
  final bool done;

  /// Happening now — the one line the customer's eye should land on.
  final bool active;
}

/// Turns the backend's vocabulary into the four or five things a customer
/// actually wants to know.
///
/// This is a deliberate translation, not a renaming of statuses: `CONFIRMED`
/// means something precise to a kitchen and nothing to a guest, while "being
/// cooked" is what they are waiting to hear. The backend's names are never
/// shown; they are mapped here in one place so no screen invents its own.
///
/// It is a pure function of (order status, delivery status) so it can be tested
/// exhaustively — this is the screen a customer stares at, and a step that
/// lights up early is a customer standing at a door for nothing.
class OrderProgress {
  const OrderProgress._(this.steps, this.headline, this.isFinished);

  final List<ProgressStep> steps;

  /// The single sentence at the top.
  final String headline;

  final bool isFinished;

  static OrderProgress of(TrackedOrder tracked) {
    final order = tracked.order;
    final delivery = tracked.delivery;
    final isDelivery = order.channel == OrderChannel.delivery.wire;

    if (order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.voided) {
      return const OrderProgress._(
        [],
        'This order was cancelled. If that is unexpected, call the restaurant.',
        true,
      );
    }

    final stage = isDelivery
        ? _deliveryStage(order, delivery)
        : _collectionStage(order);

    // Two different ladders, because they are two different journeys. A
    // collection order has no "on the way" — for a guest standing in the
    // restaurant, "ready" and "ready to collect" are the same fact, and a step
    // that can never light up is a step that makes the rest look stalled.
    final labels = isDelivery
        ? const <(String, IconData)>[
            ('Order received', Icons.receipt_long_rounded),
            ('Being cooked', Icons.local_fire_department_rounded),
            ('Ready', Icons.room_service_rounded),
            ('On the way', Icons.two_wheeler_rounded),
            ('Delivered', Icons.check_circle_rounded),
          ]
        : const <(String, IconData)>[
            ('Order received', Icons.receipt_long_rounded),
            ('Being cooked', Icons.local_fire_department_rounded),
            ('Ready to collect', Icons.shopping_bag_rounded),
            ('Collected', Icons.check_circle_rounded),
          ];

    return OrderProgress._(
      [
        for (var index = 0; index < labels.length; index++)
          ProgressStep(
            label: labels[index].$1,
            icon: labels[index].$2,
            done: index < stage,
            active: index == stage,
          ),
      ],
      _headline(stage, isDelivery: isDelivery, delivery: delivery),
      stage >= labels.length - 1,
    );
  }

  /// 0 received · 1 cooking · 2 ready · 3 on the way · 4 delivered
  ///
  /// The delivery's own status outranks the order's whenever there is one: once
  /// a rider has the bag, where the bag is matters more than what the kitchen
  /// last recorded.
  static int _deliveryStage(OrderDetail order, Delivery? delivery) {
    switch (delivery?.status) {
      case DeliveryStatus.delivered:
        return 4;
      case DeliveryStatus.pickedUp:
      case DeliveryStatus.enRoute:
        return 3;
      case DeliveryStatus.failed:
      case DeliveryStatus.cancelled:
      // Fall through to the order's own view: the restaurant will be sorting
      // it out, and the customer must not be told "delivered".
      default:
        break;
    }

    return switch (order.status) {
      // Never 4 without a rider saying so. On a delivery, "settled" usually
      // means paid, not arrived — and telling someone their dinner has been
      // delivered when it is still on a bike is the worst lie this screen has.
      OrderStatus.settled || OrderStatus.served => 3,
      OrderStatus.ready => 2,
      OrderStatus.preparing || OrderStatus.confirmed => 1,
      // An unrecognised status must not light a later step than it has earned.
      _ => 0,
    };
  }

  /// 0 received · 1 cooking · 2 ready to collect · 3 collected
  static int _collectionStage(OrderDetail order) => switch (order.status) {
        // Nobody is carrying it anywhere: handed over is the end.
        OrderStatus.settled || OrderStatus.served => 3,
        OrderStatus.ready => 2,
        OrderStatus.preparing || OrderStatus.confirmed => 1,
        _ => 0,
      };

  static String _headline(
    int stage, {
    required bool isDelivery,
    required Delivery? delivery,
  }) {
    if (stage == 0) return 'The restaurant has your order.';
    if (stage == 1) return 'Your food is being cooked.';

    if (!isDelivery) {
      return stage == 2
          ? 'Ready to collect — come to the counter.'
          : 'Collected. Enjoy.';
    }

    switch (stage) {
      case 2:
        return 'Your food is ready and waiting for a rider.';
      case 3:
        final eta = delivery?.etaMinutes;
        // "about -3 minutes" is worse than saying nothing at all.
        return eta == null || eta <= 0
            ? 'Your order is on its way.'
            : 'On its way — about $eta minutes.';
      default:
        return 'Delivered. Enjoy.';
    }
  }
}
