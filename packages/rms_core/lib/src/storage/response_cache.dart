import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../errors/api_exception.dart';
import '../providers.dart';

/// A value and how it was obtained.
///
/// The distinction is the whole point of the cache: a floor plan read from the
/// server ten seconds ago and one restored from disk after a wifi drop are both
/// usable, but only one of them can be trusted to be current. Screens must be
/// able to say which they are showing.
@immutable
class Cached<T> {
  const Cached({
    required this.value,
    required this.cachedAt,
    required this.isFresh,
  });

  final T value;

  /// When the underlying payload came off the server — not when it was read
  /// from disk.
  final DateTime cachedAt;

  /// True when this came from the network on this call.
  final bool isFresh;

  /// How old the data is, whatever route it took to get here.
  Duration age(DateTime now) => now.difference(cachedAt);

  Cached<R> map<R>(R Function(T value) transform) => Cached<R>(
        value: transform(value),
        cachedAt: cachedAt,
        isFresh: isFresh,
      );
}

/// The last successful response for a read, kept on disk.
///
/// Only ever holds data the server has already sent us, so nothing here is a
/// secret the keystore should have had — and nothing here is authoritative
/// either. It exists so a waiter in the far corner of a dining room can still
/// read the menu.
///
/// Backed by `shared_preferences` because it is already loaded synchronously at
/// startup, which is what lets a screen decide what to render without an async
/// gap. The trade-off is that a write rewrites the whole preference file; that
/// is acceptable here because a cache write happens once per successful fetch,
/// not per interaction.
class ResponseCache {
  ResponseCache(this._prefs);

  final SharedPreferences _prefs;

  static const _prefix = 'cache:';
  static const _stampSuffix = ':at';

  /// Cache keys are branch-scoped by their callers. A menu cached for one
  /// outlet must never be served for another — the prices, the tax and the
  /// availability all differ.
  static String keyFor(String name, String? branchId) =>
      '$_prefix$name:${branchId ?? 'all'}';

  ({dynamic json, DateTime cachedAt})? read(String key) {
    final raw = _prefs.getString(key);
    final stamp = _prefs.getInt('$key$_stampSuffix');
    if (raw == null || stamp == null) return null;
    try {
      return (
        json: jsonDecode(raw),
        cachedAt: DateTime.fromMillisecondsSinceEpoch(stamp),
      );
    } on FormatException {
      // Unreadable cache is no cache. Leaving it would fail the same way on
      // every launch.
      unawaited(clear(key));
      return null;
    }
  }

  /// Above this a payload is not cached at all.
  ///
  /// `shared_preferences` rewrites its whole backing file on a commit, so a
  /// multi-megabyte menu would turn every successful fetch into a long
  /// main-thread write on exactly the low-end devices this app targets. Better
  /// to lose the offline copy for an outsized catalogue than to make the app
  /// stutter for every restaurant.
  static const maxPayloadBytes = 512 * 1024;

  Future<void> write(String key, Object? json) async {
    final encoded = jsonEncode(json);
    if (encoded.length > maxPayloadBytes) {
      // Drop any previous copy too: a stale small payload kept beside a fresh
      // oversized one would be served as if it were current.
      await clear(key);
      return;
    }
    await _prefs.setString(key, encoded);
    await _prefs.setInt(
      '$key$_stampSuffix',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> clear(String key) async {
    await _prefs.remove(key);
    await _prefs.remove('$key$_stampSuffix');
  }

  /// Drop everything. Called on sign-out and on switching outlet: the next user
  /// of a shared till must not be shown the previous one's data, and a cache
  /// that outlived a tenant switch would be a privacy failure rather than a
  /// convenience.
  Future<void> clearAll() async {
    for (final key in _prefs.getKeys().toList()) {
      if (key.startsWith(_prefix)) await _prefs.remove(key);
    }
  }
}

final responseCacheProvider = Provider<ResponseCache>(
  (ref) => ResponseCache(ref.watch(sharedPreferencesProvider)),
);

/// Fetch, falling back to the last good response when the network is the thing
/// that failed.
///
/// **Only a network failure falls back.** A 403 or a 422 is the server telling
/// us something true, and quietly answering it from a cache would hide a
/// permission change or a validation error behind stale data. A cache is for
/// "we could not ask", never for "we did not like the answer".
Future<Cached<T>> readThroughCache<T>({
  required ResponseCache cache,
  required String key,
  required Future<dynamic> Function() fetch,
  required T Function(dynamic json) parse,
}) async {
  try {
    final json = await fetch();
    await cache.write(key, json);
    return Cached(value: parse(json), cachedAt: DateTime.now(), isFresh: true);
  } on ApiException catch (error) {
    if (error.kind != ApiErrorKind.network) rethrow;
    final cached = cache.read(key);
    if (cached == null) rethrow;
    return Cached(
      value: parse(cached.json),
      cachedAt: cached.cachedAt,
      isFresh: false,
    );
  }
}
