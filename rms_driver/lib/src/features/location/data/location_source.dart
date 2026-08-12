import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Why the app cannot read the rider's position, in terms the UI can act on.
///
/// Distinguished because the remedies are different and a rider on a bike has
/// no patience for a generic "location unavailable": turning the phone's GPS on
/// is a different action from granting the app a permission, and a permanent
/// denial can only be undone in system settings.
enum LocationAvailability {
  ready,

  /// The device's location services are switched off entirely.
  serviceOff,

  /// The app was refused this time; asking again is allowed.
  denied,

  /// Refused permanently — only system settings can undo it.
  blocked,
}

@immutable
class GeoFix {
  const GeoFix({required this.lat, required this.lng, this.speedKph});

  final double lat;
  final double lng;
  final double? speedKph;
}

/// Where the rider is.
///
/// An interface rather than a direct geolocator call so the sharing logic can
/// be tested without a GPS, and so nothing else in the app has to know which
/// plugin is in use.
abstract class LocationSource {
  Future<LocationAvailability> ensureAvailable();

  /// Positions as the rider moves. Cancelling the subscription stops the fix.
  Stream<GeoFix> positions();
}

class DeviceLocationSource implements LocationSource {
  const DeviceLocationSource();

  @override
  Future<LocationAvailability> ensureAvailable() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAvailability.serviceOff;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.denied => LocationAvailability.denied,
      LocationPermission.deniedForever => LocationAvailability.blocked,
      _ => LocationAvailability.ready,
    };
  }

  @override
  Stream<GeoFix> positions() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          // Distance-based rather than time-based: a rider stopped at a light
          // should not be draining a battery that has to last a whole shift,
          // and a customer's map does not move while the bike does not.
          distanceFilter: 25,
        ),
      ).map(
        (position) => GeoFix(
          lat: position.latitude,
          lng: position.longitude,
          // The plugin reports metres per second; the API takes km/h.
          speedKph: position.speed.isFinite && position.speed >= 0
              ? position.speed * 3.6
              : null,
        ),
      );
}

final locationSourceProvider =
    Provider<LocationSource>((ref) => const DeviceLocationSource());
