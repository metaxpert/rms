// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppTextUr extends AppText {
  AppTextUr([String locale = 'ur']) : super(locale);

  @override
  String get signInToOrder => 'آرڈر کے لیے سائن ان کریں';

  @override
  String get chooseRestaurant => 'ریسٹورنٹ منتخب کریں';

  @override
  String get menu => 'مینو';

  @override
  String get changeRestaurant => 'ریسٹورنٹ بدلیں';

  @override
  String get signOut => 'سائن آؤٹ';

  @override
  String get menuLoading => 'مینو لوڈ ہو رہا ہے…';

  @override
  String get searchTheMenu => 'مینو میں تلاش کریں';

  @override
  String get clearSearch => 'صاف کریں';

  @override
  String get everything => 'سب کچھ';

  @override
  String get nothingMatchesTitle => 'کچھ نہیں ملا';

  @override
  String get nothingOnMenuTitle => 'مینو میں کچھ نہیں';

  @override
  String get tryAnotherWord => 'کوئی اور لفظ آزمائیں۔';

  @override
  String get noMenuPublished => 'اس ریسٹورنٹ نے ابھی مینو شائع نہیں کیا۔';

  @override
  String prepMinutes(int minutes) {
    return 'پکنے میں تقریباً $minutes منٹ';
  }

  @override
  String addNamed(String name) {
    return '$name شامل کریں';
  }

  @override
  String addedNamed(String name) {
    return '$name شامل کر دیا';
  }

  @override
  String basketWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ٹوکری · $count آئٹم',
      one: 'ٹوکری · 1 آئٹم',
    );
    return '$_temp0';
  }

  @override
  String get yourBasket => 'آپ کی ٹوکری';

  @override
  String get basketEmptyTitle => 'آپ کی ٹوکری خالی ہے';

  @override
  String get basketEmptyMessage => 'شروع کرنے کے لیے مینو سے کچھ شامل کریں۔';

  @override
  String get backToMenu => 'مینو پر واپس';

  @override
  String get delivery => 'ڈیلیوری';

  @override
  String get collection => 'خود لے جانا';

  @override
  String get addressLabel => 'ہم کہاں پہنچائیں؟';

  @override
  String get addressHint => 'مکان، گلی، علاقہ — اور کوئی نشانی مددگار ہوتی ہے';

  @override
  String get oneFewer => 'ایک کم';

  @override
  String get remove => 'ہٹائیں';

  @override
  String get oneMore => 'ایک اور';

  @override
  String get subtotal => 'ذیلی میزان';

  @override
  String get tax => 'ٹیکس';

  @override
  String get serviceCharge => 'سروس چارج';

  @override
  String get rounding => 'راؤنڈنگ';

  @override
  String get total => 'کل';

  @override
  String get priceConfirmedNote =>
      'آرڈر قبول کرتے وقت ریسٹورنٹ حتمی قیمت کی تصدیق کرتا ہے۔ ڈیلیوری چارجز، اگر ہوں، وہی شامل کرتے ہیں۔';

  @override
  String get sending => 'بھیجا جا رہا ہے…';

  @override
  String get tryAgain => 'دوبارہ کوشش کریں';

  @override
  String get placeOrder => 'آرڈر دیں';

  @override
  String get checkoutFailedTitle => 'آپ کا آرڈر نہیں گیا';

  @override
  String get checkoutInterrupted =>
      'کسی چیز نے اسے روک دیا۔ کچھ ضائع نہیں ہوا — دوبارہ کوشش کریں۔';

  @override
  String get checkoutPartial =>
      'ہو سکتا ہے ریسٹورنٹ کے پاس اس آرڈر کا کچھ حصہ پہلے سے ہو۔ دوبارہ کوشش سے وہی جاری رہے گا، دوہرا آرڈر نہیں ہو گا۔';

  @override
  String get startOrderAgain => 'یہ آرڈر دوبارہ شروع کریں';

  @override
  String get yourOrder => 'آپ کا آرڈر';

  @override
  String get findingOrder => 'آپ کا آرڈر تلاش ہو رہا ہے…';

  @override
  String get orderPlaced => 'آرڈر دے دیا گیا';

  @override
  String get updatesAutomatically =>
      'خودکار طور پر اپ ڈیٹ ہوتا ہے۔ بے چینی ہو تو نیچے کھینچیں۔';

  @override
  String get whatYouOrdered => 'آپ نے کیا آرڈر کیا';

  @override
  String get addressWillCallTitle =>
      'ریسٹورنٹ آپ کے پتے کے بارے میں فون کرے گا';

  @override
  String get addressCouldNotAttach =>
      'ہم اسے آرڈر کے ساتھ منسلک نہیں کر سکے۔ یہ سامنے رکھیں:';

  @override
  String get stepOrderReceived => 'آرڈر موصول';

  @override
  String get stepBeingCooked => 'پک رہا ہے';

  @override
  String get stepReady => 'تیار';

  @override
  String get stepOnTheWay => 'راستے میں';

  @override
  String get stepDelivered => 'پہنچا دیا';

  @override
  String get stepReadyToCollect => 'لے جانے کو تیار';

  @override
  String get stepCollected => 'لے لیا گیا';

  @override
  String get headlineCancelled =>
      'یہ آرڈر منسوخ ہو گیا۔ اگر یہ غیر متوقع ہے تو ریسٹورنٹ کو فون کریں۔';

  @override
  String get headlineReceived => 'ریسٹورنٹ کو آپ کا آرڈر مل گیا ہے۔';

  @override
  String get headlineCooking => 'آپ کا کھانا پک رہا ہے۔';

  @override
  String get headlineWaitingRider =>
      'آپ کا کھانا تیار ہے اور رائیڈر کا انتظار ہے۔';

  @override
  String get headlineComeToCounter => 'لے جانے کو تیار — کاؤنٹر پر آ جائیں۔';

  @override
  String get headlineOnItsWay => 'آپ کا آرڈر راستے میں ہے۔';

  @override
  String headlineOnItsWayEta(int minutes) {
    return 'راستے میں — تقریباً $minutes منٹ۔';
  }

  @override
  String get headlineDelivered => 'پہنچا دیا۔ مزے سے کھائیں۔';

  @override
  String get headlineCollected => 'لے لیا گیا۔ مزے سے کھائیں۔';

  @override
  String get semanticsHappeningNow => 'ابھی ہو رہا ہے';

  @override
  String get semanticsDone => 'مکمل';

  @override
  String get semanticsToCome => 'ابھی باقی';

  @override
  String semanticsStep(String label, String state) {
    return '$label: $state';
  }
}
