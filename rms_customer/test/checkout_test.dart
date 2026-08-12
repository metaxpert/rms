import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_customer/src/features/cart/application/cart_controller.dart';
import 'package:rms_customer/src/features/checkout/application/checkout_controller.dart';
import 'package:rms_customer/src/features/orders/data/customer_order_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Placing an order is three calls on a phone that can be locked, backgrounded
/// or killed between any two of them. The outcome to design against is a
/// customer being charged for two dinners.
class _FakeOrders implements CustomerOrderRepository {
  _FakeOrders();

  final calls = <String>[];
  final keys = <String, List<String>>{};
  final addressesSent = <String?>[];

  final failOnce = <String, ApiException>{};
  final failAlways = <String, ApiException>{};

  int get createCount => calls.where((c) => c == 'create').length;

  void _record(String step, String key) {
    calls.add(step);
    (keys[step] ??= []).add(key);
    final once = failOnce.remove(step);
    if (once != null) throw once;
    final always = failAlways[step];
    if (always != null) throw always;
  }

  @override
  Future<CreatedOrder> create({
    required OrderChannel channel,
    required String idempotencyKey,
    String? address,
  }) async {
    _record('create', idempotencyKey);
    addressesSent.add(address);
    return CreatedOrder(
      order: OrderDetail.fromJson({
        'id': 'order-1',
        'orderNo': 'ORD-000021',
        'status': 'DRAFT',
        'channel': channel.wire,
        'items': const [],
      }),
      addressAccepted: address != null && address.isNotEmpty,
    );
  }

  @override
  Future<void> addItems({
    required String orderId,
    required List<Map<String, dynamic>> items,
    required String idempotencyKey,
  }) async =>
      _record('addItems', idempotencyKey);

  @override
  Future<void> place({
    required String orderId,
    required String idempotencyKey,
  }) async =>
      _record('place', idempotencyKey);

  @override
  Future<OrderDetail> fetch(String orderId) async => throw UnimplementedError();

  @override
  Future<Delivery?> deliveryFor(String orderId) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const branchId = 'branch-1';

  const config = RestaurantConfig(
    currency: 'PKR',
    defaultTaxBp: 1600,
    serviceChargeBp: 0,
    roundingEnabled: true,
    tipEnabled: true,
    autoFireKitchen: true,
  );

  const naan = MenuItem(
    id: 'item-naan',
    name: 'Garlic Naan',
    price: Money(12000),
    available: true,
    status: 'ACTIVE',
    isCombo: false,
    prepMinutes: 4,
    categoryId: 'cat-breads',
    categoryName: 'Breads',
    taxBp: 1600,
  );

