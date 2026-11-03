import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medicine.dart';
import 'app_settings.dart';
import 'gs1_parser.dart';
import '../l10n/l10n.dart';

/// سطر واحد استُخرج من صورة فاتورة.
///
/// كل الحقول الاختيارية `nullable`: قد لا يقرأ Gemini كل شيء من كل سطر،
/// والمراجعة اليدوية في شاشة الفاتورة تكمّل الناقص وتصحّح المشتبه به.
class InvoiceLine {
  InvoiceLine({
    required this.name,
    this.price,
    this.quantity,
    this.barcode,
    this.expiry,
    this.category,
    this.company,
    this.bonus,
    this.lineTotal,
    this.uncertain = false,
  });

  final String name;
  final double? price;
  final int? quantity;
  final String? barcode;

  /// نص التاريخ كما ظهر في الفاتورة — يُحوَّل لاحقاً حين يعبث المستخدم بالحقل.
  final String? expiry;

  /// الشكل الصيدلاني للمستلزمات (Tablet/Cream/Syrup/Drops/...) — يظهر في
  /// عمود «نوع المواد» في فواتير المجهّزين ويُحفظ كما هو بلا ترجمة.
  final String? category;

  /// الشركة المصنّعة أو الوكيل كما طُبعت في السطر أو عمودها.
  final String? company;

  /// الكمية المجانية (بونص) — تصل للرف فعلاً فتُضاف للكمية عند الحفظ.
  final int? bonus;

  /// مجموع السطر كما طُبع — للتحقق من الكمية × السعر.
  final double? lineTotal;

  /// علَّمه Gemini بنفسه: سطر غير واضح في الصورة.
  final bool uncertain;

  InvoiceLine withoutBarcode() => InvoiceLine(
    name: name,
    price: price,
    quantity: quantity,
    expiry: expiry,
    category: category,
    company: company,
    bonus: bonus,
    lineTotal: lineTotal,
    uncertain: uncertain,
  );
}

/// مشكلة معروفة في سطر مقروء — تُعرض كشارة في المراجعة.
enum LineIssue {
  invalidBarcode,
  totalMismatch,
  missingPrice,
  missingQuantity,
  uncertain,

  /// أقل من 100 دينار — مستحيل بالدينار العراقي، والأرجح أن فاصلة الآلاف
  /// قُرئت عشرية («1,100» ← 1.1).
  suspiciousPrice;

  /// بلغة الواجهة.
  String get label {
    final l = L10n.current;
    return switch (this) {
      invalidBarcode => l.issueInvalidBarcode,
      totalMismatch => l.issueTotalMismatch,
      missingPrice => l.issueMissingPrice,
      missingQuantity => l.issueMissingQty,
      uncertain => l.issueUncertain,
      suspiciousPrice => l.issueSuspiciousPrice,
    };
  }
}

/// سطر بعد التحقق: قد يُعدَّل (حذف باركود غير صالح) مع قائمة مشكلاته.
class ValidatedLine {
  const ValidatedLine(this.line, this.issues);
  final InvoiceLine line;
  final List<LineIssue> issues;
}

/// رأس الفاتورة كما طُبع — كل حقل null إن لم يظهر (بلا تخمين).
class InvoiceHeader {
  const InvoiceHeader({this.supplier, this.number, this.date, this.total});

  /// اسم المجهّز/المذخر.
  final String? supplier;
  final String? number;

  /// نص التاريخ كما طُبع — يُحوَّل في الشاشة حين يمكن.
  final String? date;

  /// المجموع النهائي المطبوع.
  final double? total;

  bool get isEmpty =>
      supplier == null && number == null && date == null && total == null;
}

/// نتيجة قراءة صورة فاتورة.
class InvoiceResult {
  const InvoiceResult._(
    this.ok,
    this.lines,
    this.error, {
    this.usedFallback = false,
    this.header,
  });

  final bool ok;
  final List<InvoiceLine> lines;
  final String? error;

