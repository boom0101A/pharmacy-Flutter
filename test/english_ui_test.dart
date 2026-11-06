import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/l10n/l10n.dart';
import 'package:saydaliyati/services/pharmacy_prefs.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/screens/alerts_screen.dart';
import 'package:saydaliyati/screens/form_screen.dart';
import 'package:saydaliyati/screens/home_screen.dart';
import 'package:saydaliyati/screens/medicine_detail_screen.dart';
import 'package:saydaliyati/screens/settings_sheet.dart';
import 'package:saydaliyati/state/invoice_store.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/screens/welcome_view.dart';
import 'package:saydaliyati/services/app_settings.dart';
import 'package:saydaliyati/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// بالإنجليزية لا يظهر أي حرف عربي في الواجهة — إلا البيانات المزروعة في
/// الاختبار (أسماء أدوية/مجهّزين)، فهي لا تُترجم.
final _arabic = RegExp(r'[؀-ۿ]');

/// كل النصوص المعروضة (Text وRichText) ما عدا ما في [allowed].
List<String> arabicTexts(
  WidgetTester tester, {
  Set<String> allowed = const {},
}) {
  final found = <String>[];
  for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
    final text = w.text.toPlainText();
    if (_arabic.hasMatch(text) && !allowed.any(text.contains)) found.add(text);
  }
  return found;
}

/// تطبيق مصغّر بلغة الإعدادات واتجاهها، كما في main.dart.
Widget englishHost(Widget home) => MaterialApp(
  theme: buildAppTheme(),
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) =>
      Directionality(textDirection: TextDirection.ltr, child: child!),
  home: home,
);

class _Store extends MedicineStore {
  @override
  Future<void> load() async {}

  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}
}

class _BarcodeStore extends _Store {
  _BarcodeStore(this.owner);
  final Medicine owner;

  @override
  Future<Medicine?> findByBarcode(String barcode) async =>
      barcode.trim() == owner.barcode ? owner : null;
}

Medicine _med(String id, String name, double price) => Medicine(
  id: id,
  barcode: '',
  name: name,
  price: price,
  quantity: 3,
  createdAt: 1,
  updatedAt: 1,
);

