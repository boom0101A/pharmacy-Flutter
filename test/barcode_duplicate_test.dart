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

  final List<Medicine> deleted = [];

  @override
  Future<void> delete(Medicine medicine) async {
    deleted.add(medicine);
    byBarcode.removeWhere((_, m) => m.id == medicine.id);
    all.removeWhere((m) => m.id == medicine.id);
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

    test('إدراج سجل جديد بباركود موجود يُرفض ولا يحذف القديم', () async {
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

      // سجل جديد بمعرّف مختلف لكن بنفس الباركود — كان replace يحذف القديم
      // صامتاً (200 وحدة تضيع بلا خطأ). الآن يُرفض ويبقى القديم.
      final attempt = MedicineDb.instance.upsert(
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

      await expectLater(attempt, throwsA(isA<BarcodeConflictException>()));

      final all = await MedicineDb.instance.getAll();
      expect(all.length, 1);
      expect(all.single.id, 'old1');
      expect(all.single.quantity, 200);
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
      await tester.tap(find.byIcon(Icons.check_rounded));
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
      await tester.tap(find.byIcon(Icons.check_rounded));
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

      await tester.tap(find.byIcon(Icons.check_rounded));
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
      await tester.tap(find.byIcon(Icons.check_rounded));
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
      await tester.tap(find.byIcon(Icons.check_rounded));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('⚠️ الباركود مسجَّل لمادة أخرى'), findsNothing);
      expect(store.saved.length, 1);
      expect(store.saved.single.barcode, '9999999999999');
    });

    // كان المسح (وضغط «تم») يحوّل النموذج بصمت إلى تعديل المادة الأخرى —
    // في وضع التعديل تضيع تعديلات المادة الحالية ولا يظهر أي تنبيه
    group('المسح وضغط «تم» يُظهران التنبيه نفسه', () {
      const current = Medicine(
        id: 'cur1',
        barcode: '5555555555555',
        name: 'حب انفلونزا',
        price: 3102,
        quantity: 20,
        createdAt: 0,
        updatedAt: 0,
      );

      Finder barcodeField() => find.byKey(const Key('barcodeField'));
      String barcodeText(WidgetTester tester) =>
          tester
              .widget<TextField>(
                find.descendant(
                  of: barcodeField(),
                  matching: find.byType(TextField),
                ),
              )
              .controller!
              .text;

      Future<void> open(WidgetTester tester, {Medicine? editing}) async {
        useTallSurface(tester);
        store.all.add(existing);
        store.byBarcode[existing.barcode] = existing;
        if (editing != null) {
          store.all.add(editing);
          store.byBarcode[editing.barcode] = editing;
        }
        await tester.pumpWidget(
          host(
            MedicineFormScreen(
              store: store,
              existing: editing,
              scanBarcode: (_) async => existing.barcode,
            ),
          ),
        );
        await tester.pump();
      }

      Future<void> scan(WidgetTester tester) async {
        await tester.tap(find.byIcon(Icons.qr_code_scanner_rounded));
        await tester.pumpAndSettle();
      }

      testWidgets('تعديل + مسح: تنبيه، والنموذج يبقى على المادة نفسها', (
        tester,
      ) async {
        await open(tester, editing: current);
        await scan(tester);
        expect(find.text('⚠️ الباركود مسجَّل لمادة أخرى'), findsOneWidget);
        expect(find.byKey(const Key('deleteBarcodeOwner')), findsOneWidget);
        expect(find.text('حب انفلونزا'), findsOneWidget);
        expect(store.saved, isEmpty);
      });

      testWidgets('تعديل + مسح ثم «حسناً»: يعود الباركود السابق', (
        tester,
      ) async {
        await open(tester, editing: current);
        await scan(tester);
        await tester.tap(find.text('حسناً'));
        await tester.pumpAndSettle();
        expect(barcodeText(tester), '5555555555555');
        expect(find.text('تعديل دواء'), findsOneWidget);
        expect(find.text('حب انفلونزا'), findsOneWidget);
      });

      testWidgets('تعديل + مسح ثم حذف المرتبط: الباركود يبقى ويُحفظ', (
        tester,
      ) async {
        await open(tester, editing: current);
        await scan(tester);
        await tester.tap(find.byKey(const Key('deleteBarcodeOwner')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirmDeleteOwner')));
        await tester.pumpAndSettle();
        expect(store.deleted.single.id, 'old1');
        expect(barcodeText(tester), existing.barcode);

        await tester.tap(find.byIcon(Icons.check_rounded));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(store.saved.single.id, 'cur1');
        expect(store.saved.single.barcode, existing.barcode);
      });

      // بيانات قديمة قد تحمل الباركود بصيغتين (13 و14 خانة) لمادتين — كان
      // حذف الأولى يعيد البحث فيجد الثانية فيُرجع الخانة بصمت بلا تفسير
      testWidgets('مالكان بصيغتين: حذف الأول يُبقي الباركود، والحفظ ينبّه '
          'للثاني', (tester) async {
        const twin = Medicine(
          id: 'old2',
          barcode: '01234567890123',
          name: 'باراسيتامول قديم',
          price: 400,
          quantity: 3,
          createdAt: 0,
          updatedAt: 0,
        );
        store.all.add(twin);
        store.byBarcode[twin.barcode] = twin;
        await open(tester, editing: current);
        await scan(tester);
        await tester.tap(find.byKey(const Key('deleteBarcodeOwner')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirmDeleteOwner')));
        await tester.pumpAndSettle();
        expect(store.deleted.length, 1);
        expect(barcodeText(tester), existing.barcode, reason: 'لا رجوع صامت');

        await tester.tap(find.byIcon(Icons.check_rounded));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('deleteBarcodeOwner')), findsOneWidget);
        expect(store.saved, isEmpty);
      });

      testWidgets('إضافة + مسح: ثلاثة أزرار، و«إلغاء» يُفرغ الخانة', (
        tester,
      ) async {
        await open(tester);
        await scan(tester);
        expect(find.text('تعديل الموجود'), findsOneWidget);
        expect(find.byKey(const Key('deleteBarcodeOwner')), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('إلغاء'),
          ),
        );
        await tester.pumpAndSettle();
        expect(barcodeText(tester), '');
        expect(find.text('إضافة دواء جديد'), findsOneWidget);
      });

      testWidgets('إضافة + مسح ثم «تعديل الموجود» يتبنّاها', (tester) async {
        await open(tester);
        await scan(tester);
        await tester.tap(find.text('تعديل الموجود'));
        await tester.pumpAndSettle();
        expect(find.text('تعديل دواء'), findsOneWidget);
        expect(find.text('باراسيتامول'), findsOneWidget);
      });

      testWidgets('إضافة + ضغط «تم» في لوحة المفاتيح: التنبيه نفسه', (
        tester,
      ) async {
        await open(tester);
        await tester.enterText(barcodeField(), existing.barcode);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.text('⚠️ الباركود مسجَّل لمادة أخرى'), findsOneWidget);
        expect(find.byKey(const Key('deleteBarcodeOwner')), findsOneWidget);
      });
    });

    group('حذف الدواء المرتبط بالباركود', () {
      const current = Medicine(
        id: 'cur1',
        barcode: '',
        name: 'حب انفلونزا',
        price: 3102,
        quantity: 20,
        createdAt: 0,
        updatedAt: 0,
      );

      Future<void> typeTakenBarcode(WidgetTester tester) async {
        await tester.enterText(
          find.byKey(const Key('barcodeField')),
          '1234567890123',
        );
        await tester.pump();
        await tester.tap(find.byIcon(Icons.check_rounded));
        await tester.pumpAndSettle();
      }

      Future<void> openEditing(WidgetTester tester) async {
        useTallSurface(tester);
        store.all.addAll([existing, current]);
        store.byBarcode[existing.barcode] = existing;
        await tester.pumpWidget(
          host(MedicineFormScreen(store: store, existing: current)),
        );
        await tester.pump();
      }

      Future<void> settleSave(WidgetTester tester) async {
        await tester.tap(find.byIcon(Icons.check_rounded));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      testWidgets('تعديل: الحذف بعد التأكيد يُبقي النموذج، ثم الحفظ يمرّ', (
        tester,
      ) async {
        await openEditing(tester);
        await typeTakenBarcode(tester);
        await tester.tap(find.byKey(const Key('deleteBarcodeOwner')));
        await tester.pumpAndSettle();

        // التأكيد بالاسم والكمية والسعر
        expect(find.text('حذف الدواء المرتبط؟'), findsOneWidget);
        final body = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('باراسيتامول'),
        );
        expect(body, findsOneWidget);
        final text = tester.widget<Text>(body).data!;
        expect(text, contains('200'));
        expect(text, contains('500 د.ع'));

        await tester.tap(find.byKey(const Key('confirmDeleteOwner')));
        await tester.pumpAndSettle();

        expect(store.deleted.single.id, 'old1');
        expect(store.saved, isEmpty, reason: 'لا حفظ تلقائي');
        expect(find.text('تعديل دواء'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);

        await settleSave(tester);
        expect(store.saved.single.id, 'cur1');
        expect(store.saved.single.barcode, '1234567890123');
      });

      testWidgets('ثلاثة أزرار على شاشة ضيقة (360) بلا فيضان', (tester) async {
        await openWithExisting(tester);
        tester.view.physicalSize = const Size(360, 1800);
        await tester.pump();
        await tester.enterText(find.byKey(const Key('nameField')), 'دواء آخر');
        await typeTakenBarcode(tester);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('deleteBarcodeOwner')), findsOneWidget);
        await tester.tap(find.byKey(const Key('deleteBarcodeOwner')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('confirmDeleteOwner')), findsOneWidget);
      });

      testWidgets('مالك مستلزم: العنوان «حذف المستلزم المرتبط؟»', (
        tester,
      ) async {
        useTallSurface(tester);
        final supply = existing.copyWith(type: ItemType.supply);
        store.all.addAll([supply, current]);
        store.byBarcode[supply.barcode] = supply;
        await tester.pumpWidget(
          host(MedicineFormScreen(store: store, existing: current)),
        );
        await tester.pump();
        await typeTakenBarcode(tester);
        await tester.tap(find.byKey(const Key('deleteBarcodeOwner')));
        await tester.pumpAndSettle();
        expect(find.text('حذف المستلزم المرتبط؟'), findsOneWidget);
        expect(find.text('حذف الدواء المرتبط؟'), findsNothing);
      });

      testWidgets('تعديل: «إلغاء» في التأكيد لا يحذف ولا يحفظ', (tester) async {
        await openEditing(tester);
        await typeTakenBarcode(tester);
        await tester.tap(find.byKey(const Key('deleteBarcodeOwner')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('إلغاء'),
          ),
        );
        await tester.pumpAndSettle();
        expect(store.deleted, isEmpty);
        expect(store.saved, isEmpty);
        expect(find.text('تعديل دواء'), findsOneWidget);
      });

      testWidgets('إضافة: زر الحذف بجانب «تعديل الموجود» ويحذف بعد التأكيد', (
        tester,
      ) async {
        await openWithExisting(tester);
        await tester.enterText(find.byKey(const Key('nameField')), 'دواء آخر');
        await typeTakenBarcode(tester);
        expect(find.text('تعديل الموجود'), findsOneWidget);
        await tester.tap(find.byKey(const Key('deleteBarcodeOwner')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirmDeleteOwner')));
        await tester.pumpAndSettle();

        expect(store.deleted.single.id, 'old1');
        expect(store.saved, isEmpty);
        expect(find.text('إضافة دواء جديد'), findsOneWidget);

        await settleSave(tester);
        expect(store.saved.single.name, 'دواء آخر');
        expect(store.saved.single.barcode, '1234567890123');
      });
    });
  });
}
