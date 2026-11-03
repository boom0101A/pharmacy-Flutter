import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/invoice.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/screens/invoices_screen.dart';
import 'package:saydaliyati/screens/medicine_detail_screen.dart';
import 'package:saydaliyati/state/invoice_store.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';
import 'package:saydaliyati/widgets/glass.dart';

class _Store extends MedicineStore {
  final saved = <Medicine>[];

  @override
  Future<void> load() async {}

  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}

  @override
  Future<void> save(Medicine medicine) async {
    saved.add(medicine);
    seed([
      for (final m in all)
        if (m.id != medicine.id) m,
      medicine,
    ]);
  }
}

Medicine _med({
  int qty = 4,
  double price = 2500,
  String barcode = '6285128013338',
  String? company = 'Juman',
  DateTime? expiry,
}) => Medicine(
  id: 'm1',
  barcode: barcode,
  name: 'Panadol Extra ( 500 mg ) 24 tab — اسم طويل جداً لا يُقصّ',
  price: price,
  quantity: qty,
  company: company,
  category: 'Tablet',
  expiryDate: expiry?.millisecondsSinceEpoch,
  createdAt: DateTime(2026, 8, 3).millisecondsSinceEpoch,
  updatedAt: DateTime(2026, 10, 20).millisecondsSinceEpoch,
);

