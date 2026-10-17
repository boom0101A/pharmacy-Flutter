import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/services/pharmacy_service.dart';

void main() {
  group('generateCode — رمز اقتران رقمي دائماً من 6 خانات', () {
    test('كل رمز مكوّن من 6 أرقام بالضبط، بلا حاجة لحشو', () {
      final rng = Random(1);
      for (var i = 0; i < 200; i++) {
        final code = PharmacyService.generateCode(rng);
        expect(code.length, 6);
        expect(int.tryParse(code), isNotNull);
        expect(code.startsWith('0'), isFalse);
      }
    });

    test('يقع دائماً بين 100000 و999999', () {
      final rng = Random(42);
      for (var i = 0; i < 200; i++) {
        final n = int.parse(PharmacyService.generateCode(rng));
        expect(n, greaterThanOrEqualTo(100000));
        expect(n, lessThanOrEqualTo(999999));
      }
    });
  });

  group('isExpired — مقارنة زمنية حدّية', () {
    test('قبل الانتهاء بلحظة: غير منتهٍ', () {
      final expiresAt = DateTime(2026, 1, 1, 12, 0, 0);
      final now = expiresAt.subtract(const Duration(seconds: 1));
      expect(
        PharmacyService.isExpired(expiresAt.millisecondsSinceEpoch, now),
        isFalse,
      );
    });

    test('عند لحظة الانتهاء بالضبط: منتهٍ', () {
      final expiresAt = DateTime(2026, 1, 1, 12, 0, 0);
      expect(
        PharmacyService.isExpired(expiresAt.millisecondsSinceEpoch, expiresAt),
        isTrue,
      );
    });

    test('بعد الانتهاء: منتهٍ', () {
      final expiresAt = DateTime(2026, 1, 1, 12, 0, 0);
      final now = expiresAt.add(const Duration(minutes: 1));
      expect(
        PharmacyService.isExpired(expiresAt.millisecondsSinceEpoch, now),
        isTrue,
      );
    });
  });

  group('statusOf — حالة رمز الاقتران كما تعرضها الواجهة', () {
    final now = DateTime(2026, 1, 1, 12, 0, 0);

    test('open وصلاحيته لم تنتهِ بعد يبقى open', () {
      final data = {
        'status': 'open',
        'expiresAt': now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
      };
      expect(PharmacyService.statusOf(data, now), PairingStatus.open);
    });

    test('open انتهت صلاحيته يتحوّل expired حتى لو لم يُحدَّث الحقل', () {
      final data = {
        'status': 'open',
        'expiresAt': now
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
      };
      expect(PharmacyService.statusOf(data, now), PairingStatus.expired);
    });

    test('requested تُقرأ كما هي بلا فحص انتهاء', () {
      final data = {'status': 'requested', 'joinerUid': 'u2'};
      expect(PharmacyService.statusOf(data, now), PairingStatus.requested);
    });

    test('joined تُقرأ كما هي', () {
      expect(
        PharmacyService.statusOf({'status': 'joined'}, now),
        PairingStatus.joined,
      );
    });

    test('declined تُقرأ كما هي', () {
      expect(
        PharmacyService.statusOf({'status': 'declined'}, now),
        PairingStatus.declined,
      );
    });

    test('cancelled تُقرأ كما هي', () {
      expect(
        PharmacyService.statusOf({'status': 'cancelled'}, now),
        PairingStatus.cancelled,
      );
    });

    test('قيمة غير معروفة أو غائبة تعيد unknown', () {
      expect(PharmacyService.statusOf({}, now), PairingStatus.unknown);
      expect(
        PharmacyService.statusOf({'status': 'weird'}, now),
        PairingStatus.unknown,
      );
    });
  });
}
