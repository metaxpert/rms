import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';
import '../../floor/data/floor_repository.dart';
import '../../orders/data/order_repository.dart';
import '../data/pending_send_store.dart';
import 'ticket_controller.dart';

/// Where a submission stands, from the waiter's point of view.
enum SendPhase {
  /// Nothing in flight and nothing left over.
  idle,

  /// Talking to the server right now.
  sending,

  /// The kitchen has it.
  sent,

  /// A step failed, or an earlier attempt never finished. Either way there is a
  /// [SendState.pending] record and the next attempt resumes from it.
  failed,
}

@immutable
class SendState {
  const SendState({
    this.phase = SendPhase.idle,
    this.stage,
    this.error,
    this.order,
    this.pending,
  });

  final SendPhase phase;

  /// Which of the four calls is running, or was running when it failed.
  final SendStage? stage;

  /// Null on a submission that was interrupted rather than refused — a battery
  /// that died mid-send leaves no error to show, only unfinished work.
  final ApiException? error;

  /// The server's order once there is one.
  final OrderDetail? order;

  /// An unfinished submission. Its presence is why the button says "Resume"
  /// rather than "Send": starting over would risk a second bill.
  final PendingSend? pending;

  bool get isSending => phase == SendPhase.sending;
  bool get isInterrupted => phase == SendPhase.failed && error == null;

  /// True once the order exists server-side, whatever else went wrong. The
  /// screen must say so: "nothing was sent" would be a lie the kitchen could
  /// contradict.
  bool get orderExists => (pending?.orderId ?? order?.id) != null;

  SendState copyWith({
    SendPhase? phase,
    SendStage? stage,
    ApiException? error,
    OrderDetail? order,
    PendingSend? pending,
    bool clearError = false,
    bool clearPending = false,
  }) =>
      SendState(
        phase: phase ?? this.phase,
        stage: stage ?? this.stage,
        error: clearError ? null : (error ?? this.error),
        order: order ?? this.order,
        pending: clearPending ? null : (pending ?? this.pending),
      );
}

/// Sends a table's ticket to the server, and survives being interrupted.
///
/// The submission is four calls — create, add items, place, confirm — and the
/// backend enforces the transitions between them (ARCHITECTURE.md §2). Two
/// things make that safe to retry:
///
/// * **Caller-owned idempotency keys**, persisted with the submission. A waiter
///   who taps Send again after a timeout replays the original request and gets
///   the original response, rather than opening a second bill for the table.
/// * **A recorded stage**, so a retry continues from where it stopped. Combined
///   with adopting any order the table already has, this is what stops one
///   round becoming two.
///
/// What it does NOT do is pretend to be transactional. The backend has no sync
/// protocol (ARCHITECTURE.md §8); when the server refuses a step, the waiter is
/// told which step and what the server said.
/// `autoDispose` so this state cannot outlive the screen that shows it: a
/// controller kept alive for the whole shift would still be holding the order
/// it sent an hour ago, and that stale copy would win over a fresh fetch. What
/// must survive is on disk, and [build] reads it back.
class SendController extends AutoDisposeFamilyNotifier<SendState, TicketRef> {
  /// Set when a submission is deliberately abandoned mid-flight (the bill it
  /// was going onto turned out to be closed). It stops the error handler
  /// resurrecting the record it just cleared.
  var _abandoned = false;

  /// Held while a send is in flight. Without it a waiter who walks away from
  /// the table mid-send disposes the controller, and the continuation writes to
  /// a dead notifier — the send would be abandoned at whatever step it reached.
  KeepAliveLink? _keepAlive;

  @override
  SendState build(TicketRef arg) {
    // A record found at build time is an attempt from a previous run of the
    // app — the tablet was killed or the battery went mid-send.
    final pending = ref.read(pendingSendStoreProvider).read(
          branchId: arg.branchId,
          tableId: arg.tableId,
          now: DateTime.now(),
        );
    if (pending == null) return const SendState();
    return SendState(
      phase: SendPhase.failed,
      stage: pending.stage,
      pending: pending,
    );
  }

  PendingSendStore get _store => ref.read(pendingSendStoreProvider);
  OrderRepository get _orders => ref.read(orderRepositoryProvider);

