import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';

/// Tender arithmetic. A bill that does not reconcile is either refused by the
/// server or puts the till out against the ledger, so every case here is about
/// the sum landing exactly on the total.
void main() {
  group('Tender', () {
    test('a fresh bill is one cash line for the whole amount', () {
      // Most tables are one guest paying the lot; a split is the exception.
      final tender = Tender.forBill(const Money(153100));
      expect(tender.payments.single.method, PaymentMethod.cash);
      expect(tender.payments.single.amount, const Money(153100));
      expect(tender.isBalanced, isTrue);
    });

    test('knows what is still owed', () {
      final tender = Tender.forBill(const Money(100000)).withPayments(const [
        Payment(method: PaymentMethod.card, amount: Money(60000)),
      ]);
      expect(tender.outstanding, const Money(40000));
      expect(tender.isShort, isTrue);
      expect(tender.isBalanced, isFalse);
    });

    test('knows when too much has been entered', () {
      final tender = Tender.forBill(const Money(100000)).withPayments(const [
        Payment(method: PaymentMethod.cash, amount: Money(120000)),
      ]);
      expect(tender.over, const Money(20000));
      expect(tender.isOver, isTrue);
      expect(tender.isBalanced, isFalse);
    });

    test('an even split reconciles exactly on an indivisible total', () {
      // 1000.00 over three is the classic paisa-loser: 333.33 × 3 leaves a
      // rupee unaccounted for, and the server refuses the settle.
      final tender = Tender.forBill(const Money(100000)).splitEvenly(3);

      expect(tender.payments.length, 3);
      expect(tender.taken, const Money(100000));
      expect(tender.isBalanced, isTrue);
      expect(
        tender.payments.map((p) => p.amount.minor).toList(),
        [33334, 33333, 33333],
      );
    });

    test('splitting by one collapses back to a single payment', () {
      final tender = Tender.forBill(const Money(50000))
          .splitEvenly(3)
          .splitEvenly(1);
      expect(tender.payments.length, 1);
      expect(tender.payments.single.amount, const Money(50000));
    });

    test('every split keeps the bill\'s currency', () {
      final tender = Tender.forBill(const Money(90000, 'USD')).splitEvenly(4);
      expect(tender.taken, const Money(90000, 'USD'));
      for (final payment in tender.payments) {
        expect(payment.amount.currency, 'USD');
      }
    });

    test('the signature changes with the tender and not otherwise', () {
      // It is the settle idempotency key: identical tenders must replay, and a
      // changed one must not silently reuse a spent key.
      final a = Tender.forBill(const Money(100000)).splitEvenly(2);
      final b = Tender.forBill(const Money(100000)).splitEvenly(2);
      final c = Tender.forBill(const Money(100000)).splitEvenly(3);

      expect(a.signature, b.signature);
      expect(a.signature, isNot(c.signature));
    });

    test('the signature distinguishes method from amount', () {
      final cash = Tender.forBill(const Money(100000));
      final card = cash.withPayments(const [
        Payment(method: PaymentMethod.card, amount: Money(100000)),
      ]);
      expect(cash.signature, isNot(card.signature));
    });
  });

  group('Payment', () {
    test('sends the backend\'s tender codes and integer minor units', () {
      const payment =
          Payment(method: PaymentMethod.wallet, amount: Money(153100));
      expect(payment.toApiJson(), {
        'method': 'WALLET',
        'amountMinor': 153100,
      });
    });

    test('only cash is over-tendered', () {
      // A card is charged the exact amount; offering a "given" box for one
      // would be noise at the busiest moment of a table's life.
      expect(PaymentMethod.cash.takesOverTender, isTrue);
      expect(PaymentMethod.card.takesOverTender, isFalse);
      expect(PaymentMethod.wallet.takesOverTender, isFalse);
      expect(PaymentMethod.online.takesOverTender, isFalse);
    });

    test('an unrecognised tender code falls back to cash', () {
      expect(PaymentMethod.fromWire('CRYPTO'), PaymentMethod.cash);
      expect(PaymentMethod.fromWire(null), PaymentMethod.cash);
    });
  });
}
