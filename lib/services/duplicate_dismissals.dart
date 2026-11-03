import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// قرارات «ليست مكرّرة» — مشتركة بين كل أجهزة الصيدلية.
///
/// مستند واحد لكل صيدلية في السحابة (`dupDismissals/{pharmacyId}`) مع نسخة
/// محلية تعمل بلا إنترنت.
///
/// **السحابة هي المرجع:** المحلي = السحابة + قرارات هذا الهاتف التي لم
/// يؤكّدها الخادم بعد ([_pending]). كان المحلي يُدمج مع السحابة اتحاداً فلا
/// يُحذف قرار أبداً — فـ«إظهار المخفية» على هاتف يعود ويختفي بقرارات الهاتف
/// الآخر المحلية في مزامنته التالية.
class DuplicateDismissals extends ChangeNotifier {
  DuplicateDismissals._();
  static final DuplicateDismissals instance = DuplicateDismissals._();

  static const _collection = 'dupDismissals';
  static const _kLocal = 'dismissed_duplicate_groups';
  static const _kPending = 'dismissed_duplicate_groups_pending';

  /// علم النسخة السابقة: false = قرارات محلية لم تُرفع بعد.
  static const _kMigrated = 'dismissed_duplicate_groups_migrated';

  FirebaseFirestore? _db;
  Set<String> _keys = {};

  /// قرارات هذا الهاتف التي لم يؤكّدها الخادم بعد — لا تضيع إن غابت عن
  /// السحابة لأنها لم تصلها.
  Set<String> _pending = {};

  Set<String> get keys => _keys;

  /// تُستدعى من SyncService بعد تهيئة Firebase.
  static void attach(FirebaseFirestore db) => instance._db = db;

  /// بدائل السحابة للاختبارات.
  @visibleForTesting
  Future<void> Function(String pid, List<String> keys)? cloudWrite;
  @visibleForTesting
  Future<List<String>> Function(String pid)? cloudRead;
  @visibleForTesting
  Future<void> Function(String pid)? cloudClear;
  @visibleForTesting
  Duration cloudReadTimeout = const Duration(seconds: 8);

  @visibleForTesting
  void resetForTest([Set<String> keys = const {}]) {
    _db = null;
    _keys = {...keys};
    _pending = {};
    cloudWrite = null;
    cloudRead = null;
    cloudClear = null;
    cloudReadTimeout = const Duration(seconds: 8);
  }

  bool get _hasCloud => _db != null || cloudWrite != null;

  Future<void> _savePending(SharedPreferences prefs) =>
      prefs.setStringList(_kPending, _pending.toList());

  /// مع التخزين الدائم لا يكتمل مستقبل الكتابة إلا بتأكيد الخادم — بلا
  /// إنترنت يعلّق للأبد، والكتابة نفسها محفوظة في الطابور وتُرفع لاحقاً.
  /// لذا لا يُنتظر أبداً. عند التأكيد تخرج [keys] من المعلّقة.
  void _write(String pid, List<String> keys, SharedPreferences prefs) {
    final Future<void> write =
        cloudWrite?.call(pid, keys) ??
        _db!.collection(_collection).doc(pid).set({
          'pharmacyId': pid,
          'keys': FieldValue.arrayUnion(keys),
        }, SetOptions(merge: true));
    unawaited(
      write
          .then((_) async {
            _pending.removeAll(keys);
            await _savePending(prefs);
          })
          .catchError((Object e) {
            // تبقى معلّقة وتُعاد في المزامنة التالية
            debugPrint('تعذّر رفع قرارات «ليست مكرّرة»: $e');
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
      _pending = {..._pending, ...(prefs.getStringList(_kPending) ?? const [])};
      // ترحيل لمرة واحدة: النسخة السابقة كانت تعلّم بـ_kMigrated=false
      // وجود قرارات لم تُرفع — تصير معلّقة فلا تضيع
      if (prefs.getBool(_kMigrated) == false) {
        _pending.addAll(local);
        await prefs.setBool(_kMigrated, true);
        await _savePending(prefs);
      }
      if (!local.every(_keys.contains)) {
        _keys = merge(_keys, local);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('تعذّرت قراءة قرارات «ليست مكرّرة» المحلية: $e');
    }
  }

  /// المحلي = السحابة + المعلّقة، والمعلّقة تُرفع. لا يرمي — الفشل يعني
  /// المحاولة في المزامنة التالية.
  Future<void> syncWithCloud() async {
    final pid = AppSettings.instance.pharmacyId;
    if (!_hasCloud || pid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_pending.isNotEmpty) _write(pid, _pending.toList(), prefs);
      final cloud = (await _read(pid).timeout(cloudReadTimeout)).toSet();
      final next = merge(cloud, _pending);
      if (!setEquals(next, _keys)) {
        _keys = next;
        await prefs.setStringList(_kLocal, _keys.toList());
        notifyListeners();
      }
    } catch (e) {
      debugPrint('تعذّرت مزامنة قرارات «ليست مكرّرة»: $e');
    }
  }

  /// قرار جديد: محلياً فوراً، ثم السحابة (إن تعذّرت يبقى معلّقاً ويُعاد).
  Future<void> add(String key) async {
    if (_keys.contains(key)) return;
    _keys = {..._keys, key};
    _pending.add(key);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kLocal, _keys.toList());
    await _savePending(prefs);
    final pid = AppSettings.instance.pharmacyId;
    if (!_hasCloud || pid == null) return;
    _write(pid, [key], prefs);
  }

  /// «إظهار المخفية»: تُلغى كل القرارات على كل الأجهزة — السحابة تُستبدل
  /// بقائمة فارغة (لا دمج)، فيلتقطها الهاتف الآخر في مزامنته.
  Future<void> clearAll() async {
    _keys = {};
    _pending = {};
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kLocal, const []);
    await _savePending(prefs);
    final pid = AppSettings.instance.pharmacyId;
    if (!_hasCloud || pid == null) return;
    final Future<void> clear =
        cloudClear?.call(pid) ??
        _db!.collection(_collection).doc(pid).set({
          'pharmacyId': pid,
          'keys': <String>[],
        });
    unawaited(
      clear.catchError((Object e) {
        debugPrint('تعذّر مسح قرارات «ليست مكرّرة» في السحابة: $e');
      }),
    );
  }

  /// اتحاد مجموعتين من القرارات.
  @visibleForTesting
  static Set<String> merge(Set<String> a, Set<String> b) => {...a, ...b};
}
