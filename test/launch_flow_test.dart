import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/screens/launch_flow.dart';
import 'package:saydaliyati/screens/welcome_view.dart';
import 'package:saydaliyati/services/app_settings.dart';
import 'package:saydaliyati/theme.dart';
import 'package:saydaliyati/widgets/launch_art.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late int joins;
  late bool initDone;
  late bool homeBuiltBeforeInit;

  setUp(() {
    joins = 0;
    initDone = false;
    homeBuiltBeforeInit = false;
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.init();
  });

  Future<void> start(
    WidgetTester tester, {
    required bool seen,
    Future<void> Function()? waitFor,
    bool throws = false,
    bool reduced = false,
  }) async {
    SharedPreferences.setMockInitialValues({'welcome_seen': seen});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          disableAnimations: reduced,
        ),
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: LaunchFlow(
              initialize: () async {
                await AppSettings.instance.init();
                if (waitFor != null) await waitFor();
                if (throws) throw StateError('Firebase');
                initDone = true;
              },
              home: (_) {
                if (!initDone) homeBuiltBeforeInit = true;
                return const Scaffold(body: Text('HOME'));
              },
              onJoin: (_) => joins++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// يمرّر الزمن ثانيةً ثانية حتى يكتمل الذوبان (لا pumpAndSettle: حركات لانهائية).
  Future<void> advance(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  final logo = find.byType(PharmacyLogo);
  final home = find.text('HOME');

  testWidgets('الشعار يبقى حتى تكتمل التهيئة', (tester) async {
    final gate = Completer<void>();
    await start(tester, seen: true, waitFor: () => gate.future);
    await advance(tester, 3000);
    expect(logo, findsOneWidget);
    expect(home, findsNothing);

    gate.complete();
    await advance(tester, 1500);
    expect(home, findsOneWidget);
    expect(logo, findsNothing);
    // الإشعار الذي فتح التطبيق يُقرأ في التهيئة — الرئيسية تُبنى بعدها
    expect(homeBuiltBeforeInit, isFalse);
  });

  testWidgets('حد أدنى 1.5 ثانية حتى لو انتهت التهيئة فوراً', (tester) async {
    await start(tester, seen: true);
    await advance(tester, 1000);
    expect(home, findsNothing);
    expect(logo, findsOneWidget);

    await advance(tester, 2000);
    expect(home, findsOneWidget);
    expect(logo, findsNothing);
  });

  testWidgets('تهيئة ترمي لا تعلّق الشعار', (tester) async {
    await start(tester, seen: true, throws: true);
    await advance(tester, 3000);
    expect(home, findsOneWidget);
  });

  testWidgets('أول مرة ← الشرائح، و«تخطّي» ← الرئيسية ولا تعود', (
    tester,
  ) async {
    await start(tester, seen: false);
    await advance(tester, 3000);
    expect(find.byType(WelcomeView), findsOneWidget);
    expect(home, findsNothing);

    await tester.tap(find.text('تخطّي'));
    await advance(tester, 1000);
    expect(home, findsOneWidget);
    expect(find.byType(WelcomeView), findsNothing);
    expect(find.byType(LaunchBackdrop), findsNothing);
    expect(AppSettings.instance.welcomeSeen, isTrue);
    expect(joins, 0);
  });

  testWidgets('بعد رؤية الشرائح ← الرئيسية مباشرة بلا شرائح', (tester) async {
    await start(tester, seen: true);
    await advance(tester, 3000);
    expect(find.byType(WelcomeView), findsNothing);
    expect(find.byType(LaunchBackdrop), findsNothing);
    expect(home, findsOneWidget);
  });

  testWidgets('«انضمام» ← الرئيسية ثم ورقة الانضمام', (tester) async {
    await start(tester, seen: false);
    await advance(tester, 3000);
    await tester.tap(find.text('لديّ رمز — انضمام إلى مخزون'));
    await advance(tester, 1000);
    expect(home, findsOneWidget);
    expect(joins, 1);
    expect(AppSettings.instance.welcomeSeen, isTrue);
  });

  testWidgets('الحركة المخفّضة: بلا انتظار أدنى', (tester) async {
    await start(tester, seen: true, reduced: true);
    await advance(tester, 200);
    expect(home, findsOneWidget);
    expect(logo, findsNothing);
  });
}