  /// Send the ticket, or resume an unfinished send.
  ///
  /// [draft] is only read when starting fresh: a resumed submission re-sends
  /// the payload frozen at the original tap, because the same idempotency key
  /// with a different body is a 422.
  Future<void> send(TicketDraft draft) async {
    if (state.isSending) return; // Double-tap guard; the keys make it safe anyway.

    _abandoned = false;
    _keepAlive ??= ref.keepAlive();
    final now = DateTime.now();
    var pending = state.pending ??
        _store.read(
          branchId: arg.branchId,
          tableId: arg.tableId,
          now: now,
        ) ??
        PendingSend.forDraft(
          draft,
          now: now,
          key: PendingSendStore.newKey(),
        );

    if (pending.items.isEmpty) {
      state = const SendState();
      return;
    }

    await _record(pending);
    state = state.copyWith(
      phase: SendPhase.sending,
      stage: pending.stage,
      pending: pending,
      clearError: true,
    );

    try {
      OrderDetail? order;

      if (pending.stage == SendStage.creating) {
        order = await _openOrder(pending, draft);
        pending = pending.copyWith(
          orderId: order.id,
          stage: SendStage.addingItems,
        );
        await _record(pending);
      }

      final orderId = pending.orderId!;

      if (pending.stage == SendStage.addingItems) {
        _announce(pending, SendStage.addingItems);
        order = await _addItems(pending, orderId);
        pending = pending.copyWith(stage: SendStage.placing);
        await _record(pending);
      }

      order ??= await _orders.fetch(orderId);

      if (pending.stage == SendStage.placing) {
        _announce(pending, SendStage.placing);
        if (order.canPlace) {
          order = await _orders.place(
                orderId: orderId,
                idempotencyKey: pending.keyFor(SendStage.placing),
              ) ??
              await _orders.fetch(orderId);
        }
        pending = pending.copyWith(stage: SendStage.confirming);
        await _record(pending);
      }

      if (pending.stage == SendStage.confirming) {
        _announce(pending, SendStage.confirming);
        order = await _confirm(pending, orderId, order);
      }

      await _finish(order);
    } on ApiException catch (error) {
      state = _failed(pending, error);
    } catch (error) {
      state = _failed(
        pending,
        ApiException(ApiErrorKind.unknown, 'Could not send: $error'),
      );
    } finally {
      ref.invalidate(tablesWithPendingSendsProvider);
      _keepAlive?.close();
      _keepAlive = null;
    }
  }

  /// The order this round is going onto — an existing bill where there is one,
  /// a new one otherwise.
  ///
  /// Adopting an open bill first is what makes a resume safe when the app died
  /// between creating the order and recording its id: the order is found rather
  /// than duplicated. It also means a second waiter adding drinks to a table
  /// appends to the bill instead of opening a rival one.
  Future<OrderDetail> _openOrder(PendingSend pending, TicketDraft draft) async {
    _announce(pending, SendStage.creating);

    final existing = await _orders.openOrderForTable(arg.tableId);
    if (existing != null && existing.canAddItems) return existing;

    final created = await _orders.create(
      tableId: arg.tableId,
      guestCount: pending.guestCount ?? draft.guestCount,
      idempotencyKey: pending.keyFor(SendStage.creating),
    );
    if (created != null) return created;

    // The create succeeded but its response was not an order we could read.
    // Find what it made rather than assuming — creating again could double.
    final found = await _orders.openOrderForTable(arg.tableId);
    if (found != null) return found;
    throw ApiException(
      ApiErrorKind.unknown,
      'The order was created but could not be read back. '
      'Check the table on the floor before sending again.',
    );
  }

  Future<OrderDetail> _addItems(PendingSend pending, String orderId) async {
    try {
      return await _orders.addItems(
            orderId: orderId,
            items: pending.items,
            idempotencyKey: pending.keyFor(SendStage.addingItems),
          ) ??
          await _orders.fetch(orderId);
    } on ApiException catch (error) {
      if (error.kind != ApiErrorKind.rejected &&
          error.kind != ApiErrorKind.notFound) {
        rethrow;
      }
      // The bill was settled or voided on another till while this round was
      // being typed. The draft is untouched, so the waiter can send it again
      // onto a fresh bill — but they must be told, not silently re-billed.
      final current = await _currentOrder(orderId);
      if (current != null && current.canAddItems) rethrow;
      await _store.clear(arg.branchId, arg.tableId);
      _abandoned = true;
      throw ApiException(
        ApiErrorKind.rejected,
        'That bill was closed on another till, so this round was not added. '
        'The ticket is still here — send it again to start a new bill.',
      );
    }
  }

