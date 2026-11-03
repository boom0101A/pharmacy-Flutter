import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/launch_art.dart';
import '../widgets/smooth_route.dart';

/// شرائح الترحيب الثلاث — من ملف التصميم `welcome.html`.
///
/// شفافة: تُرسم فوق [LaunchBackdrop] الذي يضعه من يعرضها.
class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key, required this.onDone});

  /// «تخطّي» أو «ابدأ الآن».
  final VoidCallback onDone;

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _SlideData {
  const _SlideData({
    required this.orb,
    required this.icon,
    required this.chips,
    required this.title,
    required this.accent,
    required this.body,
  });

  final List<Color> orb;
  final String icon;
  final List<_Chip> chips;
  final String title, accent, body;
}

class _Chip {
  const _Chip(this.dot, this.icon, this.label);

  final Color dot;
  final String icon, label;
}

final _slides = [
  _SlideData(
    orb: const [Color(0x8C2DD4BF), Color(0x2E38BDF8)],
    icon: LaunchIcons.scan,
    chips: [
      _Chip(
        const Color(0x3334D399),
        LaunchIcons.check('#34D399'),
        'Panadol · 24 علبة',
      ),
      const _Chip(Color(0x3338BDF8), LaunchIcons.search, 'تم التعرّف تلقائياً'),
    ],
    title: 'امسح الباركود ',
    accent: 'وأضف بثانية',
    body:
        'وجّه الكاميرا نحو العلبة، ويتعرّف التطبيق على الدواء من القاموس '
        'المشترك بين الصيدليات.',
  ),
  _SlideData(
    orb: const [Color(0x73FBBF24), Color(0x2638BDF8)],
    icon: LaunchIcons.receipt,
    chips: [
      const _Chip(Color(0x33FBBF24), LaunchIcons.spark, 'قراءة ذكية للفاتورة'),
      _Chip(
        const Color(0x3334D399),
        LaunchIcons.check('#34D399'),
        '12 سطراً أُضيفت',
      ),
    ],
    title: 'صوّر الفاتورة ',
    accent: 'والباقي علينا',
    body:
        'الفاتورة الذكية تقرأ الأسماء والأسعار والكميات، وتنبّهك على أي سطر '
        'مشكوك فيه قبل الحفظ.',
  ),
  const _SlideData(
    orb: [Color(0x73A78BFA), Color(0x2E2DD4BF)],
    icon: LaunchIcons.cloud,
    chips: [
      _Chip(Color(0x33FB7185), LaunchIcons.clock, '3 أدوية قاربت الانتهاء'),
      _Chip(Color(0x33A78BFA), LaunchIcons.phone, 'جهازان متزامنان'),
    ],
    title: 'مخزون واحد ',
    accent: 'على كل أجهزتك',
    body:
        'مزامنة سحابية فورية مع زملائك، وتنبيهات للصلاحية والمخزون المنخفض '
        'قبل أن تتفاجأ.',
  ),
];

class _WelcomeViewState extends State<WelcomeView> {
  int _index = 0;
  Timer? _auto;
  double _dragDx = 0;

  int get _last => _slides.length - 1;

