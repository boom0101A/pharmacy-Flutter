import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/medicine.dart';

/// طبقة قاعدة البيانات المحلية — البديل عن IndexedDB في نسخة الويب.
class MedicineDb {
  MedicineDb._();
  static final MedicineDb instance = MedicineDb._();

  static const _dbName = 'pharmacy.db';
  static const _table = 'medicines';
  static const _missTable = 'barcode_misses';

  /// معرّفات حُذفت محلياً (دمج مكرر أو إصلاح باركود) ولم تُحذف من السحابة بعد.
  ///
  /// بدونها يعود المحذوف: النسخة السحابية تُنزَّل في المزامنة التالية فتُعيد
  /// إدراج السجل الذي دُمج، ويتكرر ذلك بلا نهاية.
  static const _pendingDeletes = 'pending_deletes';

  /// مدة تجاهل الباركود الذي لم يُعثر عليه، قبل إعادة المحاولة.
  /// قصيرة عمداً لأن القاموس المشترك ينمو باستمرار.
  static const missTtl = Duration(days: 7);

  Database? _db;

  /// إصدار المخطط الحالي — يُصدَّر ليقارن به الاختبار.
  static const schemaVersion = 8;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openAt(p.join(dir, _dbName));
    return _db!;
  }

  /// فتح القاعدة على مسار محدد بنفس مسار الترقية والإنشاء تماماً.
  ///
  /// عامة ليختبرها `test/db_migration_test.dart` على قواعد حقيقية بإصدارات
  /// قديمة — اختبار نسخة مكتوبة يدوياً من المنطق لا يثبت أن الترقية الفعلية
  /// ستنجح على هاتف المستخدم.
  static Future<Database> openAt(String path) => openDatabase(
    path,
    version: schemaVersion,
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) await _createMissTable(db);
      if (oldVersion < 3) {
        await db.execute('ALTER TABLE $_table ADD COLUMN expiryDate INTEGER');
      }
      if (oldVersion < 4) {
        // كل ما كان موجوداً قبل الفصل يصبح دواءً — قرار المستخدم صراحةً.
        await db.execute(
          "ALTER TABLE $_table ADD COLUMN itemType TEXT NOT NULL "
          "DEFAULT 'medicine'",
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_type ON $_table (itemType)',
        );
      }
      if (oldVersion < 5) {
        await _createPendingDeletes(db);
        await _dedupeBarcodes(db);
        await db.execute(_uniqueBarcodeIndex);
      }
      if (oldVersion < 6) {
        // الشكل الصيدلاني للمستلزمات (قرص/شراب/كريم...) — عمود نصّي حر
        // قابل للفراغ، فلا حاجة لأي ترحيل بيانات قبله.
        await db.execute('ALTER TABLE $_table ADD COLUMN category TEXT');
      }
      if (oldVersion < 7) {
        // الشركة المصنّعة — نصّي حر قابل للفراغ مثل category.
        await db.execute('ALTER TABLE $_table ADD COLUMN company TEXT');
      }
      if (oldVersion < 8) {
        // «ليس له باركود» — يُخرج المادة من «بيانات ناقصة»
        await db.execute(
          'ALTER TABLE $_table ADD COLUMN noBarcode INTEGER NOT NULL DEFAULT 0',
        );
      }
    },
    onCreate: (db, version) async {
      await db.execute('''
          CREATE TABLE $_table (
            id TEXT PRIMARY KEY,
            barcode TEXT NOT NULL DEFAULT '',
            name TEXT NOT NULL,
            price REAL NOT NULL DEFAULT 0,
            quantity INTEGER NOT NULL DEFAULT 0,
            imagePath TEXT,
            expiryDate INTEGER,
            itemType TEXT NOT NULL DEFAULT 'medicine',
            category TEXT,
            company TEXT,
            noBarcode INTEGER NOT NULL DEFAULT 0,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');
      await db.execute('CREATE INDEX idx_barcode ON $_table (barcode)');
      await db.execute('CREATE INDEX idx_name ON $_table (name)');
      await db.execute('CREATE INDEX idx_type ON $_table (itemType)');
      await db.execute(_uniqueBarcodeIndex);
      await _createMissTable(db);
      await _createPendingDeletes(db);
    },
  );

  /// توجيه المفرد إلى قاعدة اختبار مفتوحة مسبقاً.
  @visibleForTesting
  void attachForTest(Database? db) => _db = db;

  /// باركود واحد = مادة واحدة. الشرط الجزئي يستثني الفراغ لأن المستلزمات
  /// المُدخَلة بالفاتورة كلها بلا باركود ولا يجوز أن تتصادم مع بعضها.
  static const _uniqueBarcodeIndex =
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_barcode_unique "
      "ON $_table (barcode) WHERE barcode != ''";

  static Future<void> _createPendingDeletes(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_pendingDeletes (
        id TEXT PRIMARY KEY
      )
    ''');
  }

  /// حذف سجل محلياً مع تسجيله ليُحذف من السحابة لاحقاً.
  static Future<void> _deleteAndRemember(Database db, Object? id) async {
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    await db.insert(_pendingDeletes, {
      'id': id,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// المعرّفات التي تنتظر الحذف من السحابة — تُقرأ وتُمسح مرة واحدة.
  ///
  /// **تحذير:** المعرّف يُمسح من الجدول قبل التأكد من نجاح الحذف السحابي —
  /// إن فشل الحذف السحابي بعد هذا الاستدعاء، ينتحر السجل بلا رجعة. استعمل
  /// [peekPendingDeletes] + [clearPendingDelete] للمسارات التي تحتاج ضمان
  /// إعادة المحاولة عند الفشل.
  Future<List<String>> takePendingDeletes() async {
    final db = await database;
    final rows = await db.query(_pendingDeletes, columns: ['id']);
    if (rows.isEmpty) return const [];
    await db.delete(_pendingDeletes);
    return rows.map((r) => r['id'].toString()).toList();
  }

  /// قراءة المعرّفات المعلَّقة **بلا حذفها** — لاختبار حذف كل واحد ثم مسحه
  /// فقط عند نجاحه، فيبقى الفاشل في الطابور ليُعاد لاحقاً.
  Future<List<String>> peekPendingDeletes() async {
    final db = await database;
    final rows = await db.query(_pendingDeletes, columns: ['id']);
    return rows.map((r) => r['id'].toString()).toList();
  }

  /// إدراج معرّف في طابور الحذف — يتجاهل التكرار (المعرّف نفسه قد يُطلب حذفه
  /// مرة أخرى قبل أن ينجح الحذف الأول، وهذا سليم).
  Future<void> enqueuePendingDelete(String id) async {
    final db = await database;
    await db.insert(_pendingDeletes, {
      'id': id,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// مسح معرّف واحد من الطابور — يُستدعى فور تأكيد نجاح الحذف السحابي.
  Future<void> clearPendingDelete(String id) async {
    final db = await database;
    await db.delete(_pendingDeletes, where: 'id = ?', whereArgs: [id]);
  }

  /// دمج السجلات التي تحمل الباركود نفسه قبل فرض القيد الفريد.
  ///
  /// نُبقي الأحدث `updatedAt` (فهو آخر ما لمسه المستخدم) ونحذف الباقي.
  /// بدون هذا التمرير تفشل الترقية على أي قاعدة فيها تكرار قائم.
  static Future<void> _dedupeBarcodes(Database db) async {
    final dupes = await db.rawQuery('''
      SELECT barcode FROM $_table
      WHERE barcode != ''
      GROUP BY barcode HAVING COUNT(*) > 1
    ''');

    for (final row in dupes) {
      final code = row['barcode'] as String;
      final rows = await db.query(
        _table,
        columns: ['id'],
        where: 'barcode = ?',
        whereArgs: [code],
        orderBy: 'updatedAt DESC, createdAt DESC',
      );
      // نتخطى الأول (الأحدث) ونحذف ما بعده
      for (final loser in rows.skip(1)) {
        await _deleteAndRemember(db, loser['id']);
      }
    }
    if (dupes.isNotEmpty) {
      debugPrint('دُمج ${dupes.length} باركود مكرر قبل فرض القيد الفريد');
    }
  }

  static Future<void> _createMissTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_missTable (
        barcode TEXT PRIMARY KEY,
        lastTried INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<List<Medicine>> getAll() async {
    final db = await database;
    final rows = await db.query(_table, orderBy: 'createdAt DESC');
    return rows.map(Medicine.fromMap).toList();
  }

  Future<Medicine?> findByBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    final db = await database;
    final rows = await db.query(
      _table,
      where: 'barcode = ?',
      whereArgs: [code],
      limit: 1,
    );
    return rows.isEmpty ? null : Medicine.fromMap(rows.first);
  }

  /// حفظ مادة. يرمي [BarcodeConflictException] إن كان باركودها لمادة أخرى.
  ///
  /// `replace` وحده عند تعارض الفهرس الفريد **يحذف الصف الآخر** بصمت — تعديل
  /// باركود مادة إلى باركود مادة ثانية كان يمحو الثانية بكميتها وسعرها.
  Future<void> upsert(Medicine medicine) => upsertAll([medicine]);

  /// إدراج دفعة واحدة (أسطر فاتورة، دمج). كلها أو لا شيء: أي تعارض باركود
  /// مع مادة أخرى يرمي [BarcodeConflictException] ولا يُكتب شيء من الدفعة.
  Future<void> upsertAll(List<Medicine> items) async {
    if (items.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final item in items) {
        await _writeChecked(txn, item);
      }
    });
  }

  /// دمج مكرّرات في عملية واحدة: حذف [loserIds] وإدراجها في طابور الحذف
  /// السحابي وكتابة [keeper] — كلها أو لا شيء.
  ///
  /// كانت حذفاً ثم حفظاً منفصلين: فشل الحفظ (تعارض باركود) أو إغلاق التطبيق
  /// بينهما يترك المحذوفة محذوفة والباقية بلا كمياتها. الحذف أولاً داخل
  /// المعاملة يحرّر باركود الخاسرة قبل أن تحمله الباقية.
  Future<void> mergeInto({
    required Medicine keeper,
    required List<String> loserIds,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final id in loserIds) {
        await txn.delete(_table, where: 'id = ?', whereArgs: [id]);
        await txn.insert(_pendingDeletes, {
          'id': id,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await _writeChecked(txn, keeper);
    });
  }

  /// يكتب [item] بعد التأكد أن باركوده لا تملكه مادة أخرى، وإلا يرمي
  /// [BarcodeConflictException] فتتراجع المعاملة كلها.
  static Future<void> _writeChecked(Transaction txn, Medicine item) async {
    if (item.barcode.isNotEmpty) {
      final clash = await txn.query(
        _table,
        columns: ['id'],
        where: 'barcode = ? AND id != ?',
        whereArgs: [item.barcode, item.id],
        limit: 1,
      );
      if (clash.isNotEmpty) {
        throw BarcodeConflictException(
          barcode: item.barcode,
          incomingId: item.id,
          existingId: clash.first['id'].toString(),
        );
      }
    }
    await txn.insert(
      _table,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// كتابة دفعة قد تحمل باركوداً موجوداً تحت معرّف آخر (مزامنة، استرجاع نسخة).
  ///
  /// `replace` وحده يحذف الصف المتعارض بصمت. لكن الحذف هنا خطأ أيضاً: بيانات
  /// الصيدلية فيها عشرات المواد بنفس الباركود من فواتير مختلفة بكميات حقيقية،
  /// وبعضها منتجات مختلفة. لذلك **لا يُحذف شيء**: المحلي يبقى، والوارد المتعارض
  /// يُتخطّى ولا يُدرج في أي طابور. ثابت بلا تناوب لأن المحلي لا يتغيّر.
  /// يعيد معرّفات العناصر الواردة المتخطّاة.
  Future<List<String>> upsertAllSkippingBarcodeConflicts(
    List<Medicine> items,
  ) async {
    if (items.isEmpty) return const [];
    final db = await database;
    final skipped = <String>[];
    await db.transaction((txn) async {
      for (final item in items) {
        if (item.barcode.isNotEmpty) {
          final clash = await txn.query(
            _table,
            columns: ['id'],
            where: 'barcode = ? AND id != ?',
            whereArgs: [item.barcode, item.id],
            limit: 1,
          );
          if (clash.isNotEmpty) {
            skipped.add(item.id);
            continue;
          }
        }
        await txn.insert(
          _table,
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    return skipped;
  }

  /// نقل مادة إلى معرّف جديد في معاملة واحدة — القديم يُحذف قبل كتابة الجديد
  /// (الباركود نفسه، فالترتيب المعاكس يصطدم بالفهرس الفريد).
  Future<void> rekey(String oldId, Medicine fresh) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_table, where: 'id = ?', whereArgs: [oldId]);
      await _writeChecked(txn, fresh);
    });
  }

  Future<void> delete(String id) async {
    final db = await database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// البحث بأي من صيغ الباركود المكافئة (GTIN-14 / EAN-13 / UPC-12).
  Future<Medicine?> findByAnyBarcode(List<String> variants) async {
    if (variants.isEmpty) return null;
    final db = await database;
    final placeholders = List.filled(variants.length, '?').join(',');
    final rows = await db.query(
      _table,
      where: 'barcode IN ($placeholders)',
      whereArgs: variants,
      limit: 1,
    );
    return rows.isEmpty ? null : Medicine.fromMap(rows.first);
  }

  // ---------------------------------------------------------------
  //  ذاكرة الفشل — باركودات بُحث عنها فلم توجد
  // ---------------------------------------------------------------

  /// هل بحثنا عن هذا الباركود مؤخراً دون نتيجة؟
  Future<bool> isRecentMiss(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return false;
    final db = await database;
    final rows = await db.query(
      _missTable,
      columns: ['lastTried'],
      where: 'barcode = ?',
      whereArgs: [code],
      limit: 1,
    );
    if (rows.isEmpty) return false;

    final lastTried = (rows.first['lastTried'] as num?)?.toInt() ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - lastTried;
    return age < missTtl.inMilliseconds;
  }

  Future<void> recordMiss(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return;
    final db = await database;
    await db.rawInsert(
      '''
      INSERT INTO $_missTable (barcode, lastTried, attempts) VALUES (?, ?, 1)
      ON CONFLICT(barcode) DO UPDATE SET
        lastTried = excluded.lastTried,
        attempts  = attempts + 1
      ''',
      [code, DateTime.now().millisecondsSinceEpoch],
    );
  }

  /// يُستدعى فور معرفة اسم الدواء — لم يعد مجهولاً.
  Future<void> clearMiss(List<String> variants) async {
    if (variants.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(variants.length, '?').join(',');
    await db.delete(
      _missTable,
      where: 'barcode IN ($placeholders)',
      whereArgs: variants,
    );
  }

  /// إعادة تفعيل البحث لكل الباركودات المجهولة (عند التحديث اليدوي).
  Future<void> clearAllMisses() async {
    final db = await database;
    await db.delete(_missTable);
  }

  // ---------------------------------------------------------------
  //  ترحيل لمرة واحدة: إصلاح الباركودات المحفوظة كسلسلة GS1 كاملة
  // ---------------------------------------------------------------

  /// يعيد عدد السجلات التي أُصلحت.
  ///
  /// **التصادم واقعي لا نظري:** في بيانات المستخدم سجلان باسم `Aircomb`
  /// أحدهما `8697927091604` والآخر `08697927091604` — نصّان مختلفان يصيران
  /// بعد التطبيع واحداً. بلا معالجة هنا كانت الدفعة كلها تفشل بـ
  /// `UNIQUE constraint failed` فلا يُصلَح شيء، وتتكرر المحاولة كل إقلاع.
  ///
  /// القاعدة عند التصادم هي نفسها في الترقية: يبقى الأحدث ويُحذف الأقدم
  /// (مع تسجيله ليُحذف من السحابة أيضاً).
  Future<int> repairGs1Barcodes(String Function(String raw) toBarcode) async {
    final db = await database;
    final rows = await db.query(
      _table,
      columns: ['id', 'barcode', 'updatedAt', 'createdAt'],
      where: "barcode != ''",
    );

    // الباركود بعد التطبيع ⇒ السجلات التي ستحمله
    final byTarget = <String, List<Map<String, Object?>>>{};
    for (final row in rows) {
      final current = (row['barcode'] as String?) ?? '';
      final repaired = toBarcode(current);
      final target = repaired.isEmpty ? current : repaired;
      (byTarget[target] ??= []).add({...row, '_target': target});
    }

    var fixed = 0;
    final losers = <Object?>[];

    for (final group in byTarget.values) {
      if (group.length > 1) {
        // الأحدث أولاً ثم نحذف الباقي
        group.sort((a, b) {
          final byUpdated = _asInt(
            b['updatedAt'],
          ).compareTo(_asInt(a['updatedAt']));
          if (byUpdated != 0) return byUpdated;
          return _asInt(b['createdAt']).compareTo(_asInt(a['createdAt']));
        });
        losers.addAll(group.skip(1).map((r) => r['id']));
      }

      final keeper = group.first;
      if (keeper['_target'] != keeper['barcode']) fixed++;
    }

    await db.transaction((txn) async {
      for (final id in losers) {
        await txn.delete(_table, where: 'id = ?', whereArgs: [id]);
        await txn.insert(_pendingDeletes, {
          'id': id,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final group in byTarget.values) {
        final keeper = group.first;
        if (keeper['_target'] != keeper['barcode']) {
          await txn.update(
            _table,
            {'barcode': keeper['_target']},
            where: 'id = ?',
            whereArgs: [keeper['id']],
          );
        }
      }
    });

    if (losers.isNotEmpty) {
      debugPrint('حُذف ${losers.length} سجل تصادم باركوده بعد التطبيع');
    }
    return fixed;
  }

  static int _asInt(Object? v) => (v as num?)?.toInt() ?? 0;
}

/// باركود مادة محفوظة يملكه سجل آخر — الحفظ رُفض بدل حذف السجل الآخر.
class BarcodeConflictException implements Exception {
  const BarcodeConflictException({
    required this.barcode,
    required this.incomingId,
    required this.existingId,
  });

  final String barcode;
  final String incomingId;
  final String existingId;

  @override
  String toString() => 'الباركود $barcode مسجَّل لمادة أخرى';
}
