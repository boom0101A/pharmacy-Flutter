import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../db/medicine_db.dart';
import '../models/medicine.dart';
import 'app_settings.dart';
import 'auth_service.dart';
import 'barcode_registry.dart';
import 'image_store.dart';
import 'pharmacy_service.dart';

enum SyncStatus { disabled, offline, syncing, synced, error }

/// مزامنة الأدوية مع Firestore.
///
/// المبدأ: القاعدة المحلية (SQLite) هي المصدر الأساسي — التطبيق يعمل كاملاً
/// بدون إنترنت. Firestore طبقة نسخ احتياطي/مشاركة بين الأجهزة، ويُحسم التعارض
/// بالأحدث (`updatedAt` الأكبر يفوز).
///
/// ملاحظة: الصور تبقى محلية على الجهاز ولا تُرفع (يحتاج Firebase Storage).
class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const _collection = 'medicines';
  static const _tombstones = 'tombstones';

  /// Firestore يرفض الدفعة فوق 500 عملية — نبقى دونها بهامش أمان.
  static const _batchLimit = 450;

  FirebaseFirestore? _db;
  SyncStatus _status = SyncStatus.disabled;
  String? _lastError;

  SyncStatus get status => _status;
  String? get lastError => _lastError;

  /// المزامنة تحتاج قاعدة **وهوية مالك** — بدونها القواعد سترفض كل كتابة.
  bool get isEnabled => _db != null && AuthService.instance.isSignedIn;

  String? get _uid => AuthService.instance.uid;

  String get statusLabel => switch (_status) {
    SyncStatus.disabled => 'حفظ محلي',
    SyncStatus.offline => 'غير متصل — حفظ محلي',
    SyncStatus.syncing => 'جاري المزامنة…',
    SyncStatus.synced => 'مزامنة سحابية ✓',
    SyncStatus.error => 'تعذّرت المزامنة',
  };

  /// ترجمة أخطاء Firestore الشائعة إلى سبب واضح وخطوة إصلاح.
  static String _explain(FirebaseException e) => switch (e.code) {
    'permission-denied' =>
      'قواعد أمان Firestore ترفض الوصول.\n'
          'الحل: Firebase Console ← Firestore Database ← Rules ← اسمح '
          'بالقراءة والكتابة لمجموعة medicines ثم Publish.',
    'not-found' =>
      'قاعدة بيانات Firestore غير منشأة في هذا المشروع.\n'
          'الحل: Firebase Console ← Build ← Firestore Database ← Create database.',
    'unavailable' => 'لا يوجد اتصال بالإنترنت — البيانات محفوظة محلياً.',
    'failed-precondition' =>
      'خدمة Firestore غير مفعّلة أو تحتاج إعداداً في Console.',
    'unauthenticated' =>
      'هوية الجهاز غير جاهزة.\n'
          'الحل: Firebase Console ← Authentication ← Sign-in method ← '
          'تفعيل Anonymous.',
    _ => '${e.code}: ${e.message ?? 'خطأ غير معروف'}',
  };

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
        ..['pharmacyId'] = AppSettings.instance.pharmacyId;

  /// رفع دواء واحد (بعد الحفظ المحلي). لا يرمي استثناءً أبداً.
  Future<void> pushMedicine(Medicine medicine) async {
    final db = _db;
    if (db == null || !isEnabled) return;
    try {
      await db.collection(_collection).doc(medicine.id).set(_payload(medicine));
      _setStatus(SyncStatus.synced);
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
      });
      await batch.commit();
      _setStatus(SyncStatus.synced);
      return true;
    } on FirebaseException catch (e) {
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

  /// مزامنة كاملة في الاتجاهين. ترجع true إذا تغيّرت البيانات المحلية.
  Future<bool> syncAll() async {
    final db = _db;
    final uid = _uid;
    final pharmacyId = AppSettings.instance.pharmacyId;
    if (db == null || uid == null || pharmacyId == null) return false;

    _setStatus(SyncStatus.syncing);
    try {
      final local = await MedicineDb.instance.getAll();
      final localById = {for (final m in local) m.id: m};

      // سجلات صيدلية هذا الجهاز فقط (قد تكون مشتركة مع أجهزة أخرى — راجع
      // pharmacy_service.dart). سجلات لم تُوسَم بـ pharmacyId بعد لا تُقرأ
      // هنا — خطوة الهجرة في MedicineStore.refreshFromCloud هي ما تمنحها
      // هذا الوسم من النسخة المحلية قبل أول استدعاء لهذه الدالة.
      final snapshot = await db
          .collection(_collection)
          .where('pharmacyId', isEqualTo: pharmacyId)
          .get();
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

      final deletedIds = await _tombstoneIds(db, pharmacyId, uid);

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

      // صعود: ما هو محلي وأحدث (أو غير موجود في السحابة) وليس محذوفاً
      for (final mine in local) {
        if (deletedIds.contains(mine.id)) continue;
        final remote = remoteById[mine.id];
        if (remote == null || mine.updatedAt > remote.updatedAt) {
          pending[mine.id] = _payload(mine);
        }
      }

      // `local` لُقط في بداية الدورة؛ مادة حذفها المستخدم أثناءها دخلت الطابور
      // بعد ذلك. بلا قراءة ثانية هنا يُعاد رفعها فتصير «زومبي» في السحابة.
      dropQueuedDeletes(
        pending,
        await MedicineDb.instance.peekPendingDeletes(),
      );
      await _commitInChunks(db, pending);

      _setStatus(
        SyncStatus.synced,
        error: skipped > 0
            ? 'تمت المزامنة، لكن تم تخطّي $skipped سجل غير صالح في السحابة.'
            : null,
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
    await _commitInChunks(db, pending);
    return pending.length;
  }

  /// كتابة دفعية مقسّمة — دفعة Firestore الواحدة تفشل كاملة فوق 500 عملية،
  /// وأول مزامنة لجهاز جديد بعد بضع فواتير تتجاوز ذلك بسهولة.
  Future<void> _commitInChunks(
    FirebaseFirestore db,
    Map<String, Map<String, Object?>> items,
  ) async {
    if (items.isEmpty) return;
    final entries = items.entries.toList();
    for (var i = 0; i < entries.length; i += _batchLimit) {
      final end = (i + _batchLimit).clamp(0, entries.length);
      final batch = db.batch();
      for (final e in entries.sublist(i, end)) {
        batch.set(db.collection(_collection).doc(e.key), e.value);
      }
      await batch.commit();
    }
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
