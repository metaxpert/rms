// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppTextEn extends AppText {
  AppTextEn([String locale = 'en']) : super(locale);

  @override
  String get managerSignIn => 'Manager sign in';

  @override
  String get tabService => 'Service';

  @override
  String get tabKitchen => 'Kitchen';

  @override
  String get tabSales => 'Sales';

  @override
  String get allOutlets => 'All outlets';

  @override
  String get oneOutlet => 'One outlet';

  @override
  String get chooseOutlet => 'Choose outlet';

  @override
  String get refresh => 'Refresh';

  @override
  String get signOut => 'Sign out';

  @override
  String get readingService => 'Reading the service…';

  @override
  String get live => 'Live';

  @override
  String get offline => 'Offline';

  @override
  String liveTooltip(String time) {
    return 'Live. Last read $time';
  }

  @override
  String get liveTooltipJustNow => 'Live. Last read just now';

  @override
  String get offlineTooltip =>
      'Not receiving live updates — pull down to refresh';

  @override
  String ordersReadyToRun(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orders are ready to run',
      one: '1 order is ready to run',
    );
    return '$_temp0';
  }

  @override
  String get foodUpAtPass => 'Food is up and waiting at the pass.';

  @override
  String ticketsPastTarget(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tickets are past target',
      one: '1 ticket is past target',
    );
    return '$_temp0';
  }

  @override
  String longestWaiting(String wait) {
    return 'The longest has been waiting $wait.';
  }

  @override
  String get kpiOpenBills => 'Open bills';

  @override
  String get kpiReadyToServe => 'Ready to serve';

  @override
  String get kpiKitchenTickets => 'Kitchen tickets';

  @override
  String get kpiTablesInUse => 'Tables in use';

  @override
  String get kpiSettled => 'Settled';

  @override
  String get kpiDeliveriesOut => 'Deliveries out';

  @override
  String get goNow => 'go now';

  @override
  String get nothingWaiting => 'nothing waiting';

  @override
  String get kitchenClear => 'kitchen is clear';

  @override
  String longestIs(String wait) {
    return 'longest $wait';
  }

  @override
  String get noTablesSetUp => 'no tables set up';

  @override
  String percentFull(String percent) {
    return '$percent full';
  }

  @override
  String get noneOnTheRoad => 'none on the road';

  @override
  String get onTheRoad => 'on the road';

  @override
  String get underAMinute => 'under a minute';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String readAt(String time) {
    return 'Read at $time';
  }

  @override
  String get kitchenClearTitle => 'The kitchen is clear';

  @override
  String get kitchenClearMessage => 'Nothing is waiting to be cooked.';

  @override
  String pastTargetCount(int count) {
    return '$count past target';
  }

  @override
  String ticketCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tickets',
      one: '1 ticket',
    );
    return '$_temp0';
  }

  @override
  String get ticket => 'Ticket';

  @override
  String tableLabel(String code) {
    return 'Table $code';
  }

  @override
  String targetAndStatus(int minutes, String status) {
    return 'Target $minutes min · $status';
  }

  @override
  String get stillOpen => 'Still open';

  @override
  String get settled => 'Settled';

  @override
  String get nothingSettled => 'Nothing settled yet.';

  @override
  String get salesFootnote =>
      'Covers the orders the server returns for this outlet. The ledger, not this screen, is the record of what was earned.';

  @override
  String get stillOnTables => 'Still on tables';

  @override
  String get billsClosed => 'Bills closed';

  @override
  String get averageBill => 'Average bill';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }
}