  /// قُرئت بالنموذج البديل لأن الأساسي نفدت حصته أو بقي مزدحماً — تُنبَّه
  /// الواجهة لمراجعة الأسطر بانتباه أكبر.
  final bool usedFallback;

  /// الرأس — يُستخرج في الطلب نفسه، بلا استهلاك إضافي للحصة.
  final InvoiceHeader? header;

  factory InvoiceResult.success(
    List<InvoiceLine> lines, {
    bool usedFallback = false,
    InvoiceHeader? header,
  }) => InvoiceResult._(
    true,
    lines,
    null,
    usedFallback: usedFallback,
    header: header,
  );
  factory InvoiceResult.failure(String reason) =>
      InvoiceResult._(false, const [], reason);

  InvoiceResult _viaFallback() => ok
      ? InvoiceResult.success(lines, usedFallback: true, header: header)
      : this;
}

/// سبب فشل القراءة بنموذج واحد — يقرّر الانتقال إلى البديل.
enum _Failure { none, dailyQuota, busy, other }

/// نتيجة قراءة بنموذج واحد مع سبب الفشل وموعد تجدد الحصة إن عُرف.
typedef _ModelRead = ({
  InvoiceResult result,
  _Failure failure,
  Duration? retryAfter,
});

/// عميل Google Gemini للفواتير — الصورة تُرسَل إلى endpoint النموذج [_model]
/// مع مخطط JSON صارم يجبر النموذج على إعادة أسطر منظّمة
/// بدل نص حرّ يحتاج تحليلاً هشّاً.
///
/// **لا يرمي استثناء أبداً:** كل حالات الفشل تُعاد كـ `InvoiceResult.failure`
/// برسالة عربية واضحة، فلا يعطّل خطأ الشبكة أو انتهاء المهلة الواجهة.
class GeminiVision {
  GeminiVision._();

  /// الأساسي — اختيار المستخدم (2026-10-21) لأنه الأسرع بنفس الدقة: على
  /// فاتورة حقيقية (28 سطراً) 28/28 صحيحة في 6.4 ثانية مقابل ~9.6 ثانية
  /// لـ 3.6-flash. قيس أيضاً: 3.7/3.8-flash دقيقان لكن 150–290 ثانية،
  /// و3.1-flash-lite أهمل الأسعار كلها.
  static const _model = 'gemini-3.5-flash-lite';

  /// البديل الاحتياطي فقط: عند نفاد حصة الأساسي اليومية أو بقائه مزدحماً.
  /// كان الأساسي سابقاً (28/28 على نفس الفاتورة)، وحصته المجانية مستقلة.
  static const _fallbackModel = 'gemini-3.6-flash';

  static const _apiBase =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// موعد تجدد حصة الأساسي — يُحفظ فيبقى بعد إغلاق التطبيق، فلا تُهدر
  /// محاولة على نموذج نعرف أن حصته منتهية.
  ///
  /// المفتاح يحمل اسم النموذج: موعد محفوظ لأساسي سابق (قبل تبديل
  /// النموذجين) لا يحظر الأساسي الحالي بالخطأ.
  static const _kPrimaryBlockedUntil = 'gemini_primary_blocked_until:$_model';

  /// الحد الأقصى لحجم الصورة المرسلة — Gemini يقبل حتى 20MB لكن صورة فاتورة
  /// عادية أقل من 2MB. نمنع تصعيد أي صورة كبيرة عرضاً كي لا يفشل الطلب.
  static const _maxBytes = 7 * 1024 * 1024;

  /// سقف أمان فقط: مع التفكير المنخفض تُقرأ الصفحة عادةً في ثوانٍ. كان 90
  /// ثانية مع التفكير الافتراضي فتنقطع الفواتير الكثيفة بـ TimeoutException.
  static const Duration _timeout = Duration(seconds: 180);

  static bool get isConfigured => AppSettings.instance.hasGeminiKey;

