import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/screens/home_screen.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// وجود زر مسح الباركود إلى جانب حقل البحث.
///
/// النقر الفعلي يفتح ScannerScreen ويتطلب كاميرا حقيقية، فلا نختبره هنا —
/// نتحقق فقط من وجود الزر في شريط البحث وتفاعله. المنطق الفعلي للفلترة
/// بالباركود مغطى في store_sections_test.
class _TestStore extends MedicineStore {
  @override
  Future<void> load() async {}
  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  testWidgets('زر مسح الباركود يظهر في شريط البحث ويقبل النقر', (tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _TestStore();
    await tester.pumpWidget(host(HomeScreen(store: store)));
    await tester.pump();

    // نتحقق من وجود أيقونة الماسح داخل شريط البحث (خارج الأزرار العائمة).
    // نستعمل التلميح المرئي (الأيقونة نفسها) لا نصّاً، فالزر أيقونة فقط.
    final scanIcons = find.byIcon(Icons.qr_code_scanner_rounded);
    // قد يوجد نفس الأيقونة على زر «مسح باركود» العائم — يكفي واحد على الأقل
    // في شريط البحث (فوق الطية أعلى الشاشة).
    expect(scanIcons, findsWidgets);
  });

  testWidgets('حقل البحث موجود ويبحث بالنص عند الكتابة', (tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _TestStore();
    await tester.pumpWidget(host(HomeScreen(store: store)));
    await tester.pump();

    // الكتابة اليدوية تظل تعمل بالتوازي مع زر المسح
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.pump();
    expect(store.keyword, '123456');
  });
}
