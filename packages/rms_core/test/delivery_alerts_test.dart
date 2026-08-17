import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A notification a customer gets twice is worse than one they do not get.
///
/// The duplicate problem here is not hypothetical, which is why it has its own
/// tests. The tracking screen re-reads a snapshot on every reconnect and every
/// poll, so the same "your rider is nearby" fact is *observed* over and over —
/// once a minute for the rest of the ride. Geofences make it worse: a rider
/// circling a block for parking crosses the same boundary three or four times.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AlertLedger> ledger() async =>
      AlertLedger(await SharedPreferences.getInstance());

  group('the alert ledger', () {
    test('claims a moment once', () async {
      final book = await ledger();
      expect(await book.claim('d-1', DeliveryAlert.nearby), isTrue);
      expect(await book.claim('d-1', DeliveryAlert.nearby), isFalse);
    });

    test('a repeated observation of the same fact stays silent', () async {
      // What a poll loop looks like: the same boundary crossing seen sixty times.
      final book = await ledger();
      final fired = <bool>[];
      for (var i = 0; i < 60; i++) {
        fired.add(await book.claim('d-1', DeliveryAlert.almostThere));
      }
      expect(fired.where((f) => f).length, 1);
    });

    test('different moments on one delivery each get through', () async {
      final book = await ledger();
      expect(await book.claim('d-1', DeliveryAlert.pickedUp), isTrue);
      expect(await book.claim('d-1', DeliveryAlert.onTheWay), isTrue);
      expect(await book.claim('d-1', DeliveryAlert.nearby), isTrue);
      expect(await book.claim('d-1', DeliveryAlert.arrived), isTrue);
    });

    test('two deliveries do not silence each other', () async {
      // A customer with two orders out must hear about both.
      final book = await ledger();
      expect(await book.claim('d-1', DeliveryAlert.nearby), isTrue);
      expect(await book.claim('d-2', DeliveryAlert.nearby), isTrue);
    });

    test('survives a restart', () async {
      // A process restart must not be a licence to repeat the set — Android kills
      // backgrounded apps freely, and the rider is still twenty minutes away.
      final first = await ledger();
      expect(await first.claim('d-1', DeliveryAlert.nearby), isTrue);

      final afterRestart = AlertLedger(await SharedPreferences.getInstance());
      expect(await afterRestart.claim('d-1', DeliveryAlert.nearby), isFalse);
    });

    test('a re-dispatched run may alert again', () async {
      final book = await ledger();
      expect(await book.claim('d-1', DeliveryAlert.nearby), isTrue);
      await book.forget('d-1');
      expect(await book.claim('d-1', DeliveryAlert.nearby), isTrue);
    });

    test('forgetting one delivery leaves the others alone', () async {
      final book = await ledger();
      await book.claim('d-1', DeliveryAlert.nearby);
      await book.claim('d-2', DeliveryAlert.nearby);
      await book.forget('d-1');
      expect(await book.claim('d-2', DeliveryAlert.nearby), isFalse);
    });
  });

  group('raising an alert', () {
    test('shows once and never again', () async {
      final notifier = _RecordingNotifier();
      final alerts = DeliveryAlerts(notifier: notifier, ledger: await ledger());

      final first = await alerts.raise(
        deliveryId: 'd-1',
        alert: DeliveryAlert.nearby,
        title: 'Almost there',
        body: 'Your rider is a few minutes away.',
      );
      final second = await alerts.raise(
        deliveryId: 'd-1',
        alert: DeliveryAlert.nearby,
        title: 'Almost there',
        body: 'Your rider is a few minutes away.',
      );

      expect(first, isTrue);
      expect(second, isFalse);
      expect(notifier.shown, ['Almost there']);
    });

    test('each kind keeps its own notification id, so one replaces its own', () {
      // A stable id per kind means a second alert of the same kind replaces the
      // first instead of stacking a column down the shade. Different kinds must
      // not collide, or "arrived" would overwrite "on the way".
      final ids = DeliveryAlert.values.map((a) => a.notificationId).toSet();
      expect(ids.length, DeliveryAlert.values.length);
    });

    test('there is no alert for a position update', () {
      // The rule this whole file exists to hold: an alert marks a change of state,
      // never a change of coordinates. A rider reports every fifteen seconds; a
      // notification per fix would be forty interruptions a delivery.
      final names = DeliveryAlert.values.map((a) => a.name).toList();
      expect(names, isNot(contains('location')));
      expect(names, isNot(contains('position')));
      expect(names, isNot(contains('moved')));
    });
  });
}

class _RecordingNotifier implements LocalNotifier {
  final shown = <String>[];

  @override
  Future<bool> prepare() async => true;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async =>
      shown.add(title);
}
