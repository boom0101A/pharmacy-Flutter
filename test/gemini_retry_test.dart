import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydaliyati/services/gemini_vision.dart';

/// خوادم Google ترد 503 «ضغط عالٍ» على فترات — قيس فعلياً: خمس محاولات 503
/// متتالية قبل أن تنجح السادسة. كانت الصفحة تفشل من أول 503 برسالة خام.
void main() {
  final image = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0]);
  late List<Duration> waited;

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

  /// يرد بالحالات بالترتيب، ويعدّ الطلبات.
  ({MockClient client, List<int> calls}) replies(List<int> statuses) {
    final calls = <int>[];
    final client = MockClient((_) async {
      final status = statuses[calls.length];
      calls.add(status);
      return http.Response(
        status == 200
            ? ok()
            : '{"error":{"message":"This model is currently experiencing high demand."}}',
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    return (client: client, calls: calls);
  }

  setUp(() {
    dotenv.testLoad(fileInput: 'GEMINI_API_KEY=test-key');
    waited = [];
    GeminiVision.sleep = (d) async => waited.add(d);
  });

  tearDown(GeminiVision.resetTransport);

  test('503 مرتين ثم 200 ← ينجح بعد 3 طلبات بانتظار 3ث ثم 8ث', () async {
    final r = replies([503, 503, 200]);
    GeminiVision.httpClient = r.client;
    final result = await GeminiVision.readInvoiceBytes(image);
    expect(result.ok, isTrue);
    expect(result.lines.single.name, 'Rennie');
    expect(r.calls.length, 3);
    expect(waited, [const Duration(seconds: 3), const Duration(seconds: 8)]);
  });

  test('503 ثلاث مرات ← رسالة عربية واضحة بعد 3 طلبات فقط', () async {
    final r = replies([503, 503, 503]);
    GeminiVision.httpClient = r.client;
    final result = await GeminiVision.readInvoiceBytes(image);
    expect(result.ok, isFalse);
    expect(result.error, contains('خدمة Google مزدحمة'));
    expect(r.calls.length, 3);
  });

  test('429 ثم 200 ← ينجح بعد طلبين', () async {
    final r = replies([429, 200]);
    GeminiVision.httpClient = r.client;
    final result = await GeminiVision.readInvoiceBytes(image);
    expect(result.ok, isTrue);
    expect(r.calls.length, 2);
  });

  test('429 حتى النهاية ← رسالة «طلبات كثيرة»', () async {
    final r = replies([429, 429, 429]);
    GeminiVision.httpClient = r.client;
    final result = await GeminiVision.readInvoiceBytes(image);
    expect(result.error, contains('طلبات كثيرة'));
  });

  test('400 ← فشل فوري بطلب واحد بلا انتظار', () async {
    final r = replies([400]);
    GeminiVision.httpClient = r.client;
    final result = await GeminiVision.readInvoiceBytes(image);
    expect(result.ok, isFalse);
    expect(r.calls.length, 1);
    expect(waited, isEmpty);
  });
}
