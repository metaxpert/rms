import 'dart:math' as math;

import 'location_source.dart';

/// Why a fix was not worth sending. `null` means it was.
enum FixRejection {
  /// Not a coordinate at all.
  outOfRange,

  /// The platform itself says it does not know where the phone is.
  inaccurate,

  /// Timestamped ahead of the clock by more than plausible skew.
  future,

  /// So old it describes a road the rider has already left.
  stale,

  /// Same place, no meaningful gap — the marker would not move.
  duplicate,

  /// Implies a speed no delivery bike reaches.
  impossible;

  /// The wire form, so a rejection can be logged or counted by the same name the
  /// server uses for it.
  String get wire => switch (this) {
        FixRejection.outOfRange => 'out-of-range',
        FixRejection.inaccurate => 'inaccurate',
        FixRejection.future => 'future',
        FixRejection.stale => 'stale',
        FixRejection.duplicate => 'duplicate',
        FixRejection.impossible => 'impossible',
      };
}

/// Metres between two points, by the haversine formula.
double metresBetween(GeoFix a, GeoFix b) {
  const radius = 6371008.8; // IUGG mean earth radius
  double toRad(double d) => d * math.pi / 180;
  final dLat = toRad(b.lat - a.lat);
  final dLng = toRad(b.lng - a.lng);
  final lat1 = toRad(a.lat);
  final lat2 = toRad(b.lat);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
  return 2 * radius * math.asin(math.min(1, math.sqrt(h.toDouble())));
}

/// Whether a fix is worth sending, given the last one that was.
///
/// The same rules the server applies, deliberately duplicated rather than left
/// to it. Not because the server's copy is untrusted — it is the authority and
/// it stays — but because *this* copy is what stops the request being made at
/// all. A rider in a dead spot generates a fix every few seconds; forwarding the
/// nonsense ones costs mobile data the rider is paying for, battery on a phone
/// that must last a shift, and a queue slot that a real position needed.
///
/// The two copies agreeing is checked by tests on both sides rather than by
/// sharing code across a Dart/TypeScript boundary, which would mean a codegen
/// step for eighty lines of arithmetic.
///
/// Thresholds are generous on purpose: this is a filter against nonsense, not a
/// speed camera. Refusing a real fix is worse than storing a slightly noisy one,
/// because the real one may be the only evidence of where the bike went.
FixRejection? rejectFix(GeoFix next, GeoFix? previous, {DateTime? now}) {
  final clock = now ?? DateTime.now();

  if (next.lat.isNaN ||
      next.lng.isNaN ||
      next.lat.isInfinite ||
      next.lng.isInfinite) {
    return FixRejection.outOfRange;
  }
  if (next.lat < -90 || next.lat > 90 || next.lng < -180 || next.lng > 180) {
    return FixRejection.outOfRange;
  }

  final accuracy = next.accuracyM;
  if (accuracy != null && accuracy > maxAccuracyM) {
    return FixRejection.inaccurate;
  }

  final ageMs = clock.difference(next.at).inMilliseconds;
  if (ageMs < -maxClockSkew.inMilliseconds) return FixRejection.future;
  if (ageMs > maxFixAge.inMilliseconds) return FixRejection.stale;

  if (previous == null) return null;

  final gapMs = next.at.difference(previous.at).inMilliseconds;
  if (gapMs <= 0) return FixRejection.duplicate;

  final metres = metresBetween(previous, next);
  if (metres < minMoveM && gapMs < minStillGap.inMilliseconds) {
    return FixRejection.duplicate;
  }

  final kph = (metres / (gapMs / 1000)) * 3.6;
  // A large jump over a long gap is a rider who was offline, not a teleport — so
  // the check only bites while the fixes are close enough in time for speed to
  // mean anything. Getting this wrong the other way would discard exactly the
  // fix that says where a returning phone now is.
  if (gapMs <= impliedSpeedWindow.inMilliseconds && kph > maxImpliedKph) {
    return FixRejection.impossible;
  }

  return null;
}

/// A fix the platform admits is worse than this is a guess, not a position.
const maxAccuracyM = 500.0;

/// Phone clocks run ahead; more than this is a bad timestamp, not skew.
const maxClockSkew = Duration(minutes: 1);

/// Older than this describes a road the rider has already left.
const maxFixAge = Duration(minutes: 30);

/// Below this the marker would not visibly move.
const minMoveM = 10.0;

/// …unless this much time has passed, in which case "still here" is itself news.
const minStillGap = Duration(minutes: 1);

/// Speed is only meaningful between fixes this close together.
const impliedSpeedWindow = Duration(minutes: 5);

/// Faster than any delivery bike, with room for a motorway and a noisy sensor.
const maxImpliedKph = 200.0;
