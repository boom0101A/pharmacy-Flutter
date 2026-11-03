import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/l10n/l10n.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/screens/home_screen.dart';
import 'package:saydaliyati/services/app_settings.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';
import 'package:saydaliyati/widgets/display_prefs_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تبديل العملة أو اللغة والشاشة مفتوحة: ما يظهر يتحدّث فوراً — عن قصد، لا
/// لأن السمة تُبنى من جديد مع كل إشعار من AppSettings.
class _Store extends MedicineStore {
  @override
  Future<void> load() async {}

  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}
}

/// سمة واحدة محفوظة (كما في main.dart) — لا شيء يتحدّث «بالصدفة».
final _theme = buildAppTheme();

/// يعدّ مرات بنائه: نص من خدمة (بلا اعتماد على Localizations).
class _Probe extends StatelessWidget {
  const _Probe({required this.builds});

  final List<int> builds;

  @override
  Widget build(BuildContext context) {
    builds.add(1);
    return Text(L10n.current.syncLocal, key: const Key('probe'));
  }
}

Widget _app(Widget home) => DisplayPrefsScope(
  child: Builder(
    builder: (context) => MaterialApp(
      theme: _theme,
      home: Directionality(textDirection: TextDirection.rtl, child: home),
    ),
  ),
);

void main() {
  final s = AppSettings.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await s.init();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await s.init();
  });

  testWidgets('تبديل العملة يحدّث البطاقات الظاهرة فوراً', (tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = _Store()
      ..seed([
        const Medicine(
          id: 'm1',
          barcode: '',
          name: 'Duphalac',
          price: 7877,
          quantity: 2,
          createdAt: 1,
          updatedAt: 1,
        ),
      ]);
    await tester.pumpWidget(_app(HomeScreen(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('7,877 د.ع'), findsOneWidget);

    await s.setUsdRate(1310);
    await s.setCurrency('USD');
    await tester.pumpAndSettle();
    expect(find.text(r'$6.01'), findsOneWidget);
    expect(find.text('7,877 د.ع'), findsNothing);

    // تغيير سعر الصرف وحده يحدّث أيضاً
    await s.setUsdRate(1500);
    await tester.pumpAndSettle();
    expect(find.text(r'$5.25'), findsOneWidget);
  });

  // الحقل يحتفظ بحالته عبر إعادة البناء: بلا العملة في مفتاحه كان يبقى
  // «13,100» (دينار) ويُقرأ دولاراً عند أي تعديل
  testWidgets('نطاق السعر في الفلاتر يتحوّل مع العملة', (tester) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = _Store()..setPriceRange(13100, null);
    await tester.pumpWidget(_app(HomeScreen(store: store)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byTooltip('الفلاتر'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.widgetWithText(TextField, '13,100'), findsOneWidget);

    await s.setUsdRate(1310);
    await s.setCurrency('USD');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.widgetWithText(TextField, '10'), findsOneWidget);
    expect(find.widgetWithText(TextField, '13,100'), findsNothing);
  });

  testWidgets('تبديل اللغة يحدّث نصوص الخدمات أيضاً', (tester) async {
    final builds = <int>[];
    await tester.pumpWidget(_app(Scaffold(body: _Probe(builds: builds))));
    expect(find.text('حفظ محلي'), findsOneWidget);

    await s.setLanguage('en');
    await tester.pumpAndSettle();
    expect(find.text('Saved locally'), findsOneWidget);
  });

  testWidgets('إعداد لا يخص العرض لا يعيد بناء الواجهة', (tester) async {
    final builds = <int>[];
    await tester.pumpWidget(_app(Scaffold(body: _Probe(builds: builds))));
    final before = builds.length;
    await s.setPharmacyId('p1');
    await s.setContributeToRegistry(false);
    await tester.pumpAndSettle();
    expect(builds.length, before);
  });
}
