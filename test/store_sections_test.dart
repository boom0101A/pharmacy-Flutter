import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/state/medicine_store.dart';

Medicine _item({
  required String id,
  String name = 'مادة',
  String barcode = '',
  double price = 100,
  int quantity = 5,
  ItemType type = ItemType.medicine,
  int createdAt = 0,
  String? category,
}) => Medicine(
  id: id,
  barcode: barcode,
  name: name,
  price: price,
  quantity: quantity,
  type: type,
  category: category,
  createdAt: createdAt,
  updatedAt: createdAt,
);

void main() {
  late MedicineStore store;

  setUp(() {
    store = MedicineStore()
      ..seed([
        _item(id: 'm1', name: 'Panadol', barcode: '111', createdAt: 1),
        _item(id: 'm2', name: 'Aspirin', barcode: '222', createdAt: 2),
        _item(id: 'm3', name: 'Zinc', barcode: '333', price: 0, createdAt: 3),
        _item(
          id: 's1',
          name: 'شاش طبي',
          type: ItemType.supply,
          price: 500,
          createdAt: 4,
        ),
        _item(
          id: 's2',
          name: 'قفازات',
          type: ItemType.supply,
          price: 0,
          quantity: 0,
          createdAt: 5,
        ),
      ]);
  });

  group('فصل الأقسام', () {
    test('كل قسم يرى مواده وحدها', () {
      expect(store.visibleFor(ItemType.medicine).length, 3);
      expect(store.visibleFor(ItemType.supply).length, 2);
      expect(store.countOf(ItemType.medicine), 3);
      expect(store.countOf(ItemType.supply), 2);
    });

    test('الإحصاءات تُحسب لكل قسم على حدة', () {
      // الأدوية: 100*5 + 100*5 + 0*5
      expect(store.totalValueOf(ItemType.medicine), 1000);
      // المستلزمات: 500*5 + 0*0
      expect(store.totalValueOf(ItemType.supply), 2500);
      expect(store.missingPriceCountOf(ItemType.medicine), 1);
      expect(store.missingPriceCountOf(ItemType.supply), 1);
    });

    test('البحث في قسم لا يؤثر على القسم الآخر', () {
      store.setActiveType(ItemType.medicine);
      store.setKeyword('Panadol');

      expect(store.visibleFor(ItemType.medicine).length, 1);
      // المستلزمات لم تُمَس
      expect(store.visibleFor(ItemType.supply).length, 2);

      // والتبديل يستعيد كلمة بحث القسم الآخر (فارغة) لا كلمة الأول
      store.setActiveType(ItemType.supply);
      expect(store.keyword, isEmpty);
      expect(store.visible.length, 2);

      // والعودة تستعيد بحث الأدوية كما تُرك
      store.setActiveType(ItemType.medicine);
      expect(store.keyword, 'Panadol');
      expect(store.visible.length, 1);
    });

    test('الفلاتر السريعة منفصلة لكل قسم', () {
      store.setActiveType(ItemType.supply);
      store.toggleQuickFilter(QuickFilter.outOfStock);

      expect(store.visibleFor(ItemType.supply).length, 1); // قفازات فقط
      expect(store.visibleFor(ItemType.medicine).length, 3); // بلا تأثير
      expect(store.activeFilterCount, 1);

      store.setActiveType(ItemType.medicine);
      expect(store.activeFilterCount, 0);
      expect(store.hasActiveFilters, isFalse);
    });

    test('نطاق السعر يخص قسمه', () {
      store.setActiveType(ItemType.medicine);
      store.setPriceRange(50, null);
      expect(store.visibleFor(ItemType.medicine).length, 2); // استُبعد Zinc
      expect(store.visibleFor(ItemType.supply).length, 2);
    });
  });

  group('ذاكرة النتائج المحسوبة', () {
    test('الاستدعاء المتكرر يعيد الكائن نفسه بلا إعادة فرز', () {
      final a = store.visibleFor(ItemType.medicine);
      final b = store.visibleFor(ItemType.medicine);
      // نفس المرجع = لم يُعَد الحساب (هذا ما يمنع التقطيع أثناء الانزلاق)
      expect(identical(a, b), isTrue);
    });

    test('أي تغيير في الحالة يُبطل الذاكرة', () {
      final before = store.visibleFor(ItemType.medicine);

      store.setKeyword('Aspirin');
      final after = store.visibleFor(ItemType.medicine);

      expect(identical(before, after), isFalse);
      expect(after.length, 1);
    });

    test('الذاكرة تُبطَل لكل الأقسام لا للقسم النشط وحده', () {
      final medBefore = store.visibleFor(ItemType.medicine);
      final supBefore = store.visibleFor(ItemType.supply);

      store.seed([_item(id: 'x', name: 'جديد', type: ItemType.supply)]);

      expect(
        identical(medBefore, store.visibleFor(ItemType.medicine)),
        isFalse,
      );
      expect(identical(supBefore, store.visibleFor(ItemType.supply)), isFalse);
      expect(store.visibleFor(ItemType.supply).length, 1);
      expect(store.visibleFor(ItemType.medicine), isEmpty);
    });
  });

  group('الترتيب', () {
    test('الافتراضي الأحدث أولاً', () {
      final list = store.visibleFor(ItemType.medicine);
      expect(list.first.id, 'm3'); // createdAt الأكبر
    });

    test('الترتيب بالاسم تصاعدياً ثم عكسه', () {
      store.setActiveType(ItemType.medicine);
      store.setSort(SortField.name);
      expect(store.visible.first.name, 'Aspirin');

      store.setSort(SortField.name); // نفس الحقل ⇒ يعكس الاتجاه
      expect(store.visible.first.name, 'Zinc');
    });

    test('ترتيب قسم لا يغيّر ترتيب الآخر', () {
      store.setActiveType(ItemType.medicine);
      store.setSort(SortField.price);
      expect(store.sortField, SortField.price);

      store.setActiveType(ItemType.supply);
      expect(store.sortField, SortField.date);
    });
  });

  group('البحث بنوع المادة', () {
    test('كلمة تطابق category فقط تُرجع النتيجة الصحيحة', () {
      store.seed([
        _item(
          id: 's1',
          name: 'مضاد حيوي',
          type: ItemType.supply,
          category: 'Cream',
        ),
        _item(
          id: 's2',
          name: 'شراب سعال',
          type: ItemType.supply,
          category: 'Syrup',
        ),
      ]);
      store.setActiveType(ItemType.supply);
      store.setKeyword('Cream');

      expect(store.visible.length, 1);
      expect(store.visible.first.id, 's1');
    });

    test('باركود 13 رقماً يطابق نسخته ذات الـ14 والعكس', () {
      store.seed([
        _item(id: 'a', name: 'أ').copyWith(barcode: '6285128013338'),
        _item(id: 'b', name: 'ب').copyWith(barcode: '06291100000012'),
      ]);
      store.setActiveType(ItemType.medicine);

      store.setKeyword('06285128013338');
      expect(store.visible.map((m) => m.id), ['a']);
      store.setKeyword('6291100000012');
      expect(store.visible.map((m) => m.id), ['b']);
      store.setKeyword('628512');
      expect(store.visible.map((m) => m.id), ['a']);
    });

    test('البحث باسم الشركة', () {
      store.seed([
        _item(id: 'd1', name: 'جل تسنين').copyWith(company: 'Juman'),
        _item(id: 'd2', name: 'شراب'),
      ]);
      store.setActiveType(ItemType.medicine);
      store.setKeyword('juman');

      expect(store.visible.map((m) => m.id), ['d1']);
    });

    test('لا حساسية لحالة الأحرف في مطابقة النوع', () {
      store.seed([
        _item(
          id: 's1',
          name: 'مادة',
          type: ItemType.supply,
          category: 'Tablet',
        ),
      ]);
      store.setActiveType(ItemType.supply);
      store.setKeyword('tablet');

      expect(store.visible.length, 1);
    });

    test('الاسم لا يزال يعمل بجانب النوع لا بدلاً منه', () {
      store.seed([
        _item(
          id: 's1',
          name: 'Panadol',
          type: ItemType.supply,
          category: 'Tablet',
        ),
        _item(
          id: 's2',
          name: 'Aspirin',
          type: ItemType.supply,
          category: 'Syrup',
        ),
      ]);
      store.setActiveType(ItemType.supply);
      store.setKeyword('Panadol');

      expect(store.visible.length, 1);
      expect(store.visible.first.id, 's1');
    });
  });
}
