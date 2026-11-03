import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';
import 'smooth_route.dart';

/// العناصر المرسومة لشاشتي البداية والترحيب — من ملف التصميم `welcome.html`
/// بقيمه حرفياً (الأحجام، الألوان، المدد، المنحنيات).
///
/// **الضبابية هنا حقيقية في كل شيء** (قرار المستخدم): الشفق `blur(60)`،
/// والزجاج `blur(22) saturate(180%)`، ولوحة الأزرار `blur(26) saturate(200%)`.
/// الشاشتان تظهران ثوانيَ قليلة ولا تمرير فيهما، بخلاف بقية التطبيق حيث
/// أُزيلت ضبابية الشفق لأنها كانت تُقطّع التمرير.

// ───────────────────────── الرموز ─────────────────────────

/// `--grad`: linear-gradient(135deg, #2DD4BF, #38BDF8) — باتجاه CSS نفسه
/// (من أعلى اليسار)، لا معكوساً كبقية التطبيق.
LinearGradient cssGradient(
  double degrees,
  List<Color> colors, {
  List<double>? stops,
  double aspect = 1,
}) {
  // خط التدرّج في CSS يمرّ بالزاويتين البعيدتين: طوله |w·sinθ| + |h·cosθ|
  final r = degrees * math.pi / 180;
  final dx = math.sin(r), dy = -math.cos(r);
  final half = (aspect * dx.abs() + dy.abs()) / 2;
  final end = Alignment(dx * half / (aspect / 2), dy * half / .5);
  return LinearGradient(begin: -end, end: end, colors: colors, stops: stops);
}

LinearGradient brandGradient({double aspect = 1}) => cssGradient(135, const [
  AppColors.primary,
  AppColors.primary2,
], aspect: aspect);

/// وزن Cairo — الخط متغيّر، فيُمرَّر المحور صراحةً مع `fontWeight`.
TextStyle cairo(double size, int weight, {Color? color, double? height}) =>
    TextStyle(
      fontFamily: 'Cairo',
      fontSize: size,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [ui.FontVariation.weight(weight.toDouble())],
      color: color,
      height: height,
    );

/// `saturate(s)` في CSS كمصفوفة ألوان.
ui.ColorFilter _saturate(double s) => ui.ColorFilter.matrix([
  .213 + .787 * s, .715 - .715 * s, .072 - .072 * s, 0, 0, //
  .213 - .213 * s, .715 + .285 * s, .072 - .072 * s, 0, 0, //
  .213 - .213 * s, .715 - .715 * s, .072 + .928 * s, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// `--blur`: blur(22px) saturate(180%).
final ui.ImageFilter glassFilter = ui.ImageFilter.compose(
  outer: _saturate(1.8),
  inner: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
);

/// لوحة الأزرار: blur(26px) saturate(200%).
final ui.ImageFilter panelFilter = ui.ImageFilter.compose(
  outer: _saturate(2),
  inner: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
);

/// `ease-in-out` في CSS.
const cssEaseInOut = Curves.easeInOut;

/// `@keyframes float { 50% { translate: 0 -14px } }` — ذهاب وإياب بمنحنى
/// ease-in-out لكل نصف.
double floatOffset(double t) {
  final half = t < .5 ? t * 2 : 2 - t * 2;
  return -14 * cssEaseInOut.transform(half);
}

// ───────────────────────── حلقة الحركة ─────────────────────────

/// حركة متكررة بلا نهاية (`animation: … infinite`).
///
/// [phase] كسر من الدورة يبدأ عنده (التأخير السالب في CSS)، و[delay] انتظار
/// قبل أول دورة (التأخير الموجب) يُعطى فيه [builder] القيمة `null`.
/// مع «تقليل الحركة» لا تتحرك: القيمة ثابتة [still].
class Loop extends StatefulWidget {
  const Loop({
    super.key,
    required this.period,
    required this.builder,
    this.reverse = false,
    this.phase = 0,
    this.delay = Duration.zero,
    this.still = 0,
    this.child,
  });

  final Duration period;
  final bool reverse;
  final double phase;
  final Duration delay;
  final double still;
  final Widget? child;
  final Widget Function(BuildContext context, double? t, Widget? child) builder;

  @override
  State<Loop> createState() => _LoopState();
}

class _LoopState extends State<Loop> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: widget.period,
      value: widget.phase,
    );
  }

  bool? _reduced;
  Timer? _wait;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reduced) return;
    _reduced = reduced;
    _wait?.cancel();
    if (reduced) {
      _c.stop();
    } else if (_started || widget.delay == Duration.zero) {
      _started = true;
      _c.repeat(reverse: widget.reverse);
    } else {
      _wait = Timer(widget.delay, () {
        setState(() => _started = true);
        _c.repeat(reverse: widget.reverse);
      });
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced == true) {
      return widget.builder(context, widget.still, widget.child);
    }
    if (!_started && widget.delay > Duration.zero) {
      return widget.builder(context, null, widget.child);
    }
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => widget.builder(context, _c.value, child),
    );
  }
}

