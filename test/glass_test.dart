import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/theme.dart';
import 'package:saydaliyati/widgets/glass.dart';

/// مكوّنات «Liquid Glass». أهم ما تحميه: الضبابية الحقيقية (`BackdropFilter`)
/// للأسطح الثابتة فقط — على كل بطاقة في قائمة من ألف مادة يتقطّع التمرير.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('سطح زجاجي بلا blur لا يحوي BackdropFilter', (tester) async {
    await tester.pumpWidget(host(const GlassSurface(child: Text('x'))));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('x'), findsOneWidget);
  });

  testWidgets('سطح ثابت بـ blur يحوي BackdropFilter واحداً', (tester) async {
    await tester.pumpWidget(
      host(const GlassSurface(blur: true, child: Text('x'))),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  // pumpAndSettle لا ينتهي أبداً مع حركة مستمرة (يرمي بعد المهلة) — نجاحه
  // دليل أن الخلفية لا تُعيد الرسم بلا توقف.
  testWidgets('الخلفية ثابتة: لا حركة مستمرة', (tester) async {
    await tester.pumpWidget(host(const AuroraBackground()));
    await tester.pumpAndSettle();
    expect(find.byType(AuroraBackground), findsOneWidget);
    expect(find.byType(AnimatedWidget), findsNothing);
  });

  testWidgets('زر التدرّج يستجيب للضغط ويتعطّل بلا onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GradientButton(onPressed: () => taps++, child: const Text('حفظ')),
            const GradientButton(onPressed: null, child: Text('معطّل')),
          ],
        ),
      ),
    );
    await tester.tap(find.text('حفظ'));
    await tester.tap(find.text('معطّل'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
