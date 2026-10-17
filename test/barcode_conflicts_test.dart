import 'package:flutter_test/flutter_test.dart';
import 'package:saydaliyati/models/medicine.dart';
import 'package:saydaliyati/services/barcode_conflicts.dart';

Medicine m(String id, String barcode) => Medicine(
  id: id,
  barcode: barcode,
  name: 'x',
  price: 0,
  quantity: 1,
  createdAt: 1,
  updatedAt: 1,
);

/// نسخة 2026-10-17 أدرجت خطأً في طابور الحذف كل مادة خسرت تعارض باركود.
/// هذه هي المواد التي ما زالت في السحابة ولها توأم بنفس الباركود — تُزال من
/// الطابور ولا تُعامَل كمحذوفة. حذف المستخدم الحقيقي لا يُمَس.
void main() {
  final remote = {
    'a': m('a', '111'),
    'b': m('b', '111'), // توأم a
    'c': m('c', '222'), // بلا توأم
    'd': m('d', ''), // بلا باركود
  };

  test('معرّف في الطابور له توأم باركود في السحابة = أثر تعارض', () {
    expect(conflictArtifactIds(['a', 'b'], remote), {'a', 'b'});
  });

  test('حذف حقيقي (لا توأم، أو بلا باركود، أو غير موجود سحابياً) يبقى', () {
    expect(conflictArtifactIds(['c', 'd', 'gone'], remote), isEmpty);
  });
}
