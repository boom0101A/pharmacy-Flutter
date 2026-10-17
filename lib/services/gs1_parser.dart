/// تفكيك رموز GS1 (DataMatrix / GS1-128) المطبوعة على علب الأدوية.
///
/// الرمز الواحد يحمل عدة حقول، كل حقل مسبوق بـ «معرّف تطبيق» (AI):
///
///     01 06281234567890  17 270630  10 ABC123  21 SN99871
///     └────GTIN──────┘  └الصلاحية┘ └الوجبة┘  └التسلسلي┘
///
/// بدون تفكيك، يُستخدم النص كاملاً كباركود — فلا يطابق أي قاعدة بيانات،
/// والأسوأ أن الرقم التسلسلي (21) فريد لكل علبة، فتصبح كل علبة دواءً منفصلاً.
library;

class Gs1Result {
  /// رقم المنتج بصيغة GTIN-14 — المفتاح المعياري للبحث.
  final String? gtin;

  final DateTime? expiryDate;
  final String? batch;
  final String? serial;

  /// النص كما ورد من الماسح.
  final String raw;

  /// هل تعرّفنا عليه كرمز GS1 مركّب؟
  final bool isGs1;

  const Gs1Result({
    required this.raw,
    required this.isGs1,
    this.gtin,
    this.expiryDate,
    this.batch,
    this.serial,
  });

  /// الباركود الذي يُخزَّن ويُبحث به.
  /// لرموز GS1 هو الـ GTIN، ولغيرها النص كما هو بعد التنظيف.
  String get barcode => gtin ?? raw.trim();

  bool get hasExtraData =>
      expiryDate != null || batch != null || serial != null;

  @override
  String toString() =>
      'Gs1Result(gtin: $gtin, exp: $expiryDate, batch: $batch, '
      'serial: $serial, isGs1: $isGs1)';
}

class Gs1Parser {
  Gs1Parser._();

  /// محرف الفصل FNC1 الذي ينهي الحقول متغيّرة الطول.
  static const _gs = '';

  /// أطوال البيانات للمعرّفات ثابتة الطول (الطول لا يشمل المعرّف نفسه).
  static const Map<String, int> _fixedLength = {
    '00': 18,
    '01': 14,
    '02': 14,
    '03': 14,
    '04': 16,
    '11': 6, // تاريخ الإنتاج
    '12': 6, // تاريخ الاستحقاق
    '13': 6, // تاريخ التعبئة
    '15': 6, // يُفضّل استخدامه قبل
    '16': 6, // يُباع قبل
    '17': 6, // تاريخ انتهاء الصلاحية
    '20': 2,
  };

  /// معرّفات متغيّرة الطول نهتم بها (الحد الأقصى للطول).
  static const Map<String, int> _variableLength = {
    '10': 20, // رقم الوجبة
    '21': 20, // الرقم التسلسلي
    '22': 20,
    '30': 8,
    '37': 8,
    '240': 30,
    '241': 30,
    '250': 30,
    '251': 30,
    '253': 30,
    '254': 20,
    '400': 30,
    '401': 30,
    '710': 20,
    '711': 20,
    '712': 20,
    '713': 20,
    '714': 20,
    '7003': 10,
  };

  /// النقطة الرئيسية: يحوّل ناتج الماسح إلى نتيجة مفهومة.
  ///
  /// آمن دائماً — إن لم يكن النص رمز GS1 يُعاد كما هو دون تعديل.
  static Gs1Result parse(String rawInput) {
    final raw = rawInput.trim();
    if (raw.isEmpty) return Gs1Result(raw: raw, isGs1: false);

    // 1) باركود خطي بسيط (EAN/UPC): أرقام فقط بطول معياري
    if (_isPlainGtin(raw)) {
      return Gs1Result(raw: raw, isGs1: false, gtin: _toGtin14(raw));
    }

    // 2) تنظيف: معرّف الترميز في البداية + صيغة الأقواس (01)...(17)...
    var body = _stripSymbologyId(raw);
    final hadParens = body.contains('(');
    if (hadParens) body = body.replaceAll(RegExp(r'[()]'), '');

    final fields = _parseElementString(body, parenthesised: hadParens);

    // 3) لا معرّفات صالحة ⇒ ليس GS1، نُعيده كما ورد
    if (fields.isEmpty || !fields.containsKey('01')) {
      return Gs1Result(raw: raw, isGs1: false);
    }

    final gtinRaw = fields['01']!;
    // شرط صارم: لا نقبل GTIN لا يجتاز خانة التحقق — الخطأ هنا يفسد البيانات
    if (!isValidGtin(gtinRaw)) {
      return Gs1Result(raw: raw, isGs1: false);
    }

    return Gs1Result(
      raw: raw,
      isGs1: true,
      gtin: _toGtin14(gtinRaw),
      expiryDate: _parseDate(fields['17']),
      batch: _clean(fields['10']),
      serial: _clean(fields['21']),
    );
  }

  // -----------------------------------------------------------------
  //  التفكيك
  // -----------------------------------------------------------------

