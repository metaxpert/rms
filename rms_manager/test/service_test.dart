import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_core/src/l10n/rms_localizations_en.dart';
import 'package:rms_manager/src/features/service/data/service_repository.dart';

/// A manager reads a figure here and then walks somewhere on the strength of
/// it. These tests are about the figures being true, and about the app not
/// claiming more than it knows.
void main() {
  final shared = RmsLocalizationsEn();

  OrderSummary order({
    required String status,
    int totalMinor = 100000,
    int itemCount = 2,
    String channel = 'DINE_IN',
  }) =>
      OrderSummary.fromJson({
        'id': 'o-$status-$totalMinor-$itemCount',
        'orderNo': 'ORD-0001',
        'channel': channel,
        'status': status,
        'itemCount': itemCount,
        'total': {'amountMinor': totalMinor, 'currency': 'PKR'},
      });

  Map<String, dynamic> ticket({
    required String station,
    int elapsedSeconds = 60,
    int? targetMinutes,
    String id = 't1',
  }) =>
      {
        'id': id,
        'orderNo': 'ORD-0001',
        'stationKey': station,
        'status': 'IN_PROGRESS',
        'elapsedSeconds': elapsedSeconds,
        'targetMinutes': targetMinutes,
        'items': [
          {'qty': 2, 'name': 'Chicken Karahi'},
        ],
      };

  ServiceSnapshot snapshot({
    List<OrderSummary> orders = const [],
    List<KdsTicket> tickets = const [],
    List<RestaurantTable> tables = const [],
    List<Delivery> deliveries = const [],
  }) =>
      ServiceSnapshot(
        orders: orders,
        board: KdsBoard.from(tickets),
        tables: tables,
        deliveries: deliveries,
        takenAt: DateTime(2026, 8, 13, 20, 30),
      );

  group('the money figures', () {
    test('separates what is taken from what is still on tables', () {
      final s = snapshot(orders: [
        order(status: 'SETTLED', totalMinor: 150000),
        order(status: 'SETTLED', totalMinor: 50000),
        order(status: 'CONFIRMED', totalMinor: 80000),
        order(status: 'READY', totalMinor: 20000),
      ]);

      expect(s.settledValue, const Money(200000));
      expect(s.openValue, const Money(100000));
      expect(s.settledOrders.length, 2);
      expect(s.openOrders.length, 2);
    });

    test('a cancelled bill counts as neither', () {
      // It is not money owed and it is not money taken; putting it in either
      // column would misstate the service.
      final s = snapshot(orders: [
        order(status: 'CANCELLED', totalMinor: 90000),
        order(status: 'VOID', totalMinor: 90000),
        order(status: 'SETTLED', totalMinor: 10000),
      ]);

      expect(s.settledValue, const Money(10000));
      expect(s.openValue, Money.zero);
    });

    test('the average bill is integer paisa, never a float', () {
      final s = snapshot(orders: [
        order(status: 'SETTLED', totalMinor: 100000),
        order(status: 'SETTLED', totalMinor: 100001),
        order(status: 'SETTLED', totalMinor: 100000),
      ]);
      expect(s.averageBill, const Money(100000));
    });

    test('with nothing settled the average is zero, not a division by zero',
        () {
      expect(snapshot().averageBill, Money.zero);
    });

    test('figures follow the tenant\'s currency, not a hard-coded one', () {
      final s = ServiceSnapshot(
        orders: [
          OrderSummary.fromJson(const {
            'id': 'o1',
            'status': 'SETTLED',
            'total': {'amountMinor': 5000, 'currency': 'USD'},
          }),
        ],
        board: KdsBoard.from(const []),
        tables: const [],
        deliveries: const [],
        takenAt: DateTime(2026),
      );
      expect(s.currency, 'USD');
      expect(s.settledValue.currency, 'USD');
    });
  });

  group('what a manager can act on', () {
    test('counts only the orders that need someone to walk to the pass', () {
      final s = snapshot(orders: [
        order(status: 'READY'),
        order(status: 'READY', totalMinor: 200),
        order(status: 'PREPARING'),
        order(status: 'SERVED'),
      ]);
      expect(s.readyToServe, 2);
    });

    test('counts tables in use out of the tables that exist', () {
      RestaurantTable table(String status) => RestaurantTable.fromJson({
            'id': 'tbl-$status',
            'code': 'D1',
            'status': status,
            'active': true,
          });

      final s = snapshot(tables: [
        table('OCCUPIED'),
        table('OCCUPIED'),
        table('AVAILABLE'),
        table('CLEANING'),
      ]);
      expect(s.occupiedTables, 2);
      expect(s.totalTables, 4);
    });

    test('counts only deliveries still on the road', () {
      Delivery delivery(String status) => Delivery.fromJson({
            'id': 'd-$status',
            'status': status,
            'provider': 'OWN',
          });

      final s = snapshot(deliveries: [
        delivery('EN_ROUTE'),
        delivery('ASSIGNED'),
        delivery('DELIVERED'),
        delivery('FAILED'),
      ]);
      expect(s.activeDeliveries.length, 2);
    });
  });

  group('the kitchen board', () {
    test('groups tickets by the station the kitchen actually uses', () {
      final board = KdsBoard.from([
        KdsTicket.fromJson(ticket(station: 'grill', id: 'a')),
        KdsTicket.fromJson(ticket(station: 'tandoor', id: 'b')),
        KdsTicket.fromJson(ticket(station: 'grill', id: 'c')),
      ]);

      expect(board.stationKeys, ['grill', 'tandoor']);
      expect(board.stations['grill']!.length, 2);
      expect(board.ticketCount, 3);
    });

    test('puts the longest-waiting ticket at the top of its station', () {
      // That is the one a chef picks up next and the one a manager asks about.
      final board = KdsBoard.from([
        KdsTicket.fromJson(
            ticket(station: 'grill', id: 'new', elapsedSeconds: 30)),
        KdsTicket.fromJson(
            ticket(station: 'grill', id: 'old', elapsedSeconds: 900)),
      ]);
      expect(board.stations['grill']!.first.id, 'old');
      expect(board.longestWait, const Duration(minutes: 15));
    });

    test('a ticket is overdue only against its own target', () {
      final overdue = KdsTicket.fromJson(
          ticket(station: 'grill', elapsedSeconds: 700, targetMinutes: 10));
      final inTime = KdsTicket.fromJson(
          ticket(station: 'grill', elapsedSeconds: 500, targetMinutes: 10));

      expect(overdue.isOverdue, isTrue);
      expect(inTime.isOverdue, isFalse);
    });

    test('a ticket with no target is never overdue', () {
      // Inventing a default would put half the board in red on a busy night,
      // and teach everyone to ignore the colour.
      final ticketWithoutTarget = KdsTicket.fromJson(
          ticket(station: 'grill', elapsedSeconds: 7200));
      expect(ticketWithoutTarget.isOverdue, isFalse);
    });

    test('reports waiting time, not a wall clock', () {
      expect(
        KdsTicket.fromJson(ticket(station: 'g', elapsedSeconds: 30))
            .elapsedLabelIn(shared),
        'just now',
      );
      expect(
        KdsTicket.fromJson(ticket(station: 'g', elapsedSeconds: 780))
            .elapsedLabelIn(shared),
        '13 min',
      );
      expect(
        KdsTicket.fromJson(ticket(station: 'g', elapsedSeconds: 4500))
            .elapsedLabelIn(shared),
        '1h 15m',
      );
    });

    test('an empty kitchen is empty, not a station with no tickets', () {
      final board = KdsBoard.from(const []);
      expect(board.isEmpty, isTrue);
      expect(board.overdueCount, 0);
      expect(board.longestWait, Duration.zero);
    });

    test('a ticket missing its station still lands somewhere', () {
      // Dropping it would hide food that is being cooked.
      final board = KdsBoard.from([
        KdsTicket.fromJson(const {'id': 'x', 'elapsedSeconds': 10}),
      ]);
      expect(board.ticketCount, 1);
      expect(board.stationKeys, ['kitchen']);
    });
  });
}
