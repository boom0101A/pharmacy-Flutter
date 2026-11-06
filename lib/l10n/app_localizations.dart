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

  /// No description provided for @homeCountMedicines.
  ///
  /// In ar, this message translates to:
  /// **'{n} دواء'**
  String homeCountMedicines(int n);

  /// No description provided for @homeCountSupplies.
  ///
  /// In ar, this message translates to:
  /// **'{n} مستلزم'**
  String homeCountSupplies(int n);

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

  /// No description provided for @formDeleteOwner.
  ///
  /// In ar, this message translates to:
  /// **'🗑️ حذف المرتبط'**
  String get formDeleteOwner;

  /// No description provided for @formDeleteOwnerTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف الدواء المرتبط؟'**
  String get formDeleteOwnerTitle;

  /// No description provided for @formDeleteOwnerBody.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد حذف «{name}» المرتبط بالباركود «{barcode}»؟\nالكمية {qty} بسعر {price}.\n\nيُحذف بكل تفاصيله ولا يمكن التراجع.'**
  String formDeleteOwnerBody(
    String name,
    String barcode,
    int qty,
    String price,
  );

  /// No description provided for @formOwnerDeleted.
  ///
  /// In ar, this message translates to:
  /// **'🗑️ حُذف «{name}» — اضغط حفظ لربط الباركود بهذا الدواء'**
  String formOwnerDeleted(String name);

  /// No description provided for @formBarcodeOwnerBody.
  ///
  /// In ar, this message translates to:
  /// **'الباركود «{barcode}» يخص «{name}» — الكمية {qty} بسعر {price}.\n\nلا يمكن حفظ مادتين بنفس الباركود. صحّح الباركود، أو احذف المادة المرتبطة، أو ادمج المادتين من «مراجعة التكرارات» في الإعدادات.'**
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

  /// No description provided for @settingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'⚙️ الإعدادات'**
  String get settingsTitle;

  /// No description provided for @settingsAlerts.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات الصلاحية والمخزون'**
  String get settingsAlerts;

  /// No description provided for @settingsAlertsSub.
  ///
  /// In ar, this message translates to:
  /// **'إشعار يومي الساعة 9 صباحاً إذا كانت هناك مواد منتهية أو قاربت الانتهاء أو مخزون منخفض/نافد.'**
  String get settingsAlertsSub;

  /// No description provided for @settingsContribute.
  ///
  /// In ar, this message translates to:
  /// **'المساهمة في القاموس المشترك'**
  String get settingsContribute;

  /// No description provided for @settingsContributeSub.
  ///
  /// In ar, this message translates to:
  /// **'إرسال اسم الدواء وصورته فقط عند حفظه، لمساعدة بقية الصيدليات على التعرف عليه.'**
  String get settingsContributeSub;

  /// No description provided for @settingsSent.
  ///
  /// In ar, this message translates to:
  /// **'✅ يُرسَل'**
  String get settingsSent;

  /// No description provided for @settingsSentWhat.
  ///
  /// In ar, this message translates to:
  /// **'الباركود + اسم الدواء + صورة مصغّرة'**
  String get settingsSentWhat;

  /// No description provided for @settingsNotSent.
  ///
  /// In ar, this message translates to:
  /// **'🔒 لا يُرسَل'**
  String get settingsNotSent;

  /// No description provided for @settingsNotSentWhat.
  ///
  /// In ar, this message translates to:
  /// **'السعر • الكمية • اسم صيدليتك • موقعك'**
  String get settingsNotSentWhat;

  /// No description provided for @settingsContributing.
  ///
  /// In ar, this message translates to:
  /// **'أنت تساهم حالياً — شكراً، هذا ما يجعل القاموس ينمو.'**
  String get settingsContributing;

  /// No description provided for @settingsNotContributing.
  ///
  /// In ar, this message translates to:
  /// **'المساهمة موقوفة. ستبقى تستفيد من القاموس عند المسح، لكن أدويتك لن تُضاف إليه.'**
  String get settingsNotContributing;

  /// No description provided for @settingsShowWelcome.
  ///
  /// In ar, this message translates to:
  /// **'عرض شاشة الترحيب'**
  String get settingsShowWelcome;

  /// No description provided for @backupTitle.
  ///
  /// In ar, this message translates to:
  /// **'💾 النسخة الاحتياطية'**
  String get backupTitle;

  /// No description provided for @backupSub.
  ///
  /// In ar, this message translates to:
  /// **'ملف يحفظ كل المواد. عند الحفظ أرسله إلى واتساب أو Drive أو التنزيلات — إلغاء التثبيت يمسح ما بداخل التطبيق ويغيّر هوية المزامنة.'**
  String get backupSub;

  /// No description provided for @backupSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ نسخة'**
  String get backupSave;

  /// No description provided for @backupRestore.
  ///
  /// In ar, this message translates to:
  /// **'استرجاع'**
  String get backupRestore;

  /// No description provided for @syncIdCopied.
  ///
  /// In ar, this message translates to:
  /// **'نُسخ معرّف المزامنة'**
  String get syncIdCopied;

  /// No description provided for @syncDisabled.
  ///
  /// In ar, this message translates to:
  /// **'المزامنة غير مفعّلة'**
  String get syncDisabled;

  /// No description provided for @syncId.
  ///
  /// In ar, this message translates to:
  /// **'معرّف المزامنة: {id}… (اضغط للنسخ)'**
  String syncId(String id);

  /// No description provided for @backupWhereToSave.
  ///
  /// In ar, this message translates to:
  /// **'اختر أين تحفظ النسخة: واتساب، Drive، أو التنزيلات'**
  String get backupWhereToSave;

  /// No description provided for @saveFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الحفظ: {error}'**
  String saveFailed(String error);

  /// No description provided for @restoreFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاسترجاع: {error}'**
  String restoreFailed(String error);

  /// No description provided for @restoreFromWhere.
  ///
  /// In ar, this message translates to:
  /// **'استرجاع من أين؟'**
  String get restoreFromWhere;

  /// No description provided for @restorePickFile.
  ///
  /// In ar, this message translates to:
  /// **'اختيار ملف…'**
  String get restorePickFile;

  /// No description provided for @restoreLastLocal.
  ///
  /// In ar, this message translates to:
  /// **'آخر نسخة على هذا الجهاز'**
  String get restoreLastLocal;

  /// No description provided for @restoreTitle.
  ///
  /// In ar, this message translates to:
  /// **'استرجاع النسخة'**
  String get restoreTitle;

  /// No description provided for @restoreContainsItems.
  ///
  /// In ar, this message translates to:
  /// **'الملف يحتوي {n} مادة'**
  String restoreContainsItems(int n);

  /// No description provided for @restoreAndInvoices.
  ///
  /// In ar, this message translates to:
  /// **' و{n} فاتورة'**
  String restoreAndInvoices(int n);

  /// No description provided for @restoreNote.
  ///
  /// In ar, this message translates to:
  /// **'سيُضاف الجديد ويُحدَّث الأقدم — لا يُحذف شيء موجود.'**
  String get restoreNote;

  /// No description provided for @restoreConfirm.
  ///
  /// In ar, this message translates to:
  /// **'استرجع'**
  String get restoreConfirm;

  /// No description provided for @restoreResult.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف {added} · حُدّث {updated} · بلا تغيير {skipped}'**
  String restoreResult(int added, int updated, int skipped);

  /// No description provided for @sharingTitle.
  ///
  /// In ar, this message translates to:
  /// **'🔗 مشاركة المخزون بين الأجهزة'**
  String get sharingTitle;

  /// No description provided for @sharingSub.
  ///
  /// In ar, this message translates to:
  /// **'اربط هاتف زميل أو مساعدك بنفس المخزون — أي تعديل من أي جهاز يظهر للجميع.'**
  String get sharingSub;

  /// No description provided for @shareWithDevice.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة مع جهاز آخر'**
  String get shareWithDevice;

  /// No description provided for @joinInventory.
  ///
  /// In ar, this message translates to:
  /// **'الانضمام إلى مخزون'**
  String get joinInventory;

  /// No description provided for @linkedDevices.
  ///
  /// In ar, this message translates to:
  /// **'الأجهزة المرتبطة'**
  String get linkedDevices;

  /// No description provided for @reviewDuplicates.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة التكرارات'**
  String get reviewDuplicates;

  /// No description provided for @invoicesCount.
  ///
  /// In ar, this message translates to:
  /// **'الفواتير ({n})'**
  String invoicesCount(int n);

  /// No description provided for @pairPrepareFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحضير — تحقق من الاتصال بالإنترنت.'**
  String get pairPrepareFailed;

  /// No description provided for @pairCodeFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر توليد رمز — حاول مرة أخرى.'**
  String get pairCodeFailed;

  /// No description provided for @pairRequestFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إتمام الطلب — حاول مرة أخرى.'**
  String get pairRequestFailed;

  /// No description provided for @pairShareTitle.
  ///
  /// In ar, this message translates to:
  /// **'🔗 مشاركة المخزون مع جهاز آخر'**
  String get pairShareTitle;

  /// No description provided for @pairShareSub.
  ///
  /// In ar, this message translates to:
  /// **'أعطِ هذا الرمز للجهاز الآخر — صالح لمدة 10 دقائق. بعد إدخاله هناك، وافِق على الطلب هنا ليصبح المخزون مشتركاً بين الجهازين.'**
  String get pairShareSub;

  /// No description provided for @unknownError.
  ///
  /// In ar, this message translates to:
  /// **'خطأ غير معروف'**
  String get unknownError;

  /// No description provided for @tryAgain.
  ///
  /// In ar, this message translates to:
  /// **'حاول مرة أخرى'**
  String get tryAgain;

  /// No description provided for @pairWaiting.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار الجهاز الآخر…'**
  String get pairWaiting;

  /// No description provided for @pairApproveHint.
  ///
  /// In ar, this message translates to:
  /// **'وافق فقط إن كان الجهاز أمامك الآن وأنت من أعطاه الرمز.'**
  String get pairApproveHint;

  /// No description provided for @approve.
  ///
  /// In ar, this message translates to:
  /// **'موافقة'**
  String get approve;

  /// No description provided for @decline.
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get decline;

  /// No description provided for @pairDone.
  ///
  /// In ar, this message translates to:
  /// **'تم! المخزون مشترك الآن.'**
  String get pairDone;

  /// No description provided for @done.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get done;

  /// No description provided for @pairCodeExpired.
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية الرمز.'**
  String get pairCodeExpired;

  /// No description provided for @pairNewCode.
  ///
  /// In ar, this message translates to:
  /// **'توليد رمز جديد'**
  String get pairNewCode;

  /// No description provided for @pairEnterCode.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرمز المكوّن من 6 أرقام.'**
  String get pairEnterCode;

  /// No description provided for @pairCodeWrong.
  ///
  /// In ar, this message translates to:
  /// **'الرمز غير صحيح.'**
  String get pairCodeWrong;

  /// No description provided for @pairCodeExpiredAsk.
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية الرمز، اطلب رمزاً جديداً.'**
  String get pairCodeExpiredAsk;

  /// No description provided for @pairCodeUsed.
  ///
  /// In ar, this message translates to:
  /// **'هذا الرمز استُخدم من قبل.'**
  String get pairCodeUsed;

  /// No description provided for @pairConnectFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال — تحقق من الإنترنت وحاول مرة أخرى.'**
  String get pairConnectFailed;

  /// No description provided for @pairJoined.
  ///
  /// In ar, this message translates to:
  /// **'تم الانضمام! جاري تنزيل المخزون…'**
  String get pairJoined;

  /// No description provided for @pairJoinTitle.
  ///
  /// In ar, this message translates to:
  /// **'🔗 الانضمام إلى مخزون موجود'**
  String get pairJoinTitle;

  /// No description provided for @pairJoinSub.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرمز الظاهر على الجهاز الذي يملك المخزون حالياً.'**
  String get pairJoinSub;

  /// No description provided for @join.
  ///
  /// In ar, this message translates to:
  /// **'انضمام'**
  String get join;

  /// No description provided for @pairApproved.
  ///
  /// In ar, this message translates to:
  /// **'تمت الموافقة! جاري تنزيل المخزون…'**
  String get pairApproved;

  /// No description provided for @pairDeclined.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض الطلب من الجهاز الآخر.'**
  String get pairDeclined;

  /// No description provided for @pairExpiredBeforeApproval.
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية الرمز قبل أن يوافق الجهاز الآخر.'**
  String get pairExpiredBeforeApproval;

  /// No description provided for @pairSentWaiting.
  ///
  /// In ar, this message translates to:
  /// **'تم الإرسال — بانتظار موافقة الجهاز الآخر…'**
  String get pairSentWaiting;

  /// No description provided for @pairPromptUnknown.
  ///
  /// In ar, this message translates to:
  /// **'جهاز آخر يطلب الانضمام — هل توافق؟'**
  String get pairPromptUnknown;

  /// No description provided for @pairPromptDevice.
  ///
  /// In ar, this message translates to:
  /// **'الجهاز {id} يطلب الانضمام — هل توافق؟'**
  String pairPromptDevice(String id);

  /// No description provided for @devicesLoadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحميل — تحقق من الإنترنت.'**
  String get devicesLoadFailed;

  /// No description provided for @removeDeviceTitle.
  ///
  /// In ar, this message translates to:
  /// **'إخراج الجهاز؟'**
  String get removeDeviceTitle;

  /// No description provided for @removeDeviceBody.
  ///
  /// In ar, this message translates to:
  /// **'الجهاز {id} لن يرى المخزون ولن يعدّله بعد الآن. ما على هاتفه من نسخة محلية يبقى عنده.'**
  String removeDeviceBody(String id);

  /// No description provided for @remove.
  ///
  /// In ar, this message translates to:
  /// **'إخراج'**
  String get remove;

  /// No description provided for @removeFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الإخراج: {error}'**
  String removeFailed(String error);

  /// No description provided for @devicesTitle.
  ///
  /// In ar, this message translates to:
  /// **'📱 الأجهزة المرتبطة'**
  String get devicesTitle;

  /// No description provided for @devicesSub.
  ///
  /// In ar, this message translates to:
  /// **'كل جهاز هنا يرى المخزون بأسعاره وكمياته ويعدّله. أخرج أي جهاز لا تعرفه.'**
  String get devicesSub;

  /// No description provided for @deviceName.
  ///
  /// In ar, this message translates to:
  /// **'جهاز {id}'**
  String deviceName(String id);

  /// No description provided for @deviceOwner.
  ///
  /// In ar, this message translates to:
  /// **'صاحب المخزون'**
  String get deviceOwner;

  /// No description provided for @deviceThisPhone.
  ///
  /// In ar, this message translates to:
  /// **'هذا الهاتف'**
  String get deviceThisPhone;

  /// No description provided for @dupLoadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المواد: {error}'**
  String dupLoadFailed(String error);

  /// No description provided for @dupMergeFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الدمج — لم يتغيّر شيء: {error}'**
  String dupMergeFailed(String error);

  /// No description provided for @dupSplitFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فصل الباركود: {error}'**
  String dupSplitFailed(String error);

  /// No description provided for @dupTitle.
  ///
  /// In ar, this message translates to:
  /// **'🔍 مراجعة التكرارات'**
  String get dupTitle;

  /// No description provided for @refresh.
  ///
  /// In ar, this message translates to:
  /// **'تحديث'**
  String get refresh;

  /// No description provided for @dupNone.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد تكرارات ✅'**
  String get dupNone;

  /// No description provided for @dupGroupsIntro.
  ///
  /// In ar, this message translates to:
  /// **'{n} مجموعة — علّم ما هو نفس المنتج ثم «دمج المختارة»، أو «ليست مكرّرة» إن كانت كلها منتجات مختلفة.'**
  String dupGroupsIntro(int n);

  /// No description provided for @dupSimilarIntro.
  ///
  /// In ar, this message translates to:
  /// **'🔍 أسماء متشابهة — تحقّق قبل الدمج ({n})\nأسماء متقاربة لا متطابقة: خطأ إملائي، أو كلمة زائدة، أو حجم وتركيز آخر. كثير منها منتجات مختلفة فعلاً — «ليست مكرّرة» يخفيها من كل الأجهزة.'**
  String dupSimilarIntro(int n);

  /// No description provided for @dupShowHidden.
  ///
  /// In ar, this message translates to:
  /// **'إظهار المخفية ({n})'**
  String dupShowHidden(int n);

  /// No description provided for @dupShowHiddenTitle.
  ///
  /// In ar, this message translates to:
  /// **'إظهار المجموعات المخفية'**
  String get dupShowHiddenTitle;

  /// No description provided for @dupShowHiddenBody.
  ///
  /// In ar, this message translates to:
  /// **'ستعود {n} مجموعة للمراجعة على كل الأجهزة. المواد لا تتغيّر.'**
  String dupShowHiddenBody(int n);

  /// No description provided for @show.
  ///
  /// In ar, this message translates to:
  /// **'إظهار'**
  String get show;

  /// No description provided for @dupMergePaused.
  ///
  /// In ar, this message translates to:
  /// **'الدمج متوقف: {n} عملية حذف لم تصل للسحابة بعد. الدمج يجمع الكميات ويحذف الباقي، فإن لم يصل الحذف تبقى المواد على الهاتف الآخر وتتضاعف الكمية. اتصل بالإنترنت ثم اضغط تحديث.'**
  String dupMergePaused(int n);

  /// No description provided for @dupSimilarPercent.
  ///
  /// In ar, this message translates to:
  /// **'🔍 أسماء متشابهة بنسبة {p}%'**
  String dupSimilarPercent(int p);

  /// No description provided for @dupSameBarcode.
  ///
  /// In ar, this message translates to:
  /// **'🏷️ نفس الباركود — قد تكون منتجات مختلفة'**
  String get dupSameBarcode;

  /// No description provided for @dupSameName.
  ///
  /// In ar, this message translates to:
  /// **'📝 نفس الاسم في نفس القسم'**
  String get dupSameName;

  /// No description provided for @dupDifferentBarcodes.
  ///
  /// In ar, this message translates to:
  /// **'🏷️ باركودان مختلفان — تأكّد أنها ليست حجماً أو نكهة أخرى'**
  String get dupDifferentBarcodes;

  /// No description provided for @dupTickHint.
  ///
  /// In ar, this message translates to:
  /// **'علّم المواد التي هي نفس المنتج ثم «دمج المختارة» — غير المعلّمة تبقى كما هي وتُزال من المراجعة.'**
  String get dupTickHint;

  /// No description provided for @dupPickTwo.
  ///
  /// In ar, this message translates to:
  /// **'اختر مادتين للدمج'**
  String get dupPickTwo;

  /// No description provided for @dupMergeSelected.
  ///
  /// In ar, this message translates to:
  /// **'دمج المختارة ({n}) · الكمية {total}'**
  String dupMergeSelected(int n, int total);

  /// No description provided for @dupNotDuplicates.
  ///
  /// In ar, this message translates to:
  /// **'ليست مكرّرة'**
  String get dupNotDuplicates;

  /// No description provided for @dupSplitBarcode.
  ///
  /// In ar, this message translates to:
  /// **'فصل الباركود'**
  String get dupSplitBarcode;

  /// No description provided for @detQty.
  ///
  /// In ar, this message translates to:
  /// **'الكمية {n}'**
  String detQty(int n);

  /// No description provided for @detPrice.
  ///
  /// In ar, this message translates to:
  /// **'السعر {v}'**
  String detPrice(String v);

  /// No description provided for @detExpiry.
  ///
  /// In ar, this message translates to:
  /// **'الصلاحية {d}'**
  String detExpiry(String d);

  /// No description provided for @detEdited.
  ///
  /// In ar, this message translates to:
  /// **'عُدّلت {d}'**
  String detEdited(String d);

  /// No description provided for @dupMergeTitle.
  ///
  /// In ar, this message translates to:
  /// **'دمج {n} مواد'**
  String dupMergeTitle(int n);

  /// No description provided for @dupKeptName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الذي يبقى'**
  String get dupKeptName;

  /// No description provided for @dupFinalPrice.
  ///
  /// In ar, this message translates to:
  /// **'💰 السعر النهائي ({currency})'**
  String dupFinalPrice(String currency);

  /// No description provided for @dupFinalQty.
  ///
  /// In ar, this message translates to:
  /// **'📦 الكمية النهائية'**
  String get dupFinalQty;

  /// No description provided for @dupWillDelete.
  ///
  /// In ar, this message translates to:
  /// **'تُحذف {n} مادة من هذا الهاتف ومن كل الأجهزة المشتركة.'**
  String dupWillDelete(int n);

  /// No description provided for @cdBarcodeTaken.
  ///
  /// In ar, this message translates to:
  /// **'هذا الباركود مسجّل لمادة أخرى — استعمل «دمج» إن كانت هي نفسها'**
  String get cdBarcodeTaken;

  /// No description provided for @cdMergeWith.
  ///
  /// In ar, this message translates to:
  /// **'دمج مع «{name}»'**
  String cdMergeWith(String name);

  /// No description provided for @cdMergeBody.
  ///
  /// In ar, this message translates to:
  /// **'تبقى «{keep}» بكمية {qty}، وتُحذف «{drop}» من كل الأجهزة. ينتقل إليها الباركود والصورة إن لم يكونا لها.'**
  String cdMergeBody(String keep, int qty, String drop);

  /// No description provided for @cdMergeConfirm.
  ///
  /// In ar, this message translates to:
  /// **'ادمج'**
  String get cdMergeConfirm;

  /// No description provided for @cdDeleteTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف المادة'**
  String get cdDeleteTitle;

  /// No description provided for @cdDeleteBody.
  ///
  /// In ar, this message translates to:
  /// **'تُحذف «{name}» من هذا الهاتف ومن كل الأجهزة المشتركة.'**
  String cdDeleteBody(String name);

  /// No description provided for @cdDeleteConfirm.
  ///
  /// In ar, this message translates to:
  /// **'احذف'**
  String get cdDeleteConfirm;

  /// No description provided for @cdTitle.
  ///
  /// In ar, this message translates to:
  /// **'📝 إكمال البيانات'**
  String get cdTitle;

  /// No description provided for @cdNoneInSection.
  ///
  /// In ar, this message translates to:
  /// **'لا مواد ناقصة في هذا القسم'**
  String get cdNoneInSection;

  /// No description provided for @cdListDone.
  ///
  /// In ar, this message translates to:
  /// **'انتهت القائمة — اكتملت {n} مادة'**
  String cdListDone(int n);

  /// No description provided for @back.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get back;

  /// No description provided for @cdProgress.
  ///
  /// In ar, this message translates to:
  /// **'مادة {i} من {n}'**
  String cdProgress(int i, int n);

  /// No description provided for @cdNoPrice.
  ///
  /// In ar, this message translates to:
  /// **'بلا سعر'**
  String get cdNoPrice;

  /// No description provided for @cdNoBarcode.
  ///
  /// In ar, this message translates to:
  /// **'بلا باركود'**
  String get cdNoBarcode;

  /// No description provided for @cdSimilar.
  ///
  /// In ar, this message translates to:
  /// **'🔍 تشبه مادة موجودة ({p}%)'**
  String cdSimilar(int p);

  /// No description provided for @cdMatchLine.
  ///
  /// In ar, this message translates to:
  /// **'السعر {price} · الكمية {qty}'**
  String cdMatchLine(String price, int qty);

  /// No description provided for @cdSameMerge.
  ///
  /// In ar, this message translates to:
  /// **'هي نفسها — دمج معها'**
  String get cdSameMerge;

  /// No description provided for @cdPrice.
  ///
  /// In ar, this message translates to:
  /// **'💰 السعر ({currency})'**
  String cdPrice(String currency);

  /// No description provided for @cdQty.
  ///
  /// In ar, this message translates to:
  /// **'📦 الكمية'**
  String get cdQty;

  /// No description provided for @cdBarcode.
  ///
  /// In ar, this message translates to:
  /// **'📊 الباركود'**
  String get cdBarcode;

  /// No description provided for @scanTheBarcode.
  ///
  /// In ar, this message translates to:
  /// **'مسح الباركود'**
  String get scanTheBarcode;

  /// No description provided for @cdNoBarcodeSub.
  ///
  /// In ar, this message translates to:
  /// **'تحضير أو علبة بلا رمز — لن تُعدّ ناقصة بسبب الباركود'**
  String get cdNoBarcodeSub;

  /// No description provided for @takePhoto.
  ///
  /// In ar, this message translates to:
  /// **'تصوير'**
  String get takePhoto;

  /// No description provided for @theGallery.
  ///
  /// In ar, this message translates to:
  /// **'المعرض'**
  String get theGallery;

  /// No description provided for @cdSaveNext.
  ///
  /// In ar, this message translates to:
  /// **'حفظ والتالي'**
  String get cdSaveNext;

  /// No description provided for @invTitle.
  ///
  /// In ar, this message translates to:
  /// **'📚 الفواتير'**
  String get invTitle;

  /// No description provided for @invSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث باسم المجهّز أو رقم الفاتورة…'**
  String get invSearchHint;

  /// No description provided for @invSummary.
  ///
  /// In ar, this message translates to:
  /// **'{n} فاتورة · المجموع {total}'**
  String invSummary(int n, String total);

  /// No description provided for @invEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا فواتير محفوظة بعد — تُحفظ تلقائياً من «فاتورة ذكية»'**
  String get invEmpty;

  /// No description provided for @invItems.
  ///
  /// In ar, this message translates to:
  /// **'{n} مادة'**
  String invItems(int n);

  /// No description provided for @invNumberShort.
  ///
  /// In ar, this message translates to:
  /// **' · رقم {n}'**
  String invNumberShort(String n);

  /// No description provided for @invDeleteTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف الفاتورة'**
  String get invDeleteTitle;

  /// No description provided for @invDeleteBody.
  ///
  /// In ar, this message translates to:
  /// **'يُحذف سجل الفاتورة وصورها من كل الأجهزة. المخزون لا يتغيّر — الكميات التي أضافتها تبقى.'**
  String get invDeleteBody;

  /// No description provided for @invoice.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة'**
  String get invoice;

  /// No description provided for @invDeleteRecord.
  ///
  /// In ar, this message translates to:
  /// **'حذف السجل'**
  String get invDeleteRecord;

  /// No description provided for @invPhotoElsewhere.
  ///
  /// In ar, this message translates to:
  /// **'📷 صورة الفاتورة على الهاتف الذي صوّرها'**
  String get invPhotoElsewhere;

  /// No description provided for @invPhotoFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر عرض الصورة'**
  String get invPhotoFailed;

  /// No description provided for @invRowSupplier.
  ///
  /// In ar, this message translates to:
  /// **'🏪 المجهّز'**
  String get invRowSupplier;

  /// No description provided for @invRowDate.
  ///
  /// In ar, this message translates to:
  /// **'📅 التاريخ'**
  String get invRowDate;

  /// No description provided for @invRowNumber.
  ///
  /// In ar, this message translates to:
  /// **'🔢 الرقم'**
  String get invRowNumber;

  /// No description provided for @invRowTotal.
  ///
  /// In ar, this message translates to:
  /// **'💰 مجموع الفاتورة'**
  String get invRowTotal;

  /// No description provided for @invRowLinesTotal.
  ///
  /// In ar, this message translates to:
  /// **'🧮 مجموع الأسطر'**
  String get invRowLinesTotal;

  /// No description provided for @invLineMerged.
  ///
  /// In ar, this message translates to:
  /// **'🔁 أُضيفت لموجودة'**
  String get invLineMerged;

  /// No description provided for @invLineNew.
  ///
  /// In ar, this message translates to:
  /// **'🆕 جديدة'**
  String get invLineNew;

  /// No description provided for @scanAim.
  ///
  /// In ar, this message translates to:
  /// **'🎯 وجّه الكاميرا نحو باركود الدواء'**
  String get scanAim;

  /// No description provided for @camDenied.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم منح إذن الكاميرا.\nافتح إعدادات التطبيق وفعّل الكاميرا.'**
  String get camDenied;

  /// No description provided for @camUnsupported.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا غير مدعومة على هذا الجهاز.'**
  String get camUnsupported;

  /// No description provided for @camFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تشغيل الكاميرا.\n{details}'**
  String camFailed(String details);

  /// No description provided for @cropTitle.
  ///
  /// In ar, this message translates to:
  /// **'قصّ الصورة'**
  String get cropTitle;

  /// No description provided for @cropReset.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الضبط'**
  String get cropReset;

  /// No description provided for @cropNone.
  ///
  /// In ar, this message translates to:
  /// **'بلا قص'**
  String get cropNone;

  /// No description provided for @scReplaceTitle.
  ///
  /// In ar, this message translates to:
  /// **'استبدال الصفحة؟'**
  String get scReplaceTitle;

  /// No description provided for @scReplaceBody.
  ///
  /// In ar, this message translates to:
  /// **'ستُحذف {n} سطراً مقروءاً من الصفحة الحالية وتُقرأ الصورة الجديدة مكانها.'**
  String scReplaceBody(int n);

  /// No description provided for @scReplace.
  ///
  /// In ar, this message translates to:
  /// **'استبدال'**
  String get scReplace;

  /// No description provided for @scNoValidLines.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أسطر صالحة للحفظ.'**
  String get scNoValidLines;

  /// No description provided for @scRecordFailed.
  ///
  /// In ar, this message translates to:
  /// **'حُفظت المواد، وتعذّر حفظ سجل الفاتورة'**
  String get scRecordFailed;

  /// No description provided for @scLeaveTitle.
  ///
  /// In ar, this message translates to:
  /// **'الخروج بلا حفظ؟'**
  String get scLeaveTitle;

  /// No description provided for @scLeaveBody.
  ///
  /// In ar, this message translates to:
  /// **'ستضيع {n} سطراً مقروءاً من هذه الفاتورة.'**
  String scLeaveBody(int n);

  /// No description provided for @scStay.
  ///
  /// In ar, this message translates to:
  /// **'البقاء'**
  String get scStay;

  /// No description provided for @scLeave.
  ///
  /// In ar, this message translates to:
  /// **'خروج بلا حفظ'**
  String get scLeave;

  /// No description provided for @scTitle.
  ///
  /// In ar, this message translates to:
  /// **'🧾 فاتورة ذكية'**
  String get scTitle;

  /// No description provided for @scSavedInvoices.
  ///
  /// In ar, this message translates to:
  /// **'الفواتير المحفوظة'**
  String get scSavedInvoices;

  /// No description provided for @scSaveN.
  ///
  /// In ar, this message translates to:
  /// **'حفظ ({n})'**
  String scSaveN(int n);

  /// No description provided for @scEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'صوّر الفاتورة أو اخترها من المعرض'**
  String get scEmptyTitle;

  /// No description provided for @scEmptySub.
  ///
  /// In ar, this message translates to:
  /// **'تُقرأ أسطر الصفحة وتُملأ الحقول تلقائياً (الاسم، الكمية، السعر، الصلاحية) لتراجعها قبل الحفظ.'**
  String get scEmptySub;

  /// No description provided for @scReadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت قراءة الصفحة: {error}\nاضغط «إعادة المحاولة» على الصفحة.'**
  String scReadFailed(String error);

  /// No description provided for @scFallbackModel.
  ///
  /// In ar, this message translates to:
  /// **'⚡ قُرئت بالنموذج البديل (النموذج الأساسي غير متاح الآن) — راجع الأسطر بانتباه'**
  String get scFallbackModel;

  /// No description provided for @scReading.
  ///
  /// In ar, this message translates to:
  /// **'جاري قراءة الفاتورة… قد تستغرق حتى دقيقة للصفحات الكثيفة'**
  String get scReading;

  /// No description provided for @scNoLines.
  ///
  /// In ar, this message translates to:
  /// **'لم تُقرأ أي أسطر بعد'**
  String get scNoLines;

  /// No description provided for @scHeader.
  ///
  /// In ar, this message translates to:
  /// **'🧾 بيانات الفاتورة'**
  String get scHeader;

  /// No description provided for @scSupplier.
  ///
  /// In ar, this message translates to:
  /// **'🏪 المجهّز'**
  String get scSupplier;

  /// No description provided for @scNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الفاتورة'**
  String get scNumber;

  /// No description provided for @scDate.
  ///
  /// In ar, this message translates to:
  /// **'📅 التاريخ'**
  String get scDate;

  /// No description provided for @scTotal.
  ///
  /// In ar, this message translates to:
  /// **'💰 مجموع الفاتورة ({currency})'**
  String scTotal(String currency);

  /// No description provided for @scLinesTotal.
  ///
  /// In ar, this message translates to:
  /// **'مجموع الأسطر: {total}'**
  String scLinesTotal(String total);

  /// No description provided for @scPrinted.
  ///
  /// In ar, this message translates to:
  /// **' · المطبوع: {total}'**
  String scPrinted(String total);

  /// No description provided for @scTotalsDiffer.
  ///
  /// In ar, this message translates to:
  /// **'⚠️ المجموعان مختلفان — راجع الكميات والأسعار'**
  String get scTotalsDiffer;

  /// No description provided for @scRetake.
  ///
  /// In ar, this message translates to:
  /// **'تصوير من جديد'**
  String get scRetake;

  /// No description provided for @scFromGallery.
  ///
  /// In ar, this message translates to:
  /// **'من المعرض'**
  String get scFromGallery;

  /// No description provided for @scDeletePage.
  ///
  /// In ar, this message translates to:
  /// **'حذف الصفحة'**
  String get scDeletePage;

  /// No description provided for @scRetry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get scRetry;

  /// No description provided for @close.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get close;

  /// No description provided for @scLinesSummary.
  ///
  /// In ar, this message translates to:
  /// **'{total} سطراً · {fresh} جديدة · {existing} ستُضاف لمخزون موجود'**
  String scLinesSummary(int total, int fresh, int existing);

  /// No description provided for @scNeedReview.
  ///
  /// In ar, this message translates to:
  /// **' · {n} تحتاج مراجعة'**
  String scNeedReview(int n);

  /// No description provided for @scFlaggedOnly.
  ///
  /// In ar, this message translates to:
  /// **'المشكوك فيها فقط'**
  String get scFlaggedOnly;

  /// No description provided for @scAllLinesType.
  ///
  /// In ar, this message translates to:
  /// **'نوع كل الأسطر:'**
  String get scAllLinesType;

  /// No description provided for @scName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get scName;

  /// No description provided for @scCostPrice.
  ///
  /// In ar, this message translates to:
  /// **'السعر (كلفة)'**
  String get scCostPrice;

  /// No description provided for @scQty.
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get scQty;

  /// No description provided for @scBonus.
  ///
  /// In ar, this message translates to:
  /// **'+{n} مجاناً'**
  String scBonus(int n);

  /// No description provided for @scExpiry.
  ///
  /// In ar, this message translates to:
  /// **'الصلاحية (مثل 2027-11)'**
  String get scExpiry;

  /// No description provided for @scBarcodeOpt.
  ///
  /// In ar, this message translates to:
  /// **'الباركود (اختياري)'**
  String get scBarcodeOpt;

  /// No description provided for @scExisting.
  ///
  /// In ar, this message translates to:
  /// **'🔁 موجودة مسبقاً («{name}») — الرصيد {qty}، سيُضاف الوارد إليه'**
  String scExisting(String name, int qty);

  /// No description provided for @scDuplicateLine.
  ///
  /// In ar, this message translates to:
  /// **'🔗 مكرر مع سطر آخر في هذه الفاتورة — سيُدمجان تلقائياً'**
  String get scDuplicateLine;

  /// No description provided for @issueInvalidBarcode.
  ///
  /// In ar, this message translates to:
  /// **'باركود غير صالح — حُذف'**
  String get issueInvalidBarcode;

  /// No description provided for @issueTotalMismatch.
  ///
  /// In ar, this message translates to:
  /// **'الكمية × السعر ≠ المجموع'**
  String get issueTotalMismatch;

  /// No description provided for @issueMissingPrice.
  ///
  /// In ar, this message translates to:
  /// **'السعر ناقص'**
  String get issueMissingPrice;

  /// No description provided for @issueMissingQty.
  ///
  /// In ar, this message translates to:
  /// **'الكمية ناقصة'**
  String get issueMissingQty;

  /// No description provided for @issueUncertain.
  ///
  /// In ar, this message translates to:
  /// **'غير واضح في الصورة'**
  String get issueUncertain;

  /// No description provided for @issueSuspiciousPrice.
  ///
  /// In ar, this message translates to:
  /// **'⚠️ السعر غير منطقي — راجعه'**
  String get issueSuspiciousPrice;

  /// No description provided for @gmImageReadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت قراءة ملف الصورة: {error}'**
  String gmImageReadFailed(String error);

  /// No description provided for @gmNotConfigured.
  ///
  /// In ar, this message translates to:
  /// **'قراءة الفاتورة غير مفعّلة — لم يُضبط مفتاح Gemini في ملف .env.'**
  String get gmNotConfigured;

  /// No description provided for @gmTooLarge.
  ///
  /// In ar, this message translates to:
  /// **'الصورة أكبر من {mb} ميجابايت — جرّب صورة أخفّ.'**
  String gmTooLarge(int mb);

  /// No description provided for @gmTimeout.
  ///
  /// In ar, this message translates to:
  /// **'استغرقت القراءة وقتاً طويلاً — أعد المحاولة، أو صوّر الصفحة على جزأين إن كانت طويلة جداً.'**
  String get gmTimeout;

  /// No description provided for @gmNoInternet.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال بالإنترنت.'**
  String get gmNoInternet;

  /// No description provided for @gmConnectFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال بخدمة القراءة: {error}'**
  String gmConnectFailed(String error);

  /// No description provided for @gmUnexpected.
  ///
  /// In ar, this message translates to:
  /// **'خطأ غير متوقع: {error}'**
  String gmUnexpected(String error);

  /// No description provided for @gmEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لم تُرجع الخدمة أي محتوى.'**
  String get gmEmpty;

  /// No description provided for @gmCutOff.
  ///
  /// In ar, this message translates to:
  /// **'الصفحة طويلة جداً فانقطع الرد — صوّرها على جزأين.'**
  String get gmCutOff;

  /// No description provided for @gmBadReply.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فهم ردّ الخدمة: {error}'**
  String gmBadReply(String error);

  /// No description provided for @gmBadLines.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فهم صيغة الأسطر: {error}'**
  String gmBadLines(String error);

  /// No description provided for @gmQuota.
  ///
  /// In ar, this message translates to:
  /// **'انتهت القراءات المجانية لهذا اليوم (حدّ Google المجاني) — {when}.'**
  String gmQuota(String when);

  /// No description provided for @gmQuotaTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'تتجدد غداً'**
  String get gmQuotaTomorrow;

  /// No description provided for @gmQuotaIn.
  ///
  /// In ar, this message translates to:
  /// **'تتجدد بعد نحو {duration}'**
  String gmQuotaIn(String duration);

  /// No description provided for @durMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{n} دقيقة'**
  String durMinutes(int n);

  /// No description provided for @durHours.
  ///
  /// In ar, this message translates to:
  /// **'{n, plural, =1{ساعة} =2{ساعتين} other{{n} ساعات}}'**
  String durHours(int n);

  /// No description provided for @durHoursMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{hours} و{minutes}'**
  String durHoursMinutes(String hours, String minutes);

  /// No description provided for @gmTooMany.
  ///
  /// In ar, this message translates to:
  /// **'طلبات كثيرة على خدمة القراءة — انتظر قليلاً ثم أعد المحاولة.'**
  String get gmTooMany;

  /// No description provided for @gmBusy.
  ///
  /// In ar, this message translates to:
  /// **'خدمة Google مزدحمة حالياً — انتظر دقيقة ثم اضغط «إعادة المحاولة».'**
  String get gmBusy;

  /// No description provided for @gmStatus.
  ///
  /// In ar, this message translates to:
  /// **'Gemini استجاب {code}: {reason}'**
  String gmStatus(int code, String reason);

  /// No description provided for @notifChannel.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات المخزون'**
  String get notifChannel;

  /// No description provided for @notifChannelDesc.
  ///
  /// In ar, this message translates to:
  /// **'الصلاحية والمخزون المنخفض'**
  String get notifChannelDesc;

  /// No description provided for @notifExpired.
  ///
  /// In ar, this message translates to:
  /// **'{n} منتهية الصلاحية'**
  String notifExpired(int n);

  /// No description provided for @notifExpiring.
  ///
  /// In ar, this message translates to:
  /// **'{n} تقترب من الانتهاء'**
  String notifExpiring(int n);

  /// No description provided for @notifOut.
  ///
  /// In ar, this message translates to:
  /// **'{n} نفدت من المخزون'**
  String notifOut(int n);

  /// No description provided for @notifLow.
  ///
  /// In ar, this message translates to:
  /// **'{n} منخفضة المخزون'**
  String notifLow(int n);

  /// No description provided for @notifTitle.
  ///
  /// In ar, this message translates to:
  /// **'🔔 صيدليتي — يحتاج مراجعة'**
  String get notifTitle;

  /// No description provided for @invoiceLabel.
  ///
  /// In ar, this message translates to:
  /// **'🧾 فاتورة {when}'**
  String invoiceLabel(String when);

  /// No description provided for @invoiceLabelFrom.
  ///
  /// In ar, this message translates to:
  /// **'🧾 من فاتورة بتاريخ {date}'**
  String invoiceLabelFrom(String date);

  /// No description provided for @authNoIdentity.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إنشاء هوية الجهاز'**
  String get authNoIdentity;

  /// No description provided for @authAnonDisabled.
  ///
  /// In ar, this message translates to:
  /// **'المصادقة المجهولة غير مفعّلة في Firebase.\nالحل: Console ← Authentication ← Sign-in method ← Anonymous ← Enable.'**
  String get authAnonDisabled;

  /// No description provided for @authOffline.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال — المزامنة موقوفة مؤقتاً.'**
  String get authOffline;

  /// No description provided for @authFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت المصادقة: {error}'**
  String authFailed(String error);

  /// No description provided for @backupSubject.
  ///
  /// In ar, this message translates to:
  /// **'نسخة احتياطية — صيدليتي'**
  String get backupSubject;

  /// No description provided for @backupNotFound.
  ///
  /// In ar, this message translates to:
  /// **'الملف غير موجود'**
  String get backupNotFound;

  /// No description provided for @backupReadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت قراءة الملف: {error}'**
  String backupReadFailed(String error);

  /// No description provided for @backupInvalid.
  ///
  /// In ar, this message translates to:
  /// **'الملف ليس نسخة احتياطية صالحة'**
  String get backupInvalid;

  /// No description provided for @backupNoItems.
  ///
  /// In ar, this message translates to:
  /// **'الملف لا يحتوي مواد'**
  String get backupNoItems;

  /// No description provided for @lookupLocal.
  ///
  /// In ar, this message translates to:
  /// **'قاعدتك المحلية'**
  String get lookupLocal;

  /// No description provided for @lookupRegistry.
  ///
  /// In ar, this message translates to:
  /// **'قاموس الصيدليات المشترك'**
  String get lookupRegistry;

  /// No description provided for @barcodeConflict.
  ///
  /// In ar, this message translates to:
  /// **'الباركود {barcode} مسجَّل لمادة أخرى'**
  String barcodeConflict(String barcode);

  /// No description provided for @phSyncOff.
  ///
  /// In ar, this message translates to:
  /// **'المزامنة غير مفعّلة'**
  String get phSyncOff;

  /// No description provided for @phOwnerOnly.
  ///
  /// In ar, this message translates to:
  /// **'فقط صاحب المخزون يُخرج الأجهزة'**
  String get phOwnerOnly;

  /// No description provided for @phCantRemoveOwner.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إخراج صاحب المخزون'**
  String get phCantRemoveOwner;

  /// No description provided for @phNotMember.
  ///
  /// In ar, this message translates to:
  /// **'الجهاز ليس عضواً'**
  String get phNotMember;

  /// No description provided for @alertsTitle.
  ///
  /// In ar, this message translates to:
  /// **'🔔 التنبيهات'**
  String get alertsTitle;

  /// No description provided for @alertsTooltip.
  ///
  /// In ar, this message translates to:
  /// **'التنبيهات'**
  String get alertsTooltip;

  /// No description provided for @alertsSecExpired.
  ///
  /// In ar, this message translates to:
  /// **'⛔ منتهية الصلاحية ({n})'**
  String alertsSecExpired(int n);

  /// No description provided for @alertsSecUrgent.
  ///
  /// In ar, this message translates to:
  /// **'⏳ تنتهي خلال شهر ({n})'**
  String alertsSecUrgent(int n);

  /// No description provided for @alertsSecOut.
  ///
  /// In ar, this message translates to:
  /// **'🚫 نافدة ({n})'**
  String alertsSecOut(int n);

  /// No description provided for @alertsSecLow.
  ///
  /// In ar, this message translates to:
  /// **'⚠️ مخزون منخفض ({n})'**
  String alertsSecLow(int n);

  /// No description provided for @alertsSecSoon.
  ///
  /// In ar, this message translates to:
  /// **'🕐 تنتهي خلال 3 أشهر ({n})'**
  String alertsSecSoon(int n);

  /// No description provided for @alertOutDetail.
  ///
  /// In ar, this message translates to:
  /// **'نفدت من المخزون'**
  String get alertOutDetail;

  /// No description provided for @alertLowDetail.
  ///
  /// In ar, this message translates to:
  /// **'الكمية {qty} — حد التنبيه {min}'**
  String alertLowDetail(int qty, int min);

  /// No description provided for @alertDone.
  ///
  /// In ar, this message translates to:
  /// **'تمّ'**
  String get alertDone;

  /// No description provided for @alertRestore.
  ///
  /// In ar, this message translates to:
  /// **'إرجاع'**
  String get alertRestore;

  /// No description provided for @alertHidden.
  ///
  /// In ar, this message translates to:
  /// **'أُخفي التنبيه'**
  String get alertHidden;

  /// No description provided for @alertsShowHidden.
  ///
  /// In ar, this message translates to:
  /// **'إظهار المخفية ({n})'**
  String alertsShowHidden(int n);

  /// No description provided for @alertsHideHidden.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء المخفية'**
  String get alertsHideHidden;

  /// No description provided for @alertsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'✅ لا تنبيهات — كل شيء سليم'**
  String get alertsEmpty;

  /// No description provided for @alertsEmptySub.
  ///
  /// In ar, this message translates to:
  /// **'تظهر هنا المواد المنتهية وقاربة الانتهاء والنافدة والمنخفضة'**
  String get alertsEmptySub;

  /// No description provided for @alertsBellCount.
  ///
  /// In ar, this message translates to:
  /// **'{n} تنبيه'**
  String alertsBellCount(int n);

  /// No description provided for @notifNewTitle.
  ///
  /// In ar, this message translates to:
  /// **'🔔 {n, plural, =1{تنبيه جديد} =2{تنبيهان جديدان} few{{n} تنبيهات جديدة} many{{n} تنبيهاً جديداً} other{{n} تنبيه جديد}}'**
  String notifNewTitle(int n);

  /// No description provided for @notifWeeklyTitle.
  ///
  /// In ar, this message translates to:
  /// **'📋 ملخّص الأسبوع — صيدليتي'**
  String get notifWeeklyTitle;

  /// No description provided for @notifLineExpired.
  ///
  /// In ar, this message translates to:
  /// **'⛔ {name} — انتهت'**
  String notifLineExpired(String name);

  /// No description provided for @notifLineUrgent.
  ///
  /// In ar, this message translates to:
  /// **'⏳ {name} — {n} يوماً'**
  String notifLineUrgent(String name, int n);

  /// No description provided for @notifLineToday.
  ///
  /// In ar, this message translates to:
  /// **'⏳ {name} — تنتهي اليوم'**
  String notifLineToday(String name);

  /// No description provided for @notifLineOut.
  ///
  /// In ar, this message translates to:
  /// **'🚫 {name} — نفدت'**
  String notifLineOut(String name);

  /// No description provided for @notifLineLow.
  ///
  /// In ar, this message translates to:
  /// **'⚠️ {name} — بقي {n}'**
  String notifLineLow(String name, int n);

  /// No description provided for @notifLineSoon.
  ///
  /// In ar, this message translates to:
  /// **'🕐 {name} — {n} يوماً'**
  String notifLineSoon(String name, int n);

  /// No description provided for @notifMore.
  ///
  /// In ar, this message translates to:
  /// **'و{n} أخرى'**
  String notifMore(int n);

  /// No description provided for @formMinQty.
  ///
  /// In ar, this message translates to:
  /// **'🔔 حد التنبيه (اختياري)'**
  String get formMinQty;

  /// No description provided for @formMinQtyHint.
  ///
  /// In ar, this message translates to:
  /// **'الافتراضي {n}'**
  String formMinQtyHint(int n);

  /// No description provided for @settingsLowStock.
  ///
  /// In ar, this message translates to:
  /// **'حد المخزون المنخفض الافتراضي'**
  String get settingsLowStock;

  /// No description provided for @settingsLowStockSub.
  ///
  /// In ar, this message translates to:
  /// **'تُنبَّه حين تصل الكمية إليه — لكل المواد بلا حد خاص، ومشترك بين أجهزة الصيدلية.'**
  String get settingsLowStockSub;
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
