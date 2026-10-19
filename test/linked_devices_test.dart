import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/screens/linked_devices_sheet.dart';
import 'package:saydaliyati/services/pharmacy_service.dart';
import 'package:saydaliyati/theme.dart';

/// شاشة «الأجهزة المرتبطة» بدوال حقن بدل Firestore.
void main() {
  const owner = 'Kmpv0000owner';
  const stranger = 'G7IWAicAstranger';
  late List<String> removed;

  setUp(() => removed = []);

  Future<void> open(WidgetTester tester, {required String me}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: LinkedDevicesSheet(
            loadMembers: () async => const PharmacyMembers(
              ownerUid: owner,
              memberUids: [owner, 'l9u8n5PTphone', stranger],
            ),
            removeMember: (uid) async => removed.add(uid),
            myUid: me,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('يعرض كل الأجهزة بمعرّفاتها القصيرة', (tester) async {
    await open(tester, me: owner);
    expect(find.text('جهاز Kmpv0000…'), findsOneWidget);
    expect(find.text('جهاز G7IWAicA…'), findsOneWidget);
    expect(find.textContaining('صاحب المخزون'), findsOneWidget);
  });

  testWidgets('المالك يُخرج جهازاً بعد التأكيد', (tester) async {
    await open(tester, me: owner);
    expect(find.text('إخراج'), findsNWidgets(2));

    await tester.tap(find.text('إخراج').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'إخراج'));
    await tester.pumpAndSettle();

    expect(removed, [stranger]);
    expect(find.text('جهاز G7IWAicA…'), findsNothing);
  });

  testWidgets('العضو غير المالك يرى القائمة بلا أزرار إخراج', (tester) async {
    await open(tester, me: 'l9u8n5PTphone');
    expect(find.text('إخراج'), findsNothing);
    expect(find.textContaining('هذا الهاتف'), findsOneWidget);
  });
}
