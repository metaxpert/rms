import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';
import '../features/service/data/service_repository.dart';

/// Keeps the manager's figures current.
///
/// This is the app where staleness does the most damage: a manager reads a
/// number and then walks somewhere on the strength of it. So the snapshot is
/// refreshed on every order-touching event, on resume, and on a timer — and the
/// app bar says plainly when the live feed is down rather than letting old
/// numbers pass as current.
class LiveSync extends ConsumerStatefulWidget {
  const LiveSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LiveSync> createState() => _LiveSyncState();
}

class _LiveSyncState extends ConsumerState<LiveSync>
    with WidgetsBindingObserver {
  /// Events arrive in bursts as a service moves; one refetch per burst is
  /// plenty for a screen being glanced at.
  static const _coalesce = Duration(seconds: 1);

  /// Faster than the other apps' safety nets: kitchen elapsed times are
  /// computed server-side, so a board left alone stops ageing on screen.
  static const _pollInterval = Duration(seconds: 30);

  Timer? _coalesceTimer;
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
    _coalesceTimer?.cancel();
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
    ref.invalidate(serviceSnapshotProvider);
  }

  void _onEvent(RealtimeEvent event) {
    // A manager viewing "all outlets" wants every outlet's traffic; one with an
    // outlet selected does not.
    if (event.isForeignTo(ref.read(sessionProvider).branchId)) return;
    // Every bridged restaurant event moves one of these three tabs — orders,
    // the kitchen board, or the deliveries count.
    _coalesceTimer?.cancel();
    _coalesceTimer = Timer(_coalesce, _reconcile);
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
