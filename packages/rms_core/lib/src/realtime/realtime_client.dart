import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'realtime_event.dart';

/// Whether the app currently has a live feed from the gateway.
///
/// This is surfaced to the waiter, but as *information*, never as a blocker.
/// Every screen must be correct with the socket permanently [offline] — the
/// bridge subscribes on auto-deleted queues and degrades silently on a broker
/// outage (ARCHITECTURE.md §4), so "connected" is not a promise of delivery.
enum RealtimeStatus {
  /// Not connected, and not trying — nobody is signed in.
  idle,

  /// Trying, or retrying after a drop.
  connecting,

  /// Connected and joined to the tenant room.
  live,

  /// Was connected, is not now. The library is retrying in the background.
  offline,
}

/// Callbacks a transport raises. Kept as a plain object so the transport does
/// not have to know what [RealtimeClient] does with them.
@immutable
class RealtimeCallbacks {
  const RealtimeCallbacks({
    required this.onConnected,
    required this.onDisconnected,
    required this.onError,
    required this.onMessage,
  });

  final void Function() onConnected;
  final void Function(Object? reason) onDisconnected;
  final void Function(Object? error) onError;
  final void Function(dynamic message) onMessage;
}

/// The seam between the client's policy and Socket.IO's wire protocol.
///
/// It exists so the connect/token/teardown behaviour can be tested without a
/// server. That behaviour is where the expensive bugs live: a socket that
/// reconnects with a dead token, or one that outlives a sign-out and keeps
/// another user's tenant feed open.
abstract class RealtimeTransport {
  void connect();
  void disconnect();
  void dispose();

  /// Send a message to the gateway.
  ///
  /// Added for delivery subscriptions and deliberately kept this general: the
  /// alternative was a `subscribeToDelivery` on the transport, which would push a
  /// restaurant concept into the layer whose whole job is to know nothing but
  /// Socket.IO.
  void emit(String event, Object? payload);
}

typedef RealtimeTransportFactory = RealtimeTransport Function({
  required String url,
  required Future<String?> Function() token,
  required RealtimeCallbacks callbacks,
});

/// Live feed from the backend's Socket.IO gateway.
///
/// Three things about the gateway shape the design (ARCHITECTURE.md §4):
///
/// 1. **Every domain event arrives on one channel named `event`**, as
///    `{type, payload}` — there is no per-event channel to subscribe to.
/// 2. **The handshake must carry a valid access JWT**, and access tokens live
///    15 minutes. A reconnect an hour into a shift therefore needs a *fresh*
///    token, not the one the socket first opened with. [tokenProvider] is
///    re-invoked on every connection attempt for exactly that reason.
/// 3. **The room is tenant-scoped, not branch-scoped**, so a multi-outlet
///    tenant delivers every outlet's events to every tablet. Filtering is the
///    consumer's job (see [RealtimeEvent.isForeignTo]).
class RealtimeClient {
  RealtimeClient({
    required this.urlProvider,
    required this.tokenProvider,
    RealtimeTransportFactory? transportFactory,
  }) : _transportFactory = transportFactory ?? _socketIoTransport;

  /// Read late rather than captured, so a staff member changing the server
  /// address does not leave the socket pointed at the old one.
  final String Function() urlProvider;

  /// Must return a token that is valid *now*. In the app this is
  /// `ApiClient.freshAccessToken`, which refreshes through the same
  /// single-flight future the request path uses — two parallel refreshes would
  /// burn the rotating refresh token and sign the waiter out.
  final Future<String?> Function() tokenProvider;

  final RealtimeTransportFactory _transportFactory;

  final _events = StreamController<RealtimeEvent>.broadcast();
  final _statuses = StreamController<RealtimeStatus>.broadcast();

  RealtimeTransport? _transport;
  var _status = RealtimeStatus.idle;
  var _disposed = false;

  /// Domain events, in arrival order. Broadcast: the floor screen and an open
  /// ticket both listen, and neither should stop the other from hearing.
  Stream<RealtimeEvent> get events => _events.stream;

