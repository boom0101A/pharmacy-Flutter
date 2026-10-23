import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'smooth_route.dart';

/// اللمعان العلوي (`--sheen` في ملف التصميم): خط ضوء رفيع على الحافة العليا
/// يمنح السطح إحساس الزجاج. يُرسم كتدرّج داخل السطح، بلا أي ضبابية.
const _sheen = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0x26FFFFFF), Color(0x00FFFFFF)],
  stops: [0, .35],
);

/// سطح زجاجي: تعبئة شفافة + حدّ رفيع + لمعان علوي + ظل.
///
/// **[blur] للأسطح الثابتة فقط** (الترويسة، شريط الأزرار، الأوراق، الحوارات):
/// `BackdropFilter` على كل بطاقة في قائمة من ألف مادة يقطّع التمرير على
/// الهواتف المتوسطة. البطاقات تبدو زجاجية بالشفافية واللمعان وحدهما.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 22,
    this.blur = false,
    this.color = AppColors.glass,
    this.gradient,
    this.borderColor = AppColors.border,
    this.padding,
    this.margin,
    this.shadow = true,
    this.sheen = true,
  });

  final Widget child;
  final double radius;
  final bool blur;
  final Color color;
  final Gradient? gradient;
  final Color borderColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool shadow;
  final bool sheen;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: shape,
        border: Border.all(color: borderColor),
      ),
      child: sheen
          ? DecoratedBox(
              decoration: BoxDecoration(borderRadius: shape, gradient: _sheen),
              position: DecorationPosition.foreground,
              child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
            )
          : Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );

    if (blur) body = _BlurWhenIdle(shape: shape, child: body);

    if (shadow) {
      body = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: const [
            // ظل خفيف: الظلال الضبابية الكبيرة تُعاد في كل إطار على Impeller
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: body,
      );
    }

    return margin == null ? body : Padding(padding: margin!, child: body);
  }
}

/// ضبابية حقيقية فقط والشاشة مستقرة.
///
/// أثناء انتقال الشاشات تُرسم الشاشتان معاً، وكل `BackdropFilter` فيهما يُعاد
/// حسابه في كل إطار من الحركة — أثقل مصدر للتقطّع على هاتف متوسط. هنا يظهر
/// السطح بلونه نفسه بلا ضبابية طوال الحركة، وتعود الضبابية فور الاستقرار.
/// يُعاد البناء عند تغيّر حالة الحركة فقط (بداية/نهاية)، لا في كل إطار.
class _BlurWhenIdle extends StatefulWidget {
  const _BlurWhenIdle({required this.shape, required this.child});

  final BorderRadius shape;
  final Widget child;

  @override
  State<_BlurWhenIdle> createState() => _BlurWhenIdleState();
}

class _BlurWhenIdleState extends State<_BlurWhenIdle> {
  ModalRoute<Object?>? _route;

  static bool _settled(Animation<double>? a) =>
      a == null ||
      a.status == AnimationStatus.completed ||
      a.status == AnimationStatus.dismissed;

  bool get _idle =>
      _settled(_route?.animation) && _settled(_route?.secondaryAnimation);

  void _onStatus(AnimationStatus _) {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (identical(route, _route)) return;
    _detach();
    _route = route;
    route?.animation?.addStatusListener(_onStatus);
    route?.secondaryAnimation?.addStatusListener(_onStatus);
  }

  void _detach() {
    _route?.animation?.removeStatusListener(_onStatus);
    _route?.secondaryAnimation?.removeStatusListener(_onStatus);
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  // شكل الشجرة ثابت دائماً — فقط `enabled` يتبدّل. إزالة BackdropFilter
  // وإعادته كانت تعيد بناء كل ما داخل السطح من الصفر فتضيع حالته (حقول
  // الفلاتر المكتوبة، ومتابعة الاسترجاع داخل ورقة الإعدادات بعد الحوار).
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.shape,
      child: BackdropFilter(
        enabled: _idle,
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: widget.child,
      ),
    );
  }
}

