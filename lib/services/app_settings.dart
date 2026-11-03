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
    notifyListeners();
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