  Future<ProviderContainer> containerWith(
    _FakeOrders orders, {
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues({'branch_id': branchId, ...prefs});
    final session = await Session.load(secretStore: InMemorySecretStore());
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWithValue(session),
        sharedPreferencesProvider
            .overrideWithValue(await SharedPreferences.getInstance()),
        customerOrderRepositoryProvider.overrideWithValue(orders),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Cart cartWith(ProviderContainer container) {
    container.read(cartControllerProvider.notifier).add(naan, config);
    return container.read(cartControllerProvider);
  }

  group('the basket', () {
    test('prices with the same arithmetic the waiter uses', () async {
      // A guest quoted one figure here and charged another at the counter has
      // been misled; the two screens must not be allowed to drift.
      final container = await containerWith(_FakeOrders());
      final cart = cartWith(container);
      final totals = cart.totals(config);

      // 120.00 + 16% = 139.20, rounded to the rupee = 139.00.
      expect(totals.subtotal, const Money(12000));
      expect(totals.tax, const Money(1920));
      expect(totals.total, const Money(13900));
    });

    test('a second tap on the same dish is one line of two', () async {
      final container = await containerWith(_FakeOrders());
      final controller = container.read(cartControllerProvider.notifier)
        ..add(naan, config)
        ..add(naan, config);

      expect(controller.state.lines.length, 1);
      expect(controller.state.itemCount, 2);
    });

    test('reducing a line to nothing removes it', () async {
      final container = await containerWith(_FakeOrders());
      final controller = container.read(cartControllerProvider.notifier)
        ..add(naan, config)
        ..setQty(0, 0);

      expect(controller.state.isEmpty, isTrue);
    });

    test('survives the app being closed', () async {
      final container = await containerWith(_FakeOrders());
      container.read(cartControllerProvider.notifier).add(naan, config);

      // A phone that rings, sleeps or dies mid-browse must not cost a customer
      // their choices.
      final store = container.read(cartStoreProvider);
      final restored = store.read(branchId, DateTime.now());
      expect(restored!.lines.single.itemId, 'item-naan');
    });

    test('a basket from another restaurant is not carried over', () async {
      // Its prices, menu and tax may all be different.
      final container = await containerWith(_FakeOrders());
      final store = container.read(cartStoreProvider);
      container.read(cartControllerProvider.notifier).add(naan, config);

      expect(store.read('another-branch', DateTime.now()), isNull);
    });

    test('a basket from days ago is discarded', () async {
      final stale = Cart(
        branchId: branchId,
        lines: [DraftLine.fromMenuItem(naan, config: config)],
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      );
      final container = await containerWith(_FakeOrders(), prefs: {
        CartStore.keyFor(branchId): jsonEncode(stale.toJson()),
      });

      expect(container.read(cartControllerProvider).isEmpty, isTrue);
    });
  });

  group('placing an order', () {
    test('creates, adds the items, then tells the restaurant', () async {
      final orders = _FakeOrders();
      final container = await containerWith(orders);
      final cart = cartWith(container);

      await container.read(checkoutControllerProvider.notifier).place(
            cart: cart,
            channel: OrderChannel.takeaway,
          );

      expect(orders.calls, ['create', 'addItems', 'place']);
      final state = container.read(checkoutControllerProvider);
      expect(state.phase, CheckoutPhase.placed);
      expect(state.orderId, 'order-1');
    });

    test('empties the basket once the restaurant has it', () async {
      final orders = _FakeOrders();
      final container = await containerWith(orders);
      final cart = cartWith(container);

      await container
          .read(checkoutControllerProvider.notifier)
          .place(cart: cart, channel: OrderChannel.takeaway);

      // Keeping it would offer to order the same dinner again.
      expect(container.read(cartControllerProvider).isEmpty, isTrue);
    });

    test('a second tap does not order two dinners', () async {
      final orders = _FakeOrders()
        ..failOnce['place'] = ApiException(ApiErrorKind.network, 'No signal.');
      final container = await containerWith(orders);
      final cart = cartWith(container);
      final controller = container.read(checkoutControllerProvider.notifier);

      await controller.place(cart: cart, channel: OrderChannel.takeaway);
      expect(container.read(checkoutControllerProvider).phase,
          CheckoutPhase.failed);

      await controller.place(cart: cart, channel: OrderChannel.takeaway);

      expect(orders.createCount, 1);
      expect(container.read(checkoutControllerProvider).phase,
          CheckoutPhase.placed);
    });

    test('a retry replays the original request rather than claiming a new key',
        () async {
      final orders = _FakeOrders()
        ..failOnce['place'] = ApiException(ApiErrorKind.network, 'No signal.');
      final container = await containerWith(orders);
      final cart = cartWith(container);
      final controller = container.read(checkoutControllerProvider.notifier);

      await controller.place(cart: cart, channel: OrderChannel.takeaway);
      await controller.place(cart: cart, channel: OrderChannel.takeaway);

      final used = orders.keys['place']!;
      expect(used.length, 2);
      expect(used.first, used.last);
    });

    test('an attempt cut off by the app closing is found again', () async {
      const pending = PendingCheckout(
        branchId: branchId,
        key: 'abc',
        stage: CheckoutStage.placing,
        items: [
          {'itemId': 'item-naan', 'qty': 1},
        ],
        channel: OrderChannel.takeaway,
        orderId: 'order-1',
      );
      final orders = _FakeOrders();
      final container = await containerWith(orders, prefs: {
        'checkout:$branchId': jsonEncode(pending.toJson()),
      });

      final state = container.read(checkoutControllerProvider);
      expect(state.phase, CheckoutPhase.failed);
      expect(state.orderExists, isTrue,
          reason: 'saying "nothing was ordered" would be a guess');

      await container.read(checkoutControllerProvider.notifier).place(
            cart: container.read(cartControllerProvider),
            channel: OrderChannel.takeaway,
          );

      expect(orders.calls, ['place'],
          reason: 'the order and its items were already accepted');
    });

    test('a failure is reported without losing the basket', () async {
      final orders = _FakeOrders()
        ..failAlways['addItems'] =
            ApiException(ApiErrorKind.server, 'Kitchen system is down.');
      final container = await containerWith(orders);
      final cart = cartWith(container);

      await container
          .read(checkoutControllerProvider.notifier)
          .place(cart: cart, channel: OrderChannel.takeaway);

      final state = container.read(checkoutControllerProvider);
      expect(state.phase, CheckoutPhase.failed);
      expect(state.error!.message, 'Kitchen system is down.');
      expect(container.read(cartControllerProvider).isEmpty, isFalse);
    });

    test('an empty basket is not sent at all', () async {
      final orders = _FakeOrders();
      final container = await containerWith(orders);

      await container.read(checkoutControllerProvider.notifier).place(
            cart: container.read(cartControllerProvider),
            channel: OrderChannel.takeaway,
          );

      expect(orders.calls, isEmpty);
    });
  });

}
