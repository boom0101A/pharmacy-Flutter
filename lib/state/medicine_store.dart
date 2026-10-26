import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../db/medicine_db.dart';
import '../models/medicine.dart';
import '../services/app_settings.dart';
import '../services/barcode_registry.dart';
import '../services/duplicate_dismissals.dart';
import '../services/duplicates.dart';
import '../services/gs1_parser.dart';
import '../services/image_store.dart';
import '../services/notification_service.dart';
import '../services/pharmacy_service.dart';
import '../services/sync_service.dart';
import '../util/number_parse.dart';

enum QuickFilter {
  lowStock,
  incomplete,
  noBarcode,
  hasImage,
  noImage,
  expiringSoon,
}

enum SortField { date, name, price, quantity }

/// حالة البحث والفلاتر لقسم واحد.
///
/// لكل قسم نسخته الخاصة، فبحث المستخدم في «الأدوية» لا يخفي مستلزماته.
class _SectionFilters {
  String keyword = '';
  final Set<QuickFilter> quickFilters = {};
  double? priceMin, priceMax;
  int? qtyMin, qtyMax;
  SortField sortField = SortField.date;
  bool sortAscending = false;

  /// يزيد مع كل إعادة تعيين — حقول النطاق في الواجهة تُبنى من جديد به فلا
  /// تبقى أرقام قديمة ظاهرة بعد إلغاء الفلتر.
  int resetCount = 0;

  void resetFilters() {
    resetCount++;
    quickFilters.clear();
    priceMin = priceMax = null;
    qtyMin = qtyMax = null;
    sortField = SortField.date;
    sortAscending = false;
  }
}

/// حالة التطبيق: قائمة الأدوية + البحث + الفلاتر + الترتيب.
/// منقولة عن منطق renderCards/applyFilters في الأداة الأصلية.
class MedicineStore extends ChangeNotifier {
  final _db = MedicineDb.instance;

  List<Medicine> _all = [];
  bool _loading = true;

  /// القسم المعروض حالياً — التبويب العلوي يغيّره.
  ItemType _activeType = ItemType.medicine;

  final Map<ItemType, _SectionFilters> _sections = {
    for (final t in ItemType.values) t: _SectionFilters(),
  };

  _SectionFilters get _f => _sections[_activeType]!;

  /// نتيجة الفلترة والترتيب لكل قسم، محفوظة حتى تتغيّر البيانات فعلاً.
  ///
  /// أثناء تمرير التبويب يُعاد بناء القسمين في كل إطار (60 مرة بالثانية).
  /// إعادة فرز القائمة كاملة في كل إطار هي ما يقطّع الحركة — فنحسبها مرة
  /// ونعيد النتيجة نفسها حتى يستدعي أحدهم `notifyListeners`.
  final Map<ItemType, List<Medicine>> _visibleCache = {};

  /// عدد مجموعات التكرار — يُحسب عند الطلب ويُحفظ حتى يتغيّر شيء.
  int? _duplicateCount;

  MedicineStore() {
    // قرار «ليست مكرّرة» من أي جهاز يغيّر العدد الظاهر في الرئيسية
    DuplicateDismissals.instance.addListener(notifyListeners);
  }

