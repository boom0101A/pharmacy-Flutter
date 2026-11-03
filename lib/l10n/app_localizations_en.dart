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

  @override
  String get formAlreadyRegistered =>
      'This item is already registered — you are now editing its record';

  @override
  String formBarcodeNoData(String code) {
    return 'Barcode read: $code — no data found, please fill in the fields';
  }

  @override
  String formConfirmedBy(int n) {
    return ' (confirmed by $n pharmacies)';
  }

  @override
  String formFetchedFrom(String source, String confirmed) {
    return 'Medicine data fetched from $source$confirmed ✅';
  }

  @override
  String get formAddIncomingTitle => '📦 Add incoming quantity';

  @override
  String get formAddIncomingHint => 'Quantity received on the invoice';

  @override
  String formAddedNowBalance(int added, int total) {
    return 'Added $added — balance is now $total';
  }

  @override
  String get formExpiryPickerTitle => 'Expiry date';

  @override
  String get formInvalidPrice => 'Invalid price — numbers only';

  @override
  String get formInvalidQty => 'Invalid quantity — enter a whole number';

  @override
  String formSaveFailed(String error) {
    return 'Couldn\'t save: $error';
  }

  @override
  String get formBarcodeTakenTitle => '⚠️ Barcode belongs to another item';

  @override
  String formBarcodeTakenBody(
    String barcode,
    String name,
    int qty,
    String price,
  ) {
    return 'Barcode “$barcode” belongs to “$name”, already registered — quantity $qty at $price.\n\nTwo items can\'t share a barcode. “Edit existing” opens it for updating (supports “+” to add incoming stock to the current balance).';
  }

  @override
  String get editExisting => 'Edit existing';

  @override
  String formBarcodeOwnerBody(
    String barcode,
    String name,
    int qty,
    String price,
  ) {
    return 'Barcode “$barcode” belongs to “$name” — quantity $qty at $price.\n\nTwo items can\'t share a barcode. Fix the barcode, or merge both items from “Review duplicates” in Settings.';
  }

  @override
  String get formSameNameTitle => '⚠️ An item with the same name exists';

  @override
  String formSameNameBody(String name, int qty, String price) {
    return '“$name” is already registered — quantity $qty at $price.\n\nEditing the existing one opens it for updating (supports “+” to add incoming stock). Saving as a separate record keeps both.';
  }

  @override
  String get separateRecord => 'Separate record';

  @override
  String get formTitleEditSupply => 'Edit supply';

  @override
  String get formTitleEditMedicine => 'Edit medicine';

  @override
  String get formTitleNewSupply => 'Add new supply';

  @override
  String get formTitleNewMedicine => 'Add new medicine';

  @override
  String get formType => '🗂️ Type';

  @override
  String get formBarcode => '📊 Barcode';

  @override
  String get formBarcodeHint => 'Type the barcode or scan it';

  @override
  String get formNoBarcode => 'Has no barcode';

  @override
  String get formLookingUp => 'Looking up medicine info...';

  @override
  String get formSupplyImage => '📷 Supply photo';

  @override
  String get formMedicineImage => '📷 Medicine photo';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get formSupplyName => '🩹 Supply name *';

  @override
  String get formMedicineName => '💊 Medicine name *';

  @override
  String get formSupplyNameHint => 'Enter the supply name';

  @override
  String get formMedicineNameHint => 'Enter the medicine name';

  @override
  String get formNameRequired => 'Name is required';

  @override
  String get formCompany => '🏭 Company (optional)';

  @override
  String get formCompanyHint => 'e.g. Juman';

  @override
  String get formCategory => '🧪 Form (optional)';

  @override
  String get formCategoryHint => 'e.g. Tablet, Cream, Syrup…';

  @override
  String formPrice(String currency) {
    return '💰 Price ($currency)';
  }

  @override
  String get formQuantity => '📦 Quantity';

  @override
  String get formExpiry => '📅 Expiry date (optional)';

  @override
  String get notSet => 'Not set';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get saveSupply => 'Save supply';

  @override
  String get saveMedicine => 'Save medicine';

  @override
  String chipExpiry(String date) {
    return '📅 Expiry: $date';
  }

  @override
  String chipBatch(String batch) {
    return '🏷️ Batch: $batch';
  }

  @override
  String get settingsTitle => '⚙️ Settings';

  @override
  String get settingsAlerts => 'Expiry and stock alerts';

  @override
  String get settingsAlertsSub =>
      'A daily notification at 9 AM if items are expired, expiring soon, or low/out of stock.';

  @override
  String get settingsContribute => 'Contribute to the shared dictionary';

  @override
  String get settingsContributeSub =>
      'Send only the medicine\'s name and photo when saving it, to help other pharmacies recognize it.';

  @override
  String get settingsSent => '✅ Sent';

  @override
  String get settingsSentWhat => 'Barcode + medicine name + thumbnail';

  @override
  String get settingsNotSent => '🔒 Not sent';

  @override
  String get settingsNotSentWhat =>
      'Price • quantity • your pharmacy\'s name • your location';

  @override
  String get settingsContributing =>
      'You\'re contributing — thank you, this is what makes the dictionary grow.';

  @override
  String get settingsNotContributing =>
      'Contribution is off. You still benefit from the dictionary when scanning, but your medicines won\'t be added to it.';

  @override
  String get settingsShowWelcome => 'Show the welcome screen';

  @override
  String get backupTitle => '💾 Backup';

  @override
  String get backupSub =>
      'A file holding all items. When saving, send it to WhatsApp, Drive or Downloads — uninstalling erases the app\'s data and changes its sync identity.';

  @override
  String get backupSave => 'Save backup';

  @override
  String get backupRestore => 'Restore';

  @override
  String get syncIdCopied => 'Sync ID copied';

  @override
  String get syncDisabled => 'Sync is not enabled';

  @override
  String syncId(String id) {
    return 'Sync ID: $id… (tap to copy)';
  }

  @override
  String get backupWhereToSave =>
      'Choose where to save the backup: WhatsApp, Drive, or Downloads';

  @override
  String saveFailed(String error) {
    return 'Couldn\'t save: $error';
  }

  @override
  String restoreFailed(String error) {
    return 'Couldn\'t restore: $error';
  }

  @override
  String get restoreFromWhere => 'Restore from where?';

  @override
  String get restorePickFile => 'Choose a file…';

  @override
  String get restoreLastLocal => 'Latest backup on this device';

  @override
  String get restoreTitle => 'Restore backup';

  @override
  String restoreContainsItems(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n items',
      one: '1 item',
    );
    return 'The file contains $_temp0';
  }

  @override
  String restoreAndInvoices(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n invoices',
      one: '1 invoice',
    );
    return ' and $_temp0';
  }

  @override
  String get restoreNote =>
      'New items will be added and older ones updated — nothing existing is deleted.';

  @override
  String get restoreConfirm => 'Restore';

  @override
  String restoreResult(int added, int updated, int skipped) {
    return 'Added $added · updated $updated · unchanged $skipped';
  }

  @override
  String get sharingTitle => '🔗 Share inventory between devices';

  @override
  String get sharingSub =>
      'Link a colleague\'s or assistant\'s phone to the same inventory — any change from any device shows up for everyone.';

  @override
  String get shareWithDevice => 'Share with another device';

  @override
  String get joinInventory => 'Join an inventory';

  @override
  String get linkedDevices => 'Linked devices';

  @override
  String get reviewDuplicates => 'Review duplicates';

  @override
  String invoicesCount(int n) {
    return 'Invoices ($n)';
  }

  @override
  String get pairPrepareFailed =>
      'Couldn\'t prepare — check your internet connection.';

  @override
  String get pairCodeFailed => 'Couldn\'t generate a code — try again.';

  @override
  String get pairRequestFailed => 'Couldn\'t complete the request — try again.';

  @override
  String get pairShareTitle => '🔗 Share inventory with another device';

  @override
  String get pairShareSub =>
      'Give this code to the other device — valid for 10 minutes. After it\'s entered there, approve the request here to share the inventory between both devices.';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get tryAgain => 'Try again';

  @override
  String get pairWaiting => 'Waiting for the other device…';

  @override
  String get pairApproveHint =>
      'Approve only if the device is in front of you and you gave it the code.';

  @override
  String get approve => 'Approve';

  @override
  String get decline => 'Decline';

  @override
  String get pairDone => 'Done! The inventory is now shared.';

  @override
  String get done => 'Done';

  @override
  String get pairCodeExpired => 'The code has expired.';

  @override
  String get pairNewCode => 'Generate a new code';

  @override
  String get pairEnterCode => 'Enter the 6-digit code.';

  @override
  String get pairCodeWrong => 'Incorrect code.';

  @override
  String get pairCodeExpiredAsk => 'The code has expired — ask for a new one.';

  @override
  String get pairCodeUsed => 'This code was already used.';

  @override
  String get pairConnectFailed =>
      'Couldn\'t connect — check the internet and try again.';

  @override
  String get pairJoined => 'Joined! Downloading the inventory…';

  @override
  String get pairJoinTitle => '🔗 Join an existing inventory';

  @override
  String get pairJoinSub =>
      'Enter the code shown on the device that currently owns the inventory.';

  @override
  String get join => 'Join';

  @override
  String get pairApproved => 'Approved! Downloading the inventory…';

  @override
  String get pairDeclined => 'The other device declined the request.';

  @override
  String get pairExpiredBeforeApproval =>
      'The code expired before the other device approved.';

  @override
  String get pairSentWaiting =>
      'Sent — waiting for the other device to approve…';

  @override
  String get pairPromptUnknown => 'Another device wants to join — approve?';

  @override
  String pairPromptDevice(String id) {
    return 'Device $id wants to join — approve?';
  }

  @override
  String get devicesLoadFailed => 'Couldn\'t load — check the internet.';

  @override
  String get removeDeviceTitle => 'Remove device?';

  @override
  String removeDeviceBody(String id) {
    return 'Device $id will no longer see or edit the inventory. Any local copy on that phone stays there.';
  }

  @override
  String get remove => 'Remove';

  @override
  String removeFailed(String error) {
    return 'Couldn\'t remove: $error';
  }

  @override
  String get devicesTitle => '📱 Linked devices';

  @override
  String get devicesSub =>
      'Every device here sees and edits the inventory with its prices and quantities. Remove any device you don\'t recognize.';

  @override
  String deviceName(String id) {
    return 'Device $id';
  }

  @override
  String get deviceOwner => 'Inventory owner';

  @override
  String get deviceThisPhone => 'This phone';

  @override
  String dupLoadFailed(String error) {
    return 'Couldn\'t load items: $error';
  }

  @override
  String dupMergeFailed(String error) {
    return 'Couldn\'t merge — nothing changed: $error';
  }

  @override
  String dupSplitFailed(String error) {
    return 'Couldn\'t separate the barcode: $error';
  }

  @override
  String get dupTitle => '🔍 Review duplicates';

  @override
  String get refresh => 'Refresh';

  @override
  String get dupNone => 'No duplicates ✅';

  @override
  String dupGroupsIntro(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n groups',
      one: '1 group',
    );
    return '$_temp0 — tick the ones that are the same product, then “Merge selected”, or “Not duplicates” if they\'re all different products.';
  }

  @override
  String dupSimilarIntro(int n) {
    return '🔍 Similar names — check before merging ($n)\nClose but not identical names: a typo, an extra word, or another size or strength. Many are genuinely different products — “Not duplicates” hides them on all devices.';
  }

  @override
  String dupShowHidden(int n) {
    return 'Show hidden ($n)';
  }

  @override
  String get dupShowHiddenTitle => 'Show hidden groups';

  @override
  String dupShowHiddenBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n groups',
      one: '1 group',
    );
    return '$_temp0 will return for review on all devices. Items don\'t change.';
  }

  @override
  String get show => 'Show';

  @override
  String dupMergePaused(int n) {
    return 'Merging is paused: $n deletions haven\'t reached the cloud yet. Merging sums quantities and deletes the rest — if a deletion doesn\'t arrive, the items stay on the other phone and quantities double. Connect to the internet, then tap Refresh.';
  }

  @override
  String dupSimilarPercent(int p) {
    return '🔍 Names $p% similar';
  }

  @override
  String get dupSameBarcode => '🏷️ Same barcode — may be different products';

  @override
  String get dupSameName => '📝 Same name in the same section';

  @override
  String get dupDifferentBarcodes =>
      '🏷️ Different barcodes — make sure it isn\'t another size or flavor';

  @override
  String get dupTickHint =>
      'Tick the items that are the same product, then “Merge selected” — unticked ones stay as they are and leave the review.';

  @override
  String get dupPickTwo => 'Pick two items to merge';

  @override
  String dupMergeSelected(int n, int total) {
    return 'Merge selected ($n) · quantity $total';
  }

  @override
  String get dupNotDuplicates => 'Not duplicates';

  @override
  String get dupSplitBarcode => 'Separate barcode';

  @override
  String detQty(int n) {
    return 'Qty $n';
  }

  @override
  String detPrice(String v) {
    return 'Price $v';
  }

  @override
  String detExpiry(String d) {
    return 'Expiry $d';
  }

  @override
  String detEdited(String d) {
    return 'Edited $d';
  }

  @override
  String dupMergeTitle(int n) {
    return 'Merge $n items';
  }

  @override
  String get dupKeptName => 'Name to keep';

  @override
  String dupFinalPrice(String currency) {
    return '💰 Final price ($currency)';
  }

  @override
  String get dupFinalQty => '📦 Final quantity';

  @override
  String dupWillDelete(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n items',
      one: '1 item',
    );
    return '$_temp0 will be deleted from this phone and all shared devices.';
  }

  @override
  String get cdBarcodeTaken =>
      'This barcode belongs to another item — use “Merge” if it\'s the same one';

  @override
  String cdMergeWith(String name) {
    return 'Merge with “$name”';
  }

  @override
  String cdMergeBody(String keep, int qty, String drop) {
    return '“$keep” stays with quantity $qty, and “$drop” is deleted from all devices. Its barcode and photo move over if the kept item lacks them.';
  }

  @override
  String get cdMergeConfirm => 'Merge';

  @override
  String get cdDeleteTitle => 'Delete item';

  @override
  String cdDeleteBody(String name) {
    return '“$name” will be deleted from this phone and all shared devices.';
  }

  @override
  String get cdDeleteConfirm => 'Delete';

  @override
  String get cdTitle => '📝 Complete data';

  @override
  String get cdNoneInSection => 'No incomplete items in this section';

  @override
  String cdListDone(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n items',
      one: '1 item',
    );
    return 'List finished — $_temp0 completed';
  }

  @override
  String get back => 'Back';

  @override
  String cdProgress(int i, int n) {
    return 'Item $i of $n';
  }

  @override
  String get cdNoPrice => 'No price';

  @override
  String get cdNoBarcode => 'No barcode';

  @override
  String cdSimilar(int p) {
    return '🔍 Resembles an existing item ($p%)';
  }

  @override
  String cdMatchLine(String price, int qty) {
    return 'Price $price · quantity $qty';
  }

  @override
  String get cdSameMerge => 'It\'s the same — merge';

  @override
  String cdPrice(String currency) {
    return '💰 Price ($currency)';
  }

  @override
  String get cdQty => '📦 Quantity';

  @override
  String get cdBarcode => '📊 Barcode';

  @override
  String get scanTheBarcode => 'Scan the barcode';

  @override
  String get cdNoBarcodeSub =>
      'A compound or box without a code — it won\'t count as incomplete for lacking a barcode';

  @override
  String get takePhoto => 'Photo';

  @override
  String get theGallery => 'Gallery';

  @override
  String get cdSaveNext => 'Save & next';
}
