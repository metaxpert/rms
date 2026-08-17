// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppTextUr extends AppText {
  AppTextUr([String locale = 'ur']) : super(locale);

  @override
  String get floorTitle => 'فلور';

  @override
  String get back => 'واپس';

  @override
  String get switchOutlet => 'آؤٹ لیٹ بدلیں';

  @override
  String get signOut => 'سائن آؤٹ';

  @override
  String get floorLoading => 'فلور لوڈ ہو رہا ہے…';

  @override
  String get liveConnecting => 'منسلک ہو رہا ہے';

  @override
  String get liveOffline => 'آف لائن';

  @override
  String get liveConnectingHint => 'لائیو اپ ڈیٹس سے منسلک ہو رہا ہے';

  @override
  String get liveOfflineHint =>
      'لائیو اپ ڈیٹس آف لائن ہیں — تازہ کرنے کے لیے نیچے کھینچیں';

  @override
  String floorStaleAt(String time) {
    return 'آف لائن — یہ فلور $time کا ہے۔ آرڈر کی حالت بدل چکی ہو سکتی ہے۔';
  }

  @override
  String get floorStaleUnknown =>
      'آف لائن — آخری دستیاب فلور دکھایا جا رہا ہے۔ آرڈر کی حالت بدل چکی ہو سکتی ہے۔';

  @override
  String get openBills => 'کھلے بل';

  @override
  String get readyToServe => 'پیش کرنے کو تیار';

  @override
  String get noAreasTitle => 'کوئی ڈائننگ ایریا نہیں';

  @override
  String get noAreasMessage =>
      'اس آؤٹ لیٹ میں ابھی کوئی ایریا یا میز ترتیب نہیں دی گئی۔ مینیجر ویب کنسول میں شامل کر سکتا ہے۔';

  @override
  String get checkAgain => 'دوبارہ دیکھیں';

  @override
  String get noTablesInArea => 'اس ایریا میں کوئی میز نہیں';

  @override
  String areaWithCount(String name, int count) {
    return '$name ($count)';
  }

  @override
  String get tableUnsentTicket => 'غیر بھیجی ٹکٹ';

  @override
  String get tableSendUnfinished => 'بھیجنا ادھورا';

  @override
  String get tableMerged => 'ضم شدہ';

  @override
  String tableSemantics(String code) {
    return 'میز $code';
  }

  @override
  String tableSeatsSemantics(int count) {
    return '$count نشستیں';
  }

  @override
  String tableOrderSemantics(String status, String total) {
    return 'آرڈر $status $total';
  }

  @override
  String get tableFoodReadySemantics => 'کھانا تیار';

  @override
  String tableTitle(String code) {
    return 'میز $code';
  }

  @override
  String get bill => 'بل';

  @override
  String get clearThisRound => 'یہ راؤنڈ صاف کریں';

  @override
  String get noOutletTitle => 'کوئی آؤٹ لیٹ منتخب نہیں';

  @override
  String get noOutletMessage => 'آرڈر لینے سے پہلے آؤٹ لیٹ منتخب کریں۔';

  @override
  String get tableNotFoundTitle => 'میز نہیں ملی';

  @override
  String get tableNotFoundMessage =>
      'ہو سکتا ہے اسے ہٹا دیا گیا ہو یا کسی اور میز میں ضم کر دیا گیا ہو۔';

  @override
  String get checkingForBill => 'کھلے بل کی جانچ ہو رہی ہے…';

  @override
  String get nothingOrderedTitle => 'ابھی کچھ آرڈر نہیں ہوا';

  @override
  String get nothingOrderedMessage =>
      'ٹکٹ شروع کرنے کے لیے مینو سے پکوان شامل کریں۔';

  @override
  String get openTheMenu => 'مینو کھولیں';

  @override
  String get addItems => 'آئٹم شامل کریں';

  @override
  String sendWithCount(int count) {
    return 'بھیجیں · $count';
  }

  @override
  String get sending => 'بھیجا جا رہا ہے…';

  @override
  String sentTo(String orderNo) {
    return 'بھیجا گیا · $orderNo';
  }

  @override
  String get sentHeader => 'بھیجا گیا';

  @override
  String get thisRoundNotSent => 'یہ راؤنڈ — نہیں بھیجا';

  @override
  String get notSentYet => 'ابھی نہیں بھیجا';

  @override
  String get billSoFar => 'اب تک کا بل';

  @override
  String get billHasNoItems => 'یہ بل کھلا ہے لیکن ابھی اس پر کوئی آئٹم نہیں۔';

  @override
  String couldNotCheckBill(String message) {
    return 'اس میز کا بل نہیں دیکھا جا سکا۔ $message';
  }

  @override
  String seats(int count) {
    return '$count نشستیں';
  }

  @override
  String placedAt(String time) {
    return '$time پر دیا گیا';
  }

  @override
  String get foodReadyToRun => 'کھانا لے جانے کے لیے تیار ہے';

  @override
  String unsentRoundFrom(String time) {
    return '$time کا غیر بھیجا راؤنڈ';
  }

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
  String get thisRound => 'یہ راؤنڈ';

  @override
  String get serverRetotals =>
      'یہ راؤنڈ بھیجنے پر سرور پورے بل کا حساب دوبارہ لگاتا ہے۔';

  @override
  String get clearRoundTitle => 'یہ راؤنڈ صاف کریں؟';

  @override
  String get clearRoundMessage =>
      'ہر غیر بھیجی لائن ہٹ جائے گی۔ جو کچن کو بھیجا جا چکا ہے وہ بل پر رہے گا — لیکن یہ راؤنڈ دوبارہ لینا ہو گا۔';

  @override
  String get keepIt => 'رہنے دیں';

  @override
  String get clear => 'صاف کریں';

  @override
  String get stopSendingTitle => 'بھیجنا روک دیں؟';

  @override
  String get stopSendingMessage =>
      'راؤنڈ اسی ٹیبلٹ پر رہے گا تاکہ آپ دوبارہ بھیج سکیں۔\n\nاگر اس میز کے لیے بل پہلے ہی کھل چکا ہے تو وہ منسوخ نہیں ہوتا — فلور دیکھیں، اور اگر وہ نہیں ہونا چاہیے تو مینیجر سے کالعدم کرائیں۔';

  @override
  String get keepTrying => 'کوشش جاری رکھیں';

  @override
  String get stop => 'روکیں';

  @override
  String get sentToKitchen => 'کچن کو بھیج دیا گیا۔';

  @override
  String sentToKitchenNumbered(String orderNo) {
    return 'کچن کو بھیج دیا گیا · $orderNo';
  }

  @override
  String billClosedNoMore(String status) {
    return 'یہ بل $status ہے۔ اس میں مزید کچھ شامل نہیں ہو سکتا۔';
  }

  @override
  String get noOrderPermission =>
      'آپ کا سائن اِن آرڈر نہیں لے سکتا۔ مینیجر سے آرڈر کی اجازت لیں۔';

  @override
  String get sendStageCreating => 'بل کھولا جا رہا ہے…';

  @override
  String get sendStageAddingItems => 'آئٹم شامل کیے جا رہے ہیں…';

  @override
  String get sendStagePlacing => 'آرڈر دیا جا رہا ہے…';

  @override
  String get sendStageConfirming => 'کچن کو بھیجا جا رہا ہے…';

  @override
  String get sendUnfinishedTitle => 'یہ راؤنڈ مکمل نہیں بھیجا جا سکا';

  @override
  String get sendFailedTitle => 'یہ راؤنڈ کچن تک نہیں پہنچا';

  @override
  String get sendInterruptedMessage =>
      'بھیجتے ہوئے ایپ بند ہو گئی۔ کچھ ضائع نہیں ہوا — مکمل کرنے کے لیے دوبارہ بھیجیں۔';

  @override
  String get billAlreadyOpen =>
      'اس میز کے لیے بل پہلے ہی کھلا ہے۔ دوبارہ بھیجنے سے وہی جاری رہے گا — دوسرا بل نہیں بنے گا۔';

  @override
  String get roundHeldAsSent =>
      'راؤنڈ بالکل اسی حالت میں محفوظ ہے جیسے بھیجا گیا تھا۔ بدلنے کے لیے پہلے روکیں۔';

  @override
  String resumeStage(String stage) {
    return 'جاری رکھیں · $stage';
  }

  @override
  String get tryAgain => 'دوبارہ کوشش کریں';

  @override
  String get outboxOneSent => 'زیرِ التوا ایک آرڈر کچن تک پہنچ گیا۔';

  @override
  String outboxManySent(int count) {
    return 'زیرِ التوا $count آرڈر کچن تک پہنچ گئے۔';
  }

  @override
  String get foodReadyAnywhere => 'کھانا لے جانے کے لیے تیار ہے۔';

  @override
  String foodReadyAtTable(String code) {
    return 'میز $code — کھانا تیار ہے۔';
  }

  @override
  String addToTable(String code) {
    return '$code میں شامل کریں';
  }

  @override
  String get close => 'بند کریں';

  @override
  String doneWithCount(int count) {
    return 'مکمل · $count';
  }

  @override
  String get menuLoading => 'مینو لوڈ ہو رہا ہے…';

  @override
  String get searchDishes => 'پکوان تلاش کریں';

  @override
  String get allCategories => 'سب';

  @override
  String get uncategorised => 'دیگر';

  @override
  String get noteForKitchen => 'کچن کے لیے نوٹ';

  @override
  String get noteForKitchenHint => 'مرچ نہیں، اچھی طرح پکا ہوا، آخر میں دیں…';

  @override
  String billForTable(String code) {
    return 'بل · میز $code';
  }

  @override
  String get fetchingBill => 'بل لایا جا رہا ہے…';

  @override
  String get noOpenBillTitle => 'کوئی کھلا بل نہیں';

  @override
  String get noOpenBillMessage => 'اس میز پر ادائیگی کے لیے کچھ نہیں۔';

  @override
  String billIsStatus(String status) {
    return 'یہ بل $status ہے';
  }

  @override
  String get billCannotSettle =>
      'اس کی ادائیگی نہیں ہو سکتی۔ اگر یہ غلط لگے تو مینیجر سے پوچھیں۔';

  @override
  String get discount => 'رعایت';

  @override
  String get tip => 'ٹِپ';

  @override
  String get totalDue => 'کل واجب';

  @override
  String get split => 'تقسیم';

  @override
  String get splitNone => 'نہیں';

  @override
  String get paymentMethod => 'طریقہ';

  @override
  String get paymentAmount => 'رقم';

  @override
  String get removePayment => 'یہ ادائیگی ہٹائیں';

  @override
  String get anotherPayment => 'ایک اور ادائیگی';

  @override
  String get cashGiven => 'دی گئی نقد رقم (اختیاری)';

  @override
  String get cashGivenHelper => 'صرف حساب کے لیے — سرور کو نہیں بھیجی جاتی';

  @override
  String get changeDue => 'واپسی';

  @override
  String stillToPay(String amount) {
    return '$amount ابھی باقی';
  }

  @override
  String moreThanBill(String amount) {
    return 'بل سے $amount زیادہ';
  }

  @override
  String shortOfBill(String amount) {
    return 'ادائیگیاں بل سے $amount کم ہیں۔';
  }

  @override
  String overBill(String amount) {
    return 'ادائیگیاں بل سے $amount زیادہ ہیں۔';
  }

  @override
  String get viewBill => 'بل دیکھیں';

  @override
  String settleAmount(String amount) {
    return '$amount وصول کریں';
  }

  @override
  String get settling => 'ادائیگی ہو رہی ہے…';

  @override
  String get billSettled => 'بل ادا ہو گیا';

  @override
  String get receipt => 'رسید';

  @override
  String get tableFreeWhenCleared => 'میز صاف ہونے کے بعد خالی ہو جائے گی۔';

  @override
  String get proFormaWarning =>
      'ادائیگی باقی ہے — یہ پرو فارما چھپے گا، ٹیکس انوائس نہیں۔';

  @override
  String get reprint => 'دوبارہ پرنٹ';

  @override
  String get print => 'پرنٹ';

  @override
  String get printProForma => 'پرو فارما پرنٹ کریں';

  @override
  String get printingNotAllowed => 'پرنٹ کی اجازت نہیں';

  @override
  String get reprintQueued => 'دوبارہ پرنٹ قطار میں ہے۔';

  @override
  String get printQueued =>
      'پرنٹر کو بھیج دیا۔ ٹِل ایجنٹ اٹھاتے ہی چھپ جائے گا۔';

  @override
  String get emptySlipTitle => 'سرور نے خالی پرچی دی';

  @override
  String get emptySlipMessage =>
      'پرنٹ پھر بھی ہو سکتا ہے۔ نہ ہو تو مینیجر کو بتائیں۔';

  @override
  String get billCopied => 'بل کاپی ہو گیا۔';

  @override
  String get clearSearch => 'صاف کریں';

  @override
  String get nothingHereTitle => 'یہاں کچھ نہیں';

  @override
  String noMatchTitle(String query) {
    return '\"$query\" سے کچھ نہیں ملا';
  }

  @override
  String get sectionOffMenu => 'اس حصے کا ہر پکوان اس وقت مینو سے باہر ہے۔';

  @override
  String get soldOutNotListed => 'ختم شدہ پکوان درج نہیں کیے جاتے۔';

  @override
  String get combo => 'کومبو';

  @override
  String get optionsLoading => 'آپشنز لوڈ ہو رہے ہیں…';

  @override
  String chooseExactly(int count) {
    return '$count منتخب کریں';
  }

  @override
  String chooseAtLeast(int count) {
    return 'کم از کم $count منتخب کریں';
  }

  @override
  String chooseUpTo(int count) {
    return 'زیادہ سے زیادہ $count';
  }

  @override
  String get optional => 'اختیاری';

  @override
  String chooseFirst(String group) {
    return 'پہلے $group منتخب کریں';
  }

  @override
  String addWithQtyAndPrice(int count, String amount) {
    return '$count شامل کریں · $amount';
  }

  @override
  String get waiterSignIn => 'ویٹر سائن ان';

  @override
  String get notifyFoodReadyTitle => 'کھانا تیار ہے';

  @override
  String notifyFoodReadyAtTable(String code) {
    return 'میز $code — تیار';
  }

  @override
  String get notifyFoodReadyBody => 'کھانا پاس پر تیار ہے۔';

  @override
  String get notifyOrderSentTitle => 'آرڈر بھیج دیا';

  @override
  String notifyOrderSentBody(String code) {
    return 'میز $code کچن تک پہنچ گئی۔';
  }

  @override
  String notifyOrderSentBodyNumbered(String code, String orderNo) {
    return 'میز $code کچن تک پہنچ گئی · $orderNo';
  }
}