/// خلفية «الشفق» الثابتة: تدرّج داكن + ثلاث بقع ملوّنة ضبابية (تيل، أزرق،
/// بنفسجي) بمواقع ملف التصميم.
///
/// **ثابتة بلا حركة** (قرار المستخدم): الحركة المستمرة تستهلك البطارية طوال
/// يوم العمل.
///
/// **بلا أي مرشّح ضبابية:** محرّك Impeller (المستعمل على هاتف المستخدم) لا
/// يحتفظ بنسخة نقطية جاهزة، فكانت ضبابية σ=60 على الشاشة كلها تُعاد في كل
/// إطار تمرير وانتقال — أثقل مصدر للتقطّع (قيس: ~35 إطاراً/ثانية من 120).
/// كل بقعة الآن تدرّج دائري يتلاشى إلى الشفافية: نفس الحافة الناعمة تقريباً
/// وكلفة شبه معدومة.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.4, -0.8),
            radius: 1.3,
            colors: [Color(0xFF0B2A3A), Color(0xFF030812)],
            stops: [0, .6],
          ),
        ),
        child: const Stack(
          children: [
            _Blob(color: Color(0x8C0D9488), size: 320, top: -90, right: -80),
            _Blob(
              color: Color(0x732563EB),
              size: 280,
              topFraction: .34,
              left: -120,
            ),
            _Blob(color: Color(0x667C3AED), size: 260, bottom: -80, right: -40),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.color,
    required this.size,
    this.top,
    this.topFraction,
    this.left,
    this.right,
    this.bottom,
  });

  final Color color;
  final double size;
  final double? top, topFraction, left, right, bottom;

  /// امتداد الحافة الناعمة خارج حجم البقعة — يقارب انتشار ضبابية σ=60.
  static const _spread = 120.0;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    double? out(double? v) => v == null ? null : v - _spread;
    final total = size + 2 * _spread;
    // نصف قطر البقعة الأصلية نسبةً إلى الدائرة الموسّعة
    final core = size / total;
    return Positioned(
      top: topFraction != null ? h * topFraction! - _spread : out(top),
      left: out(left),
      right: out(right),
      bottom: out(bottom),
      width: total,
      height: total,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: color.a * .55),
              color.withValues(alpha: 0),
            ],
            stops: [0, core, 1],
          ),
        ),
      ),
    );
  }
}

