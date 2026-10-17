import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/screens/pairing_sheet.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';

/// اختبارات واجهة الاقتران بلا أي خادم حقيقي — PharmacyService.instance في
/// بيئة الاختبار بلا Firestore متصل (لم يُستدعَ attach())، فكل استدعاء شبكي
/// يفشل بهدوء أو يُرمى كخطأ نموذجي. هذا يطابق تماماً حالة «بلا اتصال» الحقيقية،
/// فنختبر مسارات الخطأ والتحقق المحلي بثقة كاملة بلا الحاجة لمحاكي Firebase.
class _TestStore extends MedicineStore {
  @override
  Future<void> load() async {}

  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}
}

void main() {
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

  group('showSharePairingSheet — بلا اتصال بـ Firestore', () {
    testWidgets('يعرض رسالة تعذّر التحضير ولا ينهار', (tester) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showSharePairingSheet(context),
                  child: const Text('فتح'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('فتح'));
      await tester.pumpAndSettle();

      expect(
        find.text('تعذّر التحضير — تحقق من الاتصال بالإنترنت.'),
        findsOneWidget,
      );
      expect(find.text('حاول مرة أخرى'), findsOneWidget);
    });

    testWidgets('زر «حاول مرة أخرى» يعيد المحاولة بلا انهيار', (tester) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showSharePairingSheet(context),
                  child: const Text('فتح'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('فتح'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('حاول مرة أخرى'));
      await tester.pumpAndSettle();

      expect(
        find.text('تعذّر التحضير — تحقق من الاتصال بالإنترنت.'),
        findsOneWidget,
      );
    });
  });

  group('showJoinPairingSheet — التحقق المحلي وحالات الخطأ', () {
    testWidgets('رمز أقل من 6 أرقام يُرفض محلياً بلا لمس الشبكة', (
      tester,
    ) async {
      final store = _TestStore();
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showJoinPairingSheet(context, store),
                  child: const Text('فتح'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('فتح'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('pairing_code_field')), '12');
      await tester.tap(find.text('انضمام'));
      await tester.pumpAndSettle();

      expect(find.text('أدخل الرمز المكوّن من 6 أرقام.'), findsOneWidget);
    });

    testWidgets('رمز غير رقمي يُرفض محلياً أيضاً', (tester) async {
      final store = _TestStore();
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showJoinPairingSheet(context, store),
                  child: const Text('فتح'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('فتح'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('pairing_code_field')),
        'ابجده',
      );
      await tester.tap(find.text('انضمام'));
      await tester.pumpAndSettle();

      expect(find.text('أدخل الرمز المكوّن من 6 أرقام.'), findsOneWidget);
    });

    testWidgets('رمز صحيح الصيغة لكن بلا اتصال حقيقي يعرض «الرمز غير صحيح»', (
      tester,
    ) async {
      final store = _TestStore();
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showJoinPairingSheet(context, store),
                  child: const Text('فتح'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('فتح'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('pairing_code_field')),
        '123456',
      );
      await tester.tap(find.text('انضمام'));
      await tester.pumpAndSettle();

      expect(find.text('الرمز غير صحيح.'), findsOneWidget);
    });
  });
}
