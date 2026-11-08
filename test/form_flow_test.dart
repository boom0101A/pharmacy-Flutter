import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/screens/form_screen.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';

/// اختبار نموذج الإضافة/التعديل — أكثر شاشة يستعملها المستخدم يومياً.
///
/// يركّز على الإصلاح الأخطر في هذه الجولة: إدخال باركود مادة موجودة كان يُنشئ
/// سجلاً ثانياً بدل تحديث الموجود، وهو سبب التكرار المرصود في بيانات المستخدم.
///
/// **مخزن في الذاكرة عمداً:** `sqflite` ينفّذ في عزلة منفصلة، وزمن اختبارات
/// الواجهة مُزيَّف، فلا تكتمل عمليات القرص داخلها أبداً وتتجمّد الاختبارات.
/// سلوك القاعدة نفسه مغطّى في `db_migration_test.dart` على قاعدة حقيقية.
class _MemoryStore extends MedicineStore {
  final List<Medicine> saved = [];
  final Map<String, Medicine> byBarcode = {};

  /// تأخير اصطناعي — بلا زمن I/O حقيقي، يكتمل `save()` خلال نفس دورة
  /// الأحداث فلا يُلتقَط أي حالة "جارٍ الحفظ" وسيطة في اختبار الواجهة.
  Duration saveDelay = Duration.zero;

  @override
  Future<void> load() async {}

  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}

  @override
  Future<Medicine?> findByBarcode(String barcode) async {
    final code = barcode.trim();
    // مطابقة الصيغ المكافئة: EAN-13 مقابل GTIN-14 بصفر بادئ
    for (final entry in byBarcode.entries) {
      if (entry.key == code ||
          entry.key.padLeft(14, '0') == code.padLeft(14, '0')) {
        return entry.value;
      }
    }
    return null;
  }

  @override
  Future<void> save(Medicine medicine) async {
    if (saveDelay > Duration.zero) await Future.delayed(saveDelay);
    saved.removeWhere((m) => m.id == medicine.id);
    saved.add(medicine);
    if (medicine.barcode.isNotEmpty) byBarcode[medicine.barcode] = medicine;
  }
}

