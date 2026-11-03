import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/screens/form_screen.dart';
import 'package:saydaliyati/services/app_settings.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';
import 'package:saydaliyati/widgets/medicine_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// الدولار عملة عرض وإدخال: الأسعار تبقى مخزّنة بالدينار.
class _Store extends MedicineStore {
  final saved = <Medicine>[];

  @override
  Future<void> load() async {}

  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}

  @override
  Future<Medicine?> findByBarcode(String barcode) async => null;

  @override
  Future<void> save(Medicine medicine) async {
    saved.removeWhere((m) => m.id == medicine.id);
    saved.add(medicine);
  }
}

const _med = Medicine(
  id: 'm1',
  barcode: '',
  name: 'Duphalac',
  price: 7877,
  quantity: 2,
  createdAt: 1,
  updatedAt: 1,
);

void main() {
  final s = AppSettings.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await s.init();
    await s.setUsdRate(1310);
    await s.setCurrency('USD');
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await s.init();
  });

  Widget host(Widget child) => MaterialApp(
    theme: buildAppTheme(),
    home: Directionality(textDirection: TextDirection.rtl, child: child),
  );

  testWidgets('البطاقة تعرض السعر بالدولار', (tester) async {
    await tester.pumpWidget(
      host(
        Scaffold(
          body: SizedBox(
            width: 200,
            height: 340,
            child: MedicineCard(
              medicine: _med,
              animate: false,
              onEdit: () {},
              onDelete: () {},
              onOpen: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(r'$6.01'), findsOneWidget);
    expect(find.textContaining('7,877'), findsNothing);
  });

  group('نموذج المادة بالدولار', () {
    late _Store store;
    setUp(() => store = _Store());

    Future<void> openEdit(WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        host(MedicineFormScreen(store: store, existing: _med)),
      );
      await tester.pump();
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.check_rounded));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('الخانة بالدولار، وتعديل بلا لمس السعر يبقيه 7,877', (
      tester,
    ) async {
      await openEdit(tester);
      expect(find.text('6.01'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('quantityField')), '5');
      await save(tester);
      expect(store.saved.single.price, 7877, reason: 'لا تقريب صامت');
      expect(store.saved.single.quantity, 5);
    });

    testWidgets(r'كتابة $10 تُحفظ 13,100 ديناراً', (tester) async {
      await openEdit(tester);
      await tester.enterText(find.byKey(const Key('priceField')), '10');
      await save(tester);
      expect(store.saved.single.price, 13100);
    });
  });
}
