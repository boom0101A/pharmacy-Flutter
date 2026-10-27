import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/invoice.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/screens/duplicates_screen.dart';
import 'package:saydaliyati/services/duplicate_dismissals.dart';
import 'package:saydaliyati/state/invoice_store.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Store extends MedicineStore {
  final saved = <Medicine>[];
  final deleted = <String>[];

  /// يحاكي فشل الدمج (تعارض باركود مع مادة خارج المجموعة).
  Object? mergeError;

  @override
  Future<void> load() async {}

  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}

  @override
  Future<void> save(Medicine medicine) async => saved.add(medicine);

  @override
  Future<void> mergeDuplicates(Medicine keeper, List<Medicine> losers) async {
    final e = mergeError;
    if (e != null) throw e;
    saved.add(keeper);
    deleted.addAll(losers.map((m) => m.id));
  }
}

Medicine m(
  String id,
  String name, {
  int qty = 1,
  int updated = 1,
  String? image,
}) => Medicine(
  id: id,
  barcode: '',
  name: name,
  price: 500,
  quantity: qty,
  imagePath: image,
  type: ItemType.supply,
  createdAt: 1,
  updatedAt: updated,
);

void main() {
  late _Store store;
  late List<Medicine> cloud;
  late int pending;
  late List<Invoice> invoiceRecords;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DuplicateDismissals.instance.resetForTest();
    store = _Store();
    cloud = [
      m('a', 'لزقة خافض حرارة', qty: 20, updated: 200),
      m('b', 'لزقة خافض حرارة', qty: 70, updated: 100),
      m('c', 'شاش', qty: 5),
    ];
    pending = 0;
    invoiceRecords = [];
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1600);
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
        home: DuplicatesScreen(
          store: store,
          loadItems: () async => cloud,
          pendingCloudDeletes: () async => pending,
          invoices: InvoiceStore(
            loadAll: () async => invoiceRecords,
            write: (_) async {},
            remove: (_) async {},
            savePage: (_) async => '',
            deletePage: (_) async {},
            push: (_) async {},
            pushDelete: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// يعلّم [ids] ثم يفتح نافذة الدمج.
  Future<void> pick(WidgetTester tester, List<String> ids) async {
    for (final id in ids) {
      await tester.tap(find.byKey(ValueKey('pick-$id')));
      await tester.pump();
    }
  }

  Future<void> openMergeDialog(WidgetTester tester) async {
    await tester.tap(find.textContaining('دمج المختارة ('));
    await tester.pumpAndSettle();
  }

  Finder mergeButton() => find.ancestor(
    of: find.textContaining(RegExp(r'دمج المختارة \(|اختر مادتين')),
    matching: find.byType(FilledButton),
  );

  testWidgets('لا شيء مختار افتراضياً، والدمج يحتاج مادتين', (tester) async {
    await open(tester);
    expect(find.text('اختر مادتين للدمج'), findsOneWidget);
    expect(tester.widget<FilledButton>(mergeButton()).onPressed, isNull);

    await pick(tester, ['a']);
    expect(tester.widget<FilledButton>(mergeButton()).onPressed, isNull);

    await pick(tester, ['b']);
    expect(find.textContaining('دمج المختارة (2) · الكمية 90'), findsOneWidget);
    expect(tester.widget<FilledButton>(mergeButton()).onPressed, isNotNull);
  });

  testWidgets('نافذة الدمج: الاسم الأحدث والسعر والكمية الافتراضية', (
    tester,
  ) async {
    await open(tester);
    await pick(tester, ['a', 'b']);
    await openMergeDialog(tester);

    final keepA = tester.widget<RadioListTile<String>>(
      find.byKey(const ValueKey('keep-a')),
    );
    expect(keepA.value, 'a');
    String field(String key) =>
        tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
    expect(field('mergePrice'), '500');
    expect(field('mergeQuantity'), '90');

    await tester.tap(find.byKey(const Key('mergeSave')));
    await tester.pumpAndSettle();
    expect(store.saved.single.id, 'a'); // الأحدث افتراضياً
    expect(store.saved.single.quantity, 90);
    expect(store.deleted, ['b']);
    expect(find.text('لا توجد تكرارات ✅'), findsOneWidget);
  });

  testWidgets('الحفظ بالاسم المختار والسعر والكمية المكتوبة', (tester) async {
    await open(tester);
    await pick(tester, ['a', 'b']);
    await openMergeDialog(tester);
    await tester.tap(find.byKey(const ValueKey('keep-b')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('mergePrice')), '650');
    await tester.enterText(find.byKey(const Key('mergeQuantity')), '80');
    await tester.pump();
    await tester.tap(find.byKey(const Key('mergeSave')));
    await tester.pumpAndSettle();

    expect(store.saved.single.id, 'b');
    expect(store.saved.single.price, 650);
    expect(store.saved.single.quantity, 80);
    expect(store.deleted, ['a']);
  });

  testWidgets('غير المختارة لا تُحذف، وتُزال من المراجعة نهائياً', (
    tester,
  ) async {
    cloud = [
      m('j1', 'بلاستر انف بعد عمليات ورقي m3 جوزي', qty: 5, updated: 300),
      m('j2', 'بلاستر انف بعد عمليات ورقي m3 جوزی', qty: 9, updated: 200),
      m('t', 'بلاسترانف بعد عمليات ورقي m3 شفاف', qty: 3, updated: 100),
      m('r', 'بلاستر انة بعد عمليات ورقي m3 جوري', qty: 9, updated: 50),
    ];
    await open(tester);
    await pick(tester, ['j1', 'j2']);
    await openMergeDialog(tester);
    await tester.enterText(find.byKey(const Key('mergeQuantity')), '14');
    await tester.pump();
    await tester.tap(find.byKey(const Key('mergeSave')));
    await tester.pumpAndSettle();

    expect(store.saved.single.id, 'j1');
    expect(store.saved.single.quantity, 14);
    expect(store.deleted, ['j2']); // «شفاف» و«جوري» باقيتان في المخزون
    expect(find.text('لا توجد تكرارات ✅'), findsOneWidget);

    // وتبقى مخفية بعد إعادة فتح الشاشة (القرار محفوظ)
    cloud = [
      store.saved.single,
      m('t', 'بلاسترانف بعد عمليات ورقي m3 شفاف', qty: 3, updated: 100),
      m('r', 'بلاستر انة بعد عمليات ورقي m3 جوري', qty: 9, updated: 50),
    ];
    await tester.pumpWidget(const SizedBox());
    await open(tester);
    expect(find.text('لا توجد تكرارات ✅'), findsOneWidget);
  });

  testWidgets('تاريخ الفاتورة بجانب كل مادة', (tester) async {
    cloud = [
      m('a', 'لزقة خافض حرارة', qty: 20, updated: 200),
      m('inv_1754000000000_1_0', 'لزقة خافض حرارة', qty: 70, updated: 100),
    ];
    invoiceRecords = [
      Invoice(
        id: 'rec',
        supplier: 'مذخر الشفاء',
        dateMs: DateTime(2026, 10, 12).millisecondsSinceEpoch,
        lines: const [
          InvoiceRecordLine(
            name: 'لزقة خافض حرارة',
            quantity: 20,
            price: 500,
            medicineId: 'a',
          ),
        ],
        createdAt: 1,
        updatedAt: 1,
      ),
    ];
    await open(tester);
    expect(
      find.textContaining('🧾 فاتورة 2026/10/12 · مذخر الشفاء'),
      findsOneWidget,
    );
    expect(find.textContaining('🧾 من فاتورة بتاريخ'), findsOneWidget);
  });

  testWidgets('«ليست مكرّرة» تختفي وتبقى مختفية بعد إعادة الفتح', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('ليست مكرّرة'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد تكرارات ✅'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await open(tester);
    expect(find.text('لا توجد تكرارات ✅'), findsOneWidget);
    expect(store.saved, isEmpty);
    expect(store.deleted, isEmpty);
  });

  testWidgets('الأسماء المتشابهة في قسم منفصل، ويمكن دمجها أو إخفاؤها', (
    tester,
  ) async {
    cloud = [
      m('a', 'معجون اسنان كين كالسيوم اطفال', qty: 3, updated: 200),
      m('b', 'معجون اسنان كين كالسبوم اطفال', qty: 2, updated: 100),
    ];
    await open(tester);
    expect(find.byKey(const Key('similarSection')), findsOneWidget);
    expect(find.textContaining('أسماء متشابهة بنسبة'), findsOneWidget);

    await tester.tap(find.text('ليست مكرّرة'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد تكرارات ✅'), findsOneWidget);
  });

  testWidgets('الدمج متوقف ما دام الحذف السحابي لم يصل', (tester) async {
    pending = 3;
    await open(tester);
    expect(find.textContaining('3 عملية حذف لم تصل للسحابة'), findsOneWidget);
    await pick(tester, ['a', 'b']);
    expect(tester.widget<FilledButton>(mergeButton()).onPressed, isNull);
  });

  // السحابة لا تحمل مسار الصورة: الدمج كان يحفظ الباقية بلا صورة، وتنظيف
  // الصور اليتيمة يحذف الملف بعد ساعة.
  testWidgets('الدمج يُبقي صورة المادة المحذوفة إن لم تكن للباقية صورة', (
    tester,
  ) async {
    cloud = [
      m('a', 'لزقة خافض حرارة', qty: 20, updated: 200),
      m('b', 'لزقة خافض حرارة', qty: 70, updated: 100, image: 'b.jpg'),
    ];
    await open(tester);
    await pick(tester, ['a', 'b']);
    await openMergeDialog(tester);
    await tester.tap(find.byKey(const Key('mergeSave')));
    await tester.pumpAndSettle();

    expect(store.saved.single.id, 'a');
    expect(store.saved.single.imagePath, 'b.jpg');
  });

  testWidgets('فشل الدمج يظهر رسالة ولا يغيّر شيئاً', (tester) async {
    store.mergeError = Exception('الباركود مسجَّل لمادة أخرى');
    await open(tester);
    await pick(tester, ['a', 'b']);
    await openMergeDialog(tester);
    await tester.tap(find.byKey(const Key('mergeSave')));
    await tester.pumpAndSettle();

    expect(find.textContaining('تعذّر الدمج'), findsOneWidget);
    expect(find.text('لزقة خافض حرارة'), findsNWidgets(2));
  });
}
