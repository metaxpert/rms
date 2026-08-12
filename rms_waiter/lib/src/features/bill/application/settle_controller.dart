import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';
import '../../floor/data/floor_repository.dart';
import '../../orders/data/order_repository.dart';

enum SettlePhase { idle, settling, settled, failed }

@immutable
class SettleState {
  const SettleState({
    this.phase = SettlePhase.idle,
    this.tender,
    this.cashReceived,
    this.error,
    this.order,
  });

  final SettlePhase phase;

  /// Null until the waiter changes something — the default tender is derived
  /// from the bill, so there is nothing to store for the common case of one
  /// guest paying the whole thing in cash.
  final Tender? tender;

  /// What the guest actually handed over, for working out change. Display only:
  /// the server is told what was applied to the bill, never the note.
  final Money? cashReceived;

  final ApiException? error;

  /// The settled order, once the server has closed it.
  final OrderDetail? order;

  bool get isSettling => phase == SettlePhase.settling;

  /// The tender being composed for [due].
  Tender tenderFor(Money due) {
    final current = tender;
    if (current == null || current.due != due) return Tender.forBill(due);
    return current;
  }

  Money? changeFor(Tender tender) {
    final received = cashReceived;
    if (received == null) return null;
    final change = received - tender.due;
    return change.isNegative ? null : change;
  }

  SettleState copyWith({
    SettlePhase? phase,
    Tender? tender,
    Money? cashReceived,
    ApiException? error,
    OrderDetail? order,
    bool clearError = false,
    bool clearCash = false,
  }) =>
      SettleState(
        phase: phase ?? this.phase,
        tender: tender ?? this.tender,
        cashReceived: clearCash ? null : (cashReceived ?? this.cashReceived),
        error: clearError ? null : (error ?? this.error),
        order: order ?? this.order,
      );
}

/// Composing the tender for a bill, and closing it.
///
/// Settling is the single most consequential call the app makes: it moves
/// stock, captures COGS and posts a balanced GL journal atomically with the
/// bill. Two rules follow.
///
/// **The tender must reconcile exactly.** The button stays dead until the
/// payments sum to what the server says is due — a bill that is a rupee short
/// is refused server-side, and one composed from an unbalanced even split puts
/// the till out against the ledger. [Money.split] is what makes an odd total
/// divide cleanly.
///
/// **A retry must never charge twice.** The idempotency key is derived from the
/// order and the exact tender, so it is identical across retries without
/// needing to be stored — it survives the app being killed, where a key held in
/// memory would not. A tender the waiter has since changed produces a different
/// key, which is why a rejection is checked against the order's real status
/// before being shown as a failure.
class SettleController extends AutoDisposeFamilyNotifier<SettleState, String> {
  @override
  SettleState build(String orderId) => const SettleState();

  OrderRepository get _orders => ref.read(orderRepositoryProvider);

  void setTender(Tender tender) =>
      state = state.copyWith(tender: tender, clearError: true);

  /// Split the bill evenly. Guests asking to "split it three ways" is the only
  /// split this app offers, because it is the only one the API supports: a
  /// settle takes a list of payments, not a list of bills.
  void splitEvenly(int ways, Money due) =>
      setTender(Tender.forBill(due).splitEvenly(ways));

  void setMethod(int index, PaymentMethod method, Money due) {
    final tender = state.tenderFor(due);
    final next = [...tender.payments];
    if (index < 0 || index >= next.length) return;
    next[index] = next[index].copyWith(method: method);
    setTender(tender.withPayments(next));
  }

  void setAmount(int index, Money amount, Money due) {
    final tender = state.tenderFor(due);
    final next = [...tender.payments];
    if (index < 0 || index >= next.length) return;
    next[index] = next[index].copyWith(amount: amount);
    setTender(tender.withPayments(next));
  }

  /// Add a tender line carrying whatever is still outstanding, so the common
  /// case — "the rest on card" — is one tap rather than arithmetic done by a
  /// waiter with a queue behind them.
  void addPayment(Money due) {
    final tender = state.tenderFor(due);
    final remaining = tender.outstanding;
    setTender(tender.withPayments([
      ...tender.payments,
      Payment(
        method: PaymentMethod.card,
        amount: remaining.isNegative ? Money(0, due.currency) : remaining,
      ),
    ]));
  }

  void removePayment(int index, Money due) {
    final tender = state.tenderFor(due);
    if (tender.payments.length <= 1) return;
    final next = [...tender.payments]..removeAt(index);
    setTender(tender.withPayments(next));
  }

  void setCashReceived(Money? amount) => state = amount == null
      ? state.copyWith(clearCash: true)
      : state.copyWith(cashReceived: amount);

  /// Close the bill.
  Future<void> settle(OrderDetail order) async {
    if (state.isSettling) return;

    final tender = state.tenderFor(order.totals.total);
    if (!tender.isBalanced) {
      // The button is disabled for this, so reaching it means a race with an
      // edit. Refuse locally rather than let the server decide.
      state = state.copyWith(
        phase: SettlePhase.failed,
        error: ApiException(
          ApiErrorKind.rejected,
          tender.isShort
              ? 'The payments are ${tender.outstanding.display} short of the bill.'
              : 'The payments are ${tender.over.display} more than the bill.',
        ),
      );
      return;
    }

    final keepAlive = ref.keepAlive();
    state = state.copyWith(phase: SettlePhase.settling, clearError: true);

    try {
      final settled = await _orders.settle(
            orderId: order.id,
            payments: tender.payments,
            // Derived, not stored: identical across retries and across a
            // restart, and distinct per bill and per tender composition.
            idempotencyKey: 'settle:${order.id}:${tender.signature}',
          ) ??
          await _orders.fetch(order.id);
      _finish(settled);
    } on ApiException catch (error) {
      // "Already settled" is the expected answer when a previous attempt landed
      // and only its response was lost, or when another till closed the bill
      // first. Either way the money is taken and the guest can go — reporting a
      // failure would send a waiter to charge a second time.
      final settled = await _alreadySettled(order.id);
      if (settled != null) {
        _finish(settled);
        return;
      }
      state = state.copyWith(phase: SettlePhase.failed, error: error);
    } finally {
      keepAlive.close();
    }
  }

  Future<OrderDetail?> _alreadySettled(String orderId) async {
    try {
      final current = await _orders.fetch(orderId);
      return current.status == OrderStatus.settled ? current : null;
    } on ApiException {
      // Cannot tell. Fall through to reporting the original failure, which is
      // the safe direction: the waiter checks the bill rather than assuming.
      return null;
    }
  }

  void _finish(OrderDetail settled) {
    state = SettleState(phase: SettlePhase.settled, order: settled);
    // The table is free and the floor's open-bill count is wrong until this.
    ref.invalidate(floorSnapshotProvider);
    final tableId = settled.tableId;
    if (tableId != null) ref.invalidate(tableOrderProvider(tableId));
  }
}

final settleControllerProvider =
    NotifierProvider.autoDispose.family<SettleController, SettleState, String>(
  SettleController.new,
);
