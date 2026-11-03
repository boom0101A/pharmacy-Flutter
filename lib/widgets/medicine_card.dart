import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// intl يعرّف TextDirection خاصاً به ويتعارض مع تعريف Flutter
import 'package:intl/intl.dart' hide TextDirection;

import '../models/medicine.dart';
import '../services/image_store.dart';
import '../theme.dart';
import '../util/money.dart';
import '../l10n/l10n.dart';

final _priceFormat = NumberFormat.decimalPattern('ar');

String formatPrice(num value) => _priceFormat.format(value);

class MedicineCard extends StatelessWidget {
  const MedicineCard({
    super.key,
    required this.medicine,
    required this.onEdit,
    required this.onDelete,
    required this.onOpen,
    this.index = 0,
    this.animate = true,
  });

  final Medicine medicine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// يفتح صفحة التفاصيل — الضغط على البطاقة أو صورتها.
  final VoidCallback onOpen;

  /// ترتيب البطاقة — لتأخير ظهورها قليلاً فيبدو الدخول متتابعاً.
  final int index;

  /// هل هذه أول مرة تظهر فيها البطاقة؟
  ///
  /// بدون هذا الشرط كانت الحركة تتكرر كلما أعاد GridView تدوير البطاقة عند
  /// التمرير لأعلى وأسفل، فيبدو المحتوى وامضاً لا سلساً.
  final bool animate;

  /// عرض فك الترميز بالبكسل الفيزيائي.
  ///
  /// صور الكاميرا تصل إلى 1200 بكسل، والبطاقة لا تتجاوز 200 نقطة منطقية.
  /// فك الترميز بالحجم الكامل يستهلك ~7 ميجابايت لكل صورة ويقطّع التمرير؛
  /// 500 بكسل تكفي أحدّ الشاشات وتخفض الاستهلاك إلى أقل من الخُمس.
  static const _decodeWidth = 500;

