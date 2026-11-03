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

  @override
  String get appName => 'Saydaliyati';

  @override
  String get splashTagline => 'Your pharmacy stock… smarter and simpler';

  @override
  String splashVersion(String version) {
    return 'Version $version · Secure cloud sync';
  }

  @override
  String get splashLoading => 'Loading';

  @override
  String get splashProgress => 'Progress';

  @override
  String get welcomeSkip => 'Skip';

  @override
  String get welcomeNext => 'Next';

  @override
  String get welcomeStart => 'Get started';

  @override
  String welcomeSlideLabel(int n) {
    return 'Slide $n';
  }

  @override
  String get welcome1ChipA => 'Panadol · 24 boxes';

  @override
  String get welcome1ChipB => 'Recognized automatically';

  @override
  String get welcome1Title => 'Scan the barcode, ';

  @override
  String get welcome1Accent => 'add in a second';

  @override
  String get welcome1Body =>
      'Point the camera at the box and the app recognizes the medicine from the dictionary shared between pharmacies.';

  @override
  String get welcome2ChipA => 'Smart invoice reading';

  @override
  String get welcome2ChipB => '12 lines added';

  @override
  String get welcome2Title => 'Snap the invoice, ';

  @override
  String get welcome2Accent => 'we do the rest';

  @override
  String get welcome2Body =>
      'Smart invoices read names, prices and quantities, and flag any doubtful line before saving.';

  @override
  String get welcome3ChipA => '3 medicines expiring soon';

  @override
  String get welcome3ChipB => '2 devices in sync';

  @override
  String get welcome3Title => 'One inventory ';

  @override
  String get welcome3Accent => 'on all your devices';

  @override
  String get welcome3Body =>
      'Instant cloud sync with your colleagues, plus expiry and low-stock alerts before they surprise you.';
}
