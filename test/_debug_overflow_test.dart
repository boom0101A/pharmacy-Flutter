import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/screens/home_screen.dart';
import 'package:saydaliyati/state/medicine_store.dart';
import 'package:saydaliyati/theme.dart';

class _TestStore extends MedicineStore {
  @override
  Future<void> load() async {}
  @override
  Future<void> refreshFromCloud({bool manual = false}) async {}
}

void main() {
  testWidgets('dump', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final captured = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = captured.add;

    final store = _TestStore()
      ..seed([
        for (var i = 0; i < 6; i++)
          Medicine(
            id: 'm$i',
            barcode: '1234567890123',
            name: 'اسم مادة طويل نسبياً لاختبار الالتفاف',
            price: 1234567,
            quantity: 3,
            createdAt: 0,
            updatedAt: 0,
          ),
      ]);

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
    await tester.pumpAndSettle();

    FlutterError.onError = previous;

    for (final d in captured) {
      // ignore: avoid_print
      print('--- ${d.exception}');
      for (final line in d.toString().split('\n')) {
        if (line.contains('.dart:')) {
          // ignore: avoid_print
          print('    $line');
        }
      }
    }
    tester.takeException();
  });
}
