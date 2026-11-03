import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/invoice.dart';
import '../models/medicine.dart';
import '../services/duplicate_dismissals.dart';
import '../services/duplicates.dart';
import '../state/invoice_store.dart';
import '../state/medicine_store.dart';
import '../util/number_parse.dart';
import '../util/money.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../l10n/l10n.dart';

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
    this.invoices,
  });

  final MedicineStore store;

  /// سجل الفواتير لتاريخ فاتورة كل مادة — يُحقن في الاختبار.
  final InvoiceStore? invoices;
  final Future<List<Medicine>> Function()? loadItems;
  final Future<int> Function()? pendingCloudDeletes;

  @override
  State<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends State<DuplicatesScreen> {
  bool _loading = true;
  String? _error;
  List<Medicine> _items = const [];
  int _pending = 0;

  /// المواد المختارة للدمج في كل مجموعة — لا شيء مختار افتراضياً: الاختيار
  /// قرار المستخدم صراحةً، فالمجموعة كثيراً ما تخلط منتجات مختلفة.
  final Map<String, Set<String>> _selectedByGroup = {};

  /// أحدث فاتورة محفوظة لكل مادة.
  Map<String, Invoice> _invoiceOf = const {};

  /// «أسماء متشابهة» — مقارنة أزواج مكلفة نسبياً، فتُحسب خارج واجهة المستخدم
  /// عند التحميل وبعد كل دمج، لا في كل بناء.
  List<DuplicateGroup> _similarAll = const [];

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
      // قرارات «ليست مكرّرة» من كل أجهزة الصيدلية، لا هذا الهاتف وحده
      await DuplicateDismissals.instance.loadLocal();
      await DuplicateDismissals.instance.syncWithCloud();
      final load = widget.loadItems ?? widget.store.itemsForDuplicateReview;
      final pendingFn =
          widget.pendingCloudDeletes ?? widget.store.pendingCloudDeleteCount;
      final items = await load();
      final pending = await pendingFn();
      final invoices = widget.invoices ?? InvoiceStore.instance;
      if (invoices.all.isEmpty) await invoices.load();
      final invoiceOf = invoices.latestInvoiceByMedicine();
      if (!mounted) return;
      final similar = await _findSimilar(items);
      if (!mounted) return;
      setState(() {
        _items = items;
        _similarAll = similar;
        _pending = pending;
        _invoiceOf = invoiceOf;
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
      findDuplicateGroups(_items, dismissed: DuplicateDismissals.instance.keys);

  List<DuplicateGroup> get _similar {
    final dismissed = DuplicateDismissals.instance.keys;
    return [
      for (final g in _similarAll)
        if (!dismissed.contains(g.key)) g,
    ];
  }

  /// المواد الداخلة في مجموعة مؤكّدة تُستبعد — لا تُعرض مرتين.
  static Future<List<DuplicateGroup>> _findSimilar(List<Medicine> items) {
    final exact = {
      for (final g in findDuplicateGroups(items))
        for (final m in g.items) m.id,
    };
    // قائمة صغيرة: كلفة إنشاء عزلة أكبر من المقارنة نفسها
    if (items.length < 300) {
      return Future.value(_similarInIsolate((items, exact)));
    }
    return compute(_similarInIsolate, (items, exact));
  }

  Set<String> _selected(DuplicateGroup g) =>
      _selectedByGroup.putIfAbsent(g.key, () => <String>{});

  static Medicine _newest(Iterable<Medicine> items) =>
      ([...items]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt))).first;

  /// لـ«فصل الباركود»: المادة المختارة إن كانت واحدة، وإلا الأحدث.
  String _keeperOf(DuplicateGroup g) {
    final sel = _selected(g);
    return sel.length == 1 ? sel.first : _newest(g.items).id;
  }

  Future<void> _dismiss(DuplicateGroup g) async {
    await DuplicateDismissals.instance.add(g.key);
    if (mounted) setState(() {});
  }

  /// دمج **المختارة** فقط: نافذة الاسم الباقي والسعر والكمية النهائيين، ثم
  /// غير المختارة تُخفى من المراجعة نهائياً (قرار المستخدم أنها مختلفة).
  Future<void> _merge(DuplicateGroup g) async {
    final selectedIds = _selected(g);
    final selected = [
      for (final m in g.items)
        if (selectedIds.contains(m.id)) m,
    ];
    if (selected.length < 2) return;

    final choice = await showGlassDialog<MergeChoice>(
      context: context,
      builder: (_) => MergeDialog(items: selected),
    );
    if (choice == null || !mounted) return;

    final merged = mergeGroup(
      selected,
      choice.keeperId,
      DateTime.now(),
    ).copyWith(price: choice.price, quantity: choice.quantity);
    final losers = selected.where((m) => m.id != choice.keeperId).toList();

    // عملية واحدة: إن فشلت لا يُحذف شيء ولا تضيع كمية
    try {
      await widget.store.mergeDuplicates(merged, losers);
    } catch (e) {
      if (mounted) _toast('تعذّر الدمج — لم يتغيّر شيء: $e');
      return;
    }
    if (!mounted) return;
    final loserIds = losers.map((m) => m.id).toSet();
    final items = [
      for (final m in _items)
        if (m.id == merged.id) merged else if (!loserIds.contains(m.id)) m,
    ];

    // الباقية + غير المختارة: لا تعود مجموعة منها للمراجعة، على كل الأجهزة
    final survivors = {
      merged.id,
      for (final m in g.items)
        if (!selectedIds.contains(m.id)) m.id,
    };
    // المطابقة الواسعة على المخزون كله (~نصف ثانية على الحاسوب) — خارج
    // واجهة المستخدم كالتحميل، وإلا تجمّدت الشاشة بعد كل دمج
    final toDismiss = items.length < 300
        ? keysToDismissAfterMerge(items, survivors)
        : await compute(_dismissInIsolate, (items, survivors));
    for (final key in toDismiss) {
      await DuplicateDismissals.instance.add(key);
    }

    final similar = await _findSimilar(items);
    if (!mounted) return;
    setState(() {
      _selectedByGroup.remove(g.key);
      _items = items;
      _similarAll = similar;
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
    try {
      for (final m in cleared) {
        await widget.store.save(m);
      }
    } catch (e) {
      if (mounted) _toast('تعذّر فصل الباركود: $e');
      return;
    }
    if (!mounted) return;
    final byId = {for (final m in cleared) m.id: m};
    setState(() => _items = [for (final m in _items) byId[m.id] ?? m]);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.danger),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('🔍 مراجعة التكرارات'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh_rounded),
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
    final similar = _similar;
    final hidden = _hiddenCount;
    if (groups.isEmpty && similar.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('لا توجد تكرارات ✅', style: TextStyle(fontSize: 16)),
            if (hidden > 0) ...[
              const SizedBox(height: 14),
              _showHiddenButton(hidden),
            ],
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_pending > 0) _lockBanner(),
        if (groups.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${groups.length} مجموعة — علّم ما هو نفس المنتج ثم «دمج '
              'المختارة»، أو «ليست مكرّرة» إن كانت كلها منتجات مختلفة.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          for (final g in groups) _groupCard(g),
        ],
        if (similar.isNotEmpty) ...[
          Padding(
            key: const Key('similarSection'),
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              '🔍 أسماء متشابهة — تحقّق قبل الدمج (${similar.length})\n'
              'أسماء متقاربة لا متطابقة: خطأ إملائي، أو كلمة زائدة، أو حجم '
              'وتركيز آخر. كثير منها منتجات مختلفة فعلاً — «ليست مكرّرة» '
              'يخفيها من كل الأجهزة.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          for (final g in similar) _groupCard(g),
        ],
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(child: _showHiddenButton(hidden)),
          ),
      ],
    );
  }

  /// مجموعات مخفية حالياً بقرار «ليست مكرّرة» (أو بدمج جزئي سابق).
  int get _hiddenCount {
    final dismissed = DuplicateDismissals.instance.keys;
    if (dismissed.isEmpty) return 0;
    return findDuplicateGroups(
          _items,
        ).where((g) => dismissed.contains(g.key)).length +
        _similarAll.where((g) => dismissed.contains(g.key)).length;
  }

  Widget _showHiddenButton(int hidden) => OutlinedButton.icon(
    key: const Key('showHidden'),
    onPressed: () => _showHidden(hidden),
    icon: const Text('🙈'),
    label: Text('إظهار المخفية ($hidden)'),
  );

  /// يلغي كل قرارات الإخفاء على كل الأجهزة — المواد نفسها لا تتغيّر.
  Future<void> _showHidden(int hidden) async {
    final ok = await showGlassDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('إظهار المجموعات المخفية'),
        content: Text(
          'ستعود $hidden مجموعة للمراجعة على كل الأجهزة. المواد لا تتغيّر.',
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const Key('confirmShowHidden'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إظهار'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await DuplicateDismissals.instance.clearAll();
    if (mounted) setState(() {});
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
    final selected = _selected(g);
    final total = g.items
        .where((m) => selected.contains(m.id))
        .fold<int>(0, (n, m) => n + m.quantity);
    final locked = _pending > 0;
    final canMerge = !locked && selected.length >= 2;
    return Card(
      key: ValueKey(g.key),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              g.isSimilar
                  ? '🔍 أسماء متشابهة بنسبة ${(g.similarity! * 100).round()}%'
                  : g.byBarcode
                  ? '🏷️ نفس الباركود — قد تكون منتجات مختلفة'
                  : '📝 نفس الاسم في نفس القسم',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: g.byBarcode || g.isSimilar
                    ? AppColors.warning
                    : AppColors.primary,
              ),
            ),
            if (g.differentBarcodes)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '🏷️ باركودان مختلفان — تأكّد أنها ليست حجماً أو نكهة أخرى',
                  key: Key('differentBarcodesNote'),
                  style: TextStyle(fontSize: 12, color: AppColors.warning),
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'علّم المواد التي هي نفس المنتج ثم «دمج المختارة» — غير '
                'المعلّمة تبقى كما هي وتُزال من المراجعة.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
            // الصف المختار بخلفية تيل خفيفة وحدّ (`.radio.on`)
            for (final m in g.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: CheckboxListTile(
                  key: ValueKey('pick-${m.id}'),
                  value: selected.contains(m.id),
                  onChanged: (v) => setState(() {
                    v == true ? selected.add(m.id) : selected.remove(m.id);
                  }),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  tileColor: selected.contains(m.id)
                      ? const Color(0x1A2DD4BF)
                      : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: selected.contains(m.id)
                          ? const Color(0x592DD4BF)
                          : Colors.transparent,
                    ),
                  ),
                  title: Text(
                    m.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _details(m),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                GradientFilled(
                  enabled: canMerge,
                  child: FilledButton.icon(
                    key: ValueKey('merge-${g.key}'),
                    onPressed: canMerge ? () => _merge(g) : null,
                    icon: const Icon(Icons.merge_type_rounded, size: 18),
                    label: Text(
                      selected.length < 2
                          ? 'اختر مادتين للدمج'
                          : 'دمج المختارة (${selected.length}) · الكمية $total',
                    ),
                  ),
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
      'السعر ${formatMoney(m.price)}',
      if (m.expiryDate != null) 'الصلاحية ${_date(m.expiryDate!)}',
      if (m.barcode.isNotEmpty) m.barcode,
      if ((m.company ?? '').trim().isNotEmpty) '🏭 ${m.company!.trim()}',
      ?invoiceLabel(m, _invoiceOf[m.id]),
      'عُدّلت ${_date(m.updatedAt)}',
      m.type.labelIn(context.l10n),
    ];
    return parts.join(' · ');
  }

  static String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

List<DuplicateGroup> _similarInIsolate((List<Medicine>, Set<String>) a) =>
    findSimilarGroups(a.$1, exclude: a.$2);

/// ما اختاره المستخدم في نافذة الدمج.
class MergeChoice {
  const MergeChoice({
    required this.keeperId,
    required this.price,
    required this.quantity,
  });

  final String keeperId;
  final double price;
  final int quantity;
}

/// نافذة الدمج: الاسم الباقي من المختارة، والسعر والكمية النهائيان.
///
/// الكمية الافتراضية مجموع المختارة والسعر سعر الأحدث — لكن المستخدم يكتب
/// النهائي بنفسه (قد يكون جرد الرف غير المجموع، أو سعر إحدى النسخ قديماً).
class MergeDialog extends StatefulWidget {
  const MergeDialog({super.key, required this.items});

  final List<Medicine> items;

  @override
  State<MergeDialog> createState() => _MergeDialogState();
}

class _MergeDialogState extends State<MergeDialog> {
  late String _keeper;
  late final TextEditingController _price;
  late final double _priceSource;
  late final TextEditingController _quantity;

  @override
  void initState() {
    super.initState();
    final byNewest = [...widget.items]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _keeper = byNewest.first.id;
    final price = byNewest
        .map((m) => m.price)
        .firstWhere((p) => p > 0, orElse: () => 0);
    final qty = widget.items.fold<int>(0, (n, m) => n + m.quantity);
    _priceSource = price;
    _price = TextEditingController(text: priceInputText(price));
    _quantity = TextEditingController(text: '$qty');
  }

  @override
  void dispose() {
    _price.dispose();
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final price = priceFromInput(_price.text, originalIqd: _priceSource);
    final qty = parseLocalizedInt(_quantity.text);
    final valid = price != null && price >= 0 && qty != null && qty >= 0;
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: Text('دمج ${widget.items.length} مواد'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الاسم الذي يبقى',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            RadioGroup<String>(
              groupValue: _keeper,
              onChanged: (v) {
                if (v != null) setState(() => _keeper = v);
              },
              child: Column(
                children: [
                  for (final m in widget.items)
                    RadioListTile<String>(
                      key: ValueKey('keep-${m.id}'),
                      value: m.id,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(m.name, style: const TextStyle(fontSize: 13)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('mergePrice'),
              controller: _price,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: InputDecoration(
                labelText: '💰 السعر النهائي (${currencyLabel()})',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('mergeQuantity'),
              controller: _quantity,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '📦 الكمية النهائية',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'تُحذف ${widget.items.length - 1} مادة من هذا الهاتف ومن كل '
              'الأجهزة المشتركة.',
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          key: const Key('mergeSave'),
          onPressed: valid
              ? () => Navigator.pop(
                  context,
                  MergeChoice(keeperId: _keeper, price: price, quantity: qty),
                )
              : null,
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

List<String> _dismissInIsolate((List<Medicine>, Set<String>) a) =>
    keysToDismissAfterMerge(a.$1, a.$2);
