import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppText
/// returned by `AppText.of(context)`.
///
/// Applications need to include `AppText.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppText.localizationsDelegates,
///   supportedLocales: AppText.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppText.supportedLocales
/// property.
abstract class AppText {
  AppText(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppText of(BuildContext context) {
    return Localizations.of<AppText>(context, AppText)!;
  }

  static const LocalizationsDelegate<AppText> delegate = _AppTextDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ur')
  ];

  /// No description provided for @floorTitle.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get floorTitle;

  /// No description provided for @switchOutlet.
  ///
  /// In en, this message translates to:
  /// **'Switch outlet'**
  String get switchOutlet;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @floorLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading floor…'**
  String get floorLoading;

  /// No description provided for @liveConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get liveConnecting;

  /// No description provided for @liveOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get liveOffline;

  /// No description provided for @liveConnectingHint.
  ///
  /// In en, this message translates to:
  /// **'Connecting to live updates'**
  String get liveConnectingHint;

  /// No description provided for @liveOfflineHint.
  ///
  /// In en, this message translates to:
  /// **'Live updates are offline — pull down to refresh'**
  String get liveOfflineHint;

  /// No description provided for @floorStaleAt.
  ///
  /// In en, this message translates to:
  /// **'Offline — this floor is from {time}. Order status may have changed since.'**
  String floorStaleAt(String time);

  /// No description provided for @floorStaleUnknown.
  ///
  /// In en, this message translates to:
  /// **'Offline — showing the last floor we could load. Order status may have changed.'**
  String get floorStaleUnknown;

  /// No description provided for @openBills.
  ///
  /// In en, this message translates to:
  /// **'Open bills'**
  String get openBills;

  /// No description provided for @readyToServe.
  ///
  /// In en, this message translates to:
  /// **'Ready to serve'**
  String get readyToServe;

  /// No description provided for @noAreasTitle.
  ///
  /// In en, this message translates to:
  /// **'No dining areas'**
  String get noAreasTitle;

  /// No description provided for @noAreasMessage.
  ///
  /// In en, this message translates to:
  /// **'This outlet has no areas or tables set up yet. A manager can add them in the web console.'**
  String get noAreasMessage;

  /// No description provided for @checkAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get checkAgain;

  /// No description provided for @noTablesInArea.
  ///
  /// In en, this message translates to:
  /// **'No tables in this area'**
  String get noTablesInArea;

  /// No description provided for @areaWithCount.
  ///
  /// In en, this message translates to:
  /// **'{name} ({count})'**
  String areaWithCount(String name, int count);

  /// No description provided for @tableUnsentTicket.
  ///
  /// In en, this message translates to:
  /// **'Unsent ticket'**
  String get tableUnsentTicket;

  /// No description provided for @tableSendUnfinished.
  ///
  /// In en, this message translates to:
  /// **'Send unfinished'**
  String get tableSendUnfinished;

  /// No description provided for @tableMerged.
  ///
  /// In en, this message translates to:
  /// **'Merged'**
  String get tableMerged;

  /// No description provided for @tableSemantics.
  ///
  /// In en, this message translates to:
  /// **'Table {code}'**
  String tableSemantics(String code);

  /// No description provided for @tableSeatsSemantics.
  ///
  /// In en, this message translates to:
  /// **'seats {count}'**
  String tableSeatsSemantics(int count);

  /// No description provided for @tableOrderSemantics.
  ///
  /// In en, this message translates to:
  /// **'order {status} {total}'**
  String tableOrderSemantics(String status, String total);

  /// No description provided for @tableFoodReadySemantics.
  ///
  /// In en, this message translates to:
  /// **'food ready'**
  String get tableFoodReadySemantics;

  /// No description provided for @tableTitle.
  ///
  /// In en, this message translates to:
  /// **'Table {code}'**
  String tableTitle(String code);

  /// No description provided for @bill.
  ///
  /// In en, this message translates to:
  /// **'Bill'**
  String get bill;

  /// No description provided for @clearThisRound.
  ///
  /// In en, this message translates to:
  /// **'Clear this round'**
  String get clearThisRound;

  /// No description provided for @noOutletTitle.
  ///
  /// In en, this message translates to:
  /// **'No outlet selected'**
  String get noOutletTitle;