Future<void> frames(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  // عتبة «منخفض» 5 صراحةً: الاختبارات هنا لمنطق المنخفض نفسه، والافتراضي صار 1
  setUpAll(() => PharmacyPrefs.instance.debugSetLowStockDefault(5));
  tearDownAll(PharmacyPrefs.instance.resetForTest);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.init();
    await AppSettings.instance.setLanguage('en');
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.init();
  });

  void useSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('الرئيسية بالإنجليزية', () {
    testWidgets('بلا عربي إلا البيانات، والقيمة بالدولار', (tester) async {
      await AppSettings.instance.setUsdRate(1310);
      await AppSettings.instance.setCurrency('USD');
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final store = _Store()
        ..seed([
          _med('m1', 'Panadol', 7877),
          _med('m2', 'شراب أطفال', 1310), // بيانات عربية تبقى كما هي
        ]);
      await tester.pumpWidget(englishHost(HomeScreen(store: store)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Medicine'), findsWidgets);
      expect(find.text('2 medicines'), findsOneWidget);
      expect(find.textContaining('Total value'), findsNothing);
      expect(find.text(r'$6.01'), findsOneWidget);
      expect(find.text(r'$1.00'), findsOneWidget);
      expect(arabicTexts(tester, allowed: {'شراب أطفال'}), isEmpty);
    });
  });

  // النصوص الإنجليزية أطول أحياناً: شاشة ضيقة (360) بلا فيضان
  testWidgets('الرئيسية بالإنجليزية على شاشة ضيقة بلا فيضان', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = _Store()
      ..seed([for (var i = 0; i < 6; i++) _med('m$i', 'Medicine $i', 125000)]);
    await tester.pumpWidget(englishHost(HomeScreen(store: store)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('مركز التنبيهات بالإنجليزية', (tester) async {
    tester.view.physicalSize = const Size(420, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = _Store()
      ..seed([
        _med('a', 'شراب أطفال', 1000).copyWith(quantity: 0),
        _med('b', 'Panadol', 1000).copyWith(quantity: 2),
      ]);
    await tester.pumpWidget(
      englishHost(AlertsScreen(store: store, onOpen: (_) {})),
    );
    await tester.pumpAndSettle();
    expect(find.text('🚫 Out of stock (1)'), findsOneWidget);
    expect(find.text('Quantity 2 — alert at 5'), findsOneWidget);
    expect(arabicTexts(tester, allowed: {'شراب أطفال'}), isEmpty);
  });

  testWidgets('الإعدادات بالإنجليزية', (tester) async {
    tester.view.physicalSize = const Size(420, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = _Store();
    await tester.pumpWidget(
      englishHost(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showSettingsSheet(context, store),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('⚙️ Settings'), findsOneWidget);
    // اسم اللغة العربية يُكتب بالعربية دائماً — هو خيار لا نص واجهة
    expect(arabicTexts(tester, allowed: {'العربية'}), isEmpty);
  });

  testWidgets('التفاصيل بالإنجليزية', (tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = _Store()..seed([_med('m1', 'شراب أطفال', 7877)]);
    await tester.pumpWidget(
      englishHost(
        MedicineDetailScreen(
          store: store,
          medicineId: 'm1',
          onEdit: () {},
          onDelete: () {},
          invoices: InvoiceStore(
            loadAll: () async => [],
            write: (_) async {},
            remove: (_) async {},
            savePage: (_) async => '',
            deletePage: (_) async {},
            push: (_) async {},
            pushDelete: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Stock value'), findsOneWidget);
    // بالإنجليزية أيضاً: − يسار + (كان معكوساً من الترتيب العربي)
    expect(
      tester.getCenter(find.byKey(const Key('qtyMinus'))).dx,
      lessThan(tester.getCenter(find.byKey(const Key('qtyPlus'))).dx),
    );
    expect(find.textContaining('Added 20'), findsNothing);
    expect(find.text('7,877 IQD'), findsOneWidget);
    expect(arabicTexts(tester, allowed: {'شراب أطفال'}), isEmpty);
  });

  testWidgets('نموذج الإضافة بالإنجليزية', (tester) async {
    tester.view.physicalSize = const Size(420, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(englishHost(MedicineFormScreen(store: _Store())));
    await tester.pumpAndSettle();
    expect(find.text('Add new medicine'), findsOneWidget);
    expect(find.text('💰 Price (IQD)'), findsOneWidget);
    expect(arabicTexts(tester), isEmpty);
  });

  testWidgets('حذف مالك الباركود بالإنجليزية', (tester) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final owner = _med('o1', 'شراب أطفال', 1310).copyWith(barcode: '111222');
    final store = _BarcodeStore(owner);
    await tester.pumpWidget(englishHost(MedicineFormScreen(store: store)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('barcodeField')), '111222');
    await tester.enterText(find.byKey(const Key('nameField')), 'Other');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();
    expect(find.text('🗑️ Delete linked'), findsOneWidget);
    expect(arabicTexts(tester, allowed: {'شراب أطفال'}), isEmpty);
    await tester.tap(find.byKey(const Key('deleteBarcodeOwner')));
    await tester.pumpAndSettle();
    expect(find.text('Delete the linked medicine?'), findsOneWidget);
    expect(arabicTexts(tester, allowed: {'شراب أطفال'}), isEmpty);
    expect(tester.takeException(), isNull);
  });

  group('الترحيب بالإنجليزية', () {
    testWidgets('بلا عربي', (tester) async {
      useSize(tester);
      await tester.pumpWidget(
        englishHost(Scaffold(body: WelcomeView(onDone: () {}))),
      );
      await frames(tester);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(arabicTexts(tester), isEmpty);
    });

    testWidgets('LTR: السحب لليسار التالي، والتالية تدخل من اليمين', (
      tester,
    ) async {
      useSize(tester);
      await tester.pumpWidget(
        englishHost(Scaffold(body: WelcomeView(onDone: () {}))),
      );
      await frames(tester);
      await tester.drag(find.text('add in a second'), const Offset(-120, 0));
      await tester.pump(const Duration(milliseconds: 60));
      // الشريحة الثانية في منتصف دخولها: إلى يمين موضعها النهائي
      final mid = tester.getCenter(find.text('we do the rest')).dx;
      await frames(tester);
      final end = tester.getCenter(find.text('we do the rest')).dx;
      expect(mid, greaterThan(end));
    });
  });
}
