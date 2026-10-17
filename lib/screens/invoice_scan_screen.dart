import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/medicine.dart';
import '../services/gemini_vision.dart';
import '../state/medicine_store.dart';
import '../util/number_parse.dart';
import '../theme.dart';

/// قراءة فاتورة مجهّز بالذكاء الاصطناعي (Gemini) → مراجعة الأسطر مع تحرير
/// كامل → حفظها دفعة واحدة عبر `MedicineStore.saveAll`.
///
/// **يعمل فقط عند وجود مفتاح Gemini في ملف `.env`** — الزر الذي يفتح هذه
/// الشاشة يختفي تلقائياً في `home_screen.dart` عند غياب المفتاح.
class InvoiceScanScreen extends StatefulWidget {
  const InvoiceScanScreen({
    super.key,
    required this.store,
    this.initialType = ItemType.supply,
  });

  final MedicineStore store;

  /// النوع الافتراضي لأسطر الفاتورة — قابل للتغيير في الأعلى بأزرار السطر
  /// أو جماعياً بأداة `_bulkType`.
  final ItemType initialType;

  @override
  State<InvoiceScanScreen> createState() => _InvoiceScanScreenState();
}

class _InvoiceScanScreenState extends State<InvoiceScanScreen> {
  bool _busy = false;
  String? _error;
  List<_EditableLine> _lines = const [];
  File? _preview;

  ItemType _bulkType = ItemType.supply;

