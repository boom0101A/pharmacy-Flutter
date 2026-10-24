import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// قرارات «ليست مكرّرة» — مشتركة بين كل أجهزة الصيدلية.
///
/// كانت تُحفظ على الهاتف الذي اتُّخذ عليه القرار وحده، فيعود نفس التكرار
/// للظهور على هاتف الأخ. الآن: مستند واحد لكل صيدلية في السحابة
/// (`dupDismissals/{pharmacyId}`) مع نسخة محلية تعمل بلا إنترنت.
class DuplicateDismissals extends ChangeNotifier {
  DuplicateDismissals._();
  static final DuplicateDismissals instance = DuplicateDismissals._();

  static const _collection = 'dupDismissals';
  static const _kLocal = 'dismissed_duplicate_groups';
  static const _kMigrated = 'dismissed_duplicate_groups_migrated';

  FirebaseFirestore? _db;
  Set<String> _keys = {};

  Set<String> get keys => _keys;

  /// تُستدعى من SyncService بعد تهيئة Firebase.
  static void attach(FirebaseFirestore db) => instance._db = db;

  @visibleForTesting
  void resetForTest([Set<String> keys = const {}]) {
    _db = null;
    _keys = {...keys};
  }

  /// النسخة المحلية — فورية وتعمل بلا اتصال.
  /// لا يرمي: تعذّر قراءتها لا يجوز أن يوقف تحميل المخزون نفسه.
  Future<void> loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final local = (prefs.getStringList(_kLocal) ?? const []).toSet();
      if (!local.every(_keys.contains)) {
        _keys = merge(_keys, local);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('تعذّرت قراءة قرارات «ليست مكرّرة» المحلية: $e');
    }
  }

  /// يدمج ما في السحابة مع المحلي، ويرفع القرارات المحلية القديمة مرة واحدة.
  /// لا يرمي — الفشل يعني المحاولة في المزامنة التالية.
  Future<void> syncWithCloud() async {
    final db = _db;
    final pid = AppSettings.instance.pharmacyId;
    if (db == null || pid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ref = db.collection(_collection).doc(pid);
      if (!(prefs.getBool(_kMigrated) ?? false) && _keys.isNotEmpty) {
        await ref.set({
          'pharmacyId': pid,
          'keys': FieldValue.arrayUnion(_keys.toList()),
        }, SetOptions(merge: true));
        await prefs.setBool(_kMigrated, true);
      }
      final snap = await ref.get();
      final cloud = List<String>.from(
        (snap.data()?['keys'] as List?) ?? const [],
      ).toSet();
      final next = merge(_keys, cloud);
      if (!setEquals(next, _keys)) {
        _keys = next;
        await prefs.setStringList(_kLocal, _keys.toList());
        notifyListeners();
      }
    } catch (e) {
      debugPrint('تعذّرت مزامنة قرارات «ليست مكرّرة»: $e');
    }
  }

  /// قرار جديد: محلياً فوراً، ثم السحابة (إن تعذّرت يُرفع مع الترحيل لاحقاً).
  Future<void> add(String key) async {
    if (_keys.contains(key)) return;
    _keys = {..._keys, key};
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kLocal, _keys.toList());
    final db = _db;
    final pid = AppSettings.instance.pharmacyId;
    if (db == null || pid == null) {
      await prefs.setBool(_kMigrated, false);
      return;
    }
    try {
      await db.collection(_collection).doc(pid).set({
        'pharmacyId': pid,
        'keys': FieldValue.arrayUnion([key]),
      }, SetOptions(merge: true));
    } catch (e) {
      // يُعاد رفعه مع الترحيل في المزامنة التالية
      await prefs.setBool(_kMigrated, false);
      debugPrint('تعذّر رفع قرار «ليست مكرّرة»: $e');
    }
  }

  /// اتحاد مجموعتين من القرارات — لا يُفقد قرار اتُّخذ على أي جهاز.
  @visibleForTesting
  static Set<String> merge(Set<String> a, Set<String> b) => {...a, ...b};
}
