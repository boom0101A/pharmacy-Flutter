import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../config/app_info.dart';
import '../services/app_settings.dart';
import '../theme.dart';
import '../widgets/launch_art.dart';
import '../widgets/smooth_route.dart';
import 'welcome_view.dart';

/// بداية التطبيق: شاشة الشعار عند كل فتح، تبقى ما دامت الخدمات تُهيّأ (بحد
/// أدنى [minDuration])، ثم تذوب إلى شرائح الترحيب في أول تشغيل أو إلى
/// الرئيسية مباشرة.
class LaunchFlow extends StatefulWidget {
  const LaunchFlow({
    super.key,
    required this.initialize,
    required this.home,
    required this.onJoin,
    this.minDuration = const Duration(milliseconds: 1500),
  });

  /// تهيئة الخدمات — تجري والشعار ظاهر. فشلها لا يعلّق الشاشة.
  final Future<void> Function() initialize;
  final WidgetBuilder home;

  /// «انضمام إلى مخزون» — يُستدعى بعد ظهور الرئيسية.
  final void Function(BuildContext context) onJoin;
  final Duration minDuration;

  @override
  State<LaunchFlow> createState() => _LaunchFlowState();
}

enum _Stage { splash, welcome, home }

class _LaunchFlowState extends State<LaunchFlow> with TickerProviderStateMixin {
  _Stage _stage = _Stage.splash;
  bool _splashGone = false;
  bool _welcomeGone = false;
  bool _viaWelcome = false;
  bool _leaving = false;
  bool _started = false;
  late bool _reduced;

  /// ظهور الاسم وشريط التحميل (`up .8s .35s` و`up .6s .6s`).
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  /// امتلاء الشريط: حتى 90% أثناء التهيئة، ثم 100% عند اكتمالها.
  late final AnimationController _load = AnimationController(vsync: this);

  /// ذوبان الشعار (.8s) وظهور ما تحته (.6s بتأخير .15s).
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  /// خروج الشرائح إلى الرئيسية.
  late final AnimationController _leave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  Timer? _loadStart;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_started) return;
    _started = true;
    _run();
  }

  Future<void> _run() async {
    if (_reduced) {
      _intro.value = 1;
    } else {
      _intro.forward();
      _loadStart = Timer(const Duration(milliseconds: 800), () {
        _load.animateTo(
          .9,
          duration: const Duration(seconds: 2),
          curve: designEase,
        );
      });
    }

    final minWait = Completer<void>();
    final timer = Timer(
      _reduced ? Duration.zero : widget.minDuration,
      minWait.complete,
    );
    try {
      await Future.wait([_safeInit(), minWait.future]);
    } finally {
      timer.cancel();
    }
    if (!mounted) return;

    _loadStart?.cancel();
    if (!_reduced) {
      await _load.animateTo(
        1,
        duration: const Duration(milliseconds: 250),
        curve: designEase,
      );
      if (!mounted) return;
    }
    setState(() {
      _viaWelcome = !AppSettings.instance.welcomeSeen;
      _stage = _viaWelcome ? _Stage.welcome : _Stage.home;
    });
    if (_reduced) {
      _exit.value = 1;
    } else {
      await _exit.forward();
    }
    if (mounted) setState(() => _splashGone = true);
  }

  Future<void> _safeInit() async {
    try {
      await widget.initialize();
    } catch (e) {
      debugPrint('تعذّرت تهيئة بعض الخدمات: $e');
    }
  }

  Future<void> _finishWelcome({required bool join}) async {
    if (_stage != _Stage.welcome || _leaving) return;
    _leaving = true;
    await AppSettings.instance.markWelcomeSeen();
    if (!mounted) return;
    setState(() => _stage = _Stage.home);
    if (_reduced) {
      _leave.value = 1;
    } else {
      await _leave.forward();
    }
    if (!mounted) return;
    setState(() => _welcomeGone = true);
    if (join) widget.onJoin(context);
  }

  @override
  void dispose() {
    _loadStart?.cancel();
    _intro.dispose();
    _load.dispose();
    _exit.dispose();
    _leave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leaveFade = ReverseAnimation(
      CurvedAnimation(parent: _leave, curve: designEase),
    );
    // الخلفية تذوب مع الشرائح إن مررنا بها، وإلا مع الشعار
    final backdropOpacity = _viaWelcome
        ? leaveFade
        : ReverseAnimation(
            CurvedAnimation(
              parent: _exit,
              curve: const Interval(0, .75, curve: designEase),
            ),
          );
    final backdropGone = _viaWelcome ? _welcomeGone : _splashGone;

    return BackdropGroup(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // مفاتيح ثابتة: إدراج الرئيسية في أول القائمة لا يُعيد إنشاء ما بعدها
          if (_stage == _Stage.home)
            KeyedSubtree(
              key: const ValueKey('home'),
              child: Builder(builder: widget.home),
            ),
          if (!backdropGone)
            FadeTransition(
              key: const ValueKey('backdrop'),
              opacity: backdropOpacity,
              child: const LaunchBackdrop(),
            ),
          if (_viaWelcome && !_welcomeGone)
            FadeTransition(
              key: const ValueKey('welcome'),
              opacity: leaveFade,
              child: FadeTransition(
                // `.welcome { transition: opacity .6s .15s var(--ease) }`
                opacity: CurvedAnimation(
                  parent: _exit,
                  curve: const Interval(.1875, .9375, curve: designEase),
                ),
                child: IgnorePointer(
                  ignoring: _stage != _Stage.welcome,
                  child: WelcomeView(
                    onDone: () => _finishWelcome(join: false),
                    onJoin: () => _finishWelcome(join: true),
                  ),
                ),
              ),
            ),
          if (!_splashGone)
            IgnorePointer(
              key: const ValueKey('splash'),
              ignoring: _stage != _Stage.splash,
              child: _SplashView(intro: _intro, load: _load, exit: _exit),
            ),
        ],
      ),
    );
  }
}

