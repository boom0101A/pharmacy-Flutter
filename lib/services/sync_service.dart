import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/medicine_db.dart';
import '../models/invoice.dart';
import '../models/medicine.dart';
import 'app_settings.dart';
import 'auth_service.dart';
import 'barcode_registry.dart';
import 'duplicate_dismissals.dart';
import 'image_store.dart';
import 'pharmacy_service.dart';
import '../l10n/l10n.dart';

enum SyncStatus { disabled, offline, syncing, synced, error }

/// مزامنة الأدوية مع Firestore.
///
/// المبدأ: القاعدة المحلية (SQLite) هي المصدر الأساسي — التطبيق يعمل كاملاً
/// بدون إنترنت. Firestore طبقة نسخ احتياطي/مشاركة بين الأجهزة، ويُحسم التعارض
/// بالأحدث (`updatedAt` الأكبر يفوز).
///
/// ملاحظة: الصور تبقى محلية على الجهاز ولا تُرفع (يحتاج Firebase Storage).
/// نتيجة رفع دفعي: [acked] = أكّد الخادم (لا انقطاع)، و[denied] = معرّفات
/// رفضتها القواعد فرادى بينما قُبل غيرها.
class CommitOutcome {
  const CommitOutcome({required this.acked, required this.denied});
  final bool acked;
  final List<String> denied;
}

