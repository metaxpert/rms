import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';
import '../../location/data/fix_queue.dart';
import '../../location/data/fix_validator.dart';
import '../../location/data/location_source.dart';
import '../data/delivery_repository.dart';

/// What the rider's screen is doing right now.
@immutable
class RunState {
  const RunState({
    this.isWorking = false,
    this.error,
    this.delivery,
    this.sharing = false,
    this.locationProblem,
    this.lastPingAt,
    this.pingsSent = 0,
    this.queuedFixes = 0,
    this.cadence = TrackingCadence.active,
    this.foregroundOnly = false,
  });

  /// A transition is in flight. The one big button is dead while it is.
  final bool isWorking;

  final ApiException? error;

  /// The job as of the last successful call, ahead of any refetch.
  final Delivery? delivery;

  /// Whether the rider's position is being reported.
  final bool sharing;

  /// Set when sharing could not start. Null while it is working.
  final LocationAvailability? locationProblem;

  final DateTime? lastPingAt;
  final int pingsSent;

  /// Fixes taken but not yet accepted by the server.
  ///
  /// Surfaced because it is the difference between "no signal" and "not
  /// tracking", and a rider who can see the number knows the ride is being
  /// recorded even while the map is not moving.
  final int queuedFixes;

  /// How hard the phone is currently working for a fix.
  final TrackingCadence cadence;

  /// True when the rider granted foreground location but refused background.
  ///
  /// Tracking works in this state until the phone goes in a pocket, which is
  /// most of a run — so it is said out loud rather than discovered by a customer
  /// watching a marker that stopped.
  final bool foregroundOnly;

  RunState copyWith({
    bool? isWorking,
    ApiException? error,
    Delivery? delivery,
    bool? sharing,
    LocationAvailability? locationProblem,
    DateTime? lastPingAt,
    int? pingsSent,
    int? queuedFixes,
    TrackingCadence? cadence,
    bool? foregroundOnly,
    bool clearError = false,
    bool clearLocationProblem = false,
  }) =>
      RunState(
        isWorking: isWorking ?? this.isWorking,
        error: clearError ? null : (error ?? this.error),
        delivery: delivery ?? this.delivery,
        sharing: sharing ?? this.sharing,
        locationProblem: clearLocationProblem
            ? null
            : (locationProblem ?? this.locationProblem),
        lastPingAt: lastPingAt ?? this.lastPingAt,
        pingsSent: pingsSent ?? this.pingsSent,
        queuedFixes: queuedFixes ?? this.queuedFixes,
        cadence: cadence ?? this.cadence,
        foregroundOnly: foregroundOnly ?? this.foregroundOnly,
      );
}

/// Drives one delivery: the single next action, and location sharing.
///
/// A rider is one-handed, often on a bike, sometimes in rain. There is exactly
/// one forward action offered at a time — the one the job's current status
/// permits — because a menu of choices at a doorstep is a menu misread.
class RunController extends AutoDisposeFamilyNotifier<RunState, String> {
  @override
  RunState build(String deliveryId) {
    ref.onDispose(_stopSharing);
    return const RunState();
  }

  StreamSubscription<GeoFix>? _positions;
  Timer? _flushTimer;

  /// The last fix the server accepted, for the validator to compare against.
  ///
  /// Deliberately "accepted" rather than "seen": comparing against a fix that was
  /// itself refused would let one bad reading poison the next check.
  GeoFix? _lastAccepted;

  /// The timestamp of the last fix that was *captured* — sent or queued.
  ///
  /// The cadence throttle is measured between fix timestamps rather than between
  /// send attempts, which is both more correct and testable. Measured on the wall
  /// clock, a queue flush replaying six fixes would appear to breach the interval
  /// on every one of them, and a phone that stalled for a minute in the OS would
  /// have its next real fix throttled for a gap it did not cause.
  DateTime? _lastCapturedAt;

  TrackingCadence _cadence = TrackingCadence.active;

  DeliveryRepository get _deliveries => ref.read(deliveryRepositoryProvider);
  FixQueue get _queue => ref.read(fixQueueProvider(arg));

