import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/medicine.dart';
import '../services/gemini_vision.dart';
import '../services/gs1_parser.dart';
import '../state/medicine_store.dart';
import '../util/number_parse.dart';
import '../theme.dart';

/// يختار صورة صفحة (كاميرا أو معرض) — قابل للحقن في الاختبار.
typedef InvoicePagePicker = Future<File?> Function({required bool camera});

/// يقرأ صورة صفحة واحدة — قابل للحقن في الاختبار.
typedef InvoicePageReader = Future<InvoiceResult> Function(File image);

/// قراءة فاتورة مجهّز بالذكاء الاصطناعي (Gemini) → مراجعة الأسطر مع تحرير
/// كامل → حفظها دفعة واحدة عبر `MedicineStore.saveAll`.
///
/// **صفحة واحدة في كل مرة** (طلب المستخدم): صورة جديدة تستبدل السابقة. الأسطر
/// المكرّرة داخل الصفحة تُدمج عند الحفظ في [buildInvoiceSaveItems].
///
/// **يعمل فقط عند وجود مفتاح Gemini في ملف `.env`** — الزر الذي يفتح هذه
/// الشاشة يختفي تلقائياً في `home_screen.dart` عند غياب المفتاح.
class InvoiceScanScreen extends StatefulWidget {
  const InvoiceScanScreen({
    super.key,
    required this.store,
    this.initialType = ItemType.supply,
    this.pickPage,
    this.readPage,
  });

  final MedicineStore store;

  /// النوع الافتراضي لأسطر الفاتورة — قابل للتغيير لكل سطر أو جماعياً.
  final ItemType initialType;

  final InvoicePagePicker? pickPage;
  final InvoicePageReader? readPage;

  @override
  State<InvoiceScanScreen> createState() => _InvoiceScanScreenState();
}

enum _PageState { reading, done, failed }

class _InvoicePage {
  _InvoicePage(this.image);
  final File image;
  _PageState state = _PageState.reading;
  String? error;

  /// قرأها النموذج البديل (حصة الأساسي انتهت أو بقي مزدحماً).
  bool usedFallback = false;
}

class _InvoiceScanScreenState extends State<InvoiceScanScreen> {
  bool _saving = false;
  String? _error;
  final List<_InvoicePage> _pages = [];
  List<_EditableLine> _lines = const [];
  bool _flaggedOnly = false;

  ItemType _bulkType = ItemType.supply;

  InvoicePagePicker get _pick => widget.pickPage ?? _defaultPick;
  InvoicePageReader get _read => widget.readPage ?? GeminiVision.readInvoice;

  @override
  void initState() {
    super.initState();
    _bulkType = widget.initialType;
    // نبدأ فور الفتح — الكاميرا هي التدفّق الطبيعي
    WidgetsBinding.instance.addPostFrameCallback((_) => _addPage(camera: true));
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  /// دقة أعلى من السابق (1600) — فواتير المجهّزين كثيفة الأسطر بخط صغير.
  static Future<File?> _defaultPick({required bool camera}) async {
    final picked = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 90,
    );
    return picked == null ? null : File(picked.path);
  }