  /// يقرأ فاتورة من ملف على القرص.
  static Future<InvoiceResult> readInvoice(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return await readInvoiceBytes(bytes);
    } catch (e) {
      return InvoiceResult.failure(L10n.current.gmImageReadFailed('$e'));
    }
  }

  /// يقرأ فاتورة من بايتات مباشرة — نقطة الدخول الوحيدة القابلة للاختبار.
  static Future<InvoiceResult> readInvoiceBytes(Uint8List bytes) async {
    if (!isConfigured) {
      return InvoiceResult.failure(L10n.current.gmNotConfigured);
    }
    if (bytes.length > _maxBytes) {
      return InvoiceResult.failure(
        L10n.current.gmTooLarge(_maxBytes ~/ (1024 * 1024)),
      );
    }

    final body = jsonEncode(buildRequest(bytes));
    final headers = requestHeaders(AppSettings.instance.geminiKey);

    // حصة الأساسي معروفة النفاد حتى موعد تجددها — مباشرة إلى البديل
    final blockedUntil = await _primaryBlockedUntil();
    if (blockedUntil != null && now().isBefore(blockedUntil)) {
      final r = await _readWith(_fallbackModel, headers, body);
      if (r.failure == _Failure.dailyQuota) {
        return InvoiceResult.failure(
          _quotaMessage(_nearer(r.retryAfter, blockedUntil.difference(now()))),
        );
      }
      return r.result._viaFallback();
    }

    final first = await _readWith(_model, headers, body);
    if (first.failure != _Failure.dailyQuota &&
        first.failure != _Failure.busy) {
      return first.result;
    }
    if (first.failure == _Failure.dailyQuota) {
      await _setPrimaryBlockedUntil(
        now().add(first.retryAfter ?? const Duration(hours: 24)),
      );
    }

    final second = await _readWith(_fallbackModel, headers, body);
    if (second.failure == _Failure.dailyQuota &&
        first.failure == _Failure.dailyQuota) {
      return InvoiceResult.failure(
        _quotaMessage(_nearer(first.retryAfter, second.retryAfter)),
      );
    }
    // نجاح البديل، أو فشله لسبب آخر — رسالته هي الأصدق عن حال الخدمة الآن
    return second.result._viaFallback();
  }

  /// قراءة بنموذج واحد مع إعادة المحاولة على الأخطاء العابرة.
  ///
  /// خوادم Google تردّ 503 «ضغط عالٍ» على فترات (قيس فعلياً: خمس مرات
  /// متتالية قبل النجاح). نعيد المحاولة على العابر وحده؛ خطأ دائم (مفتاح
  /// خاطئ، طلب مرفوض) يفشل فوراً، ونفاد الحصة اليومية لا يُعاد أبداً.
  static Future<_ModelRead> _readWith(
    String model,
    Map<String, String> headers,
    String body,
  ) async {
    try {
      var attempt = 0;
      while (true) {
        final response = await _post(requestUriFor(model), headers, body);
        if (response.statusCode == 200) {
          return (
            result: parseResponse(response.body),
            failure: _Failure.none,
            retryAfter: null,
          );
        }

        if (response.statusCode == 429) {
          final quota = quotaInfo(response.body);
          if (quota.daily) {
            return (
              result: InvoiceResult.failure(_explainHttpError(response)),
              failure: _Failure.dailyQuota,
              retryAfter: quota.retryAfter,
            );
          }
        }
        final transient = _transientStatuses.contains(response.statusCode);
        if (!transient || attempt >= retryDelays.length) {
          return (
            result: InvoiceResult.failure(_explainHttpError(response)),
            failure: transient ? _Failure.busy : _Failure.other,
            retryAfter: null,
          );
        }
        await sleep(retryDelays[attempt]);
        attempt++;
      }
    } on TimeoutException {
      return _otherFailure(L10n.current.gmTimeout);
    } on SocketException {
      return _otherFailure(L10n.current.gmNoInternet);
    } on http.ClientException catch (e) {
      return _otherFailure(L10n.current.gmConnectFailed(e.message));
    } catch (e) {
      return _otherFailure(L10n.current.gmUnexpected('$e'));
    }
  }

  static _ModelRead _otherFailure(String message) => (
    result: InvoiceResult.failure(message),
    failure: _Failure.other,
    retryAfter: null,
  );

  static Duration? _nearer(Duration? a, Duration? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a < b ? a : b;
  }

  static Future<DateTime?> _primaryBlockedUntil() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_kPrimaryBlockedUntil);
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _setPrimaryBlockedUntil(DateTime until) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPrimaryBlockedUntil, until.millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// حالات عابرة تستحق إعادة المحاولة: ضغط على الخادم أو أخطاؤه، أو طلبات
  /// كثيرة في وقت قصير.
  static const _transientStatuses = {429, 500, 502, 503, 504};

  /// الانتظار قبل كل إعادة محاولة — ثلاث محاولات إجمالاً.
  @visibleForTesting
  static List<Duration> retryDelays = _defaultRetryDelays;
  static const _defaultRetryDelays = [
    Duration(seconds: 3),
    Duration(seconds: 8),
  ];

  /// قابلان للاستبدال في الاختبار فقط: عميل HTTP وهمي، وانتظار بلا تأخير.
  @visibleForTesting
  static http.Client? httpClient;
  @visibleForTesting
  static Future<void> Function(Duration) sleep = Future.delayed;

  /// الساعة — قابلة للاستبدال في الاختبار لمحاكاة تجدد الحصة.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  @visibleForTesting
  static void resetTransport() {
    httpClient = null;
    sleep = Future.delayed;
    retryDelays = _defaultRetryDelays;
    now = DateTime.now;
  }

  static Future<http.Response> _post(
    Uri url,
    Map<String, String> headers,
    String body,
  ) {
    final client = httpClient;
    final request = client == null
        ? http.post(url, headers: headers, body: body)
        : client.post(url, headers: headers, body: body);
    return request.timeout(_timeout);
  }

  /// عنوان الطلب **بلا المفتاح**: المفتاح في رابط الطلب كان يظهر داخل رسائل
  /// خطأ الاتصال (`ClientException` تطبع الرابط) فيُعرض على الشاشة.
  @visibleForTesting
  static Uri get requestUri => requestUriFor(_model);

  @visibleForTesting
  static Uri requestUriFor(String model) =>
      Uri.parse('$_apiBase/$model:generateContent');

  @visibleForTesting
  static Map<String, String> requestHeaders(String key) => {
    'Content-Type': 'application/json',
    'x-goog-api-key': key,
  };

  /// نوع الصورة من أول بايتاتها — صورة PNG من المعرض كانت تُرسَل كـ JPEG.
  @visibleForTesting
  static String mimeTypeOf(Uint8List b) {
    if (b.length >= 4 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47) {
      return 'image/png';
    }
    if (b.length >= 12 &&
        String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  /// يبني حمولة الطلب لـ Gemini بمخطط JSON structured output.
  @visibleForTesting
  static Map<String, Object?> buildRequest(Uint8List bytes) => {
    'contents': [
      {
        'parts': [
          {
            'inline_data': {
              'mime_type': mimeTypeOf(bytes),
              'data': base64Encode(bytes),
            },
          },
          {'text': _invoicePrompt},
        ],
      },
    ],
    'generationConfig': {
      'temperature': 0.05,
      // النموذج «يفكّر» قبل الرد افتراضياً: على فاتورة كثيفة تجاوز التفكير مع
      // الإخراج 90 ثانية. «low» قِيس: 7.7ث ← 2.4ث، ويُبقي تفكيراً كافياً
      // لقراءة الأعمدة (minimal أسرع قليلاً لكنه يُلغيه تقريباً).
      'thinkingConfig': {'thinkingLevel': 'low'},
      // حدّ النموذج الفعلي — فاتورة بعشرات الأسطر لا تُقطع في منتصف الـ JSON
      'maxOutputTokens': 65536,
      'response_mime_type': 'application/json',
      'response_schema': _invoiceSchema,
    },
  };

  static const _invoicePrompt = '''
هذه صورة صفحة من فاتورة مجهّز أدوية ومستلزمات طبية (عربية أو إنجليزية أو
مختلطة). استخرج **كل سطر مادة** كعنصر منفصل وبنفس ترتيب الفاتورة. تجاهل
الترويسة واسم المجهّز والتذييل وصفوف المجموع والخصم والضريبة.

الأرقام قد تكون عربية-هندية (٠١٢٣٤٥٦٧٨٩) — أعدها أرقاماً عادية.

لكل سطر:
- name: اسم المادة كما ظهر حرفياً مع التركيز والحجم (مثل 500mg، 100 ml).
- quantity: الكمية المشتراة (عدد صحيح)، **بلا** الكمية المجانية.
- bonus: الكمية المجانية إن وُجد عمود «بونص» أو «مجاني» أو «Free» أو «Bonus»،
  وإلا null.
- price: **سعر شراء الوحدة** لا سعر البيع ولا مجموع السطر. إن ظهر المجموع فقط
  فاقسمه على الكمية.
- line_total: مجموع السطر كما طُبع إن وُجد، وإلا null.
- **الأسعار والمجاميع نصّاً كما طُبعت حرفياً بفواصلها** («1,100» لا 1.1):
  الفاصلة في الدينار العراقي فاصلة آلاف، ولا كسور فيه.
- barcode: فقط إن كان الباركود مطبوعاً **في نفس السطر**. لا تنسخه من سطر مجاور
  ولا تخمّنه. إن لم يوجد فـ null.
- expiry: تاريخ الصلاحية كما ظهر في السطر بلا تحويل، وإلا null.
- category: الشكل الصيدلاني إن وُجد له عمود (Tablet/Cream/Syrup/Drops/...)
  كما هو حرفياً بلا ترجمة، وإلا null — لا تخترعه.
- company: اسم الشركة المصنّعة أو الوكيل إن ظهر في السطر أو في عمود «الشركة»
  أو «Company» أو «Manufacturer» (مثل Juman)، كما هو حرفياً، وإلا null.
- uncertain: true إن كان أي جزء من السطر مقطوعاً أو مطموساً أو غير مقروء
  بوضوح، وإلا false.

ورأس الفاتورة في header (مرة واحدة، من أعلى الصفحة أو أسفلها):
- supplier: اسم المجهّز أو المذخر أو الشركة البائعة كما طُبع.
- invoice_number: رقم الفاتورة كما طُبع.
- date: تاريخ الفاتورة كما طُبع بلا تحويل.
- total: مجموع **هذه الفاتورة وحدها** («المجموع بعد الخصم» أو «سعر القائمة»
  أو «المجموع»)، نصّاً كما طُبع بفواصله. **ليس** «الديون القديمة» ولا «الدين
  الكلي» ولا «الرصيد» — تلك ديون حساب المجهّز لا قيمة الفاتورة.
أي حقل لا يظهر بوضوح اتركه null — لا تخمّن ولا تحسب المجموع بنفسك.

لا تُضف مواد ليست في الصورة. القيمة غير المؤكدة اتركها null.
''';

  static const Map<String, Object?> _invoiceSchema = {
    'type': 'OBJECT',
    'properties': {
      'lines': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'name': {'type': 'STRING'},
            // نصاً كما طُبع: رقماً كان النموذج يقرأ «1,100» ← 1.1
            'price': {'type': 'STRING', 'nullable': true},
            'quantity': {'type': 'INTEGER', 'nullable': true},
            'barcode': {'type': 'STRING', 'nullable': true},
            'expiry': {'type': 'STRING', 'nullable': true},
            'category': {'type': 'STRING', 'nullable': true},
            'company': {'type': 'STRING', 'nullable': true},
            'bonus': {'type': 'INTEGER', 'nullable': true},
            'line_total': {'type': 'STRING', 'nullable': true},
            'uncertain': {'type': 'BOOLEAN'},
          },
          'required': ['name'],
        },
      },
      // رأس الفاتورة في الطلب نفسه — بلا استهلاك إضافي للحصة
      'header': {
        'type': 'OBJECT',
        'nullable': true,
        'properties': {
          'supplier': {'type': 'STRING', 'nullable': true},
          'invoice_number': {'type': 'STRING', 'nullable': true},
          'date': {'type': 'STRING', 'nullable': true},
          'total': {'type': 'STRING', 'nullable': true},
        },
      },
    },
    'required': ['lines'],
  };

  /// دالة عامة قابلة للاختبار: تفكيك ردّ Gemini إلى قائمة أسطر.
  @visibleForTesting
  static InvoiceResult parseResponse(String responseBody) {
    try {
      final root = jsonDecode(responseBody) as Map<String, Object?>;
      final candidates = root['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return InvoiceResult.failure(L10n.current.gmEmpty);
      }
      final first = candidates.first as Map;
      // ردّ مقطوع عند حدّ التوكنات = JSON ناقص لا يُفهم؛ رسالة صريحة أنفع
      if (first['finishReason'] == 'MAX_TOKENS') {
        return InvoiceResult.failure(L10n.current.gmCutOff);
      }
      final parts = ((first['content'] as Map?)?['parts'] as List?) ?? const [];
      // نماذج «التفكير» قد تسبق الجواب بأجزاء تفكير — الجواب أول نص غيرها
      final raw = parts
          .whereType<Map>()
          .where((p) => p['thought'] != true && p['text'] is String)
          .map((p) => p['text'] as String)
          .firstOrNull;
      if (raw == null) {
        return InvoiceResult.failure(L10n.current.gmEmpty);
      }
      return parseInvoiceJson(raw);
    } catch (e) {
      return InvoiceResult.failure(L10n.current.gmBadReply('$e'));
    }
  }

  /// تفكيك جسم JSON المُعاد من Gemini بحدّ ذاته — أُفرد ليختبَر مباشرةً
  /// بنصوص جاهزة بلا شبكة.
  @visibleForTesting
  static InvoiceResult parseInvoiceJson(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      final items = (decoded['lines'] as List?) ?? const [];
      final lines = <InvoiceLine>[];
      for (final item in items) {
        if (item is! Map) continue;
        final name = _clean(item['name']);
        if (name == null || name.isEmpty) continue;
        lines.add(
          InvoiceLine(
            name: name,
            price: _money(item['price']),
            quantity: _num(item['quantity'])?.toInt(),
            barcode: _clean(item['barcode']),
            expiry: _clean(item['expiry']),
            category: _clean(item['category']),
            company: _clean(item['company']),
            bonus: _num(item['bonus'])?.toInt(),
            lineTotal: _money(item['line_total']),
            uncertain: item['uncertain'] == true,
          ),
        );
      }
      return InvoiceResult.success(lines, header: _parseHeader(decoded));
    } catch (e) {
      return InvoiceResult.failure(L10n.current.gmBadLines('$e'));
    }
  }

  /// تحقق صِرف بعد القراءة.
  ///
  /// الباركود الذي لا يجتاز خانة التحقق يُحذف: Gemini قد يقرأه خطأً أو ينسخه
  /// من سطر مجاور، وباركود خاطئ يربط المادة بسجل آخر في المخزون.
  static ValidatedLine validateLine(InvoiceLine l) {
    final issues = <LineIssue>[];
    var line = l;
    final bc = l.barcode;
    if (bc != null && bc.isNotEmpty && !Gs1Parser.isValidGtin(bc)) {
      issues.add(LineIssue.invalidBarcode);
      line = l.withoutBarcode();
    }
    final price = l.price, qty = l.quantity, total = l.lineTotal;
    if (price != null && qty != null && total != null && total > 0) {
      if (((price * qty) - total).abs() / total > 0.01) {
        issues.add(LineIssue.totalMismatch);
      }
    }
    if (price == null || price <= 0) issues.add(LineIssue.missingPrice);
    if (qty == null || qty <= 0) issues.add(LineIssue.missingQuantity);
    if (l.uncertain) issues.add(LineIssue.uncertain);
    if (price != null && price > 0 && price < 100) {
      issues.add(LineIssue.suspiciousPrice);
    }
    return ValidatedLine(line, issues);
  }

  /// يحوّل أي حقل نص إلى string منظّف أو null.
  /// رأس تالف أو غائب لا يُسقط الأسطر — يعود null فقط.
  static InvoiceHeader? _parseHeader(Map<String, Object?> decoded) {
    final h = decoded['header'];
    if (h is! Map) return null;
    final header = InvoiceHeader(
      supplier: _clean(h['supplier']),
      number: _clean(h['invoice_number']),
      date: _clean(h['date']),
      total: _money(h['total']),
    );
    return header.isEmpty ? null : header;
  }

  /// مبلغ بالدينار كما طُبع: الفاصلة («1,100») ونقطة الآلاف («1.100»)
  /// فواصل آلاف لا كسور — لا كسور في الدينار العراقي. رقم جاهز يُقبل كما هو.
  static double? _money(Object? v) {
    if (v is num) return v.toDouble();
    var s = _clean(v);
    if (s == null) return null;
    s = s.replaceAll(RegExp(r'[,٬\s]'), '');
    if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) s = s.replaceAll('.', '');
    return double.tryParse(s);
  }

  @visibleForTesting
  static Map<String, Object?> get invoiceSchemaForTest => _invoiceSchema;

  static String? _clean(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty || s.toLowerCase() == 'null' ? null : s;
  }

  /// يحوّل أي رقم (int/double/string) إلى num، أو null إن تعذّر.
  static num? _num(Object? v) {
    if (v == null) return null;
    if (v is num) return v;
    return num.tryParse(v.toString().trim());
  }

  /// نوع حدّ 429 ومدة الانتظار كما في ردّ Google:
  /// `QuotaFailure.violations[].quotaId` (يحوي PerDay للحصة اليومية)
  /// و`RetryInfo.retryDelay` (مثل "5358s"). لا يرمي.
  @visibleForTesting
  static ({bool daily, Duration? retryAfter}) quotaInfo(String body) {
    var daily = false;
    Duration? retryAfter;
    try {
      final err = (jsonDecode(body) as Map)['error'] as Map?;
      for (final d in (err?['details'] as List?) ?? const []) {
        if (d is! Map) continue;
        for (final v in (d['violations'] as List?) ?? const []) {
          if (v is Map && '${v['quotaId']}'.contains('PerDay')) daily = true;
        }
        final delay = d['retryDelay'];
        if (delay is String && delay.endsWith('s')) {
          final secs = double.tryParse(delay.substring(0, delay.length - 1));
          if (secs != null) retryAfter = Duration(seconds: secs.round());
        }
      }
    } catch (_) {}
    return (daily: daily, retryAfter: retryAfter);
  }

  static String _quotaMessage(Duration? wait) {
    final l = L10n.current;
    return l.gmQuota(
      wait == null ? l.gmQuotaTomorrow : l.gmQuotaIn(_duration(wait)),
    );
  }

  /// «ساعة و29 دقيقة» / «12 دقيقة» (أو بالإنجليزية).
  static String _duration(Duration d) {
    final l = L10n.current;
    final h = d.inHours, m = d.inMinutes % 60;
    if (h == 0) return l.durMinutes(m < 1 ? 1 : m);
    final hours = l.durHours(h);
    return m == 0 ? hours : l.durHoursMinutes(hours, l.durMinutes(m));
  }

  static String _explainHttpError(http.Response r) {
    // بعد استنفاد المحاولات: رسالة عربية بما يفعله المستخدم، لا نص Google الخام
    if (r.statusCode == 429) {
      final q = quotaInfo(r.body);
      if (q.daily) return _quotaMessage(q.retryAfter);
      return L10n.current.gmTooMany;
    }
    if (_transientStatuses.contains(r.statusCode)) {
      return L10n.current.gmBusy;
    }
    // Gemini يعيد رسالة الخطأ داخل حقل `error.message` عادةً.
    try {
      final body = jsonDecode(r.body) as Map<String, Object?>;
      final err = (body['error'] as Map?)?.cast<String, Object?>();
      final msg = err?['message']?.toString();
      if (msg != null && msg.isNotEmpty) return 'Gemini ${r.statusCode}: $msg';
    } catch (_) {}
    return L10n.current.gmStatus(r.statusCode, r.reasonPhrase ?? '');
  }
}

