import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medicine.dart';
import '../services/duplicates.dart';
import '../state/medicine_store.dart';
import '../theme.dart';

/// مراجعة المواد المكرّرة ودمجها.
///
/// المصدر هو السحابة لا الهاتف: الفهرس الفريد على الباركود يُبقي محلياً مادة
/// واحدة من كل مجموعة باركود مكرّر، والبقية لا تُرى إلا في السحابة.
class DuplicatesScreen extends StatefulWidget {
  const DuplicatesScreen({
    super.key,
    required this.store,
    this.loadItems,
    this.pendingCloudDeletes,
  });

  final MedicineStore store;
  final Future<List<Medicine>> Function()? loadItems;
  final Future<int> Function()? pendingCloudDeletes;

  @override
  State<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends State<DuplicatesScreen> {
  static const _kDismissed = 'dismissed_duplicate_groups';

  bool _loading = true;
  String? _error;
  List<Medicine> _items = const [];
  Set<String> _dismissed = {};
  int _pending = 0;
  final Map<String, String> _keeperByGroup = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final load = widget.loadItems ?? widget.store.itemsForDuplicateReview;
      final pendingFn =
          widget.pendingCloudDeletes ?? widget.store.pendingCloudDeleteCount;
      final items = await load();
      final pending = await pendingFn();
      if (!mounted) return;
      setState(() {
        _items = items;
        _pending = pending;
        _dismissed = (prefs.getStringList(_kDismissed) ?? const []).toSet();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل المواد: $e';
      });
    }
  }

  List<DuplicateGroup> get _groups =>
      findDuplicateGroups(_items, dismissed: _dismissed);

  String _keeperOf(DuplicateGroup g) =>
      _keeperByGroup[g.key] ??
      (([
        ...g.items,
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt))).first.id);

  Future<void> _dismiss(DuplicateGroup g) async {
    final prefs = await SharedPreferences.getInstance();
    final next = {..._dismissed, g.key};
    await prefs.setStringList(_kDismissed, next.toList());
    if (!mounted) return;
    setState(() => _dismissed = next);
  }

  Future<void> _merge(DuplicateGroup g) async {
    final keeperId = _keeperOf(g);
    final merged = mergeGroup(g.items, keeperId, DateTime.now());
    final losers = g.items.where((m) => m.id != keeperId).toList();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('دمج المواد'),
        content: Text(
          'ستبقى «${merged.name}» بكمية ${merged.quantity}، وتُحذف '
          '${losers.length} مادة أخرى من هذا الهاتف ومن كل الأجهزة المشتركة.',
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ادمج'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // الحذف قبل الحفظ: يُحرّر الباركود من المادة المحذوفة محلياً قبل أن تحمله
    // المادة الباقية، فلا يصطدم بالفهرس الفريد.
    for (final m in losers) {
      // صورة انتقلت للمادة الباقية لا تُحذف مع صاحبتها الأصلية
      await widget.store.delete(
        m,
        keepImage: m.imagePath != null && m.imagePath == merged.imagePath,
      );
    }
    await widget.store.save(merged);
    if (!mounted) return;
    setState(() {
      final loserIds = losers.map((m) => m.id).toSet();
      _items = [
        for (final m in _items)
          if (m.id == merged.id) merged else if (!loserIds.contains(m.id)) m,
      ];
    });
  }

  /// يُبقي الباركود على المادة المختارة ويمسحه من البقية — لمجموعات منتجات
  /// مختلفة نسبت إليها فاتورة باركوداً واحداً خاطئاً.
  Future<void> _splitBarcode(DuplicateGroup g) async {
    final keeperId = _keeperOf(g);
    final now = DateTime.now().millisecondsSinceEpoch;
    final cleared = [
      for (final m in g.items)
        if (m.id != keeperId && m.barcode.isNotEmpty)
          m.copyWith(barcode: '', updatedAt: now),
    ];
    for (final m in cleared) {
      await widget.store.save(m);
    }
    if (!mounted) return;
    final byId = {for (final m in cleared) m.id: m};
    setState(() => _items = [for (final m in _items) byId[m.id] ?? m]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔍 مراجعة التكرارات'),
        backgroundColor: AppColors.bgCard,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
      );
    }
    final groups = _groups;
    if (groups.isEmpty) {
      return const Center(
        child: Text('لا توجد تكرارات ✅', style: TextStyle(fontSize: 16)),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_pending > 0) _lockBanner(),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${groups.length} مجموعة — اختر المادة التي تبقى ثم «دمج»، أو '
            '«ليست مكرّرة» إن كانت منتجات مختلفة.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
        for (final g in groups) _groupCard(g),
      ],
    );
  }

  Widget _lockBanner() => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
    ),
    child: Text(
      'الدمج متوقف: $_pending عملية حذف لم تصل للسحابة بعد. الدمج يجمع '
      'الكميات ويحذف الباقي، فإن لم يصل الحذف تبقى المواد على الهاتف الآخر '
      'وتتضاعف الكمية. اتصل بالإنترنت ثم اضغط تحديث.',
      style: const TextStyle(fontSize: 12, height: 1.6),
    ),
  );

  Widget _groupCard(DuplicateGroup g) {
    final keeper = _keeperOf(g);
    final total = g.items.fold<int>(0, (n, m) => n + m.quantity);
    final locked = _pending > 0;
    return Card(
      key: ValueKey(g.key),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              g.byBarcode
                  ? '🏷️ نفس الباركود — قد تكون منتجات مختلفة'
                  : '📝 نفس الاسم في نفس القسم',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: g.byBarcode ? AppColors.warning : AppColors.primary,
              ),
            ),
            RadioGroup<String>(
              groupValue: keeper,
              onChanged: (v) {
                if (v != null) setState(() => _keeperByGroup[g.key] = v);
              },
              child: Column(
                children: [
                  for (final m in g.items)
                    RadioListTile<String>(
                      value: m.id,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(m.name),
                      subtitle: Text(_details(m)),
                    ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                FilledButton.icon(
                  onPressed: locked ? null : () => _merge(g),
                  icon: const Icon(Icons.merge_type, size: 18),
                  label: Text('دمج (الكمية $total)'),
                ),
                OutlinedButton(
                  onPressed: () => _dismiss(g),
                  child: const Text('ليست مكرّرة'),
                ),
                if (g.byBarcode)
                  OutlinedButton(
                    onPressed: () => _splitBarcode(g),
                    child: const Text('فصل الباركود'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _details(Medicine m) {
    final parts = <String>[
      'الكمية ${m.quantity}',
      'السعر ${_num(m.price)}',
      if (m.expiryDate != null) 'الصلاحية ${_date(m.expiryDate!)}',
      if (m.barcode.isNotEmpty) m.barcode,
      'عُدّلت ${_date(m.updatedAt)}',
      m.type.label,
    ];
    return parts.join(' · ');
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}/${d.month}/${d.day}';
  }
}
