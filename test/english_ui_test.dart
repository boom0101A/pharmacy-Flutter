import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/l10n/l10n.dart';
import 'package:saydaliyati/screens/welcome_view.dart';
import 'package:saydaliyati/services/app_settings.dart';
import 'package:saydaliyati/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// بالإنجليزية لا يظهر أي حرف عربي في الواجهة — إلا البيانات المزروعة في
/// الاختبار (أسماء أدوية/مجهّزين)، فهي لا تُترجم.
final _arabic = RegExp(r'[؀-ۿ]');

/// كل النصوص المعروضة (Text وRichText) ما عدا ما في [allowed].
List<String> arabicTexts(
  WidgetTester tester, {
  Set<String> allowed = const {},
}) {
  final found = <String>[];
  for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
    final text = w.text.toPlainText();
    if (_arabic.hasMatch(text) && !allowed.any(text.contains)) found.add(text);
  }
  return found;
}

/// تطبيق مصغّر بلغة الإعدادات واتجاهها، كما في main.dart.
Widget englishHost(Widget home) => MaterialApp(
  theme: buildAppTheme(),
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) =>
      Directionality(textDirection: TextDirection.ltr, child: child!),
  home: home,
);

Future<void> frames(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.init();
    await AppSettings.instance.setLanguage('en');
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.init();
  });

  void useSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('الترحيب بالإنجليزية', () {
    testWidgets('بلا عربي', (tester) async {
      useSize(tester);
      await tester.pumpWidget(
        englishHost(Scaffold(body: WelcomeView(onDone: () {}))),
      );
      await frames(tester);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(arabicTexts(tester), isEmpty);
    });

    testWidgets('LTR: السحب لليسار التالي، والتالية تدخل من اليمين', (
      tester,
    ) async {
      useSize(tester);
      await tester.pumpWidget(
        englishHost(Scaffold(body: WelcomeView(onDone: () {}))),
      );
      await frames(tester);
      await tester.drag(find.text('add in a second'), const Offset(-120, 0));
      await tester.pump(const Duration(milliseconds: 60));
      // الشريحة الثانية في منتصف دخولها: إلى يمين موضعها النهائي
      final mid = tester.getCenter(find.text('we do the rest')).dx;
      await frames(tester);
      final end = tester.getCenter(find.text('we do the rest')).dx;
      expect(mid, greaterThan(end));
    });
  });
}