  /// Take the one action this job's status allows.
  ///
  /// [otp] is required for completion and is the customer's, read aloud at the
  /// door. The app never displays or caches it — the backend returns the code
  /// only at creation, and a rider who could see it could mark a delivery
  /// complete without ever arriving.
  Future<void> advance(Delivery delivery, {String? otp}) async {
    if (state.isWorking) return;
    final keepAlive = ref.keepAlive();
    state = state.copyWith(isWorking: true, clearError: true);
    try {
      final updated = await _deliveries.advance(
            id: delivery.id,
            from: delivery.status,
            otp: otp,
          ) ??
          await _deliveries.fetch(delivery.id);
      state = state.copyWith(isWorking: false, delivery: updated);
      if (updated.status.isTerminal) {
        _stopSharing();
        // The server refuses a fix on a finished run, so anything still queued is
        // history nobody will accept. Left behind it would be retried for the
        // rest of the shift.
        await _queue.clear();
        state = state.copyWith(queuedFixes: 0);
      } else {
        // The cadence follows the lifecycle: picking up a bag is the moment the
        // customer's map starts mattering.
        await retune(updated.status);
      }
      ref.invalidate(runBoardProvider);
      ref.invalidate(deliveryProvider(delivery.id));
    } on ApiException catch (error) {
      state = state.copyWith(isWorking: false, error: error);
    } finally {
      keepAlive.close();
    }
  }

  Future<void> markFailed(Delivery delivery, String reason) async {
    if (state.isWorking) return;
    final keepAlive = ref.keepAlive();
    state = state.copyWith(isWorking: true, clearError: true);
    try {
      final updated = await _deliveries.fail(
            id: delivery.id,
            reason: reason,
          ) ??
          await _deliveries.fetch(delivery.id);
      state = state.copyWith(isWorking: false, delivery: updated);
      _stopSharing();
      await _queue.clear();
      state = state.copyWith(queuedFixes: 0);
      ref.invalidate(runBoardProvider);
      ref.invalidate(deliveryProvider(delivery.id));
    } on ApiException catch (error) {
      state = state.copyWith(isWorking: false, error: error);
    } finally {
      keepAlive.close();
    }
  }

  /// Start reporting the rider's position for this job.
  ///
  /// Explicitly started rather than switched on with the app: a rider's
  /// location is only the restaurant's business while they are carrying an
  /// order, and a background stream running all shift is both a privacy
  /// question and a flat battery.
  Future<void> startSharing() async {
    if (state.sharing) return;
    final source = ref.read(locationSourceProvider);

    final availability = await source.ensureAvailable();
    if (availability != LocationAvailability.ready) {
      state = state.copyWith(sharing: false, locationProblem: availability);
      return;
    }

    // Asked for second, and only now. Android 11+ refuses to show a background
    // prompt alongside the foreground one, and iOS only escalates to "Always"
    // after "When in Use" has been granted — so requesting this first gets a
    // silent no on both. A refusal here is not fatal: tracking still works while
    // the app is open, and the rider is told which of the two they are getting.
    final background = await source.ensureBackground();

    _cadence = _cadenceFor(state.delivery?.status);
    state = state.copyWith(
      sharing: true,
      clearLocationProblem: true,
      cadence: _cadence,
      foregroundOnly: background == LocationAvailability.foregroundOnly,
      queuedFixes: _queue.read().length,
    );

    _subscribe();
    // Anything left from a previous session — a dead spot the rider rode through
    // before the process was killed — goes out now rather than waiting for the
    // next fix, which may be minutes away if they are parked.
    _scheduleFlush(immediate: true);
  }

  void stopSharing() => _stopSharing(notify: true);

  /// Re-tune the phone's effort to the job.
  ///
  /// Called when a run changes state, because the right cadence for a bag still
  /// on the pass is not the right cadence for a bike in traffic. Continuous
  /// high-accuracy GPS is close to the most expensive thing an app can do to a
  /// battery, and a rider's phone has to last the shift.
  Future<void> retune(DeliveryStatus? status) async {
    final next = _cadenceFor(status);
    if (!state.sharing || next == _cadence) return;
    _cadence = next;
    state = state.copyWith(cadence: next);
    // A cadence is a property of the platform subscription, so changing it means
    // a new one.
    await _positions?.cancel();
    _subscribe();
  }

