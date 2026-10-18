import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/services/duplicates.dart';

Medicine m(
  String id, {
  String name = 'x',
  String barcode = '',
  ItemType type = ItemType.supply,
  double price = 0,
  int qty = 1,
  int? expiry,
  int updated = 1,
}) => Medicine(
  id: id,
  barcode: barcode,
  name: name,
  price: price,
  quantity: qty,
  expiryDate: expiry,
  type: type,
  createdAt: 1,
  updatedAt: updated,
);

void main() {
  group('findDuplicateGroups', () {
    test('نفس الاسم المطبَّع في نفس القسم = مجموعة', () {
      final g = findDuplicateGroups([
        m('a', name: 'لزقة خافض حرارة'),
        m('b', name: '  لزقة   خافض حرارة '),
        m('c', name: 'شاش'),
      ]);
      expect(g.single.items.map((x) => x.id), unorderedEquals(['a', 'b']));
      expect(g.single.byBarcode, isFalse);
    });

    test('نفس الاسم في قسمين مختلفين ليس تكراراً', () {
      final g = findDuplicateGroups([
        m('a', name: 'Rennie', type: ItemType.medicine),
        m('b', name: 'Rennie', type: ItemType.supply),
      ]);
      expect(g, isEmpty);
    });

    test('نفس الباركود بصيغتي 13 و14 خانة = مجموعة ولو اختلف الاسم والقسم', () {
      final g = findDuplicateGroups([
        m('a', name: 'صابون جونسن ابيض', barcode: '6285128013338'),
        m(
          'b',
          name: 'صابون جونسون اطفال',
          barcode: '06285128013338',
          type: ItemType.medicine,
        ),
      ]);
      expect(g.single.items.length, 2);
      expect(g.single.byBarcode, isTrue);
    });

    test('المجموعات المتداخلة تتوحّد', () {
      // a وb بالاسم، b وc بالباركود ⇒ مجموعة واحدة من ثلاثة
      final g = findDuplicateGroups([
        m('a', name: 'Rennie'),
        m('b', name: 'rennie', barcode: '6285128013338'),
        m('c', name: 'Rennie 96 tab', barcode: '6285128013338'),
      ]);
      expect(g.single.items.map((x) => x.id), unorderedEquals(['a', 'b', 'c']));
    });

    test('المجموعة المرفوضة («ليست مكرّرة») لا تظهر', () {
      final items = [m('a', name: 'Rennie'), m('b', name: 'Rennie')];
      final key = findDuplicateGroups(items).single.key;
      expect(findDuplicateGroups(items, dismissed: {key}), isEmpty);
    });

    test('مفتاح المجموعة ثابت مهما كان الترتيب', () {
      final k1 = findDuplicateGroups([m('a', name: 'R'), m('b', name: 'R')]);
      final k2 = findDuplicateGroups([m('b', name: 'R'), m('a', name: 'R')]);
      expect(k1.single.key, k2.single.key);
    });
  });

  group('mergeGroup', () {
    final now = DateTime(2026, 10, 18, 12);
    final group = [
      m(
        'a',
        name: 'لزقة',
        qty: 20,
        price: 500,
        expiry: 1900000000000,
        updated: 100,
      ),
      m(
        'b',
        name: 'لزقة',
        qty: 20,
        price: 0,
        expiry: 1800000000000,
        updated: 300,
      ),
      m(
        'c',
        name: 'لزقة',
        qty: 70,
        price: 650,
        barcode: '6285128013339',
        updated: 200,
      ),
    ];

    test('الكمية مجموعة، والسعر من الأحدث غير الصفري، والصلاحية الأقرب', () {
      final r = mergeGroup(group, 'a', now);
      expect(r.id, 'a');
      expect(r.quantity, 110);
      expect(r.price, 650); // b أحدث لكن سعره صفر ⇒ c
      expect(r.expiryDate, 1800000000000);
      expect(r.updatedAt, now.millisecondsSinceEpoch);
    });

    test('الباركود: أول باركود صالح فقط', () {
      // c باركوده بخانة تحقق خاطئة ⇒ لا يُعتمد
      expect(mergeGroup(group, 'a', now).barcode, '');
      final withValid = [
        ...group,
        m('d', name: 'لزقة', barcode: '6285128013338'),
      ];
      expect(mergeGroup(withValid, 'a', now).barcode, '6285128013338');
    });
  });
}
