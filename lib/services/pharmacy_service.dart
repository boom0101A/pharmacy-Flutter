import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'app_settings.dart';
import 'auth_service.dart';

/// سبب فشل طلب الانضمام برمز اقتران — يُترجَم إلى رسالة عربية في الواجهة.
enum PairingJoinError { notFound, notOpen, expired }

class PairingJoinException implements Exception {
  final PairingJoinError reason;
  const PairingJoinException(this.reason);
}

/// حالة رمز الاقتران كما تراها الواجهة — دالة صِرفة لا تلمس الشبكة.
enum PairingStatus {
  open,
  requested,
  joined,
  declined,
  cancelled,
  expired,
  unknown,
}

/// صيدلية مشتركة بين أكثر من جهاز، ورموز الاقتران التي تربط جهازاً جديداً بها.
///
/// **لماذا هذا ضروري:** المصادقة مجهولة ومرتبطة بكل تثبيت — كل هاتف يحصل على
/// هوية مختلفة تماماً، فلا يقدر جهازان على مشاركة نفس مستندات `medicines`
/// تحت نظام الملكية الفردية القديم. هذه الخدمة تنشئ مستند `pharmacies` يحمل
/// قائمة أعضاء (`memberUids`)، وتدير رمز اقتران قصير الأجل يتيح لجهاز جديد أن
/// يطلب الانضمام — لكن **فقط عضو حالي** يقدر فعلياً على إضافته لقائمة
/// الأعضاء (تفرضه قواعد Firestore نفسها)، فلا انضمام بلا موافقة صريحة.
class PharmacyService {
  PharmacyService._();
  static final PharmacyService instance = PharmacyService._();

  static const _pharmacies = 'pharmacies';
  static const _pairing = 'pairing';
  static const _codeLength = 6;
  static const _ttl = Duration(minutes: 10);

  FirebaseFirestore? _db;

  /// تُستدعى من SyncService بعد تهيئة Firebase بنجاح.
  static void attach(FirebaseFirestore db) => instance._db = db;

  String? get _uid => AuthService.instance.uid;

  /// يعيد معرّف صيدلية هذا الجهاز، منشئاً واحدة جديدة (بعضو وحيد هو الجهاز
  /// نفسه) إن لم توجد من قبل. لا يرمي استثناءً أبداً — الفشل يعني المحاولة
  /// في المرة القادمة.
  Future<String?> ensureOwnPharmacy() async {
    final cached = AppSettings.instance.pharmacyId;
    if (cached != null) return cached;

    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) return null;

