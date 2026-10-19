import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/medicine.dart';
import 'app_settings.dart';
import 'gs1_parser.dart';

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
    bonus: bonus,
    lineTotal: lineTotal,
    uncertain: uncertain,
  );
}

/// مشكلة معروفة في سطر مقروء — تُعرض كشارة في المراجعة.
enum LineIssue {
  invalidBarcode('باركود غير صالح — حُذف'),
  totalMismatch('الكمية × السعر ≠ المجموع'),
  missingPrice('السعر ناقص'),
  missingQuantity('الكمية ناقصة'),
  uncertain('غير واضح في الصورة');

  const LineIssue(this.label);
  final String label;
}

/// سطر بعد التحقق: قد يُعدَّل (حذف باركود غير صالح) مع قائمة مشكلاته.
class ValidatedLine {
  const ValidatedLine(this.line, this.issues);
  final InvoiceLine line;
  final List<LineIssue> issues;
}

/// نتيجة قراءة صورة فاتورة.
class InvoiceResult {
  const InvoiceResult._(this.ok, this.lines, this.error);

  final bool ok;
  final List<InvoiceLine> lines;
  final String? error;

  factory InvoiceResult.success(List<InvoiceLine> lines) =>
      InvoiceResult._(true, lines, null);
  factory InvoiceResult.failure(String reason) =>
      InvoiceResult._(false, const [], reason);
}

/// عميل Google Gemini للفواتير — الصورة تُرسَل إلى endpoint النموذج [_model]
/// مع مخطط JSON صارم يجبر النموذج على إعادة أسطر منظّمة
/// بدل نص حرّ يحتاج تحليلاً هشّاً.
///
/// **لا يرمي استثناء أبداً:** كل حالات الفشل تُعاد كـ `InvoiceResult.failure`
/// برسالة عربية واضحة، فلا يعطّل خطأ الشبكة أو انتهاء المهلة الواجهة.
class GeminiVision {
  GeminiVision._();

  /// نموذج «تفكير» جديد يُوصي Google باستعماله بعد إيقاف gemini-2.0-flash
  /// و2.5-flash للمستخدمين الجدد. يستهلك بضع مئات من توكنات التفكير قبل
  /// الرد فيبطئ الاستجابة إلى 6-10 ثوانٍ للفاتورة الواحدة — مقبول لأن
  /// المستخدم يلتقط صورة ثم ينتظر مرة واحدة، لا يكرّرها في كل ضغطة.
  static const _model = 'gemini-3.6-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  /// الحد الأقصى لحجم الصورة المرسلة — Gemini يقبل حتى 20MB لكن صورة فاتورة
  /// عادية أقل من 2MB. نمنع تصعيد أي صورة كبيرة عرضاً كي لا يفشل الطلب.
  static const _maxBytes = 7 * 1024 * 1024;

  /// 90 ثانية سقف — يكفي فواتير طويلة مع توكنات التفكير قبل الاستخراج.
  static const Duration _timeout = Duration(seconds: 90);

  static bool get isConfigured => AppSettings.instance.hasGeminiKey;

