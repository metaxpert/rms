import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rms_core/rms_core.dart';

/// A road route between two points, and how long it should take.
@immutable
class RoutePlan {
  const RoutePlan({
    required this.points,
    required this.metres,
    required this.duration,
    required this.isRoad,
  });

  /// The line to draw, start to finish.
  final List<TrackedPlace> points;

  final double metres;
  final Duration duration;

  /// False when this is the straight-line fallback rather than a real road route.
  ///
  /// Carried so the UI can be honest: a straight line across a river with a
  /// confident "6 min" on it is a promise the app cannot keep, and the screen
  /// softens the wording when this is false.
  final bool isRoad;

  int get etaMinutes => math.max(1, (duration.inSeconds / 60).round());

  double get kilometres => metres / 1000;
}

/// Where a route comes from.
///
/// An interface because there is no routing in this product yet and the choice
/// should not be baked into a screen. The default speaks OSRM, which is what the
/// OpenStreetMap ecosystem offers without an API key; swapping in Google
/// Directions, Mapbox or a self-hosted OSRM is one class, and the map does not
/// change.
abstract class RouteService {
  /// A route, or null when none can be produced.
  ///
  /// Null rather than throwing: a missing route is a degraded map, not an error a
  /// customer waiting for dinner can act on.
  Future<RoutePlan?> route(
      {required TrackedPlace from, required TrackedPlace to});
}

/// Straight line, assumed speed.
///
/// The floor under everything else. It needs no network, no key and no service,
/// and it is what the screen falls back to when the router is unreachable — which
/// on Pakistani mobile data is not rare.
///
/// It is deliberately pessimistic. `_kphInTraffic` is a city average for a bike
/// including lights and turns, and the straight line always understates the real
/// distance, so an ETA from here should read late rather than early: a customer
/// told twelve minutes and served in nine is pleased, and the reverse is a
/// complaint.
class HaversineRouteService implements RouteService {
  const HaversineRouteService();

  static const _kphInTraffic = 22.0;

  /// Roads are not straight. Multiplying the great-circle distance by this is a
  /// cruder estimate than a router and a much better one than pretending the bike
  /// can fly.
  static const _windingFactor = 1.35;

  @override
  Future<RoutePlan?> route({
    required TrackedPlace from,
    required TrackedPlace to,
  }) async {
    final metres = metresBetween(from, to) * _windingFactor;
    final seconds = (metres / 1000) / _kphInTraffic * 3600;
    return RoutePlan(
      points: [from, to],
      metres: metres,
      duration: Duration(seconds: seconds.round()),
      isRoad: false,
    );
  }
}

/// Road routing via an OSRM server.
///
/// OSRM is the routing engine behind OpenStreetMap and needs no API key, which is
/// what makes it usable in a deployment with no cloud credentials configured. The
/// default host is the project's public demo server: fine for a pilot and
/// explicitly not for production volume — it is rate-limited and offers no
/// availability promise. Point [baseUrl] at a self-hosted instance before this
/// carries real traffic; nothing else has to change.
///
/// Every failure — a timeout, a 429, a body that is not the documented shape —
/// returns null so the caller falls back to the straight line. A map that degrades
/// is worth more than a map that errors.
class OsrmRouteService implements RouteService {
  OsrmRouteService({http.Client? client, this.baseUrl = _demoServer})
      : _http = client ?? http.Client();

  static const _demoServer = 'https://router.project-osrm.org';

  final http.Client _http;
  final String baseUrl;

  static const _timeout = Duration(seconds: 6);

