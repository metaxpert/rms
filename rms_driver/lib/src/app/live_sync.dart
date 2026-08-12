import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';
import '../features/runs/data/delivery_repository.dart';

/// Keeps the rider's board current without them having to pull it.
///
/// `restaurant.delivery_assigned.v1` is bridged to the socket, so a job handed
/// out by dispatch reaches the phone immediately — which is the difference
/// between a rider leaving now and leaving when they next look. The socket is
/// still only an accelerator: it is best-effort, so a resume refresh and a slow
/// poll back it up.
class LiveSync extends ConsumerStatefulWidget {
  const LiveSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LiveSync> createState() => _LiveSyncState();
}

class _LiveSyncState extends ConsumerState<LiveSync>
    with WidgetsBindingObserver {
  /// Slower than the waiter's floor: a rider is looking at their phone far less
  /// often, and every wake costs battery they need for the shift.
  static const _pollInterval = Duration(seconds: 90);

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyAuth(ref.read(authControllerProvider).status);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _reconcile();
        if (ref.read(authControllerProvider).status == AuthStatus.ready) {
          ref.read(realtimeClientProvider).connect();
        }
        _startPolling();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
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
    } else {
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

  void _reconcile() {
    if (!mounted) return;
    // Both are autoDispose, so this costs nothing when no screen is open.
    ref.invalidate(runBoardProvider);
    ref.invalidate(deliveryProvider);
  }

  void _onEvent(RealtimeEvent event) {
    if (event.isForeignTo(ref.read(sessionProvider).branchId)) return;

    switch (event.kind) {
      case RestaurantEventType.deliveryAssigned:
        _announceNewRun();
        _reconcile();
      case RestaurantEventType.deliveryCompleted:
        _reconcile();
      case RestaurantEventType.unknown:
        // A type this build does not know may still be a delivery. Refreshing
        // costs one request; ignoring it could strand a job on the board.
        _reconcile();
      default:
        // Orders, bills and reservations are somebody else's screen.
        break;
    }
  }

  void _announceNewRun() {
    final messenger = ref.read(scaffoldMessengerKeyProvider).currentState;
    messenger
      ?..removeCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 6),
          backgroundColor: AppStatusColors.ready,
          content: Row(
            children: [
              Icon(Icons.two_wheeler_rounded, color: Colors.white),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'A run has been assigned.',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (previous?.status != next.status) _applyAuth(next.status);
    });
    ref.listen(realtimeEventsProvider, (previous, next) {
      final event = next.valueOrNull;
      if (event != null) _onEvent(event);
    });
    return widget.child;
  }
}

/// Lets the socket listener reach the rider wherever they are in the app.
final scaffoldMessengerKeyProvider = Provider<GlobalKey<ScaffoldMessengerState>>(
  (ref) => GlobalKey<ScaffoldMessengerState>(),
);
