// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get settingsLanguageCurrency => '🌐 اللغة والعملة';

  @override
  String get languageLabel => 'اللغة';

  @override
  String get currencyLabel => 'العملة';

  @override
  String get currencyIqd => 'دينار';

  @override
  String get currencyUsd => 'دولار';

  @override
  String usdRateLine(String rate) {
    return '1 \$ = $rate د.ع';
  }

  @override
  String get usdRateEdit => 'تعديل سعر الصرف';

  @override
  String get usdRateTitle => 'سعر صرف الدولار';

  @override
  String get usdRateHint =>
      'كم ديناراً للدولار الواحد؟ (سعر السوق الذي تتعامل به)';

  @override
  String get usdRateField => '1 دولار = … دينار';

  @override
  String get usdRateInvalid => 'اكتب سعراً أكبر من صفر';

  @override
  String get currencyNote =>
      'الأسعار تُحفظ وتُزامَن بالدينار دائماً؛ الدولار للعرض والإدخال فقط. الفاتورة الذكية وسجل الفواتير بالدينار.';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get appName => 'صيدليتي';

  @override
  String get splashTagline => 'مخزونك الدوائي… أذكى وأبسط';

  @override
  String splashVersion(String version) {
    return 'الإصدار $version · مزامنة سحابية آمنة';
  }

  @override
  String get splashLoading => 'جارٍ التحميل';

  @override
  String get splashProgress => 'تحميل';

  @override
  String get welcomeSkip => 'تخطّي';

  @override
  String get welcomeNext => 'التالي';

  @override
  String get welcomeStart => 'ابدأ الآن';

  @override
  String welcomeSlideLabel(int n) {
    return 'الشريحة $n';
  }

  @override
  String get welcome1ChipA => 'Panadol · 24 علبة';

  @override
  String get welcome1ChipB => 'تم التعرّف تلقائياً';

  @override
  String get welcome1Title => 'امسح الباركود ';

  @override
  String get welcome1Accent => 'وأضف بثانية';

  @override
  String get welcome1Body =>
      'وجّه الكاميرا نحو العلبة، ويتعرّف التطبيق على الدواء من القاموس المشترك بين الصيدليات.';

  @override
  String get welcome2ChipA => 'قراءة ذكية للفاتورة';

  @override
  String get welcome2ChipB => '12 سطراً أُضيفت';

  @override
  String get welcome2Title => 'صوّر الفاتورة ';

  @override
  String get welcome2Accent => 'والباقي علينا';

  @override
  String get welcome2Body =>
      'الفاتورة الذكية تقرأ الأسماء والأسعار والكميات، وتنبّهك على أي سطر مشكوك فيه قبل الحفظ.';

  @override
  String get welcome3ChipA => '3 أدوية قاربت الانتهاء';

  @override
  String get welcome3ChipB => 'جهازان متزامنان';

  @override
  String get welcome3Title => 'مخزون واحد ';

  @override
  String get welcome3Accent => 'على كل أجهزتك';

  @override
  String get welcome3Body =>
      'مزامنة سحابية فورية مع زملائك، وتنبيهات للصلاحية والمخزون المنخفض قبل أن تتفاجأ.';

  @override
  String get typeMedicine => '💊 دواء';

  @override
  String get typeSupply => '🩹 مستلزم طبي';

  @override
  String get homeTitle => '💊 صيدليتي';

  @override
  String priceRepaired(int n) {
    return 'صُحّح سعر $n مادة قرأتها الفاتورة الذكية خطأً';
  }

  @override
  String invoiceAddedNew(int n) {
    return 'أُضيفت $n مادة جديدة';
  }

  @override
  String invoiceMerged(int n) {
    return 'دُمجت $n مع مواد موجودة مسبقاً';
  }

  @override
  String invoiceMergedWithin(int n) {
    return '($n منها مكرَّر داخل الفاتورة نفسها)';
  }

  @override
  String deletedItem(String name) {
    return '🗑️ حُذف \"$name\"';
  }

  @override
  String get undo => 'تراجع';

  @override
  String incompleteBanner(int n) {
    return '$n مادة بياناتها ناقصة';
  }

  @override
  String get completeData => 'إكمال البيانات';

  @override
  String get scanBarcode => 'مسح باركود';

  @override
  String get smartInvoice => 'فاتورة ذكية';

  @override
  String get add => 'إضافة';

  @override
  String get statMedicines => 'عدد الأدوية';

  @override
  String get statSupplies => 'عدد المستلزمات';

  @override
  String statTotalValue(String currency) {
    return 'القيمة الإجمالية ($currency)';
  }

  @override
  String statValueMissing(int n) {
    return 'القيمة ($n بلا سعر)';
  }

  @override
  String get searchSupplies => 'ابحث في المستلزمات بالاسم...';

  @override
  String get searchMedicines => 'ابحث بالاسم أو الباركود...';

  @override
  String get scanInSearch => 'مسح باركود في البحث';

  @override
  String get filters => 'الفلاتر';

  @override
  String get quickFilter => '📌 فلترة سريعة';

  @override
  String get filterExpiring => '⏳ قريبة الانتهاء';

  @override
  String get filterLowStock => '⚠️ منخفض أو نافد (≤5)';

  @override
  String filterIncomplete(int n) {
    return '📝 بيانات ناقصة ($n)';
  }

  @override
  String get filterNoBarcode => '📊 بدون باركود';

  @override
  String get filterHasImage => '📷 لديه صورة';

  @override
  String get filterNoImage => '🖼️ بدون صورة';

  @override
  String priceRange(String currency) {
    return '💰 نطاق السعر ($currency)';
  }

  @override
  String get quantityRange => '📦 نطاق الكمية';

  @override
  String get sortBy => '🔃 ترتيب حسب';

  @override
  String get sortNewest => '🕐 الأحدث';

  @override
  String get sortName => '🔤 الاسم';

  @override
  String get sortPrice => '💲 السعر';

  @override
  String get sortQuantity => '📦 الكمية';

  @override
  String get resetFilters => 'إعادة تعيين الفلاتر';

  @override
  String duplicatesBanner(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n تكرارات تحتاج مراجعة',
      one: '$n مجموعة تكرار تحتاج مراجعة',
    );
    return '$_temp0';
  }

  @override
  String get review => 'مراجعة';

  @override
  String showingCountMedicines(int shown, int total) {
    return 'عرض $shown من أصل $total دواء';
  }

  @override
  String showingCountSupplies(int shown, int total) {
    return 'عرض $shown من أصل $total مستلزم';
  }

  @override
  String get clearFilters => '✕ مسح الفلاتر';

  @override
  String get emptyNoResults => 'لا توجد نتائج مطابقة';

  @override
  String get emptyNoSupplies => 'لا توجد مستلزمات بعد';

  @override
  String get emptyNoMedicines => 'لا توجد أدوية بعد';

  @override
  String get emptyTryFilters => 'جرّب تغيير البحث أو الفلاتر';

  @override
  String get emptyHintInvoice => 'اضغط «فاتورة ذكية» لإضافة موادها دفعة واحدة';

  @override
  String get emptyHintAddSupply => 'اضغط «+» لإضافة أول مستلزم';

  @override
  String get emptyHintScan => 'اضغط «مسح باركود» للبدء';

  @override
  String get syncAllGood => 'كل شيء يعمل بشكل سليم ✅';

  @override
  String get ok => 'حسناً';

  @override
  String get rangeFrom => 'من';

  @override
  String get rangeTo => 'إلى';

  @override
  String get cardNoBarcode => 'بدون باركود';

  @override
  String get cardBarcode => 'باركود';

  @override
  String get price => 'السعر';

  @override
  String get quantity => 'الكمية';

  @override
  String get cardIncomplete => '📝 ناقصة';

  @override
  String get cardOut => 'نفذ';

  @override
  String get edit => 'تعديل';

  @override
  String get delete => 'حذف';

  @override
  String get expired => 'منتهي الصلاحية';

  @override
  String expiresOn(String date) {
    return 'ينتهي $date';
  }

  @override
  String get syncLocal => 'حفظ محلي';

  @override
  String get syncOffline => 'غير متصل — حفظ محلي';

  @override
  String get syncSyncing => 'جاري المزامنة…';

  @override
  String get syncSynced => 'مزامنة سحابية ✓';

  @override
  String get syncFailed => 'تعذّرت المزامنة';

  @override
  String get syncErrPermission =>
      'قواعد أمان Firestore ترفض الوصول.\nالحل: Firebase Console ← Firestore Database ← Rules ← اسمح بالقراءة والكتابة لمجموعة medicines ثم Publish.';

  @override
  String get syncErrNotFound =>
      'قاعدة بيانات Firestore غير منشأة في هذا المشروع.\nالحل: Firebase Console ← Build ← Firestore Database ← Create database.';

  @override
  String get syncErrUnavailable =>
      'لا يوجد اتصال بالإنترنت — البيانات محفوظة محلياً.';

  @override
  String get syncErrPrecondition =>
      'خدمة Firestore غير مفعّلة أو تحتاج إعداداً في Console.';

  @override
  String get syncErrUnauthenticated =>
      'هوية الجهاز غير جاهزة.\nالحل: Firebase Console ← Authentication ← Sign-in method ← تفعيل Anonymous.';

  @override
  String get syncErrUnknown => 'خطأ غير معروف';

  @override
  String syncDenied(int n) {
    return 'السحابة ترفض رفع $n مادة من هذا الهاتف — بقية المزامنة تمّت. راجع قواعد Firestore.';
  }

  @override
  String syncSkipped(int n) {
    return 'تم تخطّي $n سجل غير صالح في السحابة.';
  }

  @override
  String syncRelinked(int n, String names) {
    return 'أُعيد ربط $n مادة كانت مسجّلة باسم صيدلية أخرى: $names.';
  }

  @override
  String syncDoneWithNotes(String notes) {
    return 'تمت المزامنة. $notes';
  }

  @override
  String get listSeparator => '، ';

  @override
  String expiredDaysAgo(int n) {
    return 'منتهية منذ $n يوماً';
  }

  @override
  String get expiresToday => 'تنتهي اليوم';

  @override
  String daysLeft(int n) {
    return 'متبقٍ $n يوماً';
  }

  @override
  String get itemDeleted => 'حُذفت هذه المادة';

  @override
  String shareLinePrice(String v) {
    return 'السعر: $v';
  }

  @override
  String shareLineQty(int v) {
    return 'الكمية: $v';
  }

  @override
  String shareLineExpiry(String v) {
    return 'الصلاحية: $v';
  }

  @override
  String shareLineBarcode(String v) {
    return 'الباركود: $v';
  }

  @override
  String shareLineCompany(String v) {
    return 'الشركة: $v';
  }

  @override
  String get share => 'مشاركة';

  @override
  String get rowExpiry => '📅 الصلاحية';

  @override
  String get rowBarcode => '📊 الباركود';

  @override
  String get barcodeCopied => 'نُسخ الباركود';

  @override
  String get rowCompany => '🏭 الشركة';

  @override
  String get rowCategory => '🧪 نوع المادة';

  @override
  String get rowSection => '🗂️ القسم';

  @override
  String get rowAdded => '➕ الإضافة';

  @override
  String addedOn(String date) {
    return 'أُضيفت $date';
  }

  @override
  String get rowUpdated => '🕓 آخر تعديل';

  @override
  String get invoiceHistory => '🧾 سجل الفواتير';

  @override
  String get noInvoicesForItem => 'لا فواتير محفوظة لهذه المادة';

  @override
  String get unknownSupplier => 'مجهّز غير معروف';

  @override
  String get badgeExpired => '⛔ منتهية الصلاحية';

  @override
  String get badgeExpiring => '⏳ قاربت الانتهاء';

  @override
  String get badgeSoldOut => '🚫 نافدة';

  @override
  String get badgeLowStock => '⚠️ مخزون منخفض';

  @override
  String get badgeIncomplete => '📝 بيانات ناقصة';

  @override
  String get increase => 'زيادة';

  @override
  String get decrease => 'إنقاص';

  @override
  String get stockValue => 'قيمة المخزون';
}
