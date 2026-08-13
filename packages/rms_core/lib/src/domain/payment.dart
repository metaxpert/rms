import 'package:flutter/material.dart';

import '../l10n/rms_localizations.dart';
import '../money.dart';

/// How a guest pays. These are the backend's tender codes.
enum PaymentMethod {
  cash('CASH'),
  card('CARD'),
  wallet('WALLET'),
  online('ONLINE');

  const PaymentMethod(this.wire);

  final String wire;

  static PaymentMethod fromWire(String? value) => values.firstWhere(
        (method) => method.wire == value,
        orElse: () => PaymentMethod.cash,
      );

  String labelIn(RmsLocalizations text) => switch (this) {
        PaymentMethod.cash => text.paymentCash,
        PaymentMethod.card => text.paymentCard,
        PaymentMethod.wallet => text.paymentWallet,
        PaymentMethod.online => text.paymentOnline,
      };

  IconData get icon => switch (this) {
        PaymentMethod.cash => Icons.payments_outlined,
        PaymentMethod.card => Icons.credit_card_rounded,
        PaymentMethod.wallet => Icons.account_balance_wallet_outlined,
        PaymentMethod.online => Icons.language_rounded,
      };

  /// Only cash is physically over-tendered, so only cash needs change working
  /// out. Offering a "cash given" box for a card would be noise at the one
  /// moment a waiter is under the most pressure.
  bool get takesOverTender => this == PaymentMethod.cash;
}

/// One tender line on a bill.
///
/// A bill carries a LIST of these, which is how the backend supports splitting:
/// two guests paying half each is one settle call with two payments, not two
/// orders. There is no endpoint for splitting an order into separate bills, so
/// the app does not offer one.
@immutable
class Payment {
  const Payment({required this.method, required this.amount});

  final PaymentMethod method;
  final Money amount;

  Payment copyWith({PaymentMethod? method, Money? amount}) => Payment(
        method: method ?? this.method,
        amount: amount ?? this.amount,
      );

  Map<String, dynamic> toApiJson() => {
        'method': method.wire,
        'amountMinor': amount.minor,
      };

  /// Stable text for one tender, used to build the settle idempotency key.
  String get signature => '${method.wire}:${amount.minor}';

  @override
  bool operator ==(Object other) =>
      other is Payment && other.method == method && other.amount == amount;

  @override
  int get hashCode => Object.hash(method, amount);
}

/// The tender being composed for a bill, and whether it adds up.
///
/// Kept as its own type because "does this settle the bill?" is the question
/// the settle button hangs on, and getting it wrong either short-changes the
/// till or hands a guest a bill the server will refuse.
@immutable
class Tender {
  const Tender({required this.payments, required this.due});

  final List<Payment> payments;

  /// What the server says the bill comes to.
  final Money due;

  static Tender forBill(Money due) => Tender(
        // One cash line for the whole bill is what most tables are; a split is
        // the exception and is reached by adding a second line.
        payments: [Payment(method: PaymentMethod.cash, amount: due)],
        due: due,
      );

  Money get taken => payments.fold(
        Money(0, due.currency),
        (sum, payment) => sum + payment.amount,
      );

  /// Positive when the tender does not yet cover the bill.
  Money get outstanding => due - taken;

  bool get isBalanced => outstanding.isZero;

  /// Over-tender. On a cash bill this is the change owed to the guest; the
  /// server is sent the bill amount, never the note handed over.
  Money get over => taken - due;

  bool get isOver => over.minor > 0;

  bool get isShort => outstanding.minor > 0;

  Tender withPayments(List<Payment> next) =>
      Tender(payments: List.unmodifiable(next), due: due);

  /// Split the bill evenly [ways], every part on the same method.
  ///
  /// Uses [Money.split], which distributes the remainder — three ways on a
  /// 1000.00 bill is 333.34 / 333.33 / 333.33, not three times 333.33 with a
  /// rupee unaccounted for. A split that does not reconcile is a split the
  /// server rejects.
  Tender splitEvenly(int ways, {PaymentMethod method = PaymentMethod.cash}) {
    if (ways <= 1) return withPayments([Payment(method: method, amount: due)]);
    return withPayments([
      for (final part in due.split(ways)) Payment(method: method, amount: part),
    ]);
  }

  /// A stable description of this tender, so a retried settle presents the same
  /// idempotency key and replays rather than double-charging.
  String get signature => payments.map((p) => p.signature).join('|');
}
