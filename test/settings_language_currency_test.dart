import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/screens/settings_sheet.dart';
import 'package:saydaliyati/services/app_settings.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestStore extends MedicineStore {
  @override
  Future<void> load() async {}

  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}
}

void main() {
  final s = AppSettings.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await s.init();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await s.init();
  });

  Future<void> openSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = _TestStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showSettingsSheet(context, store),
                child: const Text('فتح'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
  }

  testWidgets('اختيار English يغيّر لغة الإعدادات', (tester) async {
    await openSettings(tester);
    await tester.tap(find.byKey(const Key('langEn')));
    await tester.pumpAndSettle();
    expect(s.language, 'en');
  });

  testWidgets('الدولار أول مرة يطلب سعر الصرف، والإلغاء يبقي الدينار', (
    tester,
  ) async {
    await openSettings(tester);
    await tester.tap(find.byKey(const Key('currencyUsd')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('usdRateField')), findsOneWidget);

    await tester.tap(find.byKey(const Key('usdRateCancel')));
    await tester.pumpAndSettle();
    expect(s.currency, 'IQD');
  });

  testWidgets('إدخال السعر يفعّل الدولار ويظهر السعر في الإعدادات', (
    tester,
  ) async {
    await openSettings(tester);
    await tester.tap(find.byKey(const Key('currencyUsd')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('usdRateField')), '1310');
    await tester.pump();
    expect(find.text('1,310'), findsOneWidget, reason: 'فواصل الآلاف');
    await tester.tap(find.byKey(const Key('usdRateSave')));
    await tester.pumpAndSettle();

    expect(s.usdRate, 1310);
    expect(s.currency, 'USD');
    expect(find.textContaining('1,310'), findsOneWidget);
  });

  testWidgets('سعر غير صالح لا يُحفظ', (tester) async {
    await openSettings(tester);
    await tester.tap(find.byKey(const Key('currencyUsd')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('usdRateField')), '0');
    await tester.tap(find.byKey(const Key('usdRateSave')));
    await tester.pumpAndSettle();
    expect(s.currency, 'IQD');
    expect(find.text('اكتب سعراً أكبر من صفر'), findsOneWidget);
  });
}