  /// يقرأ فاتورة من ملف على القرص.
  static Future<InvoiceResult> readInvoice(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return await readInvoiceBytes(bytes);
    } catch (e) {
      return InvoiceResult.failure('تعذّرت قراءة ملف الصورة: $e');
    }
  }

  /// يقرأ فاتورة من بايتات مباشرة — نقطة الدخول الوحيدة القابلة للاختبار.
  static Future<InvoiceResult> readInvoiceBytes(Uint8List bytes) async {
    if (!isConfigured) {
      return InvoiceResult.failure(
        'قراءة الفاتورة غير مفعّلة — لم يُضبط مفتاح Gemini في ملف .env.',
      );
    }
    if (bytes.length > _maxBytes) {
      return InvoiceResult.failure(
        'الصورة أكبر من ${_maxBytes ~/ (1024 * 1024)} ميجابايت — جرّب صورة أخفّ.',
      );
    }

    try {
      final body = jsonEncode(_buildRequest(bytes));

      final response = await http
          .post(
            requestUri,
            headers: requestHeaders(AppSettings.instance.geminiKey),
            body: body,
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return InvoiceResult.failure(_explainHttpError(response));
      }

      return parseResponse(response.body);
    } on SocketException {
      return InvoiceResult.failure('لا يوجد اتصال بالإنترنت.');
    } on http.ClientException catch (e) {
      return InvoiceResult.failure('تعذّر الاتصال بخدمة القراءة: ${e.message}');
    } catch (e) {
      return InvoiceResult.failure('خطأ غير متوقع: $e');
    }
  }

  /// عنوان الطلب **بلا المفتاح**: المفتاح في رابط الطلب كان يظهر داخل رسائل
  /// خطأ الاتصال (`ClientException` تطبع الرابط) فيُعرض على الشاشة.
  @visibleForTesting
  static Uri get requestUri => Uri.parse(_endpoint);

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
  static Map<String, Object?> _buildRequest(Uint8List bytes) => {
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
- barcode: فقط إن كان الباركود مطبوعاً **في نفس السطر**. لا تنسخه من سطر مجاور
  ولا تخمّنه. إن لم يوجد فـ null.
- expiry: تاريخ الصلاحية كما ظهر في السطر بلا تحويل، وإلا null.
- category: الشكل الصيدلاني إن وُجد له عمود (Tablet/Cream/Syrup/Drops/...)
  كما هو حرفياً بلا ترجمة، وإلا null — لا تخترعه.
- uncertain: true إن كان أي جزء من السطر مقطوعاً أو مطموساً أو غير مقروء
  بوضوح، وإلا false.

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
            'price': {'type': 'NUMBER', 'nullable': true},
            'quantity': {'type': 'INTEGER', 'nullable': true},
            'barcode': {'type': 'STRING', 'nullable': true},
            'expiry': {'type': 'STRING', 'nullable': true},
            'category': {'type': 'STRING', 'nullable': true},
            'bonus': {'type': 'INTEGER', 'nullable': true},
            'line_total': {'type': 'NUMBER', 'nullable': true},
            'uncertain': {'type': 'BOOLEAN'},
          },
          'required': ['name'],
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
        return InvoiceResult.failure('لم تُرجع الخدمة أي محتوى.');
      }
      final first = candidates.first as Map;
      // ردّ مقطوع عند حدّ التوكنات = JSON ناقص لا يُفهم؛ رسالة صريحة أنفع
      if (first['finishReason'] == 'MAX_TOKENS') {
        return InvoiceResult.failure(
          'الصفحة طويلة جداً فانقطع الرد — صوّرها على جزأين.',
        );
      }
      final parts = ((first['content'] as Map?)?['parts'] as List?) ?? const [];
      // نماذج «التفكير» قد تسبق الجواب بأجزاء تفكير — الجواب أول نص غيرها
      final raw = parts
          .whereType<Map>()
          .where((p) => p['thought'] != true && p['text'] is String)
          .map((p) => p['text'] as String)
          .firstOrNull;
      if (raw == null) {
        return InvoiceResult.failure('لم تُرجع الخدمة أي محتوى.');
      }
      return parseInvoiceJson(raw);
    } catch (e) {
      return InvoiceResult.failure('تعذّر فهم ردّ الخدمة: $e');
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
            price: _num(item['price'])?.toDouble(),
            quantity: _num(item['quantity'])?.toInt(),
            barcode: _clean(item['barcode']),
            expiry: _clean(item['expiry']),
            category: _clean(item['category']),
            bonus: _num(item['bonus'])?.toInt(),
            lineTotal: _num(item['line_total'])?.toDouble(),
            uncertain: item['uncertain'] == true,
          ),
        );
      }
      return InvoiceResult.success(lines);
    } catch (e) {
      return InvoiceResult.failure('تعذّر فهم صيغة الأسطر: $e');
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
    return ValidatedLine(line, issues);
  }

  /// يحوّل أي حقل نص إلى string منظّف أو null.
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

  static String _explainHttpError(http.Response r) {
    // Gemini يعيد رسالة الخطأ داخل حقل `error.message` عادةً.
    try {
      final body = jsonDecode(r.body) as Map<String, Object?>;
      final err = (body['error'] as Map?)?.cast<String, Object?>();
      final msg = err?['message']?.toString();
      if (msg != null && msg.isNotEmpty) return 'Gemini ${r.statusCode}: $msg';
    } catch (_) {}
    return 'Gemini استجاب ${r.statusCode}: ${r.reasonPhrase ?? ""}';
  }
}

/// امتداد بسيط لتحويل `InvoiceLine` إلى `Medicine` جاهز للحفظ.
///
/// المنطق الوحيد هنا: توليد `id` جديد بالوقت، تحويل `expiry` النصي إلى
/// millis إن نجح، وتحديد `category` للمستلزمات فقط. بقيّة القرارات (النوع،
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
      category: type == ItemType.supply ? category : null,
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
