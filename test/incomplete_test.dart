import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';

Medicine _m({
  double price = 100,
  int qty = 5,
  String barcode = '6285128013338',
  bool noBarcode = false,
}) => Medicine(
  id: 'x',
  barcode: barcode,
  name: 'x',
  price: price,
  quantity: qty,
  noBarcode: noBarcode,
  createdAt: 0,
  updatedAt: 0,
);

void main() {
  group('isIncomplete', () {
    test('مكتملة: سعر وباركود', () => expect(_m().isIncomplete, isFalse));
    test('بلا سعر', () => expect(_m(price: 0).isIncomplete, isTrue));
    test('بلا باركود', () => expect(_m(barcode: '').isIncomplete, isTrue));
    test('بلا باركود مؤكَّد («ليس لها باركود»)', () {
      expect(_m(barcode: '', noBarcode: true).isIncomplete, isFalse);
    });
    test('«ليس لها باركود» لا يعفي من السعر', () {
      expect(_m(price: 0, barcode: '', noBarcode: true).isIncomplete, isTrue);
    });
  });

  group('isSoldOut', () {
    test('صفر بسعر = نافدة', () => expect(_m(qty: 0).isSoldOut, isTrue));
    test('صفر بلا سعر = ناقصة لا نافدة', () {
      expect(_m(qty: 0, price: 0).isSoldOut, isFalse);
    });
  });

  group('noBarcode عبر toMap/fromMap', () {
    test('ذهاباً وإياباً', () {
      final back = Medicine.fromMap(_m(noBarcode: true).toMap());
      expect(back.noBarcode, isTrue);
    });
    test('قيم السحابة المتنوعة والسجلات القديمة', () {
      Map<String, Object?> map(Object? v) => _m().toMap()..['noBarcode'] = v;
      expect(Medicine.fromMap(map(true)).noBarcode, isTrue);
      expect(Medicine.fromMap(map(1)).noBarcode, isTrue);
      expect(Medicine.fromMap(map(0)).noBarcode, isFalse);
      expect(Medicine.fromMap(map(null)).noBarcode, isFalse);
      expect(
        Medicine.fromMap(_m().toMap()..remove('noBarcode')).noBarcode,
        isFalse,
      );
    });
    test('copyWith يحفظها ويغيّرها', () {
      expect(_m(noBarcode: true).copyWith(price: 5).noBarcode, isTrue);
      expect(_m(noBarcode: true).copyWith(noBarcode: false).noBarcode, isFalse);
    });
  });
}
