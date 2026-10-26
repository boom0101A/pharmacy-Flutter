import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/services/sync_service.dart';

FirebaseException _denied() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');

/// كاتب مزيّف: يرفض أي دفعة تحتوي معرّفاً من [deny]، ويسجّل المقبول.
class _FakeCloud {
  _FakeCloud(this.deny);
  final Set<String> deny;
  final written = <String>[];
  var calls = 0;

  Future<void> commit(List<String> ids) async {
    calls++;
    if (ids.any(deny.contains)) throw _denied();
    written.addAll(ids);
  }
}

void main() {
  const t = Duration(seconds: 1);

  test('مستند مرفوض واحد لا يُفشل الدفعة كلها — يُعزل ويُكتب الباقي', () async {
    final cloud = _FakeCloud({'b'});
    final r = await SyncService.commitIsolated(
      ['a', 'b', 'c'],
      commit: cloud.commit,
      timeout: t,
    );
    expect(r.acked, isTrue);
    expect(r.denied, ['b']);
    expect(cloud.written, unorderedEquals(['a', 'c']));
  });

  test('دفعة مقبولة كلها ← محاولة واحدة بلا عزل', () async {
    final cloud = _FakeCloud({});
    final r = await SyncService.commitIsolated(
      ['a', 'b'],
      commit: cloud.commit,
      timeout: t,
    );
    expect(r.denied, isEmpty);
    expect(cloud.calls, 1);
  });

  test('كل المستندات مرفوضة ← رفض حقيقي (عضوية مثلاً) يُعاد رميه', () async {
    final cloud = _FakeCloud({'a', 'b'});
    expect(
      SyncService.commitIsolated(['a', 'b'], commit: cloud.commit, timeout: t),
      throwsA(isA<FirebaseException>()),
    );
  });

  test('بلا إنترنت ← acked=false دون انتظار أبدي', () async {
    final r = await SyncService.commitIsolated(
      ['a'],
      commit: (_) => Completer<void>().future,
      timeout: const Duration(milliseconds: 50),
    );
    expect(r.acked, isFalse);
  });

  test('إعادة الربط: معرّف جديد وكل ما عداه كما هو', () {
    const m = Medicine(
      id: 'med_1',
      barcode: '6285128013338',
      name: 'نين',
      price: 1000,
      quantity: 59,
      company: 'Juman',
      createdAt: 5,
      updatedAt: 9,
    );
    final r = SyncService.rekeyed(m, DateTime(2026, 10, 27));
    expect(r.id, isNot('med_1'));
    expect(r.toMap()..remove('id'), m.toMap()..remove('id'));
  });

  test('الدفعات مقسّمة على الحد', () async {
    final cloud = _FakeCloud({});
    await SyncService.commitIsolated(
      List.generate(5, (i) => '$i'),
      commit: cloud.commit,
      timeout: t,
      limit: 2,
    );
    expect(cloud.calls, 3);
    expect(cloud.written.length, 5);
  });
}
