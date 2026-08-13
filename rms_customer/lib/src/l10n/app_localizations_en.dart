// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppTextEn extends AppText {
  AppTextEn([String locale = 'en']) : super(locale);

  @override
  String get signInToOrder => 'Sign in to order';

  @override
  String get chooseRestaurant => 'Choose a restaurant';

  @override
  String get menu => 'Menu';

  @override
  String get changeRestaurant => 'Change restaurant';

  @override
  String get signOut => 'Sign out';

  @override
  String get menuLoading => 'Loading the menu…';

  @override
  String get searchTheMenu => 'Search the menu';

  @override
  String get clearSearch => 'Clear';

  @override
  String get everything => 'Everything';

  @override
  String get nothingMatchesTitle => 'Nothing matches';

  @override
  String get nothingOnMenuTitle => 'Nothing on the menu';

  @override
  String get tryAnotherWord => 'Try a different word.';

  @override
  String get noMenuPublished => 'This restaurant has not published a menu yet.';

  @override
  String prepMinutes(int minutes) {
    return 'about $minutes min to cook';
  }

  @override
  String addNamed(String name) {
    return 'Add $name';
  }

  @override
  String addedNamed(String name) {
    return '$name added';
  }

  @override
  String basketWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Basket · $count items',
      one: 'Basket · 1 item',
    );
    return '$_temp0';
  }

  @override
  String get yourBasket => 'Your basket';

  @override
  String get basketEmptyTitle => 'Your basket is empty';

  @override
  String get basketEmptyMessage =>
      'Add something from the menu to get started.';

  @override
  String get backToMenu => 'Back to the menu';

  @override
  String get delivery => 'Delivery';

  @override
  String get collection => 'Collection';

  @override
  String get addressLabel => 'Where should we bring it?';

  @override
  String get addressHint => 'House, street, area — and a landmark helps';

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
  String get priceConfirmedNote =>
      'The restaurant confirms the final price when it accepts your order. Delivery charges, if any, are added by them.';

  @override
  String get sending => 'Sending…';

  @override
  String get tryAgain => 'Try again';

  @override
  String get placeOrder => 'Place order';

  @override
  String get checkoutFailedTitle => 'Your order did not go through';

  @override
  String get checkoutInterrupted =>
      'Something interrupted it. Nothing has been lost — try again.';

  @override
  String get checkoutPartial =>
      'The restaurant may already have part of this order. Trying again continues it rather than ordering twice.';

  @override
  String get startOrderAgain => 'Start this order again';

  @override
  String get yourOrder => 'Your order';

  @override
  String get findingOrder => 'Finding your order…';

  @override
  String get orderPlaced => 'Order placed';

  @override
  String get updatesAutomatically =>
      'Updates automatically. Pull down if you are impatient.';

  @override
  String get whatYouOrdered => 'What you ordered';

  @override
  String get addressWillCallTitle =>
      'The restaurant will call about your address';

  @override
  String get addressCouldNotAttach =>
      'We could not attach it to the order. Keep this handy:';

  @override
  String get stepOrderReceived => 'Order received';

  @override
  String get stepBeingCooked => 'Being cooked';

  @override
  String get stepReady => 'Ready';

  @override
  String get stepOnTheWay => 'On the way';

  @override
  String get stepDelivered => 'Delivered';

  @override
  String get stepReadyToCollect => 'Ready to collect';

  @override
  String get stepCollected => 'Collected';

  @override
  String get headlineCancelled =>
      'This order was cancelled. If that is unexpected, call the restaurant.';

  @override
  String get headlineReceived => 'The restaurant has your order.';

  @override
  String get headlineCooking => 'Your food is being cooked.';

  @override
  String get headlineWaitingRider =>
      'Your food is ready and waiting for a rider.';

  @override
  String get headlineComeToCounter => 'Ready to collect — come to the counter.';

  @override
  String get headlineOnItsWay => 'Your order is on its way.';

  @override
  String headlineOnItsWayEta(int minutes) {
    return 'On its way — about $minutes minutes.';
  }

  @override
  String get headlineDelivered => 'Delivered. Enjoy.';

  @override
  String get headlineCollected => 'Collected. Enjoy.';

  @override
  String get semanticsHappeningNow => 'happening now';

  @override
  String get semanticsDone => 'done';

  @override
  String get semanticsToCome => 'still to come';

  @override
  String semanticsStep(String label, String state) {
    return '$label: $state';
  }
}