  /// No description provided for @noOutletMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose an outlet before taking orders.'**
  String get noOutletMessage;

  /// No description provided for @tableNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Table not found'**
  String get tableNotFoundTitle;

  /// No description provided for @tableNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'It may have been removed or merged into another table.'**
  String get tableNotFoundMessage;

  /// No description provided for @checkingForBill.
  ///
  /// In en, this message translates to:
  /// **'Checking for an open bill…'**
  String get checkingForBill;

  /// No description provided for @nothingOrderedTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing ordered yet'**
  String get nothingOrderedTitle;

  /// No description provided for @nothingOrderedMessage.
  ///
  /// In en, this message translates to:
  /// **'Add dishes from the menu to start this ticket.'**
  String get nothingOrderedMessage;

  /// No description provided for @openTheMenu.
  ///
  /// In en, this message translates to:
  /// **'Open the menu'**
  String get openTheMenu;

  /// No description provided for @addItems.
  ///
  /// In en, this message translates to:
  /// **'Add items'**
  String get addItems;

  /// No description provided for @sendWithCount.
  ///
  /// In en, this message translates to:
  /// **'Send · {count}'**
  String sendWithCount(int count);

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// No description provided for @sentTo.
  ///
  /// In en, this message translates to:
  /// **'Sent · {orderNo}'**
  String sentTo(String orderNo);

  /// No description provided for @sentHeader.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sentHeader;

  /// No description provided for @thisRoundNotSent.
  ///
  /// In en, this message translates to:
  /// **'This round — not sent'**
  String get thisRoundNotSent;

  /// No description provided for @notSentYet.
  ///
  /// In en, this message translates to:
  /// **'Not sent yet'**
  String get notSentYet;

  /// No description provided for @billSoFar.
  ///
  /// In en, this message translates to:
  /// **'Bill so far'**
  String get billSoFar;

  /// No description provided for @billHasNoItems.
  ///
  /// In en, this message translates to:
  /// **'This bill is open but has no items on it yet.'**
  String get billHasNoItems;

  /// No description provided for @couldNotCheckBill.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check this table\'s bill. {message}'**
  String couldNotCheckBill(String message);

  /// No description provided for @seats.
  ///
  /// In en, this message translates to:
  /// **'Seats {count}'**
  String seats(int count);

  /// No description provided for @placedAt.
  ///
  /// In en, this message translates to:
  /// **'Placed {time}'**
  String placedAt(String time);

  /// No description provided for @foodReadyToRun.
  ///
  /// In en, this message translates to:
  /// **'Food is ready to run'**
  String get foodReadyToRun;

  /// No description provided for @unsentRoundFrom.
  ///
  /// In en, this message translates to:
  /// **'Unsent round from {time}'**
  String unsentRoundFrom(String time);

  /// No description provided for @oneFewer.
  ///
  /// In en, this message translates to:
  /// **'One fewer'**
  String get oneFewer;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @oneMore.
  ///
  /// In en, this message translates to:
  /// **'One more'**
  String get oneMore;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @tax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get tax;

  /// No description provided for @serviceCharge.
  ///
  /// In en, this message translates to:
  /// **'Service charge'**
  String get serviceCharge;

  /// No description provided for @rounding.
  ///
  /// In en, this message translates to:
  /// **'Rounding'**
  String get rounding;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @thisRound.
  ///
  /// In en, this message translates to:
  /// **'This round'**
  String get thisRound;

  /// No description provided for @serverRetotals.
  ///
  /// In en, this message translates to:
  /// **'The bill is re-totalled by the server when this round is sent.'**
  String get serverRetotals;

  /// No description provided for @clearRoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear this round?'**
  String get clearRoundTitle;

  /// No description provided for @clearRoundMessage.
  ///
  /// In en, this message translates to:
  /// **'Every unsent line will be removed. Anything already sent to the kitchen stays on the bill — but this round will have to be retaken.'**
  String get clearRoundMessage;

  /// No description provided for @keepIt.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get keepIt;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @stopSendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop trying to send?'**
  String get stopSendingTitle;