// ───────────────────────── الزجاج ─────────────────────────

/// `--sheen`: inset 0 1px 0 rgba(255,255,255,.22), inset 0 -1px 0 rgba(255,255,255,.04)
/// — هلال ضوء رفيع داخل الحافة العليا وآخر أخفت في السفلى.
class _SheenPainter extends CustomPainter {
  const _SheenPainter(this.radius, {this.top = const Color(0x38FFFFFF)});

  final double radius;
  final Color top;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    Path crescent(double dy) => Path.combine(
      PathOperation.difference,
      shape,
      shape.shift(Offset(0, dy)),
    );
    canvas.drawPath(crescent(1), Paint()..color = top);
    canvas.drawPath(crescent(-1), Paint()..color = const Color(0x0AFFFFFF));
  }

  @override
  bool shouldRepaint(_SheenPainter old) =>
      old.radius != radius || old.top != top;
}

/// سطح زجاجي بضبابية خلفية حقيقية.
class LaunchGlass extends StatelessWidget {
  const LaunchGlass({
    super.key,
    required this.radius,
    this.child,
    this.color = AppColors.glass,
    this.gradient,
    this.borderColor = AppColors.borderHi,
    this.shadows = const [],
    this.overlay,
    this.filter,
    this.backdrop = true,
    this.sheenTop = const Color(0x38FFFFFF),
  });

  /// بلا ضبابية خلفية (الزر الشبحي في التصميم).
  final bool backdrop;

  final double radius;
  final Widget? child;
  final Color color;
  final Gradient? gradient;
  final Color borderColor;
  final List<BoxShadow> shadows;

  /// طبقة فوق التعبئة (`::before` في التصميم).
  final Gradient? overlay;
  final ui.ImageFilter? filter;
  final Color sheenTop;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: shape,
      ),
      child: CustomPaint(
        foregroundPainter: _SheenPainter(radius, top: sheenTop),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: shape,
            border: Border.all(color: borderColor),
          ),
          child: overlay == null
              ? child
              : DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: shape,
                    gradient: overlay,
                  ),
                  child: child,
                ),
        ),
      ),
    );
    body = ClipRRect(
      borderRadius: shape,
      child: backdrop
          ? BackdropFilter(
              filter: filter ?? glassFilter,
              // الأسطح ذات المرشّح نفسه تتشارك لقطة الخلفية (أخف على Impeller)
              backdropGroupKey: filter == null
                  ? BackdropGroup.of(context)?.backdropKey
                  : null,
              child: body,
            )
          : body,
    );
    if (shadows.isEmpty) return body;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: shape, boxShadow: shadows),
      child: body,
    );
  }
}

// ───────────────────────── الخلفية ─────────────────────────

/// خلفية الشاشتين: لون `--bg` + الشفق المتحرك + الحبيبات + الكبسولات العائمة.
class LaunchBackdrop extends StatelessWidget {
  const LaunchBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.bgDark,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Aurora(),
          RepaintBoundary(child: CustomPaint(painter: _GrainPainter())),
          _Floaters(),
        ],
      ),
    );
  }
}

class _Aurora extends StatelessWidget {
  const _Aurora();

