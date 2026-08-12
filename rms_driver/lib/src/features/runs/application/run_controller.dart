import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';
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

  RunState copyWith({
    bool? isWorking,
    ApiException? error,
    Delivery? delivery,
    bool? sharing,
    LocationAvailability? locationProblem,
    DateTime? lastPingAt,
    int? pingsSent,
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

  /// Throttle on top of the source's distance filter: a fast bike can cross the
  /// filter every couple of seconds, and the customer's map does not need that.
  static const _minPingGap = Duration(seconds: 15);
  DateTime? _lastSentAt;

  DeliveryRepository get _deliveries => ref.read(deliveryRepositoryProvider);

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
      if (updated.status.isTerminal) _stopSharing();
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
    final availability =
        await ref.read(locationSourceProvider).ensureAvailable();
    if (availability != LocationAvailability.ready) {
      state = state.copyWith(sharing: false, locationProblem: availability);
      return;
    }

    state = state.copyWith(sharing: true, clearLocationProblem: true);
    _positions =
        ref.read(locationSourceProvider).positions().listen(_send, onError: (_) {
      // A dropped fix is not worth interrupting a rider over; the stream
      // recovers on its own once the signal returns.
    });
  }

  void stopSharing() => _stopSharing(notify: true);

  Future<void> _send(GeoFix fix) async {
    final now = DateTime.now();
    final last = _lastSentAt;
    if (last != null && now.difference(last) < _minPingGap) return;
    _lastSentAt = now;
    try {
      await _deliveries.track(
        id: arg,
        lat: fix.lat,
        lng: fix.lng,
        speedKph: fix.speedKph,
      );
      state = state.copyWith(lastPingAt: now, pingsSent: state.pingsSent + 1);
    } on ApiException {
      // A failed ping is dropped, not queued: a customer's map wants where the
      // rider IS, and replaying a position from four minutes ago would put the
      // bike somewhere it has already left.
      _lastSentAt = last;
    }
  }

  void _stopSharing({bool notify = false}) {
    _positions?.cancel();
    _positions = null;
    _lastSentAt = null;
    if (notify) state = state.copyWith(sharing: false);
  }
}

final runControllerProvider =
    NotifierProvider.autoDispose.family<RunController, RunState, String>(
  RunController.new,
);