  /// No description provided for @stopSendingMessage.
  ///
  /// In en, this message translates to:
  /// **'The round stays on this tablet so you can send it again.\n\nIf a bill was already opened for this table it is NOT cancelled — check the floor, and ask a manager to void it if it should not be there.'**
  String get stopSendingMessage;

  /// No description provided for @keepTrying.
  ///
  /// In en, this message translates to:
  /// **'Keep trying'**
  String get keepTrying;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @sentToKitchen.
  ///
  /// In en, this message translates to:
  /// **'Sent to the kitchen.'**
  String get sentToKitchen;

  /// No description provided for @sentToKitchenNumbered.
  ///
  /// In en, this message translates to:
  /// **'Sent to the kitchen · {orderNo}'**
  String sentToKitchenNumbered(String orderNo);

  /// No description provided for @billClosedNoMore.
  ///
  /// In en, this message translates to:
  /// **'This bill is {status}. Nothing more can be added to it.'**
  String billClosedNoMore(String status);

  /// No description provided for @noOrderPermission.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in cannot take orders. Ask a manager for the order permission.'**
  String get noOrderPermission;

  /// No description provided for @sendStageCreating.
  ///
  /// In en, this message translates to:
  /// **'Opening the bill…'**
  String get sendStageCreating;

  /// No description provided for @sendStageAddingItems.
  ///
  /// In en, this message translates to:
  /// **'Adding the items…'**
  String get sendStageAddingItems;

  /// No description provided for @sendStagePlacing.
  ///
  /// In en, this message translates to:
  /// **'Placing the order…'**
  String get sendStagePlacing;

  /// No description provided for @sendStageConfirming.
  ///
  /// In en, this message translates to:
  /// **'Firing the kitchen…'**
  String get sendStageConfirming;

  /// No description provided for @sendUnfinishedTitle.
  ///
  /// In en, this message translates to:
  /// **'This round was not finished sending'**
  String get sendUnfinishedTitle;

  /// No description provided for @sendFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'This round did not reach the kitchen'**
  String get sendFailedTitle;

  /// No description provided for @sendInterruptedMessage.
  ///
  /// In en, this message translates to:
  /// **'The app closed part-way through sending. Nothing was lost — send it again to finish.'**
  String get sendInterruptedMessage;

  /// No description provided for @billAlreadyOpen.
  ///
  /// In en, this message translates to:
  /// **'A bill is already open for this table. Sending again continues it — it does not start a second one.'**
  String get billAlreadyOpen;

  /// No description provided for @roundHeldAsSent.
  ///
  /// In en, this message translates to:
  /// **'The round is held exactly as it was sent. Stop first to change it.'**
  String get roundHeldAsSent;

  /// No description provided for @resumeStage.
  ///
  /// In en, this message translates to:
  /// **'Resume · {stage}'**
  String resumeStage(String stage);

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @outboxOneSent.
  ///
  /// In en, this message translates to:
  /// **'An order that was waiting has reached the kitchen.'**
  String get outboxOneSent;

  /// No description provided for @outboxManySent.
  ///
  /// In en, this message translates to:
  /// **'{count} orders that were waiting have reached the kitchen.'**
  String outboxManySent(int count);

  /// No description provided for @foodReadyAnywhere.
  ///
  /// In en, this message translates to:
  /// **'Food is ready to run.'**
  String get foodReadyAnywhere;

  /// No description provided for @foodReadyAtTable.
  ///
  /// In en, this message translates to:
  /// **'Table {code} — food is ready.'**
  String foodReadyAtTable(String code);

  /// No description provided for @addToTable.
  ///
  /// In en, this message translates to:
  /// **'Add to {code}'**
  String addToTable(String code);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @doneWithCount.
  ///
  /// In en, this message translates to:
  /// **'Done · {count}'**
  String doneWithCount(int count);

  /// No description provided for @menuLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the menu…'**
  String get menuLoading;

  /// No description provided for @searchDishes.
  ///
  /// In en, this message translates to:
  /// **'Search dishes'**
  String get searchDishes;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allCategories;

  /// No description provided for @uncategorised.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get uncategorised;

  /// No description provided for @noDishesTitle.
  ///
  /// In en, this message translates to:
  /// **'No dishes'**
  String get noDishesTitle;

  /// No description provided for @noDishesMatch.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches that search.'**
  String get noDishesMatch;

