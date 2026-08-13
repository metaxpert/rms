// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'rms_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class RmsLocalizationsUr extends RmsLocalizations {
  RmsLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get loading => 'لوڈ ہو رہا ہے…';

  @override
  String get tryAgain => 'دوبارہ کوشش کریں';

  @override
  String get errorNoConnectionTitle => 'کوئی کنکشن نہیں';

  @override
  String get errorSignedOutTitle => 'سائن آؤٹ ہو گئے';

  @override
  String get errorNotAllowedTitle => 'اجازت نہیں';

  @override
  String get errorNotFoundTitle => 'نہیں ملا';

  @override
  String get errorRejectedTitle => 'یہ نہیں ہو سکا';

  @override
  String get errorServerTitle => 'سرور کا مسئلہ';

  @override
  String get errorUnknownTitle => 'کچھ غلط ہو گیا';

  @override
  String errorReference(String traceId) {
    return 'حوالہ: $traceId';
  }

  @override
  String get signIn => 'سائن ان';

  @override
  String get signInEmail => 'ای میل';

  @override
  String get signInPassword => 'پاس ورڈ';

  @override
  String get signInEmailMissing => 'اپنا ای میل درج کریں';

  @override
  String get signInPasswordMissing => 'اپنا پاس ورڈ درج کریں';

  @override
  String get signInShowPassword => 'پاس ورڈ دکھائیں';

  @override
  String get signInHidePassword => 'پاس ورڈ چھپائیں';

  @override
  String get serverSettings => 'سرور کی ترتیبات';

  @override
  String get serverSettingsBlurb =>
      'آپ کے ریسٹورنٹ سرور کا پتہ۔ اگر یقین نہ ہو تو اپنے مینیجر سے پوچھیں۔';

  @override
  String get serverAddress => 'سرور کا پتہ';

  @override
  String get serverAddressMissing => 'سرور کا پتہ درج کریں';

  @override
  String get serverAddressNeedsScheme => 'http:// یا https:// شامل کریں';

  @override
  String serverDefaultForBuild(String environment, String url) {
    return 'اس بلڈ کا ڈیفالٹ ($environment): $url';
  }

  @override
  String get save => 'محفوظ کریں';

  @override
  String get signOut => 'سائن آؤٹ';

  @override
  String get outletsEmptyTitle => 'کوئی آؤٹ لیٹ دستیاب نہیں';

  @override
  String get outletsEmptyMessage =>
      'آپ کا اکاؤنٹ کسی آؤٹ لیٹ سے منسلک نہیں۔ اپنے مینیجر سے کہیں کہ آپ کو شامل کریں۔';

  @override
  String get outletsLoading => 'آؤٹ لیٹس لوڈ ہو رہے ہیں…';

  @override
  String get outletClosed => 'یہ آؤٹ لیٹ بند ہے';

  @override
  String get outletNotConfigured =>
      'ابھی سروس کے لیے تیار نہیں — اپنے مینیجر سے پوچھیں';

  @override
  String get checkAgain => 'دوبارہ دیکھیں';
}