/// امتداد بسيط لتحويل `InvoiceLine` إلى `Medicine` جاهز للحفظ.
///
/// المنطق الوحيد هنا: توليد `id` جديد بالوقت، تحويل `expiry` النصي إلى
/// millis إن نجح، وتحديد `category` للأدوية فقط. بقيّة القرارات (النوع،
/// الدمج بالاسم) في شاشة المراجعة.
extension InvoiceLineToMedicine on InvoiceLine {
  Medicine toMedicine({required ItemType type, DateTime? now}) {
    final ts = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final expiryMs = parseExpiry(expiry);
    return Medicine(
      id: 'inv_${ts}_${(now ?? DateTime.now()).microsecond}',
      barcode: barcode ?? '',
      name: name,
      price: price ?? 0,
      quantity: quantity ?? 0,
      expiryDate: expiryMs,
      type: type,
      category: type == ItemType.medicine ? category : null,
      company: company,
      createdAt: ts,
      updatedAt: ts,
    );
  }

  /// يحوّل نص تاريخ الفاتورة إلى مللي ثانية.
  ///
  /// يقبل: `2027-11` · `11/2027` · `2027-11-30` · `30-11-2027` — **وأيضاً
  /// السنة ذات الرقمين** (`11/27` · `1/1/27`) وهي الصيغة الأشيع في فواتير
  /// الصيدليات الحقيقية. كانت تُرفض سابقاً فتُحفظ المادة **بلا تاريخ صلاحية
  /// إطلاقاً**، فلا تظهر أبداً في تنبيهات الصلاحية — دواء منتهٍ يبقى خفياً.
  static int? parseExpiry(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final s = raw.replaceAll('/', '-').replaceAll('.', '-').trim();
    final parts = s.split('-').where((p) => p.isNotEmpty).toList();
    if (parts.length < 2) return null;
    try {
      int year, month, day;
      if (parts[0].length == 4) {
        // سنة أولاً: 2027-11 أو 2027-11-30
        year = int.parse(parts[0]);
        month = int.parse(parts[1]);
        day = parts.length > 2 ? int.parse(parts[2]) : 0;
      } else {
        // سنة أخيراً: 11-2027 أو 30-11-2027 أو 11-27 أو 1-1-27
        year = _expandYear(int.parse(parts.last));
        month = int.parse(parts[parts.length - 2]);
        day = parts.length > 2 ? int.parse(parts[0]) : 0;
      }
      if (month < 1 || month > 12 || year < 2020 || year > 2100) return null;

      // آخر يوم في الشهر عند غياب اليوم، وحدٌّ أعلى عند وجوده: بلا هذا كان
      // «2027-11-31» ينزلق إلى 1 ديسمبر (DateTime يتسامح مع الفيض).
      final lastDay = DateTime(year, month + 1, 0).day;
      if (day <= 0 || day > lastDay) day = lastDay;

      return DateTime(year, month, day).millisecondsSinceEpoch;
    } catch (_) {
      return null;
    }
  }

  /// يوسّع سنة من رقمين إلى أربعة بنفس قاعدة القرن المستعملة في مفكّك GS1
  /// (`gs1_parser`): 00-50 ⇒ 20xx، وما فوق ⇒ 19xx. السنوات المكتوبة أصلاً
  /// بأربعة أرقام تمرّ كما هي.
  static int _expandYear(int raw) {
    if (raw >= 100) return raw;
    return raw <= 50 ? 2000 + raw : 1900 + raw;
  }
}