  /// No description provided for @noteForKitchen.
  ///
  /// In en, this message translates to:
  /// **'Note for the kitchen'**
  String get noteForKitchen;

  /// No description provided for @noteForKitchenHint.
  ///
  /// In en, this message translates to:
  /// **'No chilli, well done, serve last…'**
  String get noteForKitchenHint;

  /// No description provided for @addedToTicket.
  ///
  /// In en, this message translates to:
  /// **'{name} added'**
  String addedToTicket(String name);

  /// No description provided for @billForTable.
  ///
  /// In en, this message translates to:
  /// **'Bill · Table {code}'**
  String billForTable(String code);

  /// No description provided for @fetchingBill.
  ///
  /// In en, this message translates to:
  /// **'Fetching the bill…'**
  String get fetchingBill;

  /// No description provided for @noOpenBillTitle.
  ///
  /// In en, this message translates to:
  /// **'No open bill'**
  String get noOpenBillTitle;

  /// No description provided for @noOpenBillMessage.
  ///
  /// In en, this message translates to:
  /// **'This table has nothing to settle.'**
  String get noOpenBillMessage;

  /// No description provided for @billIsStatus.
  ///
  /// In en, this message translates to:
  /// **'This bill is {status}'**
  String billIsStatus(String status);

  /// No description provided for @billCannotSettle.
  ///
  /// In en, this message translates to:
  /// **'It cannot be settled. Ask a manager if that looks wrong.'**
  String get billCannotSettle;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @tip.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get tip;

  /// No description provided for @totalDue.
  ///
  /// In en, this message translates to:
  /// **'Total due'**
  String get totalDue;

  /// No description provided for @split.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get split;

  /// No description provided for @splitNone.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get splitNone;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get paymentMethod;

  /// No description provided for @paymentAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get paymentAmount;

  /// No description provided for @removePayment.
  ///
  /// In en, this message translates to:
  /// **'Remove this payment'**
  String get removePayment;

  /// No description provided for @anotherPayment.
  ///
  /// In en, this message translates to:
  /// **'Another payment'**
  String get anotherPayment;

  /// No description provided for @cashGiven.
  ///
  /// In en, this message translates to:
  /// **'Cash given (optional)'**
  String get cashGiven;

  /// No description provided for @cashGivenHelper.
  ///
  /// In en, this message translates to:
  /// **'Working out only — not sent to the server'**
  String get cashGivenHelper;

  /// No description provided for @changeDue.
  ///
  /// In en, this message translates to:
  /// **'Change due'**
  String get changeDue;

  /// No description provided for @stillToPay.
  ///
  /// In en, this message translates to:
  /// **'{amount} still to pay'**
  String stillToPay(String amount);

  /// No description provided for @moreThanBill.
  ///
  /// In en, this message translates to:
  /// **'{amount} more than the bill'**
  String moreThanBill(String amount);

  /// No description provided for @shortOfBill.
  ///
  /// In en, this message translates to:
  /// **'The payments are {amount} short of the bill.'**
  String shortOfBill(String amount);

  /// No description provided for @overBill.
  ///
  /// In en, this message translates to:
  /// **'The payments are {amount} more than the bill.'**
  String overBill(String amount);

  /// No description provided for @viewBill.
  ///
  /// In en, this message translates to:
  /// **'View bill'**
  String get viewBill;

  /// No description provided for @settleAmount.
  ///
  /// In en, this message translates to:
  /// **'Settle {amount}'**
  String settleAmount(String amount);

  /// No description provided for @settling.
  ///
  /// In en, this message translates to:
  /// **'Settling…'**
  String get settling;

  /// No description provided for @billSettled.
  ///
  /// In en, this message translates to:
  /// **'Bill settled'**
  String get billSettled;

  /// No description provided for @receipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receipt;

  /// No description provided for @tableFreeWhenCleared.
  ///
  /// In en, this message translates to:
  /// **'The table is free once it has been cleared down.'**
  String get tableFreeWhenCleared;

  /// No description provided for @proFormaWarning.
  ///
  /// In en, this message translates to:
  /// **'Not settled — this prints as a pro-forma, not a tax invoice.'**
  String get proFormaWarning;

  /// No description provided for @reprint.
  ///
  /// In en, this message translates to:
  /// **'Reprint'**
  String get reprint;

