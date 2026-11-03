import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/screens/welcome_view.dart';
import 'package:saydaliyati/theme.dart';

/// الحركات اللانهائية (اللمعة والطفو) تمنع pumpAndSettle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late int done;
  late int joined;

  setUp(() {
    done = 0;
    joined = 0;
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: WelcomeView(onDone: () => done++, onJoin: () => joined++),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  /// عنوان الشريحة النشطة (المرئية).
  String activeTitle(WidgetTester tester) {
    for (final t in ['وأضف بثانية', 'والباقي علينا', 'على كل أجهزتك']) {
      final op = tester.widget<AnimatedOpacity>(
        find
            .ancestor(of: find.text(t), matching: find.byType(AnimatedOpacity))
            .first,
      );
      if (op.opacity == 1) return t;
    }
    return '';
  }

  testWidgets('الشريحة الأولى أولاً', (tester) async {
    await open(tester);
    expect(activeTitle(tester), 'وأضف بثانية');
    expect(find.textContaining('امسح الباركود'), findsOneWidget);
    expect(find.text('التالي'), findsOneWidget);
  });

  testWidgets('«التالي» يتقدّم، وفي الأخيرة «ابدأ الآن» ينهي', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('welcomeNext')));
    await settle(tester);
    expect(activeTitle(tester), 'والباقي علينا');

    await tester.tap(find.byKey(const Key('welcomeNext')));
    await settle(tester);
    expect(activeTitle(tester), 'على كل أجهزتك');
    expect(find.text('ابدأ الآن'), findsOneWidget);
    expect(done, 0);

    await tester.tap(find.byKey(const Key('welcomeNext')));
    await settle(tester);
    expect(done, 1);
  });

  testWidgets('«تخطّي» ينهي من أي شريحة', (tester) async {
    await open(tester);
    await tester.tap(find.text('تخطّي'));
    await settle(tester);
    expect(done, 1);
  });

  testWidgets('السحب لليسار التالي، ولليمين السابق (RTL)', (tester) async {
    await open(tester);
    final stage = find.text('وأضف بثانية');
    await tester.drag(stage, const Offset(-120, 0));
    await settle(tester);
    expect(activeTitle(tester), 'والباقي علينا');

    await tester.drag(find.text('والباقي علينا'), const Offset(120, 0));
    await settle(tester);
    expect(activeTitle(tester), 'وأضف بثانية');

    // سحب قصير (≤ 40) لا يحرّك
    await tester.drag(find.text('وأضف بثانية'), const Offset(-30, 0));
    await settle(tester);
    expect(activeTitle(tester), 'وأضف بثانية');
  });

  testWidgets('تقدّم تلقائي كل 5 ثوانٍ ويتوقف عند الأخيرة', (tester) async {
    await open(tester);
    await tester.pump(const Duration(milliseconds: 4300));
    await settle(tester);
    expect(activeTitle(tester), 'والباقي علينا');
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(activeTitle(tester), 'على كل أجهزتك');
    await tester.pump(const Duration(seconds: 10));
    await settle(tester);
    expect(activeTitle(tester), 'على كل أجهزتك');
    expect(done, 0);
  });

  testWidgets('الضغط على النقطة الثالثة', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('welcomeDot2')));
    await settle(tester);
    expect(activeTitle(tester), 'على كل أجهزتك');
  });

  testWidgets('«انضمام» يستدعي onJoin', (tester) async {
    await open(tester);
    await tester.tap(find.text('لديّ رمز — انضمام إلى مخزون'));
    await settle(tester);
    expect(joined, 1);
    expect(done, 0);
  });

  testWidgets('ضغطتان سريعتان تُنهيان مرة واحدة فقط', (tester) async {
    await open(tester);
    await tester.tap(find.text('لديّ رمز — انضمام إلى مخزون'));
    await tester.tap(find.text('لديّ رمز — انضمام إلى مخزون'));
    await tester.tap(find.text('تخطّي'));
    await settle(tester);
    expect(joined, 1);
    expect(done, 0);
  });

  testWidgets('السطر القانوني مصحّح', (tester) async {
    await open(tester);
    expect(find.text('بياناتك خاصة بصيدليتك — لا يراها غيرك'), findsOneWidget);
    expect(find.textContaining('لا تغادر جهازك'), findsNothing);
  });

  testWidgets('شاشة قصيرة: البطل مصغّر بلا فيضان', (tester) async {
    await open(tester, size: const Size(360, 640));
    expect(find.byKey(const Key('heroShort')), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('شاشة عادية: البطل بحجمه الكامل', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('heroShort')), findsNothing);
  });
}
