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
}
