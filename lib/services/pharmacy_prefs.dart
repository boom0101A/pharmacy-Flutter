import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// إعدادات تخصّ **الصيدلية** لا الجهاز — مشتركة بين كل أجهزتها:
///
/// - [lowStockDefault]: الحد العام للمخزون المنخفض (للمواد بلا حد خاص).
/// - [alertDismissals]: تنبيهات علّمها أحد «تمّ» — مفتاح `<id>:<kind>`، فلو
///   صارت «العاجلة» منتهية يعود تنبيهها بمفتاح جديد.
///
/// مستند واحد في السحابة (`pharmacyPrefs/{pharmacyId}`) مع نسخة محلية تعمل
/// بلا إنترنت. **السحابة هي المرجع**، ومعها تغييرات هذا الهاتف التي لم
/// يؤكّدها الخادم بعد — النمط نفسه في `DuplicateDismissals`.
class PharmacyPrefs extends ChangeNotifier {
  PharmacyPrefs._();
  static final PharmacyPrefs instance = PharmacyPrefs._();

  /// 1 لا 5: أغلب مواد الصيدلية تُخزَّن بقطعة أو اثنتين، فحد 5 جعل نحو 578
  /// مادة «منخفضة» (رُصد على الهاتف). المواد سريعة البيع ترفع حدها من نموذجها.
  static const defaultLowStock = 1;

  static const _collection = 'pharmacyPrefs';
  static const _kLowStock = 'pharmacy_low_stock_default';
  static const _kLowStockPending = 'pharmacy_low_stock_pending';
  static const _kDismissed = 'alert_dismissals';
  static const _kAddPending = 'alert_dismissals_add_pending';
  static const _kRemovePending = 'alert_dismissals_remove_pending';

  FirebaseFirestore? _db;

  int _lowStockDefault = defaultLowStock;
  int get lowStockDefault => _lowStockDefault;

  /// تغيير الحد العام من هذا الهاتف لم يُؤكَّد بعد — يتقدّم على قيمة السحابة.
  bool _lowStockPending = false;

  Set<String> _dismissed = {};
  Set<String> get alertDismissals => _dismissed;

  Set<String> _addPending = {};
  Set<String> _removePending = {};

  static void attach(FirebaseFirestore db) => instance._db = db;

  /// بدائل السحابة للاختبارات.
  @visibleForTesting
  Future<void> Function(
    String pid, {
    int? lowStockDefault,
    List<String> add,
    List<String> remove,
  })?
  cloudApply;
  @visibleForTesting
  Future<({int? lowStockDefault, List<String> dismissals})> Function(
    String pid,
  )?
  cloudRead;

  @visibleForTesting
  void resetForTest() {
    _db = null;
    _lowStockDefault = defaultLowStock;
    _lowStockPending = false;
    _dismissed = {};
    _addPending = {};
    _removePending = {};
    cloudApply = null;
    cloudRead = null;
  }

  /// للاختبارات التي تحتاج حداً عاماً آخر بلا سحابة ولا تخزين.
  @visibleForTesting
  void debugSetLowStockDefault(int value) {
    _lowStockDefault = value;
    notifyListeners();
  }

  bool get _hasCloud => _db != null || cloudApply != null;

  /// لا يُنتظر: مع التخزين الدائم لا يكتمل بلا إنترنت، والكتابة محفوظة في
  /// طابور Firestore. عند التأكيد تخرج من المعلّقة.
  void _apply(
    String pid,
    SharedPreferences prefs, {
    int? lowStockDefault,
    List<String> add = const [],
    List<String> remove = const [],
  }) {
    final Future<void> write =
        cloudApply?.call(
          pid,
          lowStockDefault: lowStockDefault,
          add: add,
          remove: remove,
        ) ??
        _firestoreApply(pid, lowStockDefault, add, remove);
    unawaited(
      write
          .then((_) async {
            if (lowStockDefault != null &&
                lowStockDefault == _lowStockDefault) {
              _lowStockPending = false;
            }
            _addPending.removeAll(add);
            _removePending.removeAll(remove);
            await _savePending(prefs);
          })
          .catchError((Object e) {
            debugPrint('تعذّر رفع إعدادات الصيدلية: $e');
          }),
    );
  }

  Future<void> _firestoreApply(
    String pid,
    int? lowStock,
    List<String> add,
    List<String> remove,
  ) async {
    final ref = _db!.collection(_collection).doc(pid);
    // arrayUnion وarrayRemove في كتابة واحدة غير مسموح على الحقل نفسه
    if (lowStock != null || add.isNotEmpty) {
      await ref.set({
        'pharmacyId': pid,
        'lowStockDefault': ?lowStock,
        if (add.isNotEmpty) 'alertDismissals': FieldValue.arrayUnion(add),
      }, SetOptions(merge: true));
    }
    if (remove.isNotEmpty) {
      await ref.set({
        'pharmacyId': pid,
        'alertDismissals': FieldValue.arrayRemove(remove),
      }, SetOptions(merge: true));
    }
  }

