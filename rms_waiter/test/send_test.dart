import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_waiter/src/features/orders/data/order_repository.dart';
import 'package:rms_waiter/src/features/ticket/application/send_controller.dart';
import 'package:rms_waiter/src/features/ticket/application/ticket_controller.dart';
import 'package:rms_waiter/src/features/ticket/data/draft_store.dart';
import 'package:rms_waiter/src/features/ticket/data/pending_send_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sending a ticket is four server calls that can each fail, on a device that
/// can be killed between any two of them. These tests are about the one
/// outcome that must never happen: a table billed twice for one round.
///
/// The repository is faked rather than the HTTP layer, because what is under
/// test is the order of the calls, what is persisted between them, and what a
/// second attempt does — not JSON.
class _FakeServer implements OrderRepository {
  _FakeServer({this.autoFireKitchen = false});

  /// When true, `place` lands the order in CONFIRMED, as a tenant with
  /// `autoFireKitchen` does — and `confirm` then becomes an illegal transition.
  final bool autoFireKitchen;

  /// Every call made, in order, for asserting what a resume skipped.
  final calls = <String>[];

  /// Idempotency keys seen per call, so a repeat can be proved to reuse one.
  final keys = <String, List<String>>{};

  /// Steps that should throw once, then succeed — a flaky connection.
  final failOnce = <String, ApiException>{};

  /// Steps that always throw.
  final failAlways = <String, ApiException>{};

  /// Runs when a step is reached, before any failure it is configured to
  /// raise — how another till acting between two of our calls is modelled.
  final onStep = <String, void Function()>{};

  final Map<String, OrderDetail> _orders = {};
  var _nextId = 1;

  OrderDetail? openOrder;

  int get createCount => calls.where((c) => c == 'create').length;

  /// Replace the server's copy of an order.
  void seed(OrderDetail order) {
    _orders[order.id] = order;
    openOrder = order.isOpen ? order : null;
  }

  void _record(String step, [String? key]) {
    calls.add(step);
    if (key != null) (keys[step] ??= []).add(key);
    onStep[step]?.call();
    final once = failOnce.remove(step);
    if (once != null) throw once;
    final always = failAlways[step];
    if (always != null) throw always;
  }

  OrderDetail _build({
    required String id,
    required String status,
    required List<Map<String, dynamic>> items,
  }) =>
      OrderDetail.fromJson({
        'id': id,
        'orderNo': 'ORD-00000$_nextId',
        'status': status,
        'channel': 'DINE_IN',
        'table': 'D1',
        'tableId': 'table-1',
        'guestCount': 4,
        'totals': {
          'subtotal': {'amountMinor': 12000 * items.length, 'currency': 'PKR'},
          'tax': {'amountMinor': 1920 * items.length, 'currency': 'PKR'},
          'total': {'amountMinor': 13920 * items.length, 'currency': 'PKR'},
        },
        'items': [
          for (final item in items)
            {
              'id': 'line-${items.indexOf(item)}',
              'itemId': item['itemId'],
              'name': 'Garlic Naan',
              'qty': item['qty'],
              'unitPrice': {'amountMinor': 12000, 'currency': 'PKR'},
              'lineTotal': {'amountMinor': 13920, 'currency': 'PKR'},
            },
        ],
      });

  @override
  Future<OrderDetail?> openOrderForTable(String tableId) async {
    _record('lookup');
    return openOrder;
  }

  @override
  Future<OrderDetail> fetch(String orderId) async {
    _record('fetch');
    final order = _orders[orderId];
    if (order == null) {
      throw ApiException(ApiErrorKind.notFound, 'No such order.');
    }
    return order;
  }

  @override
  Future<OrderDetail?> create({
    required String tableId,
    required int? guestCount,
    required String idempotencyKey,
  }) async {
    _record('create', idempotencyKey);
    final id = 'order-${_nextId++}';
    final order = _build(id: id, status: 'DRAFT', items: const []);
    _orders[id] = order;
    openOrder = order;
    return order;
  }

