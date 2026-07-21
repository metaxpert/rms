import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown for a non-2xx API response; carries the RFC7807 `detail` when present.
class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

/// Tiny client for the MetaXperts ERP API. Unwraps the `{data, meta}` envelope,
/// attaches the bearer token, and persists the token + base URL between launches.
class Api {
  Api._();
  static final Api instance = Api._();

  // Android emulator reaches the host machine at 10.0.2.2; overridable on the login screen.
  static const _defaultBase = 'http://10.0.2.2:3399';

  String _base = _defaultBase;
  String? _token;

  String get baseUrl => _base;
  bool get isAuthed => _token != null;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _base = p.getString('api_base') ?? _defaultBase;
    _token = p.getString('token');
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('api_base', _base);
    if (_token != null) {
      await p.setString('token', _token!);
    } else {
      await p.remove('token');
    }
  }

  Future<void> setBase(String base) async {
    _base = base.trim().replaceAll(RegExp(r'/$'), '');
    await _save();
  }

  Future<void> logout() async {
    _token = null;
    await _save();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<void> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_base/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException(res.statusCode, _detail(res.body) ?? 'Login failed');
    }
    final data = (jsonDecode(res.body)['data'] as Map<String, dynamic>);
    _token = data['accessToken'] as String;
    await _save();
  }

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body);
  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body);
  Future<dynamic> del(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final uri = Uri.parse('$_base$path');
    final req = http.Request(method, uri)..headers.addAll(_headers);
    if (body != null) req.body = jsonEncode(body);
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 401) {
      throw ApiException(401, 'Session expired — sign in again.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(res.statusCode, _detail(res.body) ?? 'Request failed (${res.statusCode})');
    }
    if (res.body.isEmpty) return null;
    final decoded = jsonDecode(res.body);
    return decoded is Map<String, dynamic> && decoded.containsKey('data') ? decoded['data'] : decoded;
  }

  String? _detail(String body) {
    try {
      final m = jsonDecode(body);
      if (m is Map) return (m['detail'] ?? m['title'] ?? m['message']) as String?;
    } catch (_) {}
    return null;
  }
}
