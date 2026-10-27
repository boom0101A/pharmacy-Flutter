import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../db/medicine_db.dart';
import '../models/invoice.dart';
import '../services/image_store.dart';
import '../services/sync_service.dart';

/// سجل فواتير المجهّزين: محلي أولاً (sqflite)، والسحابة للمشاركة بين أجهزة
/// الصيدلية. صور الصفحات محلية فقط.
class InvoiceStore extends ChangeNotifier {
  InvoiceStore({
    Future<List<Invoice>> Function()? loadAll,
    Future<void> Function(Invoice)? write,
    Future<void> Function(String id)? remove,
    Future<String> Function(File page)? savePage,
    Future<void> Function(String fileName)? deletePage,
    Future<void> Function(Invoice)? push,
    Future<void> Function(String id)? pushDelete,
  }) : _loadAll = loadAll ?? MedicineDb.instance.allInvoices,
       _write = write ?? MedicineDb.instance.upsertInvoice,
       _remove = remove ?? MedicineDb.instance.deleteInvoice,
       _savePage = savePage ?? ImageStore.saveInvoicePage,
       _deletePage = deletePage ?? ImageStore.deleteInvoicePage,
       _push = push ?? SyncService.instance.pushInvoice,
       _pushDelete = pushDelete ?? SyncService.instance.deleteInvoice;

  static final InvoiceStore instance = InvoiceStore();

  final Future<List<Invoice>> Function() _loadAll;
  final Future<void> Function(Invoice) _write;
  final Future<void> Function(String id) _remove;
  final Future<String> Function(File page) _savePage;
  final Future<void> Function(String fileName) _deletePage;
  final Future<void> Function(Invoice) _push;
  final Future<void> Function(String id) _pushDelete;

  List<Invoice> _all = const [];
  bool _loaded = false;

  /// الأحدث تاريخاً أولاً.
  List<Invoice> get all => _all;
  int get count => _all.length;

  Future<void> load() async {
    try {
      _all = await _loadAll();
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('تعذّر تحميل الفواتير: $e');
    }
  }

  Future<void> _ensureLoaded() async {
    if (!_loaded) await load();
  }

  /// يحفظ فاتورة جديدة: الصفحات تُنسخ مصغّرة إلى مجلد الفواتير، ثم السجل
  /// محلياً، ثم السحابة بلا انتظار.
  Future<Invoice> add(Invoice invoice, List<File> pages) async {
    await _ensureLoaded();
    final names = <String>[];
    for (final page in pages) {
      try {
        names.add(await _savePage(page));
      } catch (e) {
        // صفحة لم تُنسخ لا تُسقط السجل — الرأس والأسطر هي الأهم
        debugPrint('تعذّر حفظ صفحة فاتورة: $e');
      }
    }
    final saved = invoice.copyWith(imageFiles: names);
    await _write(saved);
    _all = [saved, ..._all.where((i) => i.id != saved.id)]
      ..sort((a, b) => b.sortDate.compareTo(a.sortDate));
    notifyListeners();
    unawaited(_push(saved));
    return saved;
  }

  /// يحذف السجل وصوره المحلية فقط — المخزون لا يتغيّر (قرار المستخدم).
  Future<void> delete(Invoice invoice) async {
    await _remove(invoice.id);
    for (final f in invoice.imageFiles) {
      unawaited(_deletePage(f).catchError((_) {}));
    }
    _all = _all.where((i) => i.id != invoice.id).toList();
    notifyListeners();
    unawaited(_pushDelete(invoice.id));
  }

  /// مزامنة مع السحابة — تُستدعى ضمن دورة تحديث المخزون. لا ترمي.
  Future<void> sync({bool manual = false}) async {
    await _ensureLoaded();
    final merged = await SyncService.instance.syncInvoices(
      _all,
      manual: manual,
    );
    if (merged == null) return;
    final before = {for (final i in _all) i.id: i.updatedAt};
    final gone = {for (final i in _all) i.id}
      ..removeAll(merged.map((i) => i.id));
    // ما تغيّر فقط — كتابة كل الفواتير في كل دورة تكبر مع السجل
    for (final inv in merged) {
      if (before[inv.id] != inv.updatedAt) await _write(inv);
    }
    for (final old in _all.where((i) => gone.contains(i.id))) {
      await _remove(old.id);
      for (final f in old.imageFiles) {
        unawaited(_deletePage(f).catchError((_) {}));
      }
    }
    _all = merged;
    notifyListeners();
  }

  /// لكل مادة في المخزون: أحدث فاتورة محفوظة ورد فيها سطرها.
  Map<String, Invoice> latestInvoiceByMedicine() {
    final out = <String, Invoice>{};
    for (final inv in _all) {
      for (final line in inv.lines) {
        final id = line.medicineId;
        if (id == null) continue;
        final prev = out[id];
        if (prev == null || inv.sortDate > prev.sortDate) out[id] = inv;
      }
    }
    return out;
  }

  /// استرجاع من نسخة احتياطية: يضيف الغائب ويحدّث الأقدم، ولا يحذف شيئاً.
  /// صور هذا الهاتف (إن وُجدت) تبقى. يُرجع عدد ما أُضيف أو حُدّث.
  Future<int> importAll(List<Invoice> incoming) async {
    await _ensureLoaded();
    final byId = {for (final i in _all) i.id: i};
    var changed = 0;
    for (final inv in incoming) {
      final mine = byId[inv.id];
      if (mine != null && mine.updatedAt >= inv.updatedAt) continue;
      final next = inv.copyWith(imageFiles: mine?.imageFiles ?? const []);
      await _write(next);
      byId[inv.id] = next;
      unawaited(_push(next));
      changed++;
    }
    _all = byId.values.toList()
      ..sort((a, b) => b.sortDate.compareTo(a.sortDate));
    notifyListeners();
    return changed;
  }

  @visibleForTesting
  void seed(List<Invoice> items) {
    _all = [...items]..sort((a, b) => b.sortDate.compareTo(a.sortDate));
    _loaded = true;
    notifyListeners();
  }
}