  static Map<String, String> _parseElementString(
    String s, {
    required bool parenthesised,
  }) {
    final out = <String, String>{};
    var i = 0;

    while (i < s.length) {
      // تخطّي الفواصل المتتالية
      if (s[i] == _gs) {
        i++;
        continue;
      }

      final ai = _readAi(s, i);
      if (ai == null) break; // معرّف غير معروف ⇒ نتوقف بما جمعناه
      i += ai.length;

      final fixed = _fixedLength[ai];
      if (fixed != null) {
        if (i + fixed > s.length) break; // بيانات ناقصة ⇒ نتوقف بأمان
        out[ai] = s.substring(i, i + fixed);
        i += fixed;
        continue;
      }

      // حقل متغيّر الطول: ينتهي بفاصل GS، أو بنهاية النص،
      // أو — في صيغة الأقواس — عند بداية معرّف تالٍ صالح.
      final max = _variableLength[ai] ?? 30;
      var end = s.indexOf(_gs, i);
      if (end < 0) {
        end = parenthesised ? _findNextAi(s, i, max) : s.length;
      }
      if (end - i > max) end = i + max;
      out[ai] = s.substring(i, end);
      i = end;
    }

    return out;
  }

  /// قراءة معرّف التطبيق عند الموضع [i] — الطول 2 أو 3 أو 4.
  static String? _readAi(String s, int i) {
    for (final len in [4, 3, 2]) {
      if (i + len > s.length) continue;
      final candidate = s.substring(i, i + len);
      if (!_isDigits(candidate)) continue;
      if (_fixedLength.containsKey(candidate) ||
          _variableLength.containsKey(candidate)) {
        return candidate;
      }
      // معرّفات الأوزان والأبعاد: 3100..3969 (رقم عشري في الخانة الرابعة)
      if (len == 4 && RegExp(r'^3[0-9]{2}[0-9]$').hasMatch(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  /// في صيغة الأقواس لا يوجد فاصل، فنبحث عن بداية معرّف صالح تالٍ.
  static int _findNextAi(String s, int from, int max) {
    final limit = (from + max) < s.length ? from + max : s.length;
    for (var j = from + 1; j <= limit; j++) {
      if (_readAi(s, j) != null) return j;
    }
    return limit;
  }

  // -----------------------------------------------------------------
  //  أدوات مساعدة
  // -----------------------------------------------------------------

  static final _digitsOnly = RegExp(r'^\d+$');
  static bool _isDigits(String s) => _digitsOnly.hasMatch(s);

  static String _stripSymbologyId(String s) =>
      s.startsWith(']') && s.length > 3 ? s.substring(3) : s;

  static bool _isPlainGtin(String s) =>
      RegExp(r'^\d{8}$|^\d{12}$|^\d{13}$|^\d{14}$').hasMatch(s) &&
      isValidGtin(s);

  static String? _clean(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  /// توحيد الصيغة إلى GTIN-14 بإضافة أصفار بادئة.
  static String _toGtin14(String gtin) => gtin.padLeft(14, '0');

  /// صيغ البحث المحتملة لنفس المنتج: GTIN-14 و EAN-13 و UPC-12.
  /// لازمة لأن قواعد البيانات تخزّنه بصيغ مختلفة.
  static List<String> lookupVariants(String barcode) {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return const [];
    if (!_isDigits(trimmed)) return [trimmed];

    final stripped = trimmed.replaceFirst(RegExp(r'^0+'), '');
    final variants = <String>{
      trimmed,
      stripped,
      stripped.padLeft(12, '0'),
      stripped.padLeft(13, '0'),
      stripped.padLeft(14, '0'),
    };
    variants.removeWhere((v) => v.isEmpty);
    return variants.toList();
  }

  /// التحقق من خانة المراجعة وفق معيار GS1 (mod-10).
  static bool isValidGtin(String s) {
    if (!RegExp(r'^\d{8}$|^\d{12}$|^\d{13}$|^\d{14}$').hasMatch(s)) {
      return false;
    }
    final digits = s.split('').map(int.parse).toList();
    final check = digits.removeLast();
    var sum = 0;
    var weight = 3;
    for (var i = digits.length - 1; i >= 0; i--) {
      sum += digits[i] * weight;
      weight = weight == 3 ? 1 : 3;
    }
    return (10 - (sum % 10)) % 10 == check;
  }

  /// تاريخ GS1 بصيغة YYMMDD. اليوم 00 يعني آخر يوم في الشهر.
  /// قاعدة القرن المعيارية: 00–50 ⇒ 20xx، و51–99 ⇒ 19xx.
  static DateTime? _parseDate(String? yymmdd) {
    if (yymmdd == null || yymmdd.length != 6 || !_isDigits(yymmdd)) return null;

    final yy = int.parse(yymmdd.substring(0, 2));
    final mm = int.parse(yymmdd.substring(2, 4));
    var dd = int.parse(yymmdd.substring(4, 6));

    if (mm < 1 || mm > 12) return null;

    final year = yy <= 50 ? 2000 + yy : 1900 + yy;
    if (dd == 0) {
      // آخر يوم في الشهر
      return DateTime(year, mm + 1, 0);
    }
    final lastDay = DateTime(year, mm + 1, 0).day;
    if (dd > lastDay) dd = lastDay;
    return DateTime(year, mm, dd);
  }
}