  /// No description provided for @print.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get print;

  /// No description provided for @printProForma.
  ///
  /// In en, this message translates to:
  /// **'Print pro-forma'**
  String get printProForma;

  /// No description provided for @printingNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Printing not allowed'**
  String get printingNotAllowed;

  /// No description provided for @reprintQueued.
  ///
  /// In en, this message translates to:
  /// **'Reprint queued.'**
  String get reprintQueued;

  /// No description provided for @printQueued.
  ///
  /// In en, this message translates to:
  /// **'Sent to the printer. It prints when the till agent picks it up.'**
  String get printQueued;

  /// No description provided for @emptySlipTitle.
  ///
  /// In en, this message translates to:
  /// **'The server returned an empty slip'**
  String get emptySlipTitle;

  /// No description provided for @emptySlipMessage.
  ///
  /// In en, this message translates to:
  /// **'Printing may still work. Tell a manager if it does not.'**
  String get emptySlipMessage;

  /// No description provided for @billCopied.
  ///
  /// In en, this message translates to:
  /// **'Bill copied.'**
  String get billCopied;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearSearch;

  /// No description provided for @nothingHereTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here'**
  String get nothingHereTitle;

  /// No description provided for @noMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'No match for \"{query}\"'**
  String noMatchTitle(String query);

  /// No description provided for @sectionOffMenu.
  ///
  /// In en, this message translates to:
  /// **'Every dish in this section is off the menu right now.'**
  String get sectionOffMenu;

  /// No description provided for @soldOutNotListed.
  ///
  /// In en, this message translates to:
  /// **'Sold-out dishes are not listed.'**
  String get soldOutNotListed;

  /// No description provided for @combo.
  ///
  /// In en, this message translates to:
  /// **'Combo'**
  String get combo;

  /// No description provided for @optionsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading options…'**
  String get optionsLoading;

  /// No description provided for @chooseExactly.
  ///
  /// In en, this message translates to:
  /// **'Choose {count}'**
  String chooseExactly(int count);

  /// No description provided for @chooseAtLeast.
  ///
  /// In en, this message translates to:
  /// **'Choose at least {count}'**
  String chooseAtLeast(int count);

  /// No description provided for @chooseUpTo.
  ///
  /// In en, this message translates to:
  /// **'Up to {count}'**
  String chooseUpTo(int count);

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @chooseFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose {group} first'**
  String chooseFirst(String group);

  /// No description provided for @addWithQtyAndPrice.
  ///
  /// In en, this message translates to:
  /// **'Add {count} · {amount}'**
  String addWithQtyAndPrice(int count, String amount);

  /// No description provided for @waiterSignIn.
  ///
  /// In en, this message translates to:
  /// **'Waiter sign in'**
  String get waiterSignIn;

  /// No description provided for @notifyFoodReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Food is ready'**
  String get notifyFoodReadyTitle;

  /// No description provided for @notifyFoodReadyAtTable.
  ///
  /// In en, this message translates to:
  /// **'Table {code} — ready'**
  String notifyFoodReadyAtTable(String code);

  /// No description provided for @notifyFoodReadyBody.
  ///
  /// In en, this message translates to:
  /// **'Food is up at the pass.'**
  String get notifyFoodReadyBody;

  /// No description provided for @notifyOrderSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Order sent'**
  String get notifyOrderSentTitle;

  /// No description provided for @notifyOrderSentBody.
  ///
  /// In en, this message translates to:
  /// **'Table {code} reached the kitchen.'**
  String notifyOrderSentBody(String code);

  /// No description provided for @notifyOrderSentBodyNumbered.
  ///
  /// In en, this message translates to:
  /// **'Table {code} reached the kitchen · {orderNo}'**
  String notifyOrderSentBodyNumbered(String code, String orderNo);
}

class _AppTextDelegate extends LocalizationsDelegate<AppText> {
  const _AppTextDelegate();

  @override
  Future<AppText> load(Locale locale) {
    return SynchronousFuture<AppText>(lookupAppText(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppTextDelegate old) => false;
}

AppText lookupAppText(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppTextEn();
    case 'ur':
      return AppTextUr();
  }

  throw FlutterError(
      'AppText.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
