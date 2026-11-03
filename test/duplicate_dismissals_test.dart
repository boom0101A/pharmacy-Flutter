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

  test('السحابة هي المرجع: ما مُسح فيها يُمسح من هذا الهاتف', () async {
    d.resetForTest({'old'}); // قرار قديم مؤكّد، ليس معلّقاً
    d.cloudWrite = (_, _) async {};
    d.cloudRead = (_) async => [];
    await d.syncWithCloud();
    expect(d.keys, isEmpty);
  });

  test('قرار لم يصل الخادم بعد لا يضيع إن غاب عن السحابة', () async {
    final hang = Completer<void>();
    d.cloudWrite = (_, _) => hang.future; // بلا إنترنت
    d.cloudRead = (_) async => [];
    await d.add('fresh');
    await d.syncWithCloud();
    expect(d.keys, {'fresh'});
  });

  test('بعد تأكيد الخادم يخرج القرار من المعلّقة', () async {
    d.cloudWrite = (_, _) async {};
    var cloud = <String>[];
    d.cloudRead = (_) async => cloud;
    await d.add('k');
    await Future<void>.delayed(Duration.zero);
    cloud = ['k'];
    await d.syncWithCloud();
    expect(d.keys, {'k'});
    cloud = []; // مسحه هاتف آخر بـ«إظهار المخفية»
    await d.syncWithCloud();
    expect(d.keys, isEmpty);
  });

  test('ترحيل: قرارات النسخة السابقة غير المرفوعة تصير معلّقة', () async {
    SharedPreferences.setMockInitialValues({
      'dismissed_duplicate_groups': ['legacy'],
      'dismissed_duplicate_groups_migrated': false,
    });
    d.resetForTest();
    final written = <List<String>>[];
    final cloud = <String>{};
    d.cloudWrite = (_, keys) async {
      written.add(keys);
      cloud.addAll(keys); // كالخادم الحقيقي: ما أكّده يُقرأ بعدها
    };
    d.cloudRead = (_) async => cloud.toList();
    await d.loadLocal();
    await d.syncWithCloud();
    expect(d.keys, {'legacy'});
    expect(written.single, ['legacy']);
  });

  test('clearAll يفرّغ المحلي ويستبدل السحابة بقائمة فارغة', () async {
    d.resetForTest({'a', 'b'});
    d.cloudWrite = (_, _) async {};
    final cleared = <String>[];
    d.cloudClear = (pid) async => cleared.add(pid);
    await d.clearAll();
    expect(d.keys, isEmpty);
    expect(cleared, ['p1']);
  });
}
