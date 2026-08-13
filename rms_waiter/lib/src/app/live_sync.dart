import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';
import '../features/floor/data/floor_repository.dart';
import '../l10n/app_text.dart';
import '../features/notifications/service_notifier.dart';
import '../features/orders/data/order_repository.dart';
import '../features/ticket/application/outbox_controller.dart';

/// Keeps what is on screen in step with what the server believes, by three
/// independent routes.
///
/// It takes three because none of them is sufficient alone:
///
/// 1. **The socket.** Fast, and the only way the kitchen can tell a waiter that
///    food is up without polling. But delivery is best-effort — the bridge
///    subscribes on auto-deleted queues and a broker outage degrades silently
///    (ARCHITECTURE.md §4).
/// 2. **App resume.** A tablet in a pocket for ten minutes has missed
///    everything; the socket may not even have noticed it was gone.
/// 3. **A slow poll.** `RESTAURANT_ORDER_VOIDED` is emitted by the backend but
///    is **not** in the gateway's bridged set, so a void performed by a manager
///    or another till never arrives on the socket at all. Without this, a bill
///    cancelled elsewhere would sit on the floor plan for the rest of service.
///
/// Nothing here is load-bearing for correctness: every screen it refreshes also
/// refreshes on pull-to-refresh and on being opened. This makes the app current
/// without being asked, which during a service is the difference between
/// noticing food is ready and not.
class LiveSync extends ConsumerStatefulWidget {
  const LiveSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LiveSync> createState() => _LiveSyncState();
}

