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

  @override
  String get typeMedicine => '💊 Medicine';

  @override
  String get typeSupply => '🩹 Medical supply';

  @override
  String get homeTitle => '💊 Saydaliyati';

  @override
  String priceRepaired(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n items',
      one: '1 item',
    );
    return 'Fixed the price of $_temp0 misread by the smart invoice';
  }

  @override
  String invoiceAddedNew(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n new items added',
      one: '1 new item added',
    );
    return '$_temp0';
  }

  @override
  String invoiceMerged(int n) {
    return '$n merged with existing items';
  }

  @override
  String invoiceMergedWithin(int n) {
    return '($n of them repeated within the same invoice)';
  }

  @override
  String deletedItem(String name) {
    return '🗑️ Deleted \"$name\"';
  }

  @override
  String get undo => 'Undo';

  @override
  String incompleteBanner(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n items have',
      one: '1 item has',
    );
    return '$_temp0 incomplete data';
  }

  @override
  String get completeData => 'Complete data';

  @override
  String get scanBarcode => 'Scan barcode';

  @override
  String get smartInvoice => 'Smart invoice';

  @override
  String get add => 'Add';

  @override
  String get statMedicines => 'Medicines';

  @override
  String get statSupplies => 'Supplies';

  @override
  String statTotalValue(String currency) {
    return 'Total value ($currency)';
  }

  @override
  String statValueMissing(int n) {
    return 'Value ($n without price)';
  }

  @override
  String get searchSupplies => 'Search supplies by name...';

  @override
  String get searchMedicines => 'Search by name or barcode...';

  @override
  String get scanInSearch => 'Scan a barcode to search';

  @override
  String get filters => 'Filters';

  @override
  String get quickFilter => '📌 Quick filters';

  @override
  String get filterExpiring => '⏳ Expiring soon';

  @override
  String get filterLowStock => '⚠️ Low or out (≤5)';

  @override
  String filterIncomplete(int n) {
    return '📝 Incomplete ($n)';
  }

  @override
  String get filterNoBarcode => '📊 No barcode';

  @override
  String get filterHasImage => '📷 Has image';

  @override
  String get filterNoImage => '🖼️ No image';

  @override
  String priceRange(String currency) {
    return '💰 Price range ($currency)';
  }

  @override
  String get quantityRange => '📦 Quantity range';

  @override
  String get sortBy => '🔃 Sort by';

  @override
  String get sortNewest => '🕐 Newest';

  @override
  String get sortName => '🔤 Name';

  @override
  String get sortPrice => '💲 Price';

  @override
  String get sortQuantity => '📦 Quantity';

  @override
  String get resetFilters => 'Reset filters';

  @override
  String duplicatesBanner(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n duplicates need review',
      one: '1 duplicate group needs review',
    );
    return '$_temp0';
  }

  @override
  String get review => 'Review';

  @override
  String showingCountMedicines(int shown, int total) {
    return 'Showing $shown of $total medicines';
  }

  @override
  String showingCountSupplies(int shown, int total) {
    return 'Showing $shown of $total supplies';
  }

  @override
  String get clearFilters => '✕ Clear filters';

  @override
  String get emptyNoResults => 'No matching results';

  @override
  String get emptyNoSupplies => 'No supplies yet';

  @override
  String get emptyNoMedicines => 'No medicines yet';

  @override
  String get emptyTryFilters => 'Try changing the search or filters';

  @override
  String get emptyHintInvoice =>
      'Tap “Smart invoice” to add all its items at once';

  @override
  String get emptyHintAddSupply => 'Tap “+” to add your first supply';

  @override
  String get emptyHintScan => 'Tap “Scan barcode” to start';

  @override
  String get syncAllGood => 'Everything is working fine ✅';

  @override
  String get ok => 'OK';

  @override
  String get rangeFrom => 'From';

  @override
  String get rangeTo => 'To';

  @override
  String get cardNoBarcode => 'No barcode';

  @override
  String get cardBarcode => 'Barcode';

  @override
  String get price => 'Price';

  @override
  String get quantity => 'Quantity';

  @override
  String get cardIncomplete => '📝 Incomplete';

  @override
  String get cardOut => 'Out';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get expired => 'Expired';

  @override
  String expiresOn(String date) {
    return 'Expires $date';
  }

  @override
  String get syncLocal => 'Saved locally';

  @override
  String get syncOffline => 'Offline — saved locally';

  @override
  String get syncSyncing => 'Syncing…';

  @override
  String get syncSynced => 'Cloud synced ✓';

  @override
  String get syncFailed => 'Sync failed';

  @override
  String get syncErrPermission =>
      'Firestore security rules deny access.\nFix: Firebase Console → Firestore Database → Rules → allow read and write on the medicines collection, then Publish.';

  @override
  String get syncErrNotFound =>
      'No Firestore database exists in this project.\nFix: Firebase Console → Build → Firestore Database → Create database.';

  @override
  String get syncErrUnavailable =>
      'No internet connection — data is saved locally.';

  @override
  String get syncErrPrecondition =>
      'Firestore is not enabled or needs setup in the Console.';

  @override
  String get syncErrUnauthenticated =>
      'Device identity is not ready.\nFix: Firebase Console → Authentication → Sign-in method → enable Anonymous.';

  @override
  String get syncErrUnknown => 'Unknown error';

  @override
  String syncDenied(int n) {
    return 'The cloud rejects uploading $n items from this phone — the rest synced. Check the Firestore rules.';
  }

  @override
  String syncSkipped(int n) {
    return 'Skipped $n invalid records in the cloud.';
  }

  @override
  String syncRelinked(int n, String names) {
    return 'Relinked $n items registered to another pharmacy: $names.';
  }

  @override
  String syncDoneWithNotes(String notes) {
    return 'Synced. $notes';
  }

  @override
  String get listSeparator => ', ';

  @override
  String expiredDaysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days',
      one: '1 day',
    );
    return 'Expired $_temp0 ago';
  }

  @override
  String get expiresToday => 'Expires today';

  @override
  String daysLeft(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days',
      one: '1 day',
    );
    return '$_temp0 left';
  }

  @override
  String get itemDeleted => 'This item was deleted';

  @override
  String shareLinePrice(String v) {
    return 'Price: $v';
  }

  @override
  String shareLineQty(int v) {
    return 'Quantity: $v';
  }

  @override
  String shareLineExpiry(String v) {
    return 'Expiry: $v';
  }

  @override
  String shareLineBarcode(String v) {
    return 'Barcode: $v';
  }

  @override
  String shareLineCompany(String v) {
    return 'Company: $v';
  }

  @override
  String get share => 'Share';

  @override
  String get rowExpiry => '📅 Expiry';

  @override
  String get rowBarcode => '📊 Barcode';

  @override
  String get barcodeCopied => 'Barcode copied';

  @override
  String get rowCompany => '🏭 Company';

  @override
  String get rowCategory => '🧪 Form';

  @override
  String get rowSection => '🗂️ Section';

  @override
  String get rowAdded => '➕ Added';

  @override
  String addedOn(String date) {
    return 'Added $date';
  }

  @override
  String get rowUpdated => '🕓 Last edited';

  @override
  String get invoiceHistory => '🧾 Invoice history';

  @override
  String get noInvoicesForItem => 'No saved invoices for this item';

  @override
  String get unknownSupplier => 'Unknown supplier';

  @override
  String get badgeExpired => '⛔ Expired';

  @override
  String get badgeExpiring => '⏳ Expiring soon';

  @override
  String get badgeSoldOut => '🚫 Sold out';

  @override
  String get badgeLowStock => '⚠️ Low stock';

  @override
  String get badgeIncomplete => '📝 Incomplete data';

  @override
  String get increase => 'Increase';

  @override
  String get decrease => 'Decrease';

  @override
  String get stockValue => 'Stock value';
}
