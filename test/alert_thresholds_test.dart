import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/services/pharmacy_prefs.dart';

/// عتبات التنبيه: الصلاحية بمرحلتين (عاجل ≤ 30، قريب ≤ 90 — كانت 180)،
/// والمخزون المنخفض بحد خاص للمادة أو الحد العام للصيدلية.
Medicine _m({int qty = 10, int? minQty, int? inDays}) => Medicine(
  id: 'x',
  barcode: '',
  name: 'Panadol',
  price: 1000,
  quantity: qty,
  minQuantity: minQty,
  expiryDate: inDays == null
      ? null
      : DateTime.now()
            .add(Duration(days: inDays, hours: 2))
            .millisecondsSinceEpoch,
  createdAt: 0,
  updatedAt: 0,
);

void main() {
  tearDown(() => PharmacyPrefs.instance.debugSetLowStockDefault(5));

  group('الصلاحية', () {
    test('عاجل ≤ 30 يوماً وهو «قريب» أيضاً', () {
      expect(_m(inDays: 10).isExpiringUrgent, isTrue);
      expect(_m(inDays: 30).isExpiringUrgent, isTrue);
      expect(_m(inDays: 31).isExpiringUrgent, isFalse);
      expect(_m(inDays: 10).isExpiringSoon, isTrue);
    });

    test('قريب ≤ 90 — لا 180 كما كان', () {
      expect(_m(inDays: 90).isExpiringSoon, isTrue);
      expect(_m(inDays: 91).isExpiringSoon, isFalse);
      expect(_m(inDays: 150).isExpiringSoon, isFalse);
    });

    test('المنتهية ليست عاجلة ولا قريبة', () {
      expect(_m(inDays: -3).isExpired, isTrue);
      expect(_m(inDays: -3).isExpiringUrgent, isFalse);
      expect(_m(inDays: -3).isExpiringSoon, isFalse);
    });
  });

  group('المخزون المنخفض', () {
    test('الحد العام 5 افتراضياً', () {
      expect(_m(qty: 5).isLowStock, isTrue);
      expect(_m(qty: 6).isLowStock, isFalse);
      expect(_m(qty: 0).isLowStock, isFalse, reason: 'الصفر نافد لا منخفض');
    });

    test('الحد العام يتبع إعداد الصيدلية', () {
      PharmacyPrefs.instance.debugSetLowStockDefault(10);
      expect(_m(qty: 8).isLowStock, isTrue);
      expect(_m(qty: 11).isLowStock, isFalse);
    });

    test('الحد الخاص للمادة يتقدّم على العام', () {
      expect(_m(qty: 15, minQty: 20).isLowStock, isTrue);
      expect(_m(qty: 3, minQty: 2).isLowStock, isFalse);
      expect(_m(qty: 2, minQty: 2).lowStockThreshold, 2);
      expect(_m(qty: 2).lowStockThreshold, 5);
    });
  });

  group('الحد الخاص يُحفظ ويُقرأ', () {
    test('toMap/fromMap وcopyWith', () {
      final m = _m(minQty: 12);
      expect(Medicine.fromMap(m.toMap()).minQuantity, 12);
      expect(m.copyWith(minQuantity: 7).minQuantity, 7);
      expect(m.copyWith(clearMinQuantity: true).minQuantity, isNull);
      expect(m.copyWith(name: 'x').minQuantity, 12);
      expect(
        Medicine.fromMap({...m.toMap()}..remove('minQuantity')).minQuantity,
        isNull,
      );
    });
  });
}