/// شاشة الشعار — `.splash` في التصميم.
class _SplashView extends StatelessWidget {
  const _SplashView({
    required this.intro,
    required this.load,
    required this.exit,
  });

  final Animation<double> intro, load, exit;

  /// `@keyframes up { from { opacity: 0; transform: translateY(16px) } }`
  static Widget _up(Animation<double> parent, Interval interval, Widget child) {
    final a = CurvedAnimation(parent: parent, curve: interval);
    return AnimatedBuilder(
      animation: a,
      child: child,
      builder: (context, child) => Opacity(
        opacity: a.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - a.value)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final title = cairo(40, 800, height: 1.5).copyWith(letterSpacing: -.5);
    final content = Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Semantics(
            label: 'جارٍ التحميل',
            container: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PharmacyLogo(),
                const SizedBox(height: 22),
                _up(
                  intro,
                  const Interval(350 / 1200, 1150 / 1200, curve: designEase),
                  Column(
                    children: [
                      GradientText(
                        'صيدليتي',
                        style: title,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, Color(0xFFA5F3FC)],
                          stops: [.3, 1],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'مخزونك الدوائي… أذكى وأبسط',
                        style: cairo(14, 400, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _up(
                  intro,
                  const Interval(600 / 1200, 1, curve: designEase),
                  _LoaderBar(load: load),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 26 + bottom,
          child: Text(
            'الإصدار $appVersion · مزامنة سحابية آمنة',
            textAlign: TextAlign.center,
            style: cairo(11, 400, color: AppColors.textMuted),
          ),
        ),
      ],
    );

    // `.splash.out { opacity: 0; transform: scale(1.08); filter: blur(8px) }`
    // — الشفافية .6s والتكبير .8s بمنحنى --ease، والضبابية .6s بـ ease.
    final fade = CurvedAnimation(
      parent: exit,
      curve: const Interval(0, .75, curve: designEase),
    );
    final grow = CurvedAnimation(parent: exit, curve: designEase);
    final blur = CurvedAnimation(
      parent: exit,
      curve: const Interval(0, .75, curve: Curves.ease),
    );
    return AnimatedBuilder(
      animation: exit,
      child: content,
      builder: (context, child) {
        Widget out = Transform.scale(scale: 1 + .08 * grow.value, child: child);
        if (blur.value > 0) {
          out = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: 8 * blur.value,
              sigmaY: 8 * blur.value,
            ),
            child: out,
          );
        }
        return Opacity(opacity: 1 - fade.value, child: out);
      },
    );
  }
}

/// `.loader`: 160×6 زجاجي، وبداخله شريط بالتدرّج يتوهّج.
class _LoaderBar extends StatelessWidget {
  const _LoaderBar({required this.load});

  final Animation<double> load;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'تحميل',
      child: Container(
        width: 160,
        height: 6,
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        alignment: AlignmentDirectional.centerStart,
        child: AnimatedBuilder(
          animation: load,
          builder: (context, _) => FractionallySizedBox(
            widthFactor: load.value,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: brandGradient(aspect: 26),
                boxShadow: const [
                  BoxShadow(color: Color(0xB32DD4BF), blurRadius: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// شرائح الترحيب من الإعدادات («عرض شاشة الترحيب»).
Future<void> showWelcomeAgain(
  BuildContext context, {
  required void Function(BuildContext context) onJoin,
}) {
  final navigator = Navigator.of(context);
  return navigator.push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 500),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, _, _) => BackdropGroup(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const LaunchBackdrop(),
            WelcomeView(
              onDone: () => Navigator.of(context).pop(),
              onJoin: () {
                Navigator.of(context).pop();
                onJoin(navigator.context);
              },
            ),
          ],
        ),
      ),
      transitionsBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: designEase),
        child: child,
      ),
    ),
  );
}
