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

  // التجميع بالاسم يحترم الباركود: نفس الاسم بباركودين مختلفين صنفان مختلفان
  // (طعم/لون آخر للدواء نفسه) لا تكرار. داخل كل اسم: مرساة لكل باركود،
  // وأول مادة بلا باركود ترتبط بأول باركود فقط — فلا تجسّر بين صنفين.
  final byName = <String, _NameGroup>{};
  final byCode = <String, int>{};
  final sharedCode = <int>{};
  for (var i = 0; i < items.length; i++) {
    final m = items[i];
    final code = Gs1Parser.canonicalKey(m.barcode);
    final name = MedicineStore.normalizeName(m.name);
    if (name.isNotEmpty) {
      final g = byName.putIfAbsent('${m.type.name}::$name', _NameGroup.new);
      if (code == null) {
        final first = g.noCode;
        if (first != null) {
          union(i, first);
        } else {
          g.noCode = i;
          if (g.anchors.isNotEmpty) {
            g.linkedCode = g.anchors.keys.first;
            union(i, g.anchors.values.first);
          }
        }
      } else {
        final same = g.anchors[code];
        if (same != null) {
          union(i, same);
        } else {
          g.anchors[code] = i;
          final orphan = g.noCode;
          if (orphan != null && g.linkedCode == null) {
            g.linkedCode = code;
            union(i, orphan);
          }
        }
      }
    }
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

  // صورة الباقية، وإلا أول صورة في المجموعة — لا تضيع صورة بالدمج
  final image =
      keeper.imagePath ??
      group
          .map((m) => m.imagePath)
          .firstWhere((p) => p != null, orElse: () => null);

  // الشركة ونوع المادة: قيمة الباقية، وإلا الأحدث غير الفارغ — لا يضيعان بالدمج
  String? firstText(Iterable<String?> values) => values
      .map((v) => v?.trim())
      .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
  final company = firstText([
    keeper.company,
    ...byNewest.map((m) => m.company),
  ]);
  final category = firstText([
    keeper.category,
    ...byNewest
        .where((m) => m.type == ItemType.medicine)
        .map((m) => m.category),
  ]);

  return keeper.copyWith(
    imagePath: image,
    company: company,
    category: category,
    quantity: group.fold<int>(0, (n, m) => n + m.quantity),
    price: price,
    expiryDate: expiry,
    clearExpiry: expiry == null,
    barcode: barcode,
    updatedAt: now.millisecondsSinceEpoch,
  );
}

/// قائمة المراجعة: نسخ السحابة (ترى المكرَّر بالباركود الذي لا يُحفظ محلياً)
/// مصحَّحة بما على هذا الهاتف.
///
/// - [deleted] (طابور الحذف المحلي) مستبعد: حُذف هنا ولم يصل حذفه بعد.
/// - النسخة المحلية الأحدث تفوز: تعديل لم يُرفع بعد لا يُدمج بقيمته القديمة.
/// - مسار الصورة يؤخذ من المحلي دائماً — السحابة لا تحمله، وحفظ نسخة سحابية
///   كما هي كان يمحو صورة المادة.
/// - المواد المحلية التي لم تُرفع بعد تُضاف.
List<Medicine> reconcileReviewItems({
  required List<Medicine> cloud,
  required List<Medicine> local,
  Set<String> deleted = const {},
}) {
  final localById = {for (final m in local) m.id: m};
  final out = <Medicine>[];
  final seen = <String>{};
  for (final remote in cloud) {
    if (deleted.contains(remote.id) || !seen.add(remote.id)) continue;
    final mine = localById[remote.id];
    if (mine == null) {
      out.add(remote);
    } else if (mine.updatedAt >= remote.updatedAt) {
      out.add(mine);
    } else {
      out.add(
        remote.copyWith(
          imagePath: mine.imagePath,
          clearImage: mine.imagePath == null,
          updatedAt: remote.updatedAt,
        ),
      );
    }
  }
  for (final mine in local) {
    if (deleted.contains(mine.id) || !seen.add(mine.id)) continue;
    out.add(mine);
  }
  return out;
}

/// مواد اسم واحد داخل قسم واحد: مرساة لكل باركود، وأول مادة بلا باركود
/// والباركود الوحيد الذي رُبطت به.
class _NameGroup {
  final anchors = <String, int>{};
  int? noCode;
  String? linkedCode;
}
