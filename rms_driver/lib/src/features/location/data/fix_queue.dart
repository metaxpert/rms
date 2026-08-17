import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_core/rms_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_source.dart';

/// Fixes that could not be sent, kept until they can be.
///
/// The old behaviour was to drop a failed ping, and the reasoning written down
/// with it was sound as far as it went: *"a customer's map wants where the rider
/// IS, and replaying a position from four minutes ago would put the bike
/// somewhere it has already left."* Replaying stale fixes as if they were current
/// is indeed wrong.
///
/// But dropping them loses something that is not recoverable — the shape of the
/// journey. Pakistani mobile coverage has real holes; a rider crossing one for
/// six minutes produces a dozen fixes, and with all of them discarded the trail
/// jumps from the restaurant to the customer's street in one straight line
/// through buildings, and the ETA has nothing to learn from. Every fix carries
/// the timestamp the phone took it at, and the server orders by that column, so a
/// replayed fix is filed as history rather than mistaken for the present.
///
/// So: queued, ordered, capped, and persisted.
///
/// **Persisted** because the process does not survive a shift. Android will kill
/// a backgrounded app under memory pressure and the rider will not know; an
/// in-memory queue would take the dead spot's worth of history with it.
///
/// **Capped** because a rider whose phone has been offline for an hour must not
/// return with nine hundred requests to make. The cap discards the *oldest*
/// first: the newest fixes are the ones that still describe where the bike is.
class FixQueue {
  FixQueue(this._prefs, this._deliveryId);

  final SharedPreferences _prefs;
  final String _deliveryId;

  /// Roughly forty minutes of active-cadence fixes. Past that the earliest ones
  /// have no value that the later ones do not already carry.
  static const maxDepth = 160;

  /// Scoped per delivery so finishing one run cannot flush another's leftovers,
  /// and so clearing is a single key removal.
  String get _key => 'driver:fixq:$_deliveryId';

  List<GeoFix> read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(GeoFix.fromJson)
          .whereType<GeoFix>()
          .toList(growable: false);
    } on FormatException {
      // A half-written value from a process killed mid-flush. Dropping it is the
      // only option, and it is better than throwing on every read for the rest
      // of the shift.
      return const [];
    }
  }

  Future<void> add(GeoFix fix) async {
    final next = [...read(), fix];
    await _write(
        next.length <= maxDepth ? next : next.sublist(next.length - maxDepth));
  }

  Future<void> replace(List<GeoFix> fixes) => _write(fixes);

  Future<void> clear() => _prefs.remove(_key);

  Future<void> _write(List<GeoFix> fixes) => _prefs.setString(
        _key,
        jsonEncode(fixes.map((f) => f.toJson()).toList(growable: false)),
      );
}

/// The result of trying to empty the queue.
class FlushOutcome {
  const FlushOutcome({required this.sent, required this.remaining});

  final int sent;
  final int remaining;

  bool get isDrained => remaining == 0;
}

/// Sends queued fixes oldest-first, stopping at the first failure.
///
/// Stopping matters. A failure means the connection is not back, and pushing the
/// rest of the queue at the same wall wastes every one of them — the same
/// reasoning the waiter app's outbox uses, and the same reason its test exists.
/// Order matters too: the trail is only a trail if it arrives in the order it
/// happened.
Future<FlushOutcome> flushFixes({
  required FixQueue queue,
  required Future<void> Function(GeoFix fix) send,
}) async {
  final pending = queue.read();
  if (pending.isEmpty) return const FlushOutcome(sent: 0, remaining: 0);

  var sent = 0;
  for (final fix in pending) {
    try {
      await send(fix);
      sent++;
    } on ApiException catch (error) {
      // A rejected fix is gone for good — the server has judged it, and retrying
      // will get the same answer. Anything else is worth keeping for later.
      if (error.kind == ApiErrorKind.rejected) {
        sent++;
        continue;
      }
      break;
    }
  }

  final remaining = pending.sublist(sent);
  await (remaining.isEmpty ? queue.clear() : queue.replace(remaining));
  return FlushOutcome(sent: sent, remaining: remaining.length);
}

final fixQueueProvider = Provider.family<FixQueue, String>(
  (ref, deliveryId) =>
      FixQueue(ref.watch(sharedPreferencesProvider), deliveryId),
);
