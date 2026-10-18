import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/screens/settings_sheet.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// اختبار ربط أزرار قسم «مشاركة المخزون بين الأجهزة» الجديد في شاشة الإعدادات
/// بالشاشتين الصحيحتين — بلا لمس Firestore حقيقي.
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

  /// شاشة الإعدادات طويلة (نسخ احتياطي + قاموس + إشعارات + مشاركة)، وبارتفاع
  /// افتراضي يبقى قسم المشاركة الجديد خارج حدود الشاشة قبل التمرير فلا يقدر
  /// tester.tap على الوصول إليه فعلياً.
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

  group('قسم مشاركة المخزون في الإعدادات', () {
    testWidgets('يظهر بزرَّيه', (tester) async {
      await openSettings(tester);

      expect(find.text('🔗 مشاركة المخزون بين الأجهزة'), findsOneWidget);
      expect(find.text('مشاركة مع جهاز آخر'), findsOneWidget);
      expect(find.text('الانضمام إلى مخزون'), findsOneWidget);
    });

    testWidgets('«مشاركة مع جهاز آخر» يفتح شاشة المشاركة', (tester) async {
      useTallSurface(tester);
      await openSettings(tester);

      await tester.tap(find.text('مشاركة مع جهاز آخر'));
      await tester.pumpAndSettle();

      expect(find.text('🔗 مشاركة المخزون مع جهاز آخر'), findsOneWidget);
    });

    testWidgets('«الانضمام إلى مخزون» يفتح شاشة الانضمام', (tester) async {
      useTallSurface(tester);
      await openSettings(tester);

      await tester.tap(find.text('الانضمام إلى مخزون'));
      await tester.pumpAndSettle();

      expect(find.text('🔗 الانضمام إلى مخزون موجود'), findsOneWidget);
      expect(find.byKey(const Key('pairing_code_field')), findsOneWidget);
    });

    testWidgets('«مراجعة التكرارات» يفتح شاشة التكرارات', (tester) async {
      useTallSurface(tester);
      await openSettings(tester);

      await tester.tap(find.text('مراجعة التكرارات'));
      await tester.pumpAndSettle();

      expect(find.text('🔍 مراجعة التكرارات'), findsOneWidget);
    });
  });
}
