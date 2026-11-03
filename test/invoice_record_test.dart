import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/invoice.dart';
import 'package:saydaliyati/services/backup_service.dart';
import 'package:saydaliyati/services/gemini_vision.dart';
import 'package:saydaliyati/services/sync_service.dart';
import 'package:saydaliyati/state/invoice_store.dart';

Invoice inv(
  String id, {
  int updated = 1,
  int? dateMs,
  String? supplier,
  List<String> images = const [],
}) => Invoice(
  id: id,
  supplier: supplier,
  dateMs: dateMs,
  lines: const [
    InvoiceRecordLine(name: 'A', quantity: 2, price: 1000, merged: true),
    InvoiceRecordLine(name: 'B', quantity: 1, price: 500),
  ],
  imageFiles: images,
  createdAt: 1,
  updatedAt: updated,
);

void main() {
  group('رأس الفاتورة من ردّ Gemini (الطلب نفسه)', () {
    test('رأس كامل', () {
      final r = GeminiVision.parseInvoiceJson(
        '{"lines":[{"name":"X"}],"header":{"supplier":"مذخر الشفاء",'
        '"invoice_number":"1452","date":"12/10/2026","total":1250000}}',
      );
      expect(r.header!.supplier, 'مذخر الشفاء');
      expect(r.header!.number, '1452');
      expect(r.header!.date, '12/10/2026');
      expect(r.header!.total, 1250000);
    });

    test('رأس غائب ← null والأسطر سليمة', () {
      final r = GeminiVision.parseInvoiceJson('{"lines":[{"name":"X"}]}');
      expect(r.ok, isTrue);
      expect(r.header, isNull);
      expect(r.lines.single.name, 'X');
    });

    test('رأس تالف لا يُسقط الأسطر', () {
      final r = GeminiVision.parseInvoiceJson(
        '{"lines":[{"name":"X"}],"header":"garbage"}',
      );
      expect(r.ok, isTrue);
      expect(r.header, isNull);
      expect(r.lines, hasLength(1));
    });

    test('مجموع نصي بفواصل آلاف', () {
      final r = GeminiVision.parseInvoiceJson(
        '{"lines":[],"header":{"total":"1,250,000"}}',
      );
      expect(r.header!.total, 1250000);
    });
  });

  group('Invoice', () {
    test('محلياً: ذهاباً وإياباً بالأسطر والصور', () {
      final back = Invoice.fromMap(inv('i', images: ['p1.jpg']).toMap());
      expect(back.lines, hasLength(2));
      expect(back.lines.first.merged, isTrue);
      expect(back.imageFiles, ['p1.jpg']);
      expect(back.linesTotal, 2500);
    });

    test('السحابة لا تحمل أسماء الصور (محلية لكل هاتف)', () {
      final cloud = inv('i', images: ['p1.jpg']).toCloud();
      expect(cloud.containsKey('imageFiles'), isFalse);
      expect(Invoice.fromMap(cloud).lines, hasLength(2));
    });
  });

  group('mergeInvoices', () {
    test('النازلة الأحدث تحلّ محل المحلية مع إبقاء صور هذا الهاتف', () {
      final r = SyncService.mergeInvoices(
        local: [
          inv('a', updated: 1, images: ['mine.jpg']),
        ],
        remote: [inv('a', updated: 5, supplier: 'جديد')],
        deleted: {},
      );
      expect(r.merged.single.supplier, 'جديد');
      expect(r.merged.single.imageFiles, ['mine.jpg']);
      expect(r.upload, isEmpty);
    });

    test('المحلية الأحدث أو غير المرفوعة تُرفع', () {
      final r = SyncService.mergeInvoices(
        local: [inv('a', updated: 9), inv('b')],
        remote: [inv('a', updated: 5)],
        deleted: {},
      );
      expect(r.upload.map((i) => i.id), unorderedEquals(['a', 'b']));
    });

    test('المحذوفة من هاتف آخر تختفي ولا تُرفع', () {
      final r = SyncService.mergeInvoices(
        local: [inv('a')],
        remote: [inv('a')],
        deleted: {'a'},
      );
      expect(r.merged, isEmpty);
      expect(r.upload, isEmpty);
    });

    test('الترتيب بالتاريخ الأحدث', () {
      final r = SyncService.mergeInvoices(
        local: [inv('old', dateMs: 10), inv('new', dateMs: 20)],
        remote: const [],
        deleted: {},
      );
      expect(r.merged.map((i) => i.id), ['new', 'old']);
    });
  });

  test('invoicesFor: فواتير المادة بأسطرها، الأحدث أولاً', () {
    Invoice withLine(String id, int date, String? medId, int qty) => Invoice(
      id: id,
      dateMs: date,
      lines: [
        InvoiceRecordLine(
          name: 'X',
          quantity: qty,
          price: 900,
          medicineId: medId,
        ),
      ],
      createdAt: date,
      updatedAt: date,
    );
    final store = InvoiceStore()
      ..seed([
        withLine('old', 10, 'm1', 1),
        withLine('new', 20, 'm1', 3),
        withLine('other', 30, 'm2', 5),
      ]);
    expect(store.invoicesFor('m1').map((e) => e.invoice.id), ['new', 'old']);
    expect(store.invoicesFor('m1').first.line.quantity, 3);
    expect(store.invoicesFor('zzz'), isEmpty);
  });

  group('InvoiceStore', () {
    late List<Invoice> db;
    late List<String> pushed, pushedDeletes, deletedPages;
    late InvoiceStore store;

    setUp(() {
      db = [];
      pushed = [];
      pushedDeletes = [];
      deletedPages = [];
      store = InvoiceStore(
        loadAll: () async => db,
        write: (i) async => db = [...db.where((x) => x.id != i.id), i],
        remove: (id) async => db = db.where((x) => x.id != id).toList(),
        savePage: (f) async => 'saved_${f.path.split('/').last}',
        deletePage: (n) async => deletedPages.add(n),
        push: (i) async => pushed.add(i.id),
        pushDelete: (id) async => pushedDeletes.add(id),
      );
    });

    test('الإضافة تحفظ الصفحات والسجل وترفعه', () async {
      final saved = await store.add(inv('a'), [File('x/p1.jpg')]);
      expect(saved.imageFiles, ['saved_p1.jpg']);
      expect(db.single.id, 'a');
      expect(store.all.single.id, 'a');
      expect(pushed, ['a']);
    });

    test('الحذف يحذف السجل وصوره ويرفع الحذف', () async {
      final saved = await store.add(inv('a'), [File('x/p1.jpg')]);
      await store.delete(saved);
      expect(db, isEmpty);
      expect(store.all, isEmpty);
      expect(deletedPages, ['saved_p1.jpg']);
      expect(pushedDeletes, ['a']);
    });

    test('الاسترجاع يضيف الغائب ويتجاهل الأقدم', () async {
      await store.add(inv('a', updated: 5), const []);
      final n = await store.importAll([inv('a', updated: 1), inv('b')]);
      expect(n, 1);
      expect(store.all.map((i) => i.id), unorderedEquals(['a', 'b']));
    });
  });

  test('النسخة الاحتياطية تقرأ الفواتير، والنسخ القديمة بلا فواتير سليمة', () {
    final withInv = BackupService.parse(
      '{"format":1,"items":[],"invoices":[{"id":"i","supplier":"S",'
      '"lines":[{"name":"A","quantity":1,"price":5}],'
      '"createdAt":1,"updatedAt":1}]}',
    );
    expect(withInv.invoices.single.supplier, 'S');
    expect(withInv.invoices.single.lines.single.name, 'A');

    final old = BackupService.parse('{"format":1,"items":[]}');
    expect(old.ok, isTrue);
    expect(old.invoices, isEmpty);
  });
}