    try {
      final ref = db.collection(_pharmacies).doc();
      await ref.set({
        'ownerUid': uid,
        'memberUids': [uid],
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      await AppSettings.instance.setPharmacyId(ref.id);
      return ref.id;
    } catch (e) {
      debugPrint('تعذّر إنشاء صيدلية جديدة: $e');
      return null;
    }
  }

  /// يولّد رمز اقتران جديداً صالحاً لمدة 10 دقائق، أو null إن تعذّر ذلك
  /// (بلا اتصال، أو تصادم متكرر مع رموز مستخدَمة).
  Future<String?> createPairingCode(String pharmacyId) async {
    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) return null;

    final rng = Random();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = generateCode(rng);
      final ref = db.collection(_pairing).doc(code);
      try {
        final existing = await ref.get();
        if (existing.exists) continue; // رمز مستخدَم فعلاً، جرّب غيره

        final now = DateTime.now();
        await ref.set({
          'pharmacyId': pharmacyId,
          'ownerUid': uid,
          'status': 'open',
          'createdAt': now.millisecondsSinceEpoch,
          'expiresAt': now.add(_ttl).millisecondsSinceEpoch,
        });
        return code;
      } catch (e) {
        debugPrint('تعذّر توليد رمز اقتران (محاولة ${attempt + 1}): $e');
      }
    }
    return null;
  }

  /// بث حي لحالة رمز اقتران — يستعمله الجهاز المالك لمعرفة لحظة وصول طلب
  /// انضمام، والجهاز المنضمّ لمعرفة لحظة الموافقة.
  Stream<DocumentSnapshot<Map<String, Object?>>> watchPairing(String code) {
    final db = _db;
    if (db == null) return const Stream.empty();
    return db.collection(_pairing).doc(code).snapshots();
  }

  /// الجهاز الجديد يطلب الانضمام برمز أدخله المستخدم يدوياً.
  ///
  /// يتحقق محلياً أولاً (وجود الرمز، حالته، صلاحيته) ليعطي المستخدم رسالة
  /// عربية واضحة بدل خطأ Firestore الخام إن رفضته القواعد لاحقاً لأي سبب.
  Future<void> requestJoin(String code) async {
    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) {
      throw const PairingJoinException(PairingJoinError.notFound);
    }

    final ref = db.collection(_pairing).doc(code);
    final snap = await ref.get();
    if (!snap.exists) {
      throw const PairingJoinException(PairingJoinError.notFound);
    }

    final data = snap.data()!;
    final status = statusOf(data, DateTime.now());
    if (status == PairingStatus.expired) {
      throw const PairingJoinException(PairingJoinError.expired);
    }
    if (status != PairingStatus.open) {
      throw const PairingJoinException(PairingJoinError.notOpen);
    }

    await ref.update({'status': 'requested', 'joinerUid': uid});
  }

  /// صاحب الصيدلية يوافق على طلب انضمام — يضيف طالب الانضمام لقائمة الأعضاء
  /// فعلياً. هذه هي الخطوة الوحيدة التي تمنح عضوية حقيقية.
  Future<void> approveJoin(String code) async {
    final db = _db;
    if (db == null) return;

    final pairingRef = db.collection(_pairing).doc(code);
    final pairingSnap = await pairingRef.get();
    if (!pairingSnap.exists) return;

    final data = pairingSnap.data()!;
    final pharmacyId = data['pharmacyId'] as String?;
    final joinerUid = data['joinerUid'] as String?;
    if (pharmacyId == null || joinerUid == null) return;

    final pharmacyRef = db.collection(_pharmacies).doc(pharmacyId);
    final pharmacySnap = await pharmacyRef.get();
    final members = List<String>.from(
      (pharmacySnap.data()?['memberUids'] as List?) ?? const [],
    );

    final batch = db.batch();
    if (!members.contains(joinerUid)) {
      batch.update(pharmacyRef, {
        'memberUids': [...members, joinerUid],
      });
    }
    batch.update(pairingRef, {'status': 'joined'});
    await batch.commit();
  }

  /// صاحب الصيدلية يرفض طلب انضمام.
  Future<void> declineJoin(String code) async {
    final db = _db;
    if (db == null) return;
    await db.collection(_pairing).doc(code).update({'status': 'declined'});
  }

  /// صاحب الصيدلية يلغي رمزاً لم يُستخدم بعد (مثلاً أغلق الشاشة).
  Future<void> cancelPairingCode(String code) async {
    final db = _db;
    if (db == null) return;
    await db.collection(_pairing).doc(code).delete();
  }

  /// أعضاء صيدلية هذا الجهاز، أو null إن تعذّر (بلا اتصال أو بلا صيدلية).
  Future<PharmacyMembers?> fetchMembers() async {
    final db = _db;
    final pid = AppSettings.instance.pharmacyId;
    if (db == null || pid == null) return null;
    try {
      final snap = await db.collection(_pharmacies).doc(pid).get();
      final data = snap.data();
      if (data == null) return null;
      return PharmacyMembers(
        ownerUid: data['ownerUid'] as String? ?? '',
        memberUids: List<String>.from(
          (data['memberUids'] as List?) ?? const [],
        ),
      );
    } catch (e) {
      debugPrint('تعذّرت قراءة أعضاء الصيدلية: $e');
      return null;
    }
  }

  /// المالك يُخرج جهازاً من المخزون المشترك — يفقد فوراً أي قراءة أو كتابة
  /// (القواعد تتحقق من العضوية في كل طلب). يرمي عند الفشل.
  Future<void> removeMember(String uid) async {
    final db = _db;
    final me = _uid;
    final pid = AppSettings.instance.pharmacyId;
    if (db == null || me == null || pid == null) {
      throw StateError('المزامنة غير مفعّلة');
    }
    final ref = db.collection(_pharmacies).doc(pid);
    final data = (await ref.get()).data() ?? const {};
    final next = membersAfterRemoval(
      members: List<String>.from((data['memberUids'] as List?) ?? const []),
      ownerUid: data['ownerUid'] as String? ?? '',
      requester: me,
      target: uid,
    );
    await ref.update({'memberUids': next});
  }

  /// قائمة الأعضاء بعد إخراج [target] — نفس شروط firestore.rules حرفياً حتى
  /// تُرفض المحاولة محلياً برسالة واضحة قبل أن ترفضها القواعد.
  @visibleForTesting
  static List<String> membersAfterRemoval({
    required List<String> members,
    required String ownerUid,
    required String requester,
    required String target,
  }) {
    if (requester != ownerUid) {
      throw StateError('فقط صاحب المخزون يُخرج الأجهزة');
    }
    if (target == ownerUid) throw StateError('لا يمكن إخراج صاحب المخزون');
    if (!members.contains(target)) throw StateError('الجهاز ليس عضواً');
    return [...members]..remove(target);
  }

  /// معرّف قصير يُعرض للمستخدم ليميّز الأجهزة («G7IWAicA…»).
  static String shortId(String uid) =>
      uid.length <= 8 ? uid : '${uid.substring(0, 8)}…';

  /// مدة صلاحية رمز الاقتران — تحتاجها الواجهة لتحديث العرض عند انتهائه.
  static Duration get pairingTtl => _ttl;

  /// حالة رمز الاقتران كما يجب أن تعرضها الواجهة — دالة صِرفة بلا شبكة،
  /// تأخذ في الحسبان انتهاء الصلاحية حتى لو لم يُحدَّث الحقل `status` بعد.
  /// تُستعمل من `pairing_sheet.dart` مباشرة، وليست حصراً للاختبار.
  static PairingStatus statusOf(Map<String, Object?> data, DateTime now) {
    final raw = data['status'] as String?;
    if (raw == 'open') {
      final expiresAt = (data['expiresAt'] as num?)?.toInt();
      if (expiresAt != null && isExpired(expiresAt, now)) {
        return PairingStatus.expired;
      }
      return PairingStatus.open;
    }
    return switch (raw) {
      'requested' => PairingStatus.requested,
      'joined' => PairingStatus.joined,
      'declined' => PairingStatus.declined,
      'cancelled' => PairingStatus.cancelled,
      _ => PairingStatus.unknown,
    };
  }

  @visibleForTesting
  static bool isExpired(int expiresAtMillis, DateTime now) =>
      now.millisecondsSinceEpoch >= expiresAtMillis;

  /// رمز رقمي من 6 خانات دائماً (100000-999999) — لا حاجة لحشو صفري.
  @visibleForTesting
  static String generateCode(Random rng) {
    final min = pow(10, _codeLength - 1).toInt();
    return (min + rng.nextInt(min * 9)).toString();
  }
}

/// أعضاء صيدلية مشتركة كما في مستند `pharmacies`.
class PharmacyMembers {
  const PharmacyMembers({required this.ownerUid, required this.memberUids});

  final String ownerUid;
  final List<String> memberUids;
}
