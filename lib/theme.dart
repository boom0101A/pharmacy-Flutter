import 'package:flutter/material.dart';

/// لوحة «Liquid Glass» — من ملف التصميم `صيدليتي Liquid Glass.html`.
///
/// الأسماء نفسها كاللوحة السابقة (مئات الاستعمالات لا تتغيّر)، والقيم جديدة.
/// [bgCard] سطح زجاجي **مرتفع** شبه معتم (الحوارات والأوراق وأشرطة العناوين)
/// — مقروء فوق أي شيء خلفه. [glass] هو الزجاج الخفيف للبطاقات والحقول.
class AppColors {
  static const primary = Color(0xFF2DD4BF);
  static const primary2 = Color(0xFF38BDF8);
  static const success = Color(0xFF34D399);
  static const danger = Color(0xFFFB7185);
  static const warning = Color(0xFFFBBF24);
  static const violet = Color(0xFFA78BFA);

  static const bgDark = Color(0xFF06101E);

  /// سطح مرتفع: الحوارات، الأوراق السفلية، أشرطة العناوين — rgba(18,30,52,.86).
  static const bgCard = Color(0xDB121E34);

  /// زجاج خفيف — البطاقات والحقول والكبسولات (rgba(255,255,255,.075)).
  static const glass = Color(0x13FFFFFF);

  /// زجاج أقوى — لوحة الفلاتر (rgba(18,30,52,.62)).
  static const glassStrong = Color(0x9E121E34);

  static const border = Color(0x21FFFFFF);
  static const borderHi = Color(0x47FFFFFF);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFFA9B8CC);
  static const textMuted = Color(0xFF7A8BA3);

  /// النص فوق الأزرار المتدرّجة (تيل/أزرق) — داكن ليُقرأ على اللون الفاتح.
  static const onGradient = Color(0xFF04201C);
}

/// التدرّجات — `--grad` وأزرار النجاح والتحذير في ملف التصميم.
class AppGradients {
  static const brand = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [AppColors.primary, AppColors.primary2],
  );
  static const success = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF6EE7B7), Color(0xFF10B981)],
  );
  static const warning = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
  );

  /// ترويسة الشاشة الرئيسية: تيل → أزرق → بنفسجي، شفافة.
  static const header = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0x382DD4BF), Color(0x1A38BDF8), Color(0x1FA78BFA)],
    stops: [0, .5, 1],
  );
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: AppColors.onGradient,
    secondary: AppColors.success,
    onSecondary: Color(0xFF032B1E),
    error: AppColors.danger,
    surface: AppColors.bgCard,
    onSurface: AppColors.textPrimary,
  );

  OutlineInputBorder field(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: width),
      );

  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(21));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // الخلفية الحيّة (الشفق) مرسومة تحت كل الشاشات في main.dart
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: AppColors.bgDark,
    fontFamily: 'Cairo',
    textTheme: const TextTheme().apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.glass,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.glass,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: field(AppColors.border),
      enabledBorder: field(AppColors.border),
      focusedBorder: field(const Color(0xB32DD4BF), 1.4),
      errorBorder: field(AppColors.danger),
      focusedErrorBorder: field(AppColors.danger, 1.4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onGradient,
        shape: pill,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        backgroundColor: const Color(0x0FFFFFFF),
        side: const BorderSide(color: AppColors.border),
        shape: pill,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: pill,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.glass,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.onGradient
              : AppColors.textSecondary,
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0x0FFFFFFF),
      selectedColor: const Color(0x332DD4BF),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? const Color(0xFF10B981)
            : const Color(0x1FFFFFFF),
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Colors.transparent
            : AppColors.border,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.bgCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: const BorderSide(color: AppColors.borderHi),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.bgCard,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Color(0x7302060E),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xC7142036),
      contentTextStyle: const TextStyle(
        fontFamily: 'Cairo',
        color: AppColors.textPrimary,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.borderHi),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border),
  );
}
