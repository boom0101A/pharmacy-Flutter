import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @settingsLanguageCurrency.
  ///
  /// In ar, this message translates to:
  /// **'🌐 اللغة والعملة'**
  String get settingsLanguageCurrency;

  /// No description provided for @languageLabel.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get languageLabel;

  /// No description provided for @currencyLabel.
  ///
  /// In ar, this message translates to:
  /// **'العملة'**
  String get currencyLabel;

  /// No description provided for @currencyIqd.
  ///
  /// In ar, this message translates to:
  /// **'دينار'**
  String get currencyIqd;

  /// No description provided for @currencyUsd.
  ///
  /// In ar, this message translates to:
  /// **'دولار'**
  String get currencyUsd;

  /// No description provided for @usdRateLine.
  ///
  /// In ar, this message translates to:
  /// **'1 \$ = {rate} د.ع'**
  String usdRateLine(String rate);

  /// No description provided for @usdRateEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل سعر الصرف'**
  String get usdRateEdit;

  /// No description provided for @usdRateTitle.
  ///
  /// In ar, this message translates to:
  /// **'سعر صرف الدولار'**
  String get usdRateTitle;

  /// No description provided for @usdRateHint.
  ///
  /// In ar, this message translates to:
  /// **'كم ديناراً للدولار الواحد؟ (سعر السوق الذي تتعامل به)'**
  String get usdRateHint;

  /// No description provided for @usdRateField.
  ///
  /// In ar, this message translates to:
  /// **'1 دولار = … دينار'**
  String get usdRateField;

  /// No description provided for @usdRateInvalid.
  ///
  /// In ar, this message translates to:
  /// **'اكتب سعراً أكبر من صفر'**
  String get usdRateInvalid;

  /// No description provided for @currencyNote.
  ///
  /// In ar, this message translates to:
  /// **'الأسعار تُحفظ وتُزامَن بالدينار دائماً؛ الدولار للعرض والإدخال فقط. الفاتورة الذكية وسجل الفواتير بالدينار.'**
  String get currencyNote;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'صيدليتي'**
  String get appName;

  /// No description provided for @splashTagline.
  ///
  /// In ar, this message translates to:
  /// **'مخزونك الدوائي… أذكى وأبسط'**
  String get splashTagline;

  /// No description provided for @splashVersion.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار {version} · مزامنة سحابية آمنة'**
  String splashVersion(String version);

  /// No description provided for @splashLoading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحميل'**
  String get splashLoading;

  /// No description provided for @splashProgress.
  ///
  /// In ar, this message translates to:
  /// **'تحميل'**
  String get splashProgress;

  /// No description provided for @welcomeSkip.
  ///
  /// In ar, this message translates to:
  /// **'تخطّي'**
  String get welcomeSkip;

  /// No description provided for @welcomeNext.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get welcomeNext;

  /// No description provided for @welcomeStart.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الآن'**
  String get welcomeStart;

  /// No description provided for @welcomeSlideLabel.
  ///
  /// In ar, this message translates to:
  /// **'الشريحة {n}'**
  String welcomeSlideLabel(int n);

  /// No description provided for @welcome1ChipA.
  ///
  /// In ar, this message translates to:
  /// **'Panadol · 24 علبة'**
  String get welcome1ChipA;

  /// No description provided for @welcome1ChipB.
  ///
  /// In ar, this message translates to:
  /// **'تم التعرّف تلقائياً'**
  String get welcome1ChipB;

  /// No description provided for @welcome1Title.
  ///
  /// In ar, this message translates to:
  /// **'امسح الباركود '**
  String get welcome1Title;

  /// No description provided for @welcome1Accent.
  ///
  /// In ar, this message translates to:
  /// **'وأضف بثانية'**
  String get welcome1Accent;

  /// No description provided for @welcome1Body.
  ///
  /// In ar, this message translates to:
  /// **'وجّه الكاميرا نحو العلبة، ويتعرّف التطبيق على الدواء من القاموس المشترك بين الصيدليات.'**
  String get welcome1Body;

  /// No description provided for @welcome2ChipA.
  ///
  /// In ar, this message translates to:
  /// **'قراءة ذكية للفاتورة'**
  String get welcome2ChipA;

  /// No description provided for @welcome2ChipB.
  ///
  /// In ar, this message translates to:
  /// **'12 سطراً أُضيفت'**
  String get welcome2ChipB;

  /// No description provided for @welcome2Title.
  ///
  /// In ar, this message translates to:
  /// **'صوّر الفاتورة '**
  String get welcome2Title;

  /// No description provided for @welcome2Accent.
  ///
  /// In ar, this message translates to:
  /// **'والباقي علينا'**
  String get welcome2Accent;

  /// No description provided for @welcome2Body.
  ///
  /// In ar, this message translates to:
  /// **'الفاتورة الذكية تقرأ الأسماء والأسعار والكميات، وتنبّهك على أي سطر مشكوك فيه قبل الحفظ.'**
  String get welcome2Body;

  /// No description provided for @welcome3ChipA.
  ///
  /// In ar, this message translates to:
  /// **'3 أدوية قاربت الانتهاء'**
  String get welcome3ChipA;

  /// No description provided for @welcome3ChipB.
  ///
  /// In ar, this message translates to:
  /// **'جهازان متزامنان'**
  String get welcome3ChipB;

  /// No description provided for @welcome3Title.
  ///
  /// In ar, this message translates to:
  /// **'مخزون واحد '**
  String get welcome3Title;

  /// No description provided for @welcome3Accent.
  ///
  /// In ar, this message translates to:
  /// **'على كل أجهزتك'**
  String get welcome3Accent;

  /// No description provided for @welcome3Body.
  ///
  /// In ar, this message translates to:
  /// **'مزامنة سحابية فورية مع زملائك، وتنبيهات للصلاحية والمخزون المنخفض قبل أن تتفاجأ.'**
  String get welcome3Body;

  /// No description provided for @typeMedicine.
  ///
  /// In ar, this message translates to:
  /// **'💊 دواء'**
  String get typeMedicine;

  /// No description provided for @typeSupply.
  ///
  /// In ar, this message translates to:
  /// **'🩹 مستلزم طبي'**
  String get typeSupply;

  /// No description provided for @homeTitle.
  ///
  /// In ar, this message translates to:
  /// **'💊 صيدليتي'**
  String get homeTitle;

  /// No description provided for @priceRepaired.
  ///
  /// In ar, this message translates to:
  /// **'صُحّح سعر {n} مادة قرأتها الفاتورة الذكية خطأً'**
  String priceRepaired(int n);

  /// No description provided for @invoiceAddedNew.
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت {n} مادة جديدة'**
  String invoiceAddedNew(int n);

  /// No description provided for @invoiceMerged.
  ///
  /// In ar, this message translates to:
  /// **'دُمجت {n} مع مواد موجودة مسبقاً'**
  String invoiceMerged(int n);

  /// No description provided for @invoiceMergedWithin.
  ///
  /// In ar, this message translates to:
  /// **'({n} منها مكرَّر داخل الفاتورة نفسها)'**
  String invoiceMergedWithin(int n);

  /// No description provided for @deletedItem.
  ///
  /// In ar, this message translates to:
  /// **'🗑️ حُذف \"{name}\"'**
  String deletedItem(String name);

  /// No description provided for @undo.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get undo;

  /// No description provided for @incompleteBanner.
  ///
  /// In ar, this message translates to:
  /// **'{n} مادة بياناتها ناقصة'**
  String incompleteBanner(int n);

  /// No description provided for @completeData.
  ///
  /// In ar, this message translates to:
  /// **'إكمال البيانات'**
  String get completeData;

  /// No description provided for @scanBarcode.
  ///
  /// In ar, this message translates to:
  /// **'مسح باركود'**
  String get scanBarcode;

  /// No description provided for @smartInvoice.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة ذكية'**
  String get smartInvoice;

  /// No description provided for @add.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get add;

  /// No description provided for @statMedicines.
  ///
  /// In ar, this message translates to:
  /// **'عدد الأدوية'**
  String get statMedicines;

  /// No description provided for @statSupplies.
  ///
  /// In ar, this message translates to:
  /// **'عدد المستلزمات'**
  String get statSupplies;

  /// No description provided for @statTotalValue.
  ///
  /// In ar, this message translates to:
  /// **'القيمة الإجمالية ({currency})'**
  String statTotalValue(String currency);

  /// No description provided for @statValueMissing.
  ///
  /// In ar, this message translates to:
  /// **'القيمة ({n} بلا سعر)'**
  String statValueMissing(int n);

  /// No description provided for @searchSupplies.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في المستلزمات بالاسم...'**
  String get searchSupplies;

  /// No description provided for @searchMedicines.
  ///
  /// In ar, this message translates to:
  /// **'ابحث بالاسم أو الباركود...'**
  String get searchMedicines;

  /// No description provided for @scanInSearch.
  ///
  /// In ar, this message translates to:
  /// **'مسح باركود في البحث'**
  String get scanInSearch;

  /// No description provided for @filters.
  ///
  /// In ar, this message translates to:
  /// **'الفلاتر'**
  String get filters;

  /// No description provided for @quickFilter.
  ///
  /// In ar, this message translates to:
  /// **'📌 فلترة سريعة'**
  String get quickFilter;

  /// No description provided for @filterExpiring.
  ///
  /// In ar, this message translates to:
  /// **'⏳ قريبة الانتهاء'**
  String get filterExpiring;

  /// No description provided for @filterLowStock.
  ///
  /// In ar, this message translates to:
  /// **'⚠️ منخفض أو نافد (≤5)'**
  String get filterLowStock;

  /// No description provided for @filterIncomplete.
  ///
  /// In ar, this message translates to:
  /// **'📝 بيانات ناقصة ({n})'**
  String filterIncomplete(int n);

  /// No description provided for @filterNoBarcode.
  ///
  /// In ar, this message translates to:
  /// **'📊 بدون باركود'**
  String get filterNoBarcode;

  /// No description provided for @filterHasImage.
  ///
  /// In ar, this message translates to:
  /// **'📷 لديه صورة'**
  String get filterHasImage;

  /// No description provided for @filterNoImage.
  ///
  /// In ar, this message translates to:
  /// **'🖼️ بدون صورة'**
  String get filterNoImage;

  /// No description provided for @priceRange.
  ///
  /// In ar, this message translates to:
  /// **'💰 نطاق السعر ({currency})'**
  String priceRange(String currency);

  /// No description provided for @quantityRange.
  ///
  /// In ar, this message translates to:
  /// **'📦 نطاق الكمية'**
  String get quantityRange;

  /// No description provided for @sortBy.
  ///
  /// In ar, this message translates to:
  /// **'🔃 ترتيب حسب'**
  String get sortBy;

  /// No description provided for @sortNewest.
  ///
  /// In ar, this message translates to:
  /// **'🕐 الأحدث'**
  String get sortNewest;

  /// No description provided for @sortName.
  ///
  /// In ar, this message translates to:
  /// **'🔤 الاسم'**
  String get sortName;

  /// No description provided for @sortPrice.
  ///
  /// In ar, this message translates to:
  /// **'💲 السعر'**
  String get sortPrice;

  /// No description provided for @sortQuantity.
  ///
  /// In ar, this message translates to:
  /// **'📦 الكمية'**
  String get sortQuantity;

  /// No description provided for @resetFilters.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تعيين الفلاتر'**
  String get resetFilters;

  /// No description provided for @duplicatesBanner.
  ///
  /// In ar, this message translates to:
  /// **'{n, plural, =1{{n} مجموعة تكرار تحتاج مراجعة} other{{n} تكرارات تحتاج مراجعة}}'**
  String duplicatesBanner(int n);

  /// No description provided for @review.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة'**
  String get review;

  /// No description provided for @showingCountMedicines.
  ///
  /// In ar, this message translates to:
  /// **'عرض {shown} من أصل {total} دواء'**
  String showingCountMedicines(int shown, int total);

  /// No description provided for @showingCountSupplies.
  ///
  /// In ar, this message translates to:
  /// **'عرض {shown} من أصل {total} مستلزم'**
  String showingCountSupplies(int shown, int total);

  /// No description provided for @clearFilters.
  ///
  /// In ar, this message translates to:
  /// **'✕ مسح الفلاتر'**
  String get clearFilters;

  /// No description provided for @emptyNoResults.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نتائج مطابقة'**
  String get emptyNoResults;

  /// No description provided for @emptyNoSupplies.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مستلزمات بعد'**
  String get emptyNoSupplies;

  /// No description provided for @emptyNoMedicines.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أدوية بعد'**
  String get emptyNoMedicines;

  /// No description provided for @emptyTryFilters.
  ///
  /// In ar, this message translates to:
  /// **'جرّب تغيير البحث أو الفلاتر'**
  String get emptyTryFilters;

  /// No description provided for @emptyHintInvoice.
  ///
  /// In ar, this message translates to:
  /// **'اضغط «فاتورة ذكية» لإضافة موادها دفعة واحدة'**
  String get emptyHintInvoice;

  /// No description provided for @emptyHintAddSupply.
  ///
  /// In ar, this message translates to:
  /// **'اضغط «+» لإضافة أول مستلزم'**
  String get emptyHintAddSupply;

  /// No description provided for @emptyHintScan.
  ///
  /// In ar, this message translates to:
  /// **'اضغط «مسح باركود» للبدء'**
  String get emptyHintScan;

  /// No description provided for @syncAllGood.
  ///
  /// In ar, this message translates to:
  /// **'كل شيء يعمل بشكل سليم ✅'**
  String get syncAllGood;

  /// No description provided for @ok.
  ///
  /// In ar, this message translates to:
  /// **'حسناً'**
  String get ok;

  /// No description provided for @rangeFrom.
  ///
  /// In ar, this message translates to:
  /// **'من'**
  String get rangeFrom;

  /// No description provided for @rangeTo.
  ///
  /// In ar, this message translates to:
  /// **'إلى'**
  String get rangeTo;

  /// No description provided for @cardNoBarcode.
  ///
  /// In ar, this message translates to:
  /// **'بدون باركود'**
  String get cardNoBarcode;

  /// No description provided for @cardBarcode.
  ///
  /// In ar, this message translates to:
  /// **'باركود'**
  String get cardBarcode;

  /// No description provided for @price.
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get price;

  /// No description provided for @quantity.
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get quantity;

  /// No description provided for @cardIncomplete.
  ///
  /// In ar, this message translates to:
  /// **'📝 ناقصة'**
  String get cardIncomplete;

  /// No description provided for @cardOut.
  ///
  /// In ar, this message translates to:
  /// **'نفذ'**
  String get cardOut;

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @expired.
  ///
  /// In ar, this message translates to:
  /// **'منتهي الصلاحية'**
  String get expired;

  /// No description provided for @expiresOn.
  ///
  /// In ar, this message translates to:
  /// **'ينتهي {date}'**
  String expiresOn(String date);

  /// No description provided for @syncLocal.
  ///
  /// In ar, this message translates to:
  /// **'حفظ محلي'**
  String get syncLocal;

  /// No description provided for @syncOffline.
  ///
  /// In ar, this message translates to:
  /// **'غير متصل — حفظ محلي'**
  String get syncOffline;

  /// No description provided for @syncSyncing.
  ///
  /// In ar, this message translates to:
  /// **'جاري المزامنة…'**
  String get syncSyncing;

  /// No description provided for @syncSynced.
  ///
  /// In ar, this message translates to:
  /// **'مزامنة سحابية ✓'**
  String get syncSynced;

  /// No description provided for @syncFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت المزامنة'**
  String get syncFailed;

  /// No description provided for @syncErrPermission.
  ///
  /// In ar, this message translates to:
  /// **'قواعد أمان Firestore ترفض الوصول.\nالحل: Firebase Console ← Firestore Database ← Rules ← اسمح بالقراءة والكتابة لمجموعة medicines ثم Publish.'**
  String get syncErrPermission;

  /// No description provided for @syncErrNotFound.
  ///
  /// In ar, this message translates to:
  /// **'قاعدة بيانات Firestore غير منشأة في هذا المشروع.\nالحل: Firebase Console ← Build ← Firestore Database ← Create database.'**
  String get syncErrNotFound;

  /// No description provided for @syncErrUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال بالإنترنت — البيانات محفوظة محلياً.'**
  String get syncErrUnavailable;

  /// No description provided for @syncErrPrecondition.
  ///
  /// In ar, this message translates to:
  /// **'خدمة Firestore غير مفعّلة أو تحتاج إعداداً في Console.'**
  String get syncErrPrecondition;

  /// No description provided for @syncErrUnauthenticated.
  ///
  /// In ar, this message translates to:
  /// **'هوية الجهاز غير جاهزة.\nالحل: Firebase Console ← Authentication ← Sign-in method ← تفعيل Anonymous.'**
  String get syncErrUnauthenticated;

  /// No description provided for @syncErrUnknown.
  ///
  /// In ar, this message translates to:
  /// **'خطأ غير معروف'**
  String get syncErrUnknown;

  /// No description provided for @syncDenied.
  ///
  /// In ar, this message translates to:
  /// **'السحابة ترفض رفع {n} مادة من هذا الهاتف — بقية المزامنة تمّت. راجع قواعد Firestore.'**
  String syncDenied(int n);

  /// No description provided for @syncSkipped.
  ///
  /// In ar, this message translates to:
  /// **'تم تخطّي {n} سجل غير صالح في السحابة.'**
  String syncSkipped(int n);

  /// No description provided for @syncRelinked.
  ///
  /// In ar, this message translates to:
  /// **'أُعيد ربط {n} مادة كانت مسجّلة باسم صيدلية أخرى: {names}.'**
  String syncRelinked(int n, String names);

  /// No description provided for @syncDoneWithNotes.
  ///
  /// In ar, this message translates to:
  /// **'تمت المزامنة. {notes}'**
  String syncDoneWithNotes(String notes);

  /// No description provided for @listSeparator.
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get listSeparator;

  /// No description provided for @expiredDaysAgo.
  ///
  /// In ar, this message translates to:
  /// **'منتهية منذ {n} يوماً'**
  String expiredDaysAgo(int n);

  /// No description provided for @expiresToday.
  ///
  /// In ar, this message translates to:
  /// **'تنتهي اليوم'**
  String get expiresToday;

  /// No description provided for @daysLeft.
  ///
  /// In ar, this message translates to:
  /// **'متبقٍ {n} يوماً'**
  String daysLeft(int n);

  /// No description provided for @itemDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذفت هذه المادة'**
  String get itemDeleted;

  /// No description provided for @shareLinePrice.
  ///
  /// In ar, this message translates to:
  /// **'السعر: {v}'**
  String shareLinePrice(String v);

  /// No description provided for @shareLineQty.
  ///
  /// In ar, this message translates to:
  /// **'الكمية: {v}'**
  String shareLineQty(int v);

  /// No description provided for @shareLineExpiry.
  ///
  /// In ar, this message translates to:
  /// **'الصلاحية: {v}'**
  String shareLineExpiry(String v);

  /// No description provided for @shareLineBarcode.
  ///
  /// In ar, this message translates to:
  /// **'الباركود: {v}'**
  String shareLineBarcode(String v);

  /// No description provided for @shareLineCompany.
  ///
  /// In ar, this message translates to:
  /// **'الشركة: {v}'**
  String shareLineCompany(String v);

  /// No description provided for @share.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get share;

  /// No description provided for @rowExpiry.
  ///
  /// In ar, this message translates to:
  /// **'📅 الصلاحية'**
  String get rowExpiry;

  /// No description provided for @rowBarcode.
  ///
  /// In ar, this message translates to:
  /// **'📊 الباركود'**
  String get rowBarcode;

  /// No description provided for @barcodeCopied.
  ///
  /// In ar, this message translates to:
  /// **'نُسخ الباركود'**
  String get barcodeCopied;

  /// No description provided for @rowCompany.
  ///
  /// In ar, this message translates to:
  /// **'🏭 الشركة'**
  String get rowCompany;

  /// No description provided for @rowCategory.
  ///
  /// In ar, this message translates to:
  /// **'🧪 نوع المادة'**
  String get rowCategory;

  /// No description provided for @rowSection.
  ///
  /// In ar, this message translates to:
  /// **'🗂️ القسم'**
  String get rowSection;

  /// No description provided for @rowAdded.
  ///
  /// In ar, this message translates to:
  /// **'➕ الإضافة'**
  String get rowAdded;

  /// No description provided for @addedOn.
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت {date}'**
  String addedOn(String date);

  /// No description provided for @rowUpdated.
  ///
  /// In ar, this message translates to:
  /// **'🕓 آخر تعديل'**
  String get rowUpdated;

  /// No description provided for @invoiceHistory.
  ///
  /// In ar, this message translates to:
  /// **'🧾 سجل الفواتير'**
  String get invoiceHistory;

  /// No description provided for @noInvoicesForItem.
  ///
  /// In ar, this message translates to:
  /// **'لا فواتير محفوظة لهذه المادة'**
  String get noInvoicesForItem;

  /// No description provided for @unknownSupplier.
  ///
  /// In ar, this message translates to:
  /// **'مجهّز غير معروف'**
  String get unknownSupplier;

  /// No description provided for @badgeExpired.
  ///
  /// In ar, this message translates to:
  /// **'⛔ منتهية الصلاحية'**
  String get badgeExpired;

  /// No description provided for @badgeExpiring.
  ///
  /// In ar, this message translates to:
  /// **'⏳ قاربت الانتهاء'**
  String get badgeExpiring;

  /// No description provided for @badgeSoldOut.
  ///
  /// In ar, this message translates to:
  /// **'🚫 نافدة'**
  String get badgeSoldOut;

  /// No description provided for @badgeLowStock.
  ///
  /// In ar, this message translates to:
  /// **'⚠️ مخزون منخفض'**
  String get badgeLowStock;

  /// No description provided for @badgeIncomplete.
  ///
  /// In ar, this message translates to:
  /// **'📝 بيانات ناقصة'**
  String get badgeIncomplete;

  /// No description provided for @increase.
  ///
  /// In ar, this message translates to:
  /// **'زيادة'**
  String get increase;

  /// No description provided for @decrease.
  ///
  /// In ar, this message translates to:
  /// **'إنقاص'**
  String get decrease;

  /// No description provided for @stockValue.
  ///
  /// In ar, this message translates to:
  /// **'قيمة المخزون'**
  String get stockValue;

  /// No description provided for @formAlreadyRegistered.
  ///
  /// In ar, this message translates to:
  /// **'هذه المادة مسجّلة لديك — تعدّل الآن سجلها الحالي'**
  String get formAlreadyRegistered;

  /// No description provided for @formBarcodeNoData.
  ///
  /// In ar, this message translates to:
  /// **'تم قراءة الباركود: {code} — لم نجد بياناته، أكمل الحقول يدوياً'**
  String formBarcodeNoData(String code);

  /// No description provided for @formConfirmedBy.
  ///
  /// In ar, this message translates to:
  /// **' (أكّدته {n} صيدليات)'**
  String formConfirmedBy(int n);

  /// No description provided for @formFetchedFrom.
  ///
  /// In ar, this message translates to:
  /// **'تم جلب بيانات الدواء من {source}{confirmed} ✅'**
  String formFetchedFrom(String source, String confirmed);

  /// No description provided for @formAddIncomingTitle.
  ///
  /// In ar, this message translates to:
  /// **'📦 إضافة كمية واردة'**
  String get formAddIncomingTitle;

  /// No description provided for @formAddIncomingHint.
  ///
  /// In ar, this message translates to:
  /// **'العدد الوارد في الفاتورة'**
  String get formAddIncomingHint;

  /// No description provided for @formAddedNowBalance.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف {added} — الرصيد الآن {total}'**
  String formAddedNowBalance(int added, int total);

  /// No description provided for @formExpiryPickerTitle.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ انتهاء الصلاحية'**
  String get formExpiryPickerTitle;

  /// No description provided for @formInvalidPrice.
  ///
  /// In ar, this message translates to:
  /// **'السعر غير صالح — اكتب أرقاماً فقط'**
  String get formInvalidPrice;

  /// No description provided for @formInvalidQty.
  ///
  /// In ar, this message translates to:
  /// **'الكمية غير صالحة — اكتب عدداً صحيحاً'**
  String get formInvalidQty;

  /// No description provided for @formSaveFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الحفظ: {error}'**
  String formSaveFailed(String error);

  /// No description provided for @formBarcodeTakenTitle.
  ///
  /// In ar, this message translates to:
  /// **'⚠️ الباركود مسجَّل لمادة أخرى'**
  String get formBarcodeTakenTitle;

  /// No description provided for @formBarcodeTakenBody.
  ///
  /// In ar, this message translates to:
  /// **'الباركود «{barcode}» يخص «{name}» المسجّلة لديك بالفعل — الكمية {qty} بسعر {price}.\n\nلا يمكن حفظ مادتين بنفس الباركود. «تعديل الموجود» يفتحه للتحديث (يدعم \"+\" لإضافة الوارد إلى الرصيد الحالي).'**
  String formBarcodeTakenBody(
    String barcode,
    String name,
    int qty,
    String price,
  );

  /// No description provided for @editExisting.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الموجود'**
  String get editExisting;

  /// No description provided for @formBarcodeOwnerBody.
  ///
  /// In ar, this message translates to:
  /// **'الباركود «{barcode}» يخص «{name}» — الكمية {qty} بسعر {price}.\n\nلا يمكن حفظ مادتين بنفس الباركود. صحّح الباركود، أو ادمج المادتين من «مراجعة التكرارات» في الإعدادات.'**
  String formBarcodeOwnerBody(
    String barcode,
    String name,
    int qty,
    String price,
  );

  /// No description provided for @formSameNameTitle.
  ///
  /// In ar, this message translates to:
  /// **'⚠️ مادة بنفس الاسم موجودة'**
  String get formSameNameTitle;

  /// No description provided for @formSameNameBody.
  ///
  /// In ar, this message translates to:
  /// **'«{name}» مسجّلة لديك بالفعل — الكمية {qty} بسعر {price}.\n\nتعديل الموجود يفتحه للتحديث (يدعم \"+\" لإضافة الوارد). الحفظ كسجل منفصل يُبقي الاثنين قائمين.'**
  String formSameNameBody(String name, int qty, String price);

  /// No description provided for @separateRecord.
  ///
  /// In ar, this message translates to:
  /// **'سجل منفصل'**
  String get separateRecord;

  /// No description provided for @formTitleEditSupply.
  ///
  /// In ar, this message translates to:
  /// **'تعديل مستلزم'**
  String get formTitleEditSupply;

  /// No description provided for @formTitleEditMedicine.
  ///
  /// In ar, this message translates to:
  /// **'تعديل دواء'**
  String get formTitleEditMedicine;

  /// No description provided for @formTitleNewSupply.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مستلزم جديد'**
  String get formTitleNewSupply;

  /// No description provided for @formTitleNewMedicine.
  ///
  /// In ar, this message translates to:
  /// **'إضافة دواء جديد'**
  String get formTitleNewMedicine;

  /// No description provided for @formType.
  ///
  /// In ar, this message translates to:
  /// **'🗂️ النوع'**
  String get formType;

  /// No description provided for @formBarcode.
  ///
  /// In ar, this message translates to:
  /// **'📊 الباركود'**
  String get formBarcode;

  /// No description provided for @formBarcodeHint.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الباركود يدوياً أو امسحه'**
  String get formBarcodeHint;

  /// No description provided for @formNoBarcode.
  ///
  /// In ar, this message translates to:
  /// **'ليس لها باركود'**
  String get formNoBarcode;

  /// No description provided for @formLookingUp.
  ///
  /// In ar, this message translates to:
  /// **'جاري البحث عن معلومات الدواء...'**
  String get formLookingUp;

  /// No description provided for @formSupplyImage.
  ///
  /// In ar, this message translates to:
  /// **'📷 صورة المستلزم'**
  String get formSupplyImage;

  /// No description provided for @formMedicineImage.
  ///
  /// In ar, this message translates to:
  /// **'📷 صورة الدواء'**
  String get formMedicineImage;

  /// No description provided for @camera.
  ///
  /// In ar, this message translates to:
  /// **'كاميرا'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In ar, this message translates to:
  /// **'معرض'**
  String get gallery;

  /// No description provided for @formSupplyName.
  ///
  /// In ar, this message translates to:
  /// **'🩹 اسم المستلزم *'**
  String get formSupplyName;

  /// No description provided for @formMedicineName.
  ///
  /// In ar, this message translates to:
  /// **'💊 اسم الدواء *'**
  String get formMedicineName;

  /// No description provided for @formSupplyNameHint.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسم المستلزم'**
  String get formSupplyNameHint;

  /// No description provided for @formMedicineNameHint.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسم الدواء'**
  String get formMedicineNameHint;

  /// No description provided for @formNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'الاسم مطلوب'**
  String get formNameRequired;

  /// No description provided for @formCompany.
  ///
  /// In ar, this message translates to:
  /// **'🏭 اسم الشركة (اختياري)'**
  String get formCompany;

  /// No description provided for @formCompanyHint.
  ///
  /// In ar, this message translates to:
  /// **'مثل: Juman'**
  String get formCompanyHint;

  /// No description provided for @formCategory.
  ///
  /// In ar, this message translates to:
  /// **'🧪 نوع المادة (اختياري)'**
  String get formCategory;

  /// No description provided for @formCategoryHint.
  ///
  /// In ar, this message translates to:
  /// **'مثل: Tablet، Cream، Syrup…'**
  String get formCategoryHint;

  /// No description provided for @formPrice.
  ///
  /// In ar, this message translates to:
  /// **'💰 السعر ({currency})'**
  String formPrice(String currency);

  /// No description provided for @formQuantity.
  ///
  /// In ar, this message translates to:
  /// **'📦 الكمية'**
  String get formQuantity;

  /// No description provided for @formExpiry.
  ///
  /// In ar, this message translates to:
  /// **'📅 تاريخ الصلاحية (اختياري)'**
  String get formExpiry;

  /// No description provided for @notSet.
  ///
  /// In ar, this message translates to:
  /// **'غير محدد'**
  String get notSet;

  /// No description provided for @saveChanges.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التعديلات'**
  String get saveChanges;

  /// No description provided for @saveSupply.
  ///
  /// In ar, this message translates to:
  /// **'حفظ المستلزم'**
  String get saveSupply;

  /// No description provided for @saveMedicine.
  ///
  /// In ar, this message translates to:
  /// **'حفظ الدواء'**
  String get saveMedicine;

  /// No description provided for @chipExpiry.
  ///
  /// In ar, this message translates to:
  /// **'📅 الصلاحية: {date}'**
  String chipExpiry(String date);

  /// No description provided for @chipBatch.
  ///
  /// In ar, this message translates to:
  /// **'🏷️ وجبة: {batch}'**
  String chipBatch(String batch);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
