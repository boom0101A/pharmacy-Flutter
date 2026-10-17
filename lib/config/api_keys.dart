import 'package:flutter_dotenv/flutter_dotenv.dart';

/// مصدر مفاتيح الواجهات الخارجية.
///
/// المفتاح يُقرأ من ملف `.env` المضمّن كأصل (asset) في `pubspec.yaml`.
/// إن لم يوجد المفتاح، `AppSettings.hasGeminiKey` يعود `false` فيختفي زر
/// «قراءة فاتورة» تلقائياً من الواجهة — لا يجوز أن يمنع غيابه إقلاع التطبيق.
class ApiKeys {
  ApiKeys._();

  /// المفتاح المضمّن مع نسخة التطبيق — للفواتير بالذكاء الاصطناعي (Gemini).
  static String get geminiDefault {
    // dotenv قد لا يكون مُهيَّأ (في الاختبارات مثلاً) — لا نرمي، نُعيد فراغاً.
    try {
      return (dotenv.env['GEMINI_API_KEY'] ?? '').trim();
    } catch (_) {
      return '';
    }
  }
}
