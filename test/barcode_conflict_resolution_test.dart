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

  test('وارد أحدث بنفس الباركود يحلّ محل المحلي ويُسجَّل المحلي للحذف', () async {
    await dbi.upsert(med(id: 'a1', barcode: '123', qty: 200, updatedAt: 100));
    final losers = await dbi.upsertAllResolvingBarcodes([
      med(id: 'b1', barcode: '123', qty: 5, updatedAt: 200),
    ]);
    expect(losers, ['a1']);
    expect((await dbi.getAll()).map((m) => m.id), ['b1']);
    expect(await dbi.peekPendingDeletes(), contains('a1'));
  });

  test('وارد أقدم بنفس الباركود يُتخطّى ولا يمس المحلي', () async {
    await dbi.upsert(med(id: 'a1', barcode: '123', qty: 200, updatedAt: 300));
    final losers = await dbi.upsertAllResolvingBarcodes([
      med(id: 'b1', barcode: '123', qty: 5, updatedAt: 200),
    ]);
    expect(losers, ['b1']);
    final all = await dbi.getAll();
    expect(all.single.id, 'a1');
    expect(all.single.quantity, 200);
    expect(await dbi.peekPendingDeletes(), contains('b1'));
  });

  test('تساوي الختم: المعرّف الأصغر يفوز على الجهازين', () async {
    await dbi.upsert(med(id: 'b1', barcode: '123', updatedAt: 100));
    final losers = await dbi.upsertAllResolvingBarcodes([
      med(id: 'a1', barcode: '123', updatedAt: 100),
    ]);
    expect(losers, ['b1']);
    expect((await dbi.getAll()).single.id, 'a1');
  });

  test('لا تناوب: تطبيق نفس الدفعة مرتين بترتيبين يعطي نفس النتيجة', () async {
    final batch = [
      med(id: 'a1', barcode: '123', updatedAt: 100),
      med(id: 'b1', barcode: '123', updatedAt: 200),
    ];
    await dbi.upsertAllResolvingBarcodes(batch);
    await dbi.upsertAllResolvingBarcodes(batch.reversed.toList());
    expect((await dbi.getAll()).map((m) => m.id), ['b1']);
  });

  test('باركود فارغ لا يتعارض', () async {
    await dbi.upsertAllResolvingBarcodes([
      med(id: 'a1'),
      med(id: 'b1'),
    ]);
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