  /// Fire the kitchen.
  ///
  /// `confirm` is only legal out of PLACED. A tenant with `autoFireKitchen`
  /// confirms during `place`, so "already confirmed" is the expected outcome
  /// there and must read as success — reporting a failure would send a waiter
  /// to the pass to check on food that is already being cooked.
  Future<OrderDetail> _confirm(
    PendingSend pending,
    String orderId,
    OrderDetail order,
  ) async {
    if (!order.canConfirm) return order;
    try {
      return await _orders.confirm(
            orderId: orderId,
            idempotencyKey: pending.keyFor(SendStage.confirming),
          ) ??
          await _orders.fetch(orderId);
    } on ApiException catch (error) {
      if (error.kind != ApiErrorKind.rejected) rethrow;
      final current = await _currentOrder(orderId);
      if (current != null && !current.canConfirm) return current;
      rethrow;
    }
  }

  /// Re-read an order, tolerating a second failure — this runs while already
  /// handling an error, and a network blip here must not mask the real one.
  Future<OrderDetail?> _currentOrder(String orderId) async {
    try {
      return await _orders.fetch(orderId);
    } on ApiException {
      return null;
    }
  }

  Future<void> _finish(OrderDetail order) async {
    await _store.clear(arg.branchId, arg.tableId);

    // The lines belong to the server now. Keeping the draft would offer to send
    // them a second time at the next table visit.
    ref.read(ticketControllerProvider(arg).notifier).clear();

    // Re-read the bill BEFORE declaring success, so the moment the progress
    // panel disappears the screen is already showing the order the server
    // holds. Announcing "sent" first and refreshing after would blink the
    // pre-send bill back at the waiter for a round trip.
    //
    // The order returned by the last step is kept as the fallback: a refresh
    // that fails must not turn a successful send into an apparent failure.
    var settled = order;
    try {
      settled = await ref.refresh(tableOrderProvider(arg.tableId).future) ?? order;
    } on ApiException {
      // The send worked; only the confirming read did not.
    }

    state = SendState(phase: SendPhase.sent, order: settled);
    ref.invalidate(floorSnapshotProvider);
  }

  /// Abandon an unfinished submission without sending it.
  ///
  /// The draft stays: the waiter still has the round, and can send it again.
  /// Any order already created stays too — it is on the floor for a manager to
  /// deal with, which is honest, whereas silently voiding it here would hide a
  /// bill that the kitchen may already have.
  Future<void> discard() async {
    await _store.clear(arg.branchId, arg.tableId);
    state = const SendState();
    ref.invalidate(tablesWithPendingSendsProvider);
    ref.invalidate(tableOrderProvider(arg.tableId));
  }

  /// Dismiss the success banner.
  void acknowledge() {
    if (state.phase == SendPhase.sent) state = const SendState();
  }

  /// A failure keeps the record so the next tap resumes — unless the submission
  /// was abandoned, in which case restoring it would offer to resume work that
  /// has deliberately been thrown away.
  SendState _failed(PendingSend pending, ApiException error) => _abandoned
      ? SendState(phase: SendPhase.failed, error: error)
      : state.copyWith(
          phase: SendPhase.failed,
          pending: pending,
          error: error,
        );

  Future<void> _record(PendingSend pending) async {
    await _store.write(pending);
    ref.invalidate(tablesWithPendingSendsProvider);
  }

  void _announce(PendingSend pending, SendStage stage) {
    state = state.copyWith(stage: stage, pending: pending);
  }
}

final sendControllerProvider =
    NotifierProvider.autoDispose.family<SendController, SendState, TicketRef>(
  SendController.new,
);

/// What the waiter is told while a send is in flight.
///
/// Named per step rather than one "Sending…" because the steps fail
/// differently: "Adding the items" failing leaves an empty bill on the table,
/// and a waiter who saw where it stopped can say so to a manager.
String sendStageLabel(SendStage stage) => switch (stage) {
      SendStage.creating => 'Opening the bill…',
      SendStage.addingItems => 'Adding the items…',
      SendStage.placing => 'Placing the order…',
      SendStage.confirming => 'Firing the kitchen…',
    };
