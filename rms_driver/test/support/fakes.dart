import 'dart:async';

import 'package:rms_core/rms_core.dart';
import 'package:rms_driver/src/features/location/data/location_source.dart';
import 'package:rms_driver/src/features/runs/data/delivery_repository.dart';

/// The delivery API, faked at the repository seam — what these tests are about
/// is which transition the app asks for and what it does with the answer.
class FakeDeliveries implements DeliveryRepository {
  FakeDeliveries({this.board = const []});

  List<Delivery> board;

  final calls = <String>[];

  /// Every `advance` asked for, as (status it was in, OTP supplied).
  final advances = <(DeliveryStatus, String?)>[];

  /// Positions reported, in order.
  final pings = <(double, double)>[];

  final failures = <String>[];

  ApiException? failAdvance;
  ApiException? failTrack;

  Delivery? current;

  static Delivery delivery({
    String id = 'dlv-1',
    String status = 'ASSIGNED',
    String provider = 'OWN',
    String? address = '12 Street 4, F-7/3, Islamabad',
  }) =>
      Delivery.fromJson({
        'id': id,
        'deliveryNo': 'DLV-000002',
        'orderId': 'order-1',
        'orderNo': 'ORD-000011',
        'provider': provider,
        'status': status,
        'address': address,
      });

  @override
  Future<List<Delivery>> runs() async {
    calls.add('runs');
    return board;
  }

  @override
  Future<Delivery> fetch(String id) async {
    calls.add('fetch');
    return current ?? delivery(id: id);
  }

  @override
  Future<Delivery?> advance({
    required String id,
    required DeliveryStatus from,
    String? otp,
  }) async {
    calls.add('advance');
    advances.add((from, otp));
    if (failAdvance != null) throw failAdvance!;
    final next = switch (from) {
      DeliveryStatus.assigned => 'PICKED_UP',
      DeliveryStatus.pickedUp => 'EN_ROUTE',
      DeliveryStatus.enRoute => 'DELIVERED',
      _ => from.wire,
    };
    return current = delivery(id: id, status: next);
  }

  @override
  Future<Delivery?> fail({required String id, required String reason}) async {
    calls.add('fail');
    failures.add(reason);
    return current = delivery(id: id, status: 'FAILED');
  }

  @override
  Future<void> track({
    required String id,
    required double lat,
    required double lng,
    double? speedKph,
  }) async {
    calls.add('track');
    if (failTrack != null) throw failTrack!;
    pings.add((lat, lng));
  }
}

/// A GPS that reports what the test tells it to.
class FakeLocation implements LocationSource {
  FakeLocation({this.availability = LocationAvailability.ready});

  LocationAvailability availability;
  final _controller = StreamController<GeoFix>.broadcast();

  int ensureCalls = 0;

  void emit(double lat, double lng) =>
      _controller.add(GeoFix(lat: lat, lng: lng, speedKph: 18));

  Future<void> close() => _controller.close();

  @override
  Future<LocationAvailability> ensureAvailable() async {
    ensureCalls++;
    return availability;
  }

  @override
  Stream<GeoFix> positions() => _controller.stream;
}
