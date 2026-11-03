import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/services/app_settings.dart';
import 'package:saydaliyati/services/pharmacy_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// سحابة مزيّفة: ما يُكتب يُقرأ — كمستند Firestore واحد للصيدلية.
class _FakeCloud {
  int? lowStock;
  final dismissals = <String>{};
  int writes = 0;
  bool fail = false;

  Future<void> apply(
    String pid, {
    int? lowStockDefault,
    List<String> add = const [],
    List<String> remove = const [],
  }) async {
    if (fail) throw StateError('offline');
    writes++;
    if (lowStockDefault != null) lowStock = lowStockDefault;
    dismissals
      ..addAll(add)
      ..removeAll(remove);
  }

  Future<({int? lowStockDefault, List<String> dismissals})> read(
    String pid,
  ) async {
    if (fail) throw StateError('offline');
    return (lowStockDefault: lowStock, dismissals: dismissals.toList());
  }
}

void main() {
  final prefs = PharmacyPrefs.instance;
  late _FakeCloud cloud;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.init();
    await AppSettings.instance.setPharmacyId('p1');
    prefs.resetForTest();
    cloud = _FakeCloud();
    prefs
      ..cloudApply = cloud.apply
      ..cloudRead = cloud.read;
  });

  tearDown(() async {
    prefs.resetForTest();
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.init();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('الافتراضي 5 بلا سحابة ولا تخزين', () {
    expect(prefs.lowStockDefault, 5);
    expect(prefs.alertDismissals, isEmpty);
  });

  test('الحد العام يُحفظ محلياً ويُرفع، ويبقى بعد إعادة الفتح', () async {
    await prefs.setLowStockDefault(10);
    await settle();
    expect(prefs.lowStockDefault, 10);
    expect(cloud.lowStock, 10);

    prefs.resetForTest();
    await prefs.loadLocal();
    expect(prefs.lowStockDefault, 10);
  });

  test('قيمة أقل من 1 تُرفض', () async {
    await prefs.setLowStockDefault(0);
    expect(prefs.lowStockDefault, 5);
  });

  test('حد غيّره الهاتف الآخر يصل بالمزامنة', () async {
    cloud.lowStock = 8;
    await prefs.syncWithCloud();
    expect(prefs.lowStockDefault, 8);
  });

  test('«تمّ» يُرفع ويصل للهاتف الآخر، والتراجع يُزيله من الاثنين', () async {
    await prefs.dismiss('m1:urgent');
    await settle();
    expect(prefs.alertDismissals, {'m1:urgent'});
    expect(cloud.dismissals, {'m1:urgent'});

    await prefs.restore(['m1:urgent']);
    await settle();
    expect(prefs.alertDismissals, isEmpty);
    expect(cloud.dismissals, isEmpty);
  });

  test('بلا إنترنت: يبقى معلّقاً ويُرفع في المزامنة التالية', () async {
    cloud.fail = true;
    await prefs.dismiss('m2:low');
    await prefs.setLowStockDefault(7);
    await settle();
    expect(cloud.dismissals, isEmpty);

    cloud.fail = false;
    await prefs.syncWithCloud();
    await settle();
    expect(cloud.dismissals, {'m2:low'});
    expect(cloud.lowStock, 7);
    expect(prefs.alertDismissals, {'m2:low'});
  });

  test('المعلّق لا تمحوه قراءة سحابة لم يصلها بعد', () async {
    cloud.fail = true;
    await prefs.setLowStockDefault(12);
    cloud
      ..fail = false
      ..lowStock = 5;
    // السحابة تقول 5 لكن تغيير هذا الهاتف لم يصلها — 12 يبقى ويُرفع
    await prefs.syncWithCloud();
    await settle();
    expect(prefs.lowStockDefault, 12);
    expect(cloud.lowStock, 12);
  });

  test('prune: مفاتيح تنبيهات انحلّت تُزال من الاثنين', () async {
    await prefs.dismiss('m1:urgent');
    await prefs.dismiss('m2:low');
    await settle();
    await prefs.prune({'m2:low'});
    await settle();
    expect(prefs.alertDismissals, {'m2:low'});
    expect(cloud.dismissals, {'m2:low'});
  });
}
