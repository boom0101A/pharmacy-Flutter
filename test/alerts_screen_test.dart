import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/screens/alerts_screen.dart';
import 'package:saydaliyati/screens/home_screen.dart';
import 'package:saydaliyati/services/pharmacy_prefs.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Store extends MedicineStore {
  @override
  Future<void> load() async {}

  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}
}

Medicine _m(String id, String name, {int qty = 20, int? inDays}) => Medicine(
  id: id,
  barcode: '',
  name: name,
  price: 1000,
  quantity: qty,
  expiryDate: inDays == null ? null : _noonIn(inDays).millisecondsSinceEpoch,
  createdAt: 0,
  updatedAt: 0,
);

void main() {
  late _Store store;
  late List<String> opened;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PharmacyPrefs.instance.resetForTest();
    PharmacyPrefs.instance.debugSetLowStockDefault(5);
    opened = [];
    store = _Store()
      ..seed([
        _m('e', 'Amoxil', inDays: -4),
        _m('u', 'Panadol', inDays: 9),
        _m('o', 'Brufen', qty: 0),
        _m('l', 'Vitamin C', qty: 2),
        _m('s', 'Zinc', inDays: 60),
        _m('ok', 'Healthy'),
      ]);
  });

  tearDown(PharmacyPrefs.instance.resetForTest);

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: AlertsScreen(store: store, onOpen: (m) => opened.add(m.id)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('الأقسام بعدّاداتها بالأولوية، والسليمة غائبة', (tester) async {
    await open(tester);
    expect(find.text('⛔ منتهية الصلاحية (1)'), findsOneWidget);
    expect(find.text('⏳ تنتهي خلال شهر (1)'), findsOneWidget);
    expect(find.text('🚫 نافدة (1)'), findsOneWidget);
    expect(find.text('⚠️ مخزون منخفض (1)'), findsOneWidget);
    expect(find.text('🕐 تنتهي خلال 3 أشهر (1)'), findsOneWidget);
    expect(find.text('Healthy'), findsNothing);
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('Amoxil') < y('Panadol'), isTrue);
    expect(y('Panadol') < y('Brufen'), isTrue);
    expect(y('Vitamin C') < y('Zinc'), isTrue);
  });

  testWidgets('سطر التفصيل لكل نوع', (tester) async {
    await open(tester);
    expect(find.text('منتهية منذ 4 يوماً'), findsOneWidget);
    expect(find.text('متبقٍ 9 يوماً'), findsOneWidget);
    expect(find.text('نفدت من المخزون'), findsOneWidget);
    expect(find.text('الكمية 2 — حد التنبيه 5'), findsOneWidget);
  });

  testWidgets('الضغط يفتح المادة', (tester) async {
    await open(tester);
    await tester.tap(find.text('Panadol'));
    await tester.pumpAndSettle();
    expect(opened, ['u']);
  });

  testWidgets('«تمّ» يخفي ويزامن، و«تراجع» يعيده', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('alertDone_u:urgent')));
    await tester.pumpAndSettle();
    expect(find.text('Panadol'), findsNothing);
    expect(PharmacyPrefs.instance.alertDismissals, {'u:urgent'});

    await tester.tap(find.text('تراجع'));
    await tester.pumpAndSettle();
    expect(find.text('Panadol'), findsOneWidget);
    expect(PharmacyPrefs.instance.alertDismissals, isEmpty);
  });

  testWidgets('«إظهار المخفية» يعرضها بزر «إرجاع»', (tester) async {
    await PharmacyPrefs.instance.dismiss('o:out');
    await open(tester);
    expect(find.text('Brufen'), findsNothing);
    await tester.tap(find.text('إظهار المخفية (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Brufen'), findsOneWidget);
    await tester.tap(find.byKey(const Key('alertRestore_o:out')));
    await tester.pumpAndSettle();
    expect(PharmacyPrefs.instance.alertDismissals, isEmpty);
  });

  // نقر إشعار والتطبيق مغلق: المركز يُفتح في أول إطار والمخزون لم يُحمَّل —
  // قائمة فارغة كانت تُعدّ «كل شيء انحلّ» فتُمسح قرارات «تمّ» من الهاتفين
  testWidgets('فتح المركز قبل تحميل المخزون لا يمسح قرارات «تمّ»', (
    tester,
  ) async {
    await PharmacyPrefs.instance.dismiss('o:out');
    store = _Store(); // لم يُحمَّل بعد: isLoading
    expect(store.isLoading, isTrue);
    await open(tester);
    expect(PharmacyPrefs.instance.alertDismissals, {'o:out'});
  });

  testWidgets('بلا تنبيهات: رسالة «كل شيء سليم»', (tester) async {
    store.seed([_m('ok', 'Healthy')]);
    await open(tester);
    expect(find.text('✅ لا تنبيهات — كل شيء سليم'), findsOneWidget);
  });

  testWidgets('جرس الرئيسية: العدد ثم يفتح مركز التنبيهات', (tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: HomeScreen(store: store),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bell = find.byKey(const Key('alertsBell'));
    expect(bell, findsOneWidget);
    expect(
      find.descendant(of: bell, matching: find.text('3')),
      findsOneWidget,
      reason: 'منتهية + عاجلة + نافدة — «المنخفضة» و«القريبة» لا تُعدّ',
    );

    await tester.tap(bell);
    await tester.pumpAndSettle();
    expect(find.byType(AlertsScreen), findsOneWidget);
  });

  test('عدّاد الجرس: الحرجة غير المخفية فقط', () {
    expect(criticalAlertCount(store.all, dismissed: {}), 3);
    expect(criticalAlertCount(store.all, dismissed: {'e:expired'}), 2);
  });
}

/// ظهر اليوم المطلوب: النتيجة لا تتغيّر بساعة تشغيل الاختبار (قرب منتصف
/// الليل كانت «+ساعتان» تعبر إلى اليوم التالي).
DateTime _noonIn(int days) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + days, 12);
}
