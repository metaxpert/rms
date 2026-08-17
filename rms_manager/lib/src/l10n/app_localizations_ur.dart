// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppTextUr extends AppText {
  AppTextUr([String locale = 'ur']) : super(locale);

  @override
  String get managerSignIn => 'مینیجر سائن ان';

  @override
  String get tabService => 'سروس';

  @override
  String get tabKitchen => 'کچن';

  @override
  String get tabSales => 'سیلز';

  @override
  String get allOutlets => 'تمام آؤٹ لیٹس';

  @override
  String get oneOutlet => 'ایک آؤٹ لیٹ';

  @override
  String get chooseOutlet => 'آؤٹ لیٹ منتخب کریں';

  @override
  String get refresh => 'تازہ کریں';

  @override
  String get signOut => 'سائن آؤٹ';

  @override
  String get readingService => 'سروس پڑھی جا رہی ہے…';

  @override
  String get live => 'لائیو';

  @override
  String get offline => 'آف لائن';

  @override
  String liveTooltip(String time) {
    return 'لائیو۔ آخری بار $time پر پڑھا';
  }

  @override
  String get liveTooltipJustNow => 'لائیو۔ ابھی پڑھا';

  @override
  String get offlineTooltip =>
      'لائیو اپ ڈیٹس نہیں آ رہیں — تازہ کرنے کے لیے نیچے کھینچیں';

  @override
  String ordersReadyToRun(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count آرڈر لے جانے کو تیار ہیں',
      one: '1 آرڈر لے جانے کو تیار ہے',
    );
    return '$_temp0';
  }

  @override
  String get foodUpAtPass => 'کھانا تیار ہے اور پاس پر انتظار میں ہے۔';

  @override
  String ticketsPastTarget(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ٹکٹ مقررہ وقت سے آگے ہیں',
      one: '1 ٹکٹ مقررہ وقت سے آگے ہے',
    );
    return '$_temp0';
  }

  @override
  String longestWaiting(String wait) {
    return 'سب سے زیادہ انتظار $wait کا ہے۔';
  }

  @override
  String get sectionRightNow => 'ابھی';

  @override
  String get summaryOnTables => 'میزوں پر باقی';

  @override
  String get summaryTaken => 'آج کی وصولی';

  @override
  String get kpiOpenBills => 'کھلے بل';

  @override
  String get kpiReadyToServe => 'پیش کرنے کو تیار';

  @override
  String get kpiKitchenTickets => 'کچن ٹکٹس';

  @override
  String get kpiTablesInUse => 'زیرِ استعمال میزیں';

  @override
  String get kpiSettled => 'ادا شدہ';

  @override
  String get kpiDeliveriesOut => 'باہر ڈیلیوریاں';

  @override
  String get goNow => 'ابھی جائیں';

  @override
  String get nothingWaiting => 'کچھ زیرِ التوا نہیں';

  @override
  String get kitchenClear => 'کچن خالی ہے';

  @override
  String longestIs(String wait) {
    return 'سب سے زیادہ $wait';
  }

  @override
  String get noTablesSetUp => 'کوئی میز ترتیب نہیں';

  @override
  String percentFull(String percent) {
    return '$percent بھری';
  }

  @override
  String get noneOnTheRoad => 'کوئی راستے میں نہیں';

  @override
  String get onTheRoad => 'راستے میں';

  @override
  String get underAMinute => 'ایک منٹ سے کم';

  @override
  String minutesShort(int minutes) {
    return '$minutes منٹ';
  }

  @override
  String readAt(String time) {
    return '$time پر پڑھا گیا';
  }

  @override
  String get kitchenClearTitle => 'کچن خالی ہے';

  @override
  String get kitchenClearMessage => 'پکانے کے لیے کچھ زیرِ التوا نہیں۔';

  @override
  String pastTargetCount(int count) {
    return '$count مقررہ وقت سے آگے';
  }

  @override
  String ticketCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ٹکٹ',
      one: '1 ٹکٹ',
    );
    return '$_temp0';
  }

  @override
  String get ticket => 'ٹکٹ';

  @override
  String tableLabel(String code) {
    return 'میز $code';
  }

  @override
  String targetAndStatus(int minutes, String status) {
    return 'ہدف $minutes منٹ · $status';
  }

  @override
  String get stillOpen => 'ابھی کھلے';

  @override
  String get settled => 'ادا شدہ';

  @override
  String get nothingSettled => 'ابھی کوئی ادائیگی نہیں ہوئی۔';

  @override
  String get salesFootnote =>
      'اس آؤٹ لیٹ کے وہ آرڈر جو سرور دیتا ہے۔ کمائی کا ریکارڈ لیجر ہے، یہ اسکرین نہیں۔';

  @override
  String get stillOnTables => 'میزوں پر باقی';

  @override
  String get billsClosed => 'بند بل';

  @override
  String get averageBill => 'اوسط بل';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count آئٹم',
      one: '1 آئٹم',
    );
    return '$_temp0';
  }
}
