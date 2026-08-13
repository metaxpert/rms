// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'rms_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class RmsLocalizationsEn extends RmsLocalizations {
  RmsLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get loading => 'Loading…';

  @override
  String get tryAgain => 'Try again';

  @override
  String get errorNoConnectionTitle => 'No connection';

  @override
  String get errorSignedOutTitle => 'Signed out';

  @override
  String get errorNotAllowedTitle => 'Not allowed';

  @override
  String get errorNotFoundTitle => 'Not found';

  @override
  String get errorRejectedTitle => 'Could not be done';

  @override
  String get errorServerTitle => 'Server problem';

  @override
  String get errorUnknownTitle => 'Something went wrong';

  @override
  String errorReference(String traceId) {
    return 'Ref: $traceId';
  }

  @override
  String get signIn => 'Sign in';

  @override
  String get signInEmail => 'Email';

  @override
  String get signInPassword => 'Password';

  @override
  String get signInEmailMissing => 'Enter your email';

  @override
  String get signInPasswordMissing => 'Enter your password';

  @override
  String get signInShowPassword => 'Show password';

  @override
  String get signInHidePassword => 'Hide password';

  @override
  String get serverSettings => 'Server settings';

  @override
  String get serverSettingsBlurb =>
      'The address of your restaurant server. Ask your manager if you are not sure.';

  @override
  String get serverAddress => 'Server address';

  @override
  String get serverAddressMissing => 'Enter the server address';

  @override
  String get serverAddressNeedsScheme => 'Include http:// or https://';

  @override
  String serverDefaultForBuild(String environment, String url) {
    return 'Default for this build ($environment): $url';
  }

  @override
  String get save => 'Save';

  @override
  String get signOut => 'Sign out';

  @override
  String get outletsEmptyTitle => 'No outlets available';

  @override
  String get outletsEmptyMessage =>
      'Your account is not assigned to any outlet. Ask your manager to add you to one.';

  @override
  String get outletsLoading => 'Loading outlets…';

  @override
  String get outletClosed => 'This outlet is closed';

  @override
  String get outletNotConfigured =>
      'Not set up for service yet — ask your manager';

  @override
  String get checkAgain => 'Check again';

  @override
  String get orderStatusDraft => 'Draft';

  @override
  String get orderStatusPlaced => 'Placed';

  @override
  String get orderStatusConfirmed => 'Confirmed';

  @override
  String get orderStatusPreparing => 'Cooking';

  @override
  String get orderStatusReady => 'Ready';

  @override
  String get orderStatusServed => 'Served';

  @override
  String get orderStatusSettled => 'Settled';

  @override
  String get orderStatusCancelled => 'Cancelled';

  @override
  String get orderStatusVoided => 'Voided';

  @override
  String get orderStatusUnknown => 'Unknown';

  @override
  String get tableStatusAvailable => 'Free';

  @override
  String get tableStatusReserved => 'Reserved';

  @override
  String get tableStatusWaiting => 'Waiting';

  @override
  String get tableStatusOccupied => 'Seated';

  @override
  String get tableStatusCleaning => 'Cleaning';

  @override
  String get tableStatusUnknown => 'Unknown';

  @override
  String get deliveryStatusPending => 'Unassigned';

  @override
  String get deliveryStatusAssigned => 'Assigned';

  @override
  String get deliveryStatusPickedUp => 'Picked up';

  @override
  String get deliveryStatusEnRoute => 'On the way';

  @override
  String get deliveryStatusDelivered => 'Delivered';

  @override
  String get deliveryStatusFailed => 'Failed';

  @override
  String get deliveryStatusCancelled => 'Cancelled';

  @override
  String get deliveryStatusUnknown => 'Unknown';

  @override
  String get deliveryActionPickUp => 'Picked up';

  @override
  String get deliveryActionStart => 'Start delivery';

  @override
  String get deliveryActionDeliver => 'Deliver with OTP';

  @override
  String get paymentCash => 'Cash';

  @override
  String get paymentCard => 'Card';

  @override
  String get paymentWallet => 'Wallet';

  @override
  String get paymentOnline => 'Online';

  @override
  String get waitJustNow => 'just now';

  @override
  String waitMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String waitHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get chooseOutlet => 'Choose your outlet';
}
