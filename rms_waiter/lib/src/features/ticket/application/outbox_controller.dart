import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';
import '../data/pending_send_store.dart';
import 'send_controller.dart';
import 'ticket_controller.dart';

/// A submission that finished on its own, for whoever wants to say so.
@immutable
class OutboxResult {
  const OutboxResult({
    required this.tableId,
    required this.orderNo,
    required this.succeeded,
  });

  final String tableId;
  final String? orderNo;
  final bool succeeded;
}

@immutable
class OutboxState {
  const OutboxState({
    this.isDraining = false,
    this.lastResults = const [],
  });

  final bool isDraining;

  /// What the most recent drain achieved. Consumed by the app shell to tell the
  /// waiter, then left alone.
  final List<OutboxResult> lastResults;
}

/// Finishes submissions that the network interrupted, once it comes back.
///
/// This is the only "sync queue" the backend can honestly support. There is no
/// sync protocol, no merge and no conflict resolution (ARCHITECTURE.md §8), so
/// what is queued is not a general log of mutations — it is the small set of
/// per-table submissions that already hold a persisted idempotency key, which
/// is precisely what makes replaying them safe.
///
/// **What triggers a drain is the socket going live**, not a connectivity
/// plugin. A phone can be associated to a wifi access point that cannot reach
/// the internet, and a rider or waiter in that situation would have their
/// orders retried into a black hole. A Socket.IO handshake completing is proof
/// the API is reachable *and* that our token is good — a far stronger signal
/// than "wifi is on", and one already on the wire for free.
///
/// **Settlements are deliberately not drained.** A bill is closed with a person
/// standing there; finishing one unattended, minutes later, would take money
/// with nobody watching. The settle key is derived rather than stored precisely
/// so a human can retry it safely instead.
class OutboxController extends Notifier<OutboxState> {
  @override
  OutboxState build() => const OutboxState();

  /// Push whatever is outstanding.
  ///
  /// Safe to call on every trigger: a drain already in flight is not restarted,
  /// and every step carries the key its original attempt used.
  Future<void> drain() async {
    if (state.isDraining) return;

    final branchId = ref.read(sessionProvider).branchId;
    if (branchId == null) return;

    final pending = ref.read(pendingSendStoreProvider).all(
          branchId: branchId,
          now: DateTime.now(),
        );
    if (pending.isEmpty) return;

    state = const OutboxState(isDraining: true);
    final results = <OutboxResult>[];

    // One at a time. A dining room's worth of tables retrying in parallel the
    // instant the wifi returns is exactly the stampede the API client's
    // jittered backoff exists to avoid.
    for (final submission in pending) {
      // `tableCode` takes no part in TicketRef equality, so this resolves to
      // the very same controller an open ticket screen is already using — the
      // screen sees the progress rather than a second, invisible attempt.
      final ticketRef = TicketRef(
        branchId: submission.branchId,
        tableId: submission.tableId,
        tableCode: '',
      );
      final controller = ref.read(sendControllerProvider(ticketRef).notifier);
      final draft = ref.read(ticketControllerProvider(ticketRef));

      await controller.send(draft);

      final outcome = ref.read(sendControllerProvider(ticketRef));
      results.add(OutboxResult(
        tableId: submission.tableId,
        orderNo: outcome.order?.orderNo,
        succeeded: outcome.phase == SendPhase.sent,
      ));

      // A failure means the connection is not really back. Stopping here beats
      // burning the rest of the queue's attempts against the same wall.
      if (outcome.phase != SendPhase.sent) break;
    }

    state = OutboxState(lastResults: List.unmodifiable(results));
    ref.invalidate(tablesWithPendingSendsProvider);
  }

  /// Mark the last drain's results as reported, so they are announced once.
  void acknowledge() {
    if (state.lastResults.isEmpty) return;
    state = const OutboxState();
  }
}

final outboxControllerProvider =
    NotifierProvider<OutboxController, OutboxState>(OutboxController.new);
