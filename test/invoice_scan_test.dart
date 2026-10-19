import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/screens/invoice_scan_screen.dart';
import 'package:saydaliyati/services/gemini_vision.dart';
import 'package:saydaliyati/state/medicine_store.dart';

/// اختبارات `buildInvoiceSaveItems` — الدالة الصِرفة التي تدمج أسطر الفاتورة
/// المكرَّرة قبل مقارنتها بالمخزون. تغطي العطلين الحقيقيين اللذين وُجدا:
/// (أ) مادتان جديدتان بنفس الاسم في نفس الفاتورة كانتا تُنتجان سجلّين
/// منفصلين، و(ب) مادتان تطابقان سجلاً موجوداً سلفاً كانتا تفقدان كمية إحداهما
/// بصمت (نفس `id` بكميتين مختلفتين، `saveAll` يُبقي الأخير فقط).
class _TestStore extends MedicineStore {
  @override
  Future<void> load() async {}
  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}
}

InvoiceLineDraft _draft(
  String name, {
  ItemType type = ItemType.supply,
  double price = 0,
  int quantity = 0,
  String barcode = '',
  String? category,
  int? expiryDate,
}) => InvoiceLineDraft(
  name: name,
  type: type,
  price: price,
  quantity: quantity,
  barcode: barcode,
  category: category,
  expiryDate: expiryDate,
);

