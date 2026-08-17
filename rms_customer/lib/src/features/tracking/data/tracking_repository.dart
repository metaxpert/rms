import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_core/rms_core.dart';

/// Live tracking for one delivery: a snapshot, then a stream of corrections.
///
/// The snapshot is the authority and the socket is an accelerator — the same rule
/// the rest of this product follows, and it is what makes the screen correct when
/// the socket never connects at all. A reconnect re-reads the snapshot rather than
/// resuming from whatever event happened to arrive last, because the events missed
/// during the drop are gone and the newest one is not necessarily the truth.
class TrackingRepository {
  TrackingRepository(this._client);

  final ApiClient _client;

  /// One read with everything a map needs.
  ///
  /// The staff route, deliberately. The customer app authenticates with a staff
  /// token today and calls staff endpoints; the ownership-scoped customer route
  /// (`/restaurant/customer/orders/:id/tracking`) exists server-side and is the
  /// correct destination, but reaching it means migrating this app's sign-in to
  /// customer tokens — a change to authentication rather than to a map. Switching
  /// is one line here once that migration happens.
  Future<DeliveryTracking> fetch(String deliveryId) async {
    final json =
        await _client.get('/restaurant/deliveries/$deliveryId/tracking');
    if (json is! Map<String, dynamic>) {
      throw ApiException(
        ApiErrorKind.unknown,
        'The restaurant\'s server returned something we could not read.',
      );
    }
    return DeliveryTracking.fromJson(json);
  }

  /// The rider's recorded path so far, oldest first.
  ///
  /// Used to draw where the bike has actually been, which is worth more than a
  /// straight line when the route service is unavailable — and is the only honest
  /// thing to draw for the part of the journey already ridden.
  Future<List<TrackedPosition>> trail(String deliveryId) async {
    try {
      final data =
          await _client.get('/restaurant/deliveries/$deliveryId/trail');
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(TrackedPosition.fromJson)
          .whereType<TrackedPosition>()
          .toList(growable: false);
    } on ApiException {
      // The trail is an embellishment. A customer who can see where their rider
      // *is* must not be shown an error because the history was unreadable.
      return const [];
    }
  }
}

final trackingRepositoryProvider = Provider<TrackingRepository>(
  (ref) => TrackingRepository(ref.watch(apiClientProvider)),
);

/// What the tracking screen knows right now.
@immutable
class TrackingState {
  const TrackingState({
    this.tracking,
    this.trail = const [],
    this.error,
    this.isLoading = true,
    this.isLive = false,
  });

  final DeliveryTracking? tracking;

  /// Where the bike has been. Grows as the ride goes on.
  final List<TrackedPosition> trail;

  /// Set only when there is nothing to show. A failure to refresh while a
  /// position is already on screen is not surfaced as an error: the marker is
  /// stale, the screen says so, and an error page would throw away the last thing
  /// the customer could see.
  final ApiException? error;

  final bool isLoading;

  /// Whether corrections are arriving over the socket, as opposed to by polling.
  ///
  /// Surfaced because the two feel different and a customer is entitled to know
  /// which they are watching — a map that updates every twenty seconds is not
  /// broken, but it is not live either.
  final bool isLive;

  bool get hasPosition => tracking?.hasPosition ?? false;

  TrackingState copyWith({
    DeliveryTracking? tracking,
    List<TrackedPosition>? trail,
    ApiException? error,
    bool? isLoading,
    bool? isLive,
    bool clearError = false,
  }) =>
      TrackingState(
        tracking: tracking ?? this.tracking,
        trail: trail ?? this.trail,
        error: clearError ? null : (error ?? this.error),
        isLoading: isLoading ?? this.isLoading,
        isLive: isLive ?? this.isLive,
      );
}

