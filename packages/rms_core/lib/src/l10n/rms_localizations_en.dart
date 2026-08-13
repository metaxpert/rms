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
}
