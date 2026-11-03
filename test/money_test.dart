import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/services/app_settings.dart';
import 'package:saydaliyati/util/money.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// الدينار مخزَّن دائماً؛ الدولار تحويل للعرض والإدخال بسعر الصرف.
void main() {
  final s = AppSettings.instance;

  Future<void> use({String lang = 'ar', double? rate, bool usd = false}) async {
    SharedPreferences.setMockInitialValues({});
    await s.init();
    await s.setLanguage(lang);
    if (rate != null) await s.setUsdRate(rate);
    if (usd) await s.setCurrency('USD');
  }

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await s.init();
  });

  test('الدينار بالعربية وبالإنجليزية', () async {
    await use();
    expect(formatMoney(7877), '7,877 د.ع');
    expect(currencyLabel(), 'د.ع');
    await use(lang: 'en');
    expect(formatMoney(7877), '7,877 IQD');
    expect(currencyLabel(), 'IQD');
  });

  test('الدولار بكسرين وفواصل', () async {
    await use(rate: 1310, usd: true);
    expect(formatMoney(7877), r'$6.01');
    expect(formatMoney(30918269), r'$23,601.73');
    expect(currencyLabel(), r'$');
  });

  test('iqdOnly يبقى بالدينار مع الدولار (الفاتورة الذكية)', () async {
    await use(rate: 1310, usd: true);
    expect(formatMoney(393932, iqdOnly: true), '393,932 د.ع');
  });

  test('التحويل ذهاباً وإياباً', () async {
    await use(rate: 1310, usd: true);
    expect(toDisplay(13100), 10);
    expect(fromDisplay(10), 13100);
    // الدينار بلا كسور عند الحفظ
    expect(fromDisplay(6.01), 7873);
    await use();
    expect(toDisplay(7877), 7877);
    expect(fromDisplay(7877), 7877);
  });

  test('قيمة خانة السعر بعملة العرض', () async {
    await use(rate: 1310, usd: true);
    expect(priceInputText(7877), '6.01');
    expect(priceInputText(13100), '10');
    await use();
    expect(priceInputText(7877), '7,877');
  });

  test('حماية التقريب: نص لم يُلمس يعيد الدينار الأصلي حرفياً', () async {
    await use(rate: 1310, usd: true);
    final shown = priceInputText(7877);
    expect(priceFromInput(shown, originalIqd: 7877), 7877);
    expect(priceFromInput('10', originalIqd: 7877), 13100);
    expect(priceFromInput('', originalIqd: 7877), isNull);
    expect(priceFromInput('abc'), isNull);
  });
}