void main() {
  late _MemoryStore store;

  setUp(() => store = _MemoryStore());

  /// شاشة اختبار طويلة عمداً: النموذج قائمة طويلة، وبارتفاع افتراضي تبقى
  /// نصف حقوله غير مبنية فلا تجدها المحدِّدات ولا يمكن الضغط على «حفظ».
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget host(Widget child) => MaterialApp(
    theme: buildAppTheme(),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, inner) =>
        Directionality(textDirection: TextDirection.rtl, child: inner!),
    home: child,
  );

  // مفاتيح ثابتة لا فهارس رقمية — حقل «نوع المادة» يظهر بين الاسم والسعر
  // للمستلزمات فقط فيزيح كل ما بعده، والمفتاح لا يتأثر بذلك.
  Finder barcodeField() => find.byKey(const Key('barcodeField'));
  Finder nameField() => find.byKey(const Key('nameField'));
  Finder categoryField() => find.byKey(const Key('categoryField'));
  Finder priceField() => find.byKey(const Key('priceField'));
  Finder quantityField() => find.byKey(const Key('quantityField'));

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.check_rounded));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> submitBarcode(WidgetTester tester, String code) async {
    await tester.enterText(barcodeField(), code);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('إضافة مادة جديدة', () {
    testWidgets('الاسم مطلوب — الحفظ يُرفض بلا اسم', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(host(MedicineFormScreen(store: store)));
      await tester.pump();

      await tapSave(tester);

      expect(find.text('الاسم مطلوب'), findsOneWidget);
      expect(store.saved, isEmpty);
    });

    testWidgets('الحفظ ينشئ مادة بالنوع المفتوح منه', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        host(MedicineFormScreen(store: store, initialType: ItemType.supply)),
      );
      await tester.pump();

      await tester.enterText(nameField(), 'شاش طبي معقم');
      await tester.enterText(priceField(), '750');
      await tester.enterText(quantityField(), '12');
      await tester.pump();
      await tapSave(tester);

      expect(store.saved.length, 1);
      final item = store.saved.first;
      expect(item.name, 'شاش طبي معقم');
      expect(item.price, 750);
      expect(item.quantity, 12);
      expect(
        item.type,
        ItemType.supply,
        reason: 'المادة تُنسب إلى القسم الذي فُتح منه النموذج',
      );
    });

    testWidgets('العنوان وزر الحفظ يتبعان النوع', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(host(MedicineFormScreen(store: store)));
      await tester.pump();
      expect(find.text('إضافة دواء جديد'), findsOneWidget);
      expect(find.text('حفظ الدواء'), findsOneWidget);
      expect(find.text('💊 اسم الدواء *'), findsOneWidget);

      await tester.tap(find.text('🩹 مستلزم طبي'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('إضافة مستلزم جديد'), findsOneWidget);
      expect(find.text('حفظ المستلزم'), findsOneWidget);
      expect(find.text('🩹 اسم المستلزم *'), findsOneWidget);
    });

    testWidgets('تغيير النوع يدوياً يُحفظ فعلاً', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(host(MedicineFormScreen(store: store)));
      await tester.pump();

      await tester.tap(find.text('🩹 مستلزم طبي'));
      await tester.pump();
      await tester.enterText(nameField(), 'قفازات فحص');
      await tester.pump();
      await tapSave(tester);

      expect(store.saved.single.type, ItemType.supply);
    });
  });

  // كان صندوق الصورة يعرض 💊 حتى للمستلزمات، والبطاقات تعرض 🩹
  testWidgets('صورة المستلزم الفارغة 🩹 والدواء 💊', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      host(MedicineFormScreen(store: store, initialType: ItemType.supply)),
    );
    await tester.pump();
    expect(find.text('🩹'), findsOneWidget);
    expect(find.text('💊'), findsNothing);

    await tester.tap(find.text('💊 دواء'));
    await tester.pump();
    expect(find.text('💊'), findsOneWidget);
    // زر الماسح بجانب الخانة له اسم يقرؤه قارئ الشاشة
    expect(find.byTooltip('مسح باركود'), findsOneWidget);
  });

  group('نوع المادة (الشكل الصيدلاني) — للأدوية فقط، والشركة للقسمين', () {
    Finder companyField() => find.byKey(const Key('companyField'));

    testWidgets('الحقل لا يظهر عند إضافة مستلزم، والشركة تظهر', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        host(MedicineFormScreen(store: store, initialType: ItemType.supply)),
      );
      await tester.pump();

      expect(categoryField(), findsNothing);
      expect(companyField(), findsOneWidget);

      await tester.enterText(nameField(), 'شاش طبي');
      await tester.enterText(companyField(), 'Juman');
      await tester.pump();
      await tapSave(tester);

      expect(store.saved.single.company, 'Juman');
      expect(store.saved.single.category, isNull);
    });

    testWidgets('الحقلان يظهران عند إضافة دواء ويُحفظان', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(host(MedicineFormScreen(store: store)));
      await tester.pump();

      expect(categoryField(), findsOneWidget);

      await tester.enterText(nameField(), 'باراسيتامول');
      await tester.enterText(categoryField(), 'Tablet');
      await tester.enterText(companyField(), 'SDI');
      await tester.pump();
      await tapSave(tester);

      expect(store.saved.single.category, 'Tablet');
      expect(store.saved.single.company, 'SDI');
    });

    testWidgets('حقلان فارغان يُحفظان null لا نصاً فارغاً', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(host(MedicineFormScreen(store: store)));
      await tester.pump();

      await tester.enterText(nameField(), 'دواء ما');
      await tapSave(tester);

      expect(store.saved.single.category, isNull);
      expect(store.saved.single.company, isNull);
    });

    testWidgets('التبديل إلى مستلزم يخفي الحقل ولا يحفظ قيمته', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(host(MedicineFormScreen(store: store)));
      await tester.pump();

      await tester.enterText(nameField(), 'مادة ما');
      await tester.enterText(categoryField(), 'Vial');
      await tester.pump();

      await tester.tap(find.text('🩹 مستلزم طبي'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(categoryField(), findsNothing);

      await tapSave(tester);
      expect(store.saved.single.category, isNull);
      expect(store.saved.single.type, ItemType.supply);
    });

    testWidgets('تعديل دواء موجود يملأ الحقلين بقيمهما المحفوظة', (
      tester,
    ) async {
      useTallSurface(tester);
      const existing = Medicine(
        id: 'd1',
        barcode: '',
        name: 'شراب سعال',
        price: 500,
        quantity: 5,
        category: 'Syrup',
        company: 'Juman',
        createdAt: 0,
        updatedAt: 0,
      );

      await tester.pumpWidget(
        host(MedicineFormScreen(store: store, existing: existing)),
      );
      await tester.pump();

      expect(find.text('Syrup'), findsOneWidget);
      expect(find.text('Juman'), findsOneWidget);
    });
  });

  group('تعديل مادة موجودة', () {
    const existing = Medicine(
      id: 'm1',
      barcode: '06291100000012',
      name: 'Panadol',
      price: 2500,
      quantity: 4,
      createdAt: 1,
      updatedAt: 1,
    );

    testWidgets('الحقول تُملأ ولا يُنشأ سجل ثانٍ', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        host(MedicineFormScreen(store: store, existing: existing)),
      );
      await tester.pump();

      expect(find.text('تعديل دواء'), findsOneWidget);
      expect(find.text('Panadol'), findsOneWidget);
      // السعر في خانته بفواصل الآلاف كما يُعرض في البطاقة
      expect(find.text('2,500'), findsOneWidget);
      expect(find.text('حفظ التعديلات'), findsOneWidget);

      await tester.enterText(quantityField(), '99');
      await tester.pump();
      await tapSave(tester);

      expect(store.saved.length, 1, reason: 'التعديل لا يضاعف السجل');
      expect(store.saved.first.id, 'm1', reason: 'نفس المعرّف لا معرّف جديد');
      expect(store.saved.first.quantity, 99);
      expect(store.saved.first.name, 'Panadol');
      expect(store.saved.first.createdAt, 1, reason: 'تاريخ الإنشاء محفوظ');
    });

    testWidgets('زر «+» يجمع الوارد مع الرصيد بدل استبداله', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        host(MedicineFormScreen(store: store, existing: existing)),
      );
      await tester.pump();

      expect(find.text('4'), findsOneWidget, reason: 'الرصيد الحالي معروض');

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('addQuantityDialogField')),
        '10',
      );
      await tester.tap(find.text('إضافة'));
      await tester.pump();

      expect(
        find.text('14'),
        findsOneWidget,
        reason: '4 الحالية + 10 الواردة = 14، لا استبدال',
      );

      await tapSave(tester);
      expect(store.saved.single.quantity, 14);
    });

    testWidgets('زر «+» لا يظهر عند إضافة مادة جديدة', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(host(MedicineFormScreen(store: store)));
      await tester.pump();

      expect(
        find.byIcon(Icons.add_rounded),
        findsNothing,
        reason: 'لا رصيد قائم لإضافة وارد إليه',
      );
    });
  });

  group('منع التكرار عند إدخال باركود موجود', () {
    const existing = Medicine(
      id: 'm1',
      barcode: '06291100000012',
      name: 'Panadol',
      price: 2500,
      quantity: 4,
      createdAt: 1,
      updatedAt: 1,
    );

    testWidgets('النموذج يتبنّى السجل الموجود بدل إنشاء ثانٍ', (tester) async {
      useTallSurface(tester);
      store.byBarcode[existing.barcode] = existing;

      await tester.pumpWidget(host(MedicineFormScreen(store: store)));
      await tester.pump();
      expect(find.text('إضافة دواء جديد'), findsOneWidget);

      await submitBarcode(tester, '06291100000012');
      // التنبيه نفسه كعند الحفظ — لا تحويل صامت
      await tester.tap(find.text('تعديل الموجود'));
      await tester.pumpAndSettle();

      expect(
        find.text('تعديل دواء'),
        findsOneWidget,
        reason: 'إدخال باركود موجود يجب أن يعدّل السجل لا أن يكرره',
      );
      expect(find.text('Panadol'), findsOneWidget);
      expect(find.text('حفظ التعديلات'), findsOneWidget);

      await tester.enterText(quantityField(), '10');
      await tester.pump();
      await tapSave(tester);

      expect(store.saved.length, 1, reason: 'لا سجل مكرر');
      expect(store.saved.first.id, 'm1');
      expect(store.saved.first.quantity, 10);
    });

    testWidgets('الباركود المكافئ يُطابق أيضاً (13 مقابل 14 خانة)', (
      tester,
    ) async {
      useTallSurface(tester);
      store.byBarcode[existing.barcode] = existing;

      await tester.pumpWidget(host(MedicineFormScreen(store: store)));
      await tester.pump();

      // المسح يعطي EAN-13 بلا صفر بادئ — نفس المنتج
      await submitBarcode(tester, '6291100000012');
      await tester.tap(find.text('تعديل الموجود'));
      await tester.pumpAndSettle();

      expect(find.text('تعديل دواء'), findsOneWidget);
      expect(find.text('Panadol'), findsOneWidget);
    });

    // ملاحظة: حالة «باركود غير معروف» لا تُختبر هنا لأنها تتجاوز التبنّي
    // وتنطلق إلى `DrugLookup` فتلمس القاعدة والشبكة معاً — وكلاهما لا يكتمل
    // داخل الزمن المزيَّف لاختبارات الواجهة. التبنّي نفسه يقع **قبل** ذلك،
    // والاختباران أعلاه يثبتان أنه لا يقع إلا على باركود موجود فعلاً.
  });

  group('حصر قراءة النص بالمستلزمات', () {
    testWidgets('أزرار القراءة لا تظهر للأدوية', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(host(MedicineFormScreen(store: store)));
      await tester.pump();

      expect(find.textContaining('قراءة ذكية'), findsNothing);
      expect(find.textContaining('اقرأ الاسم من الصورة'), findsNothing);
    });
  });

  testWidgets('كتابة السعر تُظهر فواصل الآلاف وتُحفظ بقيمتها', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(host(MedicineFormScreen(store: store)));
    await tester.pump();

    await tester.enterText(nameField(), 'دواء');
    await tester.enterText(priceField(), '12000');
    await tester.enterText(quantityField(), '3');
    await tester.pump();
    expect(find.text('12,000'), findsOneWidget);

    await tapSave(tester);
    expect(store.saved.single.price, 12000);
  });

  testWidgets('حد التنبيه الخاص يُحفظ مع المادة', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(host(MedicineFormScreen(store: store)));
    await tester.pump();
    await tester.enterText(nameField(), 'Panadol');
    await tester.enterText(find.byKey(const Key('minQtyField')), '20');
    await tester.pump();
    await tapSave(tester);
    expect(store.saved.single.minQuantity, 20);
  });

  testWidgets('مسح حد التنبيه يعيد المادة إلى الحد العام', (tester) async {
    useTallSurface(tester);
    const existing = Medicine(
      id: 'm1',
      barcode: '',
      name: 'Panadol',
      price: 1000,
      quantity: 4,
      minQuantity: 20,
      createdAt: 1,
      updatedAt: 1,
    );
    await tester.pumpWidget(
      host(MedicineFormScreen(store: store, existing: existing)),
    );
    await tester.pump();
    final field = find.byKey(const Key('minQtyField'));
    expect(tester.widget<TextField>(field).controller!.text, '20');
    await tester.enterText(field, '');
    await tester.pump();
    await tapSave(tester);
    expect(store.saved.single.minQuantity, isNull);
  });

  group('حماية الأرقام السالبة (فحص أخير)', () {
    testWidgets('خانة السعر لا تقبل الإشارة السالبة، والكمية السالبة صفر', (
      tester,
    ) async {
      useTallSurface(tester);
      await tester.pumpWidget(host(MedicineFormScreen(store: store)));
      await tester.pump();

      await tester.enterText(nameField(), 'دواء');
      await tester.enterText(priceField(), '-500');
      await tester.enterText(quantityField(), '-3');
      await tester.pump();
      // خانة السعر تقبل الأرقام والنقطة فقط: لا يمكن كتابة سعر سالب أصلاً
      expect(find.text('500'), findsOneWidget);
      await tapSave(tester);

      expect(store.saved.single.price, 500);
      expect(store.saved.single.quantity, 0);
    });

    testWidgets('سالب عند التعديل لا يُنقص رصيداً موجوداً بصمت', (
      tester,
    ) async {
      useTallSurface(tester);
      const existing = Medicine(
        id: 'm1',
        barcode: '',
        name: 'دواء',
        price: 1000,
        quantity: 20,
        createdAt: 0,
        updatedAt: 0,
      );
      await tester.pumpWidget(
        host(MedicineFormScreen(store: store, existing: existing)),
      );
      await tester.pump();

      await tester.enterText(quantityField(), '-9999');
      await tester.pump();
      await tapSave(tester);

      expect(
        store.saved.single.quantity,
        0,
        reason: 'يُرفض إلى صفر — لا يُحفظ رقم سالب يكسر شارة نفاد المخزون',
      );
    });
  });

  group('حماية الضغط المزدوج على «حفظ» (فحص أخير)', () {
    testWidgets('نقرتان سريعتان متتاليتان تُنتجان سجلاً واحداً لا سجلين', (
      tester,
    ) async {
      useTallSurface(tester);
      await tester.pumpWidget(host(MedicineFormScreen(store: store)));
      await tester.pump();

      await tester.enterText(nameField(), 'دواء فريد لا يتكرر اسمه');
      await tester.pump();

      // نقرتان متتاليتان بلا أي pump بينهما — تحاكي ضغطاً مزدوجاً حقيقياً
      // قبل أن تُعاد بناء الواجهة وتُعطَّل onPressed. الحارس الداخلي في
      // _save() هو خط الدفاع الحقيقي هنا لا تعطيل الزر وحده.
      await tester.tap(find.byIcon(Icons.check_rounded), warnIfMissed: false);
      await tester.tap(find.byIcon(Icons.check_rounded), warnIfMissed: false);

      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        store.saved.length,
        1,
        reason: 'نقرتان سريعتان = سجل واحد — كانتا تُنتجان سجلين قبل الإصلاح',
      );
    });

    testWidgets('الزر يتعطّل مرئياً ويظهر مؤشر تحميل أثناء الحفظ', (
      tester,
    ) async {
      useTallSurface(tester);
      store.saveDelay = const Duration(milliseconds: 300);
      await tester.pumpWidget(host(MedicineFormScreen(store: store)));
      await tester.pump();

      await tester.enterText(nameField(), 'دواء');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pump(); // إطار واحد فقط — أثناء الحفظ لا بعده

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // FilledButton غير فريد في الشاشة (زر السعر المقترَح مثلاً) — نحدّد
      // زر الحفظ عبر أبوّته لمؤشر التحميل الذي يحل محلّ أيقونته أثناء الحفظ
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull, reason: 'الزر معطَّل أثناء الحفظ');

      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('منع التكرار الصامت بالاسم عند الإضافة اليدوية (فحص أخير)', () {
    const existingSupply = Medicine(
      id: 's1',
      barcode: '',
      name: 'شاش طبي معقم',
      price: 750,
      quantity: 10,
      type: ItemType.supply,
      createdAt: 0,
      updatedAt: 0,
    );

    testWidgets('اسم مكرر بلا باركود يفتح تنبيهاً بدل حفظ صامت', (
      tester,
    ) async {
      useTallSurface(tester);
      store.all.add(existingSupply);

      await tester.pumpWidget(
        host(MedicineFormScreen(store: store, initialType: ItemType.supply)),
      );
      await tester.pump();

      await tester.enterText(nameField(), 'شاش طبي معقم');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      expect(find.text('⚠️ مادة بنفس الاسم موجودة'), findsOneWidget);
      expect(store.saved, isEmpty, reason: 'لا حفظ قبل أن يقرر المستخدم');
    });

    testWidgets('اختيار «تعديل الموجود» يفتحه للتحرير ولا يُنشئ سجلاً', (
      tester,
    ) async {
      useTallSurface(tester);
      store.all.add(existingSupply);

      await tester.pumpWidget(
        host(MedicineFormScreen(store: store, initialType: ItemType.supply)),
      );
      await tester.pump();

      await tester.enterText(nameField(), 'شاش طبي معقم');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle(); // اكتمال انتقال ظهور الحوار

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('تعديل الموجود'),
        ),
      );
      await tester.pump();

      // النموذج تحوّل الآن إلى تعديل السجل الموجود — لا حفظ حدث بعد
      expect(find.text('تعديل مستلزم'), findsOneWidget);
      expect(store.saved, isEmpty);

      await tester.tap(find.byIcon(Icons.check_rounded));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(store.saved.length, 1, reason: 'تعديل لا إضافة');
      expect(store.saved.single.id, 's1');
    });

    testWidgets('اختيار «سجل منفصل» يحفظ فعلياً كمادة ثانية', (tester) async {
      useTallSurface(tester);
      store.all.add(existingSupply);

      await tester.pumpWidget(
        host(MedicineFormScreen(store: store, initialType: ItemType.supply)),
      );
      await tester.pump();

      await tester.enterText(nameField(), 'شاش طبي معقم');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('سجل منفصل'),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(store.saved.length, 1);
      expect(
        store.saved.single.id,
        isNot('s1'),
        reason: 'سجل جديد بمعرّف مختلف',
      );
    });

    testWidgets('إلغاء الحوار لا يحفظ شيئاً ويبقي النموذج كما هو', (
      tester,
    ) async {
      useTallSurface(tester);
      store.all.add(existingSupply);

      await tester.pumpWidget(
        host(MedicineFormScreen(store: store, initialType: ItemType.supply)),
      );
      await tester.pump();

      await tester.enterText(nameField(), 'شاش طبي معقم');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('إلغاء'),
        ),
      );
      await tester.pumpAndSettle();

      expect(store.saved, isEmpty);
      expect(find.text('إضافة مستلزم جديد'), findsOneWidget);
    });

    testWidgets('باركود غير فارغ يتخطّى فحص الاسم — القيد الفريد يكفي', (
      tester,
    ) async {
      useTallSurface(tester);
      store.all.add(existingSupply);

      await tester.pumpWidget(
        host(MedicineFormScreen(store: store, initialType: ItemType.supply)),
      );
      await tester.pump();

      await tester.enterText(nameField(), 'شاش طبي معقم');
      await tester.enterText(barcodeField(), '9999999999999');
      await tester.pump();
      await tapSave(tester);

      // لا حوار تنبيه — الباركود يميّزها عن الموجودة بلا باركود
      expect(find.text('⚠️ مادة بنفس الاسم موجودة'), findsNothing);
      expect(store.saved.length, 1);
    });
  });

  // نفس سيناريوهات المجموعة أعلاه، لكن بقسم «دواء» بدل «مستلزم» — الشرط
  // الحارس في form_screen.dart._save() لا يفحص النوع إطلاقاً، فيُفترض أن
  // يعمل بالتساوي لكلا القسمين. هذه المجموعة تُثبت ذلك بدل الاكتفاء بقراءة
  // الشيفرة، وتحمي من أي انحراف مستقبلي يُدخِل شرط نوع بالخطأ.
  group('منع التكرار الصامت بالاسم عند الإضافة اليدوية — قسم الأدوية', () {
    const existingMedicine = Medicine(
      id: 'm1',
      barcode: '',
      name: 'باراسيتامول 500',
      price: 250,
      quantity: 30,
      type: ItemType.medicine,
      createdAt: 0,
      updatedAt: 0,
    );

    testWidgets('اسم مكرر بلا باركود يفتح تنبيهاً بدل حفظ صامت (دواء)', (
      tester,
    ) async {
      useTallSurface(tester);
      store.all.add(existingMedicine);

      await tester.pumpWidget(
        host(MedicineFormScreen(store: store, initialType: ItemType.medicine)),
      );
      await tester.pump();

      await tester.enterText(nameField(), 'باراسيتامول 500');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      expect(find.text('⚠️ مادة بنفس الاسم موجودة'), findsOneWidget);
      expect(store.saved, isEmpty, reason: 'لا حفظ قبل أن يقرر المستخدم');
    });

    testWidgets('اختيار «تعديل الموجود» يفتحه للتحرير ولا يُنشئ سجلاً (دواء)', (
      tester,
    ) async {
      useTallSurface(tester);
      store.all.add(existingMedicine);

      await tester.pumpWidget(
        host(MedicineFormScreen(store: store, initialType: ItemType.medicine)),
      );
      await tester.pump();

      await tester.enterText(nameField(), 'باراسيتامول 500');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('تعديل الموجود'),
        ),
      );
      await tester.pump();

      expect(find.text('تعديل دواء'), findsOneWidget);
      expect(store.saved, isEmpty);

      await tester.tap(find.byIcon(Icons.check_rounded));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(store.saved.length, 1, reason: 'تعديل لا إضافة');
      expect(store.saved.single.id, 'm1');
    });

    testWidgets('اختيار «سجل منفصل» يحفظ فعلياً كمادة ثانية (دواء)', (
      tester,
    ) async {
      useTallSurface(tester);
      store.all.add(existingMedicine);

      await tester.pumpWidget(
        host(MedicineFormScreen(store: store, initialType: ItemType.medicine)),
      );
      await tester.pump();

      await tester.enterText(nameField(), 'باراسيتامول 500');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('سجل منفصل'),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(store.saved.length, 1);
      expect(
        store.saved.single.id,
        isNot('m1'),
        reason: 'سجل جديد بمعرّف مختلف',
      );
    });

    testWidgets('باركود غير فارغ يتخطّى فحص الاسم — القيد الفريد يكفي (دواء)', (
      tester,
    ) async {
      useTallSurface(tester);
      store.all.add(existingMedicine);

      await tester.pumpWidget(
        host(MedicineFormScreen(store: store, initialType: ItemType.medicine)),
      );
      await tester.pump();

      await tester.enterText(nameField(), 'باراسيتامول 500');
      await tester.enterText(barcodeField(), '8888888888888');
      await tester.pump();
      await tapSave(tester);

      expect(find.text('⚠️ مادة بنفس الاسم موجودة'), findsNothing);
      expect(store.saved.length, 1);
    });
  });

  group('أرقام عربية في السعر والكمية', () {
    testWidgets('سعر بأرقام عربية-هندية يُحفظ بقيمته لا صفراً', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(host(MedicineFormScreen(store: store)));
      await tester.pump();

      await tester.enterText(nameField(), 'باراسيتامول');
      await tester.enterText(priceField(), '١٥٠٠');
      await tester.enterText(quantityField(), '٣');
      await tester.pump();
      await tapSave(tester);

      expect(store.saved.single.price, 1500);
      expect(store.saved.single.quantity, 3);
    });

    testWidgets('سعر غير صالح عند التعديل لا يدهس السعر القديم', (
      tester,
    ) async {
      useTallSurface(tester);
      const existing = Medicine(
        id: 'm1',
        barcode: '',
        name: 'أموكسيسيلين',
        price: 900,
        quantity: 4,
        createdAt: 1,
        updatedAt: 1,
      );
      store.saved.add(existing);
      await tester.pumpWidget(
        host(MedicineFormScreen(store: store, existing: existing)),
      );
      await tester.pump();

      // خانة السعر نفسها ترفض الأحرف (تقبل الأرقام والنقطة فقط): أحرف
      // كُتبت بعد السعر تسقط ويبقى السعر القديم سليماً
      await tester.enterText(priceField(), '900abc');
      await tester.pump();
      expect(find.text('900'), findsOneWidget);
      await tapSave(tester);

      expect(store.saved.single.price, 900);
    });
  });

  // تعديل باركود مادة إلى باركود مادة أخرى كان يمرّ بلا أي فحص (الفحص كان
  // للإضافة فقط)، فيحذف upsert المادة الأخرى بصمت.
  group('تعديل باركود إلى باركود مادة أخرى', () {
    testWidgets('يُرفض بتنبيه ولا يُحفظ شيء', (tester) async {
      useTallSurface(tester);
      const other = Medicine(
        id: 'o1',
        barcode: '6281234567890',
        name: 'بنادول',
        price: 1500,
        quantity: 30,
        createdAt: 1,
        updatedAt: 1,
      );
      const editing = Medicine(
        id: 'e1',
        barcode: '',
        name: 'رني',
        price: 2000,
        quantity: 5,
        createdAt: 1,
        updatedAt: 1,
      );
      store.byBarcode[other.barcode] = other;
      await tester.pumpWidget(
        host(MedicineFormScreen(store: store, existing: editing)),
      );
      await tester.pump();

      await tester.enterText(barcodeField(), '6281234567890');
      await tester.pump();
      await tapSave(tester);

      expect(find.text('⚠️ الباركود مسجَّل لمادة أخرى'), findsOneWidget);
      expect(find.textContaining('بنادول'), findsWidgets);
      expect(store.saved, isEmpty);
    });

    testWidgets('إبقاء باركود المادة نفسها يُحفظ عادياً', (tester) async {
      useTallSurface(tester);
      const editing = Medicine(
        id: 'e1',
        barcode: '6281234567890',
        name: 'رني',
        price: 2000,
        quantity: 5,
        createdAt: 1,
        updatedAt: 1,
      );
      store.byBarcode[editing.barcode] = editing;
      await tester.pumpWidget(
        host(MedicineFormScreen(store: store, existing: editing)),
      );
      await tester.pump();

      await tester.enterText(quantityField(), '9');
      await tester.pump();
      await tapSave(tester);

      expect(store.saved.single.quantity, 9);
    });
  });
}
