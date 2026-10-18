import '../models/medicine.dart';
import '../state/medicine_store.dart';
import 'gs1_parser.dart';

/// مجموعة مواد يُشتبه أنها نفس المادة مكرّرة.
class DuplicateGroup {
  DuplicateGroup(this.items, {required this.byBarcode});

  final List<Medicine> items;

  /// تجمّعت (جزئياً على الأقل) بباركود مشترك — قد تكون منتجات مختلفة
  /// نسبت إليها الفاتورة باركوداً خاطئاً، لا تكراراً حقيقياً.
  final bool byBarcode;

  /// مفتاح ثابت لا يتغيّر بترتيب المواد — يُحفظ عند «ليست مكرّرة».
  String get key => (items.map((m) => m.id).toList()..sort()).join('|');
}

/// المواد المكرّرة: نفس الاسم المطبَّع داخل نفس القسم، أو نفس الباركود (بأي
/// صيغة 12/13/14 خانة) في أي قسم. المجموعات المتداخلة تتوحّد.
List<DuplicateGroup> findDuplicateGroups(
  List<Medicine> items, {
  Set<String> dismissed = const {},
}) {
  final parent = List<int>.generate(items.length, (i) => i);
  int find(int i) {
    while (parent[i] != i) {
      parent[i] = parent[parent[i]];
      i = parent[i];
    }
    return i;
  }

  void union(int a, int b) => parent[find(a)] = find(b);

  final byName = <String, int>{};
  final byCode = <String, int>{};
  final sharedCode = <int>{};
  for (var i = 0; i < items.length; i++) {
    final m = items[i];
    final name = MedicineStore.normalizeName(m.name);
    if (name.isNotEmpty) {
      final key = '${m.type.name}::$name';
      final j = byName[key];
      if (j == null) {
        byName[key] = i;
      } else {
        union(i, j);
      }
    }
    final code = _canonicalBarcode(m.barcode);
    if (code != null) {
      final j = byCode[code];
      if (j == null) {
        byCode[code] = i;
      } else {
        union(i, j);
        sharedCode
          ..add(i)
          ..add(j);
      }
    }
  }

  final groups = <int, List<int>>{};
  for (var i = 0; i < items.length; i++) {
    (groups[find(i)] ??= []).add(i);
  }
  return [
    for (final idx in groups.values)
      if (idx.length > 1)
        DuplicateGroup([
          for (final i in idx) items[i],
        ], byBarcode: idx.any(sharedCode.contains)),
  ].where((g) => !dismissed.contains(g.key)).toList();
}

/// الصيغ المكافئة (EAN-13 مقابل GTIN-14 بصفر بادئ) تُختزل لمفتاح واحد.
String? _canonicalBarcode(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  if (!RegExp(r'^\d+$').hasMatch(s)) return s;
  final stripped = s.replaceFirst(RegExp(r'^0+'), '');
  return stripped.isEmpty ? null : stripped;
}

/// دمج مجموعة في المادة [keeperId]:
/// - الكمية = المجموع (الكميات تُجمع في المخزون).
/// - السعر = سعر الأحدث تعديلاً من بين الأسعار غير الصفرية.
/// - الصلاحية = الأقرب (التنبيه المبكر أسلم).
/// - الباركود = أول باركود يجتاز خانة التحقق، وإلا فارغ.
Medicine mergeGroup(List<Medicine> group, String keeperId, DateTime now) {
  final keeper = group.firstWhere((m) => m.id == keeperId);
  final byNewest = [...group]
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  final price = byNewest
      .map((m) => m.price)
      .firstWhere((p) => p > 0, orElse: () => 0);

  int? expiry;
  for (final m in group) {
    final e = m.expiryDate;
    if (e != null && (expiry == null || e < expiry)) expiry = e;
  }

  final barcode = [keeper, ...byNewest]
      .map((m) => m.barcode.trim())
      .firstWhere(Gs1Parser.isValidGtin, orElse: () => '');

  return keeper.copyWith(
    quantity: group.fold<int>(0, (n, m) => n + m.quantity),
    price: price,
    expiryDate: expiry,
    clearExpiry: expiry == null,
    barcode: barcode,
    updatedAt: now.millisecondsSinceEpoch,
  );
}
