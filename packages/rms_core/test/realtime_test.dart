import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';

/// A transport that never touches a socket, so the client's own behaviour —
/// when it connects, what it asks for a token, what it tears down — can be
/// asserted without a server.
class _FakeTransport implements RealtimeTransport {
  _FakeTransport({
    required this.url,
    required this.token,
    required this.callbacks,
  });

  final String url;
  final Future<String?> Function() token;
  final RealtimeCallbacks callbacks;

  int connectCalls = 0;
  int disconnectCalls = 0;
  int disposeCalls = 0;

  /// Tokens presented, in order — one per connection attempt, which is what
  /// proves a reconnect does not replay a 15-minute-old JWT.
  final presentedTokens = <String?>[];

  /// Messages sent to the gateway, in order — which is what proves a reconnect
  /// re-joins the delivery rooms it had before the drop.
  final emitted = <(String, Object?)>[];

  /// The same list flattened to strings.
  ///
  /// Records compare their fields with `==`, and two `Map` literals with equal
  /// contents are not `==` — so asserting on `emitted` directly fails on payloads
  /// that are visibly identical. Flattening sidesteps a confusing red test.
  List<String> get emittedSummary => emitted
      .map((e) => '${e.$1}:${(e.$2 as Map?)?['deliveryId'] ?? ''}')
      .toList(growable: false);

  @override
  void emit(String event, Object? payload) => emitted.add((event, payload));

  @override
  void connect() => connectCalls++;

  @override
  void disconnect() => disconnectCalls++;

  @override
  void dispose() => disposeCalls++;

  /// Simulate the handshake the real transport performs on every `onopen`.
  Future<void> simulateOpen() async {
    presentedTokens.add(await token());
    callbacks.onConnected();
  }

  void simulateDrop() => callbacks.onDisconnected('transport close');

  void simulateConnectError() => callbacks.onError('timeout');

  void simulateMessage(dynamic message) => callbacks.onMessage(message);
}