  @override
  Widget build(BuildContext context) {
    // ضبابية واحدة σ=60 على الطبقة كلها بدل ثلاث — النتيجة نفسها لأن البقع
    // متباعدة، وبثلث الكلفة.
    return RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: 60,
          sigmaY: 60,
          tileMode: TileMode.decal,
        ),
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            clipBehavior: Clip.none,
            children: [
              _blob(
                size: 340,
                color: const Color(0x990D9488),
                period: 18,
                top: -100,
                right: -90,
              ),
              _blob(
                size: 300,
                color: const Color(0x732563EB),
                period: 22,
                top: box.maxHeight * .38,
                left: -140,
              ),
              _blob(
                size: 280,
                color: const Color(0x667C3AED),
                period: 26,
                bottom: -90,
                right: -60,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// `@keyframes drift { to { transform: translate(-40px, 50px) scale(1.15) } }`
  /// ذهاباً وإياباً (`alternate`) بمنحنى ease-in-out.
  static Widget _blob({
    required double size,
    required Color color,
    required int period,
    double? top,
    double? left,
    double? right,
    double? bottom,
  }) => Positioned(
    top: top,
    left: left,
    right: right,
    bottom: bottom,
    width: size,
    height: size,
    child: Loop(
      period: Duration(seconds: period),
      reverse: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      builder: (context, t, child) {
        final e = cssEaseInOut.transform(t ?? 0);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.translationValues(-40 * e, 50 * e, 0)
            ..scaleByDouble(1 + .15 * e, 1 + .15 * e, 1, 1),
          child: child,
        );
      },
    ),
  );
}

/// `.grain`: نقاط 1px بيضاء (.8) على شبكة 3px، بشفافية .06 للطبقة.
class _GrainPainter extends CustomPainter {
  const _GrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cols = (size.width / 3).ceil(), rows = (size.height / 3).ceil();
    final points = Float32List(cols * rows * 2);
    var i = 0;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        points[i++] = x * 3 + 1.5;
        points[i++] = y * 3 + 1.5;
      }
    }
    canvas.drawRawPoints(
      ui.PointMode.points,
      points,
      Paint()
        ..color = const Color(0xCCFFFFFF).withValues(alpha: .8 * .06)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GrainPainter old) => false;
}

class _Floaters extends StatelessWidget {
  const _Floaters();

  static LinearGradient _half(Color c) => LinearGradient(
    colors: [c, c, const Color(0x1AFFFFFF), const Color(0x1AFFFFFF)],
    stops: const [0, .5, .5, 1],
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        return Stack(
          children: [
            _capsule(
              left: w * .12,
              top: h * .14,
              width: 64,
              height: 26,
              turn: -30,
              gradient: _half(const Color(0x592DD4BF)),
              phase: 0,
            ),
            _capsule(
              right: w * .10,
              top: h * .22,
              width: 46,
              height: 18,
              turn: 40,
              gradient: _half(const Color(0x5938BDF8)),
              phase: 2 / 7,
            ),
            _capsule(
              right: w * .14,
              top: h * .46,
              width: 38,
              height: 38,
              turn: 0,
              color: const Color(0x33A78BFA),
              phase: 4 / 7,
            ),
          ],
        );
      },
    );
  }

  static Widget _capsule({
    double? left,
    double? right,
    required double top,
    required double width,
    required double height,
    required double turn,
    required double phase,
    Gradient? gradient,
    Color color = Colors.transparent,
  }) => Positioned(
    left: left,
    right: right,
    top: top,
    width: width,
    height: height,
    child: Loop(
      period: const Duration(seconds: 7),
      phase: phase,
      child: Transform.rotate(
        angle: turn * math.pi / 180,
        child: LaunchGlass(
          radius: height / 2,
          gradient: gradient,
          color: color,
        ),
      ),
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, floatOffset(t ?? 0)),
        child: child,
      ),
    ),
  );
}

// ───────────────────────── الشعار ─────────────────────────

class LaunchIcons {
  static const cross = '''
<svg viewBox="0 0 64 64" fill="none">
<defs><linearGradient id="lg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#A5F3FC"/></linearGradient></defs>
<rect x="24" y="8" width="16" height="48" rx="6" fill="url(#lg)"/>
<rect x="8" y="24" width="48" height="16" rx="6" fill="url(#lg)"/>
<rect x="27" y="27" width="10" height="10" rx="3" fill="#2DD4BF"/>
</svg>''';

