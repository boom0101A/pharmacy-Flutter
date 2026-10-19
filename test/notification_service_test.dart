import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/services/notification_service.dart';

Medicine _item({
  required String id,
  int quantity = 10,
  double price = 100,
  DateTime? expiry,
}) => Medicine(
  id: id,
  barcode: '',
  name: 'مادة $id',
  price: price,
  quantity: quantity,
  expiryDate: expiry?.millisecondsSinceEpoch,
  createdAt: 0,
  updatedAt: 0,
);

void main() {
  final now = DateTime.now();

  group('buildSummary — دالة صِرفة بلا شبكة ولا إشعار فعلي', () {
    test('قائمة فارغة تعيد null', () {
      expect(NotificationService.buildSummary([]), isNull);
    });

    test('مخزون سليم كله لا يستدعي تنبيهاً', () {
      final all = [
        _item(
          id: 'a',
          quantity: 50,
          expiry: now.add(const Duration(days: 400)),
        ),
        _item(id: 'b', quantity: 20),
      ];
      expect(NotificationService.buildSummary(all), isNull);
    });

    test('منتهية الصلاحية تُحسب وتظهر بالنص', () {
      final all = [
        _item(id: 'a', expiry: now.subtract(const Duration(days: 5))),
      ];
      final summary = NotificationService.buildSummary(all);
      expect(summary, isNotNull);
      expect(summary, contains('1 منتهية الصلاحية'));
    });

    test('قاربت الانتهاء (خلال 180 يوماً) تُحسب في عدّاد منفصل', () {
      final all = [_item(id: 'a', expiry: now.add(const Duration(days: 30)))];
      final summary = NotificationService.buildSummary(all);
      expect(summary, contains('1 تقترب من الانتهاء'));
      expect(summary, isNot(contains('منتهية الصلاحية')));
    });

    test('منتهية فعلاً لا تُحسب أيضاً كـ"تقترب من الانتهاء" — لا ازدواج', () {
      final all = [
        _item(id: 'a', expiry: now.subtract(const Duration(days: 1))),
      ];
      final summary = NotificationService.buildSummary(all);
      expect(summary, contains('منتهية الصلاحية'));
      expect(summary, isNot(contains('تقترب من الانتهاء')));
    });

    test('نافد من المخزون (صفر) يُحسب', () {
      final all = [_item(id: 'a', quantity: 0)];
      expect(
        NotificationService.buildSummary(all),
        contains('1 نفدت من المخزون'),
      );
    });

    test('منخفض المخزون (1 إلى 5) يُحسب ولا يُخلَط بالنافد', () {
      final all = [_item(id: 'a', quantity: 3)];
      final summary = NotificationService.buildSummary(all);
      expect(summary, contains('1 منخفضة المخزون'));
      expect(summary, isNot(contains('نفدت من المخزون')));
    });

    test('مخزون 6 فأكثر لا يُحسب منخفضاً', () {
      final all = [_item(id: 'a', quantity: 6)];
      expect(NotificationService.buildSummary(all), isNull);
    });

    test('كل الحالات الأربع معاً تُجمع في نص واحد بعدادات صحيحة', () {
      final all = [
        _item(id: 'expired', expiry: now.subtract(const Duration(days: 1))),
        _item(id: 'soon1', expiry: now.add(const Duration(days: 10))),
        _item(id: 'soon2', expiry: now.add(const Duration(days: 20))),
        _item(id: 'out', quantity: 0),
        _item(id: 'low', quantity: 2),
      ];
      final summary = NotificationService.buildSummary(all);
      expect(summary, contains('1 منتهية الصلاحية'));
      expect(summary, contains('2 تقترب من الانتهاء'));
      expect(summary, contains('1 نفدت من المخزون'));
      expect(summary, contains('1 منخفضة المخزون'));
    });

    test('مواد القسمين معاً تُجمع في ملخّص واحد — لا فصل بالنوع', () {
      final all = [
        Medicine(
          id: 'm',
          barcode: '',
          name: 'دواء',
          price: 1,
          quantity: 0,
          type: ItemType.medicine,
          createdAt: 0,
          updatedAt: 0,
        ),
        Medicine(
          id: 's',
          barcode: '',
          name: 'مستلزم',
          price: 1,
          quantity: 0,
          type: ItemType.supply,
          createdAt: 0,
          updatedAt: 0,
        ),
      ];
      expect(
        NotificationService.buildSummary(all),
        contains('2 نفدت من المخزون'),
      );
    });
  });

  // مجموعة `checkAndNotifyIfNeeded` أُزيلت مع الدالة نفسها: بعد تفعيل
  // الجدولة اليومية الحقيقية صار الإشعار الفوري عند فتح التطبيق يكرّر نفس
  // النص مرتين في اليوم الواحد. تغطية `buildSummary` أعلاه (وهي المنطق الذي
  // تستعمله الجدولة فعلياً) باقية كما هي.

  group('عدم إزعاج المستخدم بإشعار بلا داعٍ', () {
    test('مخزون سليم تماماً لا ينتج ملخّصاً ولا حمولة — فلا جدولة أصلاً', () {
      final all = [
        _item(
          id: 'a',
          quantity: 40,
          expiry: now.add(const Duration(days: 500)),
        ),
      ];
      expect(NotificationService.buildSummary(all), isNull);
      expect(NotificationService.computePayload(all), isNull);
    });
  });

  group('scheduleWithFallback', () {
    test('الدقيقة تنجح ⇒ لا محاولة ثانية', () async {
      final modes = <AndroidScheduleMode>[];
      await NotificationService.scheduleWithFallback((m) async => modes.add(m));
      expect(modes, [AndroidScheduleMode.exactAllowWhileIdle]);
    });

    test('الدقيقة مرفوضة ⇒ تُجدول غير دقيقة', () async {
      final modes = <AndroidScheduleMode>[];
      await NotificationService.scheduleWithFallback((m) async {
        modes.add(m);
        if (m == AndroidScheduleMode.exactAllowWhileIdle) {
          throw Exception('exact_alarms_not_permitted');
        }
      });
      expect(modes, [
        AndroidScheduleMode.exactAllowWhileIdle,
        AndroidScheduleMode.inexactAllowWhileIdle,
      ]);
    });
  });
}
