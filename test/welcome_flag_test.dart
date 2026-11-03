import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/config/app_info.dart';
import 'package:saydaliyati/services/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// شرائح الترحيب تظهر في أول تشغيل فقط — العلم يجب أن يبقى بعد إعادة الفتح.
void main() {
  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.init();
  });

  test('الافتراضي: لم يرَ الترحيب بعد', () async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.init();
    expect(AppSettings.instance.welcomeSeen, isFalse);
  });

  test('markWelcomeSeen يستمر بعد إعادة init', () async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.init();
    await AppSettings.instance.markWelcomeSeen();
    expect(AppSettings.instance.welcomeSeen, isTrue);

    await AppSettings.instance.init();
    expect(AppSettings.instance.welcomeSeen, isTrue);
  });

  test('resetWelcome يعيد عرضه', () async {
    SharedPreferences.setMockInitialValues({'welcome_seen': true});
    await AppSettings.instance.init();
    expect(AppSettings.instance.welcomeSeen, isTrue);

    await AppSettings.instance.resetWelcome();
    expect(AppSettings.instance.welcomeSeen, isFalse);
    await AppSettings.instance.init();
    expect(AppSettings.instance.welcomeSeen, isFalse);
  });

  test('رقم الإصدار المعروض', () {
    expect(appVersion, '1.2.6');
  });
}
