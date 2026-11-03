import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/services/alerts.dart';

final _now = DateTime(2026, 11, 3, 10);

Medicine _m(
  String id, {
  int qty = 20,
  double price = 1000,
  int? inDays,
  int? minQty,
  ItemType type = ItemType.medicine,
}) => Medicine(
  id: id,
  barcode: '',
  name: 'Item $id',
  price: price,
  quantity: qty,
  minQuantity: minQty,
  type: type,
  expiryDate: inDays == null
      ? null
      : _now.add(Duration(days: inDays, hours: 1)).millisecondsSinceEpoch,
  createdAt: 0,
  updatedAt: 0,
);

void main() {
  List<AlertKind> kinds(List<StockAlert> a) => [for (final x in a) x.kind];

  test('الأنواع الخمسة وترتيبها بالأولوية', () {
    final alerts = computeAlerts([
      _m('low', qty: 3),
      _m('soon', inDays: 60),
      _m('out', qty: 0),
      _m('urgent', inDays: 10),
      _m('expired', inDays: -5),
    ], now: _now);
    expect(kinds(alerts), [
      AlertKind.expired,
      AlertKind.urgent,
      AlertKind.out,
      AlertKind.low,
      AlertKind.soon,
    ]);
  });

  test('مادة سليمة لا تنبيه لها، وصلاحية بعيدة لا تُعدّ', () {
    expect(
      computeAlerts([_m('ok'), _m('far', inDays: 200)], now: _now),
      isEmpty,
    );
  });

  test('تنبيه واحد لكل محور: الصلاحية الأشد فقط، والمخزون منفصل', () {
    final alerts = computeAlerts([_m('a', inDays: -2, qty: 0)], now: _now);
    expect(kinds(alerts), [AlertKind.expired, AlertKind.out]);
  });

  test('صفر بلا سعر تسجيل ناقص لا «نافدة»', () {
    expect(computeAlerts([_m('x', qty: 0, price: 0)], now: _now), isEmpty);
  });

  test('الحد الخاص للمادة', () {
    expect(kinds(computeAlerts([_m('x', qty: 12, minQty: 15)], now: _now)), [
      AlertKind.low,
    ]);
  });

  test('«تمّ» يخفي التنبيه، ويعود إن تغيّر نوعه', () {
    final dismissed = {'u:urgent'};
    expect(
      computeAlerts([_m('u', inDays: 10)], now: _now, dismissed: dismissed),
      isEmpty,
    );
    // انتهت صلاحيتها لاحقاً: مفتاح جديد فيعود التنبيه
    final later = computeAlerts(
      [_m('u', inDays: 10)],
      now: _now.add(const Duration(days: 12)),
      dismissed: dismissed,
    );
    expect(kinds(later), [AlertKind.expired]);
  });

  test('بتاريخ مستقبلي: ما سيصير عاجلاً صباح الغد', () {
    final tomorrow = _now.add(const Duration(days: 1));
    final m = _m('x', inDays: 31);
    expect(computeAlerts([m], now: _now).single.kind, AlertKind.soon);
    expect(computeAlerts([m], now: tomorrow).single.kind, AlertKind.urgent);
  });

  test('المفتاح يحمل النوع، وdaysLeft للصلاحية', () {
    final a = computeAlerts([_m('x', inDays: 9)], now: _now).single;
    expect(a.key, 'x:urgent');
    expect(a.daysLeft, 9);
  });

  test('isCritical: كل شيء عدا «قريبة»', () {
    final alerts = computeAlerts([
      _m('a', inDays: -1),
      _m('b', inDays: 50),
      _m('c', qty: 2),
    ], now: _now);
    expect([for (final a in alerts) a.isCritical], [true, true, false]);
  });
}
