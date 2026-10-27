import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../db/medicine_db.dart' show BarcodeConflictException;
import '../models/medicine.dart';
import '../services/duplicates.dart';
import '../services/gs1_parser.dart';
import '../services/image_store.dart';
import '../services/product_cropper.dart';
import '../services/product_image_picker.dart';
import '../state/medicine_store.dart';
import '../theme.dart';
import '../util/number_parse.dart';
import '../widgets/glass.dart';
import '../widgets/medicine_card.dart' show formatPrice;
import '../widgets/smooth_route.dart';
import 'scanner_screen.dart';

/// «إكمال البيانات»: المواد الناقصة (بلا سعر أو بلا باركود) مادةً تلو الأخرى.
///
/// كثير منها تسجيلات أُنشئت بالمسح في الأيام الأولى ولم تُسعَّر، وبعضها نسخ
/// فارغة لدواء مسعّر باسم أكمل — لذا تُعرض «مادة مشابهة» مع زر دمج.
class CompleteDataScreen extends StatefulWidget {
  const CompleteDataScreen({
    super.key,
    required this.store,
    required this.type,
    this.scanBarcode,
    this.pickImagePath,
    this.cropper = const ProductCropper(),
  });

  final MedicineStore store;
  final ItemType type;

  /// بدائل للاختبارات.
  final Future<String?> Function()? scanBarcode;
  final PickImagePath? pickImagePath;
  final ProductCropper cropper;

  @override
  State<CompleteDataScreen> createState() => _CompleteDataScreenState();
}

class _CompleteDataScreenState extends State<CompleteDataScreen> {
  /// القائمة تُلتقط عند الفتح — ما يكتمل أو يُتخطّى لا يعود في الجلسة نفسها.
  late final List<String> _queue;
  int _index = 0;
  int _done = 0;
  bool _busy = false;

  final _price = TextEditingController();
  final _quantity = TextEditingController();
  final _barcode = TextEditingController();
  bool _noBarcode = false;
  String? _image;
  int? _expiry;

  @override
  void initState() {
    super.initState();
    _queue = [for (final m in widget.store.incompleteItems(widget.type)) m.id];
    _loadCurrent();
  }

  @override
  void dispose() {
    _price.dispose();
    _quantity.dispose();
    _barcode.dispose();
    super.dispose();
  }

  Medicine? get _current {
    while (_index < _queue.length) {
      final id = _queue[_index];
      for (final m in widget.store.all) {
        if (m.id == id) return m;
      }
      _index++; // حُذفت أو دُمجت من مكان آخر
    }
    return null;
  }

