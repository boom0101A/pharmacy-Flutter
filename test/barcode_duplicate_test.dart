import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:saydaliyati/db/medicine_db.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/screens/form_screen.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// باركود مكرَّر = فقدان بيانات صامت، لا مجرد تكرار مرئي.
///
/// الجدول يحمل فهرساً فريداً جزئياً على `barcode`، و`upsert` يستعمل
/// `ConflictAlgorithm.replace` — وسلوك SQLite لـ`INSERT OR REPLACE` عند
/// تعارض قيد فريد هو **حذف الصف المتعارض** ثم الإدراج، لا رمي خطأ. لذلك
/// حفظ سجل جديد بباركود موجود كان يمحو الدواء القديم بكميته وسعره بصمت.
///
/// المجموعة الأولى توثّق سلوك القاعدة نفسه على قاعدة حقيقية (تُثبت أن الخطر
/// واقعي لا نظري)، والثانية تتحقق أن الواجهة تمنع الوصول إليه أصلاً.
class _MemoryStore extends MedicineStore {
  final List<Medicine> saved = [];
  final Map<String, Medicine> byBarcode = {};

  @override
  Future<void> load() async {}

  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}

  @override
  Future<Medicine?> findByBarcode(String barcode) async {
    final code = barcode.trim();
    for (final entry in byBarcode.entries) {
      if (entry.key == code ||
          entry.key.padLeft(14, '0') == code.padLeft(14, '0')) {
        return entry.value;
      }
    }
    return null;
  }

  @override
  Future<void> save(Medicine medicine) async {
    saved.removeWhere((m) => m.id == medicine.id);
    saved.add(medicine);
    if (medicine.barcode.isNotEmpty) byBarcode[medicine.barcode] = medicine;
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('سلوك القاعدة الحقيقي — لماذا الفحص في الواجهة ضروري', () {
    late Directory tempDir;
    var counter = 0;
    Database? db;

    setUpAll(
      () => tempDir = Directory.systemTemp.createTempSync('barcode_dup'),
    );
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

    test('إدراج سجل جديد بباركود موجود يحذف السجل القديم صامتاً', () async {
      await MedicineDb.instance.upsert(
        const Medicine(
          id: 'old1',
          barcode: '1234567890123',
          name: 'دواء قديم',
          price: 500,
          quantity: 200,
          createdAt: 0,
          updatedAt: 0,
        ),
      );

      // سجل جديد بمعرّف مختلف لكن بنفس الباركود
      await MedicineDb.instance.upsert(
        const Medicine(
          id: 'new1',
          barcode: '1234567890123',
          name: 'دواء جديد',
          price: 10,
          quantity: 5,
          createdAt: 0,
          updatedAt: 0,
        ),
      );

      final all = await MedicineDb.instance.getAll();
      // هذا هو جوهر الخطر: لم يُرمَ خطأ، ولم يبقَ السجلان — القديم اختفى
      expect(all.length, 1);
      expect(all.single.id, 'new1');
      expect(all.single.quantity, 5, reason: '200 وحدة ضاعت بلا أي خطأ');
    });
  });

  group('الواجهة تمنع الوصول إلى ذلك السلوك', () {
    late _MemoryStore store;

    setUp(() => store = _MemoryStore());

    void useTallSurface(WidgetTester tester) {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    Widget host(Widget child) => MaterialApp(
      theme: buildAppTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, inner) =>
          Directionality(textDirection: TextDirection.rtl, child: inner!),
      home: child,
    );

    const existing = Medicine(
      id: 'old1',
      barcode: '1234567890123',
      name: 'باراسيتامول',
      price: 500,
      quantity: 200,
      createdAt: 0,
      updatedAt: 0,
    );

    Future<void> openWithExisting(WidgetTester tester) async {
      useTallSurface(tester);
      store.all.add(existing);
      store.byBarcode[existing.barcode] = existing;
      await tester.pumpWidget(host(MedicineFormScreen(store: store)));
      await tester.pump();
    }

    testWidgets('كتابة باركود موجود يدوياً تُظهر تنبيهاً ولا تحفظ صامتاً', (
      tester,
    ) async {
      await openWithExisting(tester);

      await tester.enterText(
        find.byKey(const Key('barcodeField')),
        '1234567890123',
      );
      await tester.enterText(find.byKey(const Key('nameField')), 'دواء آخر');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(find.text('⚠️ الباركود مسجَّل لمادة أخرى'), findsOneWidget);
      expect(store.saved, isEmpty, reason: 'لا حفظ قبل قرار المستخدم');
    });

    testWidgets('«تعديل الموجود» يتبنّى السجل القديم ولا يُنشئ ثانياً', (
      tester,
    ) async {
      await openWithExisting(tester);

      await tester.enterText(
        find.byKey(const Key('barcodeField')),
        '1234567890123',
      );
      await tester.enterText(find.byKey(const Key('nameField')), 'دواء آخر');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('تعديل الموجود'),
        ),
      );
      await tester.pumpAndSettle();

      // صار النموذج تعديلاً للسجل القديم — بكميته الأصلية سليمة
      expect(find.text('تعديل دواء'), findsOneWidget);
      expect(store.saved, isEmpty);

      await tester.tap(find.byIcon(Icons.check));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(store.saved.length, 1);
      expect(store.saved.single.id, 'old1', reason: 'تعديل لا استبدال');
      expect(store.saved.single.quantity, 200, reason: 'الكمية لم تُمحَ');
    });

    testWidgets('«إلغاء» لا يحفظ شيئاً ويُبقي النموذج', (tester) async {
      await openWithExisting(tester);

      await tester.enterText(
        find.byKey(const Key('barcodeField')),
        '1234567890123',
      );
      await tester.enterText(find.byKey(const Key('nameField')), 'دواء آخر');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('إلغاء'),
        ),
      );
      await tester.pumpAndSettle();

      expect(store.saved, isEmpty);
      expect(find.text('إضافة دواء جديد'), findsOneWidget);
    });

    testWidgets('باركود جديد لا يُظهر أي تنبيه ويحفظ مباشرة', (tester) async {
      await openWithExisting(tester);

      await tester.enterText(
        find.byKey(const Key('barcodeField')),
        '9999999999999',
      );
      await tester.enterText(find.byKey(const Key('nameField')), 'دواء جديد');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('⚠️ الباركود مسجَّل لمادة أخرى'), findsNothing);
      expect(store.saved.length, 1);
      expect(store.saved.single.barcode, '9999999999999');
    });
  });
}
