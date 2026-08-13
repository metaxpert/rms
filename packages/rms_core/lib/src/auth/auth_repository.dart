import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/api_exception.dart';
import '../net/api_client.dart';
import '../providers.dart';
import '../storage/response_cache.dart';
import 'session.dart';

/// Talks to `/auth/*`. The only place login/logout wire formats are known.
class AuthRepository {
  AuthRepository(this._client, this._session, this._cache);

  final ApiClient _client;
  final Session _session;
  final ResponseCache _cache;

  /// Sign in and persist the token pair.
  ///
  /// Deliberately does NOT log the email or any token (brief §5/§31) — logs on
  /// a shared restaurant tablet are readable by anyone with a USB cable.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final data = await _client.post('/auth/login', {
      'email': email.trim(),
      'password': password,
    });

    if (data is! Map<String, dynamic> || data['accessToken'] is! String) {
      throw ApiException(
        ApiErrorKind.unknown,
        'The server returned an unexpected sign-in response.',
      );
    }

    await _session.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String?,
      expiresIn: data['expiresIn'] as String?,
    );
    // A fresh sign-in may be a different tenant, so the remembered outlet is
    // no longer meaningful and must be re-picked.
    await _session.setBranchId(null);
    await _session.rememberEmail(email.trim());
  }

  /// Best-effort server-side revocation, then unconditional local teardown.
  ///
  /// Local state is cleared even if the network call fails: a waiter tapping
  /// "Sign out" and handing the tablet to a colleague must never remain signed
  /// in because the wifi was down.
  Future<void> signOut() async {
    try {
      await _client.post('/auth/logout', {
        if (_session.refreshToken != null)
          'refreshToken': _session.refreshToken,
      });
    } on ApiException {
      // Ignored on purpose — see above.
    } finally {
      await _session.clear();
      // The next person to pick up a shared till must not be shown the
      // previous one's menu, floor or bills. A cache that outlived a sign-out
      // would be a privacy failure rather than a convenience.
      await _cache.clearAll();
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionProvider),
    ref.watch(responseCacheProvider),
  );
});
