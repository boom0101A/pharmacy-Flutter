import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/db/medicine_db.dart' show BarcodeConflictException;
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/screens/complete_data_screen.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';

class _Store extends MedicineStore {
  final saved = <Medicine>[];
  final deleted = <String>[];
  Medicine? mergedKeeper;
  List<Medicine>? mergedLosers;
  bool conflict = false;

  @override
  Future<void> load() async {}

  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}

  @override
  Future<void> save(Medicine medicine) async {
    if (conflict) {
      throw BarcodeConflictException(
        barcode: medicine.barcode,
        incomingId: medicine.id,
        existingId: 'other',
      );
    }
    saved.add(medicine);
  }

  @override
  Future<void> delete(Medicine medicine) async => deleted.add(medicine.id);

  @override
  Future<void> mergeDuplicates(Medicine keeper, List<Medicine> losers) async {
    mergedKeeper = keeper;
    mergedLosers = losers;
  }
}

Medicine _m(
  String id,
  String name, {
  double price = 0,
  int qty = 0,
  String barcode = '',
  int updated = 1,
}) => Medicine(
  id: id,
  barcode: barcode,
  name: name,
  price: price,
  quantity: qty,
  createdAt: 1,
  updatedAt: updated,
);

void main() {
  late _Store store;

  setUp(() {
    store = _Store()
      ..seed([
        _m('blank', 'RIBOSAN', barcode: '04009932923933'),
        _m(
          'full',
          'RIBOSAN ( 100 ml ) Syrup',
          price: 4500,
          qty: 12,
          barcode: '',
        ),
        _m('nob', 'Zinc cream', price: 900, qty: 3, updated: 0),
      ]);
  });

  Future<void> open(
    WidgetTester tester, {
    Future<String?> Function()? scan,
  }) async {
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
        home: CompleteDataScreen(
          store: store,
          type: ItemType.medicine,
          scanBarcode: scan,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('بلا سعر أولاً، ثم بلا باركود، وعدّاد التقدّم', (tester) async {
    await open(tester);
    // الكاملة السعر لكن بلا باركود («full») ناقصة أيضاً — 3 مواد
    expect(find.text('مادة 1 من 3'), findsOneWidget);
    expect(find.text('RIBOSAN'), findsOneWidget);
    expect(find.text('بلا سعر'), findsOneWidget);
  });

  testWidgets('حفظ السعر والكمية ثم التالي', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('completePrice')), '4500');
    await tester.enterText(find.byKey(const Key('completeQuantity')), '6');
    await tester.tap(find.byKey(const Key('completeSaveNext')));
    await tester.pumpAndSettle();

    expect(store.saved.single.id, 'blank');
    expect(store.saved.single.price, 4500);
    expect(store.saved.single.quantity, 6);
    expect(find.text('مادة 2 من 3'), findsOneWidget);
  });

  testWidgets('«تشبه مادة موجودة» ← الدمج يُبقي المكتملة', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('similarSuggestion')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mergeWithSimilar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ادمج'));
    await tester.pumpAndSettle();

    expect(store.mergedKeeper!.id, 'full');
    // باركود النسخة الفارغة ينتقل للباقية
    expect(store.mergedKeeper!.barcode, '04009932923933');
    expect(store.mergedLosers!.single.id, 'blank');
  });

  testWidgets('مسح الباركود يملأ الحقل (ويفكّ GS1)', (tester) async {
    await open(tester, scan: () async => '0106285128013338172711301099');
    await tester.tap(find.byKey(const Key('completeSkip')));
    await tester.pumpAndSettle(); // المادة الثانية: full بلا باركود
    await tester.tap(find.byKey(const Key('completeScan')));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.byKey(const Key('completeBarcode')),
    );
    expect(field.controller!.text, '06285128013338');
  });

  testWidgets('«ليس لها باركود» يُحفظ ويُخرجها من الناقصة', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('completeSkip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('completeSkip')));
    await tester.pumpAndSettle(); // Zinc cream: مسعّرة بلا باركود
    await tester.tap(find.byKey(const Key('completeNoBarcode')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('completeSaveNext')));
    await tester.pumpAndSettle();

    expect(store.saved.single.noBarcode, isTrue);
    expect(store.saved.single.isIncomplete, isFalse);
    expect(find.byKey(const Key('completeFinished')), findsOneWidget);
  });

  testWidgets('الحذف بتأكيد', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('completeDelete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('احذف'));
    await tester.pumpAndSettle();
    expect(store.deleted, ['blank']);
  });

  testWidgets('تعارض الباركود يُظهر رسالة ولا يتقدّم', (tester) async {
    store.conflict = true;
    await open(tester);
    await tester.enterText(find.byKey(const Key('completePrice')), '100');
    await tester.tap(find.byKey(const Key('completeSaveNext')));
    await tester.pumpAndSettle();
    expect(find.textContaining('مسجّل لمادة أخرى'), findsOneWidget);
    expect(find.text('مادة 1 من 3'), findsOneWidget);
  });
}