void main() {
  group('RestaurantEventType wire mapping', () {
    test('maps every bridged event', () {
      expect(
        RestaurantEventType.fromWire('restaurant.order_placed.v1'),
        RestaurantEventType.orderPlaced,
      );
      expect(
        RestaurantEventType.fromWire('restaurant.kds_ticket_ready.v1'),
        RestaurantEventType.kdsTicketReady,
      );
      expect(
        RestaurantEventType.fromWire('restaurant.bill_settled.v1'),
        RestaurantEventType.billSettled,
      );
      expect(
        RestaurantEventType.fromWire('restaurant.delivery_assigned.v1'),
        RestaurantEventType.deliveryAssigned,
      );
      expect(
        RestaurantEventType.fromWire('restaurant.reservation_created.v1'),
        RestaurantEventType.reservationCreated,
      );
    });

    test('an event this build does not know is not silently dropped', () {
      // A newer backend must make the app refresh, not go quiet.
      final type = RestaurantEventType.fromWire('restaurant.order_voided.v1');
      expect(type, RestaurantEventType.unknown);
      expect(type.touchesOrders, isTrue);
    });

    test('the empty sentinel never matches a real wire value', () {
      expect(RestaurantEventType.fromWire(''), RestaurantEventType.unknown);
      expect(RestaurantEventType.fromWire(null), RestaurantEventType.unknown);
    });

    test('only order events ask the floor to refresh', () {
      expect(RestaurantEventType.orderPlaced.touchesOrders, isTrue);
      expect(RestaurantEventType.kdsTicketReady.touchesOrders, isTrue);
      expect(RestaurantEventType.billSettled.touchesOrders, isTrue);
      expect(RestaurantEventType.deliveryAssigned.touchesOrders, isFalse);
      expect(RestaurantEventType.reservationCreated.touchesOrders, isFalse);
    });

    test('only the KDS ticket signals food is up', () {
      expect(RestaurantEventType.kdsTicketReady.isFoodReady, isTrue);
      expect(RestaurantEventType.orderConfirmed.isFoodReady, isFalse);
    });
  });

  group('RealtimeEvent parsing', () {
    test('reads the documented {type, payload} envelope', () {
      final event = RealtimeEvent.tryParse({
        'type': 'restaurant.kds_ticket_ready.v1',
        'payload': {'orderId': 'o1', 'branchId': 'b1', 'table': 'D1'},
      });

      expect(event, isNotNull);
      expect(event!.kind, RestaurantEventType.kdsTicketReady);
      expect(event.orderId, 'o1');
      expect(event.branchId, 'b1');
      expect(event.tableCode, 'D1');
    });

    test('keeps the raw type even when unrecognised', () {
      final event = RealtimeEvent.tryParse({'type': 'something.new.v9'});
      expect(event!.type, 'something.new.v9');
      expect(event.kind, RestaurantEventType.unknown);
      expect(event.payload, isEmpty);
    });

    test('rejects anything that is not the envelope', () {
      expect(RealtimeEvent.tryParse(null), isNull);
      expect(RealtimeEvent.tryParse('ready'), isNull);
      expect(RealtimeEvent.tryParse({'payload': {}}), isNull);
      expect(RealtimeEvent.tryParse({'type': ''}), isNull);
    });

    test('accepts snake_case payload keys', () {
      final event = RealtimeEvent.tryParse({
        'type': 'restaurant.order_placed.v1',
        'payload': {'order_id': 'o2', 'branch_id': 'b2'},
      });
      expect(event!.orderId, 'o2');
      expect(event.branchId, 'b2');
    });

    test('a loosely typed payload map is still readable', () {
      // socket_io hands back `Map<dynamic, dynamic>` from JSON.
      final event = RealtimeEvent.tryParse(<dynamic, dynamic>{
        'type': 'restaurant.order_served.v1',
        'payload': <dynamic, dynamic>{'orderId': 'o3'},
      });
      expect(event!.orderId, 'o3');
    });
  });

  group('branch filtering', () {
    RealtimeEvent event({String? branchId}) => RealtimeEvent(
          type: 'restaurant.order_placed.v1',
          payload: {if (branchId != null) 'branchId': branchId},
        );

    test('another outlet\'s event is filtered out', () {
      // The socket room is tenant-scoped, so a two-outlet tenant delivers the
      // other outlet's traffic to this tablet.
      expect(event(branchId: 'other').isForeignTo('mine'), isTrue);
    });

    test('our own outlet is kept', () {
      expect(event(branchId: 'mine').isForeignTo('mine'), isFalse);
    });

    test('an event with no branch is never assumed foreign', () {
      // Payload keys are unverified; discarding an event because we could not
      // find a branch in it would silently stop the floor updating.
      expect(event().isForeignTo('mine'), isFalse);
    });

    test('with no outlet chosen nothing is filtered', () {
      expect(event(branchId: 'other').isForeignTo(null), isFalse);
    });
  });

  group('RealtimeClient', () {
    late _FakeTransport transport;
    late List<String?> tokens;
    late RealtimeClient client;

    setUp(() {
      tokens = ['token-1', 'token-2', 'token-3'];
      client = RealtimeClient(
        urlProvider: () => 'https://rms.metaxperts.net',
        tokenProvider: () async => tokens.removeAt(0),
        transportFactory: ({required url, required token, required callbacks}) {
          return transport =
              _FakeTransport(url: url, token: token, callbacks: callbacks);
        },
      );
    });

    tearDown(() => client.dispose());

    test('starts idle and does not connect on its own', () {
      // An unauthenticated handshake is dropped by the gateway, so connecting
      // is the app's decision once someone is signed in.
      expect(client.status, RealtimeStatus.idle);
    });

    test('connects to the gateway origin', () {
      client.connect();
      expect(transport.url, 'https://rms.metaxperts.net');
      expect(transport.connectCalls, 1);
      expect(client.status, RealtimeStatus.connecting);
    });

    test('a second connect does not open a duplicate socket', () {
      client.connect();
      final first = transport;
      client.connect();
      expect(identical(transport, first), isTrue);
      expect(transport.connectCalls, 1, reason: 'events would arrive twice');
    });

    test('goes live once the handshake completes', () async {
      client.connect();
      await transport.simulateOpen();
      expect(client.status, RealtimeStatus.live);
      expect(client.isLive, isTrue);
    });

    test('every connection attempt presents a freshly fetched token', () async {
      // Access tokens last 15 minutes and rotate; a reconnect replaying the
      // token the socket first opened with would be rejected.
      client.connect();
      await transport.simulateOpen();
      transport.simulateDrop();
      await transport.simulateOpen();

      expect(transport.presentedTokens, ['token-1', 'token-2']);
    });

    test('a delivery subscription is sent to the gateway', () async {
      // Rider positions are published to a per-delivery room, not the tenant
      // room, so this call is the difference between a live map and a screen
      // that listens forever and hears nothing.
      client.connect();
      await transport.simulateOpen();
      client.subscribeToDelivery('d-1');

      expect(transport.emittedSummary, contains('delivery:subscribe:d-1'));
      expect(client.subscribedDeliveries, {'d-1'});
    });

    test('a reconnect re-joins the rooms it had before the drop', () async {
      // A room belongs to a socket. Without the replay, a recovered connection
      // reports itself live and delivers no positions — which on a customer's map
      // is indistinguishable from a rider who has parked.
      client.connect();
      await transport.simulateOpen();
      client.subscribeToDelivery('d-1');
      transport.emitted.clear();

      transport.simulateDrop();
      await transport.simulateOpen();

      expect(transport.emittedSummary, ['delivery:subscribe:d-1']);
    });

    test('unsubscribing stops it being replayed', () async {
      client.connect();
      await transport.simulateOpen();
      client.subscribeToDelivery('d-1');
      client.unsubscribeFromDelivery('d-1');
      transport.emitted.clear();

      transport.simulateDrop();
      await transport.simulateOpen();

      expect(transport.emitted, isEmpty);
      expect(client.subscribedDeliveries, isEmpty);
    });

    test('signing out forgets the rooms', () async {
      // `disconnect` is sign-out. Replaying the previous user's delivery rooms
      // onto the next session's socket is the leak this method exists to prevent.
      client.connect();
      await transport.simulateOpen();
      client.subscribeToDelivery('d-1');

      client.disconnect();
      expect(client.subscribedDeliveries, isEmpty);
    });

    test('a drop is reported as offline, not torn down', () async {
      client.connect();
      await transport.simulateOpen();
      transport.simulateDrop();

      expect(client.status, RealtimeStatus.offline);
      // The transport keeps retrying; disposing it here would end the feed for
      // the rest of the shift.
      expect(transport.disposeCalls, 0);
    });

    test('a connect error leaves the client retrying', () {
      client.connect();
      transport.simulateConnectError();
      expect(client.status, RealtimeStatus.offline);
      expect(transport.disposeCalls, 0);
    });

    test('emits parsed domain events', () async {
      client.connect();
      final received = <RealtimeEvent>[];
      client.events.listen(received.add);

      transport.simulateMessage({
        'type': 'restaurant.kds_ticket_ready.v1',
        'payload': {'orderId': 'o1'},
      });
      await Future<void>.delayed(Duration.zero);

      expect(received.single.kind, RestaurantEventType.kdsTicketReady);
      expect(client.lastEventAt, isNotNull);
    });

    test('a malformed message is dropped rather than guessed at', () async {
      client.connect();
      final received = <RealtimeEvent>[];
      client.events.listen(received.add);

      transport.simulateMessage('ready');
      await Future<void>.delayed(Duration.zero);

      expect(received, isEmpty);
      expect(client.lastEventAt, isNull);
    });

    test('status changes are broadcast to late listeners too', () async {
      final seen = <RealtimeStatus>[];
      client.statusChanges.listen(seen.add);

      client.connect();
      await transport.simulateOpen();
      await Future<void>.delayed(Duration.zero);

      expect(seen, [RealtimeStatus.connecting, RealtimeStatus.live]);
    });

    test('disconnect closes the socket so a sign-out cannot leak events',
        () async {
      client.connect();
      await transport.simulateOpen();
      client.disconnect();

      expect(transport.disconnectCalls, 1);
      expect(transport.disposeCalls, 1);
      expect(client.status, RealtimeStatus.idle);
    });

    test('reconnecting after a disconnect opens a new socket', () async {
      client.connect();
      final first = transport;
      client.disconnect();
      client.connect();

      expect(identical(transport, first), isFalse);
      expect(transport.connectCalls, 1);
    });

    test('a disposed client refuses to reconnect', () {
      client.dispose();
      client.connect();
      expect(client.status, RealtimeStatus.idle);
    });
  });

  /// These exist because their absence hid a bug that only production could
  /// show. The gateway is reached under the same path prefix as the API, and
  /// the prefix has to travel as Socket.IO's `path` option rather than in the
  /// URL, which reads a path as a namespace instead. Get it wrong and the
  /// handshake goes to the wrong origin — and because the socket is only ever
  /// an accelerator, nothing appears broken: the screens keep refreshing on
  /// resume and on their slow poll, and realtime is merely never live.
  group('where the socket connects', () {
    test('an API behind an /api prefix keeps the prefix, in the path', () {
      final target = socketIoTarget('https://rms.metaxperts.net/api');

      expect(target.origin, 'https://rms.metaxperts.net');
      expect(target.path, '/api/socket.io/');
    });

    test('an API on its own port has no prefix to carry', () {
      final target = socketIoTarget('http://10.0.2.2:3300');

      expect(target.origin, 'http://10.0.2.2:3300');
      expect(target.path, '/socket.io/');
    });

    test('a trailing slash does not become a doubled one', () {
      expect(socketIoTarget('https://host/api/').path, '/api/socket.io/');
      expect(socketIoTarget('https://host/').path, '/socket.io/');
    });

    test('a deeper mount point is carried whole', () {
      final target = socketIoTarget('https://host/erp/api');

      expect(target.origin, 'https://host');
      expect(target.path, '/erp/api/socket.io/');
    });

    test('a non-default port survives the split', () {
      expect(socketIoTarget('http://192.168.10.250:3300/api').origin,
          'http://192.168.10.250:3300');
    });

    /// A waiter typing a server address on the sign-in screen can type
    /// anything. Throwing here would crash the app on a typo; the connection
    /// error that follows names the address, which is more use.
    test('an unparseable address is passed through rather than thrown on', () {
      expect(socketIoTarget('not a url').origin, 'not a url');
      expect(socketIoTarget('not a url').path, '/socket.io/');
    });

    test('the production default resolves to the gateway, not the console', () {
      // The regression itself: stripping /api aimed this at the Next.js origin.
      final base = Environment.production.defaultApiBase;
      final target = socketIoTarget(Environment.production.socketUrl(base));

      expect(base, endsWith('/api'));
      expect(target.path, '/api/socket.io/');
    });

    test('socketUrl hands the base over intact, bar a trailing slash', () {
      const env = Environment.production;

      expect(env.socketUrl('https://host/api'), 'https://host/api');
      expect(env.socketUrl('https://host/api/'), 'https://host/api');
      expect(env.socketUrl('  https://host/api  '), 'https://host/api');
    });
  });
}
