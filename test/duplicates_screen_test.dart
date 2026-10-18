import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/screens/duplicates_screen.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Store extends MedicineStore {
  final saved = <Medicine>[];
  final deleted = <String>[];

  @override
  Future<void> load() async {}

  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}

  @override
  Future<void> save(Medicine medicine) async => saved.add(medicine);

  @override
  Future<void> delete(Medicine medicine) async => deleted.add(medicine.id);
}

Medicine m(String id, String name, {int qty = 1, int updated = 1}) => Medicine(
  id: id,
  barcode: '',
  name: name,
  price: 500,
  quantity: qty,
  type: ItemType.supply,
  createdAt: 1,
  updatedAt: updated,
);

void main() {
  late _Store store;
  late List<Medicine> cloud;
  late int pending;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = _Store();
    cloud = [
      m('a', 'لزقة خافض حرارة', qty: 20, updated: 200),
      m('b', 'لزقة خافض حرارة', qty: 70, updated: 100),
      m('c', 'شاش', qty: 5),
    ];
    pending = 0;
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
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('الدمج يجمع الكميات في الأحدث ويحذف الباقي', (tester) async {
    await open(tester);
    expect(find.text('لزقة خافض حرارة'), findsNWidgets(2));

    await tester.tap(find.textContaining('دمج (الكمية 90)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ادمج'));
    await tester.pumpAndSettle();

    expect(store.saved.single.id, 'a'); // الأحدث افتراضياً
    expect(store.saved.single.quantity, 90);
    expect(store.deleted, ['b']);
    expect(find.text('لا توجد تكرارات ✅'), findsOneWidget);
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

  testWidgets('الدمج متوقف ما دام الحذف السحابي لم يصل', (tester) async {
    pending = 3;
    await open(tester);

    expect(find.textContaining('3 عملية حذف لم تصل للسحابة'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.textContaining('دمج (الكمية 90)'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });
}
