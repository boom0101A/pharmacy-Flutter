import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/screens/settings_sheet.dart';
import 'package:saydaliyati/services/backup_actions.dart';
import 'package:saydaliyati/services/backup_service.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// النسخة الاحتياطية كانت تُحفظ في مجلد التطبيق الخاص: لا يراه تطبيق «الملفات»
/// ويُمسح عند إلغاء التثبيت — أي أنها تضيع في اللحظة التي تُطلب فيها. الآن
/// «حفظ نسخة» يفتح قائمة المشاركة لإخراج الملف، و«استرجاع» يقبل ملفاً من أي
/// مكان في الهاتف.
class _TestStore extends MedicineStore {
  List<Medicine>? imported;

  @override
  Future<void> load() async {}

  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}

  @override
  Future<({int added, int updated, int skipped})> importBackup(
    List<Medicine> incoming,
  ) async {
    imported = incoming;
    return (added: incoming.length, updated: 0, skipped: 0);
  }
}

const _validJson = '''
{"format":1,"items":[
 {"id":"m1","barcode":"","name":"باراسيتامول","price":1500,"quantity":3,"createdAt":1,"updatedAt":1},
 {"id":"m2","barcode":"","name":"شاش","price":250,"quantity":10,"createdAt":1,"updatedAt":1}
]}''';

void main() {
  group('BackupService.parse', () {
    test('نص صالح يعيد المواد', () {
      final c = BackupService.parse(_validJson);
      expect(c.ok, isTrue);
      expect(c.items.map((m) => m.id), ['m1', 'm2']);
    });

    test('نص ليس نسخة احتياطية يعيد خطأً لا استثناءً', () {
      expect(BackupService.parse('not json').ok, isFalse);
      expect(BackupService.parse('{"x":1}').ok, isFalse);
    });
  });

  group('واجهة النسخة الاحتياطية', () {
    late _TestStore store;
    late List<String> shared;
    late int pickCalls;
    String? pickResult;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      store = _TestStore();
      shared = [];
      pickCalls = 0;
      pickResult = null;
      BackupActions.export = () async => '/data/x/saydaliyati-backup-1.json';
      BackupActions.share = (path) async => shared.add(path);
      BackupActions.latestLocal = () async => null;
      BackupActions.pickJson = () async {
        pickCalls++;
        return pickResult;
      };
    });
    tearDown(BackupActions.reset);

    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    Future<void> openSettings(WidgetTester tester) async {
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
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showSettingsSheet(context, store),
                  child: const Text('فتح'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('فتح'));
      await tester.pumpAndSettle();
    }

    testWidgets('«حفظ نسخة» يفتح المشاركة بالملف المحفوظ', (tester) async {
      tall(tester);
      await openSettings(tester);
      await tester.tap(find.text('حفظ نسخة'));
      await tester.pumpAndSettle();

      expect(shared, ['/data/x/saydaliyati-backup-1.json']);
    });

    testWidgets('«استرجاع» بلا نسخة محلية يفتح اختيار ملف ويستورده', (
      tester,
    ) async {
      tall(tester);
      pickResult = _validJson;
      await openSettings(tester);
      await tester.tap(find.text('استرجاع'));
      await tester.pumpAndSettle();

      expect(pickCalls, 1);
      expect(find.textContaining('2 مادة'), findsOneWidget);
      await tester.tap(find.text('استرجع'));
      await tester.pumpAndSettle();
      expect(store.imported?.map((m) => m.id), ['m1', 'm2']);
    });

    testWidgets('إلغاء اختيار الملف لا يستورد شيئاً', (tester) async {
      tall(tester);
      await openSettings(tester);
      await tester.tap(find.text('استرجاع'));
      await tester.pumpAndSettle();

      expect(pickCalls, 1);
      expect(store.imported, isNull);
    });
  });
}
