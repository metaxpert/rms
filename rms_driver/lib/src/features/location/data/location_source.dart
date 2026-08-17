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

  /// Foreground location was granted, background was not.
  ///
  /// A distinct outcome rather than an error, because tracking genuinely works
  /// in this state — right up to the moment the rider pockets the phone, which
  /// is most of a run. The UI says so instead of claiming success and going
  /// quiet.
  foregroundOnly,
}

/// How hard to work for a fix.
///
/// Continuous high-accuracy GPS is roughly the most expensive thing an app can
/// do to a battery, and a rider's phone has to last a shift. So the cadence
/// follows the job rather than being one setting: a bag still on the pass does
/// not need the fidelity a bike in traffic does.
enum TrackingCadence {
  /// Waiting at the restaurant — assigned, not yet collected. Coarse and rare;
  /// the customer's map has nothing to animate yet.
  idle(
    accuracy: LocationAccuracy.medium,
    distanceFilter: 100,
    interval: Duration(seconds: 60),
  ),

  /// Carrying the order. This is the one a customer is watching.
  active(
    accuracy: LocationAccuracy.high,
    distanceFilter: 25,
    interval: Duration(seconds: 15),
  ),

  /// Close to the door, where a customer is looking out of a window and metres
  /// matter more than battery.
  approaching(
    accuracy: LocationAccuracy.best,
    distanceFilter: 10,
    interval: Duration(seconds: 8),
  );

  const TrackingCadence({
    required this.accuracy,
    required this.distanceFilter,
    required this.interval,
  });

  final LocationAccuracy accuracy;

  /// Metres of movement before the platform reports again. Distance-based is
  /// what keeps a rider stopped at a light from draining anything.
  final int distanceFilter;

  /// The floor on how often a fix is *sent*. The platform may report more often
  /// than this; the sender throttles to it.
  final Duration interval;
}

@immutable
class GeoFix {
  const GeoFix({
    required this.lat,
    required this.lng,
    required this.at,
    this.speedKph,
    this.headingDeg,
    this.accuracyM,
  });

  final double lat;
  final double lng;

  /// When the phone took the fix — not when it was sent. The two differ by
  /// however long the phone was offline, and the queue depends on the
  /// difference.
  final DateTime at;

  final double? speedKph;
  final double? headingDeg;
  final double? accuracyM;

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'at': at.toUtc().toIso8601String(),
        if (speedKph != null) 'speedKph': speedKph,
        if (headingDeg != null) 'headingDeg': headingDeg,
        if (accuracyM != null) 'accuracyM': accuracyM,
      };

  static GeoFix? fromJson(Map<String, dynamic> json) {
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    final at = DateTime.tryParse('${json['at']}');
    if (lat == null || lng == null || at == null) return null;
    return GeoFix(
      lat: lat,
      lng: lng,
      at: at.toLocal(),
      speedKph: (json['speedKph'] as num?)?.toDouble(),
      headingDeg: (json['headingDeg'] as num?)?.toDouble(),
      accuracyM: (json['accuracyM'] as num?)?.toDouble(),
    );
  }
}

/// Where the rider is.
///
/// An interface rather than a direct geolocator call so the sharing logic can
/// be tested without a GPS, and so nothing else in the app has to know which
/// plugin is in use.
abstract class LocationSource {
  /// Ask for what is needed to track in the foreground.
  Future<LocationAvailability> ensureAvailable();

  /// Ask for the background grant, having already got the foreground one.
  ///
  /// Separate because the platforms require it to be: Android 11+ refuses to
  /// show a background prompt in the same breath as the foreground one, and iOS
  /// will only escalate to "Always" after "When in Use" has been lived with.
  /// Calling this first gets a silent refusal on both.
  Future<LocationAvailability> ensureBackground();

  /// Positions as the rider moves. Cancelling the subscription stops the fix.
  ///
  /// [cadence] decides accuracy, distance filter, and — on Android — whether a
  /// foreground service is held. A change of cadence means a new subscription.
  Stream<GeoFix> positions({TrackingCadence cadence = TrackingCadence.active});
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
  Future<LocationAvailability> ensureBackground() async {
    final permission = await Geolocator.checkPermission();
    // `always` is the background grant on both platforms. `whileInUse` means the
    // rider said yes to the app being open and nothing more — which is a real,
    // reportable state, not a failure.
    if (permission == LocationPermission.always) {
      return LocationAvailability.ready;
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationAvailability.blocked;
    }

    final escalated = await Geolocator.requestPermission();
    return switch (escalated) {
      LocationPermission.always => LocationAvailability.ready,
      LocationPermission.whileInUse => LocationAvailability.foregroundOnly,
      LocationPermission.deniedForever => LocationAvailability.blocked,
      _ => LocationAvailability.denied,
    };
  }

  @override
  Stream<GeoFix> positions(
          {TrackingCadence cadence = TrackingCadence.active}) =>
      Geolocator.getPositionStream(locationSettings: _settingsFor(cadence)).map(
        (position) => GeoFix(
          lat: position.latitude,
          lng: position.longitude,
          // The platform's own timestamp, not `DateTime.now()`. A fix that sat
          // in the OS queue for thirty seconds must not be stamped as current;
          // the whole staleness story downstream depends on this being true.
          at: position.timestamp.toLocal(),
          // The plugin reports metres per second; the API takes km/h.
          speedKph: position.speed.isFinite && position.speed >= 0
              ? position.speed * 3.6
              : null,
          // Negative means "unknown" on both platforms, and a heading is
          // meaningless while stationary.
          headingDeg: position.heading.isFinite && position.heading >= 0
              ? position.heading
              : null,
          accuracyM: position.accuracy.isFinite && position.accuracy >= 0
              ? position.accuracy
              : null,
        ),
      );

  /// Platform-specific settings for a cadence.
  ///
  /// The Android branch is the one that matters. `foregroundNotificationConfig`
  /// is what makes geolocator hold a location foreground service, and without it
  /// Android throttles a backgrounded app to a handful of fixes an hour before
  /// stopping altogether — which on a customer's map is a rider who parked. The
  /// notification is the platform's required disclosure that a position is being
  /// reported, so its wording is a promise to the rider, not chrome.
  static LocationSettings _settingsFor(TrackingCadence cadence) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: cadence.accuracy,
        distanceFilter: cadence.distanceFilter,
        // A cap, not a target: with a distance filter set, this is how long the
        // platform may go without reporting at all. Long enough to be cheap
        // while parked, short enough that a stationary rider is still known to
        // be there.
        intervalDuration: const Duration(seconds: 30),
        forceLocationManager: false,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'On a delivery',
          notificationText:
              'Your position is shared with the restaurant until you finish this run.',
          notificationChannelName: 'Delivery tracking',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: cadence.accuracy,
        distanceFilter: cadence.distanceFilter,
        // The blue bar. Shown deliberately: a rider is entitled to see that the
        // app is reading their position, and hiding it is what gets an app
        // rejected.
        showBackgroundLocationIndicator: true,
        // iOS otherwise stops delivering fixes when the app is suspended.
        allowBackgroundLocationUpdates: true,
        activityType: ActivityType.automotiveNavigation,
        // Left on: iOS pausing updates while genuinely stationary is a battery
        // win, and movement resumes them.
        pauseLocationUpdatesAutomatically: true,
      );
    }

    return LocationSettings(
      accuracy: cadence.accuracy,
      distanceFilter: cadence.distanceFilter,
    );
  }
}

final locationSourceProvider =
    Provider<LocationSource>((ref) => const DeviceLocationSource());
