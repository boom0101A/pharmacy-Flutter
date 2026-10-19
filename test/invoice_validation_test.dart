import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/services/gemini_vision.dart';

void main() {
  group('parseInvoiceJson — الحقول الجديدة', () {
    test('يقرأ bonus وline_total وuncertain', () {
      final r = GeminiVision.parseInvoiceJson(
        '{"lines":[{"name":"Rennie","price":1000,"quantity":3,'
        '"bonus":1,"line_total":3000,"uncertain":true}]}',
      );
      final l = r.lines.single;
      expect(l.bonus, 1);
      expect(l.lineTotal, 3000);
      expect(l.uncertain, isTrue);
    });
  });

  group('validateLine', () {
    test('سطر سليم بلا مشكلات', () {
      final v = GeminiVision.validateLine(
        InvoiceLine(
          name: 'Rennie',
          price: 1000,
          quantity: 3,
          lineTotal: 3000,
          barcode: '6285128013338',
        ),
      );
      expect(v.issues, isEmpty);
      expect(v.line.barcode, '6285128013338');
    });

    test('باركود بخانة تحقق خاطئة يُحذف ويُعلَّم', () {
      final v = GeminiVision.validateLine(
        InvoiceLine(name: 'X', price: 1, quantity: 1, barcode: '6285128013339'),
      );
      expect(v.issues, contains(LineIssue.invalidBarcode));
      expect(v.line.barcode, isNull);
    });

    test('الكمية × السعر لا يطابق مجموع السطر', () {
      final v = GeminiVision.validateLine(
        InvoiceLine(name: 'X', price: 1000, quantity: 3, lineTotal: 3500),
      );
      expect(v.issues, contains(LineIssue.totalMismatch));
    });

    test('فرق تقريب أقل من 1% لا يُعلَّم', () {
      final v = GeminiVision.validateLine(
        InvoiceLine(name: 'X', price: 333.33, quantity: 3, lineTotal: 1000),
      );
      expect(v.issues, isNot(contains(LineIssue.totalMismatch)));
    });

    test('سعر أو كمية ناقصة، وuncertain من Gemini', () {
      final v = GeminiVision.validateLine(
        InvoiceLine(name: 'X', uncertain: true),
      );
      expect(
        v.issues,
        containsAll([
          LineIssue.missingPrice,
          LineIssue.missingQuantity,
          LineIssue.uncertain,
        ]),
      );
    });
  });

  test('parseExpiry متاح علناً', () {
    expect(InvoiceLineToMedicine.parseExpiry('11/27'), isNotNull);
    expect(InvoiceLineToMedicine.parseExpiry('abc'), isNull);
  });

  group('طلب Gemini وردّه', () {
    String reply(List<Map<String, Object?>> parts, {String? finish}) =>
        jsonEncode({
          'candidates': [
            {
              'content': {'parts': parts},
              'finishReason': ?finish,
            },
          ],
        });

    test('المفتاح في الترويسة لا في الرابط، والنموذج كما هو', () {
      expect(GeminiVision.requestUri.query, isEmpty);
      expect(GeminiVision.requestUri.path, contains('gemini-3.6-flash'));
      expect(GeminiVision.requestHeaders('K')['x-goog-api-key'], 'K');
    });

    test('أجزاء التفكير تُتخطّى ويُقرأ الجواب', () {
      final r = GeminiVision.parseResponse(
        reply([
          {'text': 'أفكّر…', 'thought': true},
          {'text': '{"lines":[{"name":"Rennie","quantity":2}]}'},
        ]),
      );
      expect(r.ok, isTrue);
      expect(r.lines.single.name, 'Rennie');
    });

    test('ردّ مقطوع بحدّ التوكنات يعطي رسالة واضحة', () {
      final r = GeminiVision.parseResponse(
        reply([
          {'text': '{"lines":[{"na'},
        ], finish: 'MAX_TOKENS'),
      );
      expect(r.ok, isFalse);
      expect(r.error, contains('جزأين'));
    });

    test('نوع الصورة من بايتاتها', () {
      expect(
        GeminiVision.mimeTypeOf(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0]),
        ),
        'image/png',
      );
      expect(
        GeminiVision.mimeTypeOf(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0])),
        'image/jpeg',
      );
      expect(
        GeminiVision.mimeTypeOf(Uint8List.fromList('RIFF0000WEBP'.codeUnits)),
        'image/webp',
      );
    });
  });
}
