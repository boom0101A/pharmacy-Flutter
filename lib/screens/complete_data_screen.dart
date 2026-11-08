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
import '../util/money.dart';
import '../util/number_parse.dart';
import '../widgets/barcode_owner_dialogs.dart';
import '../widgets/glass.dart';
import '../widgets/smooth_route.dart';
import 'scanner_screen.dart';
import '../l10n/l10n.dart';

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
    _price.text = m.price > 0 ? priceInputText(m.price) : '';
    _quantity.text = m.quantity > 0 ? '${m.quantity}' : '';
    _barcode.text = m.barcode;
    _noBarcode = m.noBarcode;
    _image = m.imagePath;
    _expiry = m.expiryDate;
  }

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
  DuplicateGroup? _computeSimilar(Medicine m) => bestSimilarTo(m, [
    for (final o in widget.store.all)
      // المسعّرة لا «المكتملة»: النسخة الحقيقية قد تنقصها الباركود وحده،
      // وهي بالضبط ما يحمله التسجيل الفارغ
      if (o.id != m.id && o.type == m.type && o.price > 0) o,
  ]);

  Future<void> _scan() async {
    final code =
        await (widget.scanBarcode?.call() ??
            Navigator.of(context).push<String>(
              SmoothPageRoute(builder: (_) => const ScannerScreen()),
            ));
    if (code == null || code.trim().isEmpty || !mounted) return;
    final m = _current;
    if (m == null) return;
    final parsed = Gs1Parser.parse(code);
    final previous = _barcode.text;
    final previousExpiry = _expiry;
    final previousNoBarcode = _noBarcode;
    setState(() {
      _barcode.text = parsed.barcode;
      _noBarcode = false;
      _expiry ??= parsed.expiryDate?.millisecondsSinceEpoch;
    });
    // باركود مادة أخرى: التنبيه فوراً كما في نموذج المادة — رفضه يعيد
    // الخانة وما استُخرج من الرمز إلى ما كان قبل المسح
    if (!await _checkOwner(m, parsed.barcode, previous: previous) && mounted) {
      setState(() {
        _expiry = previousExpiry;
        _noBarcode = previousNoBarcode;
      });
    }
  }

  /// [code] يخص مادة غير [m]؟ تنبيه «الباركود مسجَّل» بزر «حذف المرتبط».
  /// يعيد true إن صار الباركود حراً لـ[m] (أو كان حراً أصلاً)، وإلا يعيد
  /// الخانة إلى [previous] ويعيد false.
  Future<bool> _checkOwner(
    Medicine m,
    String code, {
    required String previous,
  }) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return true;
    final owner = await widget.store.findByBarcode(trimmed);
    if (owner == null || owner.id == m.id || !mounted) return true;
    final delete = await showBarcodeOwnerDialog(context, owner);
    if (!mounted) return false;
    if (delete == true &&
        await deleteBarcodeOwner(context, widget.store, owner)) {
      _similarCache.clear(); // قد تكون المحذوفة هي «المادة المشابهة»
      if (mounted) setState(() {});
      return true;
    }
    if (mounted) setState(() => _barcode.text = previous);
    return false;
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
    // باركود مكتوب يخص مادة أخرى: التنبيه نفسه. بعد «حذف المرتبط» لا حفظ
    // تلقائي — كالنموذج، يضغط المستخدم «حفظ» مرة أخرى
    final typed = _barcode.text.trim();
    if (typed.isNotEmpty) {
      final owner = await widget.store.findByBarcode(typed);
      if (!mounted) return;
      if (owner != null && owner.id != m.id) {
        await _checkOwner(m, typed, previous: m.barcode);
        return;
      }
    }
    final price =
        priceFromInput(
          _price.text,
          originalIqd: m.price > 0 ? m.price : null,
        ) ??
        0;
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
      _toast(L10n.current.cdBarcodeTaken);
      return;
    } catch (e) {
      _toast(L10n.current.saveFailed('$e'));
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
      context.l10n.cdMergeWith(into.name),
      context.l10n.cdMergeBody(into.name, merged.quantity, m.name),
      context.l10n.cdMergeConfirm,
    );
    if (ok != true) return;
    try {
      await widget.store.mergeDuplicates(merged, [m]);
    } catch (e) {
      _toast(L10n.current.dupMergeFailed('$e'));
      return;
    }
    _similarCache.clear(); // تغيّرت الكميات والمواد
    if (mounted) _next(completed: true);
  }

  Future<void> _delete(Medicine m) async {
    final ok = await _confirm(
      context.l10n.cdDeleteTitle,
      context.l10n.cdDeleteBody(m.name),
      context.l10n.cdDeleteConfirm,
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
              child: Text(context.l10n.cancel),
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
      appBar: GlassAppBar(title: Text(context.l10n.cdTitle)),
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
                ? context.l10n.cdNoneInSection
                : context.l10n.cdListDone(_done),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GradientButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.back),
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
          context.l10n.cdProgress(_index + 1, _queue.length),
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
                  if (m.price <= 0) _badge(context.l10n.cdNoPrice),
                  if (m.barcode.trim().isEmpty && !m.noBarcode)
                    _badge(context.l10n.cdNoBarcode),
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
                  context.l10n.cdSimilar((similar!.similarity! * 100).round()),
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
                  '${context.l10n.cdMatchLine(formatMoney(match.price), match.quantity)}'
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
                  label: Text(context.l10n.cdSameMerge),
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
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: InputDecoration(
                  labelText: context.l10n.cdPrice(currencyLabel()),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const Key('completeQuantity'),
                controller: _quantity,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: context.l10n.cdQty),
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
            labelText: context.l10n.cdBarcode,
            suffixIcon: IconButton(
              key: const Key('completeScan'),
              tooltip: context.l10n.scanTheBarcode,
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
            title: Text(context.l10n.formNoBarcode),
            subtitle: Text(
              context.l10n.cdNoBarcodeSub,
              style: const TextStyle(fontSize: 11),
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
                label: Text(context.l10n.takePhoto),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded, size: 18),
                label: Text(context.l10n.theGallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        GradientButton(
          key: const Key('completeSaveNext'),
          onPressed: _busy ? null : () => _save(m),
          child: Text(context.l10n.cdSaveNext),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextButton(
                key: const Key('completeSkip'),
                onPressed: _busy ? null : _next,
                child: Text(context.l10n.welcomeSkip),
              ),
            ),
            Expanded(
              child: TextButton(
                key: const Key('completeDelete'),
                onPressed: _busy ? null : () => _delete(m),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(context.l10n.delete),
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
