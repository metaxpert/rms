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

  /// No description provided for @signInToOrder.
  ///
  /// In en, this message translates to:
  /// **'Sign in to order'**
  String get signInToOrder;

  /// No description provided for @chooseRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Choose a restaurant'**
  String get chooseRestaurant;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @changeRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Change restaurant'**
  String get changeRestaurant;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @menuLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the menu…'**
  String get menuLoading;

  /// No description provided for @searchTheMenu.
  ///
  /// In en, this message translates to:
  /// **'Search the menu'**
  String get searchTheMenu;

  /// Tooltip on the button that empties the menu search box.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearSearch;

  /// No description provided for @everything.
  ///
  /// In en, this message translates to:
  /// **'Everything'**
  String get everything;

  /// No description provided for @nothingMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches'**
  String get nothingMatchesTitle;

  /// No description provided for @nothingOnMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing on the menu'**
  String get nothingOnMenuTitle;

  /// No description provided for @tryAnotherWord.
  ///
  /// In en, this message translates to:
  /// **'Try a different word.'**
  String get tryAnotherWord;

  /// No description provided for @noMenuPublished.
  ///
  /// In en, this message translates to:
  /// **'This restaurant has not published a menu yet.'**
  String get noMenuPublished;

  /// No description provided for @prepMinutes.
  ///
  /// In en, this message translates to:
  /// **'about {minutes} min to cook'**
  String prepMinutes(int minutes);

  /// No description provided for @addNamed.
  ///
  /// In en, this message translates to:
  /// **'Add {name}'**
  String addNamed(String name);

  /// No description provided for @addedNamed.
  ///
  /// In en, this message translates to:
  /// **'{name} added'**
  String addedNamed(String name);

  /// No description provided for @basketWithCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Basket · 1 item} other{Basket · {count} items}}'**
  String basketWithCount(int count);

  /// No description provided for @yourBasket.
  ///
  /// In en, this message translates to:
  /// **'Your basket'**
  String get yourBasket;

  /// No description provided for @basketEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your basket is empty'**
  String get basketEmptyTitle;

  /// No description provided for @basketEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add something from the menu to get started.'**
  String get basketEmptyMessage;

  /// No description provided for @backToMenu.
  ///
  /// In en, this message translates to:
  /// **'Back to the menu'**
  String get backToMenu;

  /// No description provided for @delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get delivery;

  /// No description provided for @collection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get collection;

  /// No description provided for @addressLabel.
  ///
  /// In en, this message translates to:
  /// **'Where should we bring it?'**
  String get addressLabel;

  /// No description provided for @addressHint.
  ///
  /// In en, this message translates to:
  /// **'House, street, area — and a landmark helps'**
  String get addressHint;

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

  /// No description provided for @priceConfirmedNote.
  ///
  /// In en, this message translates to:
  /// **'The restaurant confirms the final price when it accepts your order. Delivery charges, if any, are added by them.'**
  String get priceConfirmedNote;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @placeOrder.
  ///
  /// In en, this message translates to:
  /// **'Place order'**
  String get placeOrder;

  /// No description provided for @checkoutFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your order did not go through'**
  String get checkoutFailedTitle;

  /// No description provided for @checkoutInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Something interrupted it. Nothing has been lost — try again.'**
  String get checkoutInterrupted;

  /// No description provided for @checkoutPartial.
  ///
  /// In en, this message translates to:
  /// **'The restaurant may already have part of this order. Trying again continues it rather than ordering twice.'**
  String get checkoutPartial;

  /// No description provided for @startOrderAgain.
  ///
  /// In en, this message translates to:
  /// **'Start this order again'**
  String get startOrderAgain;

  /// No description provided for @yourOrder.
  ///
  /// In en, this message translates to:
  /// **'Your order'**
  String get yourOrder;

  /// No description provided for @findingOrder.
  ///
  /// In en, this message translates to:
  /// **'Finding your order…'**
  String get findingOrder;

  /// No description provided for @orderPlaced.
  ///
  /// In en, this message translates to:
  /// **'Order placed'**
  String get orderPlaced;

  /// No description provided for @updatesAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Updates automatically. Pull down if you are impatient.'**
  String get updatesAutomatically;

  /// No description provided for @whatYouOrdered.
  ///
  /// In en, this message translates to:
  /// **'What you ordered'**
  String get whatYouOrdered;

  /// No description provided for @addressWillCallTitle.
  ///
  /// In en, this message translates to:
  /// **'The restaurant will call about your address'**
  String get addressWillCallTitle;

  /// No description provided for @addressCouldNotAttach.
  ///
  /// In en, this message translates to:
  /// **'We could not attach it to the order. Keep this handy:'**
  String get addressCouldNotAttach;

  /// No description provided for @stepOrderReceived.
  ///
  /// In en, this message translates to:
  /// **'Order received'**
  String get stepOrderReceived;

  /// No description provided for @stepBeingCooked.
  ///
  /// In en, this message translates to:
  /// **'Being cooked'**
  String get stepBeingCooked;

  /// No description provided for @stepReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get stepReady;

  /// No description provided for @stepOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get stepOnTheWay;

  /// No description provided for @stepDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get stepDelivered;

  /// No description provided for @stepReadyToCollect.
  ///
  /// In en, this message translates to:
  /// **'Ready to collect'**
  String get stepReadyToCollect;

  /// No description provided for @stepCollected.
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get stepCollected;

  /// No description provided for @headlineCancelled.
  ///
  /// In en, this message translates to:
  /// **'This order was cancelled. If that is unexpected, call the restaurant.'**
  String get headlineCancelled;

  /// No description provided for @headlineReceived.
  ///
  /// In en, this message translates to:
  /// **'The restaurant has your order.'**
  String get headlineReceived;

  /// No description provided for @headlineCooking.
  ///
  /// In en, this message translates to:
  /// **'Your food is being cooked.'**
  String get headlineCooking;

  /// No description provided for @headlineWaitingRider.
  ///
  /// In en, this message translates to:
  /// **'Your food is ready and waiting for a rider.'**
  String get headlineWaitingRider;

  /// No description provided for @headlineComeToCounter.
  ///
  /// In en, this message translates to:
  /// **'Ready to collect — come to the counter.'**
  String get headlineComeToCounter;

  /// No description provided for @headlineOnItsWay.
  ///
  /// In en, this message translates to:
  /// **'Your order is on its way.'**
  String get headlineOnItsWay;

  /// No description provided for @headlineOnItsWayEta.
  ///
  /// In en, this message translates to:
  /// **'On its way — about {minutes} minutes.'**
  String headlineOnItsWayEta(int minutes);

  /// No description provided for @headlineDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered. Enjoy.'**
  String get headlineDelivered;

  /// No description provided for @headlineCollected.
  ///
  /// In en, this message translates to:
  /// **'Collected. Enjoy.'**
  String get headlineCollected;

  /// No description provided for @semanticsHappeningNow.
  ///
  /// In en, this message translates to:
  /// **'happening now'**
  String get semanticsHappeningNow;

  /// No description provided for @semanticsDone.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get semanticsDone;

  /// No description provided for @semanticsToCome.
  ///
  /// In en, this message translates to:
  /// **'still to come'**
  String get semanticsToCome;

  /// No description provided for @semanticsStep.
  ///
  /// In en, this message translates to:
  /// **'{label}: {state}'**
  String semanticsStep(String label, String state);
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
