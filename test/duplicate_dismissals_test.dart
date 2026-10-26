import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/services/app_settings.dart';
import 'package:saydaliyati/services/duplicate_dismissals.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// بلا إنترنت، كتابة Firestore (مع التخزين الدائم) لا يكتمل مستقبلها أبداً.
/// الواجهة يجب ألا تنتظرها.
void main() {
  final d = DuplicateDismissals.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.setPharmacyId('p1');
    d.resetForTest();
  });

  test('add يكتمل فوراً حتى لو لم تكتمل كتابة السحابة', () async {
    final written = <List<String>>[];
    d.cloudWrite = (pid, keys) {
      written.add(keys);
      return Completer<void>().future; // معلّقة كما في وضع الطيران
    };

    await d.add('g1').timeout(const Duration(seconds: 1));

    expect(d.keys, contains('g1'));
    expect(written.single, ['g1']);
  });

  test('syncWithCloud يكتمل ويدمج حتى لو علّقت الكتابة والقراءة', () async {
    d.resetForTest({'local'});
    d.cloudWrite = (_, _) => Completer<void>().future;
    d.cloudRead = (_) => Completer<List<String>>().future;
    d.cloudReadTimeout = const Duration(milliseconds: 50);

    await d.syncWithCloud().timeout(const Duration(seconds: 1));

    expect(d.keys, {'local'});
  });

  test('syncWithCloud يضيف قرارات السحابة', () async {
    d.cloudWrite = (_, _) async {};
    d.cloudRead = (_) async => ['cloud'];

    await d.syncWithCloud();

    expect(d.keys, {'cloud'});
  });
}
