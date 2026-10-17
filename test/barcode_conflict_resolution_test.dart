import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:saydaliyati/db/medicine_db.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// جهازا الصيدلية يضيفان نفس الباركود بمعرّفين مختلفين قبل المزامنة. بلا حلّ
/// صريح كان `INSERT OR REPLACE` يحذف أحدهما بصمت، والسحابة تبقى تحمل
/// الاثنين، فيتناوب السجلان مع كل مزامنة.
class _TestStore extends MedicineStore {
  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}
}

Medicine med({
  required String id,
  String barcode = '',
  int qty = 1,
  int updatedAt = 1,
}) => Medicine(
  id: id,
  barcode: barcode,
  name: 'x',
  price: 0,
  quantity: qty,
  createdAt: updatedAt,
  updatedAt: updatedAt,
);

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  var counter = 0;
  Database? db;

  setUpAll(() => tempDir = Directory.systemTemp.createTempSync('bc_resolve'));
  tearDownAll(() {
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });
  setUp(() async {
    db = await MedicineDb.openAt(p.join(tempDir.path, 'db_${counter++}.db'));
    MedicineDb.instance.attachForTest(db);
  });
  tearDown(() async {
    MedicineDb.instance.attachForTest(null);
    await db?.close();
    db = null;
  });

  final dbi = MedicineDb.instance;

  // القرار: تعارض الباركود لا يحذف شيئاً أبداً. بيانات الصيدلية الحقيقية فيها
  // عشرات المواد بنفس الباركود من فواتير مختلفة بكميات حقيقية (بل منتجات
  // مختلفة أحياناً)، فالحذف كان يمحو مخزوناً فعلياً. المحلي يبقى، والوارد
  // المتعارض يُتخطّى بلا أي إدراج في طابور الحذف.
  test('وارد أحدث بنفس الباركود يُتخطّى ولا يحذف المحلي', () async {
    await dbi.upsert(med(id: 'a1', barcode: '123', qty: 200, updatedAt: 100));
    final skipped = await dbi.upsertAllSkippingBarcodeConflicts([
      med(id: 'b1', barcode: '123', qty: 5, updatedAt: 200),
    ]);
    expect(skipped, ['b1']);
    final all = await dbi.getAll();
    expect(all.single.id, 'a1');
    expect(all.single.quantity, 200);
    expect(await dbi.peekPendingDeletes(), isEmpty);
  });

  test('وارد أقدم بنفس الباركود يُتخطّى كذلك', () async {
    await dbi.upsert(med(id: 'a1', barcode: '123', qty: 200, updatedAt: 300));
    final skipped = await dbi.upsertAllSkippingBarcodeConflicts([
      med(id: 'b1', barcode: '123', qty: 5, updatedAt: 200),
    ]);
    expect(skipped, ['b1']);
    expect((await dbi.getAll()).single.quantity, 200);
    expect(await dbi.peekPendingDeletes(), isEmpty);
  });

  test('تحديث نفس المعرّف يُكتب عادياً', () async {
    await dbi.upsert(med(id: 'a1', barcode: '123', qty: 1, updatedAt: 100));
    final skipped = await dbi.upsertAllSkippingBarcodeConflicts([
      med(id: 'a1', barcode: '123', qty: 9, updatedAt: 200),
    ]);
    expect(skipped, isEmpty);
    expect((await dbi.getAll()).single.quantity, 9);
  });

  test('لا تناوب: تطبيق نفس الدفعة مرتين بترتيبين يعطي نفس النتيجة', () async {
    final batch = [
      med(id: 'a1', barcode: '123', updatedAt: 100),
      med(id: 'b1', barcode: '123', updatedAt: 200),
    ];
    await dbi.upsertAllSkippingBarcodeConflicts(batch);
    await dbi.upsertAllSkippingBarcodeConflicts(batch.reversed.toList());
    expect((await dbi.getAll()).map((m) => m.id), ['a1']);
    expect(await dbi.peekPendingDeletes(), isEmpty);
  });

  test('باركود فارغ لا يتعارض', () async {
    await dbi.upsertAllSkippingBarcodeConflicts([med(id: 'a1'), med(id: 'b1')]);
    expect((await dbi.getAll()).length, 2);
  });

  test('importBackup لا يُحيي مادة في طابور الحذف', () async {
    await dbi.enqueuePendingDelete('gone');
    final store = _TestStore();
    await store.load();
    final r = await store.importBackup([med(id: 'gone', updatedAt: 999)]);
    expect(r.added, 0);
    expect(r.skipped, 1);
    expect((await dbi.getAll()).any((m) => m.id == 'gone'), isFalse);
  });

  test('importBackup بباركود محلي أحدث لا يمحو المحلي', () async {
    await dbi.upsert(med(id: 'a1', barcode: '123', qty: 200, updatedAt: 300));
    final store = _TestStore();
    await store.load();
    final r = await store.importBackup([
      med(id: 'b1', barcode: '123', qty: 5, updatedAt: 200),
    ]);
    expect(r.added, 0);
    expect(r.skipped, 1);
    final all = await dbi.getAll();
    expect(all.single.id, 'a1');
    expect(all.single.quantity, 200);
  });
}
