import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../app/config/environment.dart';
import 'storage/secret_store.dart';

/// Persisted sign-in state: server address, tokens, and the active outlet.
///
/// Split by sensitivity (brief §29): access/refresh tokens go to the platform
/// keystore via [SecretStore]; everything else (base URL, branch, remembered
/// email) goes to `shared_preferences`, which is plain XML on disk and readable
/// by anyone who plugs a restaurant tablet into a laptop.
///
/// Token values are mirrored in memory after [load] so header construction on
/// the hot request path stays synchronous — the keystore is only touched on
/// read-at-startup and on write.
class Session {
  Session._(this._prefs, this._secrets);

  // Secret keys (keystore).
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  // Non-sensitive keys (preferences).
  static const _kBase = 'api_base';
  static const _kExpiry = 'access_expires_at';
  static const _kBranch = 'branch_id';
  static const _kEmail = 'last_email';

  final SharedPreferences _prefs;
  final SecretStore _secrets;

  String? _accessToken;
  String? _refreshToken;

  static Future<Session> load({SecretStore? secretStore}) async {
    final prefs = await SharedPreferences.getInstance();
    final secrets = secretStore ?? SecureSecretStore();
    final session = Session._(prefs, secrets);
    await session._hydrate();
    return session;
  }

  Future<void> _hydrate() async {
    _accessToken = await _secrets.read(_kAccess);
    _refreshToken = await _secrets.read(_kRefresh);
    await _migrateLegacyTokens();
  }

  /// Earlier builds stored the access token in `shared_preferences` under
  /// `token`. Move any such value into the keystore once, then erase the
  /// plaintext copy — otherwise upgrading users keep a readable token on disk
  /// forever.
  Future<void> _migrateLegacyTokens() async {
    const legacyKey = 'token';
    final legacy = _prefs.getString(legacyKey);
    if (legacy == null) return;
    if (_accessToken == null) {
      _accessToken = legacy;
      await _secrets.write(_kAccess, legacy);
    }
    await _prefs.remove(legacyKey);
  }

  String get baseUrl =>
      _prefs.getString(_kBase) ?? Environment.current.defaultApiBase;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get branchId => _prefs.getString(_kBranch);
  String? get lastEmail => _prefs.getString(_kEmail);

  bool get isAuthenticated => _accessToken != null;

  DateTime? get accessExpiresAt {
    final ms = _prefs.getInt(_kExpiry);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// True when the access token is gone or within [skew] of expiring.
  ///
  /// Refreshing *before* the request rather than after a 401 means a waiter
  /// never eats a failure we could have prevented. The skew covers the round
  /// trip plus clock drift between the tablet and the server.
  bool accessTokenExpiring({Duration skew = const Duration(seconds: 60)}) {
    if (_accessToken == null) return true;
    final expiry = accessExpiresAt;
    if (expiry == null) return false; // unknown lifetime: fall back to 401 handling
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
    _accessToken = accessToken;
    await _secrets.write(_kAccess, accessToken);
    if (refreshToken != null) {
      _refreshToken = refreshToken;
      await _secrets.write(_kRefresh, refreshToken);
    }
    final ttl = parseTtl(expiresIn);
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
  /// waiter signing back in on the same till should not have to retype an API
  /// URL they do not know.
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    await _secrets.delete(_kAccess);
    await _secrets.delete(_kRefresh);
    await _prefs.remove(_kExpiry);
    await _prefs.remove(_kBranch);
  }

  /// The API reports lifetimes as "15m" / "3600s" / "1h", not raw seconds.
  /// Visible for testing.
  static Duration? parseTtl(String? value) {
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

  /// Decode the JWT payload WITHOUT verifying it.
  ///
  /// Verification is the server's job. This is used only to show who is signed
  /// in and to gate UI affordances on `perms`; nothing security-relevant may
  /// depend on it (brief §21 — the client is never the authorization boundary).
  Map<String, dynamic>? get accessTokenClaims {
    final token = _accessToken;
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final decoded = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final map = jsonDecode(decoded);
      return map is Map<String, dynamic> ? map : null;
    } catch (_) {
      return null;
    }
  }

  /// Permissions carried by the access token, e.g. `restaurant:order:write`.
  /// `*` means all permissions (tenant admin).
  Set<String> get permissions {
    final claims = accessTokenClaims;
    final perms = claims?['perms'];
    if (perms is List) return perms.whereType<String>().toSet();
    return const {};
  }

  bool hasPermission(String permission) {
    final perms = permissions;
    return perms.contains('*') || perms.contains(permission);
  }

  String? get userId => accessTokenClaims?['sub'] as String?;
  String? get tenantId => accessTokenClaims?['tenantId'] as String?;
}