  static const miniCross =
      '<svg viewBox="0 0 64 64"><rect x="24" y="8" width="16" height="48" rx="6" fill="#04201C"/><rect x="8" y="24" width="48" height="16" rx="6" fill="#04201C"/></svg>';

  static const scan =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#5EEAD4" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M3 7V5a2 2 0 0 1 2-2h2"/><path d="M17 3h2a2 2 0 0 1 2 2v2"/><path d="M21 17v2a2 2 0 0 1-2 2h-2"/><path d="M7 21H5a2 2 0 0 1-2-2v-2"/><path d="M8 7v10M12 7v10M16 7v10"/></svg>';
  static const receipt =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#FCD34D" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M4 2v20l2-1 2 1 2-1 2 1 2-1 2 1 2-1 2 1V2l-2 1-2-1-2 1-2-1-2 1-2-1-2 1Z"/><path d="M8 8h8M8 12h8M8 16h5"/></svg>';
  static const cloud =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#C4B5FD" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M17.5 19H9a7 7 0 1 1 6.7-9h1.8a4.5 4.5 0 1 1 0 9Z"/><path d="m9.5 14 2 2 4-4"/></svg>';

  static String check(String color) =>
      '<svg viewBox="0 0 24 24" fill="none" stroke="$color" stroke-width="2.5" stroke-linecap="round"><path d="M20 6 9 17l-5-5"/></svg>';
  static const search =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#38BDF8" stroke-width="2.2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/></svg>';
  static const spark =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#FBBF24" stroke-width="2.2" stroke-linecap="round"><path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1"/></svg>';
  static const clock =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#FB7185" stroke-width="2.2" stroke-linecap="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>';
  static const phone =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#A78BFA" stroke-width="2.2" stroke-linecap="round"><rect x="5" y="2" width="14" height="20" rx="2"/><path d="M12 18h.01"/></svg>';

  static const chevron =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#04201C" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m15 18-6-6 6-6"/></svg>';
  static const link =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#F1F5F9" stroke-width="2" stroke-linecap="round"><path d="M10 13a5 5 0 0 0 7.5.5l3-3a5 5 0 0 0-7-7l-1.7 1.7"/><path d="M14 11a5 5 0 0 0-7.5-.5l-3 3a5 5 0 0 0 7 7l1.7-1.7"/></svg>';
  static const shield =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#34D399" stroke-width="2" stroke-linecap="round"><path d="M20 13c0 5-3.5 7.5-7.7 9a1 1 0 0 1-.6 0C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.2-2.7a1.2 1.2 0 0 1 1.6 0C14.5 3.8 17 5 19 5a1 1 0 0 1 1 1z"/></svg>';
}

Widget svgIcon(String svg, double size) =>
    SvgPicture.string(svg, width: size, height: size);

/// `@keyframes shine { 0% { left: -60% } 45%, 100% { left: 130% } }` بمنحنى
/// ease-in-out في المقطع الأول ثم ثبات خارج السطح بقية الدورة.
double shineLeft(double t, {double from = -.6, double to = 1.3}) {
  if (t >= .45) return to;
  return from + (to - from) * cssEaseInOut.transform(t / .45);
}

/// شعار البداية: بلاطة زجاجية 112 بثلاث حلقات نبض ولمعة، تظهر بـ`pop`.
class PharmacyLogo extends StatefulWidget {
  const PharmacyLogo({super.key});

  @override
  State<PharmacyLogo> createState() => _PharmacyLogoState();
}