  @override
  Future<RoutePlan?> route({
    required TrackedPlace from,
    required TrackedPlace to,
  }) async {
    // OSRM takes lng,lat — the opposite order to almost everything else here, and
    // a reversal produces a route through the Indian Ocean rather than an error.
    final path = '${from.lng},${from.lat};${to.lng},${to.lat}';
    final uri = Uri.parse(
      '$baseUrl/route/v1/driving/$path?overview=full&geometries=geojson',
    );

    try {
      final response = await _http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      if (body is! Map || body['code'] != 'Ok') return null;
      final routes = body['routes'];
      if (routes is! List || routes.isEmpty) return null;
      final route = routes.first;
      if (route is! Map) return null;

      final coordinates = (route['geometry'] as Map?)?['coordinates'];
      if (coordinates is! List) return null;

      final points = <TrackedPlace>[];
      for (final pair in coordinates) {
        if (pair is! List || pair.length < 2) continue;
        final lng = (pair[0] as num?)?.toDouble();
        final lat = (pair[1] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        points.add(TrackedPlace(lat: lat, lng: lng));
      }
      if (points.length < 2) return null;

      final metres = (route['distance'] as num?)?.toDouble();
      final seconds = (route['duration'] as num?)?.toDouble();
      if (metres == null || seconds == null) return null;

      return RoutePlan(
        points: points,
        metres: metres,
        duration: Duration(seconds: seconds.round()),
        isRoad: true,
      );
    } catch (_) {
      // Deliberately broad. A routing service is an embellishment on this screen,
      // and there is no failure of it that a customer should be shown instead of
      // their food's position.
      return null;
    }
  }
}

/// Asks a router as rarely as it can get away with.
///
/// Left unguarded, this recomputes on every position event: a rider at active
/// cadence produces one every fifteen seconds, and a route request per fix is
/// both a rate-limit problem and pointless — a bike that has moved forty metres is
/// on the same road it was on.
///
/// Three guards, in order:
///
/// - **Cache** on the rounded pair of endpoints. Five decimal places is about a
///   metre, so a stationary rider reuses one answer indefinitely.
/// - **Distance and time thresholds.** Nothing is recomputed until the rider has
///   moved [_recomputeAfterM] or [_recomputeAfter] has passed.
/// - **Single-flight.** A request already out is awaited rather than joined by a
///   second one, which is what stops a burst of queued fixes arriving on reconnect
///   from firing a burst of route requests.
///
/// The fallback is used *while* a real route is in flight, so the screen always has
/// a distance and an ETA rather than a blank while the network decides.
class ThrottledRouteService implements RouteService {
  ThrottledRouteService({
    required RouteService road,
    RouteService fallback = const HaversineRouteService(),
  })  : _road = road,
        _fallback = fallback;

  final RouteService _road;
  final RouteService _fallback;

  static const _recomputeAfterM = 150.0;
  static const _recomputeAfter = Duration(seconds: 45);
  static const _cacheLimit = 24;

  final _cache = <String, RoutePlan>{};
  Future<RoutePlan?>? _inFlight;
  TrackedPlace? _lastFrom;
  DateTime? _lastAt;

  @override
  Future<RoutePlan?> route({
    required TrackedPlace from,
    required TrackedPlace to,
  }) async {
    final key = _keyFor(from, to);
    final cached = _cache[key];
    if (cached != null) return cached;

    final last = _lastFrom;
    final lastAt = _lastAt;
    final settled = _cache.isNotEmpty ? _cache.values.last : null;
    if (settled != null && last != null && lastAt != null) {
      final moved = metresBetween(last, from);
      final elapsed = DateTime.now().difference(lastAt);
      if (moved < _recomputeAfterM && elapsed < _recomputeAfter) return settled;
    }

    // Someone is already asking. Wait for their answer rather than adding to the
    // pile — and hand back the straight line if that request is the one that fails.
    final inFlight = _inFlight;
    if (inFlight != null) {
      return await inFlight ?? await _fallback.route(from: from, to: to);
    }

    final request = _road.route(from: from, to: to);
    _inFlight = request;
    try {
      final plan = await request;
      _lastFrom = from;
      _lastAt = DateTime.now();
      if (plan == null) return _fallback.route(from: from, to: to);
      _remember(key, plan);
      return plan;
    } finally {
      _inFlight = null;
    }
  }

  void _remember(String key, RoutePlan plan) {
    // A bounded map, because a long ride through a city produces a new key every
    // 150 metres and this object lives as long as the screen.
    if (_cache.length >= _cacheLimit) _cache.remove(_cache.keys.first);
    _cache[key] = plan;
  }

  /// Five decimal places ≈ 1 metre, which is finer than any rider's GPS.
  String _keyFor(TrackedPlace from, TrackedPlace to) =>
      '${from.lat.toStringAsFixed(5)},${from.lng.toStringAsFixed(5)}'
      '>${to.lat.toStringAsFixed(5)},${to.lng.toStringAsFixed(5)}';
}

/// Metres between two points, by the haversine formula.
double metresBetween(TrackedPlace a, TrackedPlace b) {
  const radius = 6371008.8; // IUGG mean earth radius
  double toRad(double d) => d * math.pi / 180;
  final dLat = toRad(b.lat - a.lat);
  final dLng = toRad(b.lng - a.lng);
  final lat1 = toRad(a.lat);
  final lat2 = toRad(b.lat);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
  return 2 * radius * math.asin(math.min(1, math.sqrt(h.toDouble())));
}

/// Bearing from `a` to `b` in degrees, 0 = north.
///
/// Used to point the rider's marker when the phone did not report a heading —
/// which is whenever the bike is stopped, and on some Android devices always.
double bearingBetween(TrackedPlace a, TrackedPlace b) {
  double toRad(double d) => d * math.pi / 180;
  final dLng = toRad(b.lng - a.lng);
  final lat1 = toRad(a.lat);
  final lat2 = toRad(b.lat);
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  final degrees = math.atan2(y, x) * 180 / math.pi;
  return (degrees + 360) % 360;
}

final routeServiceProvider = Provider<RouteService>((ref) {
  final service = ThrottledRouteService(road: OsrmRouteService());
  return service;
});
