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
  String homeCountMedicines(int n, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$count دواء',
    );
    return '$_temp0';
  }

  @override
  String homeCountSupplies(int n, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$count مستلزم',
    );
    return '$_temp0';
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

  @override
  String formBarcodeNoData(String code) {
    return 'تم قراءة الباركود: $code — لم نجد بياناته، أكمل الحقول يدوياً';
  }

  @override
  String formConfirmedBy(int n) {
    return ' (أكّدته $n صيدليات)';
  }

  @override
  String formFetchedFrom(String source, String confirmed) {
    return 'تم جلب بيانات الدواء من $source$confirmed ✅';
  }

  @override
  String get formAddIncomingTitle => '📦 إضافة كمية واردة';

  @override
  String get formAddIncomingHint => 'العدد الوارد في الفاتورة';

  @override
  String formAddedNowBalance(int added, int total) {
    return 'أُضيف $added — الرصيد الآن $total';
  }

  @override
  String get formExpiryPickerTitle => 'تاريخ انتهاء الصلاحية';

  @override
  String get formInvalidPrice => 'السعر غير صالح — اكتب أرقاماً فقط';

  @override
  String get formInvalidQty => 'الكمية غير صالحة — اكتب عدداً صحيحاً';

  @override
  String formSaveFailed(String error) {
    return 'تعذّر الحفظ: $error';
  }

  @override
  String get formBarcodeTakenTitle => '⚠️ الباركود مسجَّل لمادة أخرى';

  @override
  String formBarcodeTakenBody(
    String barcode,
    String name,
    int qty,
    String price,
  ) {
    return 'الباركود «$barcode» يخص «$name» المسجّلة لديك بالفعل — الكمية $qty بسعر $price.\n\nلا يمكن حفظ مادتين بنفس الباركود. «تعديل الموجود» يفتحه للتحديث (يدعم \"+\" لإضافة الوارد إلى الرصيد الحالي).';
  }

  @override
  String get editExisting => 'تعديل الموجود';

  @override
  String get formDeleteOwner => '🗑️ حذف المرتبط';

  @override
  String get formDeleteOwnerTitle => 'حذف الدواء المرتبط؟';

  @override
  String get formDeleteOwnerTitleSupply => 'حذف المستلزم المرتبط؟';

  @override
  String formDeleteOwnerBody(
    String name,
    String barcode,
    int qty,
    String price,
  ) {
    return 'هل تريد حذف «$name» المرتبط بالباركود «$barcode»؟\nالكمية $qty بسعر $price.\n\nيُحذف بكل تفاصيله ولا يمكن التراجع.';
  }

  @override
  String formOwnerDeleted(String name) {
    return '🗑️ حُذف «$name» — اضغط حفظ لربط الباركود بهذه المادة';
  }

  @override
  String formBarcodeOwnerBody(
    String barcode,
    String name,
    int qty,
    String price,
  ) {
    return 'الباركود «$barcode» يخص «$name» — الكمية $qty بسعر $price.\n\nلا يمكن حفظ مادتين بنفس الباركود. صحّح الباركود، أو احذف المادة المرتبطة، أو ادمج المادتين من «مراجعة التكرارات» في الإعدادات.';
  }

  @override
  String get formSameNameTitle => '⚠️ مادة بنفس الاسم موجودة';

  @override
  String formSameNameBody(String name, int qty, String price) {
    return '«$name» مسجّلة لديك بالفعل — الكمية $qty بسعر $price.\n\nتعديل الموجود يفتحه للتحديث (يدعم \"+\" لإضافة الوارد). الحفظ كسجل منفصل يُبقي الاثنين قائمين.';
  }

  @override
  String get separateRecord => 'سجل منفصل';

  @override
  String get formTitleEditSupply => 'تعديل مستلزم';

  @override
  String get formTitleEditMedicine => 'تعديل دواء';

  @override
  String get formTitleNewSupply => 'إضافة مستلزم جديد';

  @override
  String get formTitleNewMedicine => 'إضافة دواء جديد';

  @override
  String get formType => '🗂️ النوع';

  @override
  String get formBarcode => '📊 الباركود';

  @override
  String get formBarcodeHint => 'أدخل الباركود يدوياً أو امسحه';

  @override
  String get formNoBarcode => 'ليس لها باركود';

  @override
  String get formLookingUp => 'جاري البحث عن معلومات الدواء...';

  @override
  String get formSupplyImage => '📷 صورة المستلزم';

  @override
  String get formMedicineImage => '📷 صورة الدواء';

  @override
  String get camera => 'كاميرا';

  @override
  String get gallery => 'معرض';

  @override
  String get formSupplyName => '🩹 اسم المستلزم *';

  @override
  String get formMedicineName => '💊 اسم الدواء *';

  @override
  String get formSupplyNameHint => 'أدخل اسم المستلزم';

  @override
  String get formMedicineNameHint => 'أدخل اسم الدواء';

  @override
  String get formNameRequired => 'الاسم مطلوب';

  @override
  String get formCompany => '🏭 اسم الشركة (اختياري)';

  @override
  String get formCompanyHint => 'مثل: Juman';

  @override
  String get formCategory => '🧪 نوع المادة (اختياري)';

  @override
  String get formCategoryHint => 'مثل: Tablet، Cream، Syrup…';

  @override
  String formPrice(String currency) {
    return '💰 السعر ($currency)';
  }

  @override
  String get formQuantity => '📦 الكمية';

  @override
  String get formExpiry => '📅 تاريخ الصلاحية (اختياري)';

  @override
  String get notSet => 'غير محدد';

  @override
  String get saveChanges => 'حفظ التعديلات';

  @override
  String get saveSupply => 'حفظ المستلزم';

  @override
  String get saveMedicine => 'حفظ الدواء';

  @override
  String chipExpiry(String date) {
    return '📅 الصلاحية: $date';
  }

  @override
  String chipBatch(String batch) {
    return '🏷️ وجبة: $batch';
  }

  @override
  String get settingsTitle => '⚙️ الإعدادات';

  @override
  String get settingsTooltip => 'الإعدادات';

  @override
  String get settingsAlerts => 'تنبيهات الصلاحية والمخزون';

  @override
  String get settingsAlertsSub =>
      'إشعار يومي الساعة 9 صباحاً إذا كانت هناك مواد منتهية أو قاربت الانتهاء أو مخزون منخفض/نافد.';

  @override
  String get settingsContribute => 'المساهمة في القاموس المشترك';

  @override
  String get settingsContributeSub =>
      'إرسال اسم الدواء وصورته فقط عند حفظه، لمساعدة بقية الصيدليات على التعرف عليه.';

  @override
  String get settingsSent => '✅ يُرسَل';

  @override
  String get settingsSentWhat => 'الباركود + اسم الدواء + صورة مصغّرة';

  @override
  String get settingsNotSent => '🔒 لا يُرسَل';

  @override
  String get settingsNotSentWhat => 'السعر • الكمية • اسم صيدليتك • موقعك';

  @override
  String get settingsContributing =>
      'أنت تساهم حالياً — شكراً، هذا ما يجعل القاموس ينمو.';

  @override
  String get settingsNotContributing =>
      'المساهمة موقوفة. ستبقى تستفيد من القاموس عند المسح، لكن أدويتك لن تُضاف إليه.';

  @override
  String get settingsShowWelcome => 'عرض شاشة الترحيب';

  @override
  String get backupTitle => '💾 النسخة الاحتياطية';

  @override
  String get backupSub =>
      'ملف يحفظ كل المواد. عند الحفظ أرسله إلى واتساب أو Drive أو التنزيلات — إلغاء التثبيت يمسح ما بداخل التطبيق ويغيّر هوية المزامنة.';

  @override
  String get backupSave => 'حفظ نسخة';

  @override
  String get backupRestore => 'استرجاع';

  @override
  String get syncIdCopied => 'نُسخ معرّف المزامنة';

  @override
  String get syncDisabled => 'المزامنة غير مفعّلة';

  @override
  String syncId(String id) {
    return 'معرّف المزامنة: $id… (اضغط للنسخ)';
  }

  @override
  String get backupWhereToSave =>
      'اختر أين تحفظ النسخة: واتساب، Drive، أو التنزيلات';

  @override
  String saveFailed(String error) {
    return 'تعذّر الحفظ: $error';
  }

  @override
  String restoreFailed(String error) {
    return 'تعذّر الاسترجاع: $error';
  }

  @override
  String get restoreFromWhere => 'استرجاع من أين؟';

  @override
  String get restorePickFile => 'اختيار ملف…';

  @override
  String get restoreLastLocal => 'آخر نسخة على هذا الجهاز';

  @override
  String get restoreTitle => 'استرجاع النسخة';

  @override
  String restoreContainsItems(int n) {
    return 'الملف يحتوي $n مادة';
  }

  @override
  String restoreAndInvoices(int n) {
    return ' و$n فاتورة';
  }

  @override
  String get restoreNote =>
      'سيُضاف الجديد ويُحدَّث الأقدم — لا يُحذف شيء موجود.';

  @override
  String get restoreConfirm => 'استرجع';

  @override
  String restoreResult(int added, int updated, int skipped) {
    return 'أُضيف $added · حُدّث $updated · بلا تغيير $skipped';
  }

  @override
  String get sharingTitle => '🔗 مشاركة المخزون بين الأجهزة';

  @override
  String get sharingSub =>
      'اربط هاتف زميل أو مساعدك بنفس المخزون — أي تعديل من أي جهاز يظهر للجميع.';

  @override
  String get shareWithDevice => 'مشاركة مع جهاز آخر';

  @override
  String get joinInventory => 'الانضمام إلى مخزون';

  @override
  String get linkedDevices => 'الأجهزة المرتبطة';

  @override
  String get reviewDuplicates => 'مراجعة التكرارات';

  @override
  String invoicesCount(int n) {
    return 'الفواتير ($n)';
  }

  @override
  String get pairPrepareFailed => 'تعذّر التحضير — تحقق من الاتصال بالإنترنت.';

  @override
  String get pairCodeFailed => 'تعذّر توليد رمز — حاول مرة أخرى.';

  @override
  String get pairRequestFailed => 'تعذّر إتمام الطلب — حاول مرة أخرى.';

  @override
  String get pairShareTitle => '🔗 مشاركة المخزون مع جهاز آخر';

  @override
  String get pairShareSub =>
      'أعطِ هذا الرمز للجهاز الآخر — صالح لمدة 10 دقائق. بعد إدخاله هناك، وافِق على الطلب هنا ليصبح المخزون مشتركاً بين الجهازين.';

  @override
  String get unknownError => 'خطأ غير معروف';

  @override
  String get tryAgain => 'حاول مرة أخرى';

  @override
  String get pairWaiting => 'بانتظار الجهاز الآخر…';

  @override
  String get pairApproveHint =>
      'وافق فقط إن كان الجهاز أمامك الآن وأنت من أعطاه الرمز.';

  @override
  String get approve => 'موافقة';

  @override
  String get decline => 'رفض';

  @override
  String get pairDone => 'تم! المخزون مشترك الآن.';

  @override
  String get done => 'تم';

  @override
  String get pairCodeExpired => 'انتهت صلاحية الرمز.';

  @override
  String get pairNewCode => 'توليد رمز جديد';

  @override
  String get pairEnterCode => 'أدخل الرمز المكوّن من 6 أرقام.';

  @override
  String get pairCodeWrong => 'الرمز غير صحيح.';

  @override
  String get pairCodeExpiredAsk => 'انتهت صلاحية الرمز، اطلب رمزاً جديداً.';

  @override
  String get pairCodeUsed => 'هذا الرمز استُخدم من قبل.';

  @override
  String get pairConnectFailed =>
      'تعذّر الاتصال — تحقق من الإنترنت وحاول مرة أخرى.';

  @override
  String get pairJoined => 'تم الانضمام! جاري تنزيل المخزون…';

  @override
  String get pairJoinTitle => '🔗 الانضمام إلى مخزون موجود';

  @override
  String get pairJoinSub =>
      'أدخل الرمز الظاهر على الجهاز الذي يملك المخزون حالياً.';

  @override
  String get join => 'انضمام';

  @override
  String get pairApproved => 'تمت الموافقة! جاري تنزيل المخزون…';

  @override
  String get pairDeclined => 'تم رفض الطلب من الجهاز الآخر.';

  @override
  String get pairExpiredBeforeApproval =>
      'انتهت صلاحية الرمز قبل أن يوافق الجهاز الآخر.';

  @override
  String get pairSentWaiting => 'تم الإرسال — بانتظار موافقة الجهاز الآخر…';

  @override
  String get pairPromptUnknown => 'جهاز آخر يطلب الانضمام — هل توافق؟';

  @override
  String pairPromptDevice(String id) {
    return 'الجهاز $id يطلب الانضمام — هل توافق؟';
  }

  @override
  String get devicesLoadFailed => 'تعذّر التحميل — تحقق من الإنترنت.';

  @override
  String get removeDeviceTitle => 'إخراج الجهاز؟';

  @override
  String removeDeviceBody(String id) {
    return 'الجهاز $id لن يرى المخزون ولن يعدّله بعد الآن. ما على هاتفه من نسخة محلية يبقى عنده.';
  }

  @override
  String get remove => 'إخراج';

  @override
  String removeFailed(String error) {
    return 'تعذّر الإخراج: $error';
  }

  @override
  String get devicesTitle => '📱 الأجهزة المرتبطة';

  @override
  String get devicesSub =>
      'كل جهاز هنا يرى المخزون بأسعاره وكمياته ويعدّله. أخرج أي جهاز لا تعرفه.';

  @override
  String deviceName(String id) {
    return 'جهاز $id';
  }

  @override
  String get deviceOwner => 'صاحب المخزون';

  @override
  String get deviceThisPhone => 'هذا الهاتف';

  @override
  String dupLoadFailed(String error) {
    return 'تعذّر تحميل المواد: $error';
  }

  @override
  String dupMergeFailed(String error) {
    return 'تعذّر الدمج — لم يتغيّر شيء: $error';
  }

  @override
  String dupSplitFailed(String error) {
    return 'تعذّر فصل الباركود: $error';
  }

  @override
  String get dupTitle => '🔍 مراجعة التكرارات';

  @override
  String get refresh => 'تحديث';

  @override
  String get dupNone => 'لا توجد تكرارات ✅';

  @override
  String dupGroupsIntro(int n) {
    return '$n مجموعة — علّم ما هو نفس المنتج ثم «دمج المختارة»، أو «ليست مكرّرة» إن كانت كلها منتجات مختلفة.';
  }

  @override
  String dupSimilarIntro(int n) {
    return '🔍 أسماء متشابهة — تحقّق قبل الدمج ($n)\nأسماء متقاربة لا متطابقة: خطأ إملائي، أو كلمة زائدة، أو حجم وتركيز آخر. كثير منها منتجات مختلفة فعلاً — «ليست مكرّرة» يخفيها من كل الأجهزة.';
  }

  @override
  String dupShowHidden(int n) {
    return 'إظهار المخفية ($n)';
  }

  @override
  String get dupShowHiddenTitle => 'إظهار المجموعات المخفية';

  @override
  String dupShowHiddenBody(int n) {
    return 'ستعود $n مجموعة للمراجعة على كل الأجهزة. المواد لا تتغيّر.';
  }

  @override
  String get show => 'إظهار';

  @override
  String dupMergePaused(int n) {
    return 'الدمج متوقف: $n عملية حذف لم تصل للسحابة بعد. الدمج يجمع الكميات ويحذف الباقي، فإن لم يصل الحذف تبقى المواد على الهاتف الآخر وتتضاعف الكمية. اتصل بالإنترنت ثم اضغط تحديث.';
  }

  @override
  String dupSimilarPercent(int p) {
    return '🔍 أسماء متشابهة بنسبة $p%';
  }

  @override
  String get dupSameBarcode => '🏷️ نفس الباركود — قد تكون منتجات مختلفة';

  @override
  String get dupSameName => '📝 نفس الاسم في نفس القسم';

  @override
  String get dupDifferentBarcodes =>
      '🏷️ باركودان مختلفان — تأكّد أنها ليست حجماً أو نكهة أخرى';

  @override
  String get dupTickHint =>
      'علّم المواد التي هي نفس المنتج ثم «دمج المختارة» — غير المعلّمة تبقى كما هي وتُزال من المراجعة.';

  @override
  String get dupPickTwo => 'اختر مادتين للدمج';

  @override
  String dupMergeSelected(int n, int total) {
    return 'دمج المختارة ($n) · الكمية $total';
  }

  @override
  String get dupNotDuplicates => 'ليست مكرّرة';

  @override
  String get dupSplitBarcode => 'فصل الباركود';

  @override
  String detQty(int n) {
    return 'الكمية $n';
  }

  @override
  String detPrice(String v) {
    return 'السعر $v';
  }

  @override
  String detExpiry(String d) {
    return 'الصلاحية $d';
  }

  @override
  String detEdited(String d) {
    return 'عُدّلت $d';
  }

  @override
  String dupMergeTitle(int n) {
    return 'دمج $n مواد';
  }

  @override
  String get dupKeptName => 'الاسم الذي يبقى';

  @override
  String dupFinalPrice(String currency) {
    return '💰 السعر النهائي ($currency)';
  }

  @override
  String get dupFinalQty => '📦 الكمية النهائية';

  @override
  String dupWillDelete(int n) {
    return 'تُحذف $n مادة من هذا الهاتف ومن كل الأجهزة المشتركة.';
  }

  @override
  String get cdBarcodeTaken =>
      'هذا الباركود مسجّل لمادة أخرى — استعمل «دمج» إن كانت هي نفسها';

  @override
  String cdMergeWith(String name) {
    return 'دمج مع «$name»';
  }

  @override
  String cdMergeBody(String keep, int qty, String drop) {
    return 'تبقى «$keep» بكمية $qty، وتُحذف «$drop» من كل الأجهزة. ينتقل إليها الباركود والصورة إن لم يكونا لها.';
  }

  @override
  String get cdMergeConfirm => 'ادمج';

  @override
  String get cdDeleteTitle => 'حذف المادة';

  @override
  String cdDeleteBody(String name) {
    return 'تُحذف «$name» من هذا الهاتف ومن كل الأجهزة المشتركة.';
  }

  @override
  String get cdDeleteConfirm => 'احذف';

  @override
  String get cdTitle => '📝 إكمال البيانات';

  @override
  String get cdNoneInSection => 'لا مواد ناقصة في هذا القسم';

  @override
  String cdListDone(int n) {
    return 'انتهت القائمة — اكتملت $n مادة';
  }

  @override
  String get back => 'رجوع';

  @override
  String cdProgress(int i, int n) {
    return 'مادة $i من $n';
  }

  @override
  String get cdNoPrice => 'بلا سعر';

  @override
  String get cdNoBarcode => 'بلا باركود';

  @override
  String cdSimilar(int p) {
    return '🔍 تشبه مادة موجودة ($p%)';
  }

  @override
  String cdMatchLine(String price, int qty) {
    return 'السعر $price · الكمية $qty';
  }

  @override
  String get cdSameMerge => 'هي نفسها — دمج معها';

  @override
  String cdPrice(String currency) {
    return '💰 السعر ($currency)';
  }

  @override
  String get cdQty => '📦 الكمية';

  @override
  String get cdBarcode => '📊 الباركود';

  @override
  String get scanTheBarcode => 'مسح الباركود';

  @override
  String get cdNoBarcodeSub =>
      'تحضير أو علبة بلا رمز — لن تُعدّ ناقصة بسبب الباركود';

  @override
  String get takePhoto => 'تصوير';

  @override
  String get theGallery => 'المعرض';

  @override
  String get cdSaveNext => 'حفظ والتالي';

  @override
  String get invTitle => '📚 الفواتير';

  @override
  String get invSearchHint => 'ابحث باسم المجهّز أو رقم الفاتورة…';

  @override
  String invSummary(int n, String total) {
    return '$n فاتورة · المجموع $total';
  }

  @override
  String get invEmpty =>
      'لا فواتير محفوظة بعد — تُحفظ تلقائياً من «فاتورة ذكية»';

  @override
  String invItems(int n) {
    return '$n مادة';
  }

  @override
  String invNumberShort(String n) {
    return ' · رقم $n';
  }

  @override
  String get invDeleteTitle => 'حذف الفاتورة';

  @override
  String get invDeleteBody =>
      'يُحذف سجل الفاتورة وصورها من كل الأجهزة. المخزون لا يتغيّر — الكميات التي أضافتها تبقى.';

  @override
  String get invoice => 'فاتورة';

  @override
  String get invDeleteRecord => 'حذف السجل';

  @override
  String get invPhotoElsewhere => '📷 صورة الفاتورة على الهاتف الذي صوّرها';

  @override
  String get invPhotoFailed => 'تعذّر عرض الصورة';

  @override
  String get invRowSupplier => '🏪 المجهّز';

  @override
  String get invRowDate => '📅 التاريخ';

  @override
  String get invRowNumber => '🔢 الرقم';

  @override
  String get invRowTotal => '💰 مجموع الفاتورة';

  @override
  String get invRowLinesTotal => '🧮 مجموع الأسطر';

  @override
  String get invLineMerged => '🔁 أُضيفت لموجودة';

  @override
  String get invLineNew => '🆕 جديدة';

  @override
  String get scanAim => '🎯 وجّه الكاميرا نحو باركود الدواء';

  @override
  String get camDenied =>
      'لم يتم منح إذن الكاميرا.\nافتح إعدادات التطبيق وفعّل الكاميرا.';

  @override
  String get camUnsupported => 'الكاميرا غير مدعومة على هذا الجهاز.';

  @override
  String camFailed(String details) {
    return 'تعذّر تشغيل الكاميرا.\n$details';
  }

  @override
  String get cropTitle => 'قصّ الصورة';

  @override
  String get cropReset => 'إعادة الضبط';

  @override
  String get cropNone => 'بلا قص';

  @override
  String get scReplaceTitle => 'استبدال الصفحة؟';

  @override
  String scReplaceBody(int n) {
    return 'ستُحذف $n سطراً مقروءاً من الصفحة الحالية وتُقرأ الصورة الجديدة مكانها.';
  }

  @override
  String get scReplace => 'استبدال';

  @override
  String get scNoValidLines => 'لا توجد أسطر صالحة للحفظ.';

  @override
  String get scRecordFailed => 'حُفظت المواد، وتعذّر حفظ سجل الفاتورة';

  @override
  String get scLeaveTitle => 'الخروج بلا حفظ؟';

  @override
  String scLeaveBody(int n) {
    return 'ستضيع $n سطراً مقروءاً من هذه الفاتورة.';
  }

  @override
  String get scStay => 'البقاء';

  @override
  String get scLeave => 'خروج بلا حفظ';

  @override
  String get scTitle => '🧾 فاتورة ذكية';

  @override
  String get scSavedInvoices => 'الفواتير المحفوظة';

  @override
  String scSaveN(int n) {
    return 'حفظ ($n)';
  }

  @override
  String get scEmptyTitle => 'صوّر الفاتورة أو اخترها من المعرض';

  @override
  String get scEmptySub =>
      'تُقرأ أسطر الصفحة وتُملأ الحقول تلقائياً (الاسم، الكمية، السعر، الصلاحية) لتراجعها قبل الحفظ.';

  @override
  String scReadFailed(String error) {
    return 'تعذّرت قراءة الصفحة: $error\nاضغط «إعادة المحاولة» على الصفحة.';
  }

  @override
  String get scFallbackModel =>
      '⚡ قُرئت بالنموذج البديل (النموذج الأساسي غير متاح الآن) — راجع الأسطر بانتباه';

  @override
  String get scReading =>
      'جاري قراءة الفاتورة… قد تستغرق حتى دقيقة للصفحات الكثيفة';

  @override
  String get scNoLines => 'لم تُقرأ أي أسطر بعد';

  @override
  String get scHeader => '🧾 بيانات الفاتورة';

  @override
  String get scSupplier => '🏪 المجهّز';

  @override
  String get scNumber => 'رقم الفاتورة';

  @override
  String get scDate => '📅 التاريخ';

  @override
  String scTotal(String currency) {
    return '💰 مجموع الفاتورة ($currency)';
  }

  @override
  String scLinesTotal(String total) {
    return 'مجموع الأسطر: $total';
  }

  @override
  String scPrinted(String total) {
    return ' · المطبوع: $total';
  }

  @override
  String get scTotalsDiffer => '⚠️ المجموعان مختلفان — راجع الكميات والأسعار';

  @override
  String get scRetake => 'تصوير من جديد';

  @override
  String get scFromGallery => 'من المعرض';

  @override
  String get scDeletePage => 'حذف الصفحة';

  @override
  String get scRetry => 'إعادة المحاولة';

  @override
  String get close => 'إغلاق';

  @override
  String scLinesSummary(int total, int fresh, int existing) {
    return '$total سطراً · $fresh جديدة · $existing ستُضاف لمخزون موجود';
  }

  @override
  String scNeedReview(int n) {
    return ' · $n تحتاج مراجعة';
  }

  @override
  String get scFlaggedOnly => 'المشكوك فيها فقط';

  @override
  String get scAllLinesType => 'نوع كل الأسطر:';

  @override
  String get scName => 'الاسم';

  @override
  String get scCostPrice => 'السعر (كلفة)';

  @override
  String get scQty => 'الكمية';

  @override
  String scBonus(int n) {
    return '+$n مجاناً';
  }

  @override
  String get scExpiry => 'الصلاحية (مثل 2027-11)';

  @override
  String get scBarcodeOpt => 'الباركود (اختياري)';

  @override
  String scExisting(String name, int qty) {
    return '🔁 موجودة مسبقاً («$name») — الرصيد $qty، سيُضاف الوارد إليه';
  }

  @override
  String get scDuplicateLine =>
      '🔗 مكرر مع سطر آخر في هذه الفاتورة — سيُدمجان تلقائياً';

  @override
  String get issueInvalidBarcode => 'باركود غير صالح — حُذف';

  @override
  String get issueTotalMismatch => 'الكمية × السعر ≠ المجموع';

  @override
  String get issueMissingPrice => 'السعر ناقص';

  @override
  String get issueMissingQty => 'الكمية ناقصة';

  @override
  String get issueUncertain => 'غير واضح في الصورة';

  @override
  String get issueSuspiciousPrice => '⚠️ السعر غير منطقي — راجعه';

  @override
  String gmImageReadFailed(String error) {
    return 'تعذّرت قراءة ملف الصورة: $error';
  }

  @override
  String get gmNotConfigured =>
      'قراءة الفاتورة غير مفعّلة — لم يُضبط مفتاح Gemini في ملف .env.';

  @override
  String gmTooLarge(int mb) {
    return 'الصورة أكبر من $mb ميجابايت — جرّب صورة أخفّ.';
  }

  @override
  String get gmTimeout =>
      'استغرقت القراءة وقتاً طويلاً — أعد المحاولة، أو صوّر الصفحة على جزأين إن كانت طويلة جداً.';

  @override
  String get gmNoInternet => 'لا يوجد اتصال بالإنترنت.';

  @override
  String gmConnectFailed(String error) {
    return 'تعذّر الاتصال بخدمة القراءة: $error';
  }

  @override
  String gmUnexpected(String error) {
    return 'خطأ غير متوقع: $error';
  }

  @override
  String get gmEmpty => 'لم تُرجع الخدمة أي محتوى.';

  @override
  String get gmCutOff => 'الصفحة طويلة جداً فانقطع الرد — صوّرها على جزأين.';

  @override
  String gmBadReply(String error) {
    return 'تعذّر فهم ردّ الخدمة: $error';
  }

  @override
  String gmBadLines(String error) {
    return 'تعذّر فهم صيغة الأسطر: $error';
  }

  @override
  String gmQuota(String when) {
    return 'انتهت القراءات المجانية لهذا اليوم (حدّ Google المجاني) — $when.';
  }

  @override
  String get gmQuotaTomorrow => 'تتجدد غداً';

  @override
  String gmQuotaIn(String duration) {
    return 'تتجدد بعد نحو $duration';
  }

  @override
  String durMinutes(int n) {
    return '$n دقيقة';
  }

  @override
  String durHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ساعات',
      two: 'ساعتين',
      one: 'ساعة',
    );
    return '$_temp0';
  }

  @override
  String durHoursMinutes(String hours, String minutes) {
    return '$hours و$minutes';
  }

  @override
  String get gmTooMany =>
      'طلبات كثيرة على خدمة القراءة — انتظر قليلاً ثم أعد المحاولة.';

  @override
  String get gmBusy =>
      'خدمة Google مزدحمة حالياً — انتظر دقيقة ثم اضغط «إعادة المحاولة».';

  @override
  String gmStatus(int code, String reason) {
    return 'Gemini استجاب $code: $reason';
  }

  @override
  String get notifChannel => 'تنبيهات المخزون';

  @override
  String get notifChannelDesc => 'الصلاحية والمخزون المنخفض';

  @override
  String notifExpired(int n) {
    return '$n منتهية الصلاحية';
  }

  @override
  String notifExpiring(int n) {
    return '$n تقترب من الانتهاء';
  }

  @override
  String notifOut(int n) {
    return '$n نفدت من المخزون';
  }

  @override
  String notifLow(int n) {
    return '$n منخفضة المخزون';
  }

  @override
  String get notifTitle => '🔔 صيدليتي — يحتاج مراجعة';

  @override
  String invoiceLabel(String when) {
    return '🧾 فاتورة $when';
  }

  @override
  String invoiceLabelFrom(String date) {
    return '🧾 من فاتورة بتاريخ $date';
  }

  @override
  String get authNoIdentity => 'تعذّر إنشاء هوية الجهاز';

  @override
  String get authAnonDisabled =>
      'المصادقة المجهولة غير مفعّلة في Firebase.\nالحل: Console ← Authentication ← Sign-in method ← Anonymous ← Enable.';

  @override
  String get authOffline => 'لا يوجد اتصال — المزامنة موقوفة مؤقتاً.';

  @override
  String authFailed(String error) {
    return 'تعذّرت المصادقة: $error';
  }

  @override
  String get backupSubject => 'نسخة احتياطية — صيدليتي';

  @override
  String get backupNotFound => 'الملف غير موجود';

  @override
  String backupReadFailed(String error) {
    return 'تعذّرت قراءة الملف: $error';
  }

  @override
  String get backupInvalid => 'الملف ليس نسخة احتياطية صالحة';

  @override
  String get backupNoItems => 'الملف لا يحتوي مواد';

  @override
  String get lookupLocal => 'قاعدتك المحلية';

  @override
  String get lookupRegistry => 'قاموس الصيدليات المشترك';

  @override
  String barcodeConflict(String barcode) {
    return 'الباركود $barcode مسجَّل لمادة أخرى';
  }

  @override
  String get phSyncOff => 'المزامنة غير مفعّلة';

  @override
  String get phOwnerOnly => 'فقط صاحب المخزون يُخرج الأجهزة';

  @override
  String get phCantRemoveOwner => 'لا يمكن إخراج صاحب المخزون';

  @override
  String get phNotMember => 'الجهاز ليس عضواً';

  @override
  String get alertsTitle => '🔔 التنبيهات';

  @override
  String get alertsTooltip => 'التنبيهات';

  @override
  String alertsSecExpired(int n) {
    return '⛔ منتهية الصلاحية ($n)';
  }

  @override
  String alertsSecUrgent(int n) {
    return '⏳ تنتهي خلال شهر ($n)';
  }

  @override
  String alertsSecOut(int n) {
    return '🚫 نافدة ($n)';
  }

  @override
  String alertsSecLow(int n) {
    return '⚠️ مخزون منخفض ($n)';
  }

  @override
  String alertsSecSoon(int n) {
    return '🕐 تنتهي خلال 3 أشهر ($n)';
  }

  @override
  String get alertOutDetail => 'نفدت من المخزون';

  @override
  String alertLowDetail(int qty, int min) {
    return 'الكمية $qty — حد التنبيه $min';
  }

  @override
  String get alertDone => 'تمّ';

  @override
  String get alertRestore => 'إرجاع';

  @override
  String get alertHidden => 'أُخفي التنبيه';

  @override
  String alertsShowHidden(int n) {
    return 'إظهار المخفية ($n)';
  }

  @override
  String get alertsHideHidden => 'إخفاء المخفية';

  @override
  String get alertsEmpty => '✅ لا تنبيهات — كل شيء سليم';

  @override
  String get alertsEmptySub =>
      'تظهر هنا المواد المنتهية وقاربة الانتهاء والنافدة والمنخفضة';

  @override
  String alertsBellCount(int n) {
    return '$n تنبيه';
  }

  @override
  String notifNewTitle(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n تنبيه جديد',
      many: '$n تنبيهاً جديداً',
      few: '$n تنبيهات جديدة',
      two: 'تنبيهان جديدان',
      one: 'تنبيه جديد',
    );
    return '🔔 $_temp0';
  }

  @override
  String get notifWeeklyTitle => '📋 ملخّص الأسبوع — صيدليتي';

  @override
  String notifLineExpired(String name) {
    return '⛔ $name — انتهت';
  }

  @override
  String notifLineUrgent(String name, int n) {
    return '⏳ $name — $n يوماً';
  }

  @override
  String notifLineToday(String name) {
    return '⏳ $name — تنتهي اليوم';
  }

  @override
  String notifLineOut(String name) {
    return '🚫 $name — نفدت';
  }

  @override
  String notifLineLow(String name, int n) {
    return '⚠️ $name — بقي $n';
  }

  @override
  String notifLineSoon(String name, int n) {
    return '🕐 $name — $n يوماً';
  }

  @override
  String notifMore(int n) {
    return 'و$n أخرى';
  }

  @override
  String get formMinQty => '🔔 حد التنبيه (اختياري)';

  @override
  String formMinQtyHint(int n) {
    return 'الافتراضي $n';
  }

  @override
  String get settingsLowStock => 'حد المخزون المنخفض الافتراضي';

  @override
  String get settingsLowStockSub =>
      'تُنبَّه حين تصل الكمية إليه — لكل المواد بلا حد خاص، ومشترك بين أجهزة الصيدلية.';
}
