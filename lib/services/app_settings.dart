import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_keys.dart';

/// إعدادات التطبيق المحفوظة على الجهاز.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _kContribute = 'contribute_to_registry';
  static const _kGs1Repair = 'gs1_barcode_repair_done';
  static const _kPriceRepair = 'invoice_price_repair_done';
  static const _kOwnerClaim = 'owner_claim_done';
  static const _kNotifications = 'stock_notifications_enabled';
  static const _kPharmacyId = 'pharmacy_id';
  static const _kPharmacyBackfill = 'pharmacy_backfill_done';
  static const _kWelcomeSeen = 'welcome_seen';
  static const _kLanguage = 'ui_language';
  static const _kCurrency = 'display_currency';
  static const _kUsdRate = 'usd_rate';

  SharedPreferences? _prefs;

  /// هل يساهم التطبيق بالاسم والصورة في قاعدة الباركود المشتركة؟
  /// الاستفادة من القاعدة تبقى فعّالة دائماً بغض النظر عن هذا الخيار.
  bool _contributeToRegistry = true;
  bool get contributeToRegistry => _contributeToRegistry;

  /// هل نُفّذ ترحيل الباركودات القديمة إلى صيغة GTIN؟ (مرة واحدة فقط)
  bool _gs1RepairDone = false;
  bool get gs1RepairDone => _gs1RepairDone;

  bool _priceRepairDone = false;
  bool get priceRepairDone => _priceRepairDone;

  /// هل وُسمت السجلات السحابية القديمة بمالكها؟ (مرة واحدة فقط)
  bool _ownerClaimDone = false;
  bool get ownerClaimDone => _ownerClaimDone;

  /// تنبيه محلي عند فتح التطبيق ووجود أدوية منتهية/قاربة الانتهاء أو
  /// مخزون منخفض/نافد. مفعّل افتراضياً، قابل للإيقاف من الإعدادات.
  bool _stockNotificationsEnabled = true;
  bool get stockNotificationsEnabled => _stockNotificationsEnabled;

  /// معرّف الصيدلية المشتركة لهذا الجهاز — null قبل أول مزامنة ناجحة.
  String? _pharmacyId;
  String? get pharmacyId => _pharmacyId;

  /// هل وُسمت كل السجلات المحلية بمعرّف الصيدلية؟ (مرة واحدة فقط)
  bool _pharmacyBackfillDone = false;
  bool get pharmacyBackfillDone => _pharmacyBackfillDone;

  /// هل رأى هذا الجهاز شرائح الترحيب؟ تظهر في أول تشغيل فقط، ويعيدها
  /// المستخدم من الإعدادات.
  bool _welcomeSeen = false;
  bool get welcomeSeen => _welcomeSeen;

  /// لغة الواجهة (`ar` أو `en`) — محلية لكل جهاز، لا تُزامَن، والبيانات
  /// نفسها (أسماء الأدوية…) لا تُترجم.
  String _language = 'ar';
  String get language => _language;

  /// عملة **العرض** (`IQD` أو `USD`). الأسعار تُخزَّن وتُزامَن بالدينار
  /// دائماً؛ الدولار تحويل للعرض والإدخال فقط بسعر [usdRate].
  String _currency = 'IQD';
  String get currency => _currency;

  /// كم ديناراً للدولار الواحد — يضبطه المستخدم يدوياً (سعر السوق).
  double? _usdRate;
  double? get usdRate => _usdRate;

  /// المفتاح المستخدَم دائماً هو المفتاح المضمّن من ملف .env
  String get geminiKey => ApiKeys.geminiDefault;

  bool get hasGeminiKey => geminiKey.trim().isNotEmpty;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _contributeToRegistry = _prefs?.getBool(_kContribute) ?? true;
    _gs1RepairDone = _prefs?.getBool(_kGs1Repair) ?? false;
    _priceRepairDone = _prefs?.getBool(_kPriceRepair) ?? false;
    _ownerClaimDone = _prefs?.getBool(_kOwnerClaim) ?? false;
    _stockNotificationsEnabled = _prefs?.getBool(_kNotifications) ?? true;
    _pharmacyId = _prefs?.getString(_kPharmacyId);
    _pharmacyBackfillDone = _prefs?.getBool(_kPharmacyBackfill) ?? false;
    _welcomeSeen = _prefs?.getBool(_kWelcomeSeen) ?? false;
    _language = _prefs?.getString(_kLanguage) == 'en' ? 'en' : 'ar';
    _usdRate = _prefs?.getDouble(_kUsdRate);
    _currency = _prefs?.getString(_kCurrency) == 'USD' && _usdRate != null
        ? 'USD'
        : 'IQD';
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    _language = value == 'en' ? 'en' : 'ar';
    notifyListeners();
    await _prefs?.setString(_kLanguage, _language);
  }

  /// `false` إن طُلب الدولار بلا سعر صرف — لا تُعرض أسعار بسعر لم يُختر.
  Future<bool> setCurrency(String value) async {
    final next = value == 'USD' ? 'USD' : 'IQD';
    if (next == 'USD' && _usdRate == null) return false;
    _currency = next;
    notifyListeners();
    await _prefs?.setString(_kCurrency, next);
    return true;
  }

  Future<bool> setUsdRate(double value) async {
    if (!(value > 0)) return false;
    _usdRate = value;
    notifyListeners();
    await _prefs?.setDouble(_kUsdRate, value);
    return true;
  }

  Future<void> markWelcomeSeen() async {
    _welcomeSeen = true;
    await _prefs?.setBool(_kWelcomeSeen, true);
  }

  Future<void> resetWelcome() async {
    _welcomeSeen = false;
    await _prefs?.setBool(_kWelcomeSeen, false);
  }

  Future<void> markPriceRepairDone() async {
    _priceRepairDone = true;
    await _prefs?.setBool(_kPriceRepair, true);
  }

  Future<void> markGs1RepairDone() async {
    _gs1RepairDone = true;
    await _prefs?.setBool(_kGs1Repair, true);
  }

  Future<void> markOwnerClaimDone() async {
    _ownerClaimDone = true;
    await _prefs?.setBool(_kOwnerClaim, true);
  }

  Future<void> setPharmacyId(String value) async {
    _pharmacyId = value;
    notifyListeners();
    await _prefs?.setString(_kPharmacyId, value);
  }

  Future<void> markPharmacyBackfillDone() async {
    _pharmacyBackfillDone = true;
    await _prefs?.setBool(_kPharmacyBackfill, true);
  }

  Future<void> setContributeToRegistry(bool value) async {
    _contributeToRegistry = value;
    notifyListeners();
    await _prefs?.setBool(_kContribute, value);
  }

  Future<void> setStockNotificationsEnabled(bool value) async {
    _stockNotificationsEnabled = value;
    notifyListeners();
    await _prefs?.setBool(_kNotifications, value);
  }
}
