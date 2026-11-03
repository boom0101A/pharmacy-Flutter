import 'dart:io';

import 'package:flutter/material.dart';

import '../models/invoice.dart';
import '../services/image_store.dart';
import '../state/invoice_store.dart';
import '../theme.dart';
import '../util/money.dart';
import '../widgets/glass.dart';
import '../widgets/medicine_card.dart' show formatPrice;
import '../widgets/smooth_route.dart';
import '../l10n/l10n.dart';

String _date(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}/${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}';
}

/// التاريخ كما طُبع إن لم يُفهم، وإلا المحوَّل، وإلا يوم الحفظ.
String _shownDate(Invoice i) =>
    i.dateMs != null ? _date(i.dateMs!) : (i.dateText ?? _date(i.createdAt));

/// «📚 الفواتير» — سجل فواتير المجهّزين للرجوع إليها. للعرض فقط: لا شيء هنا
/// يغيّر المخزون.
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key, required this.store});

  final InvoiceStore store;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_changed);
    if (widget.store.all.isEmpty) widget.store.load();
  }

  @override
  void dispose() {
    widget.store.removeListener(_changed);
    _search.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  List<Invoice> get _shown {
    final k = _search.text.trim().toLowerCase();
    if (k.isEmpty) return widget.store.all;
    return [
      for (final i in widget.store.all)
        if ((i.supplier ?? '').toLowerCase().contains(k) ||
            (i.number ?? '').toLowerCase().contains(k))
          i,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final sum = shown.fold<double>(0, (s, i) => s + (i.total ?? i.linesTotal));
    return Scaffold(
      appBar: GlassAppBar(title: Text(context.l10n.invTitle)),
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: TextField(
                    key: const Key('invoiceSearch'),
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: context.l10n.invSearchHint,
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    context.l10n.invSummary(
                      shown.length,
                      formatMoney(sum, iqdOnly: true),
                    ),
                    key: const Key('invoicesSummary'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: shown.isEmpty
                      ? Center(
                          child: Text(
                            context.l10n.invEmpty,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: shown.length,
                          itemBuilder: (_, i) => _tile(shown[i]),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(Invoice inv) {
    final thumb = inv.imageFiles.isEmpty
        ? null
        : ImageStore.invoicePathSync(inv.imageFiles.first);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('invoice-${inv.id}'),
          borderRadius: BorderRadius.circular(22),
          onTap: () => Navigator.of(context).push(
            SmoothPageRoute<void>(
              builder: (_) =>
                  InvoiceDetailScreen(invoice: inv, store: widget.store),
            ),
          ),
          child: GlassSurface(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: thumb == null
                        ? const ColoredBox(
                            color: AppColors.glass,
                            child: Center(
                              child: Text('🧾', style: TextStyle(fontSize: 24)),
                            ),
                          )
                        : Image.file(
                            File(thumb),
                            fit: BoxFit.cover,
                            cacheWidth: 160,
                            errorBuilder: (_, _, _) =>
                                const Center(child: Text('🧾')),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.supplier ?? context.l10n.unknownSupplier,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_shownDate(inv)} · ${context.l10n.invItems(inv.itemsCount)}'
                        '${inv.number == null ? '' : context.l10n.invNumberShort(inv.number!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatMoney(inv.total ?? inv.linesTotal, iqdOnly: true),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// تفاصيل فاتورة: صفحاتها (تُكبَّر)، رأسها، وأسطرها كما حُفظت.
class InvoiceDetailScreen extends StatelessWidget {
  const InvoiceDetailScreen({
    super.key,
    required this.invoice,
    required this.store,
  });

  final Invoice invoice;
  final InvoiceStore store;

  Future<void> _delete(BuildContext context) async {
    final ok = await showGlassDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(context.l10n.invDeleteTitle),
        content: Text(
          context.l10n.invDeleteBody,
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(context.l10n.cdDeleteConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await store.delete(invoice);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    final pages = [
      for (final f in inv.imageFiles) ?ImageStore.invoicePathSync(f),
    ];
    final printed = inv.total;
    final off =
        printed != null &&
        printed > 0 &&
        (inv.linesTotal - printed).abs() > printed * .01;
    return Scaffold(
      appBar: GlassAppBar(
        title: Text(inv.supplier ?? context.l10n.invoice),
        actions: [
          IconButton(
            key: const Key('deleteInvoice'),
            tooltip: context.l10n.invDeleteRecord,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.danger,
            ),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (pages.isEmpty)
                  GlassSurface(
                    key: Key('noInvoiceImage'),
                    padding: EdgeInsets.all(14),
                    child: Text(
                      context.l10n.invPhotoElsewhere,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  for (final path in pages)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          SmoothPageRoute<void>(
                            builder: (_) => Scaffold(
                              backgroundColor: Colors.black,
                              appBar: AppBar(backgroundColor: Colors.black),
                              body: Center(
                                child: InteractiveViewer(
                                  maxScale: 6,
                                  child: Image.file(File(path)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(path),
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => SizedBox(
                              height: 60,
                              child: Center(
                                child: Text(context.l10n.invPhotoFailed),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                GlassSurface(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(context.l10n.invRowSupplier, inv.supplier ?? '—'),
                      _row(context.l10n.invRowDate, _shownDate(inv)),
                      if (inv.number != null)
                        _row(context.l10n.invRowNumber, inv.number!),
                      _row(
                        context.l10n.invRowTotal,
                        printed == null
                            ? '—'
                            : formatMoney(printed, iqdOnly: true),
                      ),
                      _row(
                        context.l10n.invRowLinesTotal,
                        formatMoney(inv.linesTotal, iqdOnly: true),
                        color: off ? AppColors.warning : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.invItems(inv.itemsCount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                for (final l in inv.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GlassSurface(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${l.quantity} × ${formatPrice(l.price)} = '
                                  '${formatMoney(l.total, iqdOnly: true)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            l.merged
                                ? context.l10n.invLineMerged
                                : context.l10n.invLineNew,
                            style: TextStyle(
                              fontSize: 11,
                              color: l.merged
                                  ? AppColors.warning
                                  : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ),
      ],
    ),
  );
}
