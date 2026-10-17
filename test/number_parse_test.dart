import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/util/number_parse.dart';

void main() {
  test('أرقام عربية-هندية وفارسية وفواصل', () {
    expect(parseLocalizedNumber('١٢٥٠'), 1250);
    expect(parseLocalizedNumber('۱۲۵۰'), 1250);
    expect(parseLocalizedNumber('1,250'), 1250);
    expect(parseLocalizedNumber('١٬٢٥٠'), 1250);
    expect(parseLocalizedNumber('12٫5'), 12.5);
    expect(parseLocalizedNumber(' 750 '), 750);
  });

  test('فارغ أو غير صالح يعيد null', () {
    expect(parseLocalizedNumber(''), isNull);
    expect(parseLocalizedNumber('abc'), isNull);
  });

  test('الكمية عدد صحيح فقط', () {
    expect(parseLocalizedInt('٣'), 3);
    expect(parseLocalizedInt('1,200'), 1200);
    expect(parseLocalizedInt('2.5'), isNull);
    expect(parseLocalizedInt(''), isNull);
  });
}