  static TrackingCadence _cadenceFor(DeliveryStatus? status) =>
      switch (status) {
        DeliveryStatus.enRoute => TrackingCadence.active,
        DeliveryStatus.pickedUp => TrackingCadence.active,
        DeliveryStatus.assigned => TrackingCadence.idle,
        _ => TrackingCadence.idle,
      };

  void _subscribe() {
    _positions = ref
        .read(locationSourceProvider)
        .positions(cadence: _cadence)
        .listen(_onFix, onError: (_) {
      // A dropped fix is not worth interrupting a rider over; the stream
      // recovers on its own once the signal returns.
    });
  }

  /// Keep trying to empty the queue even while the phone is producing no fixes.
  ///
  /// Without this, a rider who stops inside a dead spot and then regains signal
  /// while still stationary never sends: the flush is driven by new fixes, and a
  /// parked bike produces none.
  void _scheduleFlush({bool immediate = false}) {
    _flushTimer?.cancel();
    if (immediate) unawaited(_flush());
    _flushTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (state.queuedFixes > 0) unawaited(_flush());
    });
  }

  /// One fix off the platform stream.
  ///
  /// Three gates before a request is made, cheapest first: the send throttle, the
  /// validator, then the network. The order is the point — the throttle costs
  /// nothing, the validator costs some arithmetic, and only what survives both is
  /// worth a rider's mobile data.
  Future<void> _onFix(GeoFix fix) async {
    // Throttle on top of the source's distance filter: a fast bike can cross the
    // filter every couple of seconds, and the customer's map does not need that.
    final last = _lastCapturedAt;
    final throttled =
        last != null && fix.at.difference(last) < _cadence.interval;

    // Refused locally rather than posted and refused remotely. The server checks
    // the same rules and remains the authority; this copy is what stops the
    // request being made at all, which is battery and mobile data a rider pays
    // for.
    if (!throttled && rejectFix(fix, _lastAccepted) == null) {
      _lastCapturedAt = fix.at;
      await _deliver(fix);
      return;
    }

    // A fix we are not recording is still evidence that the phone is awake and
    // may be back on a network, so it is a free moment to try the backlog. Without
    // this the queue waits on the flush timer even though the signal has returned.
    if (_queue.read().isNotEmpty) await _flush();
  }

  /// Send one fix, queueing it if the network will not take it.
  Future<void> _deliver(GeoFix fix) async {
    // Anything already waiting goes first, so the trail arrives in the order it
    // happened rather than newest-first.
    if (_queue.read().isNotEmpty) {
      await _queue.add(fix);
      await _flush();
      return;
    }

    try {
      await _post(fix);
      _lastAccepted = fix;
      state = state.copyWith(
        lastPingAt: DateTime.now(),
        pingsSent: state.pingsSent + 1,
      );
    } on ApiException catch (error) {
      // A rejected fix is gone for good: the server has judged it and a retry
      // gets the same answer. Everything else — no signal, a timeout, a 5xx — is
      // the connection, and the fix is worth keeping.
      if (error.kind == ApiErrorKind.rejected) return;
      await _queue.add(fix);
      state = state.copyWith(queuedFixes: _queue.read().length);
      _scheduleFlush();
    }
  }

  Future<void> _flush() async {
    final outcome = await flushFixes(queue: _queue, send: _post);
    if (outcome.sent > 0) {
      state = state.copyWith(
        lastPingAt: DateTime.now(),
        pingsSent: state.pingsSent + outcome.sent,
        queuedFixes: outcome.remaining,
      );
    } else if (outcome.remaining != state.queuedFixes) {
      state = state.copyWith(queuedFixes: outcome.remaining);
    }
    if (outcome.isDrained) _flushTimer?.cancel();
  }

  Future<void> _post(GeoFix fix) => _deliveries.track(
        id: arg,
        lat: fix.lat,
        lng: fix.lng,
        speedKph: fix.speedKph,
        headingDeg: fix.headingDeg,
        accuracyM: fix.accuracyM,
        recordedAt: fix.at,
      );

  void _stopSharing({bool notify = false}) {
    _positions?.cancel();
    _positions = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _lastCapturedAt = null;
    _lastAccepted = null;
    if (notify) state = state.copyWith(sharing: false);
  }
}

final runControllerProvider =
    NotifierProvider.autoDispose.family<RunController, RunState, String>(
  RunController.new,
);
