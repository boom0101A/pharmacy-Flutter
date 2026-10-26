import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:saydaliyati/screens/crop_screen.dart';
import 'package:saydaliyati/services/product_cropper.dart';

class _FakeCropper extends ProductCropper {
  _FakeCropper(this.box);
  final Rect? box;
  Rect? croppedTo;
  final File output = File('cropped.jpg');

  @override
  Future<Size> imageSize(File file) async => const Size(1000, 800);

  @override
  Future<Rect?> detectProduct(File file) async => box;

  @override
  Future<File> crop(File file, Rect rect) async {
    croppedTo = rect;
    return output;
  }
}

class _BrokenCropper extends _FakeCropper {
  _BrokenCropper() : super(null);

  @override
  Future<Size> imageSize(File file) async => throw Exception('تالفة');
}

void main() {
  const image = Size(1000, 800);

  group('suggestCrop', () {
    test('يضيف هامشاً حول العلبة', () {
      final r = ProductCropper.suggestCrop(
        const Rect.fromLTWH(400, 300, 200, 200),
        image,
      );
      expect(r.width, closeTo(224, .01));
      expect(r.center, const Offset(500, 400));
    });

    test('يبقى داخل الصورة', () {
      final r = ProductCropper.suggestCrop(
        const Rect.fromLTWH(0, 0, 500, 500),
        image,
      );
      expect(r.left, 0);
      expect(r.top, 0);
      expect((Offset.zero & image).intersect(r), r);
    });

    test('لا اكتشاف ← إطار وسطي 85%', () {
      final r = ProductCropper.suggestCrop(null, image);
      expect(r.width, closeTo(850, .01));
      expect(r.height, closeTo(680, .01));
      expect(r.center, const Offset(500, 400));
    });

    test('صندوق يغطي الصورة كلها ← 85%', () {
      final r = ProductCropper.suggestCrop(Offset.zero & image, image);
      expect(r.width, closeTo(850, .01));
    });

    test('صندوق صغير جداً يُوسَّع لحد أدنى', () {
      final r = ProductCropper.suggestCrop(
        const Rect.fromLTWH(500, 400, 10, 10),
        image,
      );
      expect(r.width, closeTo(200, .01));
      expect(r.height, closeTo(200, .01));
    });
  });

  test('cropBytes يقصّ بالأبعاد المطلوبة', () {
    final src = img.encodeJpg(img.Image(width: 100, height: 80));
    final out = img.decodeImage(
      ProductCropper.cropBytes((src, 10, 20, 50, 30)),
    )!;
    expect(out.width, 50);
    expect(out.height, 30);
  });

  Future<Object?> openCrop(WidgetTester tester, _FakeCropper cropper) async {
    Object? result = 'pending';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      CropScreen(file: File('x.jpg'), cropper: cropper),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('تم يقصّ بالإطار المقترح', (tester) async {
    final cropper = _FakeCropper(const Rect.fromLTWH(400, 300, 200, 200));
    await openCrop(tester, cropper);
    await tester.tap(find.byKey(const Key('cropDone')));
    await tester.pumpAndSettle();
    expect(
      cropper.croppedTo,
      ProductCropper.suggestCrop(cropper.box, const Size(1000, 800)),
    );
  });

  testWidgets('سحب زاوية يغيّر الإطار، وإعادة الضبط تعيده', (tester) async {
    final cropper = _FakeCropper(const Rect.fromLTWH(400, 300, 200, 200));
    final suggested = ProductCropper.suggestCrop(
      cropper.box,
      const Size(1000, 800),
    );
    await openCrop(tester, cropper);
    await tester.drag(
      find.byKey(const Key('cropHandle0')),
      const Offset(-40, -40),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('cropDone')));
    await tester.pumpAndSettle();
    expect(cropper.croppedTo!.left, lessThan(suggested.left));

    await openCrop(tester, cropper);
    await tester.drag(
      find.byKey(const Key('cropHandle2')),
      const Offset(30, 30),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('cropReset')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cropDone')));
    await tester.pumpAndSettle();
    expect(cropper.croppedTo, suggested);
  });

  testWidgets('صورة لا تُفكّ: الشاشة تُغلق وتعيد الأصلية', (tester) async {
    final result = await openCrop(tester, _BrokenCropper());
    expect(find.text('open'), findsOneWidget);
    expect(result, isA<File>());
  });

  testWidgets('بلا قص يعيد الأصلية دون قص', (tester) async {
    final cropper = _FakeCropper(null);
    await openCrop(tester, cropper);
    await tester.tap(find.byKey(const Key('cropSkip')));
    await tester.pumpAndSettle();
    expect(cropper.croppedTo, isNull);
    expect(find.text('open'), findsOneWidget);
  });
}
