import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
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

    test('يقرأ company، ونوع المادة يُحفظ للدواء وحده', () {
      final l = GeminiVision.parseInvoiceJson(
        '{"lines":[{"name":"Baby teething Gel","company":" Juman ",'
        '"category":"Gel"}]}',
      ).lines.single;
      expect(l.company, 'Juman');
      final med = l.toMedicine(type: ItemType.medicine);
      expect(med.category, 'Gel');
      expect(med.company, 'Juman');
      final sup = l.toMedicine(type: ItemType.supply);
      expect(sup.category, isNull);
      expect(sup.company, 'Juman');
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
      expect(GeminiVision.requestUri.path, contains('gemini-3.5-flash-lite'));
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

  // فاتورة كثيفة كانت تتجاوز 90 ثانية بتفكير النموذج الافتراضي → TimeoutException.
  test('الطلب يخفّض التفكير ويرفع سقف الرد', () {
    final req = GeminiVision.buildRequest(Uint8List.fromList([0xFF, 0xD8, 0]));
    final cfg = req['generationConfig']! as Map;
    expect((cfg['thinkingConfig']! as Map)['thinkingLevel'], 'low');
    expect(cfg['maxOutputTokens'], 65536);
    expect(GeminiVision.requestUri.path, contains('gemini-3.5-flash-lite'));
  });

  // الفاتورة تطبع «1,100» (فاصلة آلاف) وكان النموذج يُرجعها رقماً 1.1 — سعر
  // أصغر بألف مرة. الأسعار صارت نصاً كما طُبعت ويحوّلها التطبيق بنفسه.
  group('الأسعار كما طُبعت (فاصلة الآلاف)', () {
    InvoiceLine one(String price, {String? total}) =>
        GeminiVision.parseInvoiceJson(
          '{"lines":[{"name":"X","quantity":1,"price":"$price"'
          '${total == null ? '' : ',"line_total":"$total"'}}]}',
        ).lines.single;

    test('«1,100» ← 1100 لا 1.1', () => expect(one('1,100').price, 1100));
    test('«10,875» ← 10875', () => expect(one('10,875').price, 10875));
    test('«1.100» (نقطة آلاف) ← 1100', () => expect(one('1.100').price, 1100));
    test('«1٬250» ← 1250', () => expect(one('1٬250').price, 1250));
    test('مجموع السطر بفواصل', () {
      expect(one('2,531', total: '15,186').lineTotal, 15186);
    });
    test('رقم قديم (num) يُقبل كما هو', () {
      final l = GeminiVision.parseInvoiceJson(
        '{"lines":[{"name":"X","price":2500}]}',
      ).lines.single;
      expect(l.price, 2500);
    });
    test('نص غير رقمي ← null', () => expect(one('غير واضح').price, isNull));
    test('مجموع الرأس «297,943» ← 297943', () {
      final r = GeminiVision.parseInvoiceJson(
        '{"lines":[],"header":{"total":"297,943"}}',
      );
      expect(r.header!.total, 297943);
    });
    test('المخطط يطلب الأسعار نصاً', () {
      final props = GeminiVision.invoiceSchemaForTest['properties'] as Map;
      final line =
          ((props['lines'] as Map)['items'] as Map)['properties'] as Map;
      expect((line['price'] as Map)['type'], 'STRING');
      expect((line['line_total'] as Map)['type'], 'STRING');
      final header = (props['header'] as Map)['properties'] as Map;
      expect((header['total'] as Map)['type'], 'STRING');
    });
  });

  group('سعر غير منطقي', () {
    test('سعر أقل من 100 دينار ← تنبيه', () {
      final v = GeminiVision.validateLine(
        InvoiceLine(name: 'X', price: 1.1, quantity: 10),
      );
      expect(v.issues, contains(LineIssue.suspiciousPrice));
    });
    test('سعر طبيعي ← بلا تنبيه', () {
      final v = GeminiVision.validateLine(
        InvoiceLine(name: 'X', price: 1100, quantity: 10),
      );
      expect(v.issues, isNot(contains(LineIssue.suspiciousPrice)));
    });
  });
}
