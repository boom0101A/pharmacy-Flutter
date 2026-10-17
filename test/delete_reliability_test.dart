import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:saydaliyati/db/medicine_db.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// موثوقية طابور الحذف: peek/clear/enqueue تعمل كما هو متوقَّع، فلا يفقد
/// معرّف فاشل بلا رجعة كما كان يحصل مع takePendingDeletes.
///
/// نُشغّل قاعدة SQLite حقيقية عبر sqflite_common_ffi على ملف مؤقت — أدق من
/// محاكاة يدوية لسلوك الجدول.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  var counter = 0;
  Database? currentDb;

  setUpAll(() => tempDir = Directory.systemTemp.createTempSync('delete_rel'));

  // إغلاق القاعدة قبل حذف المجلد — بلا هذا يفشل الحذف على ويندوز لأن SQLite
  // تُبقي مقبض الملف مفتوحاً حتى يُغلَق صراحةً.
  tearDownAll(() async {
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {
      // مجرد تنظيف مؤقّت — لا يُبطل الاختبارات
    }
  });

  setUp(() async {
    final path = p.join(tempDir.path, 'db_${counter++}.db');
    currentDb = await MedicineDb.openAt(path);
    MedicineDb.instance.attachForTest(currentDb);
  });

  tearDown(() async {
    MedicineDb.instance.attachForTest(null);
    await currentDb?.close();
    currentDb = null;
  });

  Medicine sampleMed(String id) => Medicine(
    id: id,
    barcode: '',
    name: 'مادة $id',
    price: 10,
    quantity: 5,
    createdAt: 0,
    updatedAt: 0,
  );

  group('enqueue/peek/clear pending deletes', () {
    test('enqueue ثم peek يعيد المعرّف نفسه', () async {
      await MedicineDb.instance.enqueuePendingDelete('m1');
      final ids = await MedicineDb.instance.peekPendingDeletes();
      expect(ids, contains('m1'));
    });

    test('peek لا يمسح المعرّفات — استدعاء ثانٍ يعيدها كما هي', () async {
      await MedicineDb.instance.enqueuePendingDelete('m1');
      await MedicineDb.instance.enqueuePendingDelete('m2');
      final first = await MedicineDb.instance.peekPendingDeletes();
      final second = await MedicineDb.instance.peekPendingDeletes();
      expect(first.toSet(), {'m1', 'm2'});
      expect(second.toSet(), {'m1', 'm2'});
    });

    test('clearPendingDelete يمسح معرّفاً واحداً فقط، الباقي محفوظ', () async {
      await MedicineDb.instance.enqueuePendingDelete('m1');
      await MedicineDb.instance.enqueuePendingDelete('m2');
      await MedicineDb.instance.enqueuePendingDelete('m3');

      await MedicineDb.instance.clearPendingDelete('m2');
      final remaining = await MedicineDb.instance.peekPendingDeletes();
      expect(remaining.toSet(), {'m1', 'm3'});
    });

    test('enqueue لمعرّف موجود لا يرمي (idempotent)', () async {
      await MedicineDb.instance.enqueuePendingDelete('m1');
      await MedicineDb.instance.enqueuePendingDelete('m1');
      final ids = await MedicineDb.instance.peekPendingDeletes();
      expect(ids.where((i) => i == 'm1').length, 1);
    });
  });

  group('السلوك القديم takePendingDeletes يبقى للتوافق', () {
    test('take يعيد ويمسح مرة واحدة', () async {
      await MedicineDb.instance.enqueuePendingDelete('m1');
      final first = await MedicineDb.instance.takePendingDeletes();
      final second = await MedicineDb.instance.takePendingDeletes();
      expect(first, ['m1']);
      expect(second, isEmpty);
    });
  });

  group('حذف محلي مع طابور', () {
    test('delete على المادة لا يلمس طابور الحذف مباشرة', () async {
      // MedicineDb.delete نفسها لا تُدرج في الطابور — الإدراج يتم من
      // MedicineStore.delete. هنا نتحقق أن الجدولين مستقلان.
      await MedicineDb.instance.upsert(sampleMed('m1'));
      await MedicineDb.instance.delete('m1');
      final ids = await MedicineDb.instance.peekPendingDeletes();
      expect(ids, isEmpty);
    });
  });
}