  @override
  void dispose() {
    DuplicateDismissals.instance.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  void notifyListeners() {
    _visibleCache.clear();
    _duplicateCount = null;
    super.notifyListeners();
  }

  /// الفحص التلقائي المستمر: مجموعات التكرار في المخزون المحلي بعد استبعاد
  /// قرارات «ليست مكرّرة». يُعاد حسابه بعد كل تغيير (حفظ، حذف، مزامنة، دمج)
  /// — لا في كل إعادة رسم. تقريبي: مجموعات الباركود الموجودة في السحابة فقط
  /// لا تُرى محلياً، وشاشة المراجعة نفسها تقرأ السحابة فتُظهرها كاملة.
  int get duplicateGroupCount => _duplicateCount ??= findDuplicateGroups([
    for (final m in _all)
      if (!_pendingDeleteIds.contains(m.id)) m,
  ], dismissed: DuplicateDismissals.instance.keys).length;

  bool get isLoading => _loading;
  List<Medicine> get all => _all;

  /// تعبئة الحالة مباشرة في الاختبارات، بلا قاعدة بيانات ولا شبكة.
  @visibleForTesting
  void seed(List<Medicine> items) {
    _all = List.of(items);
    _loading = false;
    notifyListeners();
  }

  ItemType get activeType => _activeType;

  void setActiveType(ItemType type) {
    if (_activeType == type) return;
    _activeType = type;
    notifyListeners();
  }

  /// معرّفات حُذفت في الواجهة لكن الحذف الفعلي مؤجَّل لمهلة التراجع —
  /// تُستبعد من كل عرض وإحصاء فوراً بلا لمس القاعدة، فيبدو الحذف فورياً
  /// ويبقى قابلاً للإلغاء حتى تنتهي المهلة أو يُحفظ حذف جديد فوقها.
  final Set<String> _pendingDeleteIds = {};

  /// مواد القسم النشط قبل البحث والفلاتر.
  List<Medicine> get _inSection => _sectionItems(_activeType);

  List<Medicine> _sectionItems(ItemType type) => _all
      .where((m) => m.type == type && !_pendingDeleteIds.contains(m.id))
      .toList();

  int countOf(ItemType type) => _sectionItems(type).length;

  /// أول مادة في نفس القسم تحمل الاسم نفسه (بلا حساسية لحالة الأحرف أو
  /// المسافات الزائدة)، أو null إن لم توجد.
  ///
  /// تُستعمل في مراجعة الفاتورة: مواد المجهّزين بلا باركود، فالاسم هو
  /// المطابق الوحيد المتاح لاكتشاف أن الفاتورة تكرّر مادة موجودة بالفعل.
  ///
  /// [barcode]: باركود السطر/المادة الجديدة. مادة موجودة بباركود **مختلف**
  /// صنف آخر (نفس الدواء بطعم أو لون آخر) فلا تُطابَق بالاسم — كان الوارد
  /// يُضاف لرصيد الصنف الخطأ.
  Medicine? findExistingByName(String name, ItemType type, {String? barcode}) {
    final norm = normalizeName(name);
    if (norm.isEmpty) return null;
    final code = Gs1Parser.canonicalKey(barcode ?? '');
    for (final m in _all) {
      if (m.type != type || normalizeName(m.name) != norm) continue;
      final other = Gs1Parser.canonicalKey(m.barcode);
      if (code != null && other != null && code != other) continue;
      return m;
    }
    return null;
  }

  /// المادة التي تحمل هذا الباركود (أو صيغته المكافئة 13/14 خانة) في أي قسم.
  ///
  /// بلا قيد القسم عمداً: الفهرس الفريد على `barcode` يشمل الجدول كله، فسطر
  /// فاتورة مصنَّف «مستلزم» بباركود دواء موجود سيصطدم به مهما كان قسمه.
  Medicine? findExistingByBarcode(String barcode) {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    final variants = Gs1Parser.lookupVariants(code).toSet();
    for (final m in _all) {
      if (m.barcode.isNotEmpty && variants.contains(m.barcode)) return m;
    }
    return null;
  }

  /// تطبيع اسم للمطابقة: بلا حساسية لحالة الأحرف ولا مسافات زائدة.
  ///
  /// عامة (لا خاصة) لأن `invoice_scan_screen.dart` يحتاج نفس التعريف بالضبط
  /// لدمج أسطر الفاتورة المكرَّرة قبل مقارنتها بهذا المخزن — تعريفان منفصلان
  /// لنفس المفهوم يخاطران بالانحراف صمتاً مع أي تعديل مستقبلي.
  static String normalizeName(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// إحصاءات قسم بعينه — التبويب المجاور يحتاجها أثناء التمرير.
  double totalValueOf(ItemType type) =>
      _sectionItems(type).fold(0, (sum, m) => sum + m.totalValue);

  int missingPriceCountOf(ItemType type) =>
      _sectionItems(type).where((m) => m.price <= 0).length;

  int incompleteCountOf(ItemType type) =>
      _sectionItems(type).where((m) => m.isIncomplete).length;

  /// قائمة «إكمال البيانات»: بلا سعر أولاً (يُفسد القيمة الإجمالية)، ثم بلا
  /// باركود، والأحدث تعديلاً أولاً داخل كل منهما.
  List<Medicine> incompleteItems(ItemType type) =>
      _sectionItems(type).where((m) => m.isIncomplete).toList()..sort((a, b) {
        final byPrice = (a.price <= 0 ? 0 : 1).compareTo(b.price <= 0 ? 0 : 1);
        return byPrice != 0 ? byPrice : b.updatedAt.compareTo(a.updatedAt);
      });

  String get keyword => _f.keyword;
  Set<QuickFilter> get quickFilters => _f.quickFilters;
  double? get priceMin => _f.priceMin;
  double? get priceMax => _f.priceMax;
  int? get qtyMin => _f.qtyMin;
  int? get qtyMax => _f.qtyMax;
  int get filterResetCount => _f.resetCount;
  SortField get sortField => _f.sortField;
  bool get sortAscending => _f.sortAscending;

  /// الإحصاءات تخصّ القسم النشط وحده — خلط الأدوية بالمستلزمات يضلّل.
  int get totalCount => _inSection.length;
  double get totalValue => _inSection.fold(0, (sum, m) => sum + m.totalValue);

  /// مواد بلا سعر — قيمتها تُحسب صفراً فتجعل «القيمة الإجمالية» أقل من الحقيقة.
  /// عرض العدد أصدق من عرض رقم ناقص بلا تنبيه.
  int get missingPriceCount => _inSection.where((m) => m.price <= 0).length;

  bool get hasActiveFilters =>
      _f.keyword.isNotEmpty ||
      _f.quickFilters.isNotEmpty ||
      _f.priceMin != null ||
      _f.priceMax != null ||
      _f.qtyMin != null ||
      _f.qtyMax != null;

  int get activeFilterCount {
    var n = _f.quickFilters.length;
    if (_f.priceMin != null || _f.priceMax != null) n++;
    if (_f.qtyMin != null || _f.qtyMax != null) n++;
    return n;
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    await _repairLegacyBarcodes();
    await DuplicateDismissals.instance.loadLocal();
    _all = await _db.getAll();
    _loading = false;
    notifyListeners();

    // مزامنة في الخلفية — لا تعطّل عرض البيانات المحلية
    unawaited(refreshFromCloud());
    // إعادة جدولة إشعار الغد بمحتوى محدَّث — كل تعديل بعده يُحدّثه أيضاً
    _scheduleDigestIfEnabled();
  }

  /// يُعيد جدولة إشعار الصلاحية اليومي بمحتوى `_all` الحالي — يُستدعى بعد
  /// كل عملية تُغيّر البيانات (حفظ، حذف، مزامنة). يتخطى بلا ضجيج إن كان
  /// المفتاح في الإعدادات معطَّلاً.
  void _scheduleDigestIfEnabled() {
    if (!AppSettings.instance.stockNotificationsEnabled) return;
    unawaited(NotificationService.instance.scheduleDailyDigest(_all));
  }

  /// مزامنة كاملة مع Firestore ثم إعادة تحميل القائمة إذا تغيّرت.
  ///
  /// [manual] يعني سحب المستخدم للتحديث بيده — نيّة صريحة لإعادة المحاولة،
  /// فنلغي ذاكرة الفشل. لا نلغيها عند كل إقلاع وإلا صارت مهلة الأيام السبعة
  /// بلا معنى وأُعيد البحث عن كل باركود مجهول في كل تشغيل.
  /// دورة المزامنة الجارية — الاستدعاء الثاني ينتظرها بدل بدء دورة موازية.
  ///
  /// بلا هذا الحارس: `load()` يُطلق `unawaited(refreshFromCloud())` عند
  /// الإقلاع، وسحب المستخدم للتحديث يُطلق دورة ثانية فوقها. عند أول تشغيل
  /// (لا `pharmacyId` بعد) تقرأ الدورتان «لا صيدلية» معاً فتُنشئان **مستندَي
  /// صيدلية مختلفين**، والثاني يفوز — فيصير كل ما رُفع تحت الأول غير مرئي
  /// لاستعلام `where('pharmacyId')` ويبدو المخزون وكأنه اختفى. ويعمل
  /// `backfillPharmacyId` (رفع كامل للمحلي) مرتين بلا داعٍ.
  Future<void>? _refreshInFlight;

  Future<void> refreshFromCloud({bool manual = false}) async {
    final running = _refreshInFlight;
    if (running != null) return running;

    final run = _runRefreshFromCloud(manual: manual);
    _refreshInFlight = run;
    try {
      await run;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<void> _runRefreshFromCloud({bool manual = false}) async {
    if (manual) await _db.clearAllMisses();

    if (!SyncService.instance.isEnabled) return;

    // وسم السجلات القديمة بمالكها — مرة واحدة، قبل تشديد قواعد الأمان
    if (!AppSettings.instance.ownerClaimDone) {
      try {
        final claimed = await SyncService.instance.claimLegacyRecords();
        debugPrint('وُسم $claimed سجلاً بمالكه');
        await AppSettings.instance.markOwnerClaimDone();
      } catch (e) {
        debugPrint('تعذّر وسم السجلات القديمة: $e');
      }
    }

    // إنشاء/جلب صيدلية هذا الجهاز، ثم وسم كل السجلات بمعرّفها — مرة واحدة.
    // بعدها تعتمد المزامنة والقواعد على pharmacyId لا ownerUid وحده، فيصبح
    // مشاركة المخزون بين أجهزة متعددة لصيدلية واحدة ممكناً (راجع pairing_sheet).
    final pharmacyId = await PharmacyService.instance.ensureOwnPharmacy();
    if (pharmacyId != null && !AppSettings.instance.pharmacyBackfillDone) {
      try {
        final tagged = await SyncService.instance.backfillPharmacyId(
          pharmacyId,
        );
        debugPrint('وُسم $tagged سجلاً بمعرّف الصيدلية');
        await AppSettings.instance.markPharmacyBackfillDone();
      } catch (e) {
        debugPrint('تعذّر وسم السجلات بمعرّف الصيدلية: $e');
      }
    }

    // المزامنة أولاً ثم تفريغ طابور الحذف: المزامنة تعامل ما في الطابور كمحذوف
    // (فلا تعيد تنزيله)، وتزيل منه أولاً أي أثر تعارض باركود قبل أن يحاول
    // التفريغ حذف مخزون حقيقي من السحابة.
    final changed = await SyncService.instance.syncAll();
    await _flushPendingDeletes();
    if (changed) {
      _all = await _db.getAll();
      notifyListeners();
    }
    unawaited(SyncService.instance.pruneOrphanImages());
    unawaited(DuplicateDismissals.instance.syncWithCloud());
    _scheduleDigestIfEnabled();
  }

  // ---------- عمليات الحفظ والحذف ----------

  Future<void> save(Medicine medicine) async {
    await _db.upsert(medicine);
    final i = _all.indexWhere((m) => m.id == medicine.id);
    if (i >= 0) {
      _all[i] = medicine;
    } else {
      _all.insert(0, medicine);
    }
    notifyListeners();

    // صار معروفاً — ارفع عنه علامة "لم يوجد" حتى لا يُتخطى بحثه مستقبلاً
    if (medicine.barcode.isNotEmpty) {
      unawaited(_db.clearMiss(Gs1Parser.lookupVariants(medicine.barcode)));
    }

    unawaited(SyncService.instance.pushMedicine(medicine));

    // مساهمة بالاسم والصورة فقط في القاموس المشترك — بلا سعر ولا كمية
    unawaited(
      BarcodeRegistry.contribute(
        barcode: medicine.barcode,
        name: medicine.name,
        imageFileName: medicine.imagePath,
      ),
    );

    _scheduleDigestIfEnabled();
  }

  /// استيراد نسخة احتياطية: يضيف الجديد ويحدّث الأقدم فقط.
  ///
  /// لا يحذف شيئاً موجوداً — الاستيراد استرجاع لا استبدال.
  /// يعيد (المضاف، المحدَّث، المتخطّى).
  Future<({int added, int updated, int skipped})> importBackup(
    List<Medicine> incoming,
  ) async {
    final byId = {for (final m in _all) m.id: m};
    // مادة حُذفت ولم يُرفع حذفها بعد لا تُحيا من نسخة قديمة
    final deleted = (await _db.peekPendingDeletes()).toSet();
    final toWrite = <Medicine>[];
    var added = 0, updated = 0, skipped = 0;

    for (final raw in incoming) {
      // نسخة من جهاز آخر تحمل أسماء صور غير موجودة هنا — مادة «لديها صورة»
      // بلا ملف تخدع الفلتر وتفتح صورة مكسورة
      final item = raw.hasImage && !_imageExists(raw.imagePath)
          ? raw.copyWith(clearImage: true, updatedAt: raw.updatedAt)
          : raw;
      final mine = byId[item.id];
      if (deleted.contains(item.id)) {
        skipped++;
      } else if (mine == null) {
        toWrite.add(item);
        added++;
      } else if (item.updatedAt > mine.updatedAt) {
        toWrite.add(item);
        updated++;
      } else {
        skipped++;
      }
    }

    if (toWrite.isNotEmpty) {
      final losers = (await _db.upsertAllSkippingBarcodeConflicts(
        toWrite,
      )).toSet();
      for (final item in toWrite) {
        if (!losers.contains(item.id)) continue;
        // وارد يتعارض باركوده مع مادة محلية أخرى — لم يُكتب
        if (byId.containsKey(item.id)) {
          updated--;
        } else {
          added--;
        }
        skipped++;
      }
      _all = await _db.getAll();
      notifyListeners();
      for (final item in toWrite) {
        if (losers.contains(item.id)) continue;
        unawaited(SyncService.instance.pushMedicine(item));
      }
    }
    return (added: added, updated: updated, skipped: skipped);
  }

  static bool _imageExists(String? fileName) {
    final path = ImageStore.fullPathSync(fileName);
    return path != null && File(path).existsSync();
  }

  /// حفظ أسطر فاتورة مراجَعة دفعة واحدة.
  ///
  /// بعض العناصر مواد جديدة، وبعضها **تحديث** لمادة موجودة اختار المستخدم
  /// دمجها (نفس `id`) — لذا نُزيل أي نسخة قديمة من `_all` بدل افتراض أن كل
  /// شيء جديد، وإلا ظهرت المادة المدموجة مرتين محلياً حتى إعادة التحميل.
  ///
  /// لا مساهمة في القاموس المشترك هنا: مواد الفواتير بلا باركود، والقاموس
  /// مبني على الباركود.
  Future<void> saveAll(List<Medicine> items) async {
    if (items.isEmpty) return;
    await _db.upsertAll(items);

    final ids = items.map((m) => m.id).toSet();
    _all.removeWhere((m) => ids.contains(m.id));
    _all.insertAll(0, items);
    notifyListeners();

    for (final item in items) {
      unawaited(SyncService.instance.pushMedicine(item));
    }

    _scheduleDigestIfEnabled();
  }

  Future<void> delete(Medicine medicine) async {
    await _db.delete(medicine.id);
    await ImageStore.deleteFile(medicine.imagePath);
    _all.removeWhere((m) => m.id == medicine.id);
    notifyListeners();

    // نُدرج في الطابور قبل محاولة السحابة: إن انهار التطبيق أو ماتت الشبكة
    // بين هذه اللحظة والحذف السحابي، المعرّف باقٍ في SQLite فيُعاد لاحقاً
    // في _flushPendingDeletes، ولا نخسر الحذف بلا رجعة. المسح النهائي من
    // الطابور يحدث فقط عند تأكيد نجاح الحذف السحابي.
    await _db.enqueuePendingDelete(medicine.id);
    unawaited(_tryCloudDelete(medicine.id));

    _scheduleDigestIfEnabled();
  }

  /// دمج مكرّرات: الحذف والحفظ في معاملة واحدة ([MedicineDb.mergeInto]).
  ///
  /// كان الدمج حذفاً ثم حفظاً منفصلين — فشل الحفظ يُضيّع كميات المحذوفة.
  /// يرمي قبل أي تغيير إن تعذّر (مثلاً تعارض باركود)، فلا يُحذف شيء.
  Future<void> mergeDuplicates(Medicine keeper, List<Medicine> losers) async {
    await _db.mergeInto(
      keeper: keeper,
      loserIds: [for (final m in losers) m.id],
    );

    final ids = losers.map((m) => m.id).toSet();
    _all.removeWhere((m) => ids.contains(m.id));
    final i = _all.indexWhere((m) => m.id == keeper.id);
    if (i >= 0) {
      _all[i] = keeper;
    } else {
      _all.insert(0, keeper);
    }
    notifyListeners();

    for (final m in losers) {
      // صورة انتقلت للمادة الباقية لا تُحذف مع صاحبتها الأصلية
      if (m.imagePath != null && m.imagePath != keeper.imagePath) {
        await ImageStore.deleteFile(m.imagePath);
      }
      unawaited(_tryCloudDelete(m.id));
    }
    unawaited(SyncService.instance.pushMedicine(keeper));
    _scheduleDigestIfEnabled();
  }

  Future<void> _tryCloudDelete(String id) async {
    try {
      final ok = await SyncService.instance.deleteMedicine(id);
      if (ok) await _db.clearPendingDelete(id);
    } catch (e) {
      debugPrint('تعذّر الحذف السحابي — سيُعاد لاحقاً: $e');
    }
  }

  // ---------- حذف بمهلة تراجع ----------
  //
  // الواجهة تستدعي هذه الثلاثة بدل delete() مباشرة، لتتيح للمستخدم التراجع
  // قبل أن يلمس الحذف القاعدة فعلياً. delete() الحقيقية أعلاه لا تتغيّر —
  // تبقى تُستدعى داخلياً فقط بعد انتهاء مهلة التراجع بلا إلغاء.

  /// يُخفي المادة فوراً من كل الشاشات بلا حذفها — الخطوة الأولى للتراجع.
  void hideForPendingDelete(String id) {
    if (_pendingDeleteIds.add(id)) notifyListeners();
  }

  /// المستخدم ضغط «تراجع» — تعود المادة كأن شيئاً لم يحدث.
  void cancelPendingDelete(String id) {
    if (_pendingDeleteIds.remove(id)) notifyListeners();
  }

  /// انتهت مهلة التراجع بلا إلغاء — الحذف الفعلي يحدث الآن فقط.
  /// لا يفعل شيئاً إن كان قد أُلغي بالفعل (يمنع حذفاً مزدوجاً).
  Future<void> commitPendingDelete(Medicine medicine) async {
    if (!_pendingDeleteIds.remove(medicine.id)) return;
    await delete(medicine);
  }

  Future<Medicine?> findByBarcode(String barcode) =>
      _db.findByAnyBarcode(Gs1Parser.lookupVariants(barcode));

  /// مواد شاشة مراجعة التكرارات: السحابة مصحَّحة بالمحلي (راجع
  /// [reconcileReviewItems]). بلا اتصال تبقى المواد المحلية وحدها.
  Future<List<Medicine>> itemsForDuplicateReview() async {
    final cloud = await SyncService.instance.fetchPharmacyItems();
    final deleted = {...await _db.peekPendingDeletes(), ..._pendingDeleteIds};
    return reconcileReviewItems(
      cloud: cloud ?? const [],
      local: _all,
      deleted: deleted,
    );
  }

  /// عدد عمليات الحذف التي لم تصل للسحابة بعد — غير صفري يعني أن الحذف
  /// السحابي يفشل حالياً (شبكة أو صلاحيات).
  Future<int> pendingCloudDeleteCount() async =>
      (await _db.peekPendingDeletes()).length;

  Future<void> _flushPendingDeletes() async {
    try {
      // Peek بدل take: نمسح المعرّف فقط بعد نجاح الحذف السحابي، فلا يضيع
      // معرّف فاشل بلا رجعة عند تعذّر الشبكة أو الصلاحيات.
      final ids = await _db.peekPendingDeletes();
      var succeeded = 0;
      for (final id in ids) {
        final ok = await SyncService.instance.deleteMedicine(id);
        if (ok) {
          await _db.clearPendingDelete(id);
          succeeded++;
        }
      }
      if (succeeded > 0) {
        debugPrint('حُذف $succeeded من ${ids.length} سجل معلَّق من السحابة');
      }
    } catch (e) {
      debugPrint('تعذّر تفريغ طابور الحذف السحابي: $e');
    }
  }

  /// ترحيل لمرة واحدة: أدوية حُفظت قبل إضافة مفكّك GS1 يحمل باركودها
  /// السلسلة الكاملة (مع الرقم التسلسلي) بدل الـ GTIN وحده.
  Future<void> _repairLegacyBarcodes() async {
    if (AppSettings.instance.gs1RepairDone) return;
    try {
      final fixed = await _db.repairGs1Barcodes(
        (raw) => Gs1Parser.parse(raw).barcode,
      );
      if (fixed > 0) debugPrint('أُصلح باركود $fixed دواء إلى صيغة GTIN');
      await AppSettings.instance.markGs1RepairDone();
    } catch (e) {
      debugPrint('تعذّر ترحيل الباركودات القديمة: $e');
    }
  }

  // ---------- البحث والفلاتر ----------

  void setKeyword(String value) {
    _f.keyword = normalizeDigits(value).trim();
    notifyListeners();
  }

  void toggleQuickFilter(QuickFilter filter) {
    if (!_f.quickFilters.remove(filter)) _f.quickFilters.add(filter);
    notifyListeners();
  }

  void setPriceRange(double? min, double? max) {
    _f.priceMin = min;
    _f.priceMax = max;
    notifyListeners();
  }

  void setQuantityRange(int? min, int? max) {
    _f.qtyMin = min;
    _f.qtyMax = max;
    notifyListeners();
  }

  void setSort(SortField field) {
    if (_f.sortField == field) {
      _f.sortAscending = !_f.sortAscending;
    } else {
      _f.sortField = field;
      _f.sortAscending = field != SortField.date;
    }
    notifyListeners();
  }

  void resetFilters() {
    _f.resetFilters();
    notifyListeners();
  }

  void clearAll() {
    _f.keyword = '';
    resetFilters();
  }

  /// مواد القسم النشط بعد تطبيق البحث والفلاتر والترتيب.
  List<Medicine> get visible => visibleFor(_activeType);

  /// النتيجة المعروضة لقسم بعينه — مطلوبة لعرض التبويبين معاً أثناء التمرير.
  List<Medicine> visibleFor(ItemType type) {
    final cached = _visibleCache[type];
    if (cached != null) return cached;

    final f = _sections[type]!;
    final list = _sectionItems(type).where((m) => _matches(m, f)).toList();

    list.sort((a, b) {
      final cmp = switch (f.sortField) {
        SortField.date => a.createdAt.compareTo(b.createdAt),
        SortField.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        SortField.price => a.price.compareTo(b.price),
        SortField.quantity => a.quantity.compareTo(b.quantity),
      };
      return f.sortAscending ? cmp : -cmp;
    });

    return _visibleCache[type] = list;
  }

  String? _codeFor;
  String? _code;

  /// المفتاح القانوني لكلمة البحث — يُحسب مرة واحدة لكل كلمة لا لكل مادة.
  String? _keywordCode(String k) {
    if (k != _codeFor) {
      _codeFor = k;
      _code = Gs1Parser.canonicalKey(k);
    }
    return _code;
  }

  bool _matches(Medicine m, _SectionFilters f) {
    if (f.keyword.isNotEmpty) {
      final k = f.keyword.toLowerCase();
      final categoryMatch = (m.category ?? '').toLowerCase().contains(k);
      // باركود كامل: 13 رقماً يطابق نسخته ذات الـ14 (بصفر بادئ) والعكس
      final code = _keywordCode(k);
      if (!m.name.toLowerCase().contains(k) &&
          !m.barcode.toLowerCase().contains(k) &&
          !categoryMatch &&
          !(m.company ?? '').toLowerCase().contains(k) &&
          (code == null || Gs1Parser.canonicalKey(m.barcode) != code)) {
        return false;
      }
    }

    for (final quick in f.quickFilters) {
      final ok = switch (quick) {
        // منخفض أو نافد: الصفر المسعّر يُطلب، والصفر بلا سعر تسجيل ناقص
        QuickFilter.lowStock => m.isLowStock || m.isSoldOut,
        QuickFilter.incomplete => m.isIncomplete,
        QuickFilter.noBarcode => m.barcode.isEmpty,
        QuickFilter.hasImage => m.hasImage,
        QuickFilter.noImage => !m.hasImage,
        QuickFilter.expiringSoon => m.isExpiringSoon || m.isExpired,
      };
      if (!ok) return false;
    }

    if (f.priceMin != null && m.price < f.priceMin!) return false;
    if (f.priceMax != null && m.price > f.priceMax!) return false;
    if (f.qtyMin != null && m.quantity < f.qtyMin!) return false;
    if (f.qtyMax != null && m.quantity > f.qtyMax!) return false;

    return true;
  }
}
