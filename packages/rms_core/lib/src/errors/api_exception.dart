import 'dart:convert';

/// Why a request failed, in terms the UI can act on.
///
/// The screens should never branch on raw HTTP status codes — a waiter tapping
/// "Settle" needs to know whether to retry, re-authenticate, or call a manager,
/// and that decision belongs here rather than duplicated in every screen.
enum ApiErrorKind {
  /// No usable connection, DNS failure, or the request timed out. Retryable.
  network,

  /// Token missing, expired, or rejected. The session must be re-established.
  unauthorized,

  /// Authenticated but not permitted — e.g. the tenant lacks the `restaurant`
  /// feature, or the user's role forbids settling a bill.
  forbidden,

  /// The resource is gone (order deleted, table removed by a manager).
  notFound,

  /// The request was well-formed but rejected — validation, or a state-machine
  /// refusal such as settling an already-settled bill (the API returns 422).
  rejected,

  /// Server-side fault. Retryable, but the waiter should be told plainly.
  server,

  /// Anything we could not classify.
  unknown,
}

/// A failed API call, carrying the RFC 7807 `detail` the backend sends.
class ApiException implements Exception {
  ApiException(
    this.kind,
    this.message, {
    this.status,
    this.traceId,
    this.cause,
  });

  final ApiErrorKind kind;

  /// Human-readable text safe to show a waiter mid-service.
  final String message;

  final int? status;

  /// The backend's correlation id, echoed in its problem+json. Worth surfacing
  /// in a copyable form on error screens — it is what support needs to find the
  /// request in the API logs.
  final String? traceId;

  final Object? cause;

  /// Whether retrying the identical request could plausibly succeed.
  bool get isRetryable =>
      kind == ApiErrorKind.network || kind == ApiErrorKind.server;

  /// Whether the app should send the user back to sign-in.
  bool get requiresReauth => kind == ApiErrorKind.unauthorized;

  /// Build from an HTTP response, preferring the backend's problem+json detail
  /// over any invented client-side wording.
  factory ApiException.fromResponse(int status, String body) {
    final parsed = _parseProblem(body);
    final detail = parsed.detail;
    final kind = switch (status) {
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      400 || 409 || 422 => ApiErrorKind.rejected,
      >= 500 => ApiErrorKind.server,
      _ => ApiErrorKind.unknown,
    };
    return ApiException(
      kind,
      detail ?? _defaultMessage(kind, status),
      status: status,
      traceId: parsed.traceId,
    );
  }

  factory ApiException.network(Object cause) => ApiException(
        ApiErrorKind.network,
        'No connection to the server. Check the restaurant wifi and try again.',
        cause: cause,
      );

  factory ApiException.timeout(Duration after) => ApiException(
        ApiErrorKind.network,
        'The server took longer than ${after.inSeconds}s to respond. Try again.',
      );

  static String _defaultMessage(ApiErrorKind kind, int status) =>
      switch (kind) {
        ApiErrorKind.unauthorized => 'Your session has ended. Sign in again.',
        ApiErrorKind.forbidden =>
          'You do not have permission to do that. Ask a manager.',
        ApiErrorKind.notFound => 'That item no longer exists.',
        ApiErrorKind.rejected => 'The server rejected that request.',
        ApiErrorKind.server => 'The server had a problem. Try again shortly.',
        _ => 'Request failed ($status).',
      };

  static ({String? detail, String? traceId}) _parseProblem(String body) {
    if (body.isEmpty) return (detail: null, traceId: null);
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final detail =
            (decoded['detail'] ?? decoded['title'] ?? decoded['message']);
        return (
          detail: detail is String && detail.isNotEmpty ? detail : null,
          traceId: decoded['traceId'] as String?,
        );
      }
    } catch (_) {
      // Non-JSON body (a proxy error page, say). Fall through to defaults —
      // dumping raw HTML at a waiter helps nobody.
    }
    return (detail: null, traceId: null);
  }

  @override
  String toString() => message;
}
