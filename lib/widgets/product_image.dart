import 'dart:io';

import 'package:flutter/widgets.dart';

/// صورة مادة **كاملة وباتجاهها الحقيقي**: العلبة العمودية تُعرض عمودية،
/// والأفقية أفقية.
///
/// كانت المعاينة صندوقاً أفقياً ثابتاً (180 بكسل) بـ`BoxFit.cover`، فتُقصّ
/// العلبة العمودية من أعلاها وأسفلها ولا يبقى إلا وسطها. هنا يأخذ الصندوق
/// ارتفاعاً من نسبة الصورة نفسها (محصوراً بين [minHeight] و[maxHeight])،
/// والصورة بـ`BoxFit.contain` فلا يُقصّ منها شيء.
class AdaptiveProductImage extends StatefulWidget {
  const AdaptiveProductImage({
    super.key,
    required this.path,
    this.minHeight = 160,
    this.maxHeight = 340,
    @visibleForTesting this.initialRatio,
  });

  final String path;

  /// نسبة معروفة مسبقاً — للاختبار، حيث لا يُفك ملف الصورة فعلياً.
  final double? initialRatio;
  final double minHeight;
  final double maxHeight;

  /// ارتفاع الصندوق لصورة بنسبة [ratio] (العرض ÷ الارتفاع) في عرض [width].
  @visibleForTesting
  static double boxHeight(
    double ratio,
    double width, {
    double minHeight = 160,
    double maxHeight = 340,
  }) => (width / ratio).clamp(minHeight, maxHeight);

  @override
  State<AdaptiveProductImage> createState() => _AdaptiveProductImageState();
}

class _AdaptiveProductImageState extends State<AdaptiveProductImage> {
  /// العرض ÷ الارتفاع — null حتى تُعرف أبعاد الصورة.
  late double? _ratio = widget.initialRatio;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener((info, _) {
    final w = info.image.width, h = info.image.height;
    info.dispose();
    if (mounted && w > 0 && h > 0) setState(() => _ratio = w / h);
  }, onError: (_, _) {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(AdaptiveProductImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _ratio = null;
      _resolve();
    }
  }

  void _resolve() {
    final stream = FileImage(
      File(widget.path),
    ).resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final ratio = _ratio;
        final height = ratio == null
            ? widget.minHeight
            : AdaptiveProductImage.boxHeight(
                ratio,
                c.maxWidth,
                minHeight: widget.minHeight,
                maxHeight: widget.maxHeight,
              );
        return SizedBox(
          height: height,
          width: double.infinity,
          child: Image.file(
            File(widget.path),
            key: const Key('adaptiveProductImage'),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
