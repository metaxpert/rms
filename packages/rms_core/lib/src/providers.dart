import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'net/api_client.dart';
import 'auth/session.dart';

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