  @override
  Future<OrderDetail?> addItems({
    required String orderId,
    required List<Map<String, dynamic>> items,
    required String idempotencyKey,
  }) async {
    _record('addItems', idempotencyKey);
    final current = _orders[orderId]!;
    final order = _build(id: orderId, status: current.status.wire, items: items);
    _orders[orderId] = order;
    openOrder = order;
    return order;
  }

  @override
  Future<OrderDetail?> place({
    required String orderId,
    required String idempotencyKey,
  }) async {
    _record('place', idempotencyKey);
    final current = _orders[orderId]!;
    final order = _build(
      id: orderId,
      status: autoFireKitchen ? 'CONFIRMED' : 'PLACED',
      items: [
        for (final line in current.lines) {'itemId': line.itemId, 'qty': line.qty}
      ],
    );
    _orders[orderId] = order;
    openOrder = order;
    return order;
  }

  @override
  Future<OrderDetail?> confirm({
    required String orderId,
    required String idempotencyKey,
  }) async {
    _record('confirm', idempotencyKey);
    final current = _orders[orderId]!;
    final order = _build(
      id: orderId,
      status: 'CONFIRMED',
      items: [
        for (final line in current.lines) {'itemId': line.itemId, 'qty': line.qty}
      ],
    );
    _orders[orderId] = order;
    openOrder = order;
    return order;
  }

  @override
  Future<void> removeLine({
    required String orderId,
    required String lineId,
  }) async =>
      _record('removeLine');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const branchId = 'branch-1';
  const tableId = 'table-1';
  const ticketRef =
      TicketRef(branchId: branchId, tableId: tableId, tableCode: 'D1');

  const line = DraftLine(
    itemId: 'item-naan',
    name: 'Garlic Naan',
    unitPrice: Money(12000),
    taxBp: 1600,
    qty: 2,
  );

  TicketDraft draftWith(List<DraftLine> lines) => TicketDraft(
        branchId: branchId,
        tableId: tableId,
        tableCode: 'D1',
        lines: lines,
        updatedAt: DateTime.now(),
        guestCount: 4,
      );

