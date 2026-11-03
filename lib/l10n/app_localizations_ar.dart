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
}
