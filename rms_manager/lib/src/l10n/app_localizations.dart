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

  /// No description provided for @managerSignIn.
  ///
  /// In en, this message translates to:
  /// **'Manager sign in'**
  String get managerSignIn;

  /// No description provided for @tabService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get tabService;

  /// No description provided for @tabKitchen.
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get tabKitchen;

  /// No description provided for @tabSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get tabSales;

  /// No description provided for @allOutlets.
  ///
  /// In en, this message translates to:
  /// **'All outlets'**
  String get allOutlets;

  /// No description provided for @oneOutlet.
  ///
  /// In en, this message translates to:
  /// **'One outlet'**
  String get oneOutlet;

  /// No description provided for @chooseOutlet.
  ///
  /// In en, this message translates to:
  /// **'Choose outlet'**
  String get chooseOutlet;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @readingService.
  ///
  /// In en, this message translates to:
  /// **'Reading the service…'**
  String get readingService;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @liveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Live. Last read {time}'**
  String liveTooltip(String time);

  /// No description provided for @liveTooltipJustNow.
  ///
  /// In en, this message translates to:
  /// **'Live. Last read just now'**
  String get liveTooltipJustNow;

  /// No description provided for @offlineTooltip.
  ///
  /// In en, this message translates to:
  /// **'Not receiving live updates — pull down to refresh'**
  String get offlineTooltip;

  /// No description provided for @ordersReadyToRun.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 order is ready to run} other{{count} orders are ready to run}}'**
  String ordersReadyToRun(int count);

  /// No description provided for @foodUpAtPass.
  ///
  /// In en, this message translates to:
  /// **'Food is up and waiting at the pass.'**
  String get foodUpAtPass;

  /// No description provided for @ticketsPastTarget.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 ticket is past target} other{{count} tickets are past target}}'**
  String ticketsPastTarget(int count);

  /// No description provided for @longestWaiting.
  ///
  /// In en, this message translates to:
  /// **'The longest has been waiting {wait}.'**
  String longestWaiting(String wait);

  /// No description provided for @sectionRightNow.
  ///
  /// In en, this message translates to:
  /// **'Right now'**
  String get sectionRightNow;

  /// No description provided for @summaryOnTables.
  ///
  /// In en, this message translates to:
  /// **'Still on tables'**
  String get summaryOnTables;

  /// No description provided for @summaryTaken.
  ///
  /// In en, this message translates to:
  /// **'Taken today'**
  String get summaryTaken;

  /// No description provided for @kpiOpenBills.
  ///
  /// In en, this message translates to:
  /// **'Open bills'**
  String get kpiOpenBills;

  /// No description provided for @kpiReadyToServe.
  ///
  /// In en, this message translates to:
  /// **'Ready to serve'**
  String get kpiReadyToServe;

  /// No description provided for @kpiKitchenTickets.
  ///
  /// In en, this message translates to:
  /// **'Kitchen tickets'**
  String get kpiKitchenTickets;

  /// No description provided for @kpiTablesInUse.
  ///
  /// In en, this message translates to:
  /// **'Tables in use'**
  String get kpiTablesInUse;

  /// No description provided for @kpiSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get kpiSettled;

  /// No description provided for @kpiDeliveriesOut.
  ///
  /// In en, this message translates to:
  /// **'Deliveries out'**
  String get kpiDeliveriesOut;

  /// No description provided for @goNow.
  ///
  /// In en, this message translates to:
  /// **'go now'**
  String get goNow;

  /// No description provided for @nothingWaiting.
  ///
  /// In en, this message translates to:
  /// **'nothing waiting'**
  String get nothingWaiting;

  /// No description provided for @kitchenClear.
  ///
  /// In en, this message translates to:
  /// **'kitchen is clear'**
  String get kitchenClear;

  /// No description provided for @longestIs.
  ///
  /// In en, this message translates to:
  /// **'longest {wait}'**
  String longestIs(String wait);

  /// No description provided for @noTablesSetUp.
  ///
  /// In en, this message translates to:
  /// **'no tables set up'**
  String get noTablesSetUp;

  /// No description provided for @percentFull.
  ///
  /// In en, this message translates to:
  /// **'{percent} full'**
  String percentFull(String percent);

  /// No description provided for @noneOnTheRoad.
  ///
  /// In en, this message translates to:
  /// **'none on the road'**
  String get noneOnTheRoad;

  /// No description provided for @onTheRoad.
  ///
  /// In en, this message translates to:
  /// **'on the road'**
  String get onTheRoad;

  /// No description provided for @underAMinute.
  ///
  /// In en, this message translates to:
  /// **'under a minute'**
  String get underAMinute;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @readAt.
  ///
  /// In en, this message translates to:
  /// **'Read at {time}'**
  String readAt(String time);

  /// No description provided for @kitchenClearTitle.
  ///
  /// In en, this message translates to:
  /// **'The kitchen is clear'**
  String get kitchenClearTitle;

  /// No description provided for @kitchenClearMessage.
  ///
  /// In en, this message translates to:
  /// **'Nothing is waiting to be cooked.'**
  String get kitchenClearMessage;

  /// No description provided for @pastTargetCount.
  ///
  /// In en, this message translates to:
  /// **'{count} past target'**
  String pastTargetCount(int count);

  /// No description provided for @ticketCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 ticket} other{{count} tickets}}'**
  String ticketCount(int count);

  /// No description provided for @ticket.
  ///
  /// In en, this message translates to:
  /// **'Ticket'**
  String get ticket;

  /// No description provided for @tableLabel.
  ///
  /// In en, this message translates to:
  /// **'Table {code}'**
  String tableLabel(String code);

  /// No description provided for @targetAndStatus.
  ///
  /// In en, this message translates to:
  /// **'Target {minutes} min · {status}'**
  String targetAndStatus(int minutes, String status);

  /// No description provided for @stillOpen.
  ///
  /// In en, this message translates to:
  /// **'Still open'**
  String get stillOpen;

  /// No description provided for @settled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get settled;

  /// No description provided for @nothingSettled.
  ///
  /// In en, this message translates to:
  /// **'Nothing settled yet.'**
  String get nothingSettled;

  /// No description provided for @salesFootnote.
  ///
  /// In en, this message translates to:
  /// **'Covers the orders the server returns for this outlet. The ledger, not this screen, is the record of what was earned.'**
  String get salesFootnote;

  /// No description provided for @stillOnTables.
  ///
  /// In en, this message translates to:
  /// **'Still on tables'**
  String get stillOnTables;

  /// No description provided for @billsClosed.
  ///
  /// In en, this message translates to:
  /// **'Bills closed'**
  String get billsClosed;

  /// No description provided for @averageBill.
  ///
  /// In en, this message translates to:
  /// **'Average bill'**
  String get averageBill;

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemCount(int count);
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
