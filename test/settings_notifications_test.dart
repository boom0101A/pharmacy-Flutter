import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/screens/settings_sheet.dart';
import 'package:saydaliyati/services/app_settings.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// اختبار مفتاح تفعيل تنبيهات المخزون في شاشة الإعدادات.
///
/// `AppSettings.instance` مفرد عام يعيش طوال عمر عملية الاختبار — نعيده إلى
/// حالته الافتراضية بعد كل اختبار حتى لا يتسرّب تغيير من اختبار إلى آخر.
class _TestStore extends MedicineStore {
  @override
  Future<void> load() async {}

  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    // إعادة الحالة الافتراضية — المفرد العام يبقى حياً بين الاختبارات
    await AppSettings.instance.setStockNotificationsEnabled(true);
  });

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

  Future<void> openSettings(WidgetTester tester) async {
    final store = _TestStore();
    await tester.pumpWidget(
      host(
        Builder(
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

  group('مفتاح تنبيهات المخزون في الإعدادات', () {
    testWidgets('يظهر ومفعَّل افتراضياً', (tester) async {
      await openSettings(tester);

      expect(find.text('تنبيهات الصلاحية والمخزون'), findsOneWidget);
      final tile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'تنبيهات الصلاحية والمخزون'),
      );
      expect(tile.value, isTrue);
    });

    testWidgets('الضغط عليه يعطّله فعلياً في AppSettings', (tester) async {
      await openSettings(tester);
      expect(AppSettings.instance.stockNotificationsEnabled, isTrue);

      await tester.tap(
        find.widgetWithText(SwitchListTile, 'تنبيهات الصلاحية والمخزون'),
      );
      await tester.pumpAndSettle();

      expect(AppSettings.instance.stockNotificationsEnabled, isFalse);
      final tile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'تنبيهات الصلاحية والمخزون'),
      );
      expect(tile.value, isFalse);
    });

    testWidgets('منفصل عن مفتاح المساهمة في القاموس المشترك', (tester) async {
      await openSettings(tester);

      await tester.tap(
        find.widgetWithText(SwitchListTile, 'تنبيهات الصلاحية والمخزون'),
      );
      await tester.pumpAndSettle();

      // تعطيل التنبيهات لا يمسّ مفتاح المساهمة الآخر
      expect(AppSettings.instance.contributeToRegistry, isTrue);
      final registryTile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'المساهمة في القاموس المشترك'),
      );
      expect(registryTile.value, isTrue);
    });
  });
}
