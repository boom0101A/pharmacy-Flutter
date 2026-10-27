import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/invoice.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/services/duplicate_dismissals.dart';
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
  String? image,
}) => Medicine(
  id: id,
  barcode: barcode,
  name: name,
  price: price,
  quantity: qty,
  expiryDate: expiry,
  imagePath: image,
  type: type,
  createdAt: 1,
  updatedAt: updated,
);

void main() {
  group('keysToDismissAfterMerge', () {
    test('غير المختارة تُخفى مع الباقية وفيما بينها', () {
      // بعد دمج j2 في j1: يبقى j1 + غير المختارتين t وr
      final after = [
        m('j1', name: 'بلاستر انف بعد عمليات ورقي m3 جوزي'),
        m('t', name: 'بلاسترانف بعد عمليات ورقي m3 شفاف'),
        m('r', name: 'بلاستر انة بعد عمليات ورقي m3 جوري'),
        m('other', name: 'شاش طبي'),
      ];
      final keys = keysToDismissAfterMerge(after, {'j1', 't', 'r'});
      expect(keys, isNotEmpty);
      final shown = [
        ...findDuplicateGroups(after, dismissed: keys.toSet()),
        ...findSimilarGroups(after, dismissed: keys.toSet()),
      ];
      expect(shown, isEmpty);
    });

    test('مجموعة فيها مادة من خارج المجموعة الأصلية لا تُخفى', () {
      final after = [
        m('keep', name: 'لوشن جونسون اطفال'),
        m('new', name: 'لوشن جونسن اطفال'),
      ];
      expect(keysToDismissAfterMerge(after, {'keep'}), isEmpty);
    });
  });

  group('invoiceLabel', () {
    test('من فاتورة محفوظة: تاريخها ومجهّزها', () {
      final inv = Invoice(
        id: 'i',
        supplier: 'مذخر الشفاء',
        dateMs: DateTime(2026, 10, 12).millisecondsSinceEpoch,
        createdAt: 1,
        updatedAt: 1,
      );
      expect(invoiceLabel(m('a'), inv), '🧾 فاتورة 2026/10/12 · مذخر الشفاء');
    });

    test('أنشأتها فاتورة ذكية قبل حفظ الفواتير: تاريخ إضافتها', () {
      final created = DateTime(2026, 8, 10).millisecondsSinceEpoch;
      final item = Medicine(
        id: 'inv_${created}_1_0',
        barcode: '',
        name: 'x',
        price: 0,
        quantity: 1,
        createdAt: created,
        updatedAt: created,
      );
      expect(invoiceLabel(item, null), '🧾 من فاتورة بتاريخ 2026/08/10');
    });

    test('مُدخلة يدوياً: بلا تسمية', () {
      expect(invoiceLabel(m('med_1'), null), isNull);
    });
  });

  group('findSimilarGroups', () {
    List<List<String>> ids(List<Medicine> items, {Set<String>? exclude}) => [
      for (final g in findSimilarGroups(items, exclude: exclude ?? {}))
        g.items.map((x) => x.id).toList()..sort(),
    ];

    test('خطأ إملائي بحرف ← متشابهة', () {
      expect(
        ids([
          m('a', name: 'لوشن جونسون اطفال'),
          m('b', name: 'لوشن جونسن اطفال'),
        ]),
        [
          ['a', 'b'],
        ],
      );
    });

    test('اسم ناقص كلمة ← متشابهة', () {
      expect(
        ids([m('a', name: 'Panadol Extra'), m('b', name: 'Panadol Extra Tab')]),
        [
          ['a', 'b'],
        ],
      );
    });

    test('تركيز مختلف ← يُعرض (قرار المستخدم)', () {
      expect(
        ids([
          m('a', name: 'Amaryl 4 mg ( 30 tab )'),
          m('b', name: 'Amaryl 2 mg ( 30 tab )'),
        ]),
        hasLength(1),
      );
    });

    test('باركودان صالحان مختلفان ← لا', () {
      expect(
        ids([
          m('a', name: 'لوشن جونسون اطفال', barcode: '6285128013338'),
          m('b', name: 'لوشن جونسن اطفال', barcode: '06291100000012'),
        ]),
        isEmpty,
      );
    });

    test('قسمان مختلفان ← لا', () {
      expect(
        ids([
          m('a', name: 'لوشن جونسون اطفال', type: ItemType.medicine),
          m('b', name: 'لوشن جونسن اطفال'),
        ]),
        isEmpty,
      );
    });

    test('كلمة عامة قصيرة لا تطابق كل ما يحتويها', () {
      expect(
        ids([m('a', name: 'جل'), m('b', name: 'جل مزلق جاكوار')]),
        isEmpty,
      );
    });

    test('أسماء مختلفة تماماً ← لا', () {
      expect(
        ids([m('a', name: 'شاش طبي'), m('b', name: 'شامبو اطفال')]),
        isEmpty,
      );
    });

    test('المستبعَد (في مجموعة مؤكّدة) لا يتكرر، والمفتاح مستقل', () {
      final items = [
        m('a', name: 'لوشن جونسون اطفال'),
        m('b', name: 'لوشن جونسن اطفال'),
      ];
      expect(ids(items, exclude: {'a'}), isEmpty);
      final g = findSimilarGroups(items).single;
      expect(g.key, startsWith('sim:'));
      expect(g.isSimilar, isTrue);
      expect(findSimilarGroups(items, dismissed: {g.key}), isEmpty);
    });

    test('المجموعة لا تتجاوز 6 مواد', () {
      final items = [
        for (var i = 0; i < 9; i++) m('$i', name: 'سرنج ${i}CC كورنر'),
      ];
      for (final g in findSimilarGroups(items)) {
        expect(g.items.length, lessThanOrEqualTo(6));
      }
    });
  });

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

  group('mergeGroup والصور', () {
    final now = DateTime(2026, 10, 19);
    test('صورة الباقية تبقى', () {
      final r = mergeGroup(
        [m('a', image: 'a.jpg'), m('b', image: 'b.jpg')],
        'a',
        now,
      );
      expect(r.imagePath, 'a.jpg');
    });
    test('بلا صورة للباقية تُؤخذ صورة أخرى من المجموعة', () {
      final r = mergeGroup([m('a'), m('b', image: 'b.jpg')], 'a', now);
      expect(r.imagePath, 'b.jpg');
    });
    test('الشركة ونوع المادة يُنقلان للباقية الفارغة ولا يستبدلان الموجود', () {
      final r = mergeGroup(
        [
          m('a'),
          m(
            'b',
            type: ItemType.medicine,
          ).copyWith(company: 'Juman', category: 'Syrup'),
        ],
        'a',
        now,
      );
      expect(r.company, 'Juman');
      expect(r.category, 'Syrup');

      final kept = mergeGroup(
        [m('a').copyWith(company: 'Old'), m('b').copyWith(company: 'New')],
        'a',
        now,
      );
      expect(kept.company, 'Old');
    });
  });

  group('reconcileReviewItems', () {
    test('المحذوف محلياً (طابور الحذف) مستبعد', () {
      final r = reconcileReviewItems(
        cloud: [m('a'), m('b')],
        local: [m('a')],
        deleted: {'b'},
      );
      expect(r.map((x) => x.id), ['a']);
    });
    test('النسخة المحلية الأحدث تفوز', () {
      final r = reconcileReviewItems(
        cloud: [m('a', qty: 5, updated: 1)],
        local: [m('a', qty: 9, updated: 2)],
      );
      expect(r.single.quantity, 9);
    });
    test('السحابية الأحدث تأخذ صورة الهاتف وختمها كما هو', () {
      final r = reconcileReviewItems(
        cloud: [m('a', qty: 5, updated: 3)],
        local: [m('a', qty: 9, updated: 2, image: 'a.jpg')],
      );
      expect(r.single.quantity, 5);
      expect(r.single.imagePath, 'a.jpg');
      expect(r.single.updatedAt, 3);
    });
    test('مادة محلية لم تُرفع بعد تُضاف، والسحابية وحدها تبقى', () {
      final r = reconcileReviewItems(cloud: [m('c')], local: [m('l')]);
      expect(r.map((x) => x.id), unorderedEquals(['c', 'l']));
    });
  });

  test('دمج قرارات «ليست مكرّرة» من جهازين لا يُفقد أياً منها', () {
    expect(DuplicateDismissals.merge({'a|b'}, {'c|d', 'a|b'}), {'a|b', 'c|d'});
  });

  // نفس الدواء والشركة بطعم/لون مختلف = باركود مختلف = منتج مختلف
  group('أصناف الطعم واللون', () {
    test('نفس الاسم وباركودان مختلفان ← ليست مجموعة', () {
      final g = findDuplicateGroups([
        m('a', name: 'Panadol Kids', barcode: '6281234567890'),
        m('b', name: 'Panadol Kids', barcode: '6281234567906'),
      ]);
      expect(g, isEmpty);
    });

    test('نفس الاسم وأحدهما بلا باركود ← مجموعة', () {
      final g = findDuplicateGroups([
        m('a', name: 'Panadol Kids', barcode: '6281234567890'),
        m('b', name: 'Panadol Kids'),
      ]);
      expect(g.single.items.length, 2);
    });

    test('نفس الاسم ونفس الباركود بصيغتين ← مجموعة', () {
      final g = findDuplicateGroups([
        m('a', name: 'Panadol Kids', barcode: '6281234567890'),
        m('b', name: 'Panadol Kids', barcode: '06281234567890'),
      ]);
      expect(g.single.items.length, 2);
    });

    test('مادة بلا باركود لا تجمع صنفين مختلفين في مجموعة واحدة', () {
      final g = findDuplicateGroups([
        m('a', name: 'Panadol Kids', barcode: '6281234567890'),
        m('b', name: 'Panadol Kids', barcode: '6281234567906'),
        m('c', name: 'Panadol Kids'),
      ]);
      for (final group in g) {
        final codes = group.items
            .map((x) => x.barcode)
            .where((b) => b.isNotEmpty)
            .toSet();
        expect(codes.length, lessThanOrEqualTo(1));
      }
    });
  });
}
