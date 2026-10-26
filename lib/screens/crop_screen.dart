import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/product_cropper.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// شاشة تأكيد القص: الإطار يبدأ حول العلبة المكتشفة تلقائياً، ويستطيع
/// المستخدم سحب زواياه قبل «تم». تعيد الملف النهائي (مقصوصاً أو الأصلي عند
/// «بلا قص»)، أو null عند الرجوع — فتبقى الصورة السابقة كما هي.
class CropScreen extends StatefulWidget {
  const CropScreen({
    super.key,
    required this.file,
    this.cropper = const ProductCropper(),
  });

  final File file;
  final ProductCropper cropper;

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  Size? _image;
  Rect? _suggested;

  /// الإطار الحالي بإحداثيات الصورة.
  Rect? _rect;
  bool _busy = false;

  static const _handle = 28.0;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final size = await widget.cropper.imageSize(widget.file);
    final box = await widget.cropper.detectProduct(widget.file);
    if (!mounted) return;
    final s = ProductCropper.suggestCrop(box, size);
    setState(() {
      _image = size;
      _suggested = s;
      _rect = s;
    });
  }

  Future<void> _done() async {
    final rect = _rect;
    if (rect == null || _busy) return;
    setState(() => _busy = true);
    try {
      final out = await widget.cropper.crop(widget.file, rect);
      if (mounted) Navigator.of(context).pop(out);
    } catch (e) {
      debugPrint('تعذّر قص الصورة: $e');
      // القص فشل؟ الأصلية أفضل من لا شيء
      if (mounted) Navigator.of(context).pop(widget.file);
    }
  }

  /// يحرّك زاوية [corner] (0 أعلى-يسار، 1 أعلى-يمين، 2 أسفل-يمين،
  /// 3 أسفل-يسار) بمقدار [d] بإحداثيات الصورة.
  void _drag(int corner, Offset d) {
    final r = _rect!, img = _image!;
    final minSide = math.min(img.width, img.height) / 10;
    var l = r.left, t = r.top, rt = r.right, b = r.bottom;
    if (corner == 0 || corner == 3) {
      l = (l + d.dx).clamp(0.0, rt - minSide);
    } else {
      rt = (rt + d.dx).clamp(l + minSide, img.width);
    }
    if (corner == 0 || corner == 1) {
      t = (t + d.dy).clamp(0.0, b - minSide);
    } else {
      b = (b + d.dy).clamp(t + minSide, img.height);
    }
    setState(() => _rect = Rect.fromLTRB(l, t, rt, b));
  }

  @override
  Widget build(BuildContext context) {
    final ready = _rect != null;
    return Scaffold(
      appBar: const GlassAppBar(title: Text('قصّ الصورة')),
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground()),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ready
                        ? _editor()
                        : const Center(child: CircularProgressIndicator()),
                  ),
                ),
                _actions(ready),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editor() {
    return LayoutBuilder(
      builder: (context, c) {
        final img = _image!;
        final scale = math.min(
          c.maxWidth / img.width,
          c.maxHeight / img.height,
        );
        final w = img.width * scale, h = img.height * scale;
        final r = _rect!;
        final view = Rect.fromLTRB(
          r.left * scale,
          r.top * scale,
          r.right * scale,
          r.bottom * scale,
        );
        final corners = [
          view.topLeft,
          view.topRight,
          view.bottomRight,
          view.bottomLeft,
        ];
        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Image.file(
                      widget.file,
                      fit: BoxFit.fill,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: AppColors.glass),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      key: const Key('cropFrame'),
                      painter: _FramePainter(view),
                    ),
                  ),
                  for (var i = 0; i < 4; i++)
                    Positioned(
                      left: corners[i].dx - _handle / 2,
                      top: corners[i].dy - _handle / 2,
                      child: GestureDetector(
                        key: Key('cropHandle$i'),
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (e) => _drag(i, e.delta / scale),
                        child: Container(
                          width: _handle,
                          height: _handle,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _actions(bool ready) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: GradientButton(
              key: const Key('cropDone'),
              onPressed: ready && !_busy ? _done : null,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('تم'),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: const Key('cropReset'),
            onPressed: ready && !_busy
                ? () => setState(() => _rect = _suggested)
                : null,
            child: const Text('إعادة الضبط'),
          ),
          TextButton(
            key: const Key('cropSkip'),
            onPressed: _busy
                ? null
                : () => Navigator.of(context).pop(widget.file),
            child: const Text('بلا قص'),
          ),
        ],
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.frame);

  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRect(frame),
    );
    canvas.drawPath(outside, Paint()..color = const Color(0x99000000));
    canvas.drawRect(
      frame,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.frame != frame;
}
