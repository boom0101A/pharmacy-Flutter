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
