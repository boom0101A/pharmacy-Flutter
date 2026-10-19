import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/screens/home_screen.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';
import 'package:saydaliyati/widgets/medicine_card.dart';

/// مخزن اختبار: يمنع `load()` من لمس SQLite أو Firestore.
class _TestStore extends MedicineStore {
  /// معرّفات وصلت فعلياً إلى `delete()` — تُميّز الحذف الحقيقي عن الإخفاء
  /// المؤقت أثناء مهلة التراجع.
  final List<String> deletedIds = [];

  @override
  Future<void> load() async {}

  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}

  @override
  Future<void> delete(Medicine medicine, {bool keepImage = false}) async {
    deletedIds.add(medicine.id);
    all.removeWhere((m) => m.id == medicine.id);
    notifyListeners();
  }
}

Medicine _item({
  required String id,
  required String name,
  ItemType type = ItemType.medicine,
  int createdAt = 0,
}) => Medicine(
  id: id,
  barcode: '',
  name: name,
  price: 100,
  quantity: 3,
  type: type,
  createdAt: createdAt,
  updatedAt: createdAt,
);

Widget _app(MedicineStore store) => MaterialApp(
  theme: buildAppTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar'), Locale('en')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: HomeScreen(store: store),
  ),
);

void main() {
  late _TestStore store;

  setUp(() {
    store = _TestStore()
      ..seed([
        _item(id: 'm1', name: 'Panadol', createdAt: 1),
        _item(id: 'm2', name: 'Aspirin', createdAt: 2),
        _item(id: 's1', name: 'شاش طبي', type: ItemType.supply, createdAt: 3),
      ]);
  });

  group('التبويب والانتقال', () {
    testWidgets('يعرض تبويبين بعدّاديهما الصحيحين', (tester) async {
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.textContaining('💊 دواء  (2)'), findsOneWidget);
      expect(find.textContaining('🩹 مستلزم طبي  (1)'), findsOneWidget);
    });

    testWidgets('TabBarView موجود فيمكن السحب بين القسمين', (tester) async {
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      final view = tester.widget<TabBarView>(find.byType(TabBarView));
      expect(view.children.length, ItemType.values.length);
    });

    testWidgets('الضغط على تبويب المستلزمات يبدّل القسم النشط', (tester) async {
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      expect(store.activeType, ItemType.medicine);

      await tester.tap(find.textContaining('مستلزم طبي'));
      await tester.pumpAndSettle();

      expect(store.activeType, ItemType.supply);
      expect(find.text('شاش طبي'), findsOneWidget);
      expect(find.text('Panadol'), findsNothing);
    });

    testWidgets('عنوان الإحصاء يتبع القسم', (tester) async {
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      expect(find.text('عدد الأدوية'), findsOneWidget);

      await tester.tap(find.textContaining('مستلزم طبي'));
      await tester.pumpAndSettle();
      expect(find.text('عدد المستلزمات'), findsOneWidget);
    });

    testWidgets('البحث لا يتسرّب بين القسمين', (tester) async {
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Panadol');
      await tester.pumpAndSettle();
      expect(store.visibleFor(ItemType.medicine).length, 1);

      await tester.tap(find.textContaining('مستلزم طبي'));
      await tester.pumpAndSettle();

      // حقل البحث فرغ لأن قسم المستلزمات لم يُبحث فيه
      expect(store.keyword, isEmpty);
      expect(find.text('شاش طبي'), findsOneWidget);
    });
  });

  group('أزرار القسم', () {
    testWidgets(
      '«مسح باركود» يظهر في كلا القسمين (لا فرق بينهما بعد إزالة القراءة الذكية)',
      (tester) async {
        await tester.pumpWidget(_app(store));
        await tester.pumpAndSettle();

        expect(find.text('مسح باركود'), findsOneWidget);
        // «قراءة ذكية» أُزيلت من التطبيق كلياً — لا تظهر في أي قسم
        expect(find.text('قراءة ذكية'), findsNothing);

        await tester.tap(find.textContaining('مستلزم طبي'));
        await tester.pumpAndSettle();

        expect(find.text('مسح باركود'), findsOneWidget);
        expect(find.text('قراءة ذكية'), findsNothing);
      },
    );

    testWidgets('زر «قراءة فاتورة» يختفي عند غياب مفتاح Gemini', (
      tester,
    ) async {
      // بيئة الاختبار بلا dotenv مُهيَّأ ⇒ hasGeminiKey = false ⇒ يختفي الزر
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.receipt_long), findsNothing);

      await tester.tap(find.textContaining('مستلزم طبي'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.receipt_long), findsNothing);
    });

    testWidgets('زر «فاتورة ذكية» ظاهر بنصه في القسمين عند وجود المفتاح', (
      tester,
    ) async {
      dotenv.testLoad(fileInput: 'GEMINI_API_KEY=test-key');
      addTearDown(dotenv.clean);
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      expect(find.text('فاتورة ذكية'), findsOneWidget);

      await tester.tap(find.textContaining('مستلزم طبي'));
      await tester.pumpAndSettle();
      expect(find.text('فاتورة ذكية'), findsOneWidget);
    });
  });

  group('حركة البطاقات', () {
    testWidgets('البطاقة تتحرك أول ظهور فقط ولا تعيدها', (tester) async {
      await tester.pumpWidget(_app(store));
      await tester.pump(); // أول بناء

      final firstPass = tester
          .widgetList<MedicineCard>(find.byType(MedicineCard))
          .toList();
      expect(firstPass, isNotEmpty);
      expect(firstPass.every((c) => c.animate), isTrue);

      await tester.pumpAndSettle();

      // إعادة بناء كاملة للشبكة (تغيير الترتيب) — هذا ما كان يُعيد تشغيل
      // الحركة قبل الإصلاح فيبدو المحتوى وامضاً
      store.setSort(SortField.name);
      await tester.pumpAndSettle();

      final secondPass = tester
          .widgetList<MedicineCard>(find.byType(MedicineCard))
          .toList();
      expect(secondPass, isNotEmpty);
      expect(secondPass.every((c) => !c.animate), isTrue);
    });

    testWidgets('البطاقة تستقر على شفافية كاملة بعد الحركة', (tester) async {
      await tester.pumpWidget(_app(store));
      await tester.pump();

      // في منتصف الحركة تكون شبه شفافة
      await tester.pump(const Duration(milliseconds: 60));
      final mid = tester.widgetList<Opacity>(find.byType(Opacity)).toList();
      expect(mid.any((o) => o.opacity < 1), isTrue);

      await tester.pumpAndSettle();
      final settled = tester.widgetList<Opacity>(find.byType(Opacity)).toList();
      expect(settled.every((o) => o.opacity == 1), isTrue);
    });

    testWidgets('كل بطاقة داخل RepaintBoundary', (tester) async {
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      final card = find.byType(MedicineCard).first;
      expect(
        find.descendant(of: card, matching: find.byType(RepaintBoundary)),
        findsWidgets,
      );
    });
  });

  group('الحالة الفارغة', () {
    testWidgets('قسم فارغ يعرض رسالته الخاصة', (tester) async {
      store.seed([_item(id: 'm1', name: 'Panadol')]);
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('مستلزم طبي'));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد مستلزمات بعد'), findsOneWidget);
    });

    testWidgets('بحث بلا نتائج يعرض رسالة مختلفة عن القسم الفارغ', (
      tester,
    ) async {
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'لا يوجد هذا');
      await tester.pumpAndSettle();

      expect(find.text('لا توجد نتائج مطابقة'), findsOneWidget);
      expect(find.text('لا توجد أدوية بعد'), findsNothing);
    });

    testWidgets('السحب للتحديث متاح في القسم الفارغ', (tester) async {
      store.seed([_item(id: 'm1', name: 'Panadol')]);
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('مستلزم طبي'));
      await tester.pumpAndSettle();

      expect(
        find.ancestor(
          of: find.text('لا توجد مستلزمات بعد'),
          matching: find.byType(RefreshIndicator),
        ),
        findsOneWidget,
      );
      // بلا مفتاح Gemini لا يُدعى المستخدم لزر غير موجود
      expect(find.textContaining('فاتورة'), findsNothing);
      expect(find.text('اضغط «+» لإضافة أول مستلزم'), findsOneWidget);
    });
  });

  group('البحث والفلاتر بأرقام عربية', () {
    testWidgets('باركود مكتوب بأرقام عربية يجد المادة', (tester) async {
      store.seed([
        Medicine(
          id: 'b1',
          barcode: '6281234567890',
          name: 'Rennie',
          price: 100,
          quantity: 3,
          createdAt: 1,
          updatedAt: 1,
        ),
        _item(id: 'm2', name: 'Aspirin'),
      ]);
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '٦٢٨١٢٣');
      await tester.pumpAndSettle();
      expect(store.visible.map((m) => m.id), ['b1']);
    });

    testWidgets('نطاق السعر يقبل أرقاماً عربية ويُمسح عند إعادة التعيين', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      store.seed([
        _item(id: 'm1', name: 'Panadol'),
        Medicine(
          id: 'm2',
          barcode: '',
          name: 'Gold',
          price: 5000,
          quantity: 3,
          createdAt: 2,
          updatedAt: 2,
        ),
      ]);
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.filter_alt_outlined));
      await tester.pumpAndSettle();

      final minPrice = find.widgetWithText(TextField, 'من').first;
      await tester.enterText(minPrice, '١٠٠٠');
      await tester.pumpAndSettle();
      expect(store.priceMin, 1000);
      expect(store.visible.map((m) => m.id), ['m2']);

      await tester.ensureVisible(find.text('إعادة تعيين الفلاتر'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إعادة تعيين الفلاتر'));
      await tester.pumpAndSettle();
      expect(store.priceMin, isNull);
      expect(find.text('١٠٠٠'), findsNothing);
    });

    test('الترتيب بالاسم لا يتأثر بحالة الأحرف', () {
      final s = _TestStore()
        ..seed([
          _item(id: 'a', name: 'zinc'),
          _item(id: 'b', name: 'Aspirin'),
          _item(id: 'c', name: 'bepanthen'),
        ])
        ..setSort(SortField.name);
      expect(s.visible.map((m) => m.name), ['Aspirin', 'bepanthen', 'zinc']);
    });
  });

  group('التراجع عن الحذف (فحص أخير)', () {
    // يحدّد زر الحذف تبعاً لاسم البطاقة لا لموضعها — الترتيب الافتراضي
    // بالأحدث أولاً يجعل موضع أي مادة غير موثوق للاختبار.
    Finder deleteButtonFor(WidgetTester tester, String name) => find.descendant(
      of: find.ancestor(
        of: find.text(name),
        matching: find.byType(MedicineCard),
      ),
      matching: find.byIcon(Icons.delete_outline),
    );

    testWidgets('الحذف يُخفي المادة فوراً ويعرض شريط تراجع لخمس ثوانٍ', (
      tester,
    ) async {
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      expect(find.text('Panadol'), findsOneWidget);
      await tester.tap(deleteButtonFor(tester, 'Panadol'));
      await tester.pump();

      expect(
        find.text('Panadol'),
        findsNothing,
        reason: 'تختفي فوراً من الشبكة — لا تنتظر تأكيداً',
      );
      expect(find.text('تراجع'), findsOneWidget);
      expect(find.textContaining('حُذف "Panadol"'), findsOneWidget);
      expect(
        store.deletedIds,
        isEmpty,
        reason: 'الحذف الفعلي من القاعدة لم يحدث بعد',
      );
    });

    testWidgets('الضغط على «تراجع» يعيد المادة ولا يحذفها فعلياً أبداً', (
      tester,
    ) async {
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      await tester.tap(deleteButtonFor(tester, 'Panadol'));
      // إتمام حركة دخول الشريط فقط — لا تدفع الوقت الافتراضي كفايةً لتشغيل
      // مؤقّت الإغلاق التلقائي (5 ثوانٍ)، لأن مؤقّتاً معلّقاً وحده لا يُجدوِل
      // إطاراً جديداً؛ pumpAndSettle تتوقف فور استقرار الحركة المرئية.
      await tester.pumpAndSettle();
      expect(find.text('Panadol'), findsNothing);

      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();

      expect(find.text('Panadol'), findsOneWidget, reason: 'عادت بعد التراجع');

      // نتجاوز الخمس ثوانٍ الأصلية للتأكد أنها لا تُحذف متأخرة رغم التراجع
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(store.deletedIds, isEmpty);
      expect(find.text('Panadol'), findsOneWidget);
    });

    testWidgets('إغلاق الشريط بأي طريقة غير «تراجع» يُنفَّذ الحذف الفعلي — '
        'يحاكي مؤقّت الخمس ثوانٍ الطبيعي', (tester) async {
      // مؤقّت SnackBar الداخلي (duration) مضمون سلوكه من Flutter نفسها —
      // ما نحتاج التأكد منه هنا هو تصرّف شيفرتنا عند أي إغلاق ليس
      // بالتراجع، سواء جاء من انتهاء المهلة أو غيره. محاكاة الإغلاق
      // مباشرة أوثق من دفع خمس ثوانٍ افتراضية عبر مؤقّتات مزيَّفة قد لا
      // تُحاكي كل تفاصيل AnimationController الداخلية لودجة SnackBar.
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      await tester.tap(deleteButtonFor(tester, 'Panadol'));
      await tester.pumpAndSettle();
      expect(store.deletedIds, isEmpty);
      expect(find.text('تراجع'), findsOneWidget);

      final messenger = tester.state<ScaffoldMessengerState>(
        find.byType(ScaffoldMessenger),
      );
      messenger.hideCurrentSnackBar(); // ليس عبر زر «تراجع»
      await tester.pumpAndSettle();

      expect(
        store.deletedIds,
        contains('m1'),
        reason: 'إغلاق الشريط بلا ضغط «تراجع» = تأكيد الحذف',
      );
      expect(find.text('تراجع'), findsNothing);
    });

    testWidgets('مهلة الشريط الفعلية مضبوطة على 4 ثوانٍ ولا يبقى ثابتاً', (
      tester,
    ) async {
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      await tester.tap(deleteButtonFor(tester, 'Panadol'));
      await tester.pumpAndSettle();

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.duration, const Duration(seconds: 4));
      // زر «تراجع» يجعل الشريط ثابتاً افتراضياً في Flutter الحديث
      expect(snackBar.persist, isFalse);
    });

    // الشريط الثابت لم يكن يُغلق، والحذف الحقيقي يحدث عند إغلاقه فقط —
    // فكانت المادة تُخفى من الشاشة دون أن تُحذف، وتعود بعد أي تحديث.
    testWidgets('الشريط يختفي وحده بعد 4 ثوانٍ ويُنفَّذ الحذف', (tester) async {
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      await tester.tap(deleteButtonFor(tester, 'Panadol'));
      await tester.pumpAndSettle(); // اكتمال حركة الظهور — المهلة تبدأ بعدها
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(store.deletedIds, isEmpty);

      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(store.deletedIds, contains('m1'));
    });

    testWidgets(
      'حذف مادة ثانية أثناء ظهور شريط الأولى يؤكّد حذف الأولى فوراً',
      (tester) async {
        await tester.pumpWidget(_app(store));
        await tester.pumpAndSettle();

        await tester.tap(deleteButtonFor(tester, 'Panadol'));
        await tester.pump();
        expect(store.deletedIds, isEmpty);

        // شريط ثانٍ يستبدل الأول (hideCurrentSnackBar) قبل انتهاء مهلته —
        // يجب أن يُعامَل الحذف الأول كمؤكَّد لا كملغى
        await tester.tap(deleteButtonFor(tester, 'Aspirin'));
        await tester.pump();

        expect(
          store.deletedIds,
          contains('m1'),
          reason: 'استبدال الشريط قبل التراجع = تأكيد ضمني للحذف الأول',
        );
      },
    );
  });
}