  Future<({int? lowStockDefault, List<String> dismissals})> _read(
    String pid,
  ) async {
    final read = cloudRead;
    if (read != null) return read(pid);
    final snap = await _db!.collection(_collection).doc(pid).get();
    final data = snap.data();
    return (
      lowStockDefault: (data?['lowStockDefault'] as num?)?.toInt(),
      dismissals: List<String>.from(
        (data?['alertDismissals'] as List?) ?? const [],
      ),
    );
  }

  Future<void> _savePending(SharedPreferences prefs) async {
    await prefs.setBool(_kLowStockPending, _lowStockPending);
    await prefs.setStringList(_kAddPending, _addPending.toList());
    await prefs.setStringList(_kRemovePending, _removePending.toList());
  }

  Future<void> _saveLocal(SharedPreferences prefs) async {
    await prefs.setInt(_kLowStock, _lowStockDefault);
    await prefs.setStringList(_kDismissed, _dismissed.toList());
    await _savePending(prefs);
  }

  /// النسخة المحلية — فورية وتعمل بلا اتصال. لا ترمي.
  Future<void> loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lowStockDefault = prefs.getInt(_kLowStock) ?? defaultLowStock;
      _lowStockPending = prefs.getBool(_kLowStockPending) ?? false;
      _dismissed = (prefs.getStringList(_kDismissed) ?? const []).toSet();
      _addPending = (prefs.getStringList(_kAddPending) ?? const []).toSet();
      _removePending = (prefs.getStringList(_kRemovePending) ?? const [])
          .toSet();
      notifyListeners();
    } catch (e) {
      debugPrint('تعذّرت قراءة إعدادات الصيدلية المحلية: $e');
    }
  }

  /// المحلي = السحابة + تغييرات هذا الهاتف المعلّقة، والمعلّقة تُرفع.
  /// لا يرمي — الفشل يعني المحاولة في المزامنة التالية.
  Future<void> syncWithCloud() async {
    final pid = AppSettings.instance.pharmacyId;
    if (!_hasCloud || pid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lowStockPending ||
          _addPending.isNotEmpty ||
          _removePending.isNotEmpty) {
        _apply(
          pid,
          prefs,
          lowStockDefault: _lowStockPending ? _lowStockDefault : null,
          add: _addPending.toList(),
          remove: _removePending.toList(),
        );
      }
      final cloud = await _read(pid).timeout(const Duration(seconds: 8));
      final nextLow = _lowStockPending
          ? _lowStockDefault
          : (cloud.lowStockDefault ?? _lowStockDefault);
      final nextDismissed = {...cloud.dismissals, ..._addPending}
        ..removeAll(_removePending);
      if (nextLow != _lowStockDefault ||
          !setEquals(nextDismissed, _dismissed)) {
        _lowStockDefault = nextLow;
        _dismissed = nextDismissed;
        await _saveLocal(prefs);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('تعذّرت مزامنة إعدادات الصيدلية: $e');
    }
  }

  Future<void> _change(
    void Function() mutate, {
    int? lowStock,
    List<String> add = const [],
    List<String> remove = const [],
  }) async {
    mutate();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _saveLocal(prefs);
    final pid = AppSettings.instance.pharmacyId;
    if (!_hasCloud || pid == null) return;
    _apply(pid, prefs, lowStockDefault: lowStock, add: add, remove: remove);
  }

  /// الحد العام للمخزون المنخفض (1 فما فوق).
  Future<void> setLowStockDefault(int value) async {
    if (value < 1 || value == _lowStockDefault) return;
    await _change(() {
      _lowStockDefault = value;
      _lowStockPending = true;
    }, lowStock: value);
  }

  /// «تمّ» على تنبيه.
  Future<void> dismiss(String key) async {
    if (_dismissed.contains(key)) return;
    await _change(() {
      _dismissed = {..._dismissed, key};
      _addPending.add(key);
      _removePending.remove(key);
    }, add: [key]);
  }

  /// تراجع عن «تمّ»، أو «إظهار المخفية» لتنبيه واحد.
  Future<void> restore(Iterable<String> keys) async {
    final gone = keys.where(_dismissed.contains).toList();
    if (gone.isEmpty) return;
    await _change(() {
      _dismissed = {..._dismissed}..removeAll(gone);
      _addPending.removeAll(gone);
      _removePending.addAll(gone);
    }, remove: gone);
  }

  /// يُزيل مفاتيح تنبيهات انحلّت (عُدّلت المادة أو حُذفت) فلا تنمو القائمة.
  Future<void> prune(Set<String> stillActive) async {
    final stale = _dismissed.where((k) => !stillActive.contains(k)).toList();
    if (stale.isEmpty) return;
    await restore(stale);
  }
}
