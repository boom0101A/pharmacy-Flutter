import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/services/sync_service.dart';

/// حارس ضد عودة عطل «المزامنة تزوّر ختم الوقت».
///
/// `syncAll` ينسخ السجل المنزَّل بـ`copyWith` ليحافظ على صورة الجهاز المحلية.
/// و`copyWith` يختم بـ«الآن» إن لم يُمرَّر `updatedAt` صراحةً — فكان كل سجل
/// يُنزَّل يُخزَّن محلياً بختم أحدث من نسخته السحابية. النتيجة: المزامنة
/// التالية ترى المحلي «أحدث» فترفعه فوق تعديل الجهاز الآخر وتمحوه.
///
/// هذه الاختبارات تثبّت العقد الذي يعتمد عليه `syncAll`: `copyWith` بلا
/// `updatedAt` يختم بالآن (سلوك مقصود لتعديلات المستخدم)، ومع تمريره يحافظ
/// على الختم (وهو ما تحتاجه المزامنة).
void main() {
  const remote = Medicine(
    id: 'm1',
    barcode: '123',
    name: 'دواء',
    price: 100,
    quantity: 10,
    createdAt: 1000,
    updatedAt: 5000, // ختم قديم قادم من السحابة
  );

  group('copyWith وختم الوقت', () {
    test('بلا updatedAt يختم بالآن — سلوك مقصود لتعديل المستخدم', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final copy = remote.copyWith(quantity: 20);
      expect(copy.updatedAt, greaterThanOrEqualTo(before));
    });

    test('مع updatedAt يحافظ عليه حرفياً — وهو ما تعتمده المزامنة', () {
      final copy = remote.copyWith(
        imagePath: 'local.jpg',
        updatedAt: remote.updatedAt,
      );
      expect(copy.updatedAt, 5000);
      expect(copy.imagePath, 'local.jpg');
    });
  });

  group('محاكاة قرار المزامنة بعد النسخ', () {
    /// نفس شرط حلقة الصعود في syncAll: يُرفع المحلي إن كان أحدث من السحابي.
    bool wouldReupload(Medicine local, Medicine cloud) =>
        local.updatedAt > cloud.updatedAt;

    test('النسخ الصحيح لا يُنتج رفعاً مرتداً', () {
      final stored = remote.copyWith(
        imagePath: 'local.jpg',
        updatedAt: remote.updatedAt,
      );
      expect(
        wouldReupload(stored, remote),
        isFalse,
        reason: 'السجل المنزَّل يجب ألا يبدو أحدث من مصدره',
      );
    });

    test('النسخ بلا تمرير الختم يُنتج رفعاً مرتداً (العطل الذي أُصلح)', () {
      final buggy = remote.copyWith(imagePath: 'local.jpg');
      expect(
        wouldReupload(buggy, remote),
        isTrue,
        reason: 'يوثّق سبب العطل: الختم المزوَّر يجعل المحلي يبدو أحدث',
      );
    });

    test('تعديل أحدث من جهاز آخر يفوز على نسخة منزَّلة سليمة', () {
      final stored = remote.copyWith(updatedAt: remote.updatedAt);
      final otherDeviceEdit = remote.copyWith(quantity: 99, updatedAt: 6000);

      expect(wouldReupload(stored, otherDeviceEdit), isFalse);
      expect(
        otherDeviceEdit.updatedAt > stored.updatedAt,
        isTrue,
        reason: 'تعديل أخيك الأحدث هو ما يجب أن ينزل، لا أن يُدهَس',
      );
    });
  });

  group('صورة محلية غائبة لا ترث مسار السحابة', () {
    const remoteWithLegacyImage = Medicine(
      id: 'm2',
      barcode: '',
      name: 'دواء بصورة قديمة',
      price: 10,
      quantity: 1,
      imagePath: 'legacy_from_web.jpg',
      createdAt: 0,
      updatedAt: 100,
    );

    test('clearImage يمنع وراثة مسار لا وجود له على هذا الجهاز', () {
      // ما يفعله syncAll حين لا يملك الجهاز صورة محلية
      final stored = remoteWithLegacyImage.copyWith(
        imagePath: null,
        clearImage: true,
        updatedAt: remoteWithLegacyImage.updatedAt,
      );
      expect(stored.imagePath, isNull);
      expect(stored.updatedAt, 100);
    });

    test('صورة محلية موجودة تُحفظ كما هي', () {
      final stored = remoteWithLegacyImage.copyWith(
        imagePath: 'mine.jpg',
        clearImage: false,
        updatedAt: remoteWithLegacyImage.updatedAt,
      );
      expect(stored.imagePath, 'mine.jpg');
    });
  });

  // مادة حُذفت أثناء دورة مزامنة كانت تُرفع ثانية من لقطة البداية.
  test('دفعة الرفع تُسقط ما دخل طابور الحذف أثناء الدورة', () {
    final pending = <String, Object?>{'a': 1, 'b': 2, 'c': 3};
    SyncService.dropQueuedDeletes(pending, ['b', 'zz']);
    expect(pending.keys, ['a', 'c']);
  });
}
