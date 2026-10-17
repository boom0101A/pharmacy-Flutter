import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/services/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ثبات حقلي pharmacyId وpharmacyBackfillDone الجديدين — نفس أسلوب
/// settings_notifications_test.dart: مفرد عام يُعاد لحالته الافتراضية بعد كل
/// اختبار حتى لا يتسرّب تغيير من اختبار إلى آخر.
void main() {
  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.init();
  });

  test('pharmacyId يبدأ null قبل أول مزامنة', () async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.init();
    expect(AppSettings.instance.pharmacyId, isNull);
  });

  test('setPharmacyId يحفظ القيمة ويستمر بعد إعادة init', () async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.init();

    await AppSettings.instance.setPharmacyId('pharmacy_123');
    expect(AppSettings.instance.pharmacyId, 'pharmacy_123');

    // إعادة init تحاكي إعادة فتح التطبيق — القيمة يجب أن تُقرأ من التخزين
    await AppSettings.instance.init();
    expect(AppSettings.instance.pharmacyId, 'pharmacy_123');
  });

  test(
    'pharmacyBackfillDone يبدأ false ويثبت true بعد markPharmacyBackfillDone',
    () async {
      SharedPreferences.setMockInitialValues({});
      await AppSettings.instance.init();
      expect(AppSettings.instance.pharmacyBackfillDone, isFalse);

      await AppSettings.instance.markPharmacyBackfillDone();
      expect(AppSettings.instance.pharmacyBackfillDone, isTrue);

      await AppSettings.instance.init();
      expect(AppSettings.instance.pharmacyBackfillDone, isTrue);
    },
  );
}
