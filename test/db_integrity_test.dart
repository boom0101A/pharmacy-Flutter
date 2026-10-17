import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// اختبارات ترقية القاعدة وقيد الباركود الفريد.
///
/// تعمل على قاعدة في الذاكرة بنفس عبارات SQL المستعملة في التطبيق، فتتحقق من
/// سلوك SQLite نفسه لا من محاكاة له.
void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  const table = 'medicines';
  const uniqueIndex =
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_barcode_unique "
      "ON $table (barcode) WHERE barcode != ''";

  Future<Database> makeV4() async {
    final db = await factory.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE $table (
        id TEXT PRIMARY KEY,
        barcode TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        price REAL NOT NULL DEFAULT 0,
        quantity INTEGER NOT NULL DEFAULT 0,
        imagePath TEXT,
        expiryDate INTEGER,
        itemType TEXT NOT NULL DEFAULT 'medicine',
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');
    return db;
  }

  Future<void> insert(
    Database db, {
    required String id,
    required String barcode,
    required String name,
    int updatedAt = 0,
    String type = 'medicine',
  }) => db.insert(table, {
    'id': id,
    'barcode': barcode,
    'name': name,
    'price': 0,
    'quantity': 0,
    'itemType': type,
    'createdAt': 0,
    'updatedAt': updatedAt,
  });

  /// نسخة الاختبار من منطق الدمج في MedicineDb._dedupeBarcodes
  Future<int> dedupe(Database db) async {
    final dupes = await db.rawQuery('''
      SELECT barcode FROM $table
      WHERE barcode != ''
      GROUP BY barcode HAVING COUNT(*) > 1
    ''');
    for (final row in dupes) {
      final rows = await db.query(
        table,
        columns: ['id'],
        where: 'barcode = ?',
        whereArgs: [row['barcode']],
        orderBy: 'updatedAt DESC, createdAt DESC',
      );
      for (final loser in rows.skip(1)) {
        await db.delete(table, where: 'id = ?', whereArgs: [loser['id']]);
      }
    }
    return dupes.length;
  }

  group('قيد الباركود الفريد', () {
    test('الدمج يُبقي الأحدث ويحذف الأقدم', () async {
      final db = await makeV4();
      // الحالة المرصودة فعلياً في بيانات المستخدم
      await insert(
        db,
        id: 'a',
        barcode: '08056515860624',
        name: 'DIBASE drop',
        updatedAt: 100,
      );
      await insert(
        db,
        id: 'b',
        barcode: '08056515860624',
        name: 'DIBASE10000iu drop',
        updatedAt: 900,
      );

      expect(await dedupe(db), 1);
      final rows = await db.query(table);
      expect(rows.length, 1);
      expect(rows.first['name'], 'DIBASE10000iu drop');
      await db.close();
    });

    test('الترقية تنجح بعد الدمج ولا تنجح قبله', () async {
      final db = await makeV4();
      await insert(db, id: 'a', barcode: '123', name: 'س', updatedAt: 1);
      await insert(db, id: 'b', barcode: '123', name: 'ص', updatedAt: 2);

      await expectLater(db.execute(uniqueIndex), throwsA(isA<Exception>()));
      await dedupe(db);
      await db.execute(uniqueIndex); // لا يرمي الآن
      await db.close();
    });

    test('المواد بلا باركود لا تتصادم مع بعضها', () async {
      final db = await makeV4();
      await db.execute(uniqueIndex);
      // كل مواد الفواتير بلا باركود — لو كان القيد شاملاً لفشل الثاني
      await insert(db, id: 'a', barcode: '', name: 'شاش', type: 'supply');
      await insert(db, id: 'b', barcode: '', name: 'قفازات', type: 'supply');
      await insert(db, id: 'c', barcode: '', name: 'كمام', type: 'supply');
      expect((await db.query(table)).length, 3);
      await db.close();
    });

    test('إدراج باركود موجود يُرفض بعد فرض القيد', () async {
      final db = await makeV4();
      await db.execute(uniqueIndex);
      await insert(db, id: 'a', barcode: '999', name: 'دواء');
      await expectLater(
        insert(db, id: 'b', barcode: '999', name: 'نسخة مكررة'),
        throwsA(isA<Exception>()),
      );
      await db.close();
    });

    test('الاستبدال بنفس المعرّف يبقى ممكناً (تعديل عادي)', () async {
      final db = await makeV4();
      await db.execute(uniqueIndex);
      await insert(db, id: 'a', barcode: '777', name: 'قبل');
      await db.insert(table, {
        'id': 'a',
        'barcode': '777',
        'name': 'بعد',
        'price': 5,
        'quantity': 3,
        'itemType': 'medicine',
        'createdAt': 0,
        'updatedAt': 5,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final rows = await db.query(table);
      expect(rows.length, 1);
      expect(rows.first['name'], 'بعد');
      await db.close();
    });
  });

  group('تقسيم الدفعة', () {
    /// نفس حساب الشرائح في SyncService._commitInChunks
    List<int> chunkSizes(int total, int limit) {
      final sizes = <int>[];
      for (var i = 0; i < total; i += limit) {
        sizes.add((i + limit).clamp(0, total) - i);
      }
      return sizes;
    }

    test('لا شريحة تتجاوز حد Firestore', () {
      for (final total in [0, 1, 449, 450, 451, 900, 1201]) {
        final sizes = chunkSizes(total, 450);
        expect(sizes.fold(0, (a, b) => a + b), total, reason: 'المجموع $total');
        for (final s in sizes) {
          expect(s, lessThanOrEqualTo(450));
          expect(s, greaterThan(0));
        }
      }
    });

    test('192 سجلاً تمرّ في دفعة واحدة و901 في ثلاث', () {
      expect(chunkSizes(192, 450).length, 1);
      expect(chunkSizes(901, 450), [450, 450, 1]);
    });
  });

  group('حمولة الرفع', () {
    test('لا تحمل مسار الصورة وتحمل المالك', () {
      const m = Medicine(
        id: 'x',
        barcode: '123',
        name: 'دواء',
        price: 10,
        quantity: 2,
        imagePath: 'local.jpg',
        createdAt: 1,
        updatedAt: 2,
      );
      // نفس بناء SyncService._payload
      final payload = Map<String, Object?>.from(m.toMap())
        ..remove('imagePath')
        ..['ownerUid'] = 'uid-123';

      expect(payload.containsKey('imagePath'), isFalse);
      expect(payload['ownerUid'], 'uid-123');
      expect(payload['price'], 10);
      expect(payload['itemType'], 'medicine');
    });
  });
}
