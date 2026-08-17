import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';

/// Whether the rider is clocked on, and whether they may take another drop.
///
/// `onRun` is not a third thing a rider chooses — it is what the server says
/// when they are holding work. The app therefore offers two buttons, never
/// three, and re-reads the state rather than predicting it.
enum DutyStatus {
  offDuty('OFF_DUTY'),
  available('AVAILABLE'),
  onRun('ON_RUN'),
  unknown('UNKNOWN');

  const DutyStatus(this.wire);

  final String wire;

  static DutyStatus fromWire(String? value) {
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return DutyStatus.unknown;
  }

  bool get isOnShift =>
      this == DutyStatus.available || this == DutyStatus.onRun;
}

/// The signed-in rider, as the roster sees them.
@immutable
class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.displayName,
    required this.dutyStatus,
    required this.liveRuns,
    required this.maxConcurrentRuns,
    required this.deliveredToday,
    this.driverCode,
    this.vehicleType,
  });

  final String id;
  final String displayName;
  final DutyStatus dutyStatus;
  final int liveRuns;
  final int maxConcurrentRuns;

  /// Shown because a rider paid per drop wants to see their own tally, and
  /// because it is the one number that makes the shift feel finite.
  final int deliveredToday;
  final String? driverCode;
  final String? vehicleType;

  bool get isOnShift => dutyStatus.isOnShift;

  /// Ending a shift while holding work is refused by the server; the app greys
  /// the button rather than letting a rider tap into an error.
  bool get canEndShift => isOnShift && liveRuns == 0;

  factory DriverProfile.fromJson(Map<String, dynamic> json) => DriverProfile(
        id: json['id'] as String,
        displayName: (json['displayName'] as String?) ?? '',
        dutyStatus: DutyStatus.fromWire(json['dutyStatus'] as String?),
        liveRuns: (json['liveRuns'] as num?)?.toInt() ?? 0,
        maxConcurrentRuns: (json['maxConcurrentRuns'] as num?)?.toInt() ?? 1,
        deliveredToday: (json['deliveredToday'] as num?)?.toInt() ?? 0,
        driverCode: json['driverCode'] as String?,
        vehicleType: json['vehicleType'] as String?,
      );
}

/// The rider's own record and shift state.
class DriverRepository {
  DriverRepository(this._client);

  final ApiClient _client;

  /// Who am I, as a rider?
  ///
  /// A 403 here is the specific, actionable case of a login that exists but has
  /// not been linked to a rider on the roster — which is a job for a manager,
  /// not something the rider can fix. It is surfaced as its own state rather
  /// than as a generic failure, because "ask your manager to link your account"
  /// is a different instruction from "try again".
  Future<DriverProfile> me() async {
    final json = await _client.get('/restaurant/driver/me');
    return DriverProfile.fromJson(json as Map<String, dynamic>);
  }

  Future<DriverProfile?> setDuty({required bool onShift}) async {
    final response = await _client.post(
      '/restaurant/driver/duty',
      {'dutyStatus': onShift ? 'AVAILABLE' : 'OFF_DUTY'},
      // Keyed on the intent, not the moment: a rider tapping "start shift"
      // twice on a bad connection must not be a second write.
      'driver:duty:${onShift ? 'on' : 'off'}',
    );
    if (response is! Map<String, dynamic> || response['id'] is! String) {
      return null;
    }
    return DriverProfile.fromJson(response);
  }
}

final driverRepositoryProvider = Provider<DriverRepository>(
  (ref) => DriverRepository(ref.watch(apiClientProvider)),
);

/// The rider's profile, refetched whenever the board is.
final driverProfileProvider = FutureProvider.autoDispose<DriverProfile>(
  (ref) => ref.watch(driverRepositoryProvider).me(),
);