  @override
  void initState() {
    super.initState();
    _bulkType = widget.initialType;
    // نبدأ فور الفتح — الكاميرا هي التدفّق الطبيعي
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture(camera: true));
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _capture({required bool camera}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
      _preview = File(picked.path);
    });

    final result = await GeminiVision.readInvoice(_preview!);
    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _busy = false;
        _error = result.error;
      });
      return;
    }

    // نظافة: أفرغ محرّرات الأسطر السابقة قبل استبدالها
    for (final line in _lines) {
      line.dispose();
    }
    setState(() {
      _busy = false;
      _lines = [
        for (final l in result.lines) _EditableLine(source: l, type: _bulkType),
      ];
    });
  }

  /// حذف سطر من المراجعة — الإزالة من الشجرة أولاً، والإتلاف بعد اكتمال
  /// الإطار.
  ///
  /// `dispose()` المباشر داخل `setState` كان يُتلف المحرّرات بينما حقولها
  /// ما زالت مبنيّة في الإطار الحالي (الإزالة الفعلية تحدث في إعادة البناء
  /// التالية). لو كان حقل السطر المحذوف يحمل التركيز، يصل تحديث إدخال معلَّق
  /// من المنصّة إلى محرّر مُتلَف → «A TextEditingController was used after
  /// being disposed» وشاشة حمراء.
  void _removeLine(int index) {
    final removed = _lines[index];
    setState(() => _lines = List.of(_lines)..removeAt(index));
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  void _applyBulkType(ItemType type) {
    setState(() {
      _bulkType = type;
      for (final line in _lines) {
        line.type = type;
      }
    });
  }

  Future<void> _save() async {
    final drafts = <InvoiceLineDraft>[
      for (final line in _lines)
        if (line.name.text.trim().isNotEmpty)
          InvoiceLineDraft(
            name: line.name.text.trim(),
            type: line.type,
            price: parseLocalizedNumber(line.price.text) ?? 0,
            quantity: parseLocalizedInt(line.quantity.text) ?? 0,
            barcode: line.barcode.text.trim(),
            category: _orNull(line.category.text),
          ),
    ];

    final result = buildInvoiceSaveItems(
      drafts: drafts,
      store: widget.store,
      now: DateTime.now(),
    );

    if (result.items.isEmpty) {
      setState(() => _error = 'لا توجد أسطر صالحة للحفظ.');
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.store.saveAll(result.items);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذّر الحفظ: $e';
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  String? _orNull(String s) => s.trim().isEmpty ? null : s.trim();

  /// هل يطابق هذا السطر سجلاً موجوداً مسبقاً في المخزون؟ — للشارة أثناء
  /// المراجعة، قبل أن يضغط المستخدم حفظ.
  Medicine? _existingMatchFor(_EditableLine line) {
    final name = line.name.text.trim();
    if (name.isEmpty) return null;
    return widget.store.findExistingByName(name, line.type);
  }

  /// هل يطابق هذا السطر سطراً آخر في نفس الفاتورة (نفس الاسم بعد التطبيع
  /// ونفس القسم)؟ — للشارة أثناء المراجعة أيضاً.
  bool _duplicatesAnotherLine(_EditableLine line) {
    final name = line.name.text.trim();
    if (name.isEmpty) return false;
    final norm = MedicineStore.normalizeName(name);
    for (final other in _lines) {
      if (identical(other, line)) continue;
      if (other.type != line.type) continue;
      if (MedicineStore.normalizeName(other.name.text.trim()) == norm) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📄 قراءة فاتورة'),
        backgroundColor: AppColors.bgCard,
        actions: [
          if (_lines.isNotEmpty && !_busy)
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check, color: AppColors.success),
              label: Text(
                'حفظ (${_lines.where((l) => l.name.text.trim().isNotEmpty).length})',
                style: const TextStyle(color: AppColors.success),
              ),
            ),
        ],
      ),
      body: _busy ? _busyView() : _mainView(),
      bottomNavigationBar: _lines.isEmpty && !_busy
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _capture(camera: true),
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('كاميرا'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _capture(camera: false),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('معرض'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _busyView() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          _preview == null ? 'جاري تحضير الكاميرا…' : 'جاري قراءة الفاتورة…',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    ),
  );

  Widget _mainView() {
    if (_lines.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📸', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 12),
            const Text(
              'صوّر الفاتورة أو اخترها من المعرض',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'تُقرأ الأسطر تلقائياً بالذكاء الاصطناعي وتظهر لك للمراجعة قبل الحفظ.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        _bulkHeader(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            itemCount: _lines.length,
            itemBuilder: (_, i) => _lineCard(i),
          ),
        ),
      ],
    );
  }

  Widget _bulkHeader() => Container(
    color: AppColors.bgCard,
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    child: Row(
      children: [
        const Text('نوع كل الأسطر:', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 10),
        Expanded(
          child: SegmentedButton<ItemType>(
            segments: [
              for (final t in ItemType.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {_bulkType},
            showSelectedIcon: false,
            onSelectionChanged: (s) => _applyBulkType(s.first),
          ),
        ),
      ],
    ),
  );

  Widget _lineCard(int i) {
    final line = _lines[i];
    return Card(
      // مفتاح مرتبط بهوية السطر نفسه: بلاه يُعيد ListView تدوير العنصر بعد
      // الحذف فيربط حقول السطر التالي بحالة السطر المحذوف (تركيز ولوحة
      // مفاتيح تشير إلى حقل لم يعد موجوداً).
      key: ObjectKey(line),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _typeChip(line)),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppColors.danger,
                  ),
                  onPressed: () => _removeLine(i),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: line.name,
              decoration: const InputDecoration(labelText: 'الاسم'),
            ),
            // شارتا تنبيه تتحدّثان حيّاً مع تعديل أي اسم — نستمع لكل أسماء
            // الأسطر معاً (لا اسم هذا السطر وحده) لأن «مكرر مع سطر آخر»
            // تعتمد على تغيّر السطر الآخر أيضاً، لا هذا السطر فقط.
            ListenableBuilder(
              listenable: Listenable.merge([for (final l in _lines) l.name]),
              builder: (context, _) => _duplicateBadges(line),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: line.price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'السعر (كلفة)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: line.quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'الكمية'),
                  ),
                ),
              ],
            ),
            if (line.type == ItemType.supply) ...[
              const SizedBox(height: 6),
              TextField(
                controller: line.category,
                decoration: const InputDecoration(
                  labelText: '🧪 نوع المادة (اختياري)',
                ),
              ),
            ],
            const SizedBox(height: 6),
            TextField(
              controller: line.barcode,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الباركود (اختياري)',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// شارتا التنبيه: «موجودة مسبقاً» (كهرمانية) و«مكررة داخل هذه الفاتورة»
  /// (زرقاء) — تظهران فقط عند الحاجة، جنباً إلى جنب إن انطبقتا معاً.
  Widget _duplicateBadges(_EditableLine line) {
    final existing = _existingMatchFor(line);
    final duplicatesOther = _duplicatesAnotherLine(line);
    if (existing == null && !duplicatesOther) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          if (existing != null)
            _badge(
              '🔁 موجودة مسبقاً — الرصيد الحالي ${existing.quantity}، سيُضاف الوارد إليه',
              AppColors.warning,
            ),
          if (duplicatesOther)
            _badge(
              '🔗 مكرر مع سطر آخر في هذه الفاتورة — سيُدمجان تلقائياً',
              AppColors.primary,
            ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(text, style: TextStyle(fontSize: 10.5, color: color)),
  );

  Widget _typeChip(_EditableLine line) => Wrap(
    spacing: 6,
    children: [
      for (final t in ItemType.values)
        ChoiceChip(
          label: Text(t.label, style: const TextStyle(fontSize: 11)),
          selected: line.type == t,
          onSelected: (_) => setState(() => line.type = t),
          selectedColor: AppColors.primary.withValues(alpha: 0.25),
          backgroundColor: AppColors.bgDark,
          showCheckmark: false,
        ),
    ],
  );
}

/// بيانات سطر فاتورة جاهزة للحفظ — منفصلة عن `TextEditingController` حتى
/// يُختبر منطق الدمج في [buildInvoiceSaveItems] بمعزل تام عن الواجهة.
class InvoiceLineDraft {
  const InvoiceLineDraft({
    required this.name,
    required this.type,
    this.price = 0,
    this.quantity = 0,
    this.barcode = '',
    this.category,
  });

  final String name;
  final ItemType type;
  final double price;
  final int quantity;
  final String barcode;
  final String? category;
}

/// نتيجة حفظ فاتورة — تُستعمل لعرض ملخّص صادق للمستخدم بدل عدّاد مبهم لا
/// يميّز مادة جديدة من مادة دُمجت مع مخزون موجود.
class InvoiceSaveResult {
  const InvoiceSaveResult({
    required this.items,
    required this.addedNew,
    required this.mergedExisting,
    required this.mergedWithinInvoice,
  });

  final List<Medicine> items;

  /// مواد جديدة تماماً لم تكن موجودة من قبل.
  final int addedNew;

  /// مواد دُمجت مع سجل كان موجوداً مسبقاً في المخزون (كمية أُضيفت لرصيد قائم).
  final int mergedExisting;

  /// كم سطراً من أسطر الفاتورة نفسها كان مكرَّراً (نفس الاسم والقسم) ودُمج
  /// مع سطر آخر في نفس الفاتورة قبل مقارنته بالمخزون أصلاً.
  final int mergedWithinInvoice;
}

/// يدمج أسطر الفاتورة المكرَّرة (نفس الاسم بعد التطبيع + نفس القسم) ضمن
/// الفاتورة نفسها **قبل** مقارنتها بالمخزون المحفوظ، ثم يقارن كل مادة مُدمَجة
/// مرة واحدة فقط بـ[MedicineStore.findExistingByName].
///
/// **لماذا هذا ضروري:** بدون الدمج المسبق، كل سطر يُقارَن بالمخزون المحفوظ
/// وحده بمعزل عن بقية أسطر نفس الفاتورة. مادتان بنفس الاسم في فاتورة واحدة
/// كانتا تُنتجان إما سجلّين منفصلين مرئيّين (إن كانت المادة جديدة كلياً)، أو
/// أسوأ من ذلك: سجلّين بنفس `id` بكميتين مختلفتين إن كانتا تطابقان سجلاً
/// موجوداً سلفاً — فيُبقي `saveAll` (عبر `ConflictAlgorithm.replace`) الأخير
/// فقط وتضيع كمية السطر الآخر بصمت. الدمج هنا يقع مرة واحدة قبل أي من ذلك.
///
/// دالة صِرفة بلا أي اعتماد على الواجهة — قابلة للاختبار مباشرة بمخزن مزيَّف.
@visibleForTesting
InvoiceSaveResult buildInvoiceSaveItems({
  required List<InvoiceLineDraft> drafts,
  required MedicineStore store,
  required DateTime now,
}) {
  // مرحلة 1: دمج التكرار داخل الفاتورة نفسها بمفتاح (نوع + اسم مُطبَّع).
  // الترتيب الأصلي (`order`) يُحفَظ حتى يبقى ظهور المواد في نفس تسلسل الفاتورة.
  final byKey = <String, InvoiceLineDraft>{};
  final mergedWithinFlags = <String, bool>{};
  final order = <String>[];

  for (final d in drafts) {
    if (d.name.trim().isEmpty) continue;
    final key = '${d.type.name}::${MedicineStore.normalizeName(d.name)}';
    final prev = byKey[key];
    if (prev == null) {
      byKey[key] = d;
      order.add(key);
    } else {
      byKey[key] = InvoiceLineDraft(
        name: prev.name,
        type: prev.type,
        price: d.price > 0 ? d.price : prev.price,
        quantity: prev.quantity + d.quantity,
        barcode: prev.barcode.isNotEmpty ? prev.barcode : d.barcode,
        category: prev.category ?? d.category,
      );
      mergedWithinFlags[key] = true;
    }
  }

  // مرحلة 2: مقارنة كل سطر مُدمَج (مرة واحدة) بالمخزون المحفوظ فعلياً.
  var addedNew = 0;
  var mergedExisting = 0;
  var mergedWithinInvoice = 0;
  final items = <Medicine>[];

  for (final key in order) {
    final d = byKey[key]!;
    if (mergedWithinFlags[key] == true) mergedWithinInvoice++;

    final existing = store.findExistingByName(d.name, d.type);
    final ts = now.millisecondsSinceEpoch;
    if (existing != null) {
      mergedExisting++;
      items.add(
        existing.copyWith(
          price: d.price > 0 ? d.price : existing.price,
          quantity: existing.quantity + d.quantity,
          type: d.type,
          category: d.type == ItemType.supply ? d.category : null,
          clearCategory: d.type != ItemType.supply,
          updatedAt: ts,
        ),
      );
    } else {
      addedNew++;
      items.add(
        Medicine(
          id: 'inv_${ts}_${now.microsecond}_${items.length}',
          barcode: d.barcode,
          name: d.name,
          price: d.price,
          quantity: d.quantity,
          type: d.type,
          category: d.type == ItemType.supply ? d.category : null,
          createdAt: ts,
          updatedAt: ts,
        ),
      );
    }
  }

  return InvoiceSaveResult(
    items: items,
    addedNew: addedNew,
    mergedExisting: mergedExisting,
    mergedWithinInvoice: mergedWithinInvoice,
  );
}

/// حاوية محرّرات سطر واحد — عمرها بعمر الشاشة، تُتلَف عند الاستبدال أو الخروج.
class _EditableLine {
  _EditableLine({required InvoiceLine source, required this.type})
    : name = TextEditingController(text: source.name),
      price = TextEditingController(
        text: source.price == null ? '' : _num(source.price!),
      ),
      quantity = TextEditingController(
        text: source.quantity == null ? '' : source.quantity!.toString(),
      ),
      barcode = TextEditingController(text: source.barcode ?? ''),
      category = TextEditingController(text: source.category ?? '');

  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController quantity;
  final TextEditingController barcode;
  final TextEditingController category;
  ItemType type;

  void dispose() {
    name.dispose();
    price.dispose();
    quantity.dispose();
    barcode.dispose();
    category.dispose();
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
