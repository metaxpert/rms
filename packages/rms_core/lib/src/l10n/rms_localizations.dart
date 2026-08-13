import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'rms_localizations_en.dart';
import 'rms_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of RmsLocalizations
/// returned by `RmsLocalizations.of(context)`.
///
/// Applications need to include `RmsLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/rms_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: RmsLocalizations.localizationsDelegates,
///   supportedLocales: RmsLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the RmsLocalizations.supportedLocales
/// property.
abstract class RmsLocalizations {
  RmsLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static RmsLocalizations of(BuildContext context) {
    return Localizations.of<RmsLocalizations>(context, RmsLocalizations)!;
  }

  static const LocalizationsDelegate<RmsLocalizations> delegate =
      _RmsLocalizationsDelegate();

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

  /// Retry button on an error surface.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @errorNoConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get errorNoConnectionTitle;

  /// No description provided for @errorSignedOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get errorSignedOutTitle;

  /// No description provided for @errorNotAllowedTitle.
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get errorNotAllowedTitle;

  /// No description provided for @errorNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get errorNotFoundTitle;

  /// No description provided for @errorRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not be done'**
  String get errorRejectedTitle;

  /// No description provided for @errorServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Server problem'**
  String get errorServerTitle;

  /// No description provided for @errorUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorUnknownTitle;

  /// Support correlation id shown under an error.
  ///
  /// In en, this message translates to:
  /// **'Ref: {traceId}'**
  String errorReference(String traceId);

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signInEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get signInEmail;

  /// No description provided for @signInPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get signInPassword;

  /// No description provided for @signInEmailMissing.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get signInEmailMissing;

  /// No description provided for @signInPasswordMissing.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get signInPasswordMissing;

  /// No description provided for @signInShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get signInShowPassword;

  /// No description provided for @signInHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get signInHidePassword;

  /// No description provided for @serverSettings.
  ///
  /// In en, this message translates to:
  /// **'Server settings'**
  String get serverSettings;

  /// No description provided for @serverSettingsBlurb.
  ///
  /// In en, this message translates to:
  /// **'The address of your restaurant server. Ask your manager if you are not sure.'**
  String get serverSettingsBlurb;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverAddress;

  /// No description provided for @serverAddressMissing.
  ///
  /// In en, this message translates to:
  /// **'Enter the server address'**
  String get serverAddressMissing;

  /// No description provided for @serverAddressNeedsScheme.
  ///
  /// In en, this message translates to:
  /// **'Include http:// or https://'**
  String get serverAddressNeedsScheme;

  /// No description provided for @serverDefaultForBuild.
  ///
  /// In en, this message translates to:
  /// **'Default for this build ({environment}): {url}'**
  String serverDefaultForBuild(String environment, String url);

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @outletsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No outlets available'**
  String get outletsEmptyTitle;

  /// No description provided for @outletsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account is not assigned to any outlet. Ask your manager to add you to one.'**
  String get outletsEmptyMessage;

  /// No description provided for @outletsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading outlets…'**
  String get outletsLoading;

  /// No description provided for @outletClosed.
  ///
  /// In en, this message translates to:
  /// **'This outlet is closed'**
  String get outletClosed;

  /// No description provided for @outletNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not set up for service yet — ask your manager'**
  String get outletNotConfigured;

  /// No description provided for @checkAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get checkAgain;

  /// No description provided for @orderStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get orderStatusDraft;

  /// No description provided for @orderStatusPlaced.
  ///
  /// In en, this message translates to:
  /// **'Placed'**
  String get orderStatusPlaced;

  /// No description provided for @orderStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get orderStatusConfirmed;

  /// No description provided for @orderStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Cooking'**
  String get orderStatusPreparing;

  /// No description provided for @orderStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get orderStatusReady;

  /// No description provided for @orderStatusServed.
  ///
  /// In en, this message translates to:
  /// **'Served'**
  String get orderStatusServed;

  /// No description provided for @orderStatusSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get orderStatusSettled;

  /// No description provided for @orderStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get orderStatusCancelled;

  /// No description provided for @orderStatusVoided.
  ///
  /// In en, this message translates to:
  /// **'Voided'**
  String get orderStatusVoided;

  /// No description provided for @orderStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get orderStatusUnknown;

  /// No description provided for @tableStatusAvailable.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get tableStatusAvailable;

  /// No description provided for @tableStatusReserved.
  ///
  /// In en, this message translates to:
  /// **'Reserved'**
  String get tableStatusReserved;

  /// No description provided for @tableStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get tableStatusWaiting;

  /// No description provided for @tableStatusOccupied.
  ///
  /// In en, this message translates to:
  /// **'Seated'**
  String get tableStatusOccupied;

  /// No description provided for @tableStatusCleaning.
  ///
  /// In en, this message translates to:
  /// **'Cleaning'**
  String get tableStatusCleaning;

  /// No description provided for @tableStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get tableStatusUnknown;

  /// No description provided for @deliveryStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get deliveryStatusPending;

  /// No description provided for @deliveryStatusAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get deliveryStatusAssigned;

  /// No description provided for @deliveryStatusPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get deliveryStatusPickedUp;

  /// No description provided for @deliveryStatusEnRoute.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get deliveryStatusEnRoute;

  /// No description provided for @deliveryStatusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get deliveryStatusDelivered;

  /// No description provided for @deliveryStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get deliveryStatusFailed;

  /// No description provided for @deliveryStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get deliveryStatusCancelled;

  /// No description provided for @deliveryStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get deliveryStatusUnknown;

  /// No description provided for @deliveryActionPickUp.
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get deliveryActionPickUp;

  /// No description provided for @deliveryActionStart.
  ///
  /// In en, this message translates to:
  /// **'Start delivery'**
  String get deliveryActionStart;

  /// No description provided for @deliveryActionDeliver.
  ///
  /// In en, this message translates to:
  /// **'Deliver with OTP'**
  String get deliveryActionDeliver;

  /// No description provided for @paymentCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentCash;

  /// No description provided for @paymentCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get paymentCard;

  /// No description provided for @paymentWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get paymentWallet;

  /// No description provided for @paymentOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get paymentOnline;

  /// No description provided for @waitJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get waitJustNow;

  /// No description provided for @waitMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String waitMinutes(int minutes);

  /// No description provided for @waitHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String waitHoursMinutes(int hours, int minutes);

  /// No description provided for @chooseOutlet.
  ///
  /// In en, this message translates to:
  /// **'Choose your outlet'**
  String get chooseOutlet;
}

class _RmsLocalizationsDelegate
    extends LocalizationsDelegate<RmsLocalizations> {
  const _RmsLocalizationsDelegate();

  @override
  Future<RmsLocalizations> load(Locale locale) {
    return SynchronousFuture<RmsLocalizations>(lookupRmsLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_RmsLocalizationsDelegate old) => false;
}

RmsLocalizations lookupRmsLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return RmsLocalizationsEn();
    case 'ur':
      return RmsLocalizationsUr();
  }

  throw FlutterError(
      'RmsLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
