import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/screens/settings_sheet.dart';
import 'package:saydaliyati/screens/welcome_view.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestStore extends MedicineStore {
  @override
  Future<void> load() async {}

  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}
}

Future<void> _frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('«عرض شاشة الترحيب» يفتح الشرائح، و«تخطّي» يعود', (tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = _TestStore();
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
        builder: (context, inner) =>
            Directionality(textDirection: TextDirection.rtl, child: inner!),
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

    await tester.ensureVisible(find.byKey(const Key('showWelcome')));
    await tester.tap(find.byKey(const Key('showWelcome')));
    await _frames(tester, 10);
    expect(find.byType(WelcomeView), findsOneWidget);

    await tester.tap(find.text('تخطّي'));
    await _frames(tester, 10);
    expect(find.byType(WelcomeView), findsNothing);
    expect(find.text('فتح'), findsOneWidget);
  });
}
