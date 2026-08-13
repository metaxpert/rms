// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppTextEn extends AppText {
  AppTextEn([String locale = 'en']) : super(locale);

  @override
  String get floorTitle => 'Floor';

  @override
  String get switchOutlet => 'Switch outlet';

  @override
  String get signOut => 'Sign out';

  @override
  String get floorLoading => 'Loading floor…';

  @override
  String get liveConnecting => 'Connecting';

  @override
  String get liveOffline => 'Offline';

  @override
  String get liveConnectingHint => 'Connecting to live updates';

  @override
  String get liveOfflineHint =>
      'Live updates are offline — pull down to refresh';

  @override
  String floorStaleAt(String time) {
    return 'Offline — this floor is from $time. Order status may have changed since.';
  }

  @override
  String get floorStaleUnknown =>
      'Offline — showing the last floor we could load. Order status may have changed.';

  @override
  String get openBills => 'Open bills';

  @override
  String get readyToServe => 'Ready to serve';

  @override
  String get noAreasTitle => 'No dining areas';

  @override
  String get noAreasMessage =>
      'This outlet has no areas or tables set up yet. A manager can add them in the web console.';

  @override
  String get checkAgain => 'Check again';

  @override
  String get noTablesInArea => 'No tables in this area';

  @override
  String areaWithCount(String name, int count) {
    return '$name ($count)';
  }

  @override
  String get tableUnsentTicket => 'Unsent ticket';

  @override
  String get tableSendUnfinished => 'Send unfinished';

  @override
  String get tableMerged => 'Merged';

  @override
  String tableSemantics(String code) {
    return 'Table $code';
  }

  @override
  String tableSeatsSemantics(int count) {
    return 'seats $count';
  }

  @override
  String tableOrderSemantics(String status, String total) {
    return 'order $status $total';
  }

  @override
  String get tableFoodReadySemantics => 'food ready';

  @override
  String tableTitle(String code) {
    return 'Table $code';
  }

  @override
  String get bill => 'Bill';

  @override
  String get clearThisRound => 'Clear this round';

  @override
  String get noOutletTitle => 'No outlet selected';

  @override
  String get noOutletMessage => 'Choose an outlet before taking orders.';

  @override
  String get tableNotFoundTitle => 'Table not found';

  @override
  String get tableNotFoundMessage =>
      'It may have been removed or merged into another table.';

  @override
  String get checkingForBill => 'Checking for an open bill…';

  @override
  String get nothingOrderedTitle => 'Nothing ordered yet';

  @override
  String get nothingOrderedMessage =>
      'Add dishes from the menu to start this ticket.';

  @override
  String get openTheMenu => 'Open the menu';

  @override
  String get addItems => 'Add items';

  @override
  String sendWithCount(int count) {
    return 'Send · $count';
  }

  @override
  String get sending => 'Sending…';

  @override
  String sentTo(String orderNo) {
    return 'Sent · $orderNo';
  }

  @override
  String get sentHeader => 'Sent';

  @override
  String get thisRoundNotSent => 'This round — not sent';

  @override
  String get notSentYet => 'Not sent yet';

  @override
  String get billSoFar => 'Bill so far';

  @override
  String get billHasNoItems => 'This bill is open but has no items on it yet.';

  @override
  String couldNotCheckBill(String message) {
    return 'Couldn\'t check this table\'s bill. $message';
  }

  @override
  String seats(int count) {
    return 'Seats $count';
  }

  @override
  String placedAt(String time) {
    return 'Placed $time';
  }

  @override
  String get foodReadyToRun => 'Food is ready to run';

  @override
  String unsentRoundFrom(String time) {
    return 'Unsent round from $time';
  }

  @override
  String get oneFewer => 'One fewer';

  @override
  String get remove => 'Remove';

  @override
  String get oneMore => 'One more';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get tax => 'Tax';

  @override
  String get serviceCharge => 'Service charge';

  @override
  String get rounding => 'Rounding';

  @override
  String get total => 'Total';

  @override
  String get thisRound => 'This round';

  @override
  String get serverRetotals =>
      'The bill is re-totalled by the server when this round is sent.';

  @override
  String get clearRoundTitle => 'Clear this round?';

  @override
  String get clearRoundMessage =>
      'Every unsent line will be removed. Anything already sent to the kitchen stays on the bill — but this round will have to be retaken.';

  @override
  String get keepIt => 'Keep it';

  @override
  String get clear => 'Clear';

  @override
  String get stopSendingTitle => 'Stop trying to send?';

  @override
  String get stopSendingMessage =>
      'The round stays on this tablet so you can send it again.\n\nIf a bill was already opened for this table it is NOT cancelled — check the floor, and ask a manager to void it if it should not be there.';

  @override
  String get keepTrying => 'Keep trying';

  @override
  String get stop => 'Stop';

  @override
  String get sentToKitchen => 'Sent to the kitchen.';

  @override
  String sentToKitchenNumbered(String orderNo) {
    return 'Sent to the kitchen · $orderNo';
  }

  @override
  String billClosedNoMore(String status) {
    return 'This bill is $status. Nothing more can be added to it.';
  }

  @override
  String get noOrderPermission =>
      'Your sign-in cannot take orders. Ask a manager for the order permission.';

  @override
  String get sendStageCreating => 'Opening the bill…';

  @override
  String get sendStageAddingItems => 'Adding the items…';

  @override
  String get sendStagePlacing => 'Placing the order…';

  @override
  String get sendStageConfirming => 'Firing the kitchen…';

  @override
  String get sendUnfinishedTitle => 'This round was not finished sending';

  @override
  String get sendFailedTitle => 'This round did not reach the kitchen';

  @override
  String get sendInterruptedMessage =>
      'The app closed part-way through sending. Nothing was lost — send it again to finish.';

  @override
  String get billAlreadyOpen =>
      'A bill is already open for this table. Sending again continues it — it does not start a second one.';

  @override
  String get roundHeldAsSent =>
      'The round is held exactly as it was sent. Stop first to change it.';

  @override
  String resumeStage(String stage) {
    return 'Resume · $stage';
  }

  @override
  String get tryAgain => 'Try again';

  @override
  String get outboxOneSent =>
      'An order that was waiting has reached the kitchen.';

  @override
  String outboxManySent(int count) {
    return '$count orders that were waiting have reached the kitchen.';
  }

  @override
  String get foodReadyAnywhere => 'Food is ready to run.';

  @override
  String foodReadyAtTable(String code) {
    return 'Table $code — food is ready.';
  }

  @override
  String addToTable(String code) {
    return 'Add to $code';
  }

  @override
  String get close => 'Close';

  @override
  String doneWithCount(int count) {
    return 'Done · $count';
  }

  @override
  String get menuLoading => 'Loading the menu…';

  @override
  String get searchDishes => 'Search dishes';

  @override
  String get allCategories => 'All';

  @override
  String get uncategorised => 'Other';

  @override
  String get noteForKitchen => 'Note for the kitchen';

  @override
  String get noteForKitchenHint => 'No chilli, well done, serve last…';

  @override
  String billForTable(String code) {
    return 'Bill · Table $code';
  }

  @override
  String get fetchingBill => 'Fetching the bill…';

  @override
  String get noOpenBillTitle => 'No open bill';

  @override
  String get noOpenBillMessage => 'This table has nothing to settle.';

  @override
  String billIsStatus(String status) {
    return 'This bill is $status';
  }

  @override
  String get billCannotSettle =>
      'It cannot be settled. Ask a manager if that looks wrong.';

  @override
  String get discount => 'Discount';

  @override
  String get tip => 'Tip';

  @override
  String get totalDue => 'Total due';

  @override
  String get split => 'Split';

  @override
  String get splitNone => 'No';

  @override
  String get paymentMethod => 'Method';

  @override
  String get paymentAmount => 'Amount';

  @override
  String get removePayment => 'Remove this payment';

  @override
  String get anotherPayment => 'Another payment';

  @override
  String get cashGiven => 'Cash given (optional)';

  @override
  String get cashGivenHelper => 'Working out only — not sent to the server';

  @override
  String get changeDue => 'Change due';

  @override
  String stillToPay(String amount) {
    return '$amount still to pay';
  }

  @override
  String moreThanBill(String amount) {
    return '$amount more than the bill';
  }

  @override
  String shortOfBill(String amount) {
    return 'The payments are $amount short of the bill.';
  }

  @override
  String overBill(String amount) {
    return 'The payments are $amount more than the bill.';
  }

  @override
  String get viewBill => 'View bill';

  @override
  String settleAmount(String amount) {
    return 'Settle $amount';
  }

  @override
  String get settling => 'Settling…';

  @override
  String get billSettled => 'Bill settled';

  @override
  String get receipt => 'Receipt';

  @override
  String get tableFreeWhenCleared =>
      'The table is free once it has been cleared down.';

  @override
  String get proFormaWarning =>
      'Not settled — this prints as a pro-forma, not a tax invoice.';

  @override
  String get reprint => 'Reprint';

  @override
  String get print => 'Print';

  @override
  String get printProForma => 'Print pro-forma';

  @override
  String get printingNotAllowed => 'Printing not allowed';

  @override
  String get reprintQueued => 'Reprint queued.';

  @override
  String get printQueued =>
      'Sent to the printer. It prints when the till agent picks it up.';

  @override
  String get emptySlipTitle => 'The server returned an empty slip';

  @override
  String get emptySlipMessage =>
      'Printing may still work. Tell a manager if it does not.';

  @override
  String get billCopied => 'Bill copied.';

  @override
  String get clearSearch => 'Clear';

  @override
  String get nothingHereTitle => 'Nothing here';

  @override
  String noMatchTitle(String query) {
    return 'No match for \"$query\"';
  }

  @override
  String get sectionOffMenu =>
      'Every dish in this section is off the menu right now.';

  @override
  String get soldOutNotListed => 'Sold-out dishes are not listed.';

  @override
  String get combo => 'Combo';

  @override
  String get optionsLoading => 'Loading options…';

  @override
  String chooseExactly(int count) {
    return 'Choose $count';
  }

  @override
  String chooseAtLeast(int count) {
    return 'Choose at least $count';
  }

  @override
  String chooseUpTo(int count) {
    return 'Up to $count';
  }

  @override
  String get optional => 'Optional';

  @override
  String chooseFirst(String group) {
    return 'Choose $group first';
  }

  @override
  String addWithQtyAndPrice(int count, String amount) {
    return 'Add $count · $amount';
  }

  @override
  String get waiterSignIn => 'Waiter sign in';

  @override
  String get notifyFoodReadyTitle => 'Food is ready';

  @override
  String notifyFoodReadyAtTable(String code) {
    return 'Table $code — ready';
  }

  @override
  String get notifyFoodReadyBody => 'Food is up at the pass.';

  @override
  String get notifyOrderSentTitle => 'Order sent';

  @override
  String notifyOrderSentBody(String code) {
    return 'Table $code reached the kitchen.';
  }

  @override
  String notifyOrderSentBodyNumbered(String code, String orderNo) {
    return 'Table $code reached the kitchen · $orderNo';
  }
}
