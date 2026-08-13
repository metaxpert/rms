import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_waiter/src/features/bill/application/settle_controller.dart';
import 'package:rms_waiter/src/features/orders/data/order_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rms_waiter/src/l10n/app_localizations_en.dart';

import 'support/fake_order_server.dart';

/// Settling moves stock, captures COGS and posts a balanced GL journal in one
/// transaction. A duplicate posts the sale twice, and a bill that does not
/// reconcile is refused — so these tests are about exactly two things: charging
/// once, and charging the right amount.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The English catalogue: the controller needs one for its two refusal
  // messages, and English is what these assertions read.
  final text = AppTextEn();

  const branchId = 'branch-1';
  const orderId = 'order-1';

  Future<ProviderContainer> containerWith(FakeOrderServer server) async {
    SharedPreferences.setMockInitialValues({'branch_id': branchId});
    final session = await Session.load(secretStore: InMemorySecretStore());
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWithValue(session),
        sharedPreferencesProvider
            .overrideWithValue(await SharedPreferences.getInstance()),
        orderRepositoryProvider.overrideWithValue(server),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// A confirmed bill for 1,531.00 sitting on a table.
  Future<(ProviderContainer, FakeOrderServer, OrderDetail)> billFor(
    int totalMinor,
  ) async {
    final server = FakeOrderServer();
    final order = OrderDetail.fromJson({
      'id': orderId,
      'orderNo': 'ORD-000009',
      'status': 'SERVED',
      'channel': 'DINE_IN',
      'table': 'D1',
      'tableId': 'table-1',
      'totals': {
        'total': {'amountMinor': totalMinor, 'currency': 'PKR'},
      },
      'items': const [],
    });
    server.seed(order);
    return (await containerWith(server), server, order);
  }

  SettleController controllerIn(ProviderContainer container) =>
      container.read(settleControllerProvider(orderId).notifier);

  SettleState stateIn(ProviderContainer container) =>
      container.read(settleControllerProvider(orderId));

  group('composing the tender', () {
    test('defaults to the whole bill in cash', () async {
      final (container, _, order) = await billFor(153100);
      final tender = stateIn(container).tenderFor(order.totals.total);

      expect(tender.payments.single.method, PaymentMethod.cash);
      expect(tender.isBalanced, isTrue);
    });

    test('splitting three ways still adds up to the bill', () async {
      final (container, _, order) = await billFor(100000);
      controllerIn(container).splitEvenly(3, order.totals.total);

      final tender = stateIn(container).tenderFor(order.totals.total);
      expect(tender.taken, order.totals.total);
      expect(tender.isBalanced, isTrue);
    });

    test('another payment carries whatever is left', () async {
      final (container, _, order) = await billFor(100000);
      final due = order.totals.total;
      final controller = controllerIn(container);

      // The guest pays 600 in cash and asks to put the rest on a card.
      controller.setAmount(0, const Money(60000), due);
      controller.addPayment(due);

      final tender = stateIn(container).tenderFor(due);
      expect(tender.payments.last.amount, const Money(40000));
      expect(tender.isBalanced, isTrue,
          reason: 'a waiter with a queue behind them should not do arithmetic');
    });

    test('the last payment cannot be removed', () async {
      final (container, _, order) = await billFor(100000);
      controllerIn(container).removePayment(0, order.totals.total);

      expect(
        stateIn(container).tenderFor(order.totals.total).payments.length,
        1,
        reason: 'a bill with no tender at all cannot be settled',
      );
    });

    test('a tender for a different total is discarded', () async {
      // Another round landed while the bill screen was open; a tender composed
      // against the old total would settle short.
      final (container, _, order) = await billFor(100000);
      controllerIn(container).splitEvenly(2, order.totals.total);

      final tender = stateIn(container).tenderFor(const Money(150000));
      expect(tender.due, const Money(150000));
      expect(tender.isBalanced, isTrue);
      expect(tender.payments.length, 1);
    });

    test('change is worked out but never sent', () async {
      final (container, server, order) = await billFor(153100);
      final controller = controllerIn(container)
        ..setCashReceived(const Money(200000));

      final tender = stateIn(container).tenderFor(order.totals.total);
      expect(stateIn(container).changeFor(tender), const Money(46900));

      await controller.settle(order, text);

      // The server is told what was applied to the bill, not the note handed
      // over — otherwise the sale posts larger than the bill.
      expect(server.settlements.single.single.amount, const Money(153100));
    });

    test('an under-tender is not sent to the server at all', () async {
      final (container, server, order) = await billFor(100000);
      final controller = controllerIn(container)
        ..setAmount(0, const Money(60000), order.totals.total);

      await controller.settle(order, text);

      expect(server.settlements, isEmpty);
      expect(stateIn(container).phase, SettlePhase.failed);
      expect(stateIn(container).error!.message, contains('Rs 400.00 short'));
    });
  });

  group('settling', () {
    test('closes the bill and reports the settled order', () async {
      final (container, server, order) = await billFor(153100);

      await controllerIn(container).settle(order, text);

      expect(server.settlements.length, 1);
      expect(stateIn(container).phase, SettlePhase.settled);
      expect(stateIn(container).order!.status, OrderStatus.settled);
    });

    test('sends the split as separate payments on one bill', () async {
      final (container, server, order) = await billFor(100000);
      final controller = controllerIn(container)
        ..splitEvenly(3, order.totals.total);

      await controller.settle(order, text);

      final sent = server.settlements.single;
      expect(sent.length, 3);
      expect(
        sent.fold(Money.zero, (Money sum, p) => sum + p.amount),
        const Money(100000),
      );
    });

    test('a retry replays instead of charging twice', () async {
      final (container, server, order) = await billFor(153100);
      final controller = controllerIn(container);

      await controller.settle(order, text);
      await controller.settle(order, text);

      expect(server.settlements.length, 1,
          reason: 'a second charge is the worst outcome this screen has');
      expect(stateIn(container).phase, SettlePhase.settled);
    });

    test('an identical tender produces an identical idempotency key', () async {
      // The key is derived rather than stored, so it is the same after the app
      // has been killed and reopened — where a key held in memory would not be.
      final (container, server, order) = await billFor(100000);
      controllerIn(container).splitEvenly(2, order.totals.total);
      await controllerIn(container).settle(order, text);

      final firstKey = server.keys['settle']!.single;

      final (container2, server2, order2) = await billFor(100000);
      controllerIn(container2).splitEvenly(2, order2.totals.total);
      await controllerIn(container2).settle(order2, text);

      expect(server2.keys['settle']!.single, firstKey);
    });

    test('a bill closed on another till reads as settled, not as an error',
        () async {
      final (container, server, order) = await billFor(153100);
      // Another till got there first.
      server.seed(OrderDetail.fromJson(const {
        'id': orderId,
        'status': 'SETTLED',
        'channel': 'DINE_IN',
        'totals': {
          'total': {'amountMinor': 153100, 'currency': 'PKR'},
        },
        'items': [],
      }));

      await controllerIn(container).settle(order, text);

      // The money is taken and the guest can go. Reporting a failure would
      // send a waiter to charge a second time.
      expect(stateIn(container).phase, SettlePhase.settled);
      expect(server.settlements, isEmpty);
    });

    test('a genuine failure is surfaced with what the server said', () async {
      final (container, server, order) = await billFor(153100);
      server.failAlways['settle'] =
          ApiException(ApiErrorKind.server, 'Ledger service unavailable.');

      await controllerIn(container).settle(order, text);

      expect(stateIn(container).phase, SettlePhase.failed);
      expect(stateIn(container).error!.message, 'Ledger service unavailable.');
    });

    test('a failure the app cannot classify does not claim success', () async {
      // The settle failed AND the confirming read failed. Assuming it worked
      // would leave an unpaid table looking closed.
      final (container, server, order) = await billFor(153100);
      server.failAlways['settle'] =
          ApiException(ApiErrorKind.network, 'Wifi dropped.');
      server.failAlways['fetch'] =
          ApiException(ApiErrorKind.network, 'Wifi dropped.');

      await controllerIn(container).settle(order, text);

      expect(stateIn(container).phase, SettlePhase.failed);
    });
  });

  group('printing', () {
    test('a first print is idempotent and a reprint is not', () async {
      // Two slips for one tap is a real cost in paper and confusion; a reprint
      // asked for twice is two slips on purpose.
      final (container, server, _) = await billFor(153100);
      final orders = container.read(orderRepositoryProvider);

      await orders.queuePrint(orderId: orderId, idempotencyKey: 'print:$orderId');
      await orders.queuePrint(orderId: orderId, reprint: true);

      expect(server.printJobs, [false, true]);
      expect(server.keys['print']!.first, 'print:$orderId');
      expect(server.keys['print']!.last, isNull);
    });
  });
}