  /// صفحة واحدة فقط في كل مرة (طلب المستخدم): صورة جديدة تستبدل السابقة
  /// وأسطرها — بتأكيد إن كانت هناك أسطر مقروءة ستضيع.
  Future<void> _addPage({required bool camera}) async {
    if (_lines.isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text('استبدال الصفحة؟'),
          content: Text(
            'ستُحذف ${_lines.length} سطراً مقروءاً من الصفحة الحالية وتُقرأ '
            'الصورة الجديدة مكانها.',
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('استبدال'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    final file = await _pick(camera: camera);
    if (file == null || !mounted) return;
    for (final old in List.of(_pages)) {
      _removePage(old);
    }
    final page = _InvoicePage(file);
    setState(() {
      _error = null;
      _pages.add(page);
    });
    await _readPage(page);
  }

  Future<void> _readPage(_InvoicePage page) async {
    setState(() {
      page.state = _PageState.reading;
      page.error = null;
    });
    final result = await _read(page.image);
    // الصفحة قد تُحذف أثناء القراءة
    if (!mounted || !_pages.contains(page)) return;

    if (!result.ok) {
      setState(() {
        page.state = _PageState.failed;
        page.error = result.error;
      });
      return;
    }
    final added = <_EditableLine>[];
    for (final l in result.lines) {
      final v = GeminiVision.validateLine(l);
      added.add(
        _EditableLine(
          source: v.line,
          issues: v.issues,
          page: page,
          type: _bulkType,
        ),
      );
    }
    setState(() {
      page.state = _PageState.done;
      page.usedFallback = result.usedFallback;
      _lines = [..._lines, ...added];
    });
  }

  /// حذف صفحة مع أسطرها — بنفس نمط [_removeLine] الآمن.
  void _removePage(_InvoicePage page) {
    final removed = _lines.where((l) => l.page == page).toList();
    setState(() {
      _pages.remove(page);
      _lines = _lines.where((l) => l.page != page).toList();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final l in removed) {
        l.dispose();
      }
    });
  }

  /// حذف سطر من المراجعة — الإزالة من الشجرة أولاً، والإتلاف بعد اكتمال
  /// الإطار.
  ///
  /// `dispose()` المباشر داخل `setState` كان يُتلف المحرّرات بينما حقولها
  /// ما زالت مبنيّة في الإطار الحالي. لو كان حقل السطر المحذوف يحمل التركيز،
  /// يصل تحديث إدخال معلَّق إلى محرّر مُتلَف → شاشة حمراء.
  void _removeLine(_EditableLine line) {
    setState(() => _lines = List.of(_lines)..remove(line));
    WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
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
            expiryDate: InvoiceLineToMedicine.parseExpiry(
              _orNull(line.expiry.text),
            ),
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

    setState(() => _saving = true);
    try {
      await widget.store.saveAll(result.items);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'تعذّر الحفظ: $e';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _leaving = true);
    Navigator.of(context).pop(result);
  }

  /// يُرفع قبل الخروج المقصود (حفظ، أو تأكيد الخروج) فيتخطّى سؤال التأكيد.
  bool _leaving = false;

  /// زر الرجوع بعد قراءة الأسطر كان يُسقط الفاتورة كلها بلا سؤال — قراءة
  /// صفحات من جديد تكلّف دقائق وطلبات Gemini.
  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('الخروج بلا حفظ؟'),
        content: Text(
          'ستضيع ${_lines.length} سطراً مقروءاً من هذه الفاتورة.',
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('البقاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('خروج بلا حفظ'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    setState(() => _leaving = true);
    Navigator.of(context).pop();
  }

  String? _orNull(String s) => s.trim().isEmpty ? null : s.trim();

  /// المطابق الموجود في المخزون — بالباركود أولاً ثم بالاسم، بنفس ترتيب
  /// [buildInvoiceSaveItems] حتى تقول الشارة ما سيحدث فعلاً عند الحفظ.
  Medicine? _existingMatchFor(_EditableLine line) {
    final byBarcode = widget.store.findExistingByBarcode(line.barcode.text);
    if (byBarcode != null) return byBarcode;
    final name = line.name.text.trim();
    if (name.isEmpty) return null;
    return widget.store.findExistingByName(name, line.type);
  }

  /// هل يطابق هذا السطر سطراً آخر في نفس الفاتورة (نفس الاسم بعد التطبيع
  /// ونفس القسم)؟
  bool _duplicatesAnotherLine(_EditableLine line) {
    final name = line.name.text.trim();
    if (name.isEmpty) return false;
    final norm = MedicineStore.normalizeName(name);
    for (final other in _lines) {
      if (identical(other, line) || other.type != line.type) continue;
      if (MedicineStore.normalizeName(other.name.text.trim()) == norm) {
        return true;
      }
    }
    return false;
  }

  bool get _anyReading => _pages.any((p) => p.state == _PageState.reading);

  @override
  Widget build(BuildContext context) {
    final named = _lines.where((l) => l.name.text.trim().isNotEmpty).length;
    return PopScope(
      canPop: _lines.isEmpty || _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: _scaffold(named),
    );
  }

  Widget _scaffold(int named) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧾 فاتورة ذكية'),
        backgroundColor: AppColors.bgCard,
        actions: [
          if (_lines.isNotEmpty && !_saving && !_anyReading)
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check, color: AppColors.success),
              label: Text(
                'حفظ ($named)',
                style: const TextStyle(color: AppColors.success),
              ),
            ),
        ],
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : _pages.isEmpty
          ? _introView()
          : _reviewView(),
      bottomNavigationBar: _pages.isEmpty && !_saving
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _addPage(camera: true),
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('كاميرا'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _addPage(camera: false),
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

  Widget _introView() => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🧾', style: TextStyle(fontSize: 60)),
        const SizedBox(height: 12),
        const Text(
          'صوّر الفاتورة أو اخترها من المعرض',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'تُقرأ أسطر الصفحة وتُملأ الحقول تلقائياً (الاسم، الكمية، السعر، '
          'الصلاحية) لتراجعها قبل الحفظ.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        if (_error != null) ...[const SizedBox(height: 14), _errorBox(_error!)],
      ],
    ),
  );

