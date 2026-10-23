import 'package:flutter/material.dart';

/// منحنى `--ease` في ملف التصميم: cubic-bezier(.215,.61,.355,1).
const designEase = Cubic(.215, .61, .355, 1);

/// منحنى `--spring` في ملف التصميم: cubic-bezier(.34,1.56,.64,1) — يتجاوز
/// الهدف قليلاً ثم يستقر، وهو ما يعطي الأوراق والحوارات إحساس «السائل».
const designSpring = Cubic(.34, 1.56, .64, 1);

/// انتقال موحّد بين شاشات التطبيق بعمق «الزجاج الطبقي».
///
/// **الشاشة الداخلة:** تلاشٍ + انزلاق قصير من اليمين (6%) + تكبير من .985
/// (`.screen.hidden` في ملف التصميم).
/// **الشاشة الخارجة:** تتراجع خلفها قليلاً (تصغير إلى .97، إزاحة 3% وتعتيم
/// خفيف) فيظهر أن الجديدة طبقة فوقها لا صورة تُلصق على شاشة جامدة.
///
/// المسافات صغيرة والمدة ≤ 300ms عمداً — الحركة الطويلة تبدو بطيئة بعد المرة
/// العاشرة، والمستخدم هنا مدخل بيانات لا زائر. من أطفأ الحركة في إعدادات
/// إمكانية الوصول يرى تلاشياً فقط.
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  SmoothPageRoute({required this.builder, super.settings})
    : super(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: buildTransition,
      );

  final WidgetBuilder builder;

  static Widget buildTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondary,
    Widget child,
  ) {
    final enter = CurvedAnimation(
      parent: animation,
      curve: designEase,
      reverseCurve: Curves.easeInCubic,
    );

    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return FadeTransition(opacity: enter, child: child);
    }

    final exit = CurvedAnimation(
      parent: secondary,
      curve: designEase,
      reverseCurve: Curves.easeInCubic,
    );

    // الخارجة: تتراجع وتخفت قليلاً بينما تغطيها الداخلة
    final receding = FadeTransition(
      opacity: Tween(begin: 1.0, end: .55).animate(exit),
      child: SlideTransition(
        position: Tween(
          begin: Offset.zero,
          end: const Offset(-0.03, 0),
        ).animate(exit),
        child: ScaleTransition(
          scale: Tween(begin: 1.0, end: .97).animate(exit),
          child: child,
        ),
      ),
    );

    // الداخلة: تظهر وتنزلق من اليمين وتكبر إلى حجمها
    return FadeTransition(
      opacity: enter,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).animate(enter),
        child: ScaleTransition(
          scale: Tween(begin: .985, end: 1.0).animate(enter),
          child: receding,
        ),
      ),
    );
  }
}

/// نفس انتقال [SmoothPageRoute] لكل صفحات التطبيق عبر السمة — بما فيها
/// الشاشة الرئيسية (يفتحها `MaterialApp` بمسار افتراضي). بلا هذا تتراجع
/// الرئيسية بحركة أندرويد الافتراضية بينما تدخل الشاشة الجديدة بحركتنا.
class GlassPageTransitionsBuilder extends PageTransitionsBuilder {
  const GlassPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => SmoothPageRoute.buildTransition(
    context,
    animation,
    secondaryAnimation,
    child,
  );
}
