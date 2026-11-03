import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/medicine.dart';
import '../services/image_store.dart';
import '../state/invoice_store.dart';
import '../state/medicine_store.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/medicine_card.dart' show formatPrice;
import '../widgets/product_image.dart';
import '../widgets/smooth_route.dart';
import 'invoices_screen.dart';

String _date(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}/${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}';
}

/// «متبقٍ N يوماً» أو «منتهية منذ N يوماً» — بالأيام التقويمية.
String _expiryLeft(DateTime expiry) {
  final now = DateTime.now();
  final days = DateTime(
    expiry.year,
    expiry.month,
    expiry.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (days < 0) return 'منتهية منذ ${-days} يوماً';
  if (days == 0) return 'تنتهي اليوم';
  return 'متبقٍ $days يوماً';
}

/// صفحة تفاصيل المادة — تتمدّد من بطاقتها (`OpenContainer` في الرئيسية).
///
/// تقرأ المادة **حيّةً** من المخزن بمعرّفها: تعديل من النموذج أو −/+ أو
/// مزامنة من الهاتف الآخر يظهر فوراً، وحذفها من أي مكان يغلق الصفحة.
class MedicineDetailScreen extends StatefulWidget {
  const MedicineDetailScreen({
    super.key,
    required this.store,
    required this.medicineId,
    required this.onEdit,
    required this.onDelete,
    this.invoices,
    this.share,
  });

  final MedicineStore store;
  final String medicineId;
  final VoidCallback onEdit;

  /// يُستدعى بعد إغلاق الصفحة — الحذف مع التراجع شأن الرئيسية.
  final VoidCallback onDelete;

  /// سجل الفواتير — يُحقن في الاختبار، وإلا [InvoiceStore.instance].
  final InvoiceStore? invoices;

  /// بديل المشاركة للاختبار، وإلا SharePlus.
  final Future<void> Function(String text)? share;

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  bool _closing = false;

  InvoiceStore get _invoices => widget.invoices ?? InvoiceStore.instance;

  Medicine? get _current {
    for (final m in widget.store.all) {
      if (m.id == widget.medicineId) return m;
    }
    return null;
  }

  /// حُذفت من مكان آخر (مزامنة، دمج): تُغلق مرة واحدة برسالة.
  void _closeGone() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop();
      messenger?.showSnackBar(
        const SnackBar(content: Text('حُذفت هذه المادة')),
      );
    });
  }

  /// من المادة الحالية في المخزن لا من قيمة محفوظة — ضغطات سريعة متتالية
  /// لا تُسقط زيادة.
  Future<void> _changeQty(int delta) async {
    final m = _current;
    if (m == null) return;
    final next = m.quantity + delta;
    if (next < 0) return;
    await widget.store.save(
      m.copyWith(
        quantity: next,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  String _shareText(Medicine m) {
    final expiry = m.expiry;
    return [
      m.name,
      'السعر: ${formatPrice(m.price)} د.ع',
      'الكمية: ${m.quantity}',
      if (expiry != null) 'الصلاحية: ${_date(expiry.millisecondsSinceEpoch)}',
      if (m.barcode.isNotEmpty) 'الباركود: ${m.barcode}',
      if ((m.company ?? '').trim().isNotEmpty) 'الشركة: ${m.company!.trim()}',
    ].join('\n');
  }

  Future<void> _share(Medicine m) async {
    final text = _shareText(m);
    final share = widget.share;
    if (share != null) return share(text);
    await SharePlus.instance.share(ShareParams(text: text));
  }

  void _delete() {
    _closing = true;
    Navigator.of(context).pop();
    widget.onDelete();
  }

  void _viewImage(String path) {
    Navigator.of(context).push(
      SmoothPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black),
          body: Center(
            child: InteractiveViewer(
              maxScale: 6,
              child: Hero(
                tag: 'medicine-image-${widget.medicineId}',
                child: Image.file(File(path)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.store, _invoices]),
      builder: (context, _) {
        final m = _current;
        if (m == null) {
          _closeGone();
          return const Scaffold(body: SizedBox.shrink());
        }
        return Scaffold(
          // معتمة بلون حاوية OpenContainer نفسه (فلا يتغيّر المظهر): أثناء
          // الرجوع ترسم الحاوية البطاقة مكبّرة خلف الصفحة، والشريط العلوي
          // الشفاف كان يُظهرها فوق شريط العنوان — رُصد في لقطات الهاتف.
          backgroundColor: AppColors.bgDark,
          appBar: GlassAppBar(
            title: Text(m.type.label),
            actions: [
              IconButton(
                key: const Key('detailShare'),
                tooltip: 'مشاركة',
                icon: const Icon(Icons.share_rounded),
                onPressed: () => _share(m),
              ),
              IconButton(
                key: const Key('detailEdit'),
                tooltip: 'تعديل',
                icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                onPressed: widget.onEdit,
              ),
              IconButton(
                key: const Key('detailDelete'),
                tooltip: 'حذف',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                ),
                onPressed: _delete,
              ),
            ],
          ),
          body: Stack(
            children: [
              const Positioned.fill(child: AuroraBackground()),
              SafeArea(child: _content(m)),
            ],
          ),
        );
      },
    );
  }

  Widget _content(Medicine m) {
    final imagePath = ImageStore.fullPathSync(m.imagePath);
    final expiry = m.expiry;
    final history = _invoices.invoicesFor(m.id);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        GlassSurface(
          padding: const EdgeInsets.all(10),
          child: imagePath == null
              ? SizedBox(
                  height: 160,
                  child: Center(
                    child: Text(
                      m.type == ItemType.supply ? '🩹' : '💊',
                      style: const TextStyle(fontSize: 64),
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: () => _viewImage(imagePath),
                  child: AdaptiveProductImage(path: imagePath),
                ),
        ),
        const SizedBox(height: 14),
        Text(
          m.name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: _statusBadges(m)),
        const SizedBox(height: 14),
        _numbers(m),
        const SizedBox(height: 14),
        GlassSurface(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (expiry != null)
                _row(
                  '📅 الصلاحية',
                  '${_date(expiry.millisecondsSinceEpoch)} · '
                      '${_expiryLeft(expiry)}',
                  color: m.isExpired || m.isExpiringSoon
                      ? AppColors.warning
                      : null,
                ),
              if (m.barcode.isNotEmpty)
                _row(
                  '📊 الباركود',
                  m.barcode,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: m.barcode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('نُسخ الباركود')),
                    );
                  },
                ),
              if ((m.company ?? '').trim().isNotEmpty)
                _row('🏭 الشركة', m.company!.trim()),
              if (m.type == ItemType.medicine &&
                  (m.category ?? '').trim().isNotEmpty)
                _row('🧪 نوع المادة', m.category!.trim()),
              _row('🗂️ القسم', m.type.label),
              _row('➕ الإضافة', 'أُضيفت ${_date(m.createdAt)}'),
              _row('🕓 آخر تعديل', _date(m.updatedAt)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '🧾 سجل الفواتير',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (history.isEmpty)
          const Text(
            'لا فواتير محفوظة لهذه المادة',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          for (final h in history)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => Navigator.of(context).push(
                    SmoothPageRoute<void>(
                      builder: (_) => InvoiceDetailScreen(
                        invoice: h.invoice,
                        store: _invoices,
                      ),
                    ),
                  ),
                  child: GlassSurface(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                h.invoice.supplier ?? 'مجهّز غير معروف',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _date(h.invoice.sortDate),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${h.line.quantity} × ${formatPrice(h.line.price)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  List<Widget> _statusBadges(Medicine m) {
    Widget badge(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
    return [
      if (m.isExpired)
        badge('⛔ منتهية الصلاحية', AppColors.danger)
      else if (m.isExpiringSoon)
        badge('⏳ قاربت الانتهاء', AppColors.warning),
      if (m.isSoldOut)
        badge('🚫 نافدة', AppColors.danger)
      else if (m.isLowStock)
        badge('⚠️ مخزون منخفض', AppColors.warning),
      if (m.isIncomplete) badge('📝 بيانات ناقصة', AppColors.warning),
    ];
  }

  Widget _numbers(Medicine m) {
    Widget cell(String label, Widget value) => Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          value,
        ],
      ),
    );
    const big = TextStyle(fontSize: 17, fontWeight: FontWeight.w800);
    return GlassSurface(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cell('السعر', Text('${formatPrice(m.price)} د.ع', style: big)),
          cell(
            'الكمية',
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  key: const Key('qtyPlus'),
                  child: IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'زيادة',
                    icon: const Icon(Icons.add_rounded, size: 18),
                    onPressed: () => _changeQty(1),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${m.quantity}',
                    key: const Key('detailQuantity'),
                    style: big,
                  ),
                ),
                SizedBox(
                  key: const Key('qtyMinus'),
                  child: IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'إنقاص',
                    icon: const Icon(Icons.remove_rounded, size: 18),
                    onPressed: m.quantity > 0 ? () => _changeQty(-1) : null,
                  ),
                ),
              ],
            ),
          ),
          cell(
            'قيمة المخزون',
            Text(
              '${formatPrice(m.price * m.quantity)} د.ع',
              style: big.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color, VoidCallback? onTap}) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
          if (onTap != null)
            const Icon(
              Icons.copy_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}
