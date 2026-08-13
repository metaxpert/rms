import 'package:intl/intl.dart';

/// Integer minor-unit money (ADR: never floats).
///
/// Every amount that crosses the API is an integer number of the currency's
/// minor unit — paisa for PKR, cents for USD. Floating point is never used for
/// arithmetic here: a `double` cannot represent 0.1 exactly, and a restaurant
/// that rounds a few hundred bills a day accumulates a real, auditable
/// discrepancy against the GL.
///
/// The backend posts a balanced journal from these same integers, so any
/// rounding the app invents client-side would put the till out against the
/// ledger. All rounding therefore happens in exactly one place: [applyBp].
class Money {
  const Money(this.minor, [this.currency = 'PKR']);

  /// Amount in minor units (paisa). Always an integer; may be negative
  /// (refunds, discounts, change due).
  final int minor;
  final String currency;

  static const zero = Money(0);

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(minor + other.minor, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(minor - other.minor, currency);
  }

  /// Scale by a whole quantity (e.g. 3 × a line price). Quantities are integers
  /// on a restaurant ticket — you sell 3 naan, never 3.5.
  Money operator *(int qty) => Money(minor * qty, currency);

  bool operator >(Money other) => minor > other.minor;
  bool operator <(Money other) => minor < other.minor;
  bool get isZero => minor == 0;
  bool get isNegative => minor < 0;

  /// Apply a rate in basis points (1600 bp = 16%), rounding half-up.
  ///
  /// Half-up is the backend's behaviour when it rounds a bill to the nearest
  /// rupee (`Math.round`), NOT when it computes tax — line tax truncates, and
  /// [taxAt] is the method for that. Using Dart's `round()` on a double would be
  /// half-away-from-zero on a value that may not be exactly representable;
  /// integer arithmetic avoids the question entirely.
  Money applyBp(int bp) {
    final product = minor * bp;
    // Half-up on the absolute value, then restore the sign, so -0.5 and +0.5
    // round symmetrically (a discount and a charge behave the same way).
    final sign = product.isNegative ? -1 : 1;
    final abs = product.abs();
    return Money(sign * ((abs + 5000) ~/ 10000), currency);
  }

  /// Tax at [bp] basis points, **truncated** — the backend's `computeMenuLine`
  /// does `Math.floor(taxable * bp / 10000)`.
  ///
  /// Kept separate from [applyBp] because the difference is not cosmetic: on a
  /// taxable amount of 1 paisa at 50% the two disagree by a paisa, and a ticket
  /// that disagrees with the printed bill by a paisa is a ticket a waiter stops
  /// trusting. Every line the app prices must land on the same integer the
  /// server will store.
  Money taxAt(int bp) {
    if (bp <= 0) return Money(0, currency);
    return Money(_floorDiv(minor * bp, 10000), currency);
  }

  /// Round to the nearest multiple of [step] minor units — 100 is "to the
  /// nearest rupee", which is what `roundingEnabled` does at settlement.
  ///
  /// Mirrors the backend's `Math.round(preRound / 100) * 100`. JavaScript rounds
  /// a half toward +∞ (so -50 becomes 0, not -100); Dart's `round()` rounds away
  /// from zero. Halves are reached often here — every bill ending in 50 paisa —
  /// so the difference is a real one-rupee discrepancy, not a corner case.
  Money roundedToNearest(int step) {
    if (step <= 1) return this;
    return Money(_floorDiv(minor + step ~/ 2, step) * step, currency);
  }

  /// Floor division. Dart's `~/` truncates toward zero, which would round a
  /// negative amount the wrong way against `Math.floor`.
  static int _floorDiv(int a, int b) {
    final q = a ~/ b;
    return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q;
  }

  /// Split into [n] parts that sum EXACTLY back to this amount.
  ///
  /// Naive division loses paisa: 1000 / 3 = 333 each, and 1 paisa vanishes.
  /// The remainder is distributed one unit at a time across the leading parts,
  /// so a split bill always reconciles against the original total.
  List<Money> split(int n) {
    if (n <= 0) throw ArgumentError.value(n, 'n', 'must be positive');
    final base = minor ~/ n;
    var remainder = minor.remainder(n).abs();
    final step = minor.isNegative ? -1 : 1;
    return List.generate(n, (i) {
      var part = base;
      if (remainder > 0) {
        part += step;
        remainder--;
      }
      return Money(part, currency);
    });
  }

  /// Major units as a display string without the currency symbol: 232000 → "2,320.00".
  String get amountText => NumberFormat('#,##0.00').format(minor / 100);

  /// Full display: "Rs 2,320.00".
  String get display => '${_symbolFor(currency)} $amountText';

  static String _symbolFor(String code) {
    switch (code) {
      case 'PKR':
        return 'Rs';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return code;
    }
  }

  void _assertSameCurrency(Money other) {
    if (other.currency != currency) {
      throw ArgumentError('Cannot combine $currency with ${other.currency}');
    }
  }

  /// The largest amount this app will accept from a keyboard: ten billion
  /// major units.
  ///
  /// Not a business rule — no restaurant takes that — but a boundary. Past
  /// roughly 9.2×10^16 minor units an `int` wraps, and a wrapped total is a
  /// wrong bill that looks like a right one. Refusing early turns a fat-fingered
  /// "100000000000000000000" into a field error a waiter can see instead.
  static const maxParsableMinor = 1000000000000;

  static final _decimal = RegExp(r'^([+-]?)(\d*)(?:\.(\d*))?$');

  /// Parse a user-typed major-unit amount ("2320.50") into minor units.
  ///
  /// Parsed **decimally, never through a `double`** — this was the last place a
  /// float touched money, and it was wrong: `1.005 * 100` is 100.49999999999999
  /// in binary, so half-up rounding produced 1.00 where the documented
  /// behaviour is 1.01. Reading the digits directly makes the arithmetic exact
  /// and removes the only remaining route by which the ADR could be violated.
  ///
  /// Returns null when the text is not a valid amount, so callers can show a
  /// field error rather than silently treating garbage as zero.
  static Money? tryParse(String text, [String currency = 'PKR']) {
    final cleaned = text.replaceAll(',', '').replaceAll(' ', '').trim();
    if (cleaned.isEmpty) return null;

    final match = _decimal.firstMatch(cleaned);
    if (match == null) return null;

    final whole = match.group(2) ?? '';
    final fraction = match.group(3) ?? '';
    // "." and "+" alone are not amounts.
    if (whole.isEmpty && fraction.isEmpty) return null;

    final units = whole.isEmpty ? 0 : int.tryParse(whole);
    if (units == null) return null;
    // A ceiling on the digits, not just the value: `int.parse` on a hundred
    // digits throws, and a wrapped total is a wrong bill that looks right.
    if (units > maxParsableMinor ~/ 100) return null;

    final padded = fraction.padRight(3, '0');
    final paisa = int.parse(padded.substring(0, 2));
    // Half-up on the third decimal, on the ABSOLUTE value, so a refund rounds
    // the mirror of the charge it reverses.
    final roundUp = padded.codeUnitAt(2) >= 0x35; // '5'

    final minor = units * 100 + paisa + (roundUp ? 1 : 0);
    if (minor > maxParsableMinor) return null;
    return Money(match.group(1) == '-' ? -minor : minor, currency);
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  @override
  String toString() => display;
}