/// Drives one delivery's live tracking.
///
/// Three sources feed it, in descending order of authority:
///
/// 1. **The snapshot read**, on open and on every reconnect. The truth.
/// 2. **Socket position events**, which move the marker between reads. Filtered
///    to this delivery — the payload names it — and ignored when older than what
///    is already drawn, because a reconnect can deliver out of order.
/// 3. **A slow poll**, as the floor. It is what makes the screen work for a
///    principal the gateway will not admit, on a network that blocks websockets,
///    and while the socket is retrying its backoff.
///
/// The poll is deliberately not cancelled when the socket is live. It is slowed
/// down. A socket that reports itself connected while delivering nothing is a real
/// failure mode — a room that was never joined looks exactly like a rider who has
/// not moved — and a ninety-second reconciliation is what stops that being
/// invisible.
class TrackingController
    extends AutoDisposeFamilyNotifier<TrackingState, String> {
  @override
  TrackingState build(String deliveryId) {
    _listenToSocket();
    ref.onDispose(_stop);
    // Kicked off rather than awaited: `build` must return a state synchronously,
    // and the screen renders its loading shape from `isLoading` in the meantime.
    unawaited(_load(initial: true));
    return const TrackingState();
  }

  Timer? _poll;
  ProviderSubscription<AsyncValue<RealtimeEvent>>? _events;

  /// While the socket is delivering, this is the reconciliation interval; without
  /// it, it is the update interval.
  static const _livePoll = Duration(seconds: 90);
  static const _fallbackPoll = Duration(seconds: 20);

  TrackingRepository get _repository => ref.read(trackingRepositoryProvider);

  Future<void> refresh() => _load();

  Future<void> _load({bool initial = false}) async {
    try {
      final tracking = await _repository.fetch(arg);
      // The trail only on first load: it is history, and the socket extends it.
      final trail = initial ? await _repository.trail(arg) : state.trail;
      state = state.copyWith(
        tracking: tracking,
        trail: trail,
        isLoading: false,
        clearError: true,
      );

      if (initial) {
        // Ask the gateway for this delivery's room. Without it, position events
        // are published to a room this socket is not in and the screen listens
        // forever in silence.
        ref.read(realtimeClientProvider).subscribeToDelivery(arg);
      }

      if (tracking.isFinished) {
        // Nothing more will move. Holding a timer and a room open for a delivered
        // order is a phone kept awake for no reason.
        _stop();
        return;
      }
      _schedulePoll();
    } on ApiException catch (error) {
      // Only fatal while there is nothing on screen. Once a position has been
      // drawn, a failed refresh means "stale", which the map already says.
      state = state.copyWith(
        isLoading: false,
        error: state.hasPosition ? null : error,
      );
      _schedulePoll();
    }
  }

  void _listenToSocket() {
    _events = ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider,
        (previous, next) {
      final event = next.valueOrNull;
      if (event == null) return;

      // A status change is not something a position event can tell us, so it is
      // answered by re-reading rather than by guessing from the payload.
      if (event.kind == RestaurantEventType.deliveryCompleted &&
          event.deliveryId == arg) {
        unawaited(_load());
        return;
      }

      if (event.kind != RestaurantEventType.deliveryLocation) return;
      // The room should make this redundant. Checked anyway: a client that
      // subscribes to two deliveries shares one socket, and a screen drawing
      // another order's rider is the worst possible bug here.
      if (event.deliveryId != arg) return;

      final position = event.position;
      if (position == null) return;

      final tracking = state.tracking;
      if (tracking == null) return;

      final next$ = TrackedPosition(
        lat: position.lat,
        lng: position.lng,
        at: position.at,
        ageSeconds: 0,
        stale: false,
        speedKph: position.speedKph,
        headingDeg: position.headingDeg,
      );
      final merged = tracking.withPosition(next$);
      // `withPosition` returns the same instance for an out-of-order event, which
      // is the signal to leave the trail alone as well.
      if (identical(merged, tracking)) return;

      state = state.copyWith(
        tracking: merged,
        trail: [...state.trail, next$],
        isLive: true,
      );
      _schedulePoll();
    });
  }

  void _schedulePoll() {
    _poll?.cancel();
    _poll = Timer.periodic(
      state.isLive ? _livePoll : _fallbackPoll,
      (_) => unawaited(_load()),
    );
  }

  void _stop() {
    _poll?.cancel();
    _poll = null;
    _events?.close();
    _events = null;
    ref.read(realtimeClientProvider).unsubscribeFromDelivery(arg);
  }
}

final trackingControllerProvider = NotifierProvider.autoDispose
    .family<TrackingController, TrackingState, String>(TrackingController.new);
