import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:saydaliyati/db/medicine_db.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/services/gs1_parser.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// اختبار الترقية على قواعد حقيقية بإصدارات قديمة، **بشيفرة التطبيق نفسها**
/// عبر `MedicineDb.openAt`.
///
/// السبب: ترقية 3←5 ستعمل على هاتف المستخدم على 192 سجلاً فعلياً، وأحدها
/// (`08056515860624`) مكرر. فشل الترقية = تعذّر فتح التطبيق أو فقدان بيانات.
void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  databaseFactory = factory;

  const table = 'medicines';
  var counter = 0;

  /// ملفات حقيقية لا قواعد في الذاكرة: اختبار الترقية يتطلب **إغلاق** القاعدة
  /// بإصدارها القديم ثم إعادة فتحها بالشيفرة الجديدة، والقاعدة في الذاكرة
  /// تُمحى عند الإغلاق.
  late Directory tempDir;

  setUpAll(() => tempDir = Directory.systemTemp.createTempSync('saydaliyati'));
  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String nextPath() => p.join(tempDir.path, 'db_${counter++}.db');

  /// يبني قاعدة بمخطط الإصدار القديم كما كان في التطبيق حينها.
  Future<Database> buildLegacy(String path, int version) async {
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(version: version),
    );
    await db.execute('''
      CREATE TABLE $table (
        id TEXT PRIMARY KEY,
        barcode TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        price REAL NOT NULL DEFAULT 0,
        quantity INTEGER NOT NULL DEFAULT 0,
        imagePath TEXT,
        ${version >= 3 ? 'expiryDate INTEGER,' : ''}
        ${version >= 4 ? "itemType TEXT NOT NULL DEFAULT 'medicine'," : ''}
        ${version >= 6 ? 'category TEXT,' : ''}
        ${version >= 7 ? 'company TEXT,' : ''}
        ${version >= 8 ? 'noBarcode INTEGER NOT NULL DEFAULT 0,' : ''}
        ${version >= 10 ? 'minQuantity INTEGER,' : ''}
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_barcode ON $table (barcode)');
    await db.execute('CREATE INDEX idx_name ON $table (name)');
    if (version >= 2) {
      await db.execute('''
        CREATE TABLE barcode_misses (
          barcode TEXT PRIMARY KEY,
          lastTried INTEGER NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 1
        )
      ''');
    }
    if (version >= 5) {
      await db.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_barcode_unique "
        "ON $table (barcode) WHERE barcode != ''",
      );
      await db.execute('CREATE TABLE pending_deletes (id TEXT PRIMARY KEY)');
    }
    return db;
  }

  Future<void> insertLegacy(
    Database db,
    int version, {
    required String id,
    required String barcode,
    required String name,
    double price = 0,
    int quantity = 0,
    int? expiryDate,
    String? itemType,
    int updatedAt = 0,
  }) => db.insert(table, {
    'id': id,
    'barcode': barcode,
    'name': name,
    'price': price,
    'quantity': quantity,
    'createdAt': updatedAt,
    'updatedAt': updatedAt,
    if (version >= 3) 'expiryDate': expiryDate,
    if (version >= 4) 'itemType': itemType ?? 'medicine',
  });

  Future<Set<String>> indexNames(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='$table'",
    );
    return rows.map((r) => r['name'].toString()).toSet();
  }

  group('ترقية 3 ← 5 (حالة هاتف المستخدم)', () {
    test('تنجح وتحفظ كل السجلات وتضيف النوع الافتراضي', () async {
      final path = nextPath();
      var db = await buildLegacy(path, 3);
      for (var i = 0; i < 20; i++) {
        await insertLegacy(
          db,
          3,
          id: 'med_$i',
          barcode: '111111111111$i',
          name: 'دواء $i',
          price: (1500 + i).toDouble(),
          quantity: i,
          expiryDate: 1900000000000,
          updatedAt: i,
        );
      }
      await db.close();

      db = await MedicineDb.openAt(path);

      expect(await db.getVersion(), MedicineDb.schemaVersion);
      final rows = await db.query(table);
      expect(rows.length, 20, reason: 'لا يجوز فقدان أي سجل');
      // كل القديم يصبح دواءً — القرار الصريح للمستخدم
      expect(rows.every((r) => r['itemType'] == 'medicine'), isTrue);
      // الحقول القديمة سليمة
      expect(rows.first['expiryDate'], 1900000000000);
      expect(rows.any((r) => r['price'] == 1500.0), isTrue);
      await db.close();
    });

    test('تدمج الباركود المكرر وتُبقي الأحدث', () async {
      final path = nextPath();
      var db = await buildLegacy(path, 3);
      // نفس التكرار المرصود في بيانات المستخدم الحقيقية
      await insertLegacy(
        db,
        3,
        id: 'a',
        barcode: '08056515860624',
        name: 'DIBASE drop',
        updatedAt: 100,
      );
      await insertLegacy(
        db,
        3,
        id: 'b',
        barcode: '08056515860624',
        name: 'DIBASE10000iu drop',
        updatedAt: 900,
      );
      await insertLegacy(
        db,
        3,
        id: 'c',
        barcode: '999',
        name: 'دواء سليم',
        updatedAt: 50,
      );
      await db.close();

      db = await MedicineDb.openAt(path);

      final rows = await db.query(table, orderBy: 'id');
      expect(rows.length, 2, reason: 'المكرر يُدمج لا يُضاعف');
      final kept = rows.firstWhere((r) => r['barcode'] == '08056515860624');
      expect(kept['name'], 'DIBASE10000iu drop', reason: 'الأحدث يفوز');
      expect(rows.any((r) => r['name'] == 'دواء سليم'), isTrue);

      // المدموج مسجَّل ليُحذف من السحابة أيضاً
      final pending = await db.query('pending_deletes');
      expect(pending.map((r) => r['id']), contains('a'));
      await db.close();
    });

    test('تضيف كل الفهارس المطلوبة', () async {
      final path = nextPath();
      var db = await buildLegacy(path, 3);
      await db.close();

      db = await MedicineDb.openAt(path);
      final names = await indexNames(db);

      expect(names, contains('idx_barcode_unique'));
      expect(names, contains('idx_type'));
      expect(names, contains('idx_barcode'));
      expect(names, contains('idx_name'));
      await db.close();
    });
  });

  group('ترقية 4 ← 5', () {
    test('تحافظ على النوع المسجَّل ولا تعيده إلى الافتراضي', () async {
      final path = nextPath();
      var db = await buildLegacy(path, 4);
      await insertLegacy(
        db,
        4,
        id: 's1',
        barcode: '',
        name: 'شاش طبي',
        itemType: 'supply',
      );
      await insertLegacy(
        db,
        4,
        id: 'm1',
        barcode: '123',
        name: 'دواء',
        itemType: 'medicine',
      );
      await db.close();

      db = await MedicineDb.openAt(path);
      final rows = await db.query(table, orderBy: 'id');
      expect(
        rows.firstWhere((r) => r['id'] == 's1')['itemType'],
        'supply',
        reason: 'المستلزمات المحفوظة لا تتحول إلى أدوية',
      );
      await db.close();
    });

    test('عدة مواد بلا باركود لا تتصادم', () async {
      final path = nextPath();
      var db = await buildLegacy(path, 4);
      // 46 مادة من الفواتير كلها بلا باركود — القيد الجزئي يجب أن يستثنيها
      for (var i = 0; i < 46; i++) {
        await insertLegacy(
          db,
          4,
          id: 'sup_$i',
          barcode: '',
          name: 'مستلزم $i',
          itemType: 'supply',
        );
      }
      await db.close();

      db = await MedicineDb.openAt(path);
      expect((await db.query(table)).length, 46);
      await db.close();
    });
  });

  group('ترقية 9 ← 10 — حد التنبيه الخاص بالمادة', () {
    test('تضيف عمود minQuantity بلا فقدان بيانات، والقديم null', () async {
      final path = nextPath();
      var db = await buildLegacy(path, 9);
      await insertLegacy(
        db,
        9,
        id: 'm1',
        barcode: '123',
        name: 'دواء قديم',
        itemType: 'medicine',
        updatedAt: 1,
      );
      await db.close();

      db = await MedicineDb.openAt(path);
      expect(await db.getVersion(), MedicineDb.schemaVersion);
      final rows = await db.query(table);
      expect(rows.single['name'], 'دواء قديم');
      expect(rows.single.containsKey('minQuantity'), isTrue);
      expect(rows.single['minQuantity'], isNull);
      await db.close();
    });
  });

  group('ترقية 10 ← 11 — العدد في الكرتون', () {
    test('تضيف packSize وpackPriced بلا فقدان بيانات، والقديم null', () async {
      final path = nextPath();
      var db = await buildLegacy(path, 10);
      await insertLegacy(
        db,
        10,
        id: 'm1',
        barcode: '123',
        name: 'دواء قديم',
        quantity: 36,
        itemType: 'medicine',
        updatedAt: 1,
      );
      await db.close();

      db = await MedicineDb.openAt(path);
      expect(await db.getVersion(), MedicineDb.schemaVersion);
      final rows = await db.query(table);
      expect(rows.single['quantity'], 36);
      expect(rows.single.containsKey('packSize'), isTrue);
      expect(rows.single['packSize'], isNull);
      expect(rows.single.containsKey('packPriced'), isTrue);
      expect(rows.single['packPriced'], isNull);
      await db.close();
    });
  });

  group('ترقية 5 ← 6 — إضافة نوع المادة', () {
    test('تضيف عمود category بلا فقدان بيانات', () async {
      final path = nextPath();
      var db = await buildLegacy(path, 5);
      await insertLegacy(
        db,
        5,
        id: 'm1',
        barcode: '123',
        name: 'دواء قديم',
        itemType: 'medicine',
        updatedAt: 1,
      );
      await insertLegacy(
        db,
        5,
        id: 's1',
        barcode: '',
        name: 'مستلزم قديم',
        itemType: 'supply',
        updatedAt: 2,
      );
      await db.close();

      db = await MedicineDb.openAt(path);
      expect(await db.getVersion(), MedicineDb.schemaVersion);

      final rows = await db.query(table, orderBy: 'id');
      expect(rows.length, 2, reason: 'لا فقدان لأي سجل قديم');
      // السجلات القديمة كانت قبل وجود العمود أصلاً — تبقى null لا فارغة
      expect(rows.every((r) => r['category'] == null), isTrue);
      expect(rows.firstWhere((r) => r['id'] == 'm1')['name'], 'دواء قديم');
      await db.close();
    });

    test('إدراج جديد بحقل category يُقرأ صحيحاً بعد الترقية', () async {
      final path = nextPath();
      var db = await buildLegacy(path, 5);
      await db.close();

      db = await MedicineDb.openAt(path);
      await db.insert(table, {
        'id': 'x',
        'barcode': '',
        'name': 'كريم مضاد حيوي',
        'price': 420,
        'quantity': 10,
        'itemType': 'supply',
        'category': 'Cream',
        'createdAt': 0,
        'updatedAt': 0,
      });

      final row = (await db.query(table)).single;
      expect(row['category'], 'Cream');
      await db.close();
    });
  });

  group('ترقية 2 ← 5 (أقدم نسخة)', () {
    test('تمرّ عبر كل الخطوات وتضيف عمودَي الصلاحية والنوع', () async {
      final path = nextPath();
      var db = await buildLegacy(path, 2);
      await insertLegacy(db, 2, id: 'x', barcode: '55', name: 'قديم جداً');
      await db.close();

      db = await MedicineDb.openAt(path);
      final rows = await db.query(table);
      expect(rows.length, 1);
      expect(rows.first.containsKey('expiryDate'), isTrue);
      expect(rows.first['itemType'], 'medicine');
      expect(rows.first['expiryDate'], isNull);
      await db.close();
    });
  });

  group('قاعدة جديدة (onCreate)', () {
    late Database db;

    setUp(() async {
      db = await MedicineDb.openAt(nextPath());
      MedicineDb.instance.attachForTest(db);
    });

    tearDown(() async {
      MedicineDb.instance.attachForTest(null);
      await db.close();
    });

    test('المخطط كامل من أول فتح', () async {
      expect(await db.getVersion(), MedicineDb.schemaVersion);
      final names = await indexNames(db);
      expect(names, contains('idx_barcode_unique'));
      expect(names, contains('idx_type'));

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      expect(
        tables.map((t) => t['name']).toList(),
        containsAll(['medicines', 'barcode_misses']),
      );
    });

    test('upsert ثم getAll يعيدان المادة كاملة', () async {
      const m = Medicine(
        id: 'm1',
        barcode: '6291100000012',
        name: 'Panadol',
        price: 2500.5,
        quantity: 7,
        imagePath: 'img.jpg',
        expiryDate: 1900000000000,
        type: ItemType.medicine,
        minQuantity: 12,
        packSize: 10,
        packPriced: false,
        createdAt: 10,
        updatedAt: 10,
      );
      await MedicineDb.instance.upsert(m);

      final all = await MedicineDb.instance.getAll();
      expect(all.length, 1);
      final got = all.first;
      expect(got.name, 'Panadol');
      expect(got.price, 2500.5);
      expect(got.quantity, 7);
      expect(got.imagePath, 'img.jpg');
      expect(got.minQuantity, 12, reason: 'حد التنبيه الخاص يُحفظ ويُقرأ');
      expect(got.packSize, 10, reason: 'العدد في الكرتون يُحفظ ويُقرأ');
      expect(got.packPriced, isFalse);
      expect(got.type, ItemType.medicine);
      expect(got.expiryDate, 1900000000000);
    });

    test('category يمرّ كاملاً عبر upsert و getAll لمستلزم', () async {
      const m = Medicine(
        id: 's1',
        barcode: '',
        name: 'كريم مضاد حيوي',
        price: 420,
        quantity: 10,
        type: ItemType.supply,
        category: 'Cream',
        createdAt: 0,
        updatedAt: 0,
      );
      await MedicineDb.instance.upsert(m);

      final got = (await MedicineDb.instance.getAll()).single;
      expect(got.category, 'Cream');
    });

    test('دواء بلا category يُقرأ null لا نصاً فارغاً', () async {
      const m = Medicine(
        id: 'm2',
        barcode: '999',
        name: 'دواء',
        price: 100,
        quantity: 1,
        type: ItemType.medicine,
        createdAt: 0,
        updatedAt: 0,
      );
      await MedicineDb.instance.upsert(m);

      final got = (await MedicineDb.instance.getAll()).single;
      expect(got.category, isNull);
    });

    test('upsertAll يدرج دفعة واحدة ويحفظ النوع', () async {
      final items = [
        for (var i = 0; i < 46; i++)
          Medicine(
            id: 'inv_$i',
            barcode: '',
            name: 'مادة فاتورة $i',
            price: (1000 + i).toDouble(),
            quantity: 2,
            type: i.isEven ? ItemType.supply : ItemType.medicine,
            createdAt: i,
            updatedAt: i,
          ),
      ];
      await MedicineDb.instance.upsertAll(items);

      final all = await MedicineDb.instance.getAll();
      expect(all.length, 46);
      expect(all.where((m) => m.type == ItemType.supply).length, 23);
      expect(all.where((m) => m.type == ItemType.medicine).length, 23);
    });

    test('upsertAll بقائمة فارغة لا يفعل شيئاً ولا يرمي', () async {
      await MedicineDb.instance.upsertAll([]);
      expect(await MedicineDb.instance.getAll(), isEmpty);
    });

    test('getAll يرتّب بالأحدث أولاً', () async {
      await MedicineDb.instance.upsertAll([
        Medicine(
          id: 'old',
          barcode: '',
          name: 'قديم',
          price: 1,
          quantity: 1,
          createdAt: 1,
          updatedAt: 1,
        ),
        Medicine(
          id: 'new',
          barcode: '',
          name: 'جديد',
          price: 1,
          quantity: 1,
          createdAt: 99,
          updatedAt: 99,
        ),
      ]);
      final all = await MedicineDb.instance.getAll();
      expect(all.first.id, 'new');
    });

    test('حفظ مادة جديدة بباركود موجود يُرفض ولا يضاعف ولا يحذف', () async {
      await MedicineDb.instance.upsert(
        const Medicine(
          id: 'a',
          barcode: '777',
          name: 'أول',
          price: 1,
          quantity: 1,
          createdAt: 0,
          updatedAt: 0,
        ),
      );
      final attempt = MedicineDb.instance.upsert(
        const Medicine(
          id: 'b',
          barcode: '777',
          name: 'ثانٍ بنفس الباركود',
          price: 2,
          quantity: 2,
          createdAt: 5,
          updatedAt: 5,
        ),
      );

      // خط الدفاع الأخير: لا سجلان بباركود واحد، ولا حذف صامت للأول.
      await expectLater(attempt, throwsA(isA<BarcodeConflictException>()));
      final all = await MedicineDb.instance.getAll();
      expect(all.length, 1);
      expect(all.first.name, 'أول');
    });

    test('تعديل نفس السجل بنفس الباركود مسموح', () async {
      const before = Medicine(
        id: 'a',
        barcode: '777',
        name: 'قبل',
        price: 1,
        quantity: 1,
        createdAt: 0,
        updatedAt: 0,
      );
      await MedicineDb.instance.upsert(before);
      await MedicineDb.instance.upsert(
        before.copyWith(name: 'بعد', quantity: 9),
      );

      final all = await MedicineDb.instance.getAll();
      expect(all.length, 1);
      expect(all.first.name, 'بعد');
      expect(all.first.quantity, 9);
    });

    test('البحث بصيغ الباركود المكافئة', () async {
      // GTIN-14 مخزّن، والمسح يعطي EAN-13 — يجب أن يُعثر عليه
      await MedicineDb.instance.upsert(
        const Medicine(
          id: 'a',
          barcode: '06291100000012',
          name: 'دواء',
          price: 1,
          quantity: 1,
          createdAt: 0,
          updatedAt: 0,
        ),
      );

      final found = await MedicineDb.instance.findByAnyBarcode(
        Gs1Parser.lookupVariants('6291100000012'),
      );
      expect(found, isNotNull);
      expect(found!.name, 'دواء');

      final missing = await MedicineDb.instance.findByAnyBarcode(
        Gs1Parser.lookupVariants('1234567890128'),
      );
      expect(missing, isNull);
    });

    test('الحذف يزيل السجل', () async {
      await MedicineDb.instance.upsert(
        const Medicine(
          id: 'a',
          barcode: '1',
          name: 'دواء',
          price: 1,
          quantity: 1,
          createdAt: 0,
          updatedAt: 0,
        ),
      );
      await MedicineDb.instance.delete('a');
      expect(await MedicineDb.instance.getAll(), isEmpty);
    });
  });

  group('ذاكرة الباركودات المجهولة', () {
    late Database db;

    setUp(() async {
      db = await MedicineDb.openAt(nextPath());
      MedicineDb.instance.attachForTest(db);
    });

    tearDown(() async {
      MedicineDb.instance.attachForTest(null);
      await db.close();
    });

    test('تسجيل الفشل ثم اعتباره حديثاً', () async {
      expect(await MedicineDb.instance.isRecentMiss('123'), isFalse);
      await MedicineDb.instance.recordMiss('123');
      expect(await MedicineDb.instance.isRecentMiss('123'), isTrue);
    });

    test('الفشل القديم يُنسى بعد انقضاء المهلة', () async {
      await MedicineDb.instance.recordMiss('123');
      // نُقدّم الزمن يدوياً إلى ما قبل المهلة بيوم
      final old =
          DateTime.now().millisecondsSinceEpoch -
          MedicineDb.missTtl.inMilliseconds -
          const Duration(days: 1).inMilliseconds;
      await db.update(
        'barcode_misses',
        {'lastTried': old},
        where: 'barcode = ?',
        whereArgs: ['123'],
      );
      expect(await MedicineDb.instance.isRecentMiss('123'), isFalse);
    });

    test('تكرار التسجيل يزيد العدّاد ولا يُنشئ صفاً ثانياً', () async {
      await MedicineDb.instance.recordMiss('123');
      await MedicineDb.instance.recordMiss('123');
      await MedicineDb.instance.recordMiss('123');

      final rows = await db.query('barcode_misses');
      expect(rows.length, 1);
      expect(rows.first['attempts'], 3);
    });

    test('clearMiss يرفع العلامة عن كل الصيغ المكافئة', () async {
      await MedicineDb.instance.recordMiss('6291100000012');
      await MedicineDb.instance.clearMiss(
        Gs1Parser.lookupVariants('6291100000012'),
      );
      expect(await MedicineDb.instance.isRecentMiss('6291100000012'), isFalse);
    });

    test('clearAllMisses يفرغ الجدول', () async {
      await MedicineDb.instance.recordMiss('1');
      await MedicineDb.instance.recordMiss('2');
      await MedicineDb.instance.clearAllMisses();
      expect((await db.query('barcode_misses')), isEmpty);
    });

    test('الباركود الفارغ يُتجاهل', () async {
      await MedicineDb.instance.recordMiss('  ');
      expect((await db.query('barcode_misses')), isEmpty);
      expect(await MedicineDb.instance.isRecentMiss(''), isFalse);
    });
  });

  group('ترحيل باركودات GS1', () {
    late Database db;

    setUp(() async {
      db = await MedicineDb.openAt(nextPath());
      MedicineDb.instance.attachForTest(db);
    });

    tearDown(() async {
      MedicineDb.instance.attachForTest(null);
      await db.close();
    });

    test('السلسلة الكاملة تُختصر إلى GTIN والسليم لا يُمَس', () async {
      await MedicineDb.instance.upsertAll([
        // سلسلة GS1 كاملة كما كانت تُحفظ قبل المفكّك
        const Medicine(
          id: 'a',
          barcode: '010629110000001217250731100ABC',
          name: 'دواء GS1',
          price: 1,
          quantity: 1,
          createdAt: 0,
          updatedAt: 0,
        ),
        // مادة أخرى بباركود GTIN-14 مطبَّع أصلاً — لا علاقة له بالأولى
        const Medicine(
          id: 'b',
          barcode: '05901234123457',
          name: 'دواء عادي',
          price: 1,
          quantity: 1,
          createdAt: 0,
          updatedAt: 0,
        ),
      ]);

      final fixed = await MedicineDb.instance.repairGs1Barcodes(
        (raw) => Gs1Parser.parse(raw).barcode,
      );

      expect(fixed, 1, reason: 'سجل واحد فقط يحتاج إصلاحاً');
      final all = await MedicineDb.instance.getAll();
      expect(all.length, 2, reason: 'لا دمج بين باركودين مختلفين');
      final gs1 = all.firstWhere((m) => m.id == 'a');
      expect(gs1.barcode, '06291100000012', reason: 'السلسلة اختُصرت إلى GTIN');
      final plain = all.firstWhere((m) => m.id == 'b');
      expect(
        plain.barcode,
        '05901234123457',
        reason: 'المطبَّع أصلاً لا يتغيّر',
      );
    });

    test('الباركود المطبَّع مسبقاً لا يُمَس', () async {
      await MedicineDb.instance.upsert(
        const Medicine(
          id: 'a',
          barcode: '06291100000012', // GTIN-14 بالفعل
          name: 'دواء',
          price: 1,
          quantity: 1,
          createdAt: 0,
          updatedAt: 0,
        ),
      );
      expect(
        await MedicineDb.instance.repairGs1Barcodes(
          (raw) => Gs1Parser.parse(raw).barcode,
        ),
        0,
      );
      final all = await MedicineDb.instance.getAll();
      expect(all.first.barcode, '06291100000012');
    });

    test('تصادم التطبيع لا يُسقط الإصلاح — حالة Aircomb الحقيقية', () async {
      // هذان السجلان موجودان فعلاً في بيانات المستخدم بنصّين مختلفين
      // يصيران بعد التطبيع باركوداً واحداً
      await MedicineDb.instance.upsertAll([
        const Medicine(
          id: 'old',
          barcode: '8697927091604',
          name: 'Aircomb',
          price: 1,
          quantity: 1,
          createdAt: 10,
          updatedAt: 10,
        ),
        const Medicine(
          id: 'new',
          barcode: '08697927091604',
          name: 'Aircomb 5/10 tab',
          price: 2,
          quantity: 2,
          createdAt: 99,
          updatedAt: 99,
        ),
      ]);

      // قبل الإصلاح كان هذا يرمي UNIQUE constraint failed ويُفشل كل شيء
      await MedicineDb.instance.repairGs1Barcodes(
        (raw) => Gs1Parser.parse(raw).barcode,
      );

      final all = await MedicineDb.instance.getAll();
      expect(all.length, 1, reason: 'المتصادمان يُدمجان لا يتعايشان');
      expect(all.first.id, 'new', reason: 'الأحدث يبقى');
      expect(all.first.barcode, '08697927091604');
    });

    test('المدموج يُسجَّل ليُحذف من السحابة', () async {
      await MedicineDb.instance.upsertAll([
        const Medicine(
          id: 'old',
          barcode: '8697927091604',
          name: 'Aircomb',
          price: 1,
          quantity: 1,
          createdAt: 10,
          updatedAt: 10,
        ),
        const Medicine(
          id: 'new',
          barcode: '08697927091604',
          name: 'Aircomb 5/10 tab',
          price: 2,
          quantity: 2,
          createdAt: 99,
          updatedAt: 99,
        ),
      ]);
      await MedicineDb.instance.repairGs1Barcodes(
        (raw) => Gs1Parser.parse(raw).barcode,
      );

      // بلا هذا التسجيل يعود المحذوف من السحابة في كل مزامنة
      final pending = await MedicineDb.instance.takePendingDeletes();
      expect(pending, contains('old'));

      // القراءة تمسح القائمة فلا تتكرر عمليات الحذف
      expect(await MedicineDb.instance.takePendingDeletes(), isEmpty);
    });
  });

  group('ترقية 6 ← 7 — اسم الشركة', () {
    test('تضيف عمود company وتحفظ category القديم', () async {
      final path = nextPath();
      var db = await buildLegacy(path, 6);
      await db.insert(table, {
        'id': 's1',
        'barcode': '',
        'name': 'كريم',
        'price': 0,
        'quantity': 1,
        'itemType': 'supply',
        'category': 'Cream',
        'createdAt': 0,
        'updatedAt': 0,
      });
      await db.close();

      db = await MedicineDb.openAt(path);
      expect(await db.getVersion(), MedicineDb.schemaVersion);
      final row = (await db.query(table)).single;
      expect(row['category'], 'Cream');
      expect(row['company'], isNull);
      await db.update(table, {'company': 'Juman'});
      expect((await db.query(table)).single['company'], 'Juman');
      await db.close();
    });
  });

  group('ترقية 7 ← 8 — «ليس لها باركود»', () {
    test('تضيف عمود noBarcode بقيمة 0 بلا فقدان بيانات', () async {
      final path = nextPath();
      var db = await buildLegacy(path, 7);
      await db.insert(table, {
        'id': 'm1',
        'barcode': '',
        'name': 'تحضير',
        'price': 100,
        'quantity': 2,
        'itemType': 'medicine',
        'company': 'Juman',
        'createdAt': 0,
        'updatedAt': 0,
      });
      await db.close();

      db = await MedicineDb.openAt(path);
      expect(await db.getVersion(), MedicineDb.schemaVersion);
      final row = (await db.query(table)).single;
      expect(row['noBarcode'], 0);
      expect(row['company'], 'Juman');
      await db.update(table, {'noBarcode': 1});
      expect((await db.query(table)).single['noBarcode'], 1);
      await db.close();
    });
  });

  group('ترقية 8 ← 9 — سجل الفواتير', () {
    test('ينشئ جدول الفواتير بلا فقدان للمواد', () async {
      final path = nextPath();
      var db = await buildLegacy(path, 8);
      await db.insert(table, {
        'id': 'm1',
        'barcode': '',
        'name': 'دواء',
        'price': 100,
        'quantity': 2,
        'itemType': 'medicine',
        'noBarcode': 1,
        'createdAt': 0,
        'updatedAt': 0,
      });
      await db.close();

      db = await MedicineDb.openAt(path);
      expect(await db.getVersion(), MedicineDb.schemaVersion);
      expect((await db.query(table)).single['noBarcode'], 1);
      await db.insert('invoices', {
        'id': 'i1',
        'supplier': 'مذخر',
        'lines': '[{"name":"A","quantity":1,"price":5}]',
        'imageFiles': '["p.jpg"]',
        'createdAt': 1,
        'updatedAt': 1,
      });
      final row = (await db.query('invoices')).single;
      expect(row['supplier'], 'مذخر');
      await db.close();
    });
  });
}
