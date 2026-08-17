import 'package:flutter_test/flutter_test.dart';
import 'package:rms_driver/src/features/location/data/fix_validator.dart';
import 'package:rms_driver/src/features/location/data/location_source.dart';

/// The client half of the GPS filter.
///
/// Deliberately the same cases as the server's `delivery-tracking.spec.ts`, run
/// against the Dart copy. The two implementations are separate on purpose — a
/// shared one would mean a codegen step across a Dart/TypeScript boundary for
/// eighty lines of arithmetic — so the thing that keeps them honest is that both
/// answer these questions identically. If one of these ever disagrees with its
/// TypeScript twin, the pair has drifted and the client will start posting fixes
/// the server throws away.
void main() {
  final now = DateTime(2026, 8, 17, 12, 30);
  GeoFix fix(double lat, double lng, DateTime at, {double? accuracyM}) =>
      GeoFix(lat: lat, lng: lng, at: at, accuracyM: accuracyM);

  // Two points about 240m apart on Margalla Road, Islamabad.
  final a = fix(33.7104, 73.0551, now.subtract(const Duration(minutes: 10)));
  final b = fix(33.7126, 73.0551, now.subtract(const Duration(minutes: 9)));

  group('metresBetween', () {
    test('measures a short city hop', () {
      final metres = metresBetween(a, b);
      expect(metres, greaterThan(200));
      expect(metres, lessThan(300));
    });

    test('is zero for the same point, and symmetric', () {
      expect(metresBetween(a, a), closeTo(0, 0.001));
      expect(metresBetween(a, b), closeTo(metresBetween(b, a), 0.001));
    });
  });

  group('the first fix of a run', () {
    test('is accepted with nothing to compare against', () {
      expect(rejectFix(fix(33.7126, 73.0551, now), null, now: now), isNull);
    });

    test('is refused if it is not a coordinate', () {
      expect(rejectFix(fix(999, 73, now), null, now: now),
          FixRejection.outOfRange);
      expect(rejectFix(fix(33.7, -4000, now), null, now: now),
          FixRejection.outOfRange);
      expect(rejectFix(fix(double.nan, 73, now), null, now: now),
          FixRejection.outOfRange);
    });
  });

  group('a fix the phone does not believe itself', () {
    test('is refused when the radius is wider than the block it claims', () {
      final guess = fix(33.7126, 73.0551, now, accuracyM: maxAccuracyM + 1);
      expect(rejectFix(guess, a, now: now), FixRejection.inaccurate);
    });

    test('is accepted at a plausible radius', () {
      final good = fix(33.7126, 73.0551, now, accuracyM: 12);
      expect(rejectFix(good, a, now: now), isNull);
    });
  });

  group('timestamps', () {
    test('refuses a fix from the future beyond clock skew', () {
      final ahead = fix(33.7126, 73.0551, now.add(const Duration(minutes: 10)));
      expect(rejectFix(ahead, a, now: now), FixRejection.future);
    });

    test('tolerates a phone clock a few seconds ahead', () {
      final ahead = fix(33.7126, 73.0551, now.add(const Duration(seconds: 20)));
      expect(rejectFix(ahead, a, now: now), isNull);
    });

    test('refuses a fix so old it describes a road already left', () {
      final old = fix(33.7126, 73.0551, now.subtract(const Duration(minutes: 45)));
      expect(rejectFix(old, a, now: now), FixRejection.stale);
    });
  });

  group('duplicates', () {
    test('refuses the same place again within the still-window', () {
      final parked = fix(a.lat, a.lng, a.at.add(const Duration(seconds: 30)));
      expect(rejectFix(parked, a, now: now), FixRejection.duplicate);
    });

    test('accepts "still here" once the window has passed — that is itself news', () {
      final stillParked = fix(a.lat, a.lng, a.at.add(const Duration(minutes: 2)));
      expect(rejectFix(stillParked, a, now: now), isNull);
    });

    test('refuses a fix older than the one already sent', () {
      // A queue flush can deliver out of order; the newest fix on file wins.
      final backwards = fix(33.7126, 73.0551, a.at.subtract(const Duration(minutes: 1)));
      expect(rejectFix(backwards, a, now: now), FixRejection.duplicate);
    });
  });

  group('impossible movement', () {
    test('refuses a jump no delivery bike could have made', () {
      // Islamabad → Lahore, ~270km, in one minute.
      final lahore = fix(31.5204, 74.3587, a.at.add(const Duration(minutes: 1)));
      expect(rejectFix(lahore, a, now: now), FixRejection.impossible);
    });

    test('allows a genuinely fast rider', () {
      // ~1.4km in a minute is about 85km/h — a motorway underpass, not a teleport.
      final fast = fix(33.7229, 73.0551, a.at.add(const Duration(minutes: 1)));
      expect(rejectFix(fast, a, now: now), isNull);
    });

    test('allows a large jump when the gap explains it', () {
      // The rider was offline across town for twenty minutes. This is the case
      // that must NOT be refused: it is exactly what a returning phone reports,
      // and calling it impossible throws away the only fix that says where the
      // bike now is.
      final earlier = fix(33.7104, 73.0551, now.subtract(const Duration(minutes: 29)));
      final acrossTown = fix(33.6844, 73.0479, now.subtract(const Duration(minutes: 1)));
      expect(rejectFix(acrossTown, earlier, now: now), isNull);
    });
  });

  group('rejection names', () {
    test('match the wire strings the server reports', () {
      // The server answers `{ recorded: false, reason: '<wire>' }`; a client that
      // logged a different vocabulary would make the two impossible to correlate
      // in an incident.
      expect(FixRejection.outOfRange.wire, 'out-of-range');
      expect(FixRejection.inaccurate.wire, 'inaccurate');
      expect(FixRejection.future.wire, 'future');
      expect(FixRejection.stale.wire, 'stale');
      expect(FixRejection.duplicate.wire, 'duplicate');
      expect(FixRejection.impossible.wire, 'impossible');
    });
  });
}
