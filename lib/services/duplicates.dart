import 'package:flutter/foundation.dart';

import '../models/medicine.dart';
import '../state/medicine_store.dart';
import 'gs1_parser.dart';

/// مجموعة مواد يُشتبه أنها نفس المادة مكرّرة.
class DuplicateGroup {
  DuplicateGroup(this.items, {required this.byBarcode, this.similarity});

  final List<Medicine> items;

  /// تجمّعت (جزئياً على الأقل) بباركود مشترك — قد تكون منتجات مختلفة
  /// نسبت إليها الفاتورة باركوداً خاطئاً، لا تكراراً حقيقياً.
  final bool byBarcode;

  /// نسبة التشابه (0-1) لمجموعة «أسماء متشابهة»، وnull للمؤكّدة.
  final double? similarity;

  bool get isSimilar => similarity != null;

  /// مفتاح ثابت لا يتغيّر بترتيب المواد — يُحفظ عند «ليست مكرّرة».
  /// المتشابهة بمفتاح مستقل حتى لا يُخفي قرارُها مجموعة مؤكّدة بنفس المواد.
  String get key =>
      '${isSimilar ? 'sim:' : ''}'
      '${(items.map((m) => m.id).toList()..sort()).join('|')}';
}

/// أقصى حجم لمجموعة متشابهة — أكبر من ذلك تصير المراجعة متعبة وغير دقيقة.
const _maxSimilarGroup = 6;

/// مواد بأسماء متقاربة لا متطابقة: خطأ إملائي بحرف أو حرفين، أو اسم ناقص
/// كلمة («Panadol Extra» / «Panadol Extra Tab»)، أو تركيز/حجم آخر — قرار
/// المستخدم أن تُعرض كلها ويقرّر هو. اقتراحات لا يقين: تظهر في قسم منفصل
/// ولا يعدّها شريط الرئيسية.
///
/// - النوع نفسه فقط، ولا زوج بباركودين صالحين مختلفين (صنفان مؤكّدان).
/// - [exclude]: معرّفات في مجموعات مؤكّدة — لا تُعرض مرتين.
/// - المقارنة داخل «كتلة» أول 3 حروف من أول كلمة فقط: ~670 دواء تعني 224
///   ألف زوج بلا تقسيم؛ خطأ إملائي في أول 3 حروف نادر ويُفوَّت.
List<DuplicateGroup> findSimilarGroups(
  List<Medicine> items, {
  Set<String> dismissed = const {},
  Set<String> exclude = const {},
}) {
  final pool = [
    for (final m in items)
      if (!exclude.contains(m.id)) m,
  ];
  final keys = [for (final m in pool) similarityKey(m.name)];
  final codes = [for (final m in pool) Gs1Parser.canonicalKey(m.barcode)];

  final blocks = <String, List<int>>{};
  for (var i = 0; i < pool.length; i++) {
    final k = keys[i];
    if (k.length < 3) continue;
    final first = k.split(' ').first;
    final head = first.length < 3 ? first : first.substring(0, 3);
    (blocks['${pool[i].type.name}::$head'] ??= []).add(i);
  }

  final parent = List<int>.generate(pool.length, (i) => i);
  final size = List<int>.filled(pool.length, 1);
  final best = List<double>.filled(pool.length, 0);
  int find(int i) {
    while (parent[i] != i) {
      parent[i] = parent[parent[i]];
      i = parent[i];
    }
    return i;
  }

  for (final idx in blocks.values) {
    for (var a = 0; a < idx.length; a++) {
      for (var b = a + 1; b < idx.length; b++) {
        final i = idx[a], j = idx[b];
        if (keys[i] == keys[j]) continue; // متطابقة: شأن المجموعات المؤكّدة
        final ci = codes[i], cj = codes[j];
        if (ci != null && cj != null && ci != cj) continue;
        final score = nameSimilarity(keys[i], keys[j]);
        if (score == 0) continue;
        final ri = find(i), rj = find(j);
        if (ri == rj) {
          if (score > best[ri]) best[ri] = score;
          continue;
        }
        if (size[ri] + size[rj] > _maxSimilarGroup) continue;
        parent[ri] = rj;
        size[rj] += size[ri];
        best[rj] = [best[ri], best[rj], score].reduce((x, y) => x > y ? x : y);
      }
    }
  }

  final groups = <int, List<int>>{};
  for (var i = 0; i < pool.length; i++) {
    (groups[find(i)] ??= []).add(i);
  }
  final out = [
    for (final e in groups.entries)
      if (e.value.length > 1)
        DuplicateGroup(
          [for (final i in e.value) pool[i]],
          byBarcode: false,
          similarity: best[e.key],
        ),
  ].where((g) => !dismissed.contains(g.key)).toList();
  out.sort((a, b) => b.similarity!.compareTo(a.similarity!));
  return out;
}

/// الاسم للمقارنة: صغير، بلا ترقيم ولا أقواس، ومسافات موحّدة.
@visibleForTesting
String similarityKey(String name) => MedicineStore.normalizeName(
  name.replaceAll(
    RegExp(
      r'[()\[\]{},.\-_/+*«»"'
      "'"
      r']',
    ),
    ' ',
  ),
);

/// تشابه اسمين مطبَّعين (0 = غير متشابهين):
/// - حرفي ≥ 0.85 (مسافة Levenshtein) — خطأ إملائي بحرف أو حرفين.
/// - أو كل كلمات الأقصر موجودة في الأطول («panadol extra» ⊂ «panadol extra
///   tab»)، بشرط أن يكون الأقصر مميِّزاً: كلمتان، أو كلمة من 5 أحرف فأكثر —
///   وإلا طابقت «gel» كل جل في المخزون.
@visibleForTesting
double nameSimilarity(String a, String b) {
  final longest = a.length > b.length ? a.length : b.length;
  if (longest == 0) return 0;
  final ratio = 1 - _levenshtein(a, b) / longest;
  if (ratio >= .85) return ratio;

  final ta = a.split(' ').where((w) => w.length >= 2).toSet();
  final tb = b.split(' ').where((w) => w.length >= 2).toSet();
  final (short, long) = ta.length <= tb.length ? (ta, tb) : (tb, ta);
  final distinctive =
      short.length >= 2 || (short.length == 1 && short.first.length >= 5);
  if (distinctive && long.containsAll(short)) {
    return short.length / long.length * .9 + .05;
  }
  return 0;
}

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (j) => j);
  var cur = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final del = prev[j] + 1, ins = cur[j - 1] + 1, sub = prev[j - 1] + cost;
      cur[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
    }
    final t = prev;
    prev = cur;
    cur = t;
  }
  return prev[b.length];
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
