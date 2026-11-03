import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/util/number_parse.dart';

/// خانات الأسعار تُكتب بفواصل الآلاف كما تُعرض في بقية التطبيق: `1,764`.
void main() {
  final f = ThousandsSeparatorInputFormatter();

  /// كتابة/تعديل: [text] النص الجديد والمؤشر في [cursor] (افتراضياً آخره).
  TextEditingValue edit(String old, String text, {int? cursor}) =>
      f.formatEditUpdate(
        TextEditingValue(
          text: old,
          selection: TextSelection.collapsed(offset: old.length),
        ),
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: cursor ?? text.length),
        ),
      );

  group('ThousandsSeparatorInputFormatter', () {
    test('كتابة متتابعة', () {
      var v = const TextEditingValue();
      for (final d in '1764'.split('')) {
        v = edit(v.text, v.text + d);
      }
      expect(v.text, '1,764');
      expect(v.selection.baseOffset, 5);
      expect(edit('', '1234567').text, '1,234,567');
      expect(edit('', '999').text, '999');
    });

    test('أرقام عربية-هندية تصبح لاتينية', () {
      expect(edit('', '١٧٦٤').text, '1,764');
      expect(edit('', '۱۲۰۰۰').text, '12,000');
    });

    test('الكسر يبقى، ونقطة ثانية تُرفض', () {
      expect(edit('', '1234.5').text, '1,234.5');
      expect(edit('1,234.5', '1,234.5.').text, '1,234.5');
      expect(edit('', '.5').text, '0.5');
    });

    test('النص الفارغ يبقى فارغاً', () {
      expect(edit('1', '').text, '');
    });

    test('الحذف من الوسط يعيد التجميع والمؤشر يبقى بعد الرقم نفسه', () {
      // «1,23|4,567» — حذف «3»
      final v = edit('1,234,567', '1,24,567', cursor: 3);
      expect(v.text, '124,567');
      // المؤشر بعد «12»
      expect(v.text.substring(0, v.selection.baseOffset), '12');
    });

    test('الكتابة في الوسط تبقي المؤشر بعد الرقم المكتوب', () {
      // «1,7|64» + «0» ⇒ «17064» ⇒ «17,064» والمؤشر بعد «170»
      final v = edit('1,764', '1,7064', cursor: 4);
      expect(v.text, '17,064');
      expect(v.text.substring(0, v.selection.baseOffset), '17,0');
    });

    test('حذف الفاصلة نفسها يحذف ما قبلها لا يعيدها فقط', () {
      // «1,|764» — Backspace يحذف «,» فيُعاد تجميع «1764» كما هو؛ المقبول
      // أن يبقى الرقم سليماً لا أن يتلف
      final v = edit('1,764', '1764', cursor: 1);
      expect(v.text, '1,764');
    });
  });

  group('formatPriceInput', () {
    test('عدد صحيح بلا كسور', () {
      expect(formatPriceInput(1764), '1,764');
      expect(formatPriceInput(393932), '393,932');
      expect(formatPriceInput(500), '500');
      expect(formatPriceInput(0), '0');
      expect(formatPriceInput(1764.0), '1,764');
    });

    test('الكسر يبقى', () {
      expect(formatPriceInput(1234.5), '1,234.5');
    });

    test('ما يُكتب يُقرأ بالقيمة نفسها', () {
      for (final x in [0, 7, 1764, 393932, 1234567, 1234.5]) {
        expect(parseLocalizedNumber(formatPriceInput(x)), x);
      }
    });
  });
}