class _PharmacyLogoState extends State<PharmacyLogo>
    with SingleTickerProviderStateMixin {
  /// `pop .9s var(--spring) both`
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pop.value = 1;
    } else if (_pop.isDismissed) {
      _pop.forward();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < 3; i++) _ring(i),
          AnimatedBuilder(
            animation: _pop,
            child: const _LogoTile(),
            builder: (context, child) {
              final v = designSpring.transform(_pop.value);
              return Opacity(
                opacity: v.clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: -12 * (1 - v) * math.pi / 180,
                  child: Transform.scale(scale: .4 + .6 * v, child: child),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// `@keyframes ring { from { scale(.85); opacity: .9 } to { scale(1.7); opacity: 0 } }`
  /// كل 2.4 ثانية، بتأخير .8 بين الحلقات.
  Widget _ring(int i) => Loop(
    period: const Duration(milliseconds: 2400),
    delay: Duration(milliseconds: 800 * i),
    still: 1,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: const Color(0x732DD4BF)),
      ),
      child: const SizedBox.expand(),
    ),
    builder: (context, t, child) {
      if (t == null) return const SizedBox.shrink();
      final e = designEase.transform(t);
      return Opacity(
        opacity: .9 * (1 - e),
        child: Transform.scale(scale: .85 + .85 * e, child: child),
      );
    },
  );
}

class _LogoTile extends StatelessWidget {
  const _LogoTile();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 112,
      child: LaunchGlass(
        radius: 36,
        gradient: cssGradient(
          145,
          const [Color(0x592DD4BF), Color(0x2438BDF8), Color(0x33A78BFA)],
          stops: const [0, .55, 1],
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x4D2DD4BF),
            blurRadius: 50,
            offset: Offset(0, 20),
          ),
        ],
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ::before — ضوء النصف العلوي
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x47FFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
            // ::after — لمعة مائلة تعبر كل 2.6 ثانية بعد ثانية
            Positioned.fill(
              child: Loop(
                period: const Duration(milliseconds: 2600),
                delay: const Duration(seconds: 1),
                builder: (context, t, _) => CustomPaint(
                  painter: _ShinePainter(
                    left: t == null ? -.6 : shineLeft(t),
                    width: .4,
                    angle: 25,
                    tall: true,
                  ),
                ),
              ),
            ),
            // الصليب مع drop-shadow(0 4px 12px rgba(0,0,0,.35))
            Transform.translate(
              offset: const Offset(0, 4),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0x59000000),
                    BlendMode.srcIn,
                  ),
                  child: svgIcon(LaunchIcons.cross, 58),
                ),
              ),
            ),
            svgIcon(LaunchIcons.cross, 58),
          ],
        ),
      ),
    );
  }
}

/// شريط لمعة أبيض شفاف (transparent → .45/.55 → transparent).
///
/// [left] و[width] كسور من عرض السطح. [tall]: شريط الشعار (ارتفاعه 200% يبدأ
/// من -50% ومدوّر 25°)، وإلا شريط الزر (بارتفاعه ومائل skewX).
class _ShinePainter extends CustomPainter {
  const _ShinePainter({
    required this.left,
    required this.width,
    required this.angle,
    this.tall = false,
    this.peak = const Color(0x73FFFFFF),
  });

  final double left, width, angle;
  final bool tall;
  final Color peak;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * width;
    final x = size.width * left;
    final rect = tall
        ? Rect.fromLTWH(x, -size.height * .5, w, size.height * 2)
        : Rect.fromLTWH(x, 0, w, size.height);
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    if (tall) {
      canvas.rotate(angle * math.pi / 180);
    } else {
      canvas.transform(
        (Matrix4.identity()..setEntry(0, 1, math.tan(angle * math.pi / 180)))
            .storage,
      );
    }
    canvas.translate(-rect.center.dx, -rect.center.dy);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [peak.withValues(alpha: 0), peak, peak.withValues(alpha: 0)],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShinePainter old) => old.left != left;
}

/// لمعة زر «التالي»: `shine 3.2s 1.5s` بعرض 30% ومائلة skewX(-20deg).
class ButtonShine extends StatelessWidget {
  const ButtonShine({super.key});

  @override
  Widget build(BuildContext context) {
    return Loop(
      period: const Duration(milliseconds: 3200),
      delay: const Duration(milliseconds: 1500),
      builder: (context, t, _) => CustomPaint(
        size: Size.infinite,
        painter: _ShinePainter(
          left: t == null ? -.4 : shineLeft(t, from: -.4),
          width: .3,
          angle: -20,
          peak: const Color(0x8CFFFFFF),
        ),
      ),
    );
  }
}

/// نص بتدرّج (`background-clip: text`).
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    required this.style,
    required this.gradient,
  });

  final String text;
  final TextStyle style;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: gradient.createShader,
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}
