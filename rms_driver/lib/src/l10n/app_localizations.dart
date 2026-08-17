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

  /// No description provided for @runsTitle.
  ///
  /// In en, this message translates to:
  /// **'Runs'**
  String get runsTitle;

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

  /// No description provided for @runsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your runs…'**
  String get runsLoading;

  /// No description provided for @nothingToDeliverTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to deliver'**
  String get nothingToDeliverTitle;

  /// No description provided for @nothingToDeliverMessage.
  ///
  /// In en, this message translates to:
  /// **'New runs appear here as the kitchen dispatches them. Pull down to check again.'**
  String get nothingToDeliverMessage;

  /// No description provided for @sectionOnTheGo.
  ///
  /// In en, this message translates to:
  /// **'On the go'**
  String get sectionOnTheGo;

  /// No description provided for @sectionDoneToday.
  ///
  /// In en, this message translates to:
  /// **'Done today'**
  String get sectionDoneToday;

  /// No description provided for @noAddress.
  ///
  /// In en, this message translates to:
  /// **'No address on file'**
  String get noAddress;

  /// No description provided for @etaMinutes.
  ///
  /// In en, this message translates to:
  /// **'ETA {minutes} min'**
  String etaMinutes(int minutes);

  /// No description provided for @assignedAt.
  ///
  /// In en, this message translates to:
  /// **'assigned {time}'**
  String assignedAt(String time);

  /// No description provided for @notYours.
  ///
  /// In en, this message translates to:
  /// **'{provider} — not yours to drive'**
  String notYours(String provider);

  /// No description provided for @run.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get run;

  /// No description provided for @dropOff.
  ///
  /// In en, this message translates to:
  /// **'Drop-off'**
  String get dropOff;

  /// No description provided for @noAddressCall.
  ///
  /// In en, this message translates to:
  /// **'No address on file — call the restaurant.'**
  String get noAddressCall;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @coordinatesCopied.
  ///
  /// In en, this message translates to:
  /// **'Coordinates copied — paste into Maps.'**
  String get coordinatesCopied;

  /// No description provided for @sharingLocation.
  ///
  /// In en, this message translates to:
  /// **'Sharing your location'**
  String get sharingLocation;

  /// No description provided for @locationOff.
  ///
  /// In en, this message translates to:
  /// **'Location off'**
  String get locationOff;

  /// No description provided for @sharingOnHint.
  ///
  /// In en, this message translates to:
  /// **'The customer can see roughly where you are. It stops when the run finishes.'**
  String get sharingOnHint;

  /// No description provided for @sharingOffHint.
  ///
  /// In en, this message translates to:
  /// **'Turn on while you are carrying this order so the customer can follow it.'**
  String get sharingOffHint;

  /// No description provided for @lastSent.
  ///
  /// In en, this message translates to:
  /// **'Last sent {time} · {count} updates'**
  String lastSent(String time, int count);

  /// No description provided for @locationServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Location is switched off on this phone. Turn it on in the pull-down settings, then try again.'**
  String get locationServiceOff;

  /// No description provided for @locationDenied.
  ///
  /// In en, this message translates to:
  /// **'The app was not given permission this time. Tap the switch again to be asked once more.'**
  String get locationDenied;

  /// No description provided for @locationBlocked.
  ///
  /// In en, this message translates to:
  /// **'Location permission is blocked for this app. It can only be turned back on in the phone\'s Settings → Apps.'**
  String get locationBlocked;

  /// No description provided for @locationForegroundOnly.
  ///
  /// In en, this message translates to:
  /// **'Tracking only works while this screen is open. To keep the customer\'s map moving with the phone in your pocket, allow location \"all the time\" in Settings.'**
  String get locationForegroundOnly;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @progressAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get progressAssigned;

  /// No description provided for @progressPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get progressPickedUp;

  /// No description provided for @progressDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get progressDelivered;

  /// No description provided for @runIsStatus.
  ///
  /// In en, this message translates to:
  /// **'This run is {status}.'**
  String runIsStatus(String status);

  /// No description provided for @aggregatorCarrying.
  ///
  /// In en, this message translates to:
  /// **'{provider} is carrying this one. Track it through their app — nothing here changes it.'**
  String aggregatorCarrying(String provider);

  /// No description provided for @waitingForAssignment.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the restaurant to assign this run.'**
  String get waitingForAssignment;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @confirmHandover.
  ///
  /// In en, this message translates to:
  /// **'Confirm the handover'**
  String get confirmHandover;

  /// No description provided for @askForCode.
  ///
  /// In en, this message translates to:
  /// **'Ask the customer to read out the code on their order.'**
  String get askForCode;

  /// No description provided for @deliveryCode.
  ///
  /// In en, this message translates to:
  /// **'Delivery code'**
  String get deliveryCode;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @failNobodyThere.
  ///
  /// In en, this message translates to:
  /// **'Nobody at the address'**
  String get failNobodyThere;

  /// No description provided for @failRefused.
  ///
  /// In en, this message translates to:
  /// **'Customer refused the order'**
  String get failRefused;

  /// No description provided for @failAddressNotFound.
  ///
  /// In en, this message translates to:
  /// **'Address could not be found'**
  String get failAddressNotFound;

  /// No description provided for @failNoCode.
  ///
  /// In en, this message translates to:
  /// **'Customer would not give the code'**
  String get failNoCode;

  /// No description provided for @failVehicle.
  ///
  /// In en, this message translates to:
  /// **'Accident or vehicle problem'**
  String get failVehicle;

  /// No description provided for @whatHappened.
  ///
  /// In en, this message translates to:
  /// **'What happened?'**
  String get whatHappened;

  /// No description provided for @markFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark this run failed?'**
  String get markFailedTitle;

  /// No description provided for @markFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{reason}\"\n\nThe restaurant is told straight away. This cannot be undone from here.'**
  String markFailedMessage(String reason);

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get goBack;

  /// No description provided for @markFailed.
  ///
  /// In en, this message translates to:
  /// **'Mark failed'**
  String get markFailed;

  /// No description provided for @driverSignIn.
  ///
  /// In en, this message translates to:
  /// **'Driver sign in'**
  String get driverSignIn;

  /// No description provided for @whichKitchen.
  ///
  /// In en, this message translates to:
  /// **'Which kitchen?'**
  String get whichKitchen;

  /// No description provided for @runAssigned.
  ///
  /// In en, this message translates to:
  /// **'A run has been assigned.'**
  String get runAssigned;

  /// No description provided for @startShift.
  ///
  /// In en, this message translates to:
  /// **'Start shift'**
  String get startShift;

  /// No description provided for @endShift.
  ///
  /// In en, this message translates to:
  /// **'End shift'**
  String get endShift;

  /// No description provided for @offShift.
  ///
  /// In en, this message translates to:
  /// **'Off shift — you will not be given deliveries'**
  String get offShift;

  /// No description provided for @onShiftSummary.
  ///
  /// In en, this message translates to:
  /// **'On shift · {live} in hand · {done} delivered today'**
  String onShiftSummary(int live, int done);

  /// No description provided for @riderNotLinked.
  ///
  /// In en, this message translates to:
  /// **'This login is not linked to a rider yet. Ask your manager to link it on the rider roster.'**
  String get riderNotLinked;

  /// No description provided for @riderProfileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not load your rider details.'**
  String get riderProfileUnavailable;

  /// No description provided for @yourRunsOnly.
  ///
  /// In en, this message translates to:
  /// **'These are your runs only. A job you cannot see has been given to another rider.'**
  String get yourRunsOnly;
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
