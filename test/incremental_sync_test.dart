import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/invoice.dart';
import 'package:saydaliyati/services/sync_service.dart';

Invoice _inv(String id, int updated) =>
    Invoice(id: id, createdAt: 1, updatedAt: updated);

void main() {
  const day = 24 * 60 * 60 * 1000;
  const now = 100 * day;

  group('needsFull — نوع دورة المزامنة', () {
    test('أول مرة (لا مؤشر) ← كاملة', () {
      expect(
        SyncService.needsFull(
          seenMs: null,
          lastFullMs: null,
          manual: false,
          nowMs: now,
        ),
        isTrue,
      );
    });

    test('السحب اليدوي ← كاملة دائماً', () {
      expect(
        SyncService.needsFull(
          seenMs: now,
          lastFullMs: now,
          manual: true,
          nowMs: now,
        ),
        isTrue,
      );
    });

    test('مرّ أكثر من أسبوع على آخر كاملة ← كاملة', () {
      expect(
        SyncService.needsFull(
          seenMs: now,
          lastFullMs: now - 8 * day,
          manual: false,
          nowMs: now,
        ),
        isTrue,
      );
    });

    test('تشغيل عادي بعد كاملة حديثة ← تزايدية', () {
      expect(
        SyncService.needsFull(
          seenMs: 0, // 0 = كاملة سابقة بلا أختام قديمة — مؤشر صالح
          lastFullMs: now - day,
          manual: false,
          nowMs: now,
        ),
        isFalse,
      );
    });
  });

  group('mergeInvoices تزايدياً (uploadSince)', () {
    test('غيابها عن «ما تغيّر» لا يعني أنها غير مرفوعة', () {
      final r = SyncService.mergeInvoices(
        local: [_inv('old', 5), _inv('new', 50)],
        remote: const [],
        deleted: {},
        uploadSince: 10,
      );
      expect(r.upload.map((i) => i.id), ['new']);
      expect(r.merged.map((i) => i.id), unorderedEquals(['old', 'new']));
    });

    test('بلا uploadSince (كاملة) يُرفع كل غائب عن السحابة', () {
      final r = SyncService.mergeInvoices(
        local: [_inv('old', 5), _inv('new', 50)],
        remote: const [],
        deleted: {},
      );
      expect(r.upload.map((i) => i.id), unorderedEquals(['old', 'new']));
    });

    test('النازلة الأحدث تفوز ولا تُرفع المحلية الأقدم', () {
      final r = SyncService.mergeInvoices(
        local: [_inv('a', 20)],
        remote: [_inv('a', 30)],
        deleted: {},
        uploadSince: 10,
      );
      expect(r.upload, isEmpty);
      expect(r.merged.single.updatedAt, 30);
    });
  });
}
