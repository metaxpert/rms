import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers.dart';
import 'local_notifier_stub.dart'
    if (dart.library.io) 'local_notifier_device.dart';

/// A delivery moment worth interrupting someone for.
///
/// The list is short on purpose, and what is missing matters more than what is
/// here: **there is no case for a position update.** A rider at active cadence
/// reports every fifteen seconds, and a notification per fix would be forty
/// interruptions a delivery. The rule is that an alert marks a change of *state* —
/// something a person would tell you on the phone — never a change of coordinates.
enum DeliveryAlert {
  assigned,
  pickedUp,
  onTheWay,

  /// Inside the outer geofence: minutes away, worth putting shoes on for.
  nearby,

  /// Inside the inner geofence: at the gate.
  almostThere,

  /// The rider says they have arrived.
  arrived,

  completed;

  /// A stable channel-scoped notification id.
  ///
  /// One id per kind, so a second alert of the same kind *replaces* the first
  /// rather than stacking a column of near-identical rows down the shade.
  int get notificationId => 200 + index;
}

/// Getting a customer's attention when they are not looking at the app.
///
/// Local notifications only. There is no push service in this backend and no
/// device-token endpoint to register against, so nothing here can wake a killed
/// process — it fires while the app is alive, including backgrounded with the
/// screen off. Stating that plainly beats shipping something that resembles push
/// and silently is not.
///
/// Takes finished strings rather than the facts behind them, because this runs
/// outside the widget tree with no `BuildContext` to translate with. The caller has
/// one; pushing the lookup there is what keeps the app's last copy out of a
/// platform-channel wrapper.
abstract class LocalNotifier {
  /// Prepare the channel and ask for permission if the platform wants one.
  /// Returns false when notifications will not be delivered, so nothing else has
  /// to pretend they will.
  Future<bool> prepare();

  Future<void> show({
    required int id,
    required String title,
    required String body,
  });
}

final localNotifierProvider =
    Provider<LocalNotifier>((ref) => createLocalNotifier());

/// Remembers which alerts have already fired.
///
/// The duplicate problem here is not hypothetical. The tracking screen recovers by
/// re-reading a snapshot on every reconnect and every poll, so the same "rider is
/// nearby" fact is observed repeatedly — once a minute for the rest of the ride.
/// Geofences make it worse: a rider circling a block to find parking crosses the
/// same boundary four times.
///
/// So an alert is keyed by *what happened*, not by when it was noticed:
/// `<deliveryId>:<alert>`. Fired once per delivery, ever.
///
/// Persisted, because the interruption a customer minds is the one they get twice,
/// and a process restart must not be a licence to repeat the set. Capped, because
/// this is a phone and the keys are worthless a day later.
class AlertLedger {
  AlertLedger(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'delivery:alerts:fired';
  static const _limit = 120;

  /// Whether this is the first time, and claim it if so.
  ///
  /// One call rather than a check and a separate write: two position events
  /// arriving in the same frame would otherwise both see "not fired" and both
  /// notify.
  Future<bool> claim(String deliveryId, DeliveryAlert alert) async {
    final token = '$deliveryId:${alert.name}';
    final fired = _prefs.getStringList(_key) ?? const <String>[];
    if (fired.contains(token)) return false;

    final next = [...fired, token];
    await _prefs.setStringList(
      _key,
      next.length <= _limit ? next : next.sublist(next.length - _limit),
    );
    return true;
  }

  /// Forget one delivery's alerts. Used when a run is re-dispatched, where the
  /// journey genuinely starts again.
  Future<void> forget(String deliveryId) async {
    final fired = _prefs.getStringList(_key) ?? const <String>[];
    await _prefs.setStringList(
      _key,
      fired.where((t) => !t.startsWith('$deliveryId:')).toList(growable: false),
    );
  }
}

final alertLedgerProvider = Provider<AlertLedger>(
  (ref) => AlertLedger(ref.watch(sharedPreferencesProvider)),
);

/// Raises a delivery alert at most once, with the copy the caller supplies.
///
/// The single place an alert is decided, so the dedupe cannot be forgotten at a
/// call site — which is the failure this exists to prevent. Returns whether it
/// fired, which is what lets a test assert "the second crossing was silent".
@immutable
class DeliveryAlerts {
  const DeliveryAlerts({required this.notifier, required this.ledger});

  final LocalNotifier notifier;
  final AlertLedger ledger;

  Future<bool> raise({
    required String deliveryId,
    required DeliveryAlert alert,
    required String title,
    required String body,
  }) async {
    if (!await ledger.claim(deliveryId, alert)) return false;
    await notifier.show(id: alert.notificationId, title: title, body: body);
    return true;
  }
}

final deliveryAlertsProvider = Provider<DeliveryAlerts>(
  (ref) => DeliveryAlerts(
    notifier: ref.watch(localNotifierProvider),
    ledger: ref.watch(alertLedgerProvider),
  ),
);
