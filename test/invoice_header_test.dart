import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/invoice.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/screens/invoice_scan_screen.dart';
import 'package:saydaliyati/screens/invoices_screen.dart';
import 'package:saydaliyati/services/gemini_vision.dart';
import 'package:saydaliyati/state/invoice_store.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';

class _Store extends MedicineStore {
  List<Medicine>? saved;

  @override
  Future<void> load() async {}

  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}

  @override
  Future<void> saveAll(List<Medicine> items) async => saved = items;
}

Widget _app(Widget home) => MaterialApp(
  theme: buildAppTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar'), Locale('en')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

void main() {
  late _Store store;
  late List<Invoice> savedInvoices;
  late List<String> savedPages;
  late bool failInvoice;
  late InvoiceStore invoices;

  setUp(() {
    store = _Store();
    savedInvoices = [];
    savedPages = [];
    failInvoice = false;
    invoices = InvoiceStore(
      loadAll: () async => savedInvoices,
      write: (i) async {
        if (failInvoice) throw Exception('disk full');
        savedInvoices = [...savedInvoices.where((x) => x.id != i.id), i];
      },
      remove: (id) async =>
          savedInvoices = savedInvoices.where((x) => x.id != id).toList(),
      savePage: (f) async {
        savedPages.add(f.path);
        return 'page.jpg';
      },
      deletePage: (_) async {},
      push: (_) async {},
      pushDelete: (_) async {},
    );
  });

  Future<void> scan(WidgetTester tester, InvoiceResult result) async {
    tester.view.physicalSize = const Size(420, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        InvoiceScanScreen(
          store: store,
          invoices: invoices,
          pickPage: ({required bool camera}) async => File('inv1.jpg'),
          readPage: (_) async => result,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('كاميرا'));
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

  final result = InvoiceResult.success(
    [
      InvoiceLine(name: 'Rennie', price: 1000, quantity: 3),
      InvoiceLine(name: 'Panadol', price: 2000, quantity: 1),
    ],
    header: const InvoiceHeader(
      supplier: 'مذخر الشفاء',
      number: '1452',
      date: '12/10/2026',
      total: 5000,
    ),
  );

  testWidgets('الرأس يُملأ من ردّ Gemini نفسه', (tester) async {
    await scan(tester, result);
    expect(text(tester, 'headerSupplier'), 'مذخر الشفاء');
    expect(text(tester, 'headerNumber'), '1452');
    expect(text(tester, 'headerDate'), '12/10/2026');
    // بفواصل الآلاف كبقية الأسعار
    expect(text(tester, 'headerTotal'), '5,000');
    expect(find.textContaining('المجموعان مختلفان'), findsNothing);
  });

  testWidgets('اختلاف مجموع الأسطر عن المطبوع يُنبَّه عليه', (tester) async {
    await scan(tester, result);
    await tester.enterText(find.byKey(const Key('headerTotal')), '9000');
    await tester.pump();
    expect(text(tester, 'headerTotal'), '9,000');
    expect(find.textContaining('المجموعان مختلفان'), findsOneWidget);
  });

  testWidgets('الحفظ يحفظ المواد وسجل الفاتورة بأسطره وصورته', (tester) async {
    await scan(tester, result);
    await tester.enterText(
      find.byKey(const Key('headerSupplier')),
      'مذخر النور',
    );
    await tester.tap(find.textContaining('حفظ ('));
    await tester.pumpAndSettle();

    expect(store.saved, hasLength(2));
    final inv = savedInvoices.single;
    expect(inv.supplier, 'مذخر النور'); // تصحيح المستخدم يُحفظ
    expect(inv.number, '1452');
    expect(inv.total, 5000);
    expect(inv.lines.map((l) => l.name), ['Rennie', 'Panadol']);
    expect(inv.lines.first.quantity, 3);
    expect(inv.lines.every((l) => !l.merged), isTrue);
    expect(inv.imageFiles, ['page.jpg']);
    expect(savedPages.single, endsWith('inv1.jpg'));
  });

  testWidgets('سطر لمادة موجودة يُسجَّل «أُضيفت لموجودة»', (tester) async {
    store.seed([
      const Medicine(
        id: 'old',
        barcode: '',
        name: 'Rennie',
        price: 900,
        quantity: 10,
        type: ItemType.supply,
        createdAt: 0,
        updatedAt: 0,
      ),
    ]);
    await scan(tester, result);
    await tester.tap(find.textContaining('حفظ ('));
    await tester.pumpAndSettle();
    final rennie = savedInvoices.single.lines.firstWhere(
      (l) => l.name == 'Rennie',
    );
    expect(rennie.merged, isTrue);
    expect(rennie.medicineId, 'old');
    expect(rennie.quantity, 3); // كمية الفاتورة لا رصيد المخزون
  });

  testWidgets('فشل حفظ سجل الفاتورة لا يمنع حفظ المواد', (tester) async {
    failInvoice = true;
    await scan(tester, result);
    await tester.tap(find.textContaining('حفظ ('));
    await tester.pumpAndSettle();
    expect(store.saved, hasLength(2));
    expect(savedInvoices, isEmpty);
  });

  group('سجل الفواتير', () {
    Invoice record(
      String id,
      String supplier,
      int date, {
      bool image = false,
    }) => Invoice(
      id: id,
      supplier: supplier,
      dateMs: date,
      total: 1000,
      lines: const [InvoiceRecordLine(name: 'Rennie', quantity: 2, price: 500)],
      imageFiles: image ? ['missing.jpg'] : const [],
      createdAt: date,
      updatedAt: date,
    );

    Future<void> openList(WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      invoices.seed([
        record('a', 'مذخر الشفاء', DateTime(2026, 9, 1).millisecondsSinceEpoch),
        record('b', 'مذخر النور', DateTime(2026, 10, 1).millisecondsSinceEpoch),
      ]);
      await tester.pumpWidget(_app(InvoicesScreen(store: invoices)));
      await tester.pumpAndSettle();
    }

    testWidgets('مرتّبة بالأحدث، والبحث بالمجهّز', (tester) async {
      await openList(tester);
      final first = tester.getTopLeft(find.text('مذخر النور')).dy;
      final second = tester.getTopLeft(find.text('مذخر الشفاء')).dy;
      expect(first, lessThan(second));

      await tester.enterText(find.byKey(const Key('invoiceSearch')), 'الشفاء');
      await tester.pump();
      expect(find.text('مذخر النور'), findsNothing);
      expect(find.text('مذخر الشفاء'), findsOneWidget);
    });

    testWidgets('التفاصيل: الأسطر، و«الصورة على هاتف آخر»، والحذف', (
      tester,
    ) async {
      await openList(tester);
      await tester.tap(find.text('مذخر النور'));
      await tester.pumpAndSettle();
      expect(find.text('Rennie'), findsOneWidget);
      expect(find.byKey(const Key('noInvoiceImage')), findsOneWidget);

      await tester.tap(find.byKey(const Key('deleteInvoice')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('احذف'));
      await tester.pumpAndSettle();
      expect(invoices.all.map((i) => i.id), ['a']);
      expect(store.saved, isNull); // المخزون لم يُمس
    });
  });
}