  void _loadCurrent() {
    final m = _current;
    if (m == null) return;
    _price.text = m.price > 0 ? _num(m.price) : '';
    _quantity.text = m.quantity > 0 ? '${m.quantity}' : '';
    _barcode.text = m.barcode;
    _noBarcode = m.noBarcode;
    _image = m.imagePath;
    _expiry = m.expiryDate;
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  void _next({bool completed = false}) {
    setState(() {
      if (completed) _done++;
      _index++;
      _loadCurrent();
    });
  }

  /// المقارنة تمر على كل مواد القسم — تُحسب مرة لكل مادة لا مع كل بناء
  /// (كل حرف في حقل الباركود يعيد البناء).
  final _similarCache = <String, DuplicateGroup?>{};

  DuplicateGroup? _similarFor(Medicine m) =>
      _similarCache.putIfAbsent(m.id, () => _computeSimilar(m));

  /// أقرب مادة **مسعّرة** في القسم نفسه — النسخة الحقيقية لهذه المادة غالباً.
  DuplicateGroup? _computeSimilar(Medicine m) {
    final candidates = [
      m,
      for (final o in widget.store.all)
        // المسعّرة لا «المكتملة»: النسخة الحقيقية قد تنقصها الباركود وحده،
        // وهي بالضبط ما يحمله التسجيل الفارغ
        if (o.id != m.id && o.type == m.type && o.price > 0) o,
    ];
    final groups = findSimilarGroups(candidates);
    for (final g in groups) {
      if (g.items.any((x) => x.id == m.id)) return g;
    }
    return null;
  }

  Future<void> _scan() async {
    final code =
        await (widget.scanBarcode?.call() ??
            Navigator.of(context).push<String>(
              SmoothPageRoute(builder: (_) => const ScannerScreen()),
            ));
    if (code == null || code.trim().isEmpty || !mounted) return;
    final parsed = Gs1Parser.parse(code);
    setState(() {
      _barcode.text = parsed.barcode;
      _noBarcode = false;
      _expiry ??= parsed.expiryDate?.millisecondsSinceEpoch;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final saved = await pickProductImage(
      context,
      source,
      cropper: widget.cropper,
      pickImagePath: widget.pickImagePath,
    );
    if (saved != null && mounted) setState(() => _image = saved);
  }

  Future<void> _save(Medicine m) async {
    if (_busy) return;
    final price = parseLocalizedNumber(_price.text) ?? 0;
    final qty = parseLocalizedInt(_quantity.text) ?? 0;
    final updated = m.copyWith(
      price: price < 0 ? 0 : price,
      quantity: qty < 0 ? 0 : qty,
      barcode: _barcode.text.trim(),
      noBarcode: _barcode.text.trim().isEmpty && _noBarcode,
      imagePath: _image,
      clearImage: _image == null,
      expiryDate: _expiry,
      clearExpiry: _expiry == null,
    );
    setState(() => _busy = true);
    try {
      await widget.store.save(updated);
    } on BarcodeConflictException {
      _toast('هذا الباركود مسجّل لمادة أخرى — استعمل «دمج» إن كانت هي نفسها');
      return;
    } catch (e) {
      _toast('تعذّر الحفظ: $e');
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    _next(completed: !updated.isIncomplete);
  }

  Future<void> _merge(Medicine m, Medicine into) async {
    final merged = mergeGroup([into, m], into.id, DateTime.now());
    final ok = await _confirm(
      'دمج مع «${into.name}»',
      'تبقى «${into.name}» بكمية ${merged.quantity}، وتُحذف «${m.name}» من كل '
          'الأجهزة. ينتقل إليها الباركود والصورة إن لم يكونا لها.',
      'ادمج',
    );
    if (ok != true) return;
    try {
      await widget.store.mergeDuplicates(merged, [m]);
    } catch (e) {
      _toast('تعذّر الدمج — لم يتغيّر شيء: $e');
      return;
    }
    _similarCache.clear(); // تغيّرت الكميات والمواد
    if (mounted) _next(completed: true);
  }

  Future<void> _delete(Medicine m) async {
    final ok = await _confirm(
      'حذف المادة',
      'تُحذف «${m.name}» من هذا الهاتف ومن كل الأجهزة المشتركة.',
      'احذف',
    );
    if (ok != true) return;
    await widget.store.delete(m);
    _similarCache.clear();
    if (mounted) _next(completed: true);
  }

  Future<bool?> _confirm(String title, String body, String action) =>
      showGlassDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: Text(title),
          content: Text(
            body,
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action),
            ),
          ],
        ),
      );

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.warning),
      );
  }

  @override
  Widget build(BuildContext context) {
    final m = _current;
    return Scaffold(
      appBar: const GlassAppBar(title: Text('📝 إكمال البيانات')),
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground()),
          SafeArea(child: m == null ? _finished() : _item(m)),
        ],
      ),
    );
  }

  Widget _finished() => Center(
    key: const Key('completeFinished'),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            _queue.isEmpty
                ? 'لا مواد ناقصة في هذا القسم'
                : 'انتهت القائمة — اكتملت $_done مادة',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GradientButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('رجوع'),
          ),
        ],
      ),
    ),
  );

  Widget _item(Medicine m) {
    final similar = _similarFor(m);
    final match = similar?.items.firstWhere((x) => x.id != m.id);
    final imagePath = ImageStore.fullPathSync(_image);
    return ListView(
      key: ValueKey(m.id),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'مادة ${_index + 1} من ${_queue.length}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: _queue.isEmpty ? 1 : _index / _queue.length,
          minHeight: 4,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 14),
        GlassSurface(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (m.price <= 0) _badge('بلا سعر'),
                  if (m.barcode.trim().isEmpty && !m.noBarcode)
                    _badge('بلا باركود'),
                ],
              ),
            ],
          ),
        ),
        if (match != null) ...[
          const SizedBox(height: 12),
          GlassSurface(
            key: const Key('similarSuggestion'),
            padding: const EdgeInsets.all(14),
            borderColor: AppColors.warning.withValues(alpha: .5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔍 تشبه مادة موجودة (${(similar!.similarity! * 100).round()}%)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  match.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'السعر ${formatPrice(match.price)} د.ع · الكمية '
                  '${match.quantity}'
                  '${match.barcode.isEmpty ? '' : ' · ${match.barcode}'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('mergeWithSimilar'),
                  onPressed: () => _merge(m, match),
                  icon: const Icon(Icons.merge_type_rounded, size: 18),
                  label: const Text('هي نفسها — دمج معها'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('completePrice'),
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '💰 السعر (د.ع)'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const Key('completeQuantity'),
                controller: _quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '📦 الكمية'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('completeBarcode'),
          controller: _barcode,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: '📊 الباركود',
            suffixIcon: IconButton(
              key: const Key('completeScan'),
              tooltip: 'مسح الباركود',
              icon: const Icon(
                Icons.qr_code_scanner_rounded,
                color: AppColors.primary,
              ),
              onPressed: _scan,
            ),
          ),
        ),
        if (_barcode.text.trim().isEmpty)
          CheckboxListTile(
            key: const Key('completeNoBarcode'),
            value: _noBarcode,
            onChanged: (v) => setState(() => _noBarcode = v ?? false),
            title: const Text('ليس لها باركود'),
            subtitle: const Text(
              'تحضير أو علبة بلا رمز — لن تُعدّ ناقصة بسبب الباركود',
              style: TextStyle(fontSize: 11),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(imagePath),
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(width: 56),
                ),
              ),
            if (imagePath != null) const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_rounded, size: 18),
                label: const Text('تصوير'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded, size: 18),
                label: const Text('المعرض'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        GradientButton(
          key: const Key('completeSaveNext'),
          onPressed: _busy ? null : () => _save(m),
          child: const Text('حفظ والتالي'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextButton(
                key: const Key('completeSkip'),
                onPressed: _busy ? null : _next,
                child: const Text('تخطّي'),
              ),
            ),
            Expanded(
              child: TextButton(
                key: const Key('completeDelete'),
                onPressed: _busy ? null : () => _delete(m),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('حذف'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.warning.withValues(alpha: .4)),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11, color: AppColors.warning),
    ),
  );
}
