import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persisted sign-in state: server address, tokens, and the active outlet.
///
/// Kept deliberately separate from the HTTP client so token storage can be
/// swapped (e.g. for `flutter_secure_storage` on managed devices) without
/// touching request logic.
class Session {
  Session._(this._prefs);

  static const _kBase = 'api_base';
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kExpiry = 'access_expires_at';
  static const _kBranch = 'branch_id';
  static const _kEmail = 'last_email';

  /// Android emulator reaches the host at 10.0.2.2. Overridden on the sign-in
  /// screen; production installs point at https://<host>/api.
  static const defaultBase = 'http://10.0.2.2:3399';

  final SharedPreferences _prefs;

  static Future<Session> load() async =>
      Session._(await SharedPreferences.getInstance());

  String get baseUrl => _prefs.getString(_kBase) ?? defaultBase;
  String? get accessToken => _prefs.getString(_kAccess);
  String? get refreshToken => _prefs.getString(_kRefresh);
  String? get branchId => _prefs.getString(_kBranch);
  String? get lastEmail => _prefs.getString(_kEmail);

  bool get isAuthenticated => accessToken != null;

  DateTime? get accessExpiresAt {
    final ms = _prefs.getInt(_kExpiry);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// True when the access token is gone or within [skew] of expiring.
  ///
  /// The refresh is done *before* the request rather than after a 401, so a
  /// waiter never sees a failure that we could have prevented. The skew covers
  /// the round trip plus clock drift between the phone and the server.
  bool accessTokenExpiring({Duration skew = const Duration(seconds: 60)}) {
    if (accessToken == null) return true;
    final expiry = accessExpiresAt;
    if (expiry == null) return false; // unknown lifetime: rely on 401 handling
    return DateTime.now().add(skew).isAfter(expiry);
  }

  Future<void> setBaseUrl(String value) async {
    final normalised = value.trim().replaceAll(RegExp(r'/+$'), '');
    await _prefs.setString(_kBase, normalised);
  }

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    String? expiresIn,
  }) async {
    await _prefs.setString(_kAccess, accessToken);
    if (refreshToken != null) {
      await _prefs.setString(_kRefresh, refreshToken);
    }
    final ttl = _parseTtl(expiresIn);
    if (ttl != null) {
      await _prefs.setInt(
        _kExpiry,
        DateTime.now().add(ttl).millisecondsSinceEpoch,
      );
    } else {
      await _prefs.remove(_kExpiry);
    }
  }

  Future<void> setBranchId(String? id) async {
    if (id == null) {
      await _prefs.remove(_kBranch);
    } else {
      await _prefs.setString(_kBranch, id);
    }
  }

  Future<void> rememberEmail(String email) => _prefs.setString(_kEmail, email);

  /// Clear credentials but keep the server address and remembered email — a
  /// waiter signing back in on the same till should not have to retype the API
  /// URL, which they typically do not know.
  Future<void> clear() async {
    await _prefs.remove(_kAccess);
    await _prefs.remove(_kRefresh);
    await _prefs.remove(_kExpiry);
    await _prefs.remove(_kBranch);
  }

  /// The API reports lifetimes as "15m" / "3600s" / "1h", not seconds.
  static Duration? _parseTtl(String? value) {
    if (value == null || value.isEmpty) return null;
    final match = RegExp(r'^(\d+)\s*([smhd]?)$').firstMatch(value.trim());
    if (match == null) return null;
    final amount = int.parse(match.group(1)!);
    return switch (match.group(2)) {
      'm' => Duration(minutes: amount),
      'h' => Duration(hours: amount),
      'd' => Duration(days: amount),
      _ => Duration(seconds: amount),
    };
  }

  /// Decode the JWT payload without verifying it.
  ///
  /// Verification is the server's job — this is only used to show who is signed
  /// in and to recover an expiry when the login response omits `expiresIn`.
  /// Nothing security-relevant may depend on it.
  Map<String, dynamic>? get accessTokenClaims {
    final token = accessToken;
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final normalised = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalised));
      final map = jsonDecode(decoded);
      return map is Map<String, dynamic> ? map : null;
    } catch (_) {
      return null;
    }
  }
}
