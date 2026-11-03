// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsLanguageCurrency => '🌐 Language & currency';

  @override
  String get languageLabel => 'Language';

  @override
  String get currencyLabel => 'Currency';

  @override
  String get currencyIqd => 'Dinar';

  @override
  String get currencyUsd => 'Dollar';

  @override
  String usdRateLine(String rate) {
    return '1 \$ = $rate IQD';
  }

  @override
  String get usdRateEdit => 'Edit exchange rate';

  @override
  String get usdRateTitle => 'Dollar exchange rate';

  @override
  String get usdRateHint =>
      'How many dinars per dollar? (the market rate you use)';

  @override
  String get usdRateField => '1 dollar = … dinars';

  @override
  String get usdRateInvalid => 'Enter a rate greater than zero';

  @override
  String get currencyNote =>
      'Prices are always stored and synced in dinars; the dollar is for display and entry only. Smart invoices and the invoice log stay in dinars.';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';
}
