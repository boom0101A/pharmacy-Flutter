import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/theme.dart';
import 'package:saydaliyati/widgets/medicine_card.dart';
import 'package:saydaliyati/widgets/smooth_route.dart';

Medicine _item({
  ItemType type = ItemType.medicine,
  String? imagePath,
  int quantity = 3,
  double price = 100,
  String? category,
}) => Medicine(
  id: 'x1',
  barcode: '123',
  name: 'Panadol',
  price: price,
  quantity: quantity,
  imagePath: imagePath,
  type: type,
  category: category,
  createdAt: 0,
  updatedAt: 0,
);

Widget _host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  theme: buildAppTheme(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: SizedBox(width: 200, height: 340, child: child)),
    ),
  ),
);

MedicineCard _card(Medicine m, {bool animate = true}) => MedicineCard(
  medicine: m,
  animate: animate,
  onEdit: () {},
  onDelete: () {},
  onOpen: () {},
);

void main() {
  group('حركة دخول البطاقة', () {
    testWidgets('animate=false لا يلفّ البطاقة بأي حركة', (tester) async {
      await tester.pumpWidget(_host(_card(_item(), animate: false)));
      await tester.pump();

      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
      expect(find.text('Panadol'), findsOneWidget);
    });

    testWidgets('animate=true يشغّل الحركة ثم تستقر', (tester) async {
      await tester.pumpWidget(_host(_card(_item())));
      await tester.pump();

      expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 50));
      final mid = tester.widget<Opacity>(find.byType(Opacity).first);
      expect(mid.opacity, lessThan(1));

      await tester.pumpAndSettle();
      final done = tester.widget<Opacity>(find.byType(Opacity).first);
      expect(done.opacity, 1);
    });

    testWidgets('إطفاء الحركة في النظام يُحترم', (tester) async {
      await tester.pumpWidget(_host(_card(_item()), disableAnimations: true));
      await tester.pump();

      // لا حركة إطلاقاً رغم animate=true
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
      expect(find.text('Panadol'), findsOneWidget);
    });
  });

  group('أيقونة النوع', () {
    testWidgets('الدواء 💊 والمستلزم 🩹', (tester) async {
      await tester.pumpWidget(_host(_card(_item(), animate: false)));
      await tester.pumpAndSettle();
      expect(find.text('💊'), findsOneWidget);

      await tester.pumpWidget(
        _host(_card(_item(type: ItemType.supply), animate: false)),
      );
      await tester.pumpAndSettle();
      expect(find.text('🩹'), findsOneWidget);
      expect(find.text('💊'), findsNothing);
    });
  });

  group('حالات المخزون', () {
    testWidgets('نفاد المخزون يظهر بكلمة «نفذ»', (tester) async {
      await tester.pumpWidget(_host(_card(_item(quantity: 0), animate: false)));
      await tester.pumpAndSettle();
      expect(find.text('نفذ'), findsOneWidget);
    });

    testWidgets('المادة بلا باركود تُعلَّم', (tester) async {
      final m = Medicine(
        id: 's1',
        barcode: '',
        name: 'شاش',
        price: 500,
        quantity: 2,
        type: ItemType.supply,
        createdAt: 0,
        updatedAt: 0,
      );
      await tester.pumpWidget(_host(_card(m, animate: false)));
      await tester.pumpAndSettle();
      expect(find.text('بدون باركود'), findsOneWidget);
    });
  });

  group('انتقال الشاشات', () {
    // من أطفأ الحركة في إعدادات إمكانية الوصول: تلاشٍ فقط بلا انزلاق ولا تكبير
    testWidgets('«تقليل الحركة» ← تلاشٍ فقط', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Builder(
              builder: (c) {
                ctx = c;
                return const Scaffold(body: Text('home'));
              },
            ),
          ),
        ),
      );
      Navigator.of(ctx).push(
        SmoothPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('next')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final next = find.text('next');
      expect(
        find.ancestor(of: next, matching: find.byType(SlideTransition)),
        findsNothing,
      );
      expect(
        find.ancestor(of: next, matching: find.byType(ScaleTransition)),
        findsNothing,
      );
      expect(
        find.ancestor(of: next, matching: find.byType(FadeTransition)),
        findsWidgets,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('SmoothPageRoute ينتقل ويعود بقيمته', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    SmoothPageRoute<String>(
                      builder: (_) => const Scaffold(
                        body: Center(child: Text('الشاشة الثانية')),
                      ),
                    ),
                  ),
                  child: const Text('افتح'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('افتح'));
      await tester.pump();

      // أثناء الانتقال: الشاشة الجديدة موجودة لكن لم تكتمل شفافيتها
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('الشاشة الثانية'), findsOneWidget);
      final fades = tester
          .widgetList<FadeTransition>(find.byType(FadeTransition))
          .toList();
      expect(fades.any((f) => f.opacity.value < 1), isTrue);

      await tester.pumpAndSettle();
      expect(find.text('الشاشة الثانية'), findsOneWidget);
      expect(find.text('افتح'), findsNothing);
    });

    testWidgets('مدة الانتقال قصيرة عمداً', (tester) async {
      final route = SmoothPageRoute(builder: (_) => const SizedBox());
      expect(route.transitionDuration.inMilliseconds, lessThanOrEqualTo(300));
      expect(route.reverseTransitionDuration.inMilliseconds, lessThan(300));
    });
  });

  group('خانة الكمية: «نفذ» مقابل «ناقصة»', () {
    testWidgets('صفر بسعر ← نفذ', (tester) async {
      await tester.pumpWidget(_host(_card(_item(quantity: 0), animate: false)));
      await tester.pumpAndSettle();
      expect(find.text('نفذ'), findsOneWidget);
    });

    testWidgets('صفر بلا سعر ← 📝 ناقصة', (tester) async {
      await tester.pumpWidget(
        _host(_card(_item(quantity: 0, price: 0), animate: false)),
      );
      await tester.pumpAndSettle();
      expect(find.text('📝 ناقصة'), findsOneWidget);
      expect(find.text('نفذ'), findsNothing);
    });
  });

  group('شارة نوع المادة على البطاقة', () {
    testWidgets('تظهر للدواء الذي له نوع', (tester) async {
      await tester.pumpWidget(
        _host(
          _card(
            _item(type: ItemType.medicine, category: 'Tablet'),
            animate: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Tablet'), findsOneWidget);
    });

    testWidgets('لا تظهر للدواء بلا نوع', (tester) async {
      await tester.pumpWidget(
        _host(_card(_item(type: ItemType.medicine), animate: false)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('🧪'), findsNothing);
    });

    testWidgets('لا تظهر لمستلزم يحمل قيمة category قديمة', (tester) async {
      await tester.pumpWidget(
        _host(
          _card(
            _item(type: ItemType.supply, category: 'Cream'),
            animate: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Cream'), findsNothing);
    });

    testWidgets('الشركة تظهر للقسمين بجانب النوع', (tester) async {
      await tester.pumpWidget(
        _host(
          _card(
            _item(
              type: ItemType.medicine,
              category: 'Tablet',
            ).copyWith(company: 'Juman'),
            animate: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('🧪 Tablet · 🏭 Juman'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          _card(
            _item(type: ItemType.supply).copyWith(company: 'Juman'),
            animate: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('🏭 Juman'), findsOneWidget);
    });
  });
}
