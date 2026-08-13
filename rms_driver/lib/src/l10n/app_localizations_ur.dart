// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppTextUr extends AppText {
  AppTextUr([String locale = 'ur']) : super(locale);

  @override
  String get runsTitle => 'رنز';

  @override
  String get switchOutlet => 'آؤٹ لیٹ بدلیں';

  @override
  String get signOut => 'سائن آؤٹ';

  @override
  String get runsLoading => 'آپ کے رنز لوڈ ہو رہے ہیں…';

  @override
  String get nothingToDeliverTitle => 'پہنچانے کو کچھ نہیں';

  @override
  String get nothingToDeliverMessage =>
      'جیسے ہی کچن رن بھیجے گا یہاں نظر آئے گا۔ دوبارہ دیکھنے کے لیے نیچے کھینچیں۔';

  @override
  String get sectionOnTheGo => 'جاری';

  @override
  String get sectionDoneToday => 'آج مکمل';

  @override
  String get wholeOutletBoard =>
      'یہ پورے آؤٹ لیٹ کا بورڈ ہے — سرور صرف آپ کے اپنے رنز کی فہرست نہیں دیتا۔';

  @override
  String get noAddress => 'کوئی پتہ درج نہیں';

  @override
  String etaMinutes(int minutes) {
    return 'متوقع $minutes منٹ';
  }

  @override
  String assignedAt(String time) {
    return '$time پر مختص';
  }

  @override
  String notYours(String provider) {
    return '$provider — یہ آپ کا نہیں';
  }

  @override
  String get run => 'رن';

  @override
  String get dropOff => 'پہنچانے کی جگہ';

  @override
  String get noAddressCall => 'کوئی پتہ درج نہیں — ریسٹورنٹ کو فون کریں۔';

  @override
  String get copy => 'کاپی';

  @override
  String get coordinatesCopied =>
      'کوآرڈینیٹس کاپی ہو گئے — میپس میں پیسٹ کریں۔';

  @override
  String get sharingLocation => 'آپ کا مقام شیئر ہو رہا ہے';

  @override
  String get locationOff => 'مقام بند';

  @override
  String get sharingOnHint =>
      'گاہک تقریباً دیکھ سکتا ہے کہ آپ کہاں ہیں۔ رن ختم ہوتے ہی بند ہو جائے گا۔';

  @override
  String get sharingOffHint =>
      'جب تک یہ آرڈر آپ کے پاس ہے، آن رکھیں تاکہ گاہک اسے دیکھ سکے۔';

  @override
  String lastSent(String time, int count) {
    return 'آخری بار $time · $count اپ ڈیٹس';
  }

  @override
  String get locationServiceOff =>
      'اس فون پر مقام بند ہے۔ اوپر سے کھینچ کر سیٹنگز میں آن کریں، پھر دوبارہ کوشش کریں۔';

  @override
  String get locationDenied =>
      'اس بار ایپ کو اجازت نہیں ملی۔ دوبارہ پوچھنے کے لیے سوئچ دبائیں۔';

  @override
  String get locationBlocked =>
      'اس ایپ کے لیے مقام کی اجازت بند ہے۔ یہ صرف فون کی Settings → Apps سے دوبارہ آن ہو سکتی ہے۔';

  @override
  String get progress => 'پیش رفت';

  @override
  String get progressAssigned => 'مختص';

  @override
  String get progressPickedUp => 'اٹھا لیا';

  @override
  String get progressDelivered => 'پہنچا دیا';

  @override
  String runIsStatus(String status) {
    return 'یہ رن $status ہے۔';
  }

  @override
  String aggregatorCarrying(String provider) {
    return '$provider یہ لے جا رہا ہے۔ اسے ان کی ایپ سے دیکھیں — یہاں سے کچھ نہیں بدلتا۔';
  }

  @override
  String get waitingForAssignment =>
      'ریسٹورنٹ کے یہ رن مختص کرنے کا انتظار ہے۔';

  @override
  String get somethingWentWrong => 'کچھ غلط ہو گیا';

  @override
  String get confirmHandover => 'حوالگی کی تصدیق کریں';

  @override
  String get askForCode => 'گاہک سے کہیں کہ اپنے آرڈر کا کوڈ پڑھ کر سنائے۔';

  @override
  String get deliveryCode => 'ڈیلیوری کوڈ';

  @override
  String get cancel => 'منسوخ';

  @override
  String get delivered => 'پہنچا دیا';

  @override
  String get failNobodyThere => 'پتے پر کوئی نہیں تھا';

  @override
  String get failRefused => 'گاہک نے آرڈر لینے سے انکار کیا';

  @override
  String get failAddressNotFound => 'پتہ نہیں مل سکا';

  @override
  String get failNoCode => 'گاہک نے کوڈ نہیں دیا';

  @override
  String get failVehicle => 'حادثہ یا گاڑی کا مسئلہ';

  @override
  String get whatHappened => 'کیا ہوا؟';

  @override
  String get markFailedTitle => 'اس رن کو ناکام قرار دیں؟';

  @override
  String markFailedMessage(String reason) {
    return '\"$reason\"\n\nریسٹورنٹ کو فوراً بتا دیا جائے گا۔ یہاں سے واپس نہیں ہو سکتا۔';
  }

  @override
  String get goBack => 'واپس';

  @override
  String get markFailed => 'ناکام قرار دیں';

  @override
  String get driverSignIn => 'ڈرائیور سائن ان';

  @override
  String get whichKitchen => 'کون سا کچن؟';

  @override
  String get runAssigned => 'ایک رن مختص ہوا ہے۔';
}
