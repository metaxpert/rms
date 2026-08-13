import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_waiter/src/features/floor/data/floor_repository.dart';
import 'package:rms_waiter/src/features/orders/data/order_repository.dart';
import 'package:rms_waiter/src/features/ticket/application/outbox_controller.dart';
import 'package:rms_waiter/src/features/ticket/data/pending_send_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_order_server.dart';

/// The one queue the backend can honestly support: per-table submissions that
/// already carry a persisted idempotency key, finished off once the server is
/// reachable again. Everything here is about not turning a wifi drop into
/// duplicate orders, and not going quiet about work done unattended.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const branchId = 'branch-1';

  PendingSend pending({
    required String tableId,
    required DateTime startedAt,
    SendStage stage = SendStage.creating,
    String? orderId,
  }) =>
      PendingSend(
        branchId: branchId,
        tableId: tableId,
        key: 'key-$tableId',
        stage: stage,
        items: const [
          {'itemId': 'item-naan', 'qty': 2},
        ],
        startedAt: startedAt,
        orderId: orderId,
      );

  Future<ProviderContainer> containerWith(
    FakeOrderServer server, {
    List<PendingSend> queued = const [],
    String? branch = branchId,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (branch != null) 'branch_id': branch,
      for (final record in queued)
        PendingSendStore.keyFor(record.branchId, record.tableId):
            jsonEncode(record.toJson()),
    });
    final session = await Session.load(secretStore: InMemorySecretStore());
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWithValue(session),
        sharedPreferencesProvider
            .overrideWithValue(await SharedPreferences.getInstance()),
        orderRepositoryProvider.overrideWithValue(server),
        // The drain invalidates the floor; nothing here should reach a network.
        floorSnapshotProvider.overrideWith((ref) => FloorSnapshot(
              areas: const [],
              tables: const [],
              openOrdersByTableCode: const {},
              readAt: DateTime(2026),
            )),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('the queue', () {
    test('lists unfinished submissions oldest first', () async {
      // Drained in the order the tables were actually served.
      final container = await containerWith(FakeOrderServer(), queued: [
        pending(tableId: 't-late', startedAt: DateTime(2026, 8, 13, 20, 30)),
        pending(tableId: 't-early', startedAt: DateTime(2026, 8, 13, 19, 15)),
      ]);

      final all = container
          .read(pendingSendStoreProvider)
          .all(branchId: branchId, now: DateTime(2026, 8, 13, 21));

      expect(all.map((p) => p.tableId).toList(), ['t-early', 't-late']);
    });

    test('another outlet\'s submissions are not drained here', () async {
      final container = await containerWith(FakeOrderServer(), queued: [
        PendingSend(
          branchId: 'other-branch',
          tableId: 't1',
          key: 'k',
          stage: SendStage.creating,
          items: const [
            {'itemId': 'i', 'qty': 1},
          ],
          startedAt: DateTime.now(),
        ),
      ]);

      await container.read(outboxControllerProvider.notifier).drain();
      expect(container.read(orderRepositoryProvider), isA<FakeOrderServer>());
      expect((container.read(orderRepositoryProvider) as FakeOrderServer).calls,
          isEmpty);
    });

    test('a submission from a previous service is not resurrected', () async {
      final server = FakeOrderServer();
      final container = await containerWith(server, queued: [
        pending(
          tableId: 't1',
          startedAt: DateTime.now().subtract(const Duration(hours: 13)),
        ),
      ]);

      await container.read(outboxControllerProvider.notifier).drain();
      expect(server.calls, isEmpty);
    });
  });

  group('draining', () {
    test('finishes an interrupted submission without re-creating the order',
        () async {
      final server = FakeOrderServer();
      await server.create(
        tableId: 't1',
        guestCount: 2,
        idempotencyKey: 'seed',
      );
      server.calls.clear();

      final container = await containerWith(server, queued: [
        pending(
          tableId: 't1',
          startedAt: DateTime.now(),
          stage: SendStage.placing,
          orderId: 'order-1',
        ),
      ]);

      await container.read(outboxControllerProvider.notifier).drain();

      expect(server.createCount, 0, reason: 'the table must not be billed twice');
      expect(server.calls, contains('place'));
      expect(
        container.read(outboxControllerProvider).lastResults.single.succeeded,
        isTrue,
      );
    });

    test('clears the record it completed', () async {
      final server = FakeOrderServer();
      final container = await containerWith(server, queued: [
        pending(tableId: 't1', startedAt: DateTime.now()),
      ]);

      await container.read(outboxControllerProvider.notifier).drain();

      expect(
        container.read(pendingSendStoreProvider).all(
              branchId: branchId,
              now: DateTime.now(),
            ),
        isEmpty,
      );
    });

    test('stops at the first failure instead of burning the rest', () async {
      // A failure means the connection is not really back. Pushing the whole
      // queue at the same wall wastes every submission's attempt.
      final server = FakeOrderServer()
        ..failAlways['lookup'] =
            ApiException(ApiErrorKind.network, 'Still no wifi.');
      final container = await containerWith(server, queued: [
        pending(tableId: 't1', startedAt: DateTime(2026, 8, 13, 19)),
        pending(tableId: 't2', startedAt: DateTime(2026, 8, 13, 20)),
      ]);

      await container.read(outboxControllerProvider.notifier).drain();

      final results = container.read(outboxControllerProvider).lastResults;
      expect(results.length, 1);
      expect(results.single.succeeded, isFalse);
      expect(server.calls.where((c) => c == 'lookup').length, 1);
    });

    test('a failed submission is kept for the next attempt', () async {
      final server = FakeOrderServer()
        ..failAlways['lookup'] =
            ApiException(ApiErrorKind.network, 'Still no wifi.');
      final container = await containerWith(server, queued: [
        pending(tableId: 't1', startedAt: DateTime.now()),
      ]);

      await container.read(outboxControllerProvider.notifier).drain();

      expect(
        container
            .read(pendingSendStoreProvider)
            .all(branchId: branchId, now: DateTime.now())
            .length,
        1,
      );
    });

    test('a second drain while one runs is ignored', () async {
      final server = FakeOrderServer();
      final container = await containerWith(server, queued: [
        pending(tableId: 't1', startedAt: DateTime.now()),
      ]);
      final controller = container.read(outboxControllerProvider.notifier);

      await Future.wait([controller.drain(), controller.drain()]);

      expect(server.createCount, 1);
    });

    test('nothing queued means nothing sent', () async {
      final server = FakeOrderServer();
      final container = await containerWith(server);

      await container.read(outboxControllerProvider.notifier).drain();

      expect(server.calls, isEmpty);
      expect(container.read(outboxControllerProvider).lastResults, isEmpty);
    });

    test('with no outlet chosen there is nothing to drain', () async {
      final server = FakeOrderServer();
      final container = await containerWith(server, branch: null);

      await container.read(outboxControllerProvider.notifier).drain();
      expect(server.calls, isEmpty);
    });
  });

  group('reporting', () {
    test('results are offered once, then cleared', () async {
      // Work done unattended must be announced — a waiter has to know whether
      // to chase the kitchen — but announced once, not on every rebuild.
      final server = FakeOrderServer();
      final container = await containerWith(server, queued: [
        pending(tableId: 't1', startedAt: DateTime.now()),
      ]);
      final controller = container.read(outboxControllerProvider.notifier);

      await controller.drain();
      expect(container.read(outboxControllerProvider).lastResults, hasLength(1));

      controller.acknowledge();
      expect(container.read(outboxControllerProvider).lastResults, isEmpty);
    });

    test('carries the order number so the waiter can name it', () async {
      final server = FakeOrderServer();
      final container = await containerWith(server, queued: [
        pending(tableId: 't1', startedAt: DateTime.now()),
      ]);

      await container.read(outboxControllerProvider.notifier).drain();

      final result =
          container.read(outboxControllerProvider).lastResults.single;
      expect(result.tableId, 't1');
      expect(result.orderNo, isNotEmpty);
    });
  });
}
