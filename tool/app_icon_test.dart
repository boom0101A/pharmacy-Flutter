// مولّد أيقونة التطبيق من شعار شاشة البداية (welcome.html) — يُشغَّل يدوياً:
//
//   flutter test tool/app_icon_test.dart
//
// يكتب ملفات PNG في android/app/src/main/res/mipmap-*:
// - ic_launcher_background / _foreground: الأيقونة التكيّفية (Android 8+)
// - ic_launcher_monochrome: الأيقونات ذات السمة (Android 13+)
// - ic_launcher: الأيقونة الكاملة للأجهزة الأقدم
// ومعاينة tool/app_icon_preview.png.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';

/// كثافات Android: المضاعف لكل مجلد.
const _densities = {
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};

/// الخلفية: لون --bg مع بقع الشفق الثلاث (تيل أعلى اليمين، أزرق يسار،
/// بنفسجي أسفل اليمين) — كما خلف الشعار في شاشة البداية.
void _background(Canvas c, double s) {
  c.drawRect(
    Offset.zero & Size(s, s),
    Paint()..color = const Color(0xFF06101E),
  );
  void glow(Offset center, double radius, Color color) {
    c.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(center, radius, [
          color,
          color.withValues(alpha: 0),
        ]),
    );
  }

  glow(Offset(s * .88, s * .08), s * .62, const Color(0xB30D9488));
  glow(Offset(s * .02, s * .62), s * .55, const Color(0x8C2563EB));
  glow(Offset(s * .92, s * 1.0), s * .55, const Color(0x807C3AED));
}

/// الصليب (svg بإطار 64): عمود + ذراع بتدرّج أبيض→#A5F3FC، ومربع تيل
/// في الوسط، وظل drop-shadow(0 4px 12px rgba(0,0,0,.35)).
void _cross(Canvas c, Rect box, {bool mono = false}) {
  final k = box.width / 64;
  RRect r(double x, double y, double w, double h, double rad) =>
      RRect.fromRectAndRadius(
        Rect.fromLTWH(box.left + x * k, box.top + y * k, w * k, h * k),
        Radius.circular(rad * k),
      );
  final bar = r(24, 8, 16, 48, 6), arm = r(8, 24, 48, 16, 6);
  final shape = Path()
    ..addRRect(bar)
    ..addRRect(arm);
  if (mono) {
    c.drawPath(shape, Paint()..color = Colors.white);
    return;
  }
  // ظل: 58px من الشعار ↔ 64 وحدة، والإزاحة 4 والضبابية 12 (σ=6)
  final px = box.width / 58;
  c.drawPath(
    shape.shift(Offset(0, 4 * px)),
    Paint()
      ..color = const Color(0x59000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * px),
  );
  c.drawPath(
    shape,
    Paint()
      ..shader = ui.Gradient.linear(box.topLeft, box.bottomRight, const [
        Colors.white,
        Color(0xFFA5F3FC),
      ]),
  );
  c.drawRRect(r(27, 27, 10, 10, 3), Paint()..color = const Color(0xFF2DD4BF));
}

/// المقدّمة: بلاطة الشعار الزجاجية (112 بزوايا 36) بالصليب (58).
/// [t] حجم البلاطة، في وسط لوحة بحجم [s].
void _foreground(Canvas c, double s, {double tileFraction = .5}) {
  final t = s * tileFraction;
  final u = t / 112; // بكسل التصميم
  final tile = Rect.fromCenter(
    center: Offset(s / 2, s / 2),
    width: t,
    height: t,
  );
  final shape = RRect.fromRectAndRadius(tile, Radius.circular(36 * u));

  // 0 20px 50px rgba(45,212,191,.3)
  c.drawRRect(
    shape.shift(Offset(0, 20 * u)),
    Paint()
      ..color = const Color(0x4D2DD4BF)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 25 * u),
  );

  c.save();
  c.clipRRect(shape);
  // تعبئة الزجاج: linear-gradient(145deg, teal .35, blue .14 55%, violet .2)
  // فوق لون داكن خفيف — يعطي البلاطة عمقها فوق أي خلفية للمشغّل.
  c.drawRect(tile, Paint()..color = const Color(0x9906101E));
  final a = 145 * math.pi / 180;
  final dir = Offset(math.sin(a), -math.cos(a));
  final half = (dir.dx.abs() + dir.dy.abs()) * t / 2;
  c.drawRect(
    tile,
    Paint()
      ..shader = ui.Gradient.linear(
        tile.center - dir * half,
        tile.center + dir * half,
        const [Color(0x592DD4BF), Color(0x2438BDF8), Color(0x33A78BFA)],
        const [0, .55, 1],
      ),
  );
  // ::before — ضوء النصف العلوي
  c.drawRect(
    Rect.fromLTWH(tile.left, tile.top, t, t / 2),
    Paint()
      ..shader = ui.Gradient.linear(tile.topCenter, tile.center, const [
        Color(0x47FFFFFF),
        Color(0x00FFFFFF),
      ]),
  );
  // لمعة مائلة ساكنة (لقطة من ::after)
  c.save();
  c.translate(tile.left + t * .22, tile.center.dy);
  c.rotate(25 * math.pi / 180);
  final stripe = Rect.fromCenter(
    center: Offset.zero,
    width: t * .28,
    height: t * 2,
  );
  c.drawRect(
    stripe,
    Paint()
      ..shader = ui.Gradient.linear(
        stripe.centerLeft,
        stripe.centerRight,
        const [Color(0x00FFFFFF), Color(0x40FFFFFF), Color(0x00FFFFFF)],
        const [0, .5, 1],
      ),
  );
  c.restore();
  // --sheen: هلال ضوء داخل الحافة العليا
  final outline = Path()..addRRect(shape);
  c.drawPath(
    Path.combine(
      PathOperation.difference,
      outline,
      outline.shift(Offset(0, 1.5 * u)),
    ),
    Paint()..color = const Color(0x38FFFFFF),
  );
  c.restore();

  // الحدّ border-hi
  c.drawRRect(
    shape.deflate(.5 * u),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u
      ..color = const Color(0x47FFFFFF),
  );

  final crossSize = 58 * u;
  _cross(
    c,
    Rect.fromCenter(center: tile.center, width: crossSize, height: crossSize),
  );
}

