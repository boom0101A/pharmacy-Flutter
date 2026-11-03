import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/screens/settings_sheet.dart';
import 'package:saydaliyati/services/app_settings.dart';
import 'package:saydaliyati/services/pharmacy_prefs.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Store extends MedicineStore {
  @override
  Future<void> load() async {}

  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.init();
    PharmacyPrefs.instance.resetForTest();
  });

  tearDown(PharmacyPrefs.instance.resetForTest);

  testWidgets('الحد العام: − و+ يغيّرانه، ولا ينزل تحت 1', (tester) async {
    tester.view.physicalSize = const Size(420, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showSettingsSheet(context, _Store()),
              child: const Text('فتح'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
    expect(find.text('حد المخزون المنخفض الافتراضي'), findsOneWidget);
    expect(find.byKey(const Key('lowStockValue')), findsOneWidget);

    await tester.tap(find.byKey(const Key('lowStockPlus')));
    await tester.pumpAndSettle();
    expect(PharmacyPrefs.instance.lowStockDefault, 6);

    for (var i = 0; i < 8; i++) {
      await tester.tap(find.byKey(const Key('lowStockMinus')));
      await tester.pumpAndSettle();
    }
    expect(PharmacyPrefs.instance.lowStockDefault, 1);
  });
}
