import '../models/medicine.dart';

/// معرّفات في طابور الحذف هي أثر تعارض باركود لا حذف حقيقي من المستخدم:
/// ما زالت في السحابة ولها توأم سحابي بنفس الباركود.
///
/// نسخة 2026-10-17 الأولى كانت تُدرج خاسر كل تعارض في الطابور فتحاول حذف
/// مخزون حقيقي من السحابة. هذه الدالة تتعرّف عليها لتُزال من الطابور.
Set<String> conflictArtifactIds(
  Iterable<String> pendingDeletes,
  Map<String, Medicine> remoteById,
) {
  final countByBarcode = <String, int>{};
  for (final m in remoteById.values) {
    if (m.barcode.isEmpty) continue;
    countByBarcode[m.barcode] = (countByBarcode[m.barcode] ?? 0) + 1;
  }
  return {
    for (final id in pendingDeletes)
      if (remoteById[id] case final m?
          when m.barcode.isNotEmpty && (countByBarcode[m.barcode] ?? 0) > 1)
        id,
  };
}
