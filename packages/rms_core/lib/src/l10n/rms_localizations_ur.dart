// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'rms_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class RmsLocalizationsUr extends RmsLocalizations {
  RmsLocalizationsUr([String locale = 'ur']) : super(locale);

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

  @override
  String get orderStatusDraft => 'مسودہ';

  @override
  String get orderStatusPlaced => 'دیا گیا';

  @override
  String get orderStatusConfirmed => 'تصدیق شدہ';

  @override
  String get orderStatusPreparing => 'پک رہا ہے';

  @override
  String get orderStatusReady => 'تیار';

  @override
  String get orderStatusServed => 'پیش کر دیا';

  @override
  String get orderStatusSettled => 'ادائیگی مکمل';

  @override
  String get orderStatusCancelled => 'منسوخ';

  @override
  String get orderStatusVoided => 'کالعدم';

  @override
  String get orderStatusUnknown => 'نامعلوم';

  @override
  String get tableStatusAvailable => 'خالی';

  @override
  String get tableStatusReserved => 'محفوظ';

  @override
  String get tableStatusWaiting => 'انتظار میں';

  @override
  String get tableStatusOccupied => 'مہمان بیٹھے ہیں';

  @override
  String get tableStatusCleaning => 'صفائی';

  @override
  String get tableStatusUnknown => 'نامعلوم';

  @override
  String get deliveryStatusPending => 'غیر مختص';

  @override
  String get deliveryStatusAssigned => 'مختص';

  @override
  String get deliveryStatusPickedUp => 'اٹھا لیا';

  @override
  String get deliveryStatusEnRoute => 'راستے میں';

  @override
  String get deliveryStatusDelivered => 'پہنچا دیا';

  @override
  String get deliveryStatusFailed => 'ناکام';

  @override
  String get deliveryStatusCancelled => 'منسوخ';

  @override
  String get deliveryStatusUnknown => 'نامعلوم';

  @override
  String get deliveryActionPickUp => 'اٹھا لیا';

  @override
  String get deliveryActionStart => 'ڈیلیوری شروع کریں';

  @override
  String get deliveryActionDeliver => 'OTP کے ساتھ پہنچائیں';

  @override
  String get paymentCash => 'نقد';

  @override
  String get paymentCard => 'کارڈ';

  @override
  String get paymentWallet => 'والٹ';

  @override
  String get paymentOnline => 'آن لائن';

  @override
  String get waitJustNow => 'ابھی';

  @override
  String waitMinutes(int minutes) {
    return '$minutes منٹ';
  }

  @override
  String waitHoursMinutes(int hours, int minutes) {
    return '$hours گھنٹے $minutes منٹ';
  }

  @override
  String get chooseOutlet => 'اپنا آؤٹ لیٹ منتخب کریں';
}
