import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/screens/invoice_scan_screen.dart';
import 'package:saydaliyati/services/gemini_vision.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';

/// شاشة الفاتورة بصفحات متعددة: كل صفحة طلب مستقل، فشل صفحة لا يُسقط البقية،
/// والأسطر المشكوك فيها معلَّمة قبل الحفظ.
class _Store extends MedicineStore {
  List<Medicine>? saved;

  @override
  Future<void> load() async {}

  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}

  @override
  Future<void> saveAll(List<Medicine> items) async => saved = items;
}

void main() {
  late _Store store;
  late List<String> picks;
  late Map<String, InvoiceResult> results;

  setUp(() {
    store = _Store();
    picks = ['page1.jpg', 'page2.jpg', 'page3.jpg'];
    results = {};
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: InvoiceScanScreen(
          store: store,
          pickPage: ({required bool camera}) async =>
              picks.isEmpty ? null : File(picks.removeAt(0)),
          readPage: (file) async =>
              results[file.path.split(RegExp(r'[\\/]')).last] ??
              InvoiceResult.failure('no fixture'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> retake(WidgetTester tester) async {
    await tester.tap(find.byTooltip('تصوير من جديد'));
    await tester.pumpAndSettle();
  }

  // صفحة واحدة في كل مرة (طلب المستخدم): لا «+ صفحة» تُلحق أسطراً بأخرى.
  testWidgets('لا زر لإضافة صفحة ثانية — صفحة واحدة فقط', (tester) async {
    results['page1.jpg'] = InvoiceResult.success([
      InvoiceLine(name: 'Rennie', price: 1000, quantity: 3),
    ]);
    await pump(tester);

    expect(find.widgetWithText(TextField, 'Rennie'), findsOneWidget);
    expect(find.text('+ صفحة'), findsNothing);
    expect(find.text('تصوير من جديد'), findsOneWidget);
  });

  testWidgets('«تصوير من جديد» يستبدل الصفحة وأسطرها بعد التأكيد', (
    tester,
  ) async {
    results['page1.jpg'] = InvoiceResult.success([
      InvoiceLine(name: 'Rennie', price: 1000, quantity: 3),
    ]);
    results['page2.jpg'] = InvoiceResult.success([
      InvoiceLine(name: 'Panadol', price: 500, quantity: 10),
    ]);
    await pump(tester);
    await retake(tester);
    expect(find.text('استبدال الصفحة؟'), findsOneWidget);
    await tester.tap(find.text('استبدال'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Panadol'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Rennie'), findsNothing);
  });

  testWidgets('إلغاء الاستبدال يُبقي الأسطر ولا يفتح الكاميرا', (tester) async {
    results['page1.jpg'] = InvoiceResult.success([
      InvoiceLine(name: 'Rennie', price: 1000, quantity: 3),
    ]);
    await pump(tester);
    await retake(tester);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Rennie'), findsOneWidget);
    expect(picks, ['page2.jpg', 'page3.jpg']);
  });

  testWidgets('فشل الصفحة يظهر سببه مباشرة، و«إعادة المحاولة» تقرأها', (
    tester,
  ) async {
    results['page1.jpg'] = InvoiceResult.failure(
      'استغرقت القراءة وقتاً طويلاً',
    );
    await pump(tester);

    expect(find.text('لم تُقرأ أي أسطر بعد'), findsNothing);
    expect(
      find.textContaining('تعذّرت قراءة الصفحة: استغرقت القراءة'),
      findsOneWidget,
    );

    results['page1.jpg'] = InvoiceResult.success([
      InvoiceLine(name: 'Panadol', price: 500, quantity: 10),
    ]);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Panadol'), findsOneWidget);
    expect(find.textContaining('تعذّرت قراءة الصفحة'), findsNothing);
  });

  testWidgets('السطر المشكوك فيه معلَّم والملخّص يعدّه', (tester) async {
    results['page1.jpg'] = InvoiceResult.success([
      InvoiceLine(name: 'Rennie', price: 1000, quantity: 3),
      InvoiceLine(name: 'Bad', price: 1, quantity: 1, barcode: '6285128013339'),
    ]);
    await pump(tester);

    expect(find.text('باركود غير صالح — حُذف'), findsOneWidget);
    expect(find.textContaining('1 تحتاج مراجعة'), findsOneWidget);
  });

  testWidgets('البونص يُضاف للكمية، والصلاحية تصل إلى الحفظ', (tester) async {
    results['page1.jpg'] = InvoiceResult.success([
      InvoiceLine(
        name: 'Rennie',
        price: 1000,
        quantity: 3,
        bonus: 1,
        expiry: '2027-11',
      ),
    ]);
    await pump(tester);

    expect(find.text('+1 مجاناً'), findsOneWidget);
    await tester.tap(find.textContaining('حفظ ('));
    await tester.pumpAndSettle();

    final saved = store.saved!.single;
    expect(saved.quantity, 4);
    expect(saved.expiryDate, InvoiceLineToMedicine.parseExpiry('2027-11'));
  });

  testWidgets('الرجوع بعد قراءة أسطر يسأل قبل إسقاط الفاتورة', (tester) async {
    results['page1.jpg'] = InvoiceResult.success([
      InvoiceLine(name: 'Rennie', price: 1000, quantity: 3),
    ]);
    await pump(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('الخروج بلا حفظ؟'), findsOneWidget);

    await tester.tap(find.text('البقاء'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Rennie'), findsOneWidget);
  });

  testWidgets('صفحة قرأها النموذج البديل تُعلَّم لمراجعة أدق', (tester) async {
    results['page1.jpg'] = InvoiceResult.success([
      InvoiceLine(name: 'Rennie', price: 1000, quantity: 3),
    ], usedFallback: true);
    await pump(tester);
    expect(find.textContaining('قُرئت بالنموذج البديل'), findsOneWidget);
  });

  testWidgets('قراءة بالنموذج الأساسي بلا علامة', (tester) async {
    results['page1.jpg'] = InvoiceResult.success([
      InvoiceLine(name: 'Rennie', price: 1000, quantity: 3),
    ]);
    await pump(tester);
    expect(find.textContaining('قُرئت بالنموذج البديل'), findsNothing);
  });
}
