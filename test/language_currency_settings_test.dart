import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/services/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// اللغة والعملة إعدادات محلية لكل جهاز — لا تُزامَن ولا تغيّر البيانات.
void main() {
  final s = AppSettings.instance;

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await s.init();
  });

  test('الافتراضي: العربية والدينار بلا سعر صرف', () async {
    SharedPreferences.setMockInitialValues({});
    await s.init();
    expect(s.language, 'ar');
    expect(s.currency, 'IQD');
    expect(s.usdRate, isNull);
  });

  test('اللغة تُحفظ وتبقى بعد إعادة الفتح', () async {
    SharedPreferences.setMockInitialValues({});
    await s.init();
    await s.setLanguage('en');
    expect(s.language, 'en');
    await s.init();
    expect(s.language, 'en');
  });

  test('الدولار يُرفض بلا سعر صرف', () async {
    SharedPreferences.setMockInitialValues({});
    await s.init();
    expect(await s.setCurrency('USD'), isFalse);
    expect(s.currency, 'IQD');
  });

  test('سعر الصرف ثم الدولار، ويبقيان بعد إعادة الفتح', () async {
    SharedPreferences.setMockInitialValues({});
    await s.init();
    await s.setUsdRate(1310);
    expect(await s.setCurrency('USD'), isTrue);
    await s.init();
    expect(s.currency, 'USD');
    expect(s.usdRate, 1310);
  });

  test('سعر صرف غير موجب يُرفض', () async {
    SharedPreferences.setMockInitialValues({});
    await s.init();
    expect(await s.setUsdRate(0), isFalse);
    expect(await s.setUsdRate(-5), isFalse);
    expect(s.usdRate, isNull);
  });
}