  /// Connection state changes. The current value is [status]; this stream only
  /// carries transitions, so a listener should seed itself from [status].
  Stream<RealtimeStatus> get statusChanges => _statuses.stream;

  RealtimeStatus get status => _status;

  bool get isLive => _status == RealtimeStatus.live;

  /// When the last event arrived. A feed that has been "live" for an hour
  /// without a single event during service is more likely broken than quiet,
  /// and a screen may choose to reconcile on that basis.
  DateTime? get lastEventAt => _lastEventAt;
  DateTime? _lastEventAt;

  /// Open the feed. Safe to call repeatedly — a second call while a socket
  /// already exists is ignored rather than opening a duplicate, which would
  /// double every event.
  void connect() {
    if (_disposed || _transport != null) return;

    _setStatus(RealtimeStatus.connecting);
    _transport = _transportFactory(
      url: urlProvider(),
      token: tokenProvider,
      callbacks: RealtimeCallbacks(
        onConnected: () {
          _setStatus(RealtimeStatus.live);
          // Rooms belong to a socket, so a reconnect starts with none. Replaying
          // them here is what stops a recovered connection from reporting itself
          // "live" while delivering no positions.
          for (final deliveryId in _watched) {
            _transport?.emit('delivery:subscribe', {'deliveryId': deliveryId});
          }
        },
        onDisconnected: (_) => _setStatus(RealtimeStatus.offline),
        // A connect error is not fatal: the transport keeps retrying with
        // backoff. Reporting it as `offline` rather than tearing down means a
        // tablet that boots before the wifi associates recovers by itself.
        onError: (_) => _setStatus(RealtimeStatus.offline),
        onMessage: _handleMessage,
      ),
    );
    _transport!.connect();
  }

  /// Follow one delivery's live position.
  ///
  /// Rider positions do **not** arrive in the tenant room. They are published to
  /// a per-delivery room the gateway only admits an authorised client to, so
  /// without this call a screen listening for
  /// [RestaurantEventType.deliveryLocation] hears nothing at all — which is the
  /// failure mode worth knowing about, because it looks exactly like a rider who
  /// has not started moving.
  ///
  /// Re-sent automatically on every reconnect: a room is a property of a socket,
  /// so a dropped connection silently loses it. [subscribedDeliveries] is the
  /// record that makes that replay possible.
  void subscribeToDelivery(String deliveryId) {
    if (deliveryId.isEmpty) return;
    _watched.add(deliveryId);
    _transport?.emit('delivery:subscribe', {'deliveryId': deliveryId});
  }

  void unsubscribeFromDelivery(String deliveryId) {
    _watched.remove(deliveryId);
    _transport?.emit('delivery:unsubscribe', {'deliveryId': deliveryId});
  }

  /// The deliveries this client wants to follow, whether or not the socket is up.
  Set<String> get subscribedDeliveries => Set.unmodifiable(_watched);

  final _watched = <String>{};

  /// Close the feed and stop retrying — used on sign-out, where continuing to
  /// hold a tenant-scoped socket open would leak the next user's events to a
  /// screen the previous user was looking at.
  void disconnect() {
    final transport = _transport;
    _transport = null;
    // Cleared, not kept: `disconnect` is sign-out, and replaying the previous
    // user's delivery rooms onto the next session's socket is precisely the leak
    // this method exists to prevent.
    _watched.clear();
    transport?.disconnect();
    transport?.dispose();
    _setStatus(RealtimeStatus.idle);
  }

  void _handleMessage(dynamic message) {
    final event = RealtimeEvent.tryParse(message);
    if (event == null) {
      // A message that is not the documented `{type, payload}` envelope is
      // dropped rather than guessed at; guessing would invent state.
      assert(() {
        debugPrint('realtime: ignoring unrecognised message: $message');
        return true;
      }());
      return;
    }
    _lastEventAt = DateTime.now();
    if (!_events.isClosed) _events.add(event);
  }

