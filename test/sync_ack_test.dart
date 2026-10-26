import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/services/sync_service.dart';

/// مع التخزين الدائم، مستقبل كتابة Firestore لا يكتمل بلا إنترنت — والدورة
/// يجب ألا تنتظره إلى الأبد.
void main() {
  const short = Duration(milliseconds: 50);

  test('كتابة معلّقة (بلا إنترنت) ← false خلال المهلة', () async {
    final ok = await SyncService.awaitServerAck(
      Completer<void>().future,
      short,
    ).timeout(const Duration(seconds: 1));
    expect(ok, isFalse);
  });

  test('كتابة أكّدها الخادم ← true', () async {
    expect(await SyncService.awaitServerAck(Future.value(), short), isTrue);
  });

  test('رفض حقيقي من الخادم يُعاد رميه', () async {
    expect(
      SyncService.awaitServerAck(
        Future.error(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        short,
      ),
      throwsA(isA<FirebaseException>()),
    );
  });
}