  @override
  void initState() {
    super.initState();
    _restartAuto();
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  /// تقدّم تلقائي كل 5 ثوانٍ يتوقف عند الأخيرة؛ يُعاد ضبطه مع كل تفاعل.
  void _restartAuto() {
    _auto?.cancel();
    _auto = Timer.periodic(const Duration(seconds: 5), (t) {
      if (_index < _last) {
        setState(() => _index++);
      } else {
        t.cancel();
      }
    });
  }

  /// الإنهاء مرة واحدة فقط: ضغطتان سريعتان كانتا تفتحان ورقتَي انضمام، وفي
  /// «عرض شاشة الترحيب» من الإعدادات كانتا تغلقان الرئيسية نفسها.
  bool _finished = false;

  void _finish(VoidCallback callback) {
    if (_finished) return;
    _finished = true;
    _auto?.cancel();
    callback();
  }

  void _show(int i) {
    if (_finished) return;
    setState(() => _index = i);
    _restartAuto();
  }

  void _next() {
    if (_index < _last) {
      _show(_index + 1);
    } else {
      _finish(widget.onDone);
    }
  }

  void _prev() {
    if (_index > 0) {
      _show(_index - 1);
    } else {
      _restartAuto();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final short = MediaQuery.sizeOf(context).height < 700;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18 + pad.top, 18, 20 + pad.bottom),
      child: Column(
        children: [
          _top(),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) => _dragDx = 0,
              onHorizontalDragUpdate: (d) => _dragDx += d.delta.dx,
              // RTL: السحب لليسار = التالي
              onHorizontalDragEnd: (_) {
                if (_dragDx.abs() > 40) _dragDx < 0 ? _next() : _prev();
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (var k = 0; k < _slides.length; k++)
                    _Slide(
                      key: ValueKey(k),
                      data: _slides[k],
                      offset: k.compareTo(_index),
                      short: short,
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 18),
            child: _dots(),
          ),
          _actions(),
        ],
      ),
    );
  }

  Widget _top() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: brandGradient(),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x592DD4BF),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: const Border(top: BorderSide(color: Color(0x80FFFFFF))),
            ),
            alignment: Alignment.center,
            child: svgIcon(LaunchIcons.miniCross, 22),
          ),
          const SizedBox(width: 10),
          Text('صيدليتي', style: cairo(17, 800, color: AppColors.textPrimary)),
        ],
      ),
      _Pressable(
        key: const Key('welcomeSkip'),
        onTap: () => _finish(widget.onDone),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44),
          child: SizedBox(
            height: 44,
            child: LaunchGlass(
              radius: 22,
              borderColor: AppColors.border,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    'تخطّي',
                    style: cairo(13, 700, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _dots() {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var k = 0; k < _slides.length; k++) ...[
          if (k > 0) const SizedBox(width: 8),
          Semantics(
            button: true,
            selected: k == _index,
            label: 'الشريحة ${k + 1}',
            child: GestureDetector(
              key: Key('welcomeDot$k'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _show(k),
              child: SizedBox(
                width: 44,
                height: 24,
                // `transition: width .45s var(--spring), background .3s`
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: k == _index ? 28 : 8),
                    duration: reduced
                        ? Duration.zero
                        : const Duration(milliseconds: 450),
                    curve: designSpring,
                    builder: (context, w, child) =>
                        SizedBox(width: w, height: 8, child: child),
                    child: AnimatedContainer(
                      duration: reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 300),
                      curve: Curves.ease,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: k == _index ? null : const Color(0x40FFFFFF),
                        gradient: k == _index
                            ? brandGradient(aspect: 3.5)
                            : null,
                        boxShadow: k == _index
                            ? const [
                                BoxShadow(
                                  color: Color(0x992DD4BF),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _actions() => LaunchGlass(
    radius: 30,
    color: const Color(0x800E182A),
    filter: panelFilter,
    shadows: const [
      BoxShadow(
        color: Color(0x73000000),
        blurRadius: 40,
        offset: Offset(0, 18),
      ),
    ],
    // زر «التالي» وحده (قرار المستخدم): الانضمام إلى مخزون من الإعدادات ←
    // المشاركة، لا من الترحيب
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: _Pressable(
        key: const Key('welcomeNext'),
        onTap: _next,
        child: _PrimaryButton(last: _index == _last),
      ),
    ),
  );
}

/// زر «التالي»/«ابدأ الآن»: تدرّج + لمعة متكررة.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.last});

  final bool last;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(27);
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: shape,
        gradient: brandGradient(aspect: 6.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x662DD4BF),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: shape,
        border: const Border(top: BorderSide(color: Color(0x80FFFFFF))),
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ButtonShine(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      last ? 'ابدأ الآن' : 'التالي',
                      style: cairo(16, 800, color: AppColors.onGradient),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                svgIcon(LaunchIcons.chevron, 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ضغطة نابضية: `.btn:active { transform: scale(.96) }` بمنحنى spring .2s.
class _Pressable extends StatefulWidget {
  const _Pressable({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? .96 : 1,
          duration: const Duration(milliseconds: 200),
          curve: designSpring,
          child: widget.child,
        ),
      ),
    );
  }
}

/// شريحة واحدة. [offset]: 0 النشطة، سالب السابقة، موجب اللاحقة.
///
/// `.slide { opacity 0; translateX(-30px) scale(.97) }` و`.slide.prev
/// { translateX(30px) }` — الشفافية .45s ease والحركة .55s spring.
class _Slide extends StatelessWidget {
  const _Slide({
    super.key,
    required this.data,
    required this.offset,
    required this.short,
  });

  final _SlideData data;
  final int offset;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final active = offset == 0;
    final dx = active ? 0.0 : (offset < 0 ? 30.0 : -30.0);
    return IgnorePointer(
      ignoring: !active,
      child: AnimatedOpacity(
        opacity: active ? 1 : 0,
        duration: reduced ? Duration.zero : const Duration(milliseconds: 450),
        curve: designEase,
        child: TweenAnimationBuilder<Offset>(
          tween: Tween(end: Offset(dx, active ? 1 : .97)),
          duration: reduced ? Duration.zero : const Duration(milliseconds: 550),
          curve: designSpring,
          builder: (context, v, child) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.translationValues(v.dx, 0, 0)
              ..scaleByDouble(v.dy, v.dy, 1, 1),
            child: child,
          ),
          child: Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _scaledHero(active),
                  const SizedBox(height: 26),
                  _copy(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// `@media (max-height:700px) { .hero { transform: scale(.8); margin: -25px 0 } }`
  Widget _scaledHero(bool active) {
    final hero = _Hero(data: data, active: active);
    if (!short) return hero;
    return SizedBox(
      key: const Key('heroShort'),
      width: 250,
      height: 200,
      child: OverflowBox(
        maxWidth: 250,
        maxHeight: 250,
        child: Transform.scale(scale: .8, child: hero),
      ),
    );
  }

  Widget _copy() {
    final h2 = cairo(
      short ? 22 : 26,
      800,
      color: AppColors.textPrimary,
      height: 1.35,
    );
    return Column(
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: data.title),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GradientText(
                  data.accent,
                  style: h2,
                  gradient: brandGradient(aspect: 4),
                ),
              ),
            ],
          ),
          style: h2,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            data.body,
            textAlign: TextAlign.center,
            style: cairo(15, 400, color: AppColors.textSecondary, height: 1.75),
          ),
        ),
      ],
    );
  }
}

/// البطل 250×250: كرة ضبابية + بطاقة زجاجية بالأيقونة + رقاقتان عائمتان.
///
/// كلما صارت الشريحة نشطة: البطاقة `pop .7s spring`، والرقاقتان
/// `chipIn .7s .15s spring` ثم `float 6s` بعد ثانية.
class _Hero extends StatefulWidget {
  const _Hero({required this.data, required this.active});

  final _SlideData data;
  final bool active;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with TickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  Timer? _floatStart;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _entry.value = 1;
      _float.stop();
      _floatStart?.cancel();
    } else if (widget.active && _entry.isDismissed) {
      _enter();
    }
  }

  @override
  void didUpdateWidget(_Hero old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !_reduced) _enter();
    if (!widget.active && old.active) {
      _floatStart?.cancel();
      _float.stop();
    }
  }

  void _enter() {
    _entry.forward(from: 0);
    _float.value = 0;
    _floatStart?.cancel();
    _floatStart = Timer(const Duration(seconds: 1), () {
      if (mounted) _float.repeat();
    });
  }

  @override
  void dispose() {
    _floatStart?.cancel();
    _entry.dispose();
    _float.dispose();
    super.dispose();
  }

  static const _cardShadow = [
    BoxShadow(color: Color(0x59000000), blurRadius: 40, offset: Offset(0, 16)),
  ];

  /// `.glass-card::before`: linear-gradient(160deg, rgba(255,255,255,.16), transparent 45%)
  static final _cardOverlay = cssGradient(
    160,
    const [Color(0x29FFFFFF), Color(0x00FFFFFF)],
    stops: const [0, .45],
  );

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return SizedBox(
      width: 250,
      height: 250,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // .orb: inset 20، radial-gradient(circle at 35% 30%) + blur(6px)
          Positioned.fill(
            left: 20,
            top: 20,
            right: 20,
            bottom: 20,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-.3, -.4),
                    // farthest-corner من (35%,30%) في مربع 210
                    radius: .955,
                    colors: [d.orb[0], d.orb[1], d.orb[1].withValues(alpha: 0)],
                    stops: const [0, .55, .72],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 30,
            right: 30,
            top: 36,
            bottom: 36,
            child: AnimatedBuilder(
              animation: _entry,
              child: LaunchGlass(
                radius: 26,
                shadows: _cardShadow,
                overlay: _cardOverlay,
                child: Center(child: svgIcon(d.icon, 84)),
              ),
              builder: (context, child) {
                final t = (_entry.value * 850 / 700).clamp(0.0, 1.0);
                final v = designSpring.transform(t);
                return Opacity(
                  opacity: v.clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: -12 * (1 - v) * math.pi / 180,
                    child: Transform.scale(scale: .4 + .6 * v, child: child),
                  ),
                );
              },
            ),
          ),
          Positioned(top: 8, right: -6, child: _chip(d.chips[0])),
          Positioned(bottom: 14, left: -10, child: _chip(d.chips[1])),
        ],
      ),
    );
  }

  Widget _chip(_Chip c) => AnimatedBuilder(
    animation: Listenable.merge([_entry, _float]),
    child: LaunchGlass(
      radius: 16,
      shadows: _cardShadow,
      overlay: _cardOverlay,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: c.dot,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: svgIcon(c.icon, 15),
            ),
            const SizedBox(width: 8),
            Text(
              c.label,
              maxLines: 1,
              softWrap: false,
              style: cairo(12, 700, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    ),
    builder: (context, child) {
      final t = ((_entry.value * 850 - 150) / 700).clamp(0.0, 1.0);
      final v = designSpring.transform(t);
      return Transform.translate(
        offset: Offset(0, 10 * (1 - v) + floatOffset(_float.value)),
        child: Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.scale(scale: .6 + .4 * v, child: child),
        ),
      );
    },
  );
}
