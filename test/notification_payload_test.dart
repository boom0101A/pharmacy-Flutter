import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/services/pharmacy_prefs.dart';
import 'package:saydaliyati/services/notification_service.dart';

/// اختبارات دالة `computePayload` — دالة صِرفة تحدّد ماذا يفتح الإشعار عليه.
///
/// الأولوية المتَّفَق عليها (متطلَّب المستخدم):
///   1. صلاحية دواء → قسم الأدوية بفلتر «قاربة الانتهاء»
///   2. صلاحية مستلزم → قسم المستلزمات بفلتر «قاربة الانتهاء»
///   3. نافد أدوية → قسم الأدوية بفلتر «منخفض أو نافد»
///   4. نافد مستلزمات → قسم المستلزمات بفلتر «منخفض أو نافد»
///   5. منخفض أدوية → «منخفض»
///   6. منخفض مستلزمات → «منخفض»
///   7. لا شيء → null
Medicine make({
  required String id,
  ItemType type = ItemType.medicine,
  int quantity = 50,
  double price = 1000,
  DateTime? expiry,
}) => Medicine(
  id: id,
  barcode: '',
  name: id,
  price: price,
  quantity: quantity,
  type: type,
  expiryDate: expiry?.millisecondsSinceEpoch,
  createdAt: 0,
  updatedAt: 0,
);

void main() {
  // عتبة «منخفض» 5 صراحةً: الاختبارات هنا لمنطق المنخفض نفسه، والافتراضي صار 1
  setUpAll(() => PharmacyPrefs.instance.debugSetLowStockDefault(5));
  tearDownAll(PharmacyPrefs.instance.resetForTest);

  final today = DateTime.now();
  final expired = today.subtract(const Duration(days: 30));
  final soon = today.add(const Duration(days: 60)); // قارب من الانتهاء
  final far = today.add(const Duration(days: 400)); // بعيد

  group('computePayload — الأولوية', () {
    test('قائمة سليمة كاملة → null (لا حاجة لإشعار)', () {
      final all = [
        make(id: 'm1', quantity: 20, expiry: far),
        make(id: 's1', type: ItemType.supply, quantity: 20, expiry: far),
      ];
      expect(NotificationService.computePayload(all), isNull);
    });

    test('دواء منتهي → medicine|expiringSoon (الأولوية للأدوية)', () {
      final all = [
        make(id: 'm1', expiry: expired),
        make(id: 's1', type: ItemType.supply, expiry: expired),
      ];
      expect(
        NotificationService.computePayload(all),
        'type:medicine|filter:expiringSoon',
      );
    });

    test('دواء قارب فقط (مستلزمات سليمة) → medicine|expiringSoon', () {
      final all = [
        make(id: 'm1', expiry: soon),
        make(id: 's1', type: ItemType.supply, expiry: far),
      ];
      expect(
        NotificationService.computePayload(all),
        'type:medicine|filter:expiringSoon',
      );
    });

    test('لا صلاحية أدوية لكن صلاحية مستلزم → supply|expiringSoon', () {
      final all = [
        make(id: 'm1', expiry: far),
        make(id: 's1', type: ItemType.supply, expiry: expired),
      ];
      expect(
        NotificationService.computePayload(all),
        'type:supply|filter:expiringSoon',
      );
    });

    test('بلا صلاحية، دواء نافد → medicine|lowStock (منخفض أو نافد)', () {
      final all = [
        make(id: 'm1', quantity: 0),
        make(id: 's1', type: ItemType.supply, quantity: 20),
      ];
      expect(
        NotificationService.computePayload(all),
        'type:medicine|filter:lowStock',
      );
    });

    test('دواء بكمية 0 بلا سعر (ناقص لا نافد) لا يُطلق إشعار نفاد', () {
      final all = [make(id: 'm1', quantity: 0, price: 0, expiry: far)];
      expect(NotificationService.computePayload(all), isNull);
      expect(NotificationService.buildSummary(all), isNull);
    });

    test('بلا صلاحية ولا أدوية نافدة، مستلزم نافد → supply|lowStock', () {
      final all = [
        make(id: 'm1', quantity: 20),
        make(id: 's1', type: ItemType.supply, quantity: 0),
      ];
      expect(
        NotificationService.computePayload(all),
        'type:supply|filter:lowStock',
      );
    });

    test('دواء منخفض فقط → medicine|lowStock', () {
      final all = [make(id: 'm1', quantity: 3)];
      expect(
        NotificationService.computePayload(all),
        'type:medicine|filter:lowStock',
      );
    });

    test('مستلزم منخفض فقط (لا شيء غيره) → supply|lowStock', () {
      final all = [make(id: 's1', type: ItemType.supply, quantity: 3)];
      expect(
        NotificationService.computePayload(all),
        'type:supply|filter:lowStock',
      );
    });

    test('قائمة فارغة → null', () {
      expect(NotificationService.computePayload(const []), isNull);
    });

    test('صلاحية أدوية + مخزون نافد للأدوية → الأولوية للصلاحية', () {
      // بلا هذا الاختبار قد يتغيّر الترتيب سهواً وتظهر «نفد» بدل «قارب»
      final all = [make(id: 'm1', quantity: 0, expiry: expired)];
      expect(
        NotificationService.computePayload(all),
        'type:medicine|filter:expiringSoon',
      );
    });
  });
}