  @override
  Widget build(BuildContext context) {
    // كل بطاقة طبقة رسم مستقلة: تحريك واحدة لا يعيد رسم الشبكة كلها
    final card = RepaintBoundary(child: _buildCard(context));

    // من أطفأ الحركة في إعدادات إمكانية الوصول لا تُفرض عليه
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final moving = animate && !reduceMotion;

    // ظهور متدرّج خفيف: شفافية + إزاحة بسيطة. بلا حزم ولا رسم إضافي.
    //
    // الغلاف موجود دائماً، وبلا حركة يبدأ من نهايته (1→1): لو أُزيل حين
    // تصير animate=false في إعادة بناء الشبكة لتغيّر شكل الشجرة فأُعيد إنشاء
    // البطاقة وصورتها — وميض أعلى البطاقة عند الرجوع من التفاصيل.
    final delayed = (index.clamp(0, 8)) * 45;
    return TweenAnimationBuilder<double>(
      key: ValueKey(medicine.id),
      tween: Tween(begin: moving ? 0 : 1, end: 1),
      duration: Duration(milliseconds: 300 + delayed),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - t)),
          // تكبير طفيف جداً — يعطي إحساس «الدخول» بلا مبالغة
          child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
        ),
      ),
      child: card,
    );
  }

  /// البطاقة كلها (والصورة) تفتح التفاصيل؛ أزرار التعديل والحذف تبقى لها.
  /// لون النص يُحدَّد هنا لا يُورَث: حزمة animations 3 تبني `Material` من
  /// حزمة `material_ui` المنفصلة، و`Theme` الخاص بها لا يرى سمة التطبيق
  /// فيرجع إلى السمة الفاتحة الافتراضية — نص داكن فوق البطاقة ساكنةً وأثناء
  /// الانتقال (ظهرت الأسماء سوداء على الهاتف).
  Widget _buildCard(BuildContext context) => DefaultTextStyle.merge(
    style: const TextStyle(color: AppColors.textPrimary),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: _cardBody(context),
    ),
  );

  Widget _cardBody(BuildContext context) {
    final imagePath = ImageStore.fullPathSync(medicine.imagePath);
    // كمية صفر بلا سعر: تسجيل لم يكتمل، لا مادة نفدت
    final unfinished = medicine.isOutOfStock && medicine.price <= 0;
    final qtyColor = unfinished
        ? AppColors.warning
        : medicine.isOutOfStock
        ? AppColors.danger
        : medicine.isLowStock
        ? AppColors.warning
        : AppColors.success;

    // بطاقة زجاجية بلا ضبابية حقيقية (قرار الأداء): شفافية + حدّ + لمعان
    // قطري (`.card::after` في ملف التصميم) — قائمة من ألف مادة تبقى سلسة.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        // بلا ظل: ظل ضبابي تحت كل بطاقة ظاهرة كان يُعاد في كل إطار تمرير
        // (Impeller بلا ذاكرة نقطية)، وأثره المرئي ضئيل على الخلفية الداكنة.
      ),
      position: DecorationPosition.background,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment(0.2, 0.2),
            colors: [Color(0x1FFFFFFF), Color(0x00FFFFFF)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // الصورة تأخذ المساحة المتبقية — يمنع الفيضان مهما كان حجم الخط.
            // مؤطّرة داخل البطاقة بهامش 6 وزوايا 18 كما في ملف التصميم.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: double.infinity,
                    child: imagePath != null
                        // كاملة باتجاهها: العلبة العمودية لا تُقصّ لشريط أفقي
                        // من وسطها. الانتقال إلى التفاصيل يتولّاه
                        // OpenContainer، فلا Hero هنا.
                        ? Image.file(
                            File(imagePath),
                            fit: BoxFit.contain,
                            cacheWidth: _decodeWidth,
                            // ظهور ناعم بدل قفزة الصورة عند اكتمال فك الترميز
                            frameBuilder: (_, child, frame, wasSyncLoaded) {
                              if (wasSyncLoaded) return child;
                              return AnimatedOpacity(
                                opacity: frame == null ? 0 : 1,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                                child: child,
                              );
                            },
                            errorBuilder: (_, _, _) =>
                                _ImagePlaceholder(type: medicine.type),
                          )
                        : _ImagePlaceholder(type: medicine.type),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // الأرقام تُعرض من اليسار لليمين حتى لا ينكسر ترتيب الباركود
                  if (medicine.barcode.isEmpty)
                    Text(
                      context.l10n.cardNoBarcode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: AppColors.warning),
                    )
                  else
                    Row(
                      children: [
                        Text(
                          context.l10n.cardBarcode,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            medicine.barcode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.ltr,
                            // الأرقام LTR دائماً، ومحاذاتها لبداية سطر الواجهة
                            textAlign:
                                Directionality.of(context) == TextDirection.rtl
                                ? TextAlign.right
                                : TextAlign.left,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_details(medicine) case final details?) ...[
                    const SizedBox(height: 4),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  if (medicine.isExpired || medicine.isExpiringSoon) ...[
                    const SizedBox(height: 5),
                    _ExpiryBadge(medicine: medicine),
                  ],
                  const SizedBox(height: 8),
                  // السعر يأخذ ضعف مساحة الكمية: «١٠٥٬٠٠٠ د.ع» أطول بكثير من «3»
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _Stat(
                          label: context.l10n.price,
                          value: formatMoney(medicine.price),
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: _Stat(
                          label: context.l10n.quantity,
                          value: unfinished
                              ? context.l10n.cardIncomplete
                              : medicine.isOutOfStock
                              ? context.l10n.cardOut
                              : medicine.quantity.toString(),
                          color: qtyColor,
                          alignEnd: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // أيقونات فقط في كبسولتين زجاجيتين (`.card .actions` في ملف التصميم)
            SizedBox(
              height: 46,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.edit_rounded,
                        color: AppColors.primary,
                        tooltip: context.l10n.edit,
                        onPressed: onEdit,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.delete_outline_rounded,
                        color: AppColors.danger,
                        tooltip: context.l10n.delete,
                        onPressed: onDelete,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// تنبيه الصلاحية — أحمر للمنتهي، برتقالي لما يقترب.
class _ExpiryBadge extends StatelessWidget {
  const _ExpiryBadge({required this.medicine});

  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    final expired = medicine.isExpired;
    final color = expired ? AppColors.danger : AppColors.warning;
    final e = medicine.expiry!;
    final label = expired
        ? context.l10n.expired
        : context.l10n.expiresOn(
            '${e.year}/${e.month.toString().padLeft(2, '0')}',
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '⏳ $label',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// زر أيقونة يملأ نصف عرض البطاقة — مساحة لمس مريحة رغم صغر الأيقونة.
class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.tooltip,
    child: Material(
      color: const Color(0x0DFFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onPressed();
        },
        onHighlightChanged: (v) => setState(() => _down = v),
        splashColor: widget.color.withValues(alpha: 0.18),
        highlightColor: widget.color.withValues(alpha: 0.08),
        child: Center(
          // انكماش لحظي تحت الإصبع — تأكيد لمسي بلا صوت ولا تأخير
          child: AnimatedScale(
            scale: _down ? 0.82 : 1,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: Icon(widget.icon, size: 20, color: widget.color),
          ),
        ),
      ),
    ),
  );
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.type});

  final ItemType type;

  @override
  // توهّج تيل خفيف بدل الخلفية المصمتة (`.card .img` في ملف التصميم)
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(-0.4, -0.6),
        radius: 1.1,
        colors: [Color(0x382DD4BF), Color(0x0F38BDF8), Color(0x08FFFFFF)],
        stops: [0, .6, 1],
      ),
    ),
    alignment: Alignment.center,
    child: Text(
      type == ItemType.supply ? '🩹' : '💊',
      style: const TextStyle(fontSize: 40),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
      ),
      // الرقم يصغر ليتّسع بدل أن يُقصّ: «١٢٣٬٤٥٦ د.ع» مقصوصة بلا معنى،
      // ومصغّرة قليلاً لا تزال مقروءة تماماً.
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignEnd
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Text(
          value,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    ],
  );
}

/// «🧪 نوع المادة · 🏭 الشركة» — نوع المادة للأدوية فقط.
String? _details(Medicine m) {
  final parts = [
    if (m.type == ItemType.medicine && (m.category ?? '').trim().isNotEmpty)
      '🧪 ${m.category!.trim()}',
    if ((m.company ?? '').trim().isNotEmpty) '🏭 ${m.company!.trim()}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
