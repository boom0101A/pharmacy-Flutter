import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/services/gs1_parser.dart';

const gs = '';

void main() {
  group('خانة التحقق', () {
    test('يقبل باركودات صحيحة', () {
      expect(Gs1Parser.isValidGtin('5449000000996'), isTrue); // EAN-13
      expect(Gs1Parser.isValidGtin('00012345678905'), isTrue); // GTIN-14
      expect(Gs1Parser.isValidGtin('96385074'), isTrue); // EAN-8
    });

    test('يرفض باركودات خاطئة', () {
      expect(Gs1Parser.isValidGtin('5449000000997'), isFalse);
      expect(Gs1Parser.isValidGtin('123'), isFalse);
      expect(Gs1Parser.isValidGtin('abcdefghijklm'), isFalse);
      expect(Gs1Parser.isValidGtin(''), isFalse);
    });
  });

  group('الباركود الخطي البسيط', () {
    test('EAN-13 يمر كما هو ويُوحَّد إلى GTIN-14', () {
      final r = Gs1Parser.parse('5449000000996');
      expect(r.isGs1, isFalse);
      expect(r.barcode, '05449000000996');
      expect(r.expiryDate, isNull);
    });

    test('نص غير رقمي يعود كما هو دون تعديل', () {
      final r = Gs1Parser.parse('ABC-123-XYZ');
      expect(r.isGs1, isFalse);
      expect(r.barcode, 'ABC-123-XYZ');
      expect(r.gtin, isNull);
    });

    test('رقم لا يجتاز خانة التحقق يبقى كما هو', () {
      final r = Gs1Parser.parse('1234567890123');
      expect(r.isGs1, isFalse);
      expect(r.barcode, '1234567890123');
    });
  });

  group('تفكيك GS1', () {
    test('GTIN + صلاحية + وجبة + تسلسلي مع فواصل', () {
      final raw =
          '0100012345678905'
          '17270630'
          '${gs}10ABC123'
          '${gs}21SN99871';
      final r = Gs1Parser.parse(raw);

      expect(r.isGs1, isTrue);
      expect(r.gtin, '00012345678905');
      expect(r.barcode, '00012345678905');
      expect(r.expiryDate, DateTime(2027, 6, 30));
      expect(r.batch, 'ABC123');
      expect(r.serial, 'SN99871');
    });

    test('GTIN وصلاحية فقط — كلاهما ثابت الطول بلا فواصل', () {
      final r = Gs1Parser.parse('010001234567890517251130');
      expect(r.isGs1, isTrue);
      expect(r.gtin, '00012345678905');
      expect(r.expiryDate, DateTime(2025, 11, 30));
      expect(r.batch, isNull);
    });

    test('صيغة الأقواس', () {
      final r = Gs1Parser.parse('(01)00012345678905(17)270630(10)LOT9');
      expect(r.isGs1, isTrue);
      expect(r.gtin, '00012345678905');
      expect(r.expiryDate, DateTime(2027, 6, 30));
      expect(r.batch, 'LOT9');
    });

    test('معرّف الترميز ]d2 في البداية يُتجاهل', () {
      final r = Gs1Parser.parse(']d20100012345678905${gs}10L1');
      expect(r.isGs1, isTrue);
      expect(r.gtin, '00012345678905');
      expect(r.batch, 'L1');
    });

    test('اليوم 00 يعني آخر يوم في الشهر', () {
      final r = Gs1Parser.parse('010001234567890517260200');
      expect(r.expiryDate, DateTime(2026, 2, 28));
    });

    test('الحقل المتغيّر بلا فاصل في النهاية يُقرأ حتى آخر النص', () {
      final r = Gs1Parser.parse('010001234567890510BATCH777');
      expect(r.gtin, '00012345678905');
      expect(r.batch, 'BATCH777');
    });
  });

  group('الحماية من الفساد', () {
    test('GTIN داخل GS1 لا يجتاز خانة التحقق ⇒ يُرفض التفكيك', () {
      final r = Gs1Parser.parse('0100012345678900${gs}10X1');
      expect(r.isGs1, isFalse);
      expect(r.barcode, '0100012345678900${gs}10X1');
    });

    test('بيانات ناقصة لا تُسبب انهياراً', () {
      expect(() => Gs1Parser.parse('0100012'), returnsNormally);
      expect(() => Gs1Parser.parse('01'), returnsNormally);
      expect(() => Gs1Parser.parse(''), returnsNormally);
      expect(() => Gs1Parser.parse(gs), returnsNormally);
    });

    test('شهر غير صالح يعطي صلاحية فارغة لا تاريخاً خاطئاً', () {
      final r = Gs1Parser.parse('010001234567890517991301');
      expect(r.gtin, '00012345678905');
      expect(r.expiryDate, isNull);
    });

    test('نفس الدواء بعلبتين مختلفتين يعطي نفس الباركود', () {
      final a = Gs1Parser.parse('0100012345678905${gs}21SN0001');
      final b = Gs1Parser.parse('0100012345678905${gs}21SN9999');
      expect(a.barcode, b.barcode);
      expect(a.serial, isNot(b.serial));
    });
  });

  group('صيغ البحث', () {
    test('تشمل الصيغ الشائعة لنفس المنتج', () {
      final v = Gs1Parser.lookupVariants('00012345678905');
      expect(v, contains('00012345678905'));
      expect(v, contains('12345678905'));
      expect(v, contains('0012345678905'));
    });

    test('لا تُنتج قيماً فارغة', () {
      expect(Gs1Parser.lookupVariants('   '), isEmpty);
      expect(Gs1Parser.lookupVariants('0000'), isNot(contains('')));
    });
  });
}