  void _setStatus(RealtimeStatus next) {
    if (_status == next) return;
    _status = next;
    if (!_statuses.isClosed) _statuses.add(next);
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _events.close();
    _statuses.close();
  }
}

/// Where Socket.IO should actually connect, given the API's base URL.
///
/// Socket.IO is handed an *origin*, and finds the gateway at its `path` option
/// (default `/socket.io/`). A path left in the URL is read as a **namespace**,
/// not as a prefix — so an API served from `https://host/api` cannot simply be
/// passed through: the prefix would be silently reinterpreted and the client
/// would handshake against `https://host/socket.io/`, which behind this
/// deployment's reverse proxy is the web console, not the gateway.
///
/// So the prefix is moved from the URL to the path, where it belongs:
///
/// | API base                    | origin              | path              |
/// | --------------------------- | ------------------- | ----------------- |
/// | `https://host/api`          | `https://host`      | `/api/socket.io/` |
/// | `http://10.0.2.2:3300`      | `http://10.0.2.2:3300` | `/socket.io/`  |
///
/// A base that cannot be parsed as an absolute URL is handed back untouched
/// with the default path: it is not this function's job to decide that a
/// server address a restaurant typed is invalid, and the connection error that
/// follows names the address, which is more use than an exception here.
({String origin, String path}) socketIoTarget(String apiBase) {
  const defaultPath = '/socket.io/';
  final uri = Uri.tryParse(apiBase.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return (origin: apiBase.trim(), path: defaultPath);
  }

  var prefix = uri.path;
  while (prefix.endsWith('/')) {
    prefix = prefix.substring(0, prefix.length - 1);
  }

  return (
    origin: uri.origin,
    path: prefix.isEmpty ? defaultPath : '$prefix$defaultPath',
  );
}

/// The real transport.
///
/// Reconnection is left to the library rather than hand-rolled, because its
/// backoff is already jittered — a dining room of tablets coming back after a
/// wifi drop must not retry in lockstep — and because `setAuthFn` is re-run on
/// every `onopen`, which is what makes each retry present a current token.
RealtimeTransport _socketIoTransport({
  required String url,
  required Future<String?> Function() token,
  required RealtimeCallbacks callbacks,
}) =>
    _SocketIoTransport(url: url, token: token, callbacks: callbacks);

class _SocketIoTransport implements RealtimeTransport {
  _SocketIoTransport({
    required String url,
    required Future<String?> Function() token,
    required RealtimeCallbacks callbacks,
  }) {
    final target = socketIoTarget(url);
    _socket = io.io(
      target.origin,
      io.OptionBuilder()
          // The gateway sits under whatever prefix the API does, and Socket.IO
          // reads a path in the URL as a namespace rather than a prefix, so the
          // prefix has to arrive here instead.
          .setPath(target.path)
          // Websocket only: the polling fallback would open a long-poll loop
          // against restaurant wifi and burn battery on a device that is
          // already carried all shift.
          .setTransports(['websocket'])
          .disableAutoConnect()
          // A new Manager per client, so a reconnect cannot silently reuse a
          // cached manager still holding the previous session's handshake.
          .enableForceNew()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(30000)
          .setAuthFn((complete) async {
            final value = await token();
            complete({if (value != null) 'token': value});
          })
          .build(),
    );

    _socket
      ..onConnect((_) => callbacks.onConnected())
      ..onDisconnect(callbacks.onDisconnected)
      ..onConnectError(callbacks.onError)
      ..onError(callbacks.onError)
      // Every domain event, on the one channel the gateway publishes to.
      ..on('event', callbacks.onMessage);
  }

  late final io.Socket _socket;

  @override
  void connect() => _socket.connect();

  @override
  void disconnect() => _socket.disconnect();

  @override
  void emit(String event, Object? payload) => _socket.emit(event, payload);

  @override
  void dispose() {
    _socket.clearListeners();
    _socket.dispose();
  }
}