class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const _collection = 'medicines';
  static const _tombstones = 'tombstones';

  /// Firestore يرفض الدفعة فوق 500 عملية — نبقى دونها بهامش أمان.
  static const _batchLimit = 450;

  /// أقصى عدد مواد مرفوضة يُعاد ربطها بمعرّف جديد في مزامنة واحدة.
  static const _maxRelink = 20;

  FirebaseFirestore? _db;
  SyncStatus _status = SyncStatus.disabled;
  String? _lastError;

  SyncStatus get status => _status;
  String? get lastError => _lastError;

  /// المزامنة تحتاج قاعدة **وهوية مالك** — بدونها القواعد سترفض كل كتابة.
  bool get isEnabled => _db != null && AuthService.instance.isSignedIn;

  String? get _uid => AuthService.instance.uid;

  String get statusLabel {
    final l = L10n.current;
    return switch (_status) {
      SyncStatus.disabled => l.syncLocal,
      SyncStatus.offline => l.syncOffline,
      SyncStatus.syncing => l.syncSyncing,
      SyncStatus.synced => l.syncSynced,
      SyncStatus.error => l.syncFailed,
    };
  }

  /// ترجمة أخطاء Firestore الشائعة إلى سبب واضح وخطوة إصلاح.
  static String _explain(FirebaseException e) {
    final l = L10n.current;
    return switch (e.code) {
      'permission-denied' => l.syncErrPermission,
      'not-found' => l.syncErrNotFound,
      'unavailable' => l.syncErrUnavailable,
      'failed-precondition' => l.syncErrPrecondition,
      'unauthenticated' => l.syncErrUnauthenticated,
      _ => '${e.code}: ${e.message ?? l.syncErrUnknown}',
    };
  }

  void _setStatus(SyncStatus value, {String? error}) {
    _status = value;
    _lastError = error;
    notifyListeners();
  }

  /// تهيئة Firebase. تفشل بهدوء إذا لم يكن google-services.json موجوداً،
  /// فيبقى التطبيق يعمل محلياً.
  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _db = FirebaseFirestore.instance;
      // تخزين مؤقت محلي لبيانات Firestore حتى تعمل القراءة بلا إنترنت
      _db!.settings = const Settings(persistenceEnabled: true);
      BarcodeRegistry.attach(_db!);
      PharmacyService.attach(_db!);
      DuplicateDismissals.attach(_db!);

      // الهوية شرط للكتابة تحت القواعد الجديدة
      await AuthService.instance.init();
      if (!AuthService.instance.isSignedIn) {
        _setStatus(SyncStatus.disabled, error: AuthService.instance.error);
        return;
      }
      _setStatus(SyncStatus.synced);
    } catch (e) {
      _db = null;
      _setStatus(SyncStatus.disabled, error: e.toString());
      debugPrint('Firebase غير مهيأ — التطبيق يعمل محلياً: $e');
    }
  }

  /// حمولة الرفع: نحذف مسار الصورة (خاص بالجهاز) ونضيف المالك ومعرّف صيدليته.
  ///
  /// `ownerUid` يبقى مؤقتاً لدعم الأجهزة التي لم تُهاجَر بعد إلى نظام
  /// الصيدلية المشتركة (راجع firestore.rules) — `pharmacyId` هو ما تعتمد
  /// عليه المزامنة والقواعد فعلياً بعد الهجرة.
  Map<String, Object?> _payload(Medicine m) =>
      Map<String, Object?>.from(m.toMap())
        ..remove('imagePath')
        ..['ownerUid'] = _uid
        ..['pharmacyId'] = AppSettings.instance.pharmacyId
        // ختم الخادم: المزامنة التزايدية تقرأ ما تغيّر بعده فقط
        ..['syncedAt'] = FieldValue.serverTimestamp();

  /// رفع دواء واحد (بعد الحفظ المحلي). لا يرمي استثناءً أبداً.
  Future<void> pushMedicine(Medicine medicine) async {
    final db = _db;
    if (db == null || !isEnabled) return;
    try {
      final acked = await awaitServerAck(
        db.collection(_collection).doc(medicine.id).set(_payload(medicine)),
        ackTimeout,
      );
      _setStatus(acked ? SyncStatus.synced : SyncStatus.offline);
    } on FirebaseException catch (e) {
      _setStatus(
        e.code == 'unavailable' ? SyncStatus.offline : SyncStatus.error,
        error: _explain(e),
      );
    } catch (e) {
      _setStatus(SyncStatus.error, error: e.toString());
    }
  }

  /// الحذف يترك **شاهداً** (tombstone) لا مجرد إزالة.
  ///
  /// بدونه: الجهاز الثاني لا يزال يحمل السجل محلياً، فيرفعه في مرحلة الصعود
  /// فيعود المحذوف من الموت. الشاهد يخبر بقية الأجهزة أن الحذف مقصود.
  ///
  /// يُرجع `true` عند نجاح الحذف السحابي فعلياً، `false` عند أي فشل (شبكة،
  /// صلاحيات، `pharmacyId` غير جاهز). المُتّصل مسؤول عن إبقاء المعرّف في
  /// طابور `pending_deletes` المحلي حين يعود `false` ليُعاد لاحقاً — كتابة
  /// شاهد بلا `pharmacyId` تجعله غير مرئي لأي مزامنة تالية (يعود الحذف).
  Future<bool> deleteMedicine(String id) async {
    final db = _db;
    if (db == null || !isEnabled) return false;

    // إنتاج شاهد بلا pharmacyId يُهدره — استعلام syncAll يفلتره على
    // pharmacyId فيصبح كأنه غير موجود، ثم يعود المحذوف من السحابة في أول
    // مزامنة نزول. نضمن الوسم قبل الكتابة.
    if (AppSettings.instance.pharmacyId == null) {
      await PharmacyService.instance.ensureOwnPharmacy();
    }
    final pharmacyId = AppSettings.instance.pharmacyId;
    if (pharmacyId == null) return false;

    try {
      final batch = db.batch();
      batch.delete(db.collection(_collection).doc(id));
      batch.set(db.collection(_tombstones).doc(id), {
        'ownerUid': _uid,
        'pharmacyId': pharmacyId,
        'deletedAt': DateTime.now().millisecondsSinceEpoch,
        'syncedAt': FieldValue.serverTimestamp(),
      });
      if (!await awaitServerAck(batch.commit(), ackTimeout)) {
        // في الطابور الدائم؛ المعرّف يبقى في pending_deletes ويُعاد لاحقاً
        _setStatus(SyncStatus.offline);
        return false;
      }
      _setStatus(SyncStatus.synced);
      return true;
    } on FirebaseException catch (e) {
      // مستند السحابة لصيدلية أخرى (لا نملك حذفه): شاهد الحذف وحده مسموح
      // ويكفي لأجهزتنا. بدونه يبقى المعرّف في طابور الحذف ويفشل للأبد.
      if (e.code == 'permission-denied') {
        try {
          final tomb = db.collection(_tombstones).doc(id).set({
            'ownerUid': _uid,
            'pharmacyId': pharmacyId,
            'deletedAt': DateTime.now().millisecondsSinceEpoch,
            'syncedAt': FieldValue.serverTimestamp(),
          });
          if (await awaitServerAck(tomb, ackTimeout)) {
            _setStatus(SyncStatus.synced);
            return true;
          }
          _setStatus(SyncStatus.offline);
          return false;
        } on FirebaseException {
          // يسقط إلى رسالة الرفض الأصلية أدناه
        }
      }
      _setStatus(
        e.code == 'unavailable' ? SyncStatus.offline : SyncStatus.error,
        error: _explain(e),
      );
      return false;
    } catch (e) {
      _setStatus(SyncStatus.error, error: e.toString());
      return false;
    }
  }

  /// كل مواد صيدلية هذا الجهاز كما في السحابة، بلا أي كتابة — لشاشة مراجعة
  /// التكرارات (مجموعات الباركود المكرّر لا تُرى محلياً). null إن تعذّر.
  ///
  /// المستندات التي لها شاهد حذف تُستبعد: جهاز قديم أو سباق مزامنة قد يعيد
  /// رفع مادة محذوفة، والمزامنة تتجاهلها — فدمجها كان يضيف كمية مادة محذوفة.
  Future<List<Medicine>?> fetchPharmacyItems() async {
    final db = _db;
    final uid = _uid;
    final pharmacyId = AppSettings.instance.pharmacyId;
    if (db == null || !isEnabled || uid == null || pharmacyId == null) {
      return null;
    }
    try {
      final snapshot = await db
          .collection(_collection)
          .where('pharmacyId', isEqualTo: pharmacyId)
          .get();
      final deleted = await _tombstoneIds(db, pharmacyId, uid);
      final items = <Medicine>[];
      for (final doc in snapshot.docs) {
        if (deleted.contains(doc.id)) continue;
        try {
          items.add(
            Medicine.fromMap(
              Map<String, Object?>.from(doc.data())..['id'] = doc.id,
            ),
          );
        } catch (_) {
          // مستند تالف لا يُسقط القائمة
        }
      }
      return items;
    } catch (e) {
      debugPrint('تعذّر جلب مواد الصيدلية: $e');
      return null;
    }
  }

  // ---------------- المزامنة التزايدية ----------------
  //
  // المزامنة الكاملة تقرأ كل المواد وكل شواهد الحذف (~2,500 قراءة) في كل
  // تشغيل — والحد المجاني 50,000 يومياً للمشروع كله، أي ~20 تشغيلاً للهاتفين.
  // كل كتابة صارت تحمل `syncedAt` (ختم الخادم، لا ساعة الهاتف)، فيقرأ الجهاز
  // ما تغيّر بعد آخر ختم رآه فقط. الكاملة تبقى شبكة أمان: أول مرة، والسحب
  // اليدوي، وأسبوعياً.

  static const _kSeenMed = 'sync_seen_medicines';
  static const _kSeenTomb = 'sync_seen_tombstones';
  static const _kSeenInv = 'sync_seen_invoices';
  static const _kPushMed = 'sync_push_medicines';
  static const _kPushInv = 'sync_push_invoices';
  static const _kLastFull = 'sync_last_full';

  /// مزامنة كاملة أسبوعية حتى لو سار كل شيء تزايدياً بلا خطأ.
  static const fullEvery = Duration(days: 7);

  /// هامش للكتابات التي وصلت للخادم أثناء القراءة السابقة — التكرار لا يضر
  /// (المقارنة بـ updatedAt)، أما الفوات فيضر.
  static const _overlap = Duration(minutes: 2);

  /// شواهد الحذف المقروءة في آخر [syncAll] — تعيد مزامنة الفواتير استعمالها
  /// بدل قراءتها مرة ثانية.
  Set<String>? _lastTombstones;

  /// هل تكون هذه الدورة كاملة؟ دالة صِرفة.
  @visibleForTesting
  static bool needsFull({
    required int? seenMs,
    required int? lastFullMs,
    required bool manual,
    required int nowMs,
  }) =>
      manual ||
      seenMs == null ||
      lastFullMs == null ||
      nowMs - lastFullMs > fullEvery.inMilliseconds;

  /// أكبر ختم `syncedAt` في المستندات، أو null إن لم يحمله أي منها.
  static int? _maxSynced(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int? max;
    for (final d in docs) {
      final ts = d.data()['syncedAt'];
      if (ts is Timestamp) {
        final ms = ts.millisecondsSinceEpoch;
        if (max == null || ms > max) max = ms;
      }
    }
    return max;
  }

  static Timestamp _since(int seenMs) => Timestamp.fromMillisecondsSinceEpoch(
    (seenMs - _overlap.inMilliseconds).clamp(0, seenMs),
  );

  /// مزامنة في الاتجاهين — تزايدية افتراضياً، وكاملة عند [manual] أو حين
  /// يلزم ([needsFull]). ترجع true إذا تغيّرت البيانات المحلية.
  Future<bool> syncAll({bool manual = false}) async {
    final db = _db;
    final uid = _uid;
    final pharmacyId = AppSettings.instance.pharmacyId;
    if (db == null || uid == null || pharmacyId == null) return false;

    _setStatus(SyncStatus.syncing);
    try {
      final prefs = await SharedPreferences.getInstance();
      final cycleStart = DateTime.now().millisecondsSinceEpoch;
      final seenMed = prefs.getInt(_kSeenMed);
      final seenTomb = prefs.getInt(_kSeenTomb) ?? 0;
      final pushMed = prefs.getInt(_kPushMed) ?? 0;
      var full = needsFull(
        seenMs: seenMed,
        lastFullMs: prefs.getInt(_kLastFull),
        manual: manual,
        nowMs: cycleStart,
      );

      final local = await MedicineDb.instance.getAll();
      final localById = {for (final m in local) m.id: m};

      // سجلات صيدلية هذا الجهاز فقط (قد تكون مشتركة مع أجهزة أخرى — راجع
      // pharmacy_service.dart). سجلات لم تُوسَم بـ pharmacyId بعد لا تُقرأ
      // هنا — خطوة الهجرة في MedicineStore.refreshFromCloud هي ما تمنحها
      // هذا الوسم من النسخة المحلية قبل أول استدعاء لهذه الدالة.
      final base = db
          .collection(_collection)
          .where('pharmacyId', isEqualTo: pharmacyId);
      QuerySnapshot<Map<String, dynamic>>? snapshot;
      Set<String>? deletedIds;
      int? maxTomb;
      if (!full) {
        try {
          snapshot = await base
              .where('syncedAt', isGreaterThan: _since(seenMed!))
              .get();
          final tombs = await db
              .collection(_tombstones)
              .where('pharmacyId', isEqualTo: pharmacyId)
              .where('syncedAt', isGreaterThan: _since(seenTomb))
              .get();
          deletedIds = {for (final t in tombs.docs) t.id};
          maxTomb = _maxSynced(tombs.docs);
        } on FirebaseException catch (e) {
          // فهرس (pharmacyId + syncedAt) لم يُنشأ بعد: الرسالة تحمل رابط
          // إنشائه. المزامنة لا تتعطّل — تعود كاملة كما كانت.
          if (e.code != 'failed-precondition') rethrow;
          debugPrint('المزامنة التزايدية تحتاج فهرساً: ${e.message}');
          full = true;
        }
      }
      if (full) {
        snapshot = await base.get();
        deletedIds = await _tombstoneIds(db, pharmacyId, uid);
      }
      _lastTombstones = {...deletedIds!};
      final maxMed = _maxSynced(snapshot!.docs);
      final remoteById = <String, Medicine>{};
      final legacyImages = <String, String>{}; // id -> data URL من نسخة الويب
      var skipped = 0;

      for (final doc in snapshot.docs) {
        // مستند تالف واحد يجب ألا يوقف المزامنة كلها
        try {
          final data = Map<String, Object?>.from(doc.data())..['id'] = doc.id;

          // نسخة الويب كانت تحفظ الصورة كـ base64 في الحقل image
          final legacy = data.remove('image');
          if (legacy is String && legacy.startsWith('data:image')) {
            legacyImages[doc.id] = legacy;
          }

          remoteById[doc.id] = Medicine.fromMap(data);
        } catch (e) {
          skipped++;
          debugPrint('تخطّي مستند غير صالح ${doc.id}: $e');
        }
      }

      // حماية: أي معرّف ما زال في طابور الحذف المحلي (لأن الحذف السحابي فشل
      // ولم يُثبَّت شاهد بعد) يُعامَل كمحذوف لهذه المزامنة — بلا هذا يظل
      // مرئياً في السحابة، فتُحضره حلقة النزول أدناه ويعود الحذف الظاهري.
      final pendingDeletes = await MedicineDb.instance.peekPendingDeletes();
      deletedIds.addAll(pendingDeletes);

      var localChanged = false;
      final pending = <String, Map<String, Object?>>{};

      for (final id in deletedIds) {
        if (localById.containsKey(id)) {
          final victim = localById[id]!;
          await MedicineDb.instance.delete(id);
          await ImageStore.deleteFile(victim.imagePath);
          localById.remove(id);
          localChanged = true;
        }
      }

      // نزول: ما هو في السحابة وأحدث (أو غير موجود محلياً). يُجمَع ثم يُكتب
      // دفعة واحدة تحسم تعارض الباركود بين الأجهزة بدل حذف صامت.
      final downloads = <Medicine>[];
      for (final remote in remoteById.values) {
        if (deletedIds.contains(remote.id)) continue;
        final mine = localById[remote.id];
        if (mine == null) {
          // ترحيل صورة base64 القديمة إلى ملف محلي عند أول تنزيل.
          //
          // `updatedAt` يُمرَّر صراحةً: copyWith يختم بـ«الآن» إن لم يُمرَّر،
          // فيصير السجل المنزَّل أحدث من نسخته السحابية، فتعيد المزامنة
          // التالية رفعه — وأسوأ: تدهس تعديلاً أحدث من الجهاز الآخر لأنه
          // «أقدم» بالمقارنة المزوَّرة. الختم يجب أن يبقى ختم المصدر.
          final imageFile = await _saveLegacyImage(legacyImages[remote.id]);
          downloads.add(
            imageFile == null
                ? remote
                : remote.copyWith(
                    imagePath: imageFile,
                    updatedAt: remote.updatedAt,
                  ),
          );
        } else if (remote.updatedAt > mine.updatedAt) {
          // نحافظ على صورة الجهاز المحلية إن وُجدت — وعلى ختم السحابة كما هو
          downloads.add(
            remote.copyWith(
              imagePath: mine.imagePath,
              clearImage: mine.imagePath == null,
              updatedAt: remote.updatedAt,
            ),
          );
        }
      }
      if (downloads.isNotEmpty) {
        // المتعارض بالباركود يُتخطّى محلياً ولا يُحذف من أي مكان
        await MedicineDb.instance.upsertAllSkippingBarcodeConflicts(downloads);
        localChanged = true;
      }

      // صعود: ما هو محلي وأحدث وليس محذوفاً. في الكاملة: غير الموجود في
      // السحابة أو الأقدم فيها. في التزايدية لا نرى السحابة كلها، فنرفع ما
      // عُدّل محلياً بعد آخر دورة ناجحة (والحفظ يرفع فوراً أصلاً).
      for (final mine in local) {
        if (deletedIds.contains(mine.id)) continue;
        final remote = remoteById[mine.id];
        final newer = remote == null || mine.updatedAt > remote.updatedAt;
        if (full ? newer : (newer && mine.updatedAt > pushMed)) {
          pending[mine.id] = _payload(mine);
        }
      }

      // `local` لُقط في بداية الدورة؛ مادة حذفها المستخدم أثناءها دخلت الطابور
      // بعد ذلك. بلا قراءة ثانية هنا يُعاد رفعها فتصير «زومبي» في السحابة.
      dropQueuedDeletes(
        pending,
        await MedicineDb.instance.peekPendingDeletes(),
      );
      final outcome = await _commitInChunks(db, pending);
      if (!outcome.acked) {
        // ما نزل محفوظ ومعروض؛ الرفع في الطابور الدائم حتى يعود الاتصال
        _setStatus(SyncStatus.offline);
        return localChanged;
      }

      // مادة محلية معرّفها مستعمل في السحابة لمستند صيدلية أخرى: لا نراه في
      // استعلامنا فنرفعها، فترفضها القواعد — في كل مزامنة. المادة لنا محلياً،
      // والتعارض في المعرّف وحده: تُنقل لمعرّف جديد وتُرفع تحت صيدليتنا. مستند
      // الصيدلية الأخرى لا يُمسّ.
      // سقف أمان: رفض جماعي يعني قواعد معطوبة لا تعارض معرّفات — نقل مئات
      // المواد لمعرّفات جديدة كان سيضاعفها في السحابة حين تُصلَح القواعد
      if (outcome.denied.length > _maxRelink) {
        _setStatus(
          SyncStatus.error,
          error: L10n.current.syncDenied(outcome.denied.length),
        );
        return localChanged;
      }
      final relinked = <String>[];
      for (final id in outcome.denied) {
        final mine = localById[id];
        if (mine == null) continue;
        final fresh = rekeyed(mine, DateTime.now());
        await MedicineDb.instance.rekey(id, fresh);
        final retry = await _commitInChunks(db, {fresh.id: _payload(fresh)});
        if (retry.denied.isEmpty) relinked.add(mine.name);
        localChanged = true;
      }

      // الدورة اكتملت: يتقدّم المؤشر. بلا ختم في أي مستند (كلها أقدم من
      // هذه النسخة) يصير 0 — فتلتقط التزايدية التالية كل ما يُكتب بعد الآن.
      await prefs.setInt(_kSeenMed, math.max(seenMed ?? 0, maxMed ?? 0));
      await prefs.setInt(_kSeenTomb, math.max(seenTomb, maxTomb ?? 0));
      await prefs.setInt(_kPushMed, cycleStart);
      if (full) await prefs.setInt(_kLastFull, cycleStart);

      final notes = [
        if (skipped > 0) L10n.current.syncSkipped(skipped),
        if (relinked.isNotEmpty)
          L10n.current.syncRelinked(
            relinked.length,
            relinked.take(3).join(L10n.current.listSeparator),
          ),
      ];
      _setStatus(
        SyncStatus.synced,
        error: notes.isEmpty
            ? null
            : L10n.current.syncDoneWithNotes(notes.join(' ')),
      );
      return localChanged;
    } on FirebaseException catch (e) {
      _setStatus(
        e.code == 'unavailable' ? SyncStatus.offline : SyncStatus.error,
        error: _explain(e),
      );
      return false;
    } on SocketException {
      _setStatus(SyncStatus.offline);
      return false;
    } catch (e) {
      _setStatus(SyncStatus.error, error: e.toString());
      return false;
    }
  }

  /// نسخة من [m] بمعرّف جديد — كل ما عدا المعرّف كما هو (الختم أيضاً).
  @visibleForTesting
  static Medicine rekeyed(Medicine m, DateTime now) => Medicine.fromMap(
    m.toMap()..['id'] = 'med_${now.millisecondsSinceEpoch}_r${now.microsecond}',
  );

  /// يُسقط من دفعة الرفع كل معرّف دخل طابور الحذف.
  @visibleForTesting
  static void dropQueuedDeletes(
    Map<String, Object?> pending,
    Iterable<String> queued,
  ) {
    for (final id in queued) {
      pending.remove(id);
    }
  }

  // ---------------- الفواتير ----------------
  //
  // أعدادها صغيرة (فاتورة أو اثنتان يومياً)، فالمزامنة مستند مستند بلا دفعات.
  // الكتابات بلا تأكيد خادم محفوظة في طابور Firestore الدائم وتُرفع وحدها.

  static const _invoices = 'invoices';

  Map<String, Object?> _invoicePayload(Invoice inv) => inv.toCloud()
    ..['ownerUid'] = _uid
    ..['pharmacyId'] = AppSettings.instance.pharmacyId
    ..['syncedAt'] = FieldValue.serverTimestamp();

  /// رفع فاتورة (بعد الحفظ المحلي). لا يرمي.
  Future<void> pushInvoice(Invoice inv) async {
    final db = _db;
    if (db == null || !isEnabled || AppSettings.instance.pharmacyId == null) {
      return;
    }
    try {
      await awaitServerAck(
        db.collection(_invoices).doc(inv.id).set(_invoicePayload(inv)),
        ackTimeout,
      );
    } catch (e) {
      debugPrint('تعذّر رفع الفاتورة: $e');
    }
  }

  /// حذف فاتورة من السحابة مع شاهد حذف حتى لا يعيدها هاتف آخر. لا يرمي.
  Future<void> deleteInvoice(String id) async {
    final db = _db;
    final pharmacyId = AppSettings.instance.pharmacyId;
    if (db == null || !isEnabled || pharmacyId == null) return;
    try {
      final batch = db.batch()
        ..delete(db.collection(_invoices).doc(id))
        ..set(db.collection(_tombstones).doc(id), {
          'ownerUid': _uid,
          'pharmacyId': pharmacyId,
          'kind': 'invoice',
          'deletedAt': DateTime.now().millisecondsSinceEpoch,
          'syncedAt': FieldValue.serverTimestamp(),
        });
      await awaitServerAck(batch.commit(), ackTimeout);
    } catch (e) {
      debugPrint('تعذّر حذف الفاتورة من السحابة: $e');
    }
  }

  /// مزامنة الفواتير في الاتجاهين، تُرجع القائمة المحلية الجديدة أو null إن
  /// تعذّرت. الأحدث `updatedAt` يفوز، وأسماء الصور المحلية لا تُمس أبداً.
  ///
  /// تزايدية كالمواد: ما تغيّر بعد آخر ختم فقط، وشواهد الحذف من آخر
  /// [syncAll] بدل قراءتها مرة ثانية. كاملة عند [manual] أو حين يلزم.
  Future<List<Invoice>?> syncInvoices(
    List<Invoice> local, {
    bool manual = false,
  }) async {
    final db = _db;
    final uid = _uid;
    final pharmacyId = AppSettings.instance.pharmacyId;
    if (db == null || uid == null || pharmacyId == null || !isEnabled) {
      return null;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final cycleStart = DateTime.now().millisecondsSinceEpoch;
      final seen = prefs.getInt(_kSeenInv);
      var full = needsFull(
        seenMs: seen,
        lastFullMs: prefs.getInt(_kLastFull),
        manual: manual,
        nowMs: cycleStart,
      );
      final base = db
          .collection(_invoices)
          .where('pharmacyId', isEqualTo: pharmacyId);
      QuerySnapshot<Map<String, dynamic>>? snap;
      if (!full) {
        try {
          snap = await base
              .where('syncedAt', isGreaterThan: _since(seen!))
              .get();
        } on FirebaseException catch (e) {
          if (e.code != 'failed-precondition') rethrow;
          debugPrint('مزامنة الفواتير التزايدية تحتاج فهرساً: ${e.message}');
          full = true;
        }
      }
      snap ??= await base.get();
      final deleted =
          _lastTombstones ?? await _tombstoneIds(db, pharmacyId, uid);
      final result = mergeInvoices(
        local: local,
        remote: [
          for (final d in snap.docs)
            Invoice.fromMap(Map<String, Object?>.from(d.data())..['id'] = d.id),
        ],
        deleted: deleted,
        uploadSince: full ? null : prefs.getInt(_kPushInv) ?? 0,
      );
      for (final inv in result.upload) {
        unawaited(pushInvoice(inv));
      }
      await prefs.setInt(
        _kSeenInv,
        math.max(seen ?? 0, _maxSynced(snap.docs) ?? 0),
      );
      await prefs.setInt(_kPushInv, cycleStart);
      return result.merged;
    } catch (e) {
      debugPrint('تعذّرت مزامنة الفواتير: $e');
      return null;
    }
  }

  /// دمج صِرف للفواتير المحلية والسحابية — قابل للاختبار بلا Firestore.
  /// [uploadSince] (تزايدية): يُرفع ما عُدّل محلياً بعده فقط.
  @visibleForTesting
  static ({List<Invoice> merged, List<Invoice> upload}) mergeInvoices({
    required List<Invoice> local,
    required List<Invoice> remote,
    required Set<String> deleted,
    int? uploadSince,
  }) {
    final byId = {for (final i in local) i.id: i};
    final remoteById = {for (final r in remote) r.id: r};
    final upload = <Invoice>[];
    for (final r in remote) {
      if (deleted.contains(r.id)) continue;
      final mine = byId[r.id];
      if (mine == null || r.updatedAt > mine.updatedAt) {
        // صور هذا الهاتف (إن كانت) تبقى — السحابة لا تحملها
        byId[r.id] = mine == null ? r : r.copyWith(imageFiles: mine.imageFiles);
      }
    }
    for (final mine in local) {
      final r = remoteById[mine.id];
      if (deleted.contains(mine.id)) continue;
      final newer = r == null || mine.updatedAt > r.updatedAt;
      // تزايدية: [remote] ما تغيّر فقط، فغيابها لا يعني أنها غير مرفوعة
      if (newer && (uploadSince == null || mine.updatedAt > uploadSince)) {
        upload.add(mine);
      }
    }
    byId.removeWhere((id, _) => deleted.contains(id));
    final merged = byId.values.toList()
      ..sort((a, b) => b.sortDate.compareTo(a.sortDate));
    return (merged: merged, upload: upload);
  }

  /// معرّفات كل شواهد الحذف المرئية لهذا الجهاز.
  ///
  /// شواهد الصيدلية: ما حذفه أي عضو يصل لبقية الأعضاء. وشواهد قديمة من قبل
  /// هجرة الصيدلية المشتركة تحمل ownerUid فقط — بلا استعلامها تظل غير مرئية
  /// للأبد فيعود ما حُذف عبرها. فشل أحد الاستعلامين لا يُسقط الآخر.
  Future<Set<String>> _tombstoneIds(
    FirebaseFirestore db,
    String pharmacyId,
    String uid,
  ) async {
    final ids = <String>{};
    try {
      final tombs = await db
          .collection(_tombstones)
          .where('pharmacyId', isEqualTo: pharmacyId)
          .get();
      ids.addAll(tombs.docs.map((t) => t.id));
    } catch (e) {
      debugPrint('تعذّرت قراءة شواهد الحذف: $e');
    }
    try {
      final legacy = await db
          .collection(_tombstones)
          .where('ownerUid', isEqualTo: uid)
          .get();
      ids.addAll(legacy.docs.map((t) => t.id));
    } catch (e) {
      debugPrint('تعذّرت قراءة شواهد الحذف القديمة: $e');
    }
    return ids;
  }

  /// استحواذ لمرة واحدة على السجلات التي رُفعت قبل وجود المصادقة.
  ///
  /// السجلات القديمة في السحابة بلا `ownerUid`، فلن تراها استعلامات المالك ولن
  /// تسمح بها القواعد الجديدة. النسخة المحلية هي المرجع: نرفعها كلها موسومة
  /// بالمالك فتصبح السحابة مطابقة ومحميّة.
  ///
  /// **يجب أن يعمل قبل نشر القواعد المشددة** — بعدها لن يُسمح بتعديل مستند
  /// لا يحمل مالكاً.
  Future<int> claimLegacyRecords() => _pushAllLocal();

  /// وسم كل السجلات المحلية بمعرّف الصيدلية [pharmacyId] — لمرة واحدة، بعد
  /// أن ينشئ الجهاز صيدليته الخاصة أو ينضمّ إلى صيدلية موجودة.
  ///
  /// نفس عملية [claimLegacyRecords] تماماً (رفع كل سجل محلي موسوماً)، فقط
  /// بغاية مختلفة: تلك تمنح مالكاً لسجل بلا مالك إطلاقاً، وهذه تمنح `pharmacyId`
  /// لسجل موسوم بمالك فردي قديم فقط. [pharmacyId] غير مستخدَم مباشرة هنا —
  /// [_payload] يقرأه من [AppSettings] الذي يجب أن يكون مضبوطاً بالفعل قبل
  /// هذا الاستدعاء (`ensureOwnPharmacy` يضبطه).
  Future<int> backfillPharmacyId(String pharmacyId) => _pushAllLocal();

  /// يرفع كل السجلات المحلية موسومة بمالكها الحالي ومعرّف صيدليته — العملية
  /// المشتركة بين [claimLegacyRecords] و [backfillPharmacyId].
  Future<int> _pushAllLocal() async {
    final db = _db;
    if (db == null || !isEnabled) return 0;

    final local = await MedicineDb.instance.getAll();
    if (local.isEmpty) return 0;

    final pending = {for (final m in local) m.id: _payload(m)};
    // بلا تأكيد لا تُعلَّم العملية «تمّت». المرفوض فرادى يعالجه syncAll
    // بإعادة ربطه بمعرّف جديد، فلا يمنع إتمام هذه العملية.
    final outcome = await _commitInChunks(db, pending);
    if (!outcome.acked) {
      throw TimeoutException('لم يؤكّد الخادم رفع السجلات');
    }
    return pending.length;
  }

  /// مهلة انتظار تأكيد الخادم لكتابة.
  static const ackTimeout = Duration(seconds: 15);

  /// مع التخزين الدائم لا يكتمل مستقبل الكتابة إلا بتأكيد الخادم — بلا
  /// إنترنت يعلّق إلى أن يعود الاتصال، فتعلق معه دورة المزامنة وسحب التحديث.
  /// الكتابة نفسها محفوظة في الطابور الدائم وتُرفع وحدها لاحقاً، فالمهلة لا
  /// تُضيّع شيئاً. true = أكّد الخادم · false = لم يؤكّد بعد. الرفض الحقيقي
  /// (صلاحيات مثلاً) يُعاد رميه كما هو.
  @visibleForTesting
  static Future<bool> awaitServerAck(Future<void> write, Duration timeout) =>
      write.then((_) => true).timeout(timeout, onTimeout: () => false);

  /// كتابة دفعية مقسّمة مع عزل المرفوض.
  ///
  /// الدفعة ذرّية: مستند واحد ترفضه القواعد (معرّف مستعمل لمستند صيدلية
  /// أخرى مثلاً) كان يُفشلها كلها **في كل مزامنة** — فلا يُرفع أي تعديل من
  /// ذلك الجهاز، ويظهر «تعذّرت المزامنة» بلا سبب مفهوم. الآن: عند الرفض تُعاد
  /// مستندات الدفعة فرادى، ويُعاد المرفوض منها في [CommitOutcome.denied].
  ///
  /// لا يرمي أبداً عند رفض الصلاحية — ولا حين يُرفض الكل: في المزامنة
  /// المستقرة قد تكون المادة المرفوضة **وحدها** في الدفعة. التمييز بين
  /// «مستند بعينه» و«فقدان العضوية» شأن المستدعي ([syncAll] قرأ استعلام
  /// الصيدلية لتوّه، والقراءة نفسها تتطلب العضوية).
  @visibleForTesting
  static Future<CommitOutcome> commitIsolated(
    List<String> ids, {
    required Future<void> Function(List<String> ids) commit,
    required Duration timeout,
    int limit = _batchLimit,
  }) async {
    final denied = <String>[];
    for (var i = 0; i < ids.length; i += limit) {
      final chunk = ids.sublist(i, (i + limit).clamp(0, ids.length));
      try {
        if (!await awaitServerAck(commit(chunk), timeout)) {
          return CommitOutcome(acked: false, denied: denied);
        }
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
        for (final id in chunk) {
          try {
            if (!await awaitServerAck(commit([id]), timeout)) {
              return CommitOutcome(acked: false, denied: denied);
            }
          } on FirebaseException catch (one) {
            if (one.code != 'permission-denied') rethrow;
            denied.add(id);
          }
        }
      }
    }
    return CommitOutcome(acked: true, denied: denied);
  }

  /// يُرجع false إن لم يؤكّد الخادم دفعةً خلال [ackTimeout] (بلا إنترنت).
  /// المرفوضة تُعاد في [CommitOutcome.denied].
  Future<CommitOutcome> _commitInChunks(
    FirebaseFirestore db,
    Map<String, Map<String, Object?>> items,
  ) {
    if (items.isEmpty) {
      return Future.value(const CommitOutcome(acked: true, denied: []));
    }
    return commitIsolated(
      items.keys.toList(),
      timeout: ackTimeout,
      commit: (ids) {
        final batch = db.batch();
        for (final id in ids) {
          batch.set(db.collection(_collection).doc(id), items[id]!);
        }
        return batch.commit();
      },
    );
  }

  /// تحويل صورة base64 (data URL) من نسخة الويب إلى ملف محلي.
  static Future<String?> _saveLegacyImage(String? dataUrl) async {
    if (dataUrl == null) return null;
    try {
      final comma = dataUrl.indexOf(',');
      if (comma < 0) return null;
      final header = dataUrl.substring(0, comma);
      if (!header.contains('base64')) return null;
      final bytes = base64Decode(dataUrl.substring(comma + 1));
      final ext = header.contains('png') ? '.png' : '.jpg';
      return await ImageStore.saveBytes(bytes, ext: ext);
    } catch (_) {
      return null;
    }
  }

  /// مهلة حماية للصور الحديثة — أي ملف أُنشئ خلالها لا يُحذف مهما بدا يتيماً.
  ///
  /// **لماذا:** المستخدم يلتقط الصورة في نموذج الإضافة فتُكتب على القرص فوراً،
  /// لكن صف المادة لا يُكتب في القاعدة إلا عند ضغط «حفظ» — وبينهما دقائق يكتب
  /// فيها الاسم والسعر والكمية. لو انتهت مزامنة الإقلاع في تلك الأثناء، رأى
  /// التنظيف ملفاً «لا يشير إليه أي دواء» فحذف صورة المستخدم قبل حفظها، فتُشير
  /// المادة بعد الحفظ إلى ملف غير موجود.
  static const _orphanGrace = Duration(hours: 1);

  /// تنظيف صور يتيمة لا يشير إليها أي دواء (بعد مزامنة نزول).
  /// لا يرمي أبداً — يُستدعى بـ`unawaited` فأي رمية تصير خطأً غير ملتقَط.
  Future<void> pruneOrphanImages() async {
    try {
      final used = (await MedicineDb.instance.getAll())
          .map((m) => m.imagePath)
          .whereType<String>()
          .toSet();
      final dirPath = ImageStore.dirPathSync;
      if (dirPath == null) return;
      final dir = Directory(dirPath);
      if (!await dir.exists()) return;

      final cutoff = DateTime.now().subtract(_orphanGrace);
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (used.contains(name)) continue;
        // ملف حديث = غالباً صورة قيد الإدخال لم تُحفظ مادتها بعد
        final stat = await entity.stat();
        if (stat.modified.isAfter(cutoff)) continue;
        await entity.delete();
      }
    } catch (e) {
      debugPrint('تعذّر تنظيف الصور اليتيمة: $e');
    }
  }
}