class _LiveSyncState extends ConsumerState<LiveSync>
    with WidgetsBindingObserver {
  /// Long enough to collapse the burst of events a single order transition
  /// produces, short enough that a waiter does not see a stale floor.
  static const _coalesce = Duration(milliseconds: 400);

  /// The safety net for changes the socket cannot carry. Deliberately slow: it
  /// exists to catch a void within a minute, not to be the update mechanism.
  static const _pollInterval = Duration(seconds: 60);

  Timer? _coalesceTimer;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The first frame has not run, so defer until the container is usable.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyAuth(ref.read(authControllerProvider).status);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _coalesceTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Whatever happened while the screen was off, we did not see. Ask.
        _reconcile();
        // A socket dropped in the background reconnects here rather than
        // waiting out its own backoff while a waiter stares at a stale table.
        if (ref.read(authControllerProvider).status == AuthStatus.ready) {
          ref.read(realtimeClientProvider).connect();
          ref.read(outboxControllerProvider.notifier).drain();
        }
        _startPolling();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Polling a backgrounded tablet drains a battery that has to last a
        // full service and refreshes screens nobody is looking at.
        _stopPolling();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _applyAuth(AuthStatus status) {
    final client = ref.read(realtimeClientProvider);
    if (status == AuthStatus.ready) {
      client.connect();
      _startPolling();
      // Asked for once a waiter is actually on the floor, rather than at the
      // sign-in screen where the request has no context to justify it.
      ref.read(serviceNotifierProvider).prepare();
    } else {
      // Holding a tenant-scoped socket open past sign-out would deliver the
      // next user's events to the previous user's screens.
      client.disconnect();
      _stopPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _reconcile());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _onEvent(RealtimeEvent event) {
    // The gateway room is tenant-scoped, so a multi-outlet tenant delivers
    // every outlet's traffic here.
    if (event.isForeignTo(ref.read(sessionProvider).branchId)) return;

    if (event.kind.isFoodReady) {
      _announceFoodReady(event);
      // Also buzzes the tablet, for the waiter who is not looking at the app.
      final messenger = ref.read(scaffoldMessengerKeyProvider).currentState;
      if (messenger != null) {
        final text = appText(messenger.context);
        final table = event.tableCode;
        ref.read(serviceNotifierProvider).foodReady(
              title: table == null
                  ? text.notifyFoodReadyTitle
                  : text.notifyFoodReadyAtTable(table),
              body: text.notifyFoodReadyBody,
            );
      }
    }
    if (event.kind.touchesOrders) _scheduleReconcile();
  }

  void _scheduleReconcile() {
    _coalesceTimer?.cancel();
    _coalesceTimer = Timer(_coalesce, _reconcile);
  }

  /// Refetch the server-derived state.
  ///
  /// Both providers are `autoDispose`, so invalidating them costs nothing when
  /// nobody is watching — this only issues requests for screens that are open.
  void _reconcile() {
    if (!mounted) return;
    ref.invalidate(floorSnapshotProvider);
    ref.invalidate(tableOrderProvider);
  }

  /// The one event a waiter must not miss.
  ///
  /// The payload's shape is unverified, so the table is named only when it is
  /// actually there; a wrong table number would send someone to the wrong pass.
  void _announceFoodReady(RealtimeEvent event) {
    final messenger = ref.read(scaffoldMessengerKeyProvider).currentState;
    if (messenger == null) return;
    final table = event.tableCode;
    final context = messenger.context;
    final text = appText(context);
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          backgroundColor: AppStatusColors.ready,
          content: Row(
            children: [
              const Icon(Icons.room_service_rounded, color: Colors.white),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  table == null
                      ? text.foodReadyAnywhere
                      : text.foodReadyAtTable(table),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  /// The socket completing a handshake is the app's connectivity signal.
  ///
  /// Better than a connectivity plugin: a tablet can be associated to an access
  /// point that cannot reach the internet, and retrying orders into that would
  /// burn every attempt. A handshake proves the API is reachable *and* the
  /// token is good.
  void _onRealtimeStatus(RealtimeStatus status) {
    if (status != RealtimeStatus.live) return;
    _reconcile();
    ref.read(outboxControllerProvider.notifier).drain();
  }

  /// Tell the waiter about work that finished while they were doing something
  /// else. A send that completed itself is exactly the kind of thing that must
  /// not be silent — they have to know whether to chase the kitchen.
  void _announceOutbox(OutboxState outbox) {
    if (outbox.lastResults.isEmpty) return;
    final sent = outbox.lastResults.where((r) => r.succeeded).toList();
    ref.read(outboxControllerProvider.notifier).acknowledge();
    if (sent.isEmpty) return;

    final messenger = ref.read(scaffoldMessengerKeyProvider).currentState;
    if (messenger == null) return;
    final text = appText(messenger.context);

    for (final result in sent) {
      final orderNo = result.orderNo;
      ref.read(serviceNotifierProvider).orderSent(
            title: text.notifyOrderSentTitle,
            body: orderNo == null || orderNo.isEmpty
                ? text.notifyOrderSentBody(result.tableId)
                : text.notifyOrderSentBodyNumbered(result.tableId, orderNo),
          );
    }

    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            sent.length == 1
                ? text.outboxOneSent
                : text.outboxManySent(sent.length),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (previous?.status != next.status) _applyAuth(next.status);
    });

    // Listening here is what subscribes the app to the socket at all — the
    // stream provider is otherwise cold.
    ref.listen(realtimeEventsProvider, (previous, next) {
      final event = next.valueOrNull;
      if (event != null) _onEvent(event);
    });

    ref.listen(realtimeStatusProvider, (previous, next) {
      final status = next.valueOrNull;
      if (status != null && status != previous?.valueOrNull) {
        _onRealtimeStatus(status);
      }
    });

    ref.listen(outboxControllerProvider, (previous, next) {
      _announceOutbox(next);
    });

    return widget.child;
  }
}

/// Lets code outside the widget tree — the socket listener — put a message in
/// front of the waiter wherever they happen to be.
final scaffoldMessengerKeyProvider = Provider<GlobalKey<ScaffoldMessengerState>>(
  (ref) => GlobalKey<ScaffoldMessengerState>(),
);
