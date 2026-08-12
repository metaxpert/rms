import 'package:flutter_test/flutter_test.dart';
import 'package:rms_waiter/src/core/money.dart';

void main() {
  group('Money arithmetic', () {
    test('adds and subtracts in minor units', () {
      expect((const Money(1450) + const Money(850)).minor, 2300);
      expect((const Money(2300) - const Money(850)).minor, 1450);
    });

    test('multiplies by a whole quantity', () {
      expect((const Money(60) * 3).minor, 180);
    });

    test('refuses to mix currencies', () {
      expect(
        () => const Money(100, 'PKR') + const Money(100, 'USD'),
        throwsArgumentError,
      );
    });
  });

  group('applyBp — tax at 16% (1600 bp)', () {
    test('matches the seeded demo bill exactly', () {
      // The Karahi Point settled bill posted Rs 2,000.00 net + Rs 320.00 tax
      // = Rs 2,320.00 cash. If this drifts, the till stops reconciling.
      const net = Money(200000);
      expect(net.applyBp(1600).minor, 32000);
      expect((net + net.applyBp(1600)).minor, 232000);
    });

    test('rounds half-up', () {
      // 3 paisa @ 16% = 0.48 -> 0
      expect(const Money(3).applyBp(1600).minor, 0);
      // 313 @ 16% = 50.08 -> 50
      expect(const Money(313).applyBp(1600).minor, 50);
      // Exactly .5 rounds up: 3125 @ 16% = 500.0
      expect(const Money(3125).applyBp(1600).minor, 500);
      // 1 @ 5000bp = 0.5 -> 1 (half-up, not banker's)
      expect(const Money(1).applyBp(5000).minor, 1);
    });

    test('rounds negatives symmetrically', () {
      // A refund of the same amount must produce the same magnitude of tax,
      // otherwise refunding a bill leaves a residue in the tax account.
      expect(const Money(-3125).applyBp(1600).minor, -500);
      expect(const Money(-1).applyBp(5000).minor, -1);
    });

    test('zero and 0 bp are no-ops', () {
      expect(Money.zero.applyBp(1600).minor, 0);
      expect(const Money(12345).applyBp(0).minor, 0);
    });
  });

  group('split — bills must reconcile', () {
    test('splits evenly when divisible', () {
      final parts = const Money(900).split(3);
      expect(parts.map((p) => p.minor).toList(), [300, 300, 300]);
    });

    test('distributes the remainder instead of losing it', () {
      final parts = const Money(1000).split(3);
      expect(parts.map((p) => p.minor).toList(), [334, 333, 333]);
      expect(parts.fold(0, (sum, p) => sum + p.minor), 1000);
    });

    test('every split sums back to the original for many totals', () {
      for (var total = 0; total < 500; total++) {
        for (var n = 1; n <= 8; n++) {
          final parts = Money(total).split(n);
          expect(parts.length, n);
          expect(
            parts.fold(0, (sum, p) => sum + p.minor),
            total,
            reason: 'splitting $total into $n parts lost money',
          );
        }
      }
    });

    test('handles negative totals (refund split)', () {
      final parts = const Money(-1000).split(3);
      expect(parts.fold(0, (sum, p) => sum + p.minor), -1000);
    });

    test('rejects a non-positive part count', () {
      expect(() => const Money(100).split(0), throwsArgumentError);
    });
  });

  group('formatting', () {
    test('groups thousands with two decimals', () {
      expect(const Money(232000).amountText, '2,320.00');
      expect(const Money(60).amountText, '0.60');
      expect(const Money(0).amountText, '0.00');
    });

    test('prefixes the currency symbol', () {
      expect(const Money(232000).display, 'Rs 2,320.00');
      expect(const Money(100, 'USD').display, '\$ 1.00');
      expect(const Money(100, 'JPY').display, 'JPY 1.00');
    });
  });

  group('tryParse', () {
    test('parses major units into minor', () {
      expect(Money.tryParse('2320.50')?.minor, 232050);
      expect(Money.tryParse('2,320.50')?.minor, 232050);
      expect(Money.tryParse('60')?.minor, 6000);
    });

    test('rounds half-up at the paisa boundary', () {
      expect(Money.tryParse('0.005')?.minor, 1);
      expect(Money.tryParse('0.004')?.minor, 0);
    });

    test('returns null for junk so the field can show an error', () {
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse('   '), isNull);
    });

    test('round-trips through display', () {
      expect(Money.tryParse(const Money(232000).amountText)?.minor, 232000);
    });
  });
}
