import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// قصّ صورة الدواء/المستلزم حول العلبة تلقائياً.
///
/// الاكتشاف على الهاتف نفسه (ML Kit — بلا إنترنت ولا كلفة ولا يمسّ حصة
/// Gemini): يعيد صندوق «الجسم الأبرز» في الصورة، أي العلبة. القرار الأخير
/// للمستخدم في شاشة التأكيد — الاكتشاف يخطئ أحياناً (علبة بيضاء على طاولة
/// بيضاء)، فهو اقتراح لا حكم.
class ProductCropper {
  const ProductCropper();

  /// صندوق الجسم الأبرز بإحداثيات الصورة كما تُعرض (بعد تصحيح الدوران)،
  /// أو null إن لم يُكتشف شيء أو تعذّر الاكتشاف. لا يرمي.
  Future<ui.Rect?> detectProduct(File file) async {
    final detector = ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: false,
        multipleObjects: false,
      ),
    );
    try {
      final objects = await detector.processImage(
        InputImage.fromFilePath(file.path),
      );
      if (objects.isEmpty) return null;
      // الأكبر مساحةً هو العلبة غالباً
      objects.sort(
        (a, b) => (b.boundingBox.width * b.boundingBox.height).compareTo(
          a.boundingBox.width * a.boundingBox.height,
        ),
      );
      return objects.first.boundingBox;
    } catch (e) {
      debugPrint('تعذّر اكتشاف العلبة في الصورة: $e');
      return null;
    } finally {
      await detector.close();
    }
  }

  /// أبعاد الصورة كما تُعرض.
  Future<ui.Size> imageSize(File file) async {
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    final frame = await codec.getNextFrame();
    final size = ui.Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
    frame.image.dispose();
    codec.dispose();
    return size;
  }

  /// إطار القص المقترح من صندوق الاكتشاف — دالة صِرفة.
  ///
  /// - هامش ~6% حول العلبة حتى لا تُقصّ حوافها، محصور داخل الصورة.
  /// - لا اكتشاف، أو صندوق يغطي ≥92% من الصورة (فشل فعلي في التمييز) ←
  ///   إطار وسطي بنسبة 85%.
  /// - صندوق صغير جداً (ضجيج) يُوسَّع إلى ربع أصغر بُعد على الأقل.
  static ui.Rect suggestCrop(ui.Rect? box, ui.Size image) {
    final full = ui.Offset.zero & image;
    ui.Rect fallback() => ui.Rect.fromCenter(
      center: full.center,
      width: image.width * .85,
      height: image.height * .85,
    );
    if (box == null || box.isEmpty) return fallback();
    final covered = (box.width * box.height) / (image.width * image.height);
    if (covered >= .92) return fallback();

    final minSide = math.min(image.width, image.height) / 4;
    final w = math.max(box.width * 1.12, minSide);
    final h = math.max(box.height * 1.12, minSide);
    final grown = ui.Rect.fromCenter(center: box.center, width: w, height: h);
    return grown.intersect(full);
  }

  /// يقصّ [file] إلى [rect] (إحداثيات الصورة) ويحفظ JPEG في ملف مؤقت.
  Future<File> crop(File file, ui.Rect rect) async {
    final bytes = await file.readAsBytes();
    final out = await compute(_cropBytes, (
      bytes,
      rect.left.round(),
      rect.top.round(),
      rect.width.round(),
      rect.height.round(),
    ));
    final dir = await getTemporaryDirectory();
    final target = File(
      p.join(dir.path, 'crop_${DateTime.now().microsecondsSinceEpoch}.jpg'),
    );
    await target.writeAsBytes(out);
    return target;
  }

  /// يعمل في عزلة منفصلة — دالة عليا. يصحّح دوران EXIF أولاً حتى تطابق
  /// إحداثيات القص ما رآه المستخدم.
  @visibleForTesting
  static Uint8List cropBytes((Uint8List, int, int, int, int) a) =>
      _cropBytes(a);

  static Uint8List _cropBytes((Uint8List, int, int, int, int) a) {
    final (bytes, x, y, w, h) = a;
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final upright = img.bakeOrientation(decoded);
    final cx = x.clamp(0, upright.width - 1);
    final cy = y.clamp(0, upright.height - 1);
    final cropped = img.copyCrop(
      upright,
      x: cx,
      y: cy,
      width: w.clamp(1, upright.width - cx),
      height: h.clamp(1, upright.height - cy),
    );
    return img.encodeJpg(cropped, quality: 88);
  }
}