Future<void> _png(
  String path,
  int size,
  void Function(Canvas c, double s) draw,
) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  draw(canvas, size.toDouble());
  final img = await rec.endRecording().toImage(size, size);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(data!.buffer.asUint8List());
}

/// الأيقونة الكاملة (قبل Android 8): وسط اللوحة التكيّفية (72 من 108) بزوايا مدوّرة.
void _legacy(Canvas c, double s) {
  final full = s * 108 / 72;
  c.clipRRect(
    RRect.fromRectAndRadius(Offset.zero & Size(s, s), Radius.circular(s * .22)),
  );
  c.translate(-(full - s) / 2, -(full - s) / 2);
  _background(c, full);
  _foreground(c, full);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('توليد أيقونة التطبيق', () async {
    for (final e in _densities.entries) {
      final dir = '$_res/mipmap-${e.key}';
      final adaptive = (108 * e.value).round();
      await _png('$dir/ic_launcher_background.png', adaptive, _background);
      await _png('$dir/ic_launcher_foreground.png', adaptive, _foreground);
      await _png(
        '$dir/ic_launcher_monochrome.png',
        adaptive,
        (c, s) => _cross(
          c,
          Rect.fromCenter(
            center: Offset(s / 2, s / 2),
            width: s * .5,
            height: s * .5,
          ),
          mono: true,
        ),
      );
      await _png('$dir/ic_launcher.png', (48 * e.value).round(), _legacy);
    }

    // معاينة: دائري وsquircle ومربّع مدوّر كما تقصّها المشغّلات
    await _png('tool/app_icon_preview.png', 1200, (c, s) {
      c.drawRect(
        Offset.zero & Size(s, s),
        Paint()..color = const Color(0xFFE8EDF3),
      );
      final masks = <Path Function(Rect)>[
        (r) => Path()..addOval(r),
        (r) => Path()
          ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(r.width * .3))),
        (r) => Path()
          ..addRRect(
            RRect.fromRectAndRadius(r, Radius.circular(r.width * .12)),
          ),
      ];
      for (var i = 0; i < 3; i++) {
        final r = Rect.fromLTWH(60 + i * 380.0, 60, 320, 320);
        // المشغّل يعرض 72 من 108 — نرسم اللوحة كاملة ونقصّها
        final full = r.width * 108 / 72;
        c.save();
        c.clipPath(masks[i](r));
        c.translate(
          r.left - (full - r.width) / 2,
          r.top - (full - r.width) / 2,
        );
        _background(c, full);
        _foreground(c, full);
        c.restore();
      }
      // على خلفية داكنة، وبأحجام صغيرة كما في الشاشة الرئيسية للهاتف
      c.drawRect(
        Rect.fromLTWH(0, 440, s, 760),
        Paint()..color = const Color(0xFF111827),
      );
      var x = 80.0;
      for (final size in [192.0, 144.0, 96.0, 64.0]) {
        final r = Rect.fromLTWH(x, 640, size, size);
        final full = size * 108 / 72;
        c.save();
        c.clipPath(Path()..addOval(r));
        c.translate(r.left - (full - size) / 2, r.top - (full - size) / 2);
        _background(c, full);
        _foreground(c, full);
        c.restore();
        x += size + 90;
      }
    });
  });
}
