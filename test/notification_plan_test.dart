import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/services/notification_service.dart';

final _slot = DateTime(2026, 11, 4, 9);

Medicine _m(String id, {int qty = 20, int? inDays}) => Medicine(
  id: id,
  barcode: '',
  name: 'Item $id',
  price: 1000,
  quantity: qty,
  expiryDate: inDays == null
      ? null
      : _slot.add(Duration(days: inDays, hours: 1)).millisecondsSinceEpoch,
  createdAt: 0,
  updatedAt: 0,
);

void main() {
  test('الجديد فقط: ما أُبلغ عنه لا يتكرر، و«قريبة» لا تُبلغ', () {
    final all = [_m('a', inDays: -1), _m('b', qty: 0), _m('c', inDays: 60)];
    final p1 = NotificationService.planNew(all, slot: _slot, notified: {});
    expect(p1.fresh.map((a) => a.key), ['a:expired', 'b:out']);
    final p2 = NotificationService.planNew(
      all,
      slot: _slot,
      notified: {'a:expired', 'b:out'},
    );
    expect(p2.fresh, isEmpty);
  });

  test('ما انحلّ يخرج من «المُبلَّغ» فيُبلَّغ إن عاد', () {
    final p = NotificationService.planNew(
      [_m('b', qty: 0)],
      slot: _slot,
      notified: {'a:expired', 'b:out'},
    );
    expect(p.notified, {'b:out'});
  });

  test('المخفي بـ«تمّ» لا يُبلَّغ', () {
    final p = NotificationService.planNew(
      [_m('a', inDays: -1)],
      slot: _slot,
      notified: {},
      dismissed: {'a:expired'},
    );
    expect(p.fresh, isEmpty);
  });

  test('المحتوى بالأسماء، و«و N أخرى» بعد خمسة', () {
    final all = [for (var i = 0; i < 7; i++) _m('$i', qty: 0)];
    final fresh = NotificationService.planNew(
      all,
      slot: _slot,
      notified: {},
    ).fresh;
    final c = NotificationService.buildAlertsContent(fresh);
    expect(c.lines.length, 6);
    expect(c.lines.first, '🚫 Item 0 — نفدت');
    expect(c.lines.last, 'و2 أخرى');
  });
}
