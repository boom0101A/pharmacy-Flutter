import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/widgets/product_image.dart';

void main() {
  group('boxHeight — الارتفاع من اتجاه الصورة', () {
    test('عمودية ← أطول (حتى الحد الأقصى)', () {
      expect(AdaptiveProductImage.boxHeight(1 / 3, 300), 340);
      expect(AdaptiveProductImage.boxHeight(0.75, 240), 320);
    });
    test('أفقية ← أقصر (حتى الحد الأدنى)', () {
      expect(AdaptiveProductImage.boxHeight(3, 360), 160);
      expect(AdaptiveProductImage.boxHeight(1.5, 360), 240);
    });
  });

  Future<Size> shown(WidgetTester tester, double ratio) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: AdaptiveProductImage(path: 'none.jpg', initialRatio: ratio),
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.getSize(find.byKey(const Key('adaptiveProductImage')));
  }

  testWidgets('علبة عمودية: صندوق طويل والصورة كاملة (contain)', (
    tester,
  ) async {
    expect((await shown(tester, 1 / 3)).height, 340);
    final image = tester.widget<Image>(
      find.byKey(const Key('adaptiveProductImage')),
    );
    expect(image.fit, BoxFit.contain);
  });

  testWidgets('علبة أفقية: صندوق أقصر', (tester) async {
    expect((await shown(tester, 2)).height, 180);
  });
}
