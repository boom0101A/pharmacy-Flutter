import 'dart:async';

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

  /// بدائل السحابة للاختبارات.
  @visibleForTesting
  Future<void> Function(String pid, List<String> keys)? cloudWrite;
  @visibleForTesting
  Future<List<String>> Function(String pid)? cloudRead;
  @visibleForTesting
  Duration cloudReadTimeout = const Duration(seconds: 8);

  @visibleForTesting
  void resetForTest([Set<String> keys = const {}]) {
    _db = null;
    _keys = {...keys};
    cloudWrite = null;
    cloudRead = null;
    cloudReadTimeout = const Duration(seconds: 8);
  }

  bool get _hasCloud => _db != null || cloudWrite != null;

  /// مع التخزين الدائم لا يكتمل مستقبل الكتابة إلا بتأكيد الخادم — بلا
  /// إنترنت يعلّق للأبد، والكتابة نفسها محفوظة في الطابور وتُرفع لاحقاً.
  /// لذا لا يُنتظر أبداً؛ يُعاد الترحيل فقط إن رُفضت الكتابة فعلاً.
  void _write(String pid, List<String> keys, SharedPreferences prefs) {
    final Future<void> write =
        cloudWrite?.call(pid, keys) ??
        _db!.collection(_collection).doc(pid).set({
          'pharmacyId': pid,
          'keys': FieldValue.arrayUnion(keys),
        }, SetOptions(merge: true));
    unawaited(
      write.catchError((Object e) async {
        debugPrint('تعذّر رفع قرارات «ليست مكرّرة»: $e');
        await prefs.setBool(_kMigrated, false);
      }),
    );
  }

  Future<List<String>> _read(String pid) async {
    final read = cloudRead;
    if (read != null) return read(pid);
    final snap = await _db!.collection(_collection).doc(pid).get();
    return List<String>.from((snap.data()?['keys'] as List?) ?? const []);
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
    final pid = AppSettings.instance.pharmacyId;
    if (!_hasCloud || pid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_kMigrated) ?? false) && _keys.isNotEmpty) {
        // في الطابور الدائم الآن — يُعاد العلم إلى false إن رُفضت
        await prefs.setBool(_kMigrated, true);
        _write(pid, _keys.toList(), prefs);
      }
      final cloud = (await _read(pid).timeout(cloudReadTimeout)).toSet();
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
    final pid = AppSettings.instance.pharmacyId;
    if (!_hasCloud || pid == null) {
      // يُرفع مع الترحيل في المزامنة التالية
      await prefs.setBool(_kMigrated, false);
      return;
    }
    _write(pid, [key], prefs);
  }

  /// اتحاد مجموعتين من القرارات — لا يُفقد قرار اتُّخذ على أي جهاز.
  @visibleForTesting
  static Set<String> merge(Set<String> a, Set<String> b) => {...a, ...b};
}
