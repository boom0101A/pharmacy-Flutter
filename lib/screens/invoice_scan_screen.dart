import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/invoice.dart';
import '../models/medicine.dart';
import '../services/gemini_vision.dart';
import '../services/gs1_parser.dart';
import '../state/invoice_store.dart';
import '../state/medicine_store.dart';
import '../util/number_parse.dart';
import '../util/money.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/medicine_card.dart' show formatPrice;
import '../widgets/smooth_route.dart';
import 'invoices_screen.dart';
import 'scanner_screen.dart';
import '../l10n/l10n.dart';

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
    this.scanBarcode,
    this.invoices,
  });

  final MedicineStore store;

  /// سجل الفواتير — يُحقن في الاختبار، وإلا [InvoiceStore.instance].
  final InvoiceStore? invoices;

  /// النوع الافتراضي لأسطر الفاتورة — قابل للتغيير لكل سطر أو جماعياً.
  final ItemType initialType;

  final InvoicePagePicker? pickPage;
  final InvoicePageReader? readPage;

  /// يمسح باركوداً بالكاميرا (null = ألغى) — قابل للحقن في الاختبار.
  final Future<String?> Function()? scanBarcode;

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

  // رأس الفاتورة — يملؤه Gemini من الطلب نفسه، والمستخدم يصحّحه قبل الحفظ
  final _supplier = TextEditingController();
  final _number = TextEditingController();
  final _date = TextEditingController();
  final _total = TextEditingController();

  InvoicePagePicker get _pick => widget.pickPage ?? _defaultPick;

  /// مسح باركود سطر: الكاميرا ← GTIN في خانة الباركود، وصلاحية رمز GS1 إن
  /// كانت خانتها فارغة. الباركود صار مسحاً حقيقياً فتسقط شارة «غير صالح»،
  /// وشارة «موجودة مسبقاً» تُعاد حسابها تلقائياً (تستمع لخانة الباركود).
  Future<void> _scanBarcodeFor(_EditableLine line) async {
    final code =
        await (widget.scanBarcode?.call() ??
            Navigator.of(context).push<String>(
              SmoothPageRoute(builder: (_) => const ScannerScreen()),
            ));
    if (code == null || code.trim().isEmpty || !mounted) return;
    final parsed = Gs1Parser.parse(code);
    setState(() {
      line.barcode.text = parsed.barcode;
      final exp = parsed.expiryDate;
      if (exp != null && line.expiry.text.trim().isEmpty) {
        line.expiry.text =
            '${exp.year}-${exp.month.toString().padLeft(2, '0')}';
      }
      line.issues.remove(LineIssue.invalidBarcode);
    });
  }

  InvoicePageReader get _read => widget.readPage ?? GeminiVision.readInvoice;

  @override
  void initState() {
    super.initState();
    _bulkType = widget.initialType;
    // لا تصوير تلقائي عند الفتح (طلب المستخدم): صفحة الاختيار تظهر أولاً
    // ويختار هو «كاميرا» أو «معرض».
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    for (final c in [_supplier, _number, _date, _total]) {
      c.dispose();
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
      final replace = await showGlassDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: Text(context.l10n.scReplaceTitle),
          content: Text(
            context.l10n.scReplaceBody(_lines.length),
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.scReplace),
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
      final line = _EditableLine(
        source: v.line,
        issues: v.issues,
        page: page,
        type: _bulkType,
      );
      // مادة سبق شراؤها بالكرتون: السطر مفعّل بالعدد والاختيار المحفوظين
      final known = _existingMatchFor(line);
      if (known?.packSize != null) {
        line
          ..packed = true
          ..packSize.text = '${known!.packSize}'
          ..pricePerPack = known.packPriced ?? true;
      }
      added.add(line);
    }
    setState(() {
      page.state = _PageState.done;
      page.usedFallback = result.usedFallback;
      _lines = [..._lines, ...added];
      _fillHeader(result.header);
    });
  }

  /// يملأ الخانات الفارغة فقط — لا يدهس تصحيحاً كتبه المستخدم.
  void _fillHeader(InvoiceHeader? h) {
    if (h == null) return;
    void fill(TextEditingController c, String? v) {
      if (c.text.trim().isEmpty && v != null) c.text = v;
    }

    fill(_supplier, h.supplier);
    fill(_number, h.number);
    fill(_date, h.date);
    final total = h.total;
    fill(_total, total == null ? null : formatPriceInput(total));
  }

  /// مجموع الأسطر كما عُدّلت (الكمية × السعر).
  double get _linesTotal => _lines.fold(
    0,
    (s, l) =>
        s +
        (parseLocalizedNumber(l.price.text) ?? 0) *
            ((parseLocalizedInt(l.quantity.text) ?? 0) - l.bonus),
  );

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
    // عدد كرتون غير صالح يضرب الرصيد في رقم خاطئ — لا حفظ قبل تصحيحه
    if (_lines.any((l) => l.name.text.trim().isNotEmpty && l.packInvalid)) {
      setState(() => _error = context.l10n.scPackInvalid);
      return;
    }
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
            company: _orNull(line.company.text),
            expiryDate: InvoiceLineToMedicine.parseExpiry(
              _orNull(line.expiry.text),
            ),
            packSize: line.packed ? line.validPackSize : null,
            pricePerPack: line.pricePerPack,
          ),
    ];

    final result = buildInvoiceSaveItems(
      drafts: drafts,
      store: widget.store,
      now: DateTime.now(),
    );

    if (result.items.isEmpty) {
      setState(() => _error = context.l10n.scNoValidLines);
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.store.saveAll(result.items);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = L10n.current.saveFailed('$e');
      });
      return;
    }
    // سجل الفاتورة بعد نجاح المواد — فشله لا يُلغي ما حُفظ في المخزون
    if (!mounted) return;
    // في الخلفية: ضغط الصفحات يأخذ ثانية تقريباً، ولا داعي لإبقاء المستخدم
    // ينتظر — المواد محفوظة أصلاً. الرسالة تظهر في الرئيسية إن فشل.
    final messenger = ScaffoldMessenger.maybeOf(context);
    unawaited(
      (widget.invoices ?? InvoiceStore.instance)
          .add(_buildInvoice(result), [for (final p in _pages) p.image])
          .then<void>((_) {})
          .catchError((Object e) {
            debugPrint('تعذّر حفظ سجل الفاتورة: $e');
            messenger?.showSnackBar(
              SnackBar(
                content: Text(L10n.current.scRecordFailed),
                backgroundColor: AppColors.warning,
              ),
            );
          }),
    );
    setState(() => _leaving = true);
    Navigator.of(context).pop(result);
  }

  Invoice _buildInvoice(InvoiceSaveResult result) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dateText = _orNull(_date.text);
    return Invoice(
      id: 'invrec_$now',
      supplier: _orNull(_supplier.text),
      number: _orNull(_number.text),
      dateText: dateText,
      dateMs: InvoiceLineToMedicine.parseExpiry(dateText),
      total: parseLocalizedNumber(_total.text),
      lines: result.records,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// يُرفع قبل الخروج المقصود (حفظ، أو تأكيد الخروج) فيتخطّى سؤال التأكيد.
  bool _leaving = false;

  /// زر الرجوع بعد قراءة الأسطر كان يُسقط الفاتورة كلها بلا سؤال — قراءة
  /// صفحات من جديد تكلّف دقائق وطلبات Gemini.
  Future<void> _confirmLeave() async {
    final leave = await showGlassDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(context.l10n.scLeaveTitle),
        content: Text(
          context.l10n.scLeaveBody(_lines.length),
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.scStay),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(context.l10n.scLeave),
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
    return widget.store.findExistingByName(
      name,
      line.type,
      barcode: line.barcode.text,
    );
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
      appBar: GlassAppBar(
        title: Text(context.l10n.scTitle),
        actions: [
          IconButton(
            key: const Key('openInvoices'),
            tooltip: context.l10n.scSavedInvoices,
            icon: const Text('📚', style: TextStyle(fontSize: 20)),
            onPressed: () => Navigator.of(context).push(
              SmoothPageRoute<void>(
                builder: (_) => InvoicesScreen(
                  store: widget.invoices ?? InvoiceStore.instance,
                ),
              ),
            ),
          ),
          if (_lines.isNotEmpty && !_saving && !_anyReading)
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded, color: AppColors.success),
              label: Text(
                context.l10n.scSaveN(named),
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
                      child: GradientFilled(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: () => _addPage(camera: true),
                            icon: const Icon(Icons.photo_camera_rounded),
                            label: Text(context.l10n.camera),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _addPage(camera: false),
                          icon: const Icon(Icons.photo_library_rounded),
                          label: Text(context.l10n.gallery),
                        ),
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
        Text(
          context.l10n.scEmptyTitle,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.scEmptySub,
          textAlign: TextAlign.center,
          style: const TextStyle(
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
        : context.l10n.scReadFailed(
            failed.first.error ?? context.l10n.unknownError,
          );
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
            color: AppColors.glass,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _badge(context.l10n.scFallbackModel, AppColors.warning),
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
                        ? Text(
                            context.l10n.scReading,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          )
                        : failureText != null
                        ? _errorBox(failureText)
                        : Text(
                            context.l10n.scNoLines,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: shown.length + 1,
                  itemBuilder: (_, i) =>
                      i == 0 ? _headerCard() : _lineCard(shown[i - 1]),
                ),
        ),
      ],
    );
  }

  /// بطاقة رأس الفاتورة: يملؤها Gemini وتُصحَّح هنا، مع مقارنة المجموعين.
  Widget _headerCard() {
    final printed = parseLocalizedNumber(_total.text);
    final lines = _linesTotal;
    final off =
        printed != null &&
        printed > 0 &&
        (lines - printed).abs() > printed * .01;
    return GlassSurface(
      key: const Key('invoiceHeader'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.scHeader,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('headerSupplier'),
            controller: _supplier,
            decoration: InputDecoration(labelText: context.l10n.scSupplier),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('headerNumber'),
                  controller: _number,
                  decoration: InputDecoration(labelText: context.l10n.scNumber),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('headerDate'),
                  controller: _date,
                  decoration: InputDecoration(labelText: context.l10n.scDate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('headerTotal'),
            controller: _total,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [ThousandsSeparatorInputFormatter()],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.l10n.scTotal(currencyLabel(iqdOnly: true)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${context.l10n.scLinesTotal(formatMoney(lines, iqdOnly: true))}'
            '${printed == null ? '' : context.l10n.scPrinted(formatMoney(printed, iqdOnly: true))}',
            key: const Key('headerCompare'),
            style: TextStyle(
              fontSize: 12,
              color: off ? AppColors.warning : AppColors.textSecondary,
              fontWeight: off ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (off)
            Text(
              context.l10n.scTotalsDiffer,
              style: TextStyle(fontSize: 12, color: AppColors.warning),
            ),
        ],
      ),
    );
  }

  /// شريط الصفحة: مصغّرتها بحالتها، وزرّا تصوير/اختيار صورة بديلة.
  // لوحة زجاجية متصلة: شريط الصفحة أعلاها، ثم الملخّص، ثم نوع الأسطر أسفلها
  // (`.pages` و`.inv-summary` و`.bulk` في ملف التصميم).
  Widget _pageStrip() => Container(
    decoration: const BoxDecoration(
      color: AppColors.glass,
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      border: Border(
        top: BorderSide(color: AppColors.border),
        left: BorderSide(color: AppColors.border),
        right: BorderSide(color: AppColors.border),
      ),
    ),
    margin: const EdgeInsets.fromLTRB(10, 4, 10, 0),
    height: 116,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final page in _pages) _pageTile(page),
        _addPageButton(
          icon: Icons.photo_camera_rounded,
          label: context.l10n.scRetake,
          camera: true,
        ),
        _addPageButton(
          icon: Icons.photo_library_rounded,
          label: context.l10n.scFromGallery,
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
                          child: Icon(Icons.description_rounded),
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
                        tooltip: context.l10n.scDeletePage,
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: const Icon(
                          Icons.cancel_rounded,
                          color: AppColors.danger,
                        ),
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
                  child: Text(
                    context.l10n.scRetry,
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
    showGlassDialog<void>(
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
                    child: Icon(Icons.broken_image_rounded, size: 48),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.close),
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
      color: AppColors.glass,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${context.l10n.scLinesSummary(total, total - existing, existing)}'
              '${flagged > 0 ? context.l10n.scNeedReview(flagged) : ''}',
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
          if (flagged > 0)
            FilterChip(
              label: Text(
                context.l10n.scFlaggedOnly,
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
    decoration: const BoxDecoration(
      color: AppColors.glass,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      border: Border(
        bottom: BorderSide(color: AppColors.border),
        left: BorderSide(color: AppColors.border),
        right: BorderSide(color: AppColors.border),
      ),
    ),
    margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    child: Row(
      children: [
        Text(context.l10n.scAllLinesType, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 10),
        Expanded(
          child: SegmentedButton<ItemType>(
            segments: [
              for (final t in ItemType.values)
                ButtonSegment(value: t, label: Text(t.labelIn(context.l10n))),
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
      // المشكوك فيه: حدّ برتقالي وتعبئة دافئة (`.line.flagged`)
      color: flagged ? const Color(0x1AFBBF24) : AppColors.glass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: flagged ? const Color(0x99FBBF24) : AppColors.border,
          width: flagged ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // نقطة رقم متدرّجة (`.num-dot`)
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: AppGradients.brand,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onGradient,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _typeChip(line)),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
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
              decoration: InputDecoration(labelText: context.l10n.scName),
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
                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                    decoration: InputDecoration(
                      labelText: context.l10n.scCostPrice,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: line.quantity,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.scQty,
                      helperText: line.bonus > 0
                          ? context.l10n.scBonus(line.bonus)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            _packSection(line),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: line.expiry,
                    decoration: InputDecoration(
                      labelText: context.l10n.scExpiry,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  // الكتابة اليدوية باقية؛ الأيقونة تملؤها من صورة الباركود
                  child: TextField(
                    controller: line.barcode,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.scBarcodeOpt,
                      suffixIcon: IconButton(
                        tooltip: context.l10n.scanTheBarcode,
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: AppColors.primary,
                        ),
                        onPressed: () => _scanBarcodeFor(line),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('lineCompany'),
              controller: line.company,
              decoration: InputDecoration(labelText: context.l10n.formCompany),
            ),
            if (line.type == ItemType.medicine) ...[
              const SizedBox(height: 6),
              TextField(
                key: const Key('lineCategory'),
                controller: line.category,
                decoration: InputDecoration(
                  labelText: context.l10n.formCategory,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// «📦 بالكرتون»: العدد داخل الكرتون، والسعر للكرتون أو للعلبة، ومعاينة
  /// فورية لما سيدخل المخزون. المعاينة تتبع الكمية والسعر والعدد حيّاً.
  Widget _packSection(_EditableLine line) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            key: const Key('packToggle'),
            value: line.packed,
            onChanged: (v) => setState(() => line.packed = v ?? false),
            title: Text(
              context.l10n.scPacked,
              style: const TextStyle(fontSize: 13.5),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
          ),
          if (line.packed) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('packSizeInput'),
                    controller: line.packSize,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: context.l10n.scPackSize,
                      errorText:
                          line.packSize.text.trim().isNotEmpty &&
                              line.validPackSize == null
                          ? context.l10n.scPackInvalid
                          : null,
                      errorMaxLines: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SegmentedButton<bool>(
                  key: const Key('packPriceMode'),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text(context.l10n.scPricePerPack),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(context.l10n.scPricePerUnit),
                    ),
                  ],
                  selected: {line.pricePerPack},
                  onSelectionChanged: (s) =>
                      setState(() => line.pricePerPack = s.first),
                ),
              ],
            ),
            ListenableBuilder(
              listenable: Listenable.merge([
                line.quantity,
                line.price,
                line.packSize,
              ]),
              builder: (context, _) {
                final size = line.validPackSize;
                if (size == null) return const SizedBox.shrink();
                final qty = parseLocalizedInt(line.quantity.text) ?? 0;
                final price = parseLocalizedNumber(line.price.text) ?? 0;
                final unit = line.pricePerPack ? price / size : price;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    context.l10n.scPackPreview(
                      formatPrice(qty * size),
                      formatMoney(unit),
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
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
              context.l10n.scExisting(existing.name, existing.quantity),
              AppColors.warning,
            ),
          if (duplicatesOther)
            _badge(context.l10n.scDuplicateLine, AppColors.primary),
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
          label: Text(
            t.labelIn(context.l10n),
            style: const TextStyle(fontSize: 11),
          ),
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
    this.company,
    this.expiryDate,
    this.packSize,
    this.pricePerPack = true,
  });

  final String name;
  final ItemType type;

  /// كما في الورقة: سعر الكرتون أو العلبة (انظر [pricePerPack]).
  final double price;

  /// كما في الورقة: عدد الكراتين إن كان [packSize] غير null.
  final int quantity;
  final String barcode;
  final String? category;
  final String? company;

  /// مللي ثانية، أو null إن لم تُقرأ صلاحية.
  final int? expiryDate;

  /// «📦 بالكرتون»: العدد داخل الكرتون (≥ 2)، وnull = مفرد.
  final int? packSize;

  /// [price] سعر الكرتون فيُقسم على [packSize] — أو سعر العلبة أصلاً.
  final bool pricePerPack;

  /// العلب التي تدخل المخزون.
  int get units => packSize == null ? quantity : quantity * packSize!;

  /// سعر شراء العلبة الواحدة.
  double get unitPrice =>
      packSize != null && pricePerPack ? price / packSize! : price;
}

/// نتيجة حفظ فاتورة — تُستعمل لعرض ملخّص صادق للمستخدم بدل عدّاد مبهم لا
/// يميّز مادة جديدة من مادة دُمجت مع مخزون موجود.
class InvoiceSaveResult {
  const InvoiceSaveResult({
    required this.items,
    required this.addedNew,
    required this.mergedExisting,
    required this.mergedWithinInvoice,
    this.records = const [],
  });

  final List<Medicine> items;

  /// نسخة أسطر الفاتورة كما حُفظت — لسجل الفواتير: كمية الفاتورة نفسها
  /// (لا رصيد المخزون بعد الدمج) ووجهتها في المخزون.
  final List<InvoiceRecordLine> records;

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

  // «📦 بالكرتون»: المخزون يُبنى بالعلب وسعر العلبة، والسجل بقيم الورقة.
  // سطر دُمج مع غيره داخل الفاتورة يُسجَّل بالعلب (لا ورقة واحدة تمثّله).
  final paperByKey = <String, InvoiceLineDraft>{};
  final packByKey = <String, (int, bool)>{};

  for (final raw in drafts) {
    if (raw.name.trim().isEmpty) continue;
    final packSize = raw.packSize != null && raw.packSize! >= 2
        ? raw.packSize
        : null;
    final paper = InvoiceLineDraft(
      name: raw.name,
      type: raw.type,
      price: raw.price < 0 ? 0 : raw.price,
      quantity: raw.quantity < 0 ? 0 : raw.quantity,
      barcode: raw.barcode.trim(),
      category: raw.category,
      company: raw.company,
      expiryDate: raw.expiryDate,
      packSize: packSize,
      pricePerPack: raw.pricePerPack,
    );
    final d = InvoiceLineDraft(
      name: paper.name,
      type: paper.type,
      price: paper.unitPrice,
      quantity: paper.units,
      barcode: paper.barcode,
      category: paper.category,
      company: paper.company,
      expiryDate: paper.expiryDate,
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
      paperByKey[fresh] = paper;
      if (packSize != null) packByKey[fresh] = (packSize, paper.pricePerPack);
      order.add(fresh);
      if (code != null) keyByCode[code] = fresh;
      keyByName.putIfAbsent(nameKey, () => fresh);
    } else {
      final k = key!;
      paperByKey.remove(k);
      if (packSize != null) packByKey[k] = (packSize, paper.pricePerPack);
      if (code != null) keyByCode[code] = k;
      keyByName.putIfAbsent(nameKey, () => k);
      byKey[k] = InvoiceLineDraft(
        name: prev.name,
        type: prev.type,
        price: d.price > 0 ? d.price : prev.price,
        quantity: prev.quantity + d.quantity,
        barcode: prev.barcode.isNotEmpty ? prev.barcode : d.barcode,
        category: prev.category ?? d.category,
        company: prev.company ?? d.company,
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
  final records = <InvoiceRecordLine>[];
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
    // بالاسم فقط إن لم يتعارض الباركودان: باركود مختلف = صنف آخر (طعم/لون)
    final existing =
        byBarcode ??
        store.findExistingByName(d.name, d.type, barcode: d.barcode);
    final ts = now.millisecondsSinceEpoch;
    final already = existing == null ? null : indexById[existing.id];
    final paper = paperByKey[key];
    final pack = packByKey[key];
    records.add(
      InvoiceRecordLine(
        name: d.name,
        // كما في الورقة (12 × 1,764) — والسطر المدموج بالعلب
        quantity: paper?.quantity ?? d.quantity,
        price: paper?.price ?? d.price,
        packSize: paper?.packSize,
        pricePerPack: paper?.pricePerPack ?? true,
        medicineId:
            existing?.id ?? 'inv_${ts}_${now.microsecond}_${items.length}',
        merged: existing != null,
      ),
    );
    if (already != null) {
      final prev = items[already];
      items[already] = prev.copyWith(
        price: d.price > 0 ? d.price : prev.price,
        quantity: prev.quantity + d.quantity,
        expiryDate: _earlier(prev.expiryDate, d.expiryDate),
        packSize: pack?.$1,
        packPriced: pack?.$2,
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
          // نملأ الفارغ فقط — لا نغيّر قيمة كتبها المستخدم سابقاً. نوع المادة
          // للأدوية وحدها؛ قيمة قديمة لمستلزم تبقى مخفية كما هي.
          category: type == ItemType.medicine
              ? (existing.category ?? d.category)
              : null,
          company: existing.company ?? d.company,
          expiryDate: expiry,
          // يُتذكّر للفاتورة التالية؛ سطر مفرد هذه المرة لا يمسح المحفوظ
          packSize: pack?.$1,
          packPriced: pack?.$2,
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
          category: d.type == ItemType.medicine ? d.category : null,
          company: d.company,
          expiryDate: d.expiryDate,
          packSize: pack?.$1,
          packPriced: pack?.$2,
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
    records: records,
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
    List<LineIssue> issues = const [],
  }) : issues = List.of(issues),
       bonus = source.bonus ?? 0,
       name = TextEditingController(text: source.name),
       price = TextEditingController(
         text: source.price == null ? '' : formatPriceInput(source.price!),
       ),
       // البونص يصل للرف فعلاً فيُضاف للكمية، ويُعرض «+N مجاناً» تحت الحقل
       quantity = TextEditingController(
         text: source.quantity == null && source.bonus == null
             ? ''
             : '${(source.quantity ?? 0) + (source.bonus ?? 0)}',
       ),
       barcode = TextEditingController(text: source.barcode ?? ''),
       expiry = TextEditingController(text: source.expiry ?? ''),
       category = TextEditingController(text: source.category ?? ''),
       company = TextEditingController(text: source.company ?? '');

  final _InvoicePage page;
  final List<LineIssue> issues;
  final int bonus;
  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController quantity;
  final TextEditingController barcode;
  final TextEditingController expiry;
  final TextEditingController category;
  final TextEditingController company;
  ItemType type;

  /// «📦 بالكرتون»: الكمية كراتين، و[packSize] العدد داخل الكرتون.
  bool packed = false;
  final TextEditingController packSize = TextEditingController();

  /// السعر المكتوب للكرتون (يُقسم) — أو للعلبة.
  bool pricePerPack = true;

  /// العدد داخل الكرتون إن كان صالحاً (2 فما فوق)، وإلا null.
  int? get validPackSize {
    final n = int.tryParse(packSize.text.trim());
    return n != null && n >= 2 ? n : null;
  }

  /// مفعّل والعدد غير صالح — يمنع الحفظ.
  bool get packInvalid => packed && validPackSize == null;

  void dispose() {
    packSize.dispose();
    name.dispose();
    price.dispose();
    quantity.dispose();
    barcode.dispose();
    expiry.dispose();
    category.dispose();
    company.dispose();
  }
}