void main() {
  final now = DateTime(2026, 1, 1, 9);

  group('buildInvoiceSaveItems — دمج التكرار داخل الفاتورة نفسها', () {
    test('سطران جديدان بنفس الاسم/القسم → سجل واحد بكمية مجموعة', () {
      final store = _TestStore();
      final result = buildInvoiceSaveItems(
        drafts: [
          _draft('قفازات طبية', quantity: 10, price: 500),
          _draft('قفازات طبية', quantity: 5, price: 600),
        ],
        store: store,
        now: now,
      );

      expect(result.items.length, 1);
      expect(result.items.single.quantity, 15);
      expect(result.addedNew, 1);
      expect(result.mergedExisting, 0);
      expect(result.mergedWithinInvoice, 1);
    });

    test(
      'سطران يطابقان سجلاً موجوداً مسبقاً → سجل واحد بكمية القديم + كليهما (لا فقدان صامت)',
      () {
        final store = _TestStore()
          ..seed([
            Medicine(
              id: 'existing1',
              barcode: '',
              name: 'قفازات طبية',
              price: 400,
              quantity: 20,
              type: ItemType.supply,
              createdAt: 0,
              updatedAt: 0,
            ),
          ]);

        final result = buildInvoiceSaveItems(
          drafts: [
            _draft('قفازات طبية', quantity: 10),
            _draft('قفازات طبية', quantity: 7),
          ],
          store: store,
          now: now,
        );

        expect(result.items.length, 1);
        expect(result.items.single.id, 'existing1');
        // 20 (قديم) + 10 + 7 — لو لم يُدمَج داخل الفاتورة أولاً لكانت إحدى
        // الزيادتين تضيع بصمت (كلتا الحسابين تنطلقان من نفس القديم 20).
        expect(result.items.single.quantity, 37);
        expect(result.addedNew, 0);
        expect(result.mergedExisting, 1);
        expect(result.mergedWithinInvoice, 1);
      },
    );

    test('سطر واحد جديد كلياً بلا أي تكرار', () {
      final store = _TestStore();
      final result = buildInvoiceSaveItems(
        drafts: [_draft('دواء فريد', quantity: 3)],
        store: store,
        now: now,
      );

      expect(result.items.length, 1);
      expect(result.addedNew, 1);
      expect(result.mergedExisting, 0);
      expect(result.mergedWithinInvoice, 0);
    });

    test('نفس الاسم لكن قسمين مختلفين (دواء/مستلزم) → لا يُدمجان', () {
      final store = _TestStore();
      final result = buildInvoiceSaveItems(
        drafts: [
          _draft('باراسيتامول', type: ItemType.medicine, quantity: 10),
          _draft('باراسيتامول', type: ItemType.supply, quantity: 5),
        ],
        store: store,
        now: now,
      );

      expect(result.items.length, 2);
      expect(result.addedNew, 2);
      expect(result.mergedWithinInvoice, 0);
    });

    test('التطبيع يتجاهل حالة الأحرف والمسافات الزائدة', () {
      final store = _TestStore();
      final result = buildInvoiceSaveItems(
        drafts: [
          _draft('  Gloves  ', quantity: 4),
          _draft('gloves', quantity: 6),
        ],
        store: store,
        now: now,
      );

      expect(result.items.length, 1);
      expect(result.items.single.quantity, 10);
    });

    test(
      'الفئة (category) تُحفَظ للمستلزم فقط، وتُمسَح إن كان القسم دواءً',
      () {
        final store = _TestStore();
        final supplyResult = buildInvoiceSaveItems(
          drafts: [_draft('كريم', category: 'Cream', quantity: 1)],
          store: store,
          now: now,
        );
        expect(supplyResult.items.single.category, 'Cream');

        final medResult = buildInvoiceSaveItems(
          drafts: [
            _draft(
              'دواء',
              type: ItemType.medicine,
              category: 'Tablet',
              quantity: 1,
            ),
          ],
          store: store,
          now: now,
        );
        expect(medResult.items.single.category, isNull);
      },
    );

    test(
      'الدمج داخل الفاتورة: يُحتفَظ بالباركود الموجود إن كان لسطر واحد فقط',
      () {
        final store = _TestStore();
        final result = buildInvoiceSaveItems(
          drafts: [
            _draft('شراب', quantity: 2, barcode: ''),
            _draft('شراب', quantity: 3, barcode: '12345'),
          ],
          store: store,
          now: now,
        );
        expect(result.items.single.barcode, '12345');
      },
    );

    test('أسطر بأسماء فارغة تُتجاهَل بلا رمي استثناء', () {
      final store = _TestStore();
      final result = buildInvoiceSaveItems(
        drafts: [_draft('   '), _draft('مادة صالحة', quantity: 1)],
        store: store,
        now: now,
      );
      expect(result.items.length, 1);
      expect(result.items.single.name, 'مادة صالحة');
    });

    test('قائمة فارغة تعيد نتيجة فارغة بلا أخطاء', () {
      final store = _TestStore();
      final result = buildInvoiceSaveItems(
        drafts: const [],
        store: store,
        now: now,
      );
      expect(result.items, isEmpty);
      expect(result.addedNew, 0);
      expect(result.mergedExisting, 0);
      expect(result.mergedWithinInvoice, 0);
    });
  });

  /// تاريخ الصلاحية المقروء من الفاتورة.
  ///
  /// السنة ذات الرقمين (`11/27`) هي الأشيع في فواتير الصيدليات، وكانت تُرفض
  /// فتُحفظ المادة **بلا تاريخ صلاحية إطلاقاً** — أي دواء منتهٍ لا يظهر أبداً
  /// في تنبيهات الصلاحية.
  group('تحليل تاريخ الصلاحية من نص الفاتورة', () {
    DateTime? parsed(String raw) {
      final line = InvoiceLine(name: 'مادة', expiry: raw);
      final med = line.toMedicine(type: ItemType.medicine, now: now);
      return med.expiry;
    }

    test('سنة من رقمين بصيغة شهر/سنة — 11/27', () {
      final d = parsed('11/27');
      expect(d, isNotNull);
      expect(d!.year, 2027);
      expect(d.month, 11);
    });

    test('سنة من رقمين بصيغة يوم/شهر/سنة — 1/1/27', () {
      final d = parsed('1/1/27');
      expect(d, isNotNull);
      expect(d!.year, 2027);
      expect(d.month, 1);
      expect(d.day, 1);
    });

    test(
      'يوم خارج نطاق الشهر يُقصَر على آخر يوم فيه لا ينزلق للشهر التالي',
      () {
        final d = parsed('2027-11-31');
        expect(d, isNotNull);
        expect(d!.month, 11, reason: 'نوفمبر 30 يوماً — لا انزلاق إلى ديسمبر');
        expect(d.day, 30);
      },
    );

    test('الصيغ ذات السنة الرباعية تبقى تعمل كما كانت', () {
      expect(parsed('2027-11')?.year, 2027);
      expect(parsed('11/2027')?.month, 11);
      expect(parsed('30-11-2027')?.day, 30);
    });

    test('شهر بلا يوم يأخذ آخر يوم في الشهر (الصلاحية تنتهي بنهايته)', () {
      final d = parsed('2027-02');
      expect(d!.day, 28, reason: 'فبراير 2027 غير كبيسة');
    });

    test('نص غير صالح أو سنة خارج المدى يعيد null بلا رمي', () {
      expect(parsed('غير معروف'), isNull);
      expect(parsed('13/2027'), isNull, reason: 'شهر 13 غير صالح');
      expect(parsed('11/1999'), isNull, reason: 'سنة خارج المدى المعقول');
    });
  });

  group('مطابقة الباركود والصلاحية', () {
    Medicine existing({String barcode = '', int? expiry}) => Medicine(
      id: 'e1',
      barcode: barcode,
      name: 'Klamoks Fort 312.5 mg ( 100 ml )',
      price: 3000,
      quantity: 6,
      expiryDate: expiry,
      type: ItemType.medicine,
      createdAt: 0,
      updatedAt: 0,
    );

    // الباركود في الفاتورة يخص مادة موجودة باسم مكتوب بشكل آخر: كان يُنشأ سجل
    // جديد بنفس الباركود، فيحذف upsert(replace) المادة الأصلية محلياً
    // وتبقى النسختان في السحابة — مصدر مجموعات الباركود المكرّرة.
    test('باركود مادة موجودة واسم مختلف → يُدمج معها لا سجل جديد', () {
      final store = _TestStore()..seed([existing(barcode: '6285128013338')]);
      final r = buildInvoiceSaveItems(
        drafts: [
          _draft(
            'Klamoks 312.5mg Syrup 100ml',
            type: ItemType.medicine,
            quantity: 20,
            barcode: '6285128013338',
          ),
        ],
        store: store,
        now: now,
      );
      expect(r.items.single.id, 'e1');
      expect(r.items.single.quantity, 26);
      expect(r.addedNew, 0);
    });

    test('مطابقة الباركود تقبل الصيغة المكافئة (13 مقابل 14 خانة)', () {
      final store = _TestStore()..seed([existing(barcode: '06285128013338')]);
      final r = buildInvoiceSaveItems(
        drafts: [
          _draft(
            'X',
            type: ItemType.medicine,
            quantity: 1,
            barcode: '6285128013338',
          ),
        ],
        store: store,
        now: now,
      );
      expect(r.items.single.id, 'e1');
    });

    test('الصلاحية تنتقل للمادة الجديدة', () {
      final r = buildInvoiceSaveItems(
        drafts: [_draft('شاش', quantity: 5, expiryDate: 1900000000000)],
        store: _TestStore(),
        now: now,
      );
      expect(r.items.single.expiryDate, 1900000000000);
    });

    test('المادة المدموجة تأخذ الصلاحية الأقرب', () {
      final store = _TestStore()
        ..seed([existing(barcode: '6285128013338', expiry: 1800000000000)]);
      final later = buildInvoiceSaveItems(
        drafts: [
          _draft(
            'X',
            type: ItemType.medicine,
            quantity: 1,
            barcode: '6285128013338',
            expiryDate: 1900000000000,
          ),
        ],
        store: store,
        now: now,
      );
      expect(later.items.single.expiryDate, 1800000000000);
      final sooner = buildInvoiceSaveItems(
        drafts: [
          _draft(
            'X',
            type: ItemType.medicine,
            quantity: 1,
            barcode: '6285128013338',
            expiryDate: 1700000000000,
          ),
        ],
        store: store,
        now: now,
      );
      expect(sooner.items.single.expiryDate, 1700000000000);
    });
  });

  // سطران بباركود واحد واسمين مختلفين: كانا يُنتجان سجلّين بنفس المعرّف (تضيع
  // كمية الأول) أو سجلّين جديدين بنفس الباركود (يحذف الثاني الأول محلياً
  // ويُرفعان كلاهما للسحابة — أصل مجموعات الباركود المكرّرة).
  group('سطران بنفس الباركود واسمين مختلفين', () {
    const stocked = Medicine(
      id: 'e1',
      barcode: '6285128013338',
      name: 'Klamoks',
      price: 3000,
      quantity: 6,
      type: ItemType.supply,
      createdAt: 0,
      updatedAt: 0,
    );

    test('مادة موجودة → سجل واحد بكل الكمية', () {
      final r = buildInvoiceSaveItems(
        drafts: [
          _draft('Klamoks Fort', quantity: 10, barcode: '6285128013338'),
          _draft('KLAMOKS 312', quantity: 5, barcode: '06285128013338'),
        ],
        store: _TestStore()..seed([stocked]),
        now: now,
      );
      expect(r.items.length, 1);
      expect(r.items.single.id, 'e1');
      expect(r.items.single.quantity, 21);
    });

    test('مادة جديدة → سجل جديد واحد لا سجلان', () {
      final r = buildInvoiceSaveItems(
        drafts: [
          _draft('Gauze A', quantity: 10, price: 500, barcode: '6285128013338'),
          _draft('Gauze B', quantity: 4, barcode: '6285128013338'),
        ],
        store: _TestStore()..seed([]),
        now: now,
      );
      expect(r.items.length, 1);
      expect(r.items.single.quantity, 14);
      expect(r.items.single.price, 500);
      expect(r.addedNew, 1);
      expect(r.mergedWithinInvoice, 1);
    });

    test('سطر بالباركود وآخر بالاسم يطابقان المادة نفسها → سجل واحد', () {
      final r = buildInvoiceSaveItems(
        drafts: [
          _draft('Other name', quantity: 10, barcode: '6285128013338'),
          _draft('klamoks', quantity: 2),
        ],
        store: _TestStore()..seed([stocked]),
        now: now,
      );
      expect(r.items.length, 1);
      expect(r.items.single.quantity, 18);
    });

    test('كمية أو سعر سالب لا يُنقص الرصيد', () {
      final r = buildInvoiceSaveItems(
        drafts: [_draft('X', quantity: -5, price: -100)],
        store: _TestStore()..seed([]),
        now: now,
      );
      expect(r.items.single.quantity, 0);
      expect(r.items.single.price, 0);
    });
  });
}