  Widget _errorBox(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.danger.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.danger, fontSize: 13),
    ),
  );

  Widget _reviewView() {
    final flagged = _lines.where((l) => l.issues.isNotEmpty).length;
    final shown = _flaggedOnly
        ? _lines.where((l) => l.issues.isNotEmpty).toList()
        : _lines;
    // سبب الفشل ظاهر بلا ضغط — كان مخفياً خلف الصورة المصغّرة فلا يرى
    // المستخدم إلا إطاراً أحمر و«لم تُقرأ أي أسطر بعد»
    final failed = _pages.where((p) => p.state == _PageState.failed);
    final failureText = failed.isEmpty
        ? null
        : 'تعذّرت قراءة الصفحة: ${failed.first.error ?? 'خطأ غير معروف'}\n'
              'اضغط «إعادة المحاولة» على الصفحة.';
    return Column(
      children: [
        _pageStrip(),
        if (failureText != null && _lines.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _errorBox(failureText),
          ),
        if (_lines.isNotEmpty && _pages.any((p) => p.usedFallback))
          Container(
            width: double.infinity,
            color: AppColors.bgCard,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _badge(
              '⚡ قُرئت بالنموذج البديل (حصة النموذج الأساسي انتهت) — راجع '
              'الأسطر بانتباه',
              AppColors.warning,
            ),
          ),
        if (_lines.isNotEmpty) _summary(flagged),
        if (_lines.isNotEmpty) _bulkHeader(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _errorBox(_error!),
          ),
        Expanded(
          child: _lines.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _anyReading
                        ? const Text(
                            'جاري قراءة الفاتورة… قد تستغرق حتى دقيقة '
                            'للصفحات الكثيفة',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          )
                        : failureText != null
                        ? _errorBox(failureText)
                        : const Text(
                            'لم تُقرأ أي أسطر بعد',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: shown.length,
                  itemBuilder: (_, i) => _lineCard(shown[i]),
                ),
        ),
      ],
    );
  }

  /// شريط الصفحة: مصغّرتها بحالتها، وزرّا تصوير/اختيار صورة بديلة.
  Widget _pageStrip() => Container(
    color: AppColors.bgCard,
    height: 112,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final page in _pages) _pageTile(page),
        _addPageButton(
          icon: Icons.photo_camera,
          label: 'تصوير من جديد',
          camera: true,
        ),
        _addPageButton(
          icon: Icons.photo_library,
          label: 'من المعرض',
          camera: false,
        ),
      ],
    ),
  );

  Widget _addPageButton({
    required IconData icon,
    required String label,
    required bool camera,
  }) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: Tooltip(
      message: label,
      child: InkWell(
        onTap: _saving ? null : () => _addPage(camera: camera),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 76,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _pageTile(_InvoicePage page) {
    final color = switch (page.state) {
      _PageState.reading => AppColors.primary,
      _PageState.done => AppColors.success,
      _PageState.failed => AppColors.danger,
    };
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Container(
        width: page.state == _PageState.failed ? 140 : 76,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () => _viewPage(page),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.file(
                        page.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.description_outlined),
                        ),
                      ),
                    ),
                  ),
                  if (page.state == _PageState.reading)
                    const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  PositionedDirectional(
                    top: 0,
                    end: 0,
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                        tooltip: 'حذف الصفحة',
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: const Icon(Icons.cancel, color: AppColors.danger),
                        onPressed: () => _removePage(page),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (page.state == _PageState.failed)
              SizedBox(
                width: 62,
                child: TextButton(
                  onPressed: () => _readPage(page),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: const Text(
                    'إعادة المحاولة',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.danger),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// الصفحة مكبّرة للمقارنة مع الأسطر، مع سبب الفشل إن فشلت.
  void _viewPage(_InvoicePage page) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.bgDark,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (page.error != null)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  page.error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            Flexible(
              child: InteractiveViewer(
                maxScale: 6,
                child: Image.file(
                  page.image,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Icon(Icons.broken_image_outlined, size: 48),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  /// «N سطراً · M جديدة · K ستُضاف لمخزون موجود · J تحتاج مراجعة»
  Widget _summary(int flagged) {
    final named = _lines.where((l) => l.name.text.trim().isNotEmpty);
    final existing = named.where((l) => _existingMatchFor(l) != null).length;
    final total = named.length;
    return Container(
      color: AppColors.bgCard,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$total سطراً · ${total - existing} جديدة · '
              '$existing ستُضاف لمخزون موجود'
              '${flagged > 0 ? ' · $flagged تحتاج مراجعة' : ''}',
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
          if (flagged > 0)
            FilterChip(
              label: const Text(
                'المشكوك فيها فقط',
                style: TextStyle(fontSize: 11),
              ),
              selected: _flaggedOnly,
              onSelected: (v) => setState(() => _flaggedOnly = v),
              selectedColor: AppColors.warning.withValues(alpha: 0.25),
              showCheckmark: false,
            ),
        ],
      ),
    );
  }

  Widget _bulkHeader() => Container(
    color: AppColors.bgCard,
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
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

  Widget _lineCard(_EditableLine line) {
    final i = _lines.indexOf(line);
    final flagged = line.issues.isNotEmpty;
    return Card(
      // مفتاح مرتبط بهوية السطر نفسه: بلاه يُعيد ListView تدوير العنصر بعد
      // الحذف فيربط حقول السطر التالي بحالة السطر المحذوف.
      key: ObjectKey(line),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: flagged
            ? const BorderSide(color: AppColors.warning, width: 1.5)
            : BorderSide.none,
      ),
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
                  onPressed: () => _removeLine(line),
                ),
              ],
            ),
            if (flagged)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final issue in line.issues)
                      _badge(issue.label, AppColors.warning),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            TextField(
              controller: line.name,
              decoration: const InputDecoration(labelText: 'الاسم'),
            ),
            // الشارات تتحدّث حيّاً مع تعديل أي اسم أو باركود — «مكرر مع سطر
            // آخر» تعتمد على تغيّر السطر الآخر أيضاً.
            ListenableBuilder(
              listenable: Listenable.merge([
                for (final l in _lines) ...[l.name, l.barcode],
              ]),
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
                    decoration: InputDecoration(
                      labelText: 'الكمية',
                      helperText: line.bonus > 0
                          ? '+${line.bonus} مجاناً'
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: line.expiry,
                    decoration: const InputDecoration(
                      labelText: 'الصلاحية (مثل 2027-11)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: line.barcode,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الباركود (اختياري)',
                    ),
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
          ],
        ),
      ),
    );
  }

  /// «موجودة مسبقاً» و«مكررة داخل هذه الفاتورة» — عند الحاجة فقط.
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
              '🔁 موجودة مسبقاً («${existing.name}») — الرصيد '
              '${existing.quantity}، سيُضاف الوارد إليه',
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
    this.expiryDate,
  });

  final String name;
  final ItemType type;
  final double price;
  final int quantity;
  final String barcode;
  final String? category;

  /// مللي ثانية، أو null إن لم تُقرأ صلاحية.
  final int? expiryDate;
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
  //
  // المطابقة بالباركود أولاً (سطران بباركود واحد واسمين مختلفين مادة واحدة)،
  // ثم بالاسم — إلا إن حمل السطران باركودين مختلفين فهما منتجان مختلفان.
  final byKey = <String, InvoiceLineDraft>{};
  final mergedWithinFlags = <String, bool>{};
  final order = <String>[];
  final keyByCode = <String, String>{};
  final keyByName = <String, String>{};

  for (final raw in drafts) {
    if (raw.name.trim().isEmpty) continue;
    final d = InvoiceLineDraft(
      name: raw.name,
      type: raw.type,
      price: raw.price < 0 ? 0 : raw.price,
      quantity: raw.quantity < 0 ? 0 : raw.quantity,
      barcode: raw.barcode.trim(),
      category: raw.category,
      expiryDate: raw.expiryDate,
    );
    final code = Gs1Parser.canonicalKey(d.barcode);
    final nameKey = '${d.type.name}::${MedicineStore.normalizeName(d.name)}';

    var key = code == null ? null : keyByCode[code];
    if (key == null) {
      final byName = keyByName[nameKey];
      final other = byName == null ? null : byKey[byName]!.barcode;
      final compatible =
          other == null ||
          code == null ||
          other.isEmpty ||
          Gs1Parser.canonicalKey(other) == code;
      if (byName != null && compatible) key = byName;
    }

    final prev = key == null ? null : byKey[key];
    if (prev == null) {
      // اسم مستعمل لسطر بباركود آخر — مفتاح مستقل لهذا المنتج المختلف
      final fresh = byKey.containsKey(nameKey) ? '$nameKey::$code' : nameKey;
      byKey[fresh] = d;
      order.add(fresh);
      if (code != null) keyByCode[code] = fresh;
      keyByName.putIfAbsent(nameKey, () => fresh);
    } else {
      final k = key!;
      if (code != null) keyByCode[code] = k;
      keyByName.putIfAbsent(nameKey, () => k);
      byKey[k] = InvoiceLineDraft(
        name: prev.name,
        type: prev.type,
        price: d.price > 0 ? d.price : prev.price,
        quantity: prev.quantity + d.quantity,
        barcode: prev.barcode.isNotEmpty ? prev.barcode : d.barcode,
        category: prev.category ?? d.category,
        expiryDate: _earlier(prev.expiryDate, d.expiryDate),
      );
      mergedWithinFlags[k] = true;
    }
  }

  // مرحلة 2: مقارنة كل سطر مُدمَج (مرة واحدة) بالمخزون المحفوظ فعلياً.
  var addedNew = 0;
  var mergedExisting = 0;
  var mergedWithinInvoice = 0;
  final items = <Medicine>[];
  // مادة موجودة تطابقها مجموعتان (واحدة بالباركود وأخرى بالاسم) — تُجمع في
  // عنصر واحد، وإلا حمل الحفظ نفس المعرّف مرتين وبقي الأخير وحده.
  final indexById = <String, int>{};

  for (final key in order) {
    final d = byKey[key]!;
    if (mergedWithinFlags[key] == true) mergedWithinInvoice++;

    // الباركود أولاً: سطر بباركود مادة موجودة (ولو باسم مكتوب بشكل آخر) يُدمج
    // معها. إنشاء سجل جديد بنفس الباركود كان يجعل upsert(replace) يحذف
    // المادة الأصلية محلياً بينما تبقى النسختان في السحابة.
    final byBarcode = store.findExistingByBarcode(d.barcode);
    final existing = byBarcode ?? store.findExistingByName(d.name, d.type);
    final ts = now.millisecondsSinceEpoch;
    final already = existing == null ? null : indexById[existing.id];
    if (already != null) {
      final prev = items[already];
      items[already] = prev.copyWith(
        price: d.price > 0 ? d.price : prev.price,
        quantity: prev.quantity + d.quantity,
        expiryDate: _earlier(prev.expiryDate, d.expiryDate),
        updatedAt: ts,
      );
      mergedWithinInvoice++;
    } else if (existing != null) {
      mergedExisting++;
      indexById[existing.id] = items.length;
      // مطابقة الباركود لا تنقل المادة لقسم آخر بسبب تصنيف الفاتورة الجماعي
      final type = byBarcode != null ? existing.type : d.type;
      final expiry = _earlier(existing.expiryDate, d.expiryDate);
      items.add(
        existing.copyWith(
          price: d.price > 0 ? d.price : existing.price,
          quantity: existing.quantity + d.quantity,
          type: type,
          category: type == ItemType.supply
              ? (d.category ?? existing.category)
              : null,
          clearCategory: type != ItemType.supply,
          expiryDate: expiry,
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
          expiryDate: d.expiryDate,
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

/// الأقرب من تاريخين — التنبيه المبكر بالصلاحية أسلم من المتأخر.
int? _earlier(int? a, int? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a < b ? a : b;
}

/// حاوية محرّرات سطر واحد — عمرها بعمر الشاشة، تُتلَف عند الحذف أو الخروج.
class _EditableLine {
  _EditableLine({
    required InvoiceLine source,
    required this.type,
    required this.page,
    this.issues = const [],
  }) : bonus = source.bonus ?? 0,
       name = TextEditingController(text: source.name),
       price = TextEditingController(
         text: source.price == null ? '' : _num(source.price!),
       ),
       // البونص يصل للرف فعلاً فيُضاف للكمية، ويُعرض «+N مجاناً» تحت الحقل
       quantity = TextEditingController(
         text: source.quantity == null && source.bonus == null
             ? ''
             : '${(source.quantity ?? 0) + (source.bonus ?? 0)}',
       ),
       barcode = TextEditingController(text: source.barcode ?? ''),
       expiry = TextEditingController(text: source.expiry ?? ''),
       category = TextEditingController(text: source.category ?? '');

  final _InvoicePage page;
  final List<LineIssue> issues;
  final int bonus;
  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController quantity;
  final TextEditingController barcode;
  final TextEditingController expiry;
  final TextEditingController category;
  ItemType type;

  void dispose() {
    name.dispose();
    price.dispose();
    quantity.dispose();
    barcode.dispose();
    expiry.dispose();
    category.dispose();
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
