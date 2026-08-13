import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_core/src/l10n/rms_localizations_en.dart';

void main() {
  // The English catalogue, so the assertions read as a user would see them.
  final text = RmsLocalizationsEn();

  group('DeliveryStatus wire mapping', () {
    test('maps every backend value', () {
      expect(DeliveryStatus.fromWire('PENDING'), DeliveryStatus.pending);
      expect(DeliveryStatus.fromWire('ASSIGNED'), DeliveryStatus.assigned);
      expect(DeliveryStatus.fromWire('PICKED_UP'), DeliveryStatus.pickedUp);
      expect(DeliveryStatus.fromWire('EN_ROUTE'), DeliveryStatus.enRoute);
      expect(DeliveryStatus.fromWire('DELIVERED'), DeliveryStatus.delivered);
      expect(DeliveryStatus.fromWire('FAILED'), DeliveryStatus.failed);
      expect(DeliveryStatus.fromWire('CANCELLED'), DeliveryStatus.cancelled);
    });

    test('an unknown status degrades rather than crashing a rider mid-run', () {
      expect(DeliveryStatus.fromWire('RETURNING'), DeliveryStatus.unknown);
      expect(DeliveryStatus.fromWire(null), DeliveryStatus.unknown);
    });
  });

  group('terminal vs active', () {
    test('terminal states end the job', () {
      expect(DeliveryStatus.delivered.isTerminal, isTrue);
      expect(DeliveryStatus.failed.isTerminal, isTrue);
      expect(DeliveryStatus.cancelled.isTerminal, isTrue);
    });

    test('live states remain on the run list', () {
      expect(DeliveryStatus.assigned.isActive, isTrue);
      expect(DeliveryStatus.enRoute.isActive, isTrue);
      expect(DeliveryStatus.delivered.isActive, isFalse);
    });

    test('unknown is not treated as active work', () {
      expect(DeliveryStatus.unknown.isActive, isFalse);
    });
  });

  group('next action — exactly one, never a menu', () {
    test('follows the own-fleet flow', () {
      expect(DeliveryStatus.assigned.nextActionPath, 'pickup');
      expect(DeliveryStatus.pickedUp.nextActionPath, 'enroute');
      expect(DeliveryStatus.enRoute.nextActionPath, 'complete');
    });

    test('nothing to do before assignment or after completion', () {
      expect(DeliveryStatus.pending.nextActionPath, isNull);
      expect(DeliveryStatus.delivered.nextActionPath, isNull);
      expect(DeliveryStatus.failed.nextActionPath, isNull);
    });

    test('label and path stay in step', () {
      for (final status in DeliveryStatus.values) {
        expect(
          status.nextActionLabelIn(text) == null,
          status.nextActionPath == null,
          reason: '${status.wire} has a label/path mismatch',
        );
      }
    });
  });

  group('Delivery parsing', () {
    Map<String, dynamic> json({
      String status = 'ASSIGNED',
      String provider = 'OWN',
      Object? location,
      Object? pickedUpAt,
    }) =>
        {
          'id': 'd1',
          'deliveryNo': 'DLV-0001',
          'orderId': 'o1',
          'orderNo': 'ORD-000009',
          'branchId': 'b1',
          'provider': provider,
          'driverEmployeeId': 'emp-1',
          'customerId': 'c1',
          'address': '12 Main Blvd, Gulberg',
          'location': location,
          'status': status,
          'etaMinutes': 25,
          'assignedAt': '2026-08-12T09:05:00.000Z',
          'pickedUpAt': pickedUpAt,
          'deliveredAt': null,
        };

    test('reads the verified payload', () {
      final d = Delivery.fromJson(json(
        location: {'lat': 31.5204, 'lng': 74.3587},
      ));

      expect(d.deliveryNo, 'DLV-0001');
      expect(d.orderNo, 'ORD-000009');
      expect(d.status, DeliveryStatus.assigned);
      expect(d.address, '12 Main Blvd, Gulberg');
      expect(d.location!.lat, closeTo(31.5204, 1e-9));
      expect(d.etaMinutes, 25);
      expect(d.assignedAt, isNotNull);
      expect(d.pickedUpAt, isNull);
    });

    test('never exposes an OTP — the customer reads it to the rider', () {
      // The backend returns otp only at creation. If this ever changes, the
      // driver app must still not surface it, or the check is worthless.
      final d = Delivery.fromJson(json());
      expect((d as dynamic).toString(), isNot(contains('otp')));
    });

    test('an aggregator job is not driven from this app', () {
      final own = Delivery.fromJson(json(provider: 'OWN'));
      final agg = Delivery.fromJson(json(provider: 'FOODPANDA'));
      expect(own.isActionable, isTrue);
      expect(agg.isOwnFleet, isFalse);
      expect(agg.isActionable, isFalse);
    });

    test('a completed own-fleet job offers no action', () {
      final d = Delivery.fromJson(json(status: 'DELIVERED'));
      expect(d.isActionable, isFalse);
    });

    test('missing location and timestamps are tolerated', () {
      final d = Delivery.fromJson(json(location: null));
      expect(d.location, isNull);
      expect(d.deliveredAt, isNull);
    });

    test('timestamps are converted to local time for the rider', () {
      final d = Delivery.fromJson(json(pickedUpAt: '2026-08-12T09:05:00.000Z'));
      expect(d.pickedUpAt!.isUtc, isFalse);
    });
  });
}
