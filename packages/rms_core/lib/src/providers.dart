import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/environment.dart';
import 'net/api_client.dart';
import 'auth/session.dart';
import 'realtime/realtime_client.dart';
import 'realtime/realtime_event.dart';

/// Core dependency graph (brief §3 — one state-management system, no competing
/// service locators).
///
/// [sessionProvider] has no default: [Session.load] is asynchronous and must
/// complete before the first frame, so `bootstrap()` overrides it at the root
/// `ProviderScope`. Reading it without that override is a programming error and
/// throws immediately rather than silently handing back an empty session.
final sessionProvider = Provider<Session>((ref) {
  throw StateError(
    'sessionProvider must be overridden in ProviderScope — see bootstrap().',
  );
});

/// Plain on-device storage for anything that is not a secret — the same
/// instance [Session] uses. Overridden alongside [sessionProvider] in
/// `bootstrap()`, because `getInstance()` is asynchronous and callers on the
/// draft path need it synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError(
    'sharedPreferencesProvider must be overridden in ProviderScope — see main().',
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(ref.watch(sessionProvider));
  ref.onDispose(client.dispose);
  return client;
});

/// The live feed. Created eagerly but **not connected** — connecting is the
/// app's decision, because only the app knows whether anyone is signed in, and
/// an unauthenticated handshake is disconnected by the gateway immediately.
final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  final session = ref.watch(sessionProvider);
  final api = ref.watch(apiClientProvider);
  final client = RealtimeClient(
    // The gateway is on the API's origin without the `/api` prefix.
    urlProvider: () => Environment.current.socketUrl(session.baseUrl),
    // Routed through the API client so a handshake that needs a new access
    // token shares its single-flight refresh rather than racing it.
    tokenProvider: api.freshAccessToken,
  );
  ref.onDispose(client.dispose);
  return client;
});

/// Domain events as they arrive.
///
/// Deliberately not `autoDispose`: this is a broadcast stream off a socket that
/// outlives any one screen, and re-subscribing per screen would drop events in
/// the gap between a waiter closing a ticket and opening the floor.
final realtimeEventsProvider = StreamProvider<RealtimeEvent>(
  (ref) => ref.watch(realtimeClientProvider).events,
);

/// Connection state, seeded with the current value so a widget built after the
/// socket connected does not sit on `loading` until the next transition.
final realtimeStatusProvider = StreamProvider<RealtimeStatus>((ref) async* {
  final client = ref.watch(realtimeClientProvider);
  yield client.status;
  yield* client.statusChanges;
});