/// زر بتدرّج («filled» و«success» و«warn» في ملف التصميم) مع ضغطة نابضية.
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.gradient = AppGradients.brand,
    this.foreground = AppColors.onGradient,
    this.height = 42,
    this.radius = 21,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.glow = const Color(0x472DD4BF),
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Gradient gradient;
  final Color foreground;
  final double height;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color glow;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final shape = BorderRadius.circular(widget.radius);
    return AnimatedScale(
      scale: _down ? 0.96 : 1,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: Opacity(
        opacity: enabled ? 1 : 0.38,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: shape,
            boxShadow: [
              BoxShadow(
                color: widget.glow,
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: shape,
              onTap: widget.onPressed,
              onHighlightChanged: (v) => setState(() => _down = v),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: shape,
                  gradient: _sheen,
                ),
                child: SizedBox(
                  height: widget.height,
                  child: Padding(
                    padding: widget.padding,
                    child: Center(
                      widthFactor: 1,
                      child: DefaultTextStyle.merge(
                        style: TextStyle(
                          color: widget.foreground,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        child: IconTheme.merge(
                          data: IconThemeData(color: widget.foreground),
                          child: widget.child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// مربع 52×52 بجانب البحث: «filled» بتدرّج أو «outlined» زجاجي.
class GlassSquareButton extends StatefulWidget {
  const GlassSquareButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.filled = false,
    this.active = false,
    this.size = 52,
    this.tooltip,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final bool filled;

  /// مفتوح (لوحة الفلاتر): حدّ تيل وخلفية خفيفة.
  final bool active;
  final double size;
  final String? tooltip;

  @override
  State<GlassSquareButton> createState() => _GlassSquareButtonState();
}

class _GlassSquareButtonState extends State<GlassSquareButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(18);
    final decoration = widget.filled
        ? BoxDecoration(
            gradient: AppGradients.brand,
            borderRadius: shape,
            boxShadow: const [
              BoxShadow(
                color: Color(0x592DD4BF),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          )
        : BoxDecoration(
            color: widget.active ? const Color(0x262DD4BF) : AppColors.glass,
            borderRadius: shape,
            border: Border.all(
              color: widget.active ? const Color(0x992DD4BF) : AppColors.border,
            ),
          );
    Widget button = AnimatedScale(
      scale: _down ? 0.92 : 1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      child: SizedBox.square(
        dimension: widget.size,
        child: DecoratedBox(
          decoration: decoration,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: shape,
              onTap: widget.onPressed,
              onHighlightChanged: (v) => setState(() => _down = v),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: widget.filled
                      ? AppColors.onGradient
                      : AppColors.primary,
                ),
                child: Center(child: widget.icon),
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}

/// مقبض الورقة السفلية.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 42,
      height: 5,
      decoration: BoxDecoration(
        color: const Color(0x4DFFFFFF),
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}

/// فاصل يتلاشى من الطرفين (`.divider` في ملف التصميم).
class GlassDivider extends StatelessWidget {
  const GlassDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.transparent, AppColors.borderHi, Colors.transparent],
      ),
    ),
  );
}

/// عرض ورقة سفلية زجاجية عائمة (هامش 8، زوايا 32، ضبابية حقيقية).
///
/// بديل موحّد لـ`showModalBottomSheet` في الإعدادات والمشاركة والأجهزة —
/// المحتوى نفسه بلا تغيير، فقط الإطار.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    // صعود نابضي (`--spring`) ونزول أهدأ عند الإغلاق
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 380),
      reverseDuration: Duration(milliseconds: 240),
      curve: designSpring,
      reverseCurve: Curves.easeInCubic,
    ),
    // الورقة الطويلة (الإعدادات) كانت تمتد تحت شريط حالة الهاتف فيختفي
    // مقبضها وأعلاها خلف الساعة والأيقونات — رُصد على هاتف المستخدم.
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: GlassSurface(
        blur: true,
        radius: 32,
        color: const Color(0xB8101C30),
        borderColor: AppColors.borderHi,
        // طبقة Material شفافة فوق الزجاج: ListTile/SwitchListTile يرسمان
        // خلفيتهما وتموّج اللمس على أقرب Material — بدونها تخفيها التعبئة.
        child: Material(
          type: MaterialType.transparency,
          child: Builder(builder: builder),
        ),
      ),
    ),
  );
}

/// يرسم تدرّجاً خلف `FilledButton` عادي — يبقى الزر نفسه (حالة التعطيل،
/// الاختبارات، إمكانية الوصول) ويأخذ مظهر «filled/success» في ملف التصميم.
///
/// الزر الداخلي يجب ألا يحدّد `backgroundColor` بنفسه — وإلا غطّى التدرّج.
class GradientFilled extends StatelessWidget {
  const GradientFilled({
    super.key,
    required this.child,
    this.gradient = AppGradients.brand,
    this.foreground = AppColors.onGradient,
    this.radius = 21,
    this.enabled = true,
    this.glow = const Color(0x472DD4BF),
  });

  final Widget child;
  final Gradient gradient;
  final Color foreground;
  final double radius;
  final bool enabled;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(color: glow, blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: FilledButtonTheme(
          data: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              foregroundColor: foreground,
              disabledForegroundColor: foreground,
              shadowColor: Colors.transparent,
              shape: shape,
              textStyle: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// شريط عنوان زجاجي عائم (`.appbar` في ملف التصميم): هامش 10، زوايا 22،
/// ارتفاع 60. بلا ضبابية حقيقية: لا محتوى يمر خلفه، فكانت كلفة كل إطار بلا أثر. زر الرجوع يستعمل `maybePop` فيحترم
/// أي `PopScope` في الشاشة (مثل تأكيد الخروج من الفاتورة).
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({super.key, required this.title, this.actions = const []});

  final Widget title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(74);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
        child: GlassSurface(
          radius: 22,
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                const SizedBox(width: 4),
                if (canPop)
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    color: AppColors.textSecondary,
                    icon: const BackButtonIcon(),
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                else
                  const SizedBox(width: 8),
                Expanded(
                  child: DefaultTextStyle.merge(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    child: title,
                  ),
                ),
                ...actions,
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// حوار زجاجي يظهر بتكبير نابضي من .92 مع تلاشٍ (`.dialog.show` في ملف
/// التصميم) بدل التلاشي المجرّد الافتراضي.
///
/// نفس توقيع `showDialog` المستعمل في التطبيق — المحتوى (`AlertDialog`) لا
/// يتغيّر، فقط طريقة ظهوره. الضغط خارجه يُغلقه ما دام [barrierDismissible].
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x8C02060E),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, _, _) => Builder(builder: builder),
    transitionBuilder: (ctx, animation, _, child) {
      final reduce = MediaQuery.maybeDisableAnimationsOf(ctx) ?? false;
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      if (reduce) return FadeTransition(opacity: fade, child: child);
      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: Tween(begin: .92, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: designSpring,
              reverseCurve: Curves.easeInCubic,
            ),
          ),
          child: child,
        ),
      );
    },
  );
}
