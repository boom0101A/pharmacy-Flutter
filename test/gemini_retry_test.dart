import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydaliyati/services/gemini_vision.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// إعادة المحاولة والنموذج البديل.
///
/// خوادم Google ترد 503 «ضغط عالٍ» على فترات (قيس: خمس مرات متتالية)، والخطة
/// المجانية تحدّ gemini-3.6-flash بعشرين قراءة يومياً. عند نفاد حصته أو بقاء
/// الضغط ينتقل التطبيق إلى gemini-3.5-flash-lite (28/28 على فاتورة حقيقية).
void main() {
  const primary = 'gemini-3.6-flash';
  const fallback = 'gemini-3.5-flash-lite';
  final image = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0]);
  late List<Duration> waited;
  late Map<String, List<int>> calls;
  late DateTime clock;

  const jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

  String ok() => jsonEncode({
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': '{"lines":[{"name":"Rennie","quantity":2,"price":1000}]}'},
          ],
        },
        'finishReason': 'STOP',
      },
    ],
  });

  const busy =
      '{"error":{"message":"This model is currently experiencing high demand."}}';

  String quota(String quotaId, String delay) => jsonEncode({
    'error': {
      'code': 429,
      'status': 'RESOURCE_EXHAUSTED',
      'message': 'You exceeded your current quota',
      'details': [
        {
          '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
          'violations': [
            {'quotaId': quotaId, 'quotaValue': '20'},
          ],
        },
        {
          '@type': 'type.googleapis.com/google.rpc.RetryInfo',
          'retryDelay': delay,
        },
      ],
    },
  });

  final daily = quota(
    'GenerateRequestsPerDayPerProjectPerModel-FreeTier',
    '5358s',
  );

  /// ردود كل نموذج بالترتيب: (الحالة، الجسم). نموذج بلا ردود متبقية يفشل
  /// الاختبار — فطلب غير متوقع (للبديل مثلاً) يُكشف.
  void serve(Map<String, List<(int, String)>> byModel) {
    calls = {primary: [], fallback: []};
    GeminiVision.httpClient = MockClient((req) async {
      final model = req.url.path.contains(fallback) ? fallback : primary;
      final queue = byModel[model] ?? const [];
      final n = calls[model]!.length;
      if (n >= queue.length) fail('طلب غير متوقع رقم ${n + 1} إلى $model');
      final (status, body) = queue[n];
      calls[model]!.add(status);
      return http.Response(body, status, headers: jsonHeaders);
    });
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(fileInput: 'GEMINI_API_KEY=test-key');
    waited = [];
    clock = DateTime(2026, 10, 21, 10);
    GeminiVision.sleep = (d) async => waited.add(d);
    GeminiVision.now = () => clock;
  });

  tearDown(GeminiVision.resetTransport);

  group('إعادة المحاولة على النموذج الأساسي', () {
    test('503 مرتين ثم 200 ← ينجح بعد 3 طلبات بانتظار 3ث ثم 8ث', () async {
      serve({
        primary: [(503, busy), (503, busy), (200, ok())],
      });
      final result = await GeminiVision.readInvoiceBytes(image);
      expect(result.ok, isTrue);
      expect(result.usedFallback, isFalse);
      expect(calls[primary]!.length, 3);
      expect(calls[fallback], isEmpty);
      expect(waited, [const Duration(seconds: 3), const Duration(seconds: 8)]);
    });

    test('حدّ الدقيقة ← يُعاد على الأساسي لا ينتقل للبديل', () async {
      serve({
        primary: [
          (429, quota('GenerateRequestsPerMinutePerProjectPerModel', '20s')),
          (200, ok()),
        ],
      });
      final result = await GeminiVision.readInvoiceBytes(image);
      expect(result.ok, isTrue);
      expect(result.usedFallback, isFalse);
      expect(calls[primary]!.length, 2);
    });

    test('الأساسي ينجح ← البديل لا يُستدعى أبداً', () async {
      serve({
        primary: [(200, ok())],
      });
      final result = await GeminiVision.readInvoiceBytes(image);
      expect(result.usedFallback, isFalse);
      expect(calls[fallback], isEmpty);
    });

    test('400 ← فشل فوري بلا إعادة ولا بديل', () async {
      serve({
        primary: [(400, '{"error":{"message":"bad"}}')],
      });
      final result = await GeminiVision.readInvoiceBytes(image);
      expect(result.ok, isFalse);
      expect(calls[primary]!.length, 1);
      expect(calls[fallback], isEmpty);
      expect(waited, isEmpty);
    });
  });

  group('النموذج البديل gemini-3.5-flash-lite', () {
    test('حصة الأساسي اليومية نفدت ← طلب واحد له ثم البديل ينجح', () async {
      serve({
        primary: [(429, daily)],
        fallback: [(200, ok())],
      });
      final result = await GeminiVision.readInvoiceBytes(image);
      expect(result.ok, isTrue);
      expect(result.usedFallback, isTrue);
      expect(result.lines.single.name, 'Rennie');
      expect(calls[primary]!.length, 1);
      expect(calls[fallback]!.length, 1);
      expect(waited, isEmpty);
    });

    test('بعدها مباشرة: لا طلب للأساسي حتى تتجدد حصته', () async {
      serve({
        primary: [(429, daily)],
        fallback: [(200, ok()), (200, ok())],
      });
      await GeminiVision.readInvoiceBytes(image);
      clock = clock.add(const Duration(minutes: 30));
      final second = await GeminiVision.readInvoiceBytes(image);
      expect(second.usedFallback, isTrue);
      expect(calls[primary]!.length, 1, reason: 'الثانية تتخطّى الأساسي');
      expect(calls[fallback]!.length, 2);
    });

    test('بعد تجدد الحصة يعود إلى الأساسي', () async {
      serve({
        primary: [(429, daily), (200, ok())],
        fallback: [(200, ok())],
      });
      await GeminiVision.readInvoiceBytes(image);
      clock = clock.add(const Duration(seconds: 5358 + 60));
      final later = await GeminiVision.readInvoiceBytes(image);
      expect(later.usedFallback, isFalse);
      expect(calls[primary]!.length, 2);
    });

    test('الأساسي مزدحم بعد محاولاته الثلاث ← البديل يقرأ', () async {
      serve({
        primary: [(503, busy), (503, busy), (503, busy)],
        fallback: [(200, ok())],
      });
      final result = await GeminiVision.readInvoiceBytes(image);
      expect(result.ok, isTrue);
      expect(result.usedFallback, isTrue);
    });

    test('الاثنان مزدحمان ← «خدمة Google مزدحمة»', () async {
      serve({
        primary: [(503, busy), (503, busy), (503, busy)],
        fallback: [(503, busy), (503, busy), (503, busy)],
      });
      final result = await GeminiVision.readInvoiceBytes(image);
      expect(result.ok, isFalse);
      expect(result.error, contains('خدمة Google مزدحمة'));
    });

    test('حصة الاثنين نفدت ← رسالة الحصة بالوقت الأقرب', () async {
      serve({
        primary: [(429, daily)],
        fallback: [
          (
            429,
            quota('GenerateRequestsPerDayPerProjectPerModel-FreeTier', '1800s'),
          ),
        ],
      });
      final result = await GeminiVision.readInvoiceBytes(image);
      expect(result.ok, isFalse);
      expect(result.error, contains('انتهت القراءات المجانية'));
      expect(result.error, contains('30 دقيقة'));
    });
  });

  test('quotaInfo يقرأ النوع والمدة من الرد الحقيقي', () {
    final q = GeminiVision.quotaInfo(daily);
    expect(q.daily, isTrue);
    expect(q.retryAfter, const Duration(seconds: 5358));
    expect(GeminiVision.quotaInfo('not json').daily, isFalse);
  });
}
