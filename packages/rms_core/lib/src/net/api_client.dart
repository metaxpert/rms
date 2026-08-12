import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../errors/api_exception.dart';
import '../auth/session.dart';

/// HTTP client for the MetaXperts ERP API.
///
/// Responsibilities kept here so no screen has to think about them:
///   * unwrapping the `{data: ...}` envelope
///   * attaching the bearer token
///   * refreshing an expiring access token — exactly once, even under
///     concurrency (see [_refresh])
///   * timeouts and bounded retry with jittered backoff
///   * idempotency keys on mutations, so a retried "settle" cannot double-post
class ApiClient {
  ApiClient(this._session, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final Session _session;
  final http.Client _http;

  /// A restaurant's wifi is often poor; 20s is long enough to ride out a weak
  /// signal but short enough that a waiter is not left staring at a spinner.
  static const _timeout = Duration(seconds: 20);
  static const _maxAttempts = 3;

  final _random = Random();

  /// In-flight refresh, shared by every caller that needs one.
  ///
  /// The backend ROTATES refresh tokens and rejects reuse with 401. If two
  /// requests both noticed an expiring token and each POSTed /auth/refresh, the
  /// first would consume the token and the second would get 401 — signing the
  /// waiter out in the middle of service. Memoising the future means the second
  /// caller awaits the first's result instead of starting its own.
  Future<void>? _refreshInFlight;

  /// Called when the session cannot be recovered and the user must sign in.
  /// Set by the app shell; kept as a callback so this layer has no UI import.
  void Function()? onAuthenticationLost;

  Future<dynamic> get(String path) => _send('GET', path);

  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, [Object? body]) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, [Object? body]) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Append the active branch to a branch-scoped read.
  String branchScoped(String path) {
    final branch = _session.branchId;
    if (branch == null) return path;
    return '$path${path.contains('?') ? '&' : '?'}branchId=$branch';
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    bool isRetryOfAuthFailure = false,
  }) async {
    // Refresh proactively so the waiter never eats an avoidable 401.
    if (_session.accessTokenExpiring() && _session.refreshToken != null) {
      await _refresh();
    }

    // One idempotency key per logical request, reused across transport retries
    // so a settle that timed out and got retried cannot post twice.
    final idempotencyKey = _isMutation(method) ? _newIdempotencyKey() : null;

    Object? lastError;
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final response = await _execute(method, path, body, idempotencyKey);

        if (response.statusCode == 401 && !isRetryOfAuthFailure) {
          // Token rejected despite our expiry check (clock drift, or revoked
          // server-side). Try exactly one recovery, then give up.
          if (_session.refreshToken != null) {
            await _refresh();
            return _send(method, path, body: body, isRetryOfAuthFailure: true);
          }
          _loseAuthentication();
          throw ApiException.fromResponse(401, response.body);
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          final error =
              ApiException.fromResponse(response.statusCode, response.body);

          // 409 on a request carrying an Idempotency-Key means the FIRST attempt
          // is still running server-side (idempotency.interceptor: "already in
          // progress"). The original will succeed and its response is stored for
          // replay, so backing off and retrying the same key collects that
          // response. Surfacing the 409 would tell a waiter the bill failed
          // while it was in fact being settled.
          final isIdempotencyInFlight =
              response.statusCode == 409 && idempotencyKey != null;

          // Retry transient server faults; surface everything else immediately
          // so a validation error is not silently attempted three times.
          if ((error.isRetryable || isIdempotencyInFlight) &&
              attempt < _maxAttempts) {
            lastError = error;
            await _backoff(attempt);
            continue;
          }
          if (error.requiresReauth) _loseAuthentication();
          throw error;
        }

        return _decode(response.body);
      } on ApiException {
        rethrow;
      } on TimeoutException {
        lastError = ApiException.timeout(_timeout);
        if (attempt == _maxAttempts) throw lastError;
        await _backoff(attempt);
      } on SocketException catch (e) {
        lastError = ApiException.network(e);
        if (attempt == _maxAttempts) throw lastError;
        await _backoff(attempt);
      } on http.ClientException catch (e) {
        lastError = ApiException.network(e);
        if (attempt == _maxAttempts) throw lastError;
        await _backoff(attempt);
      }
    }

    throw lastError is ApiException
        ? lastError
        : ApiException(ApiErrorKind.unknown, 'Request failed.');
  }

  Future<http.Response> _execute(
    String method,
    String path,
    Object? body,
    String? idempotencyKey,
  ) {
    final uri = Uri.parse('${_session.baseUrl}$path');
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_session.accessToken != null)
          'Authorization': 'Bearer ${_session.accessToken}',
        if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      });
    if (body != null) request.body = jsonEncode(body);

    return _http.send(request).then(http.Response.fromStream).timeout(_timeout);
  }

  /// Exchange the refresh token for a new access token.
  ///
  /// Single-flight: concurrent callers share one request. On failure the session
  /// is cleared and [onAuthenticationLost] fires — there is no way back without
  /// the user's password.
  Future<void> _refresh() {
    final existing = _refreshInFlight;
    if (existing != null) return existing;

    final future = _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
    _refreshInFlight = future;
    return future;
  }

  Future<void> _performRefresh() async {
    final token = _session.refreshToken;
    if (token == null) {
      _loseAuthentication();
      throw ApiException(ApiErrorKind.unauthorized, 'Signed out.');
    }
    try {
      final response = await _http
          .post(
            Uri.parse('${_session.baseUrl}/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': token}),
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _loseAuthentication();
        throw ApiException.fromResponse(response.statusCode, response.body);
      }

      final data = _decode(response.body);
      if (data is! Map<String, dynamic> || data['accessToken'] is! String) {
        _loseAuthentication();
        throw ApiException(
            ApiErrorKind.unauthorized, 'Could not renew your session.');
      }
      // The refresh token is rotated and the old one is dead the moment this
      // succeeds, so persist the replacement before anything else runs.
      await _session.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String?,
        expiresIn: data['expiresIn'] as String?,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      // A network blip during refresh is NOT a reason to sign the waiter out —
      // the token may still be valid once the wifi returns.
      throw ApiException.network(e);
    }
  }

  void _loseAuthentication() {
    unawaited(_session.clear());
    onAuthenticationLost?.call();
  }

  Future<void> _backoff(int attempt) {
    // Exponential with jitter, so a rack of tills coming back after a wifi drop
    // does not stampede the API in lockstep.
    final base = 200 * pow(2, attempt - 1).toInt();
    final jitter = _random.nextInt(150);
    return Future.delayed(Duration(milliseconds: base + jitter));
  }

  static bool _isMutation(String method) =>
      method == 'POST' || method == 'PUT' || method == 'PATCH';

  String _newIdempotencyKey() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Unwrap `{data: ...}`; pass anything else through untouched.
  static dynamic _decode(String body) {
    if (body.isEmpty) return null;
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
      return decoded['data'];
    }
    return decoded;
  }

  void dispose() => _http.close();
}
