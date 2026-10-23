import 'package:flutter/material.dart';

/// انتقال موحّد بين شاشات التطبيق: تلاشٍ مع انزلاق خفيف من اليمين.
///
/// الانتقال الافتراضي في أندرويد يرفع الشاشة من الأسفل بمسافة كبيرة، وهو ثقيل
/// بصرياً في تطبيق يُفتح فيه النموذج والماسح عشرات المرات يومياً. الانزلاق
/// القصير أسرع إدراكاً ويحترم اتجاه الواجهة من اليمين إلى اليسار.
///
/// المسافة صغيرة عمداً (6% من العرض) — الحركة الطويلة تبدو بطيئة بعد المرة
/// العاشرة، والمستخدم هنا مدخل بيانات لا زائر.
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  SmoothPageRoute({required this.builder, super.settings})
    : super(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondary, child) {
          // منحنى `--ease` في ملف التصميم: cubic-bezier(.215,.61,.355,1)
          final curved = CurvedAnimation(
            parent: animation,
            curve: const Cubic(.215, .61, .355, 1),
            reverseCurve: Curves.easeInCubic,
          );

          // تلاشٍ + انزلاق 6% + تكبير من .985 (`.screen.hidden`) — بلا ضبابية
          // الانتقال الموجودة في الملف: ثقيلة على الهاتف لكل فتح شاشة.
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(curved),
              child: ScaleTransition(
                scale: Tween(begin: .985, end: 1.0).animate(curved),
                child: child,
              ),
            ),
          );
        },
      );

  final WidgetBuilder builder;
}
