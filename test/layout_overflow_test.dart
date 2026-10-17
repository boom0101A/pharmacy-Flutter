import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/screens/home_screen.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';

/// فحص أن الواجهة لا تفيض على الشاشات الصغيرة ولا مع تكبير الخط.
///
/// الفيضان ليس تجميلياً: الشريط الأصفر يغطي المحتوى ويجعل الأزرار غير قابلة
/// للضغط. سبق أن ظهرت هذه المشكلة في البطاقات، والتبويب الجديد وصناديق
/// الإحصاء أعادا توزيع الارتفاعات كلها.
class _TestStore extends MedicineStore {
  @override
  Future<void> load() async {}

  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}
}

Medicine _item(String id, ItemType type) => Medicine(
  id: id,
  barcode: '1234567890123',
  name: 'اسم مادة طويل نسبياً لاختبار الالتفاف',
  price: 1234567,
  quantity: 3,
  type: type,
  createdAt: 0,
  updatedAt: 0,
);

/// تكبير الخط يُحقن **خارج** التطبيق كما يفعل النظام، فيمرّ على حدّ التثبيت
/// الموجود في main.dart بدل أن يلتفّ حوله.
Widget _app(MedicineStore store, double textScale) => MediaQuery(
  data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
  child: MaterialApp(
    theme: buildAppTheme(),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // نفس ما في main.dart حرفياً
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.9,
        maxScaleFactor: 1.15,
        child: child!,
      ),
    ),
    home: HomeScreen(store: store),
  ),
);

Future<void> _expectNoOverflow(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  required bool openFilters,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final store = _TestStore()
    ..seed([
      for (var i = 0; i < 6; i++) _item('m$i', ItemType.medicine),
      _item('s1', ItemType.supply),
    ]);

  await tester.pumpWidget(_app(store, textScale));
  await tester.pumpAndSettle();

  if (openFilters) {
    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pumpAndSettle();
  }

  // takeException يُستدعى مرة واحدة فقط — الاستدعاء الثاني يعيد null دائماً
  final thrown = tester.takeException();
  expect(
    thrown,
    isNull,
    reason:
        'فيضان عند ${size.width}x${size.height} '
        'وتكبير خط $textScale '
        '${openFilters ? 'مع لوحة الفلاتر' : ''}\n$thrown',
  );
}

void main() {
  group('لا فيضان في الشاشة الرئيسية', () {
    testWidgets('هاتف صغير 360x640', (tester) async {
      await _expectNoOverflow(
        tester,
        size: const Size(360, 640),
        textScale: 1.0,
        openFilters: false,
      );
    });

    testWidgets('هاتف صغير جداً 320x568', (tester) async {
      await _expectNoOverflow(
        tester,
        size: const Size(320, 568),
        textScale: 1.0,
        openFilters: false,
      );
    });

    testWidgets('هاتف المستخدم 1080x2400 بكثافة 1', (tester) async {
      await _expectNoOverflow(
        tester,
        size: const Size(1080, 2400),
        textScale: 1.0,
        openFilters: false,
      );
    });

    testWidgets('خط مكبَّر إلى أقصى حدّ مسموح', (tester) async {
      await _expectNoOverflow(
        tester,
        size: const Size(360, 640),
        textScale: 2.0, // يُقصّ إلى 1.15 بفعل withClampedTextScaling
        openFilters: false,
      );
    });

    testWidgets('لوحة الفلاتر مفتوحة على هاتف صغير', (tester) async {
      await _expectNoOverflow(
        tester,
        size: const Size(360, 640),
        textScale: 1.0,
        openFilters: true,
      );
    });

    testWidgets('لوحة الفلاتر مفتوحة مع خط مكبَّر', (tester) async {
      await _expectNoOverflow(
        tester,
        size: const Size(360, 640),
        textScale: 2.0,
        openFilters: true,
      );
    });
  });
}