void main() {
  late _Store store;
  late InvoiceStore invoices;
  late List<String> shared;
  late int edits;
  late int deletes;

  setUp(() {
    store = _Store();
    invoices = InvoiceStore(
      loadAll: () async => [],
      write: (_) async {},
      remove: (_) async {},
      savePage: (_) async => '',
      deletePage: (_) async {},
      push: (_) async {},
      pushDelete: (_) async {},
    );
    shared = [];
    edits = 0;
    deletes = 0;
  });

  Future<void> open(WidgetTester tester, Medicine m) async {
    store.seed([m]);
    tester.view.physicalSize = const Size(420, 2400);
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
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MedicineDetailScreen(
                    store: store,
                    medicineId: m.id,
                    invoices: invoices,
                    onEdit: () => edits++,
                    onDelete: () => deletes++,
                    share: (text) async => shared.add(text),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('تعرض الاسم الكامل والسعر والكمية وقيمة المخزون', (tester) async {
    await open(tester, _med());
    expect(find.textContaining('اسم طويل جداً لا يُقصّ'), findsOneWidget);
    expect(find.text('2,500 د.ع'), findsOneWidget);
    expect(find.byKey(const Key('detailQuantity')), findsOneWidget);
    expect(find.text('10,000 د.ع'), findsOneWidget);
    // التاريخ وحده بجانب «الإضافة» — لا «الإضافة | أُضيفت …» مكرّرة
    expect(find.text('2026/08/03'), findsOneWidget);
    expect(find.textContaining('أُضيفت'), findsNothing);
  });

  // OpenContainer يرسم البطاقة مكبّرة خلف الصفحة أثناء الرجوع؛ شريط العنوان
  // الزجاجي فوق خلفية شفافة كان يُظهرها — «تداخل أعلى البطاقة» على الهاتف.
  testWidgets('خلفية الصفحة معتمة فلا يظهر ما خلفها أثناء الانتقال', (
    tester,
  ) async {
    await open(tester, _med());
    final scaffold = tester.widget<Scaffold>(
      find
          .descendant(
            of: find.byType(MedicineDetailScreen),
            matching: find.byType(Scaffold),
          )
          .first,
    );
    expect(scaffold.backgroundColor, AppColors.bgDark);
    expect(scaffold.backgroundColor!.a, 1.0);
  });

  // كان أعلى الصفحة لوناً داكناً موحّداً وتحته يبدأ الشفق — خط فاصل ظاهر
  // أسفل شريط العنوان. الآن يمتد الشفق خلف الشريط كبقية الشاشات.
  testWidgets('الشفق يمتد خلف شريط العنوان', (tester) async {
    await open(tester, _med());
    expect(tester.getRect(find.byType(AuroraBackground)).top, 0);
  });

  testWidgets('المحتوى يبدأ أسفل شريط العنوان لا تحته', (tester) async {
    await open(tester, _med());
    final bar = tester.getRect(find.byType(GlassAppBar));
    final name = tester.getRect(find.textContaining('اسم طويل جداً'));
    expect(name.top, greaterThanOrEqualTo(bar.bottom));
    // والقائمة نفسها تبدأ تحته، فلا يمرّ المحتوى تحت الزجاج عند التمرير
    expect(
      tester.getRect(find.byType(ListView)).top,
      greaterThanOrEqualTo(bar.bottom),
    );
  });

  testWidgets('الصلاحية مع الأيام المتبقية', (tester) async {
    final n = DateTime.now();
    // ظهر اليوم الثلاثين: لا يتأثر بساعة التشغيل قرب منتصف الليل
    final in30 = DateTime(n.year, n.month, n.day + 30, 12);
    await open(tester, _med(expiry: in30));
    expect(find.textContaining('متبقٍ 30'), findsOneWidget);
  });

  testWidgets('الحقول الغائبة لا تظهر', (tester) async {
    await open(tester, _med(barcode: '', company: null));
    expect(find.textContaining('الباركود'), findsNothing);
    expect(find.textContaining('الشركة'), findsNothing);
    expect(find.textContaining('الصلاحية'), findsNothing);
  });

  testWidgets('سجل الفواتير يعرض المجهّز، والضغط يفتح الفاتورة', (
    tester,
  ) async {
    invoices.seed([
      Invoice(
        id: 'i1',
        supplier: 'مذخر الشفاء',
        dateMs: DateTime(2026, 10, 12).millisecondsSinceEpoch,
        lines: const [
          InvoiceRecordLine(
            name: 'Panadol',
            quantity: 3,
            price: 2200,
            medicineId: 'm1',
          ),
        ],
        createdAt: 1,
        updatedAt: 1,
      ),
    ]);
    await open(tester, _med());
    expect(find.text('مذخر الشفاء'), findsOneWidget);
    await tester.tap(find.text('مذخر الشفاء'));
    await tester.pumpAndSettle();
    expect(find.byType(InvoiceDetailScreen), findsOneWidget);
  });

  testWidgets('بلا فواتير', (tester) async {
    await open(tester, _med());
    expect(find.text('لا فواتير محفوظة لهذه المادة'), findsOneWidget);
  });

  testWidgets('حذفها من مكان آخر يغلق الصفحة', (tester) async {
    await open(tester, _med());
    store.seed([]);
    await tester.pumpAndSettle();
    expect(find.byType(MedicineDetailScreen), findsNothing);
    expect(find.text('حُذفت هذه المادة'), findsOneWidget);
  });

  testWidgets('المشاركة ترسل نص المادة', (tester) async {
    await open(tester, _med());
    await tester.tap(find.byKey(const Key('detailShare')));
    await tester.pumpAndSettle();
    expect(shared.single, contains('Panadol Extra'));
    expect(shared.single, contains('2,500'));
    expect(shared.single, contains('6285128013338'));
  });

  testWidgets('التعديل يستدعي onEdit، والحذف يغلق ثم يستدعي onDelete', (
    tester,
  ) async {
    await open(tester, _med());
    await tester.tap(find.byKey(const Key('detailEdit')));
    await tester.pumpAndSettle();
    expect(edits, 1);
    await tester.tap(find.byKey(const Key('detailDelete')));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    expect(find.byType(MedicineDetailScreen), findsNothing);
  });

  testWidgets('− يسار + في الواجهة (كالمعتاد)', (tester) async {
    await open(tester, _med());
    final minus = tester.getCenter(find.byKey(const Key('qtyMinus'))).dx;
    final plus = tester.getCenter(find.byKey(const Key('qtyPlus'))).dx;
    expect(minus, lessThan(plus));
  });

  group('تعديل سريع للكمية', () {
    String shownQty(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('detailQuantity'))).data!;

    testWidgets('+ يزيد ويحفظ', (tester) async {
      await open(tester, _med(qty: 4));
      await tester.tap(find.byKey(const Key('qtyPlus')));
      await tester.pumpAndSettle();
      expect(store.saved.last.quantity, 5);
      expect(shownQty(tester), '5');
    });

    testWidgets('− معطّل عند الصفر', (tester) async {
      await open(tester, _med(qty: 0));
      final minus = tester.widget<IconButton>(
        find.descendant(
          of: find.byKey(const Key('qtyMinus')),
          matching: find.byType(IconButton),
        ),
      );
      expect(minus.onPressed, isNull);
    });

    testWidgets('ضغطات متتالية لا تُسقط زيادة', (tester) async {
      await open(tester, _med(qty: 4));
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('qtyPlus')));
      }
      await tester.pumpAndSettle();
      expect(store.saved.last.quantity, 7);
      expect(shownQty(tester), '7');
    });
  });
}