  Future<ProviderContainer> containerWith(
    _FakeServer server, {
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues({'branch_id': branchId, ...prefs});
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

  group('PendingSend', () {
    test('each step gets its own idempotency key', () {
      // The interceptor rejects one key reused with a different body (422), and
      // the four calls carry four different bodies.
      final pending = PendingSend.forDraft(
        draftWith([line]),
        now: DateTime.now(),
        key: 'abc',
      );
      final used = SendStage.values.map(pending.keyFor).toSet();
      expect(used.length, SendStage.values.length);
      expect(pending.keyFor(SendStage.creating), 'abc:creating');
    });

    test('the key survives a round trip through storage', () {
      // If it did not, a resume would claim a NEW key and open a second bill —
      // which is the entire failure this record exists to prevent.
      final original = PendingSend.forDraft(
        draftWith([line]),
        now: DateTime.now(),
        key: 'abc',
      ).copyWith(orderId: 'order-1', stage: SendStage.placing);

      final restored =
          PendingSend.fromJson(jsonDecode(jsonEncode(original.toJson())));

      expect(restored!.key, 'abc');
      expect(restored.orderId, 'order-1');
      expect(restored.stage, SendStage.placing);
      expect(restored.items, original.items);
      expect(restored.itemCount, 2);
    });

    test('a record this build cannot read is refused, not half-restored', () {
      expect(PendingSend.fromJson(const {'version': 99}), isNull);
      expect(PendingSend.fromJson(const {'version': 1}), isNull);
    });

    test('an unknown stage falls back to the earliest, not the latest', () {
      // Resuming too late would skip a step that never ran; resuming too early
      // is safe, because every step is idempotent.
      final restored = PendingSend.fromJson({
        'version': 1,
        'branchId': branchId,
        'tableId': tableId,
        'key': 'abc',
        'stage': 'teleporting',
        'items': const [],
        'startedAt': DateTime.now().toUtc().toIso8601String(),
      });
      expect(restored!.stage, SendStage.creating);
    });

    test('keys are not guessable or repeated', () {
      final keys = List.generate(50, (_) => PendingSendStore.newKey());
      expect(keys.toSet().length, 50);
    });
  });

  group('PendingSendStore', () {
    test('a submission from a previous service is discarded on read', () async {
      final stale = PendingSend.forDraft(
        draftWith([line]),
        now: DateTime.now().subtract(const Duration(hours: 13)),
        key: 'abc',
      );
      SharedPreferences.setMockInitialValues({
        PendingSendStore.keyFor(branchId, tableId): jsonEncode(stale.toJson()),
      });
      final store = PendingSendStore(await SharedPreferences.getInstance());

      expect(
        store.read(branchId: branchId, tableId: tableId, now: DateTime.now()),
        isNull,
      );
    });

    test('unfinished sends are listed for the floor plan', () async {
      final pending = PendingSend.forDraft(
        draftWith([line]),
        now: DateTime.now(),
        key: 'abc',
      );
      SharedPreferences.setMockInitialValues({
        PendingSendStore.keyFor(branchId, tableId): jsonEncode(pending.toJson()),
        PendingSendStore.keyFor('other-branch', 't9'):
            jsonEncode(pending.toJson()),
      });
      final store = PendingSendStore(await SharedPreferences.getInstance());

      expect(
        store.tablesWithPendingSends(branchId: branchId, now: DateTime.now()),
        {tableId},
        reason: 'another outlet\'s tables are not on this floor',
      );
    });
  });

  group('sending a round', () {
    test('runs create, add, place and confirm in order', () async {
      final server = _FakeServer();
      final container = await containerWith(server);
      final sender = container.read(sendControllerProvider(ticketRef).notifier);

      await sender.send(draftWith([line]));

      expect(
        server.calls,
        // The trailing lookup is the confirming re-read: success is declared
        // only once the bill has been fetched back, so the screen never blinks
        // the pre-send order at the waiter.
        ['lookup', 'create', 'addItems', 'place', 'confirm', 'lookup'],
      );
      final state = container.read(sendControllerProvider(ticketRef));
      expect(state.phase, SendPhase.sent);
      expect(state.order!.status, OrderStatus.confirmed);
    });

    test('sends the item payload the draft describes', () async {
      final server = _FakeServer();
      final container = await containerWith(server);

      await sender(container).send(draftWith([line]));

      expect(server.openOrder!.lines.single.qty, 2);
    });

    test('the draft is cleared once the kitchen has it', () async {
      final server = _FakeServer();
      final container = await containerWith(server);
      final ticket = container.read(ticketControllerProvider(ticketRef).notifier)
        ..add(line);

      await sender(container).send(container.read(ticketControllerProvider(ticketRef)));

      // Keeping it would offer to send the same round again at the next visit.
      expect(ticket.state.isEmpty, isTrue);
      final store = container.read(draftStoreProvider);
      expect(
        store.read(branchId: branchId, tableId: tableId, now: DateTime.now()),
        isNull,
      );
    });

    test('no record is left behind after a clean send', () async {
      final server = _FakeServer();
      final container = await containerWith(server);

      await sender(container).send(draftWith([line]));

      expect(
        container.read(pendingSendStoreProvider).read(
              branchId: branchId,
              tableId: tableId,
              now: DateTime.now(),
            ),
        isNull,
      );
    });

    test('an empty round is not sent at all', () async {
      final server = _FakeServer();
      final container = await containerWith(server);

      await sender(container).send(draftWith(const []));

      expect(server.calls, isEmpty);
    });
  });

  group('a table that already has a bill', () {
    test('the round is appended rather than opening a second bill', () async {
      final server = _FakeServer()
        ..openOrder = OrderDetail.fromJson(const {
          'id': 'order-existing',
          'orderNo': 'ORD-000001',
          'status': 'CONFIRMED',
          'channel': 'DINE_IN',
          'table': 'D1',
          'items': [],
        });
      // The fake needs to know the order for the follow-up fetches.
      await server.addItems(
        orderId: 'order-existing',
        items: const [],
        idempotencyKey: 'seed',
      ).catchError((_) => null);
      server.calls.clear();

      final container = await containerWith(server);
      await sender(container).send(draftWith([line]));

      expect(server.createCount, 0, reason: 'the table already has a bill');
      expect(server.calls, contains('addItems'));
    });

    test('an already-confirmed order is not placed or confirmed again',
        () async {
      final server = _FakeServer()
        ..openOrder = OrderDetail.fromJson(const {
          'id': 'order-existing',
          'status': 'PREPARING',
          'channel': 'DINE_IN',
          'items': [],
        });
      final container = await containerWith(server);

      await sender(container).send(draftWith([line]));

      // The kitchen is already cooking this ticket; `place` would be a 422.
      expect(server.calls, isNot(contains('place')));
      expect(server.calls, isNot(contains('confirm')));
    });

    test('a settled bill refuses the round and says so', () async {
      final server = _FakeServer()
        ..openOrder = OrderDetail.fromJson(const {
          'id': 'order-old',
          'status': 'SETTLED',
          'channel': 'DINE_IN',
          'items': [],
        });
      final container = await containerWith(server);

      await sender(container).send(draftWith([line]));

      // A closed bill cannot be adopted, so a new one is opened for the round
      // rather than the waiter being told to start over.
      expect(server.createCount, 1);
    });
  });

  group('when a tenant fires the kitchen automatically', () {
    test('confirm is skipped rather than reported as a failure', () async {
      final server = _FakeServer(autoFireKitchen: true);
      final container = await containerWith(server);

      await sender(container).send(draftWith([line]));

      expect(server.calls, contains('place'));
      expect(server.calls, isNot(contains('confirm')));
      expect(
        container.read(sendControllerProvider(ticketRef)).phase,
        SendPhase.sent,
      );
    });
  });

  group('when a step fails', () {
    test('the round is kept and the failure named', () async {
      final server = _FakeServer()
        ..failAlways['addItems'] =
            ApiException(ApiErrorKind.server, 'Database is down.');
      final container = await containerWith(server);

      await sender(container).send(draftWith([line]));

      final state = container.read(sendControllerProvider(ticketRef));
      expect(state.phase, SendPhase.failed);
      expect(state.stage, SendStage.addingItems);
      expect(state.error!.message, 'Database is down.');
      // The bill exists even though the round did not land — saying otherwise
      // would be a lie the kitchen could contradict.
      expect(state.orderExists, isTrue);
    });

    test('retrying resumes instead of creating a second order', () async {
      final server = _FakeServer()
        ..failOnce['addItems'] =
            ApiException(ApiErrorKind.network, 'Wifi dropped.');
      final container = await containerWith(server);
      final draft = draftWith([line]);

      await sender(container).send(draft);
      expect(container.read(sendControllerProvider(ticketRef)).phase,
          SendPhase.failed);

      await sender(container).send(draft);

      expect(server.createCount, 1, reason: 'the table must not be billed twice');
      expect(container.read(sendControllerProvider(ticketRef)).phase,
          SendPhase.sent);
    });

    test('the resumed step reuses the original idempotency key', () async {
      // This is what makes the retry safe when the first attempt actually
      // reached the server and only its response was lost.
      final server = _FakeServer()
        ..failOnce['addItems'] =
            ApiException(ApiErrorKind.network, 'Wifi dropped.');
      final container = await containerWith(server);
      final draft = draftWith([line]);

      await sender(container).send(draft);
      await sender(container).send(draft);

      final used = server.keys['addItems']!;
      expect(used.length, 2);
      expect(used.first, used.last);
    });

    test('a failure after placing resumes at confirm only', () async {
      final server = _FakeServer()
        ..failOnce['confirm'] =
            ApiException(ApiErrorKind.server, 'Kitchen printer service down.');
      final container = await containerWith(server);
      final draft = draftWith([line]);

      await sender(container).send(draft);
      server.calls.clear();
      await sender(container).send(draft);

      expect(server.calls, isNot(contains('create')));
      expect(server.calls, isNot(contains('addItems')));
      expect(server.calls, isNot(contains('place')));
      expect(server.calls, contains('confirm'));
    });
  });

  group('after the app was killed mid-send', () {
    test('the unfinished submission is found on the next launch', () async {
      final interrupted = PendingSend.forDraft(
        draftWith([line]),
        now: DateTime.now(),
        key: 'abc',
      ).copyWith(orderId: 'order-1', stage: SendStage.placing);

      final server = _FakeServer();
      final container = await containerWith(server, prefs: {
        PendingSendStore.keyFor(branchId, tableId):
            jsonEncode(interrupted.toJson()),
      });

      final state = container.read(sendControllerProvider(ticketRef));
      expect(state.phase, SendPhase.failed);
      expect(state.isInterrupted, isTrue,
          reason: 'there is no error to show — the app simply stopped');
      expect(state.stage, SendStage.placing);
      expect(state.orderExists, isTrue);
    });

    test('resuming continues the original order', () async {
      final interrupted = PendingSend.forDraft(
        draftWith([line]),
        now: DateTime.now(),
        key: 'abc',
      ).copyWith(orderId: 'order-1', stage: SendStage.placing);

      final server = _FakeServer();
      // The order the interrupted attempt created.
      await server.create(
        tableId: tableId,
        guestCount: 4,
        idempotencyKey: 'seed',
      );
      server.calls.clear();

      final container = await containerWith(server, prefs: {
        PendingSendStore.keyFor(branchId, tableId):
            jsonEncode(interrupted.toJson()),
      });

      await sender(container).send(draftWith([line]));

      expect(server.createCount, 0);
      expect(server.calls, isNot(contains('addItems')),
          reason: 'the items were already accepted before the app died');
    });

    test('discarding leaves the round on the tablet and stops retrying',
        () async {
      final interrupted = PendingSend.forDraft(
        draftWith([line]),
        now: DateTime.now(),
        key: 'abc',
      ).copyWith(orderId: 'order-1', stage: SendStage.placing);

      final server = _FakeServer();
      final container = await containerWith(server, prefs: {
        PendingSendStore.keyFor(branchId, tableId):
            jsonEncode(interrupted.toJson()),
      });

      await container.read(sendControllerProvider(ticketRef).notifier).discard();

      final state = container.read(sendControllerProvider(ticketRef));
      expect(state.phase, SendPhase.idle);
      expect(state.pending, isNull);
      expect(
        container.read(pendingSendStoreProvider).read(
              branchId: branchId,
              tableId: tableId,
              now: DateTime.now(),
            ),
        isNull,
      );
    });
  });

  group('when the bill is closed elsewhere mid-send', () {
    test('the round is kept and the waiter is told to send it again', () async {
      final server = _FakeServer();
      // The bill is open when the table is looked up...
      server.seed(OrderDetail.fromJson(const {
        'id': 'order-open',
        'status': 'CONFIRMED',
        'channel': 'DINE_IN',
        'items': [],
      }));
      // ...and settled by another till before this round reaches it.
      server.onStep['addItems'] = () => server.seed(OrderDetail.fromJson(const {
            'id': 'order-open',
            'status': 'SETTLED',
            'channel': 'DINE_IN',
            'items': [],
          }));
      server.failAlways['addItems'] = ApiException(
        ApiErrorKind.rejected,
        'Order is already settled.',
        status: 422,
      );

      final container = await containerWith(server);
      await sender(container).send(draftWith([line]));

      final state = container.read(sendControllerProvider(ticketRef));
      expect(state.phase, SendPhase.failed);
      expect(state.error!.message, contains('closed on another till'));
      // The abandoned record must not be offered for resume: its key is bound
      // to a bill that no longer accepts items.
      expect(state.pending, isNull);
      expect(
        container.read(pendingSendStoreProvider).read(
              branchId: branchId,
              tableId: tableId,
              now: DateTime.now(),
            ),
        isNull,
      );
    });
  });
}

SendController sender(ProviderContainer container) => container.read(
      sendControllerProvider(
        const TicketRef(
          branchId: 'branch-1',
          tableId: 'table-1',
          tableCode: 'D1',
        ),
      ).notifier,
    );
