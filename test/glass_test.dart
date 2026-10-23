import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/theme.dart';
import 'package:saydaliyati/widgets/glass.dart';
import 'package:saydaliyati/widgets/smooth_route.dart';

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

  // Impeller بلا ذاكرة نقطية: أي ضبابية تُعاد في كل إطار — الخلفية تُرسم
  // بتدرّجات فقط فلا تكلّف شيئاً أثناء التمرير والانتقالات.
  testWidgets('الخلفية بلا أي مرشّح ضبابية', (tester) async {
    await tester.pumpWidget(host(const AuroraBackground()));
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
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

  // الضبابية الحقيقية تتوقف أثناء حركة الانتقال (أثقل مصدر للتقطّع على
  // الهاتف) وتعود فور استقرار الشاشة.
  testWidgets('لا ضبابية أثناء انتقال الشاشة، وتعود بعد استقرارها', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold(body: Text('home'));
          },
        ),
      ),
    );
    Navigator.of(ctx).push(
      SmoothPageRoute<void>(
        builder: (_) => const Scaffold(
          body: GlassSurface(blur: true, child: Text('glass')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('glass'), findsOneWidget);
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isFalse,
    );

    await tester.pumpAndSettle();
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isTrue,
    );
  });

  // إيقاف الضبابية لا يغيّر شكل الشجرة: ما داخل السطح يحتفظ بحالته عبر
  // الانتقالات (كان يُعاد بناؤه فتضيع الحقول ومتابعة العمليات).
  testWidgets('حالة ما داخل السطح تبقى عبر انتقال الشاشة', (tester) async {
    late BuildContext ctx;
    final field = TextEditingController();
    addTearDown(field.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (c) {
            ctx = c;
            return Scaffold(
              body: GlassSurface(
                blur: true,
                child: _Counter(key: const Key('counter')),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('counter')));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    Navigator.of(ctx).push(
      SmoothPageRoute<void>(builder: (_) => const Scaffold(body: Text('x'))),
    );
    await tester.pumpAndSettle();
    Navigator.of(ctx).pop();
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget, reason: 'الحالة لم تُفقد');
  });

  testWidgets('حوار زجاجي: يظهر ويُغلق بالضغط خارجه ويُعيد قيمته', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    final outside = showGlassDialog<bool>(
      context: ctx,
      builder: (_) => const AlertDialog(content: Text('سؤال')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(await outside, isNull);

    final answered = showGlassDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        content: TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('نعم'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('نعم'));
    await tester.pumpAndSettle();
    expect(await answered, isTrue);
  });
}

/// عدّاد بسيط بحالة داخلية — لكشف أي إعادة بناء من الصفر.
class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _n = 0;

  @override
  Widget build(BuildContext context) =>
      GestureDetector(onTap: () => setState(() => _n++), child: Text('$_n'));
}
