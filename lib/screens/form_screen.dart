import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/medicine.dart';
import '../services/drug_lookup.dart';
import '../services/gs1_parser.dart';
import '../services/image_store.dart';
import '../state/medicine_store.dart';
import '../theme.dart';
import '../widgets/medicine_card.dart' show formatPrice;
import '../widgets/smooth_route.dart';
import '../util/number_parse.dart';
import 'scanner_screen.dart';

/// شاشة إضافة/تعديل دواء.
class MedicineFormScreen extends StatefulWidget {
  const MedicineFormScreen({
    super.key,
    required this.store,
    this.existing,
    this.openScannerOnStart = false,
    this.initialType = ItemType.medicine,
  });

  final MedicineStore store;
  final Medicine? existing;

  /// فتح الماسح فوراً عند الدخول (مسار "امسح ثم أضف").
  final bool openScannerOnStart;

  /// القسم الذي فُتح منه النموذج — يحدد النوع الابتدائي للمادة الجديدة.
  final ItemType initialType;

  @override
  State<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends State<MedicineFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _barcode;
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _quantity;

  /// الشكل الصيدلاني — خاص بالمستلزمات فقط.
  late final TextEditingController _category;

  String? _imageFileName;
  bool _looking = false;
  bool _saving = false;

  DateTime? _expiry;

  late ItemType _type;
  bool get _isSupply => _type == ItemType.supply;

  /// نتيجة آخر مسح — لعرض الصلاحية ورقم الوجبة إن كان الرمز من نوع GS1.
  Gs1Result? _lastScan;

  /// السجل الذي نعدّله فعلياً — قد يتحوّل أثناء الجلسة إذا كشف المسح أن
  /// الباركود موجود مسبقاً، فنعدّل الموجود بدل إنشاء نسخة ثانية منه.
  Medicine? _target;

  bool get _isEdit => _target != null;

  @override
  void initState() {
    super.initState();
    final m = _target = widget.existing;
    _barcode = TextEditingController(text: m?.barcode ?? '');
    _name = TextEditingController(text: m?.name ?? '');
    _price = TextEditingController(text: m == null ? '' : _trimNumber(m.price));
    _quantity = TextEditingController(
      text: m == null ? '' : m.quantity.toString(),
    );
    _category = TextEditingController(text: m?.category ?? '');
    _imageFileName = m?.imagePath;
    _expiry = m?.expiry;
    _type = m?.type ?? widget.initialType;

    if (widget.openScannerOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
    }
  }

  @override
  void dispose() {
    _barcode.dispose();
    _name.dispose();
    _price.dispose();
    _quantity.dispose();
    _category.dispose();
    super.dispose();
  }

  static String _trimNumber(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  void _toast(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ---------- المسح والملء التلقائي ----------

  Future<void> _scan() async {
    final code = await Navigator.of(
      context,
    ).push<String>(SmoothPageRoute(builder: (_) => const ScannerScreen()));
    if (code == null || !mounted) return;

    // رموز GS1 تحمل الرقم التسلسلي ورقم الوجبة إضافة للباركود.
    // بدون تفكيكها تصبح كل علبة دواءً منفصلاً ولا تطابق أي قاعدة بيانات.
    final parsed = Gs1Parser.parse(code);
    _lastScan = parsed;
    _barcode.text = parsed.barcode;
    // الصلاحية المستخرجة من الرمز تُحفظ فعلياً لا تُعرض فقط
    if (parsed.expiryDate != null) _expiry ??= parsed.expiryDate;
    await _autoFill(parsed.barcode);
  }

  Future<void> _autoFill(String code) async {
    setState(() => _looking = true);

    // الباركود موجود في مخزنك؟ إذن هذه إعادة تعبئة لا مادة جديدة.
    // بدون هذا التحويل كان كل مسح لدواء موجود يولّد سجلاً مكرراً.
    final existing = await widget.store.findByBarcode(code);
    if (existing != null && existing.id != _target?.id) {
      if (!mounted) return;
      setState(() {
        _looking = false;
        _adoptExisting(existing);
      });
      _toast(
        'هذه المادة مسجّلة لديك — تعدّل الآن سجلها الحالي',
        color: AppColors.warning,
      );
      return;
    }

    final info = await DrugLookup.byBarcode(code);
    if (!mounted) return;
    setState(() => _looking = false);

    if (info == null) {
      _toast('تم قراءة الباركود: $code — لم نجد بياناته، أكمل الحقول يدوياً');
      return;
    }

    setState(() {
      if (_name.text.trim().isEmpty && info.name.isNotEmpty) {
        _name.text = info.name;
      }
      if (info.source == LookupSource.local) {
        if (_price.text.trim().isEmpty && info.price != null) {
          _price.text = _trimNumber(info.price!);
        }
        if (_quantity.text.trim().isEmpty && info.quantity != null) {
          _quantity.text = info.quantity.toString();
        }
      }
      _imageFileName ??= info.imageFileName;
    });

    final confirmed = info.confirmations != null && info.confirmations! > 1
        ? ' (أكّدته ${info.confirmations} صيدليات)'
        : '';
    _toast(
      'تم جلب بيانات الدواء من ${info.sourceLabel}$confirmed ✅',
      color: AppColors.success,
    );
  }

  /// تحويل النموذج إلى تعديل سجل قائم — يُستدعى داخل setState.
  void _adoptExisting(Medicine m) {
    _target = m;
    _barcode.text = m.barcode;
    _name.text = m.name;
    _price.text = _trimNumber(m.price);
    _quantity.text = m.quantity.toString();
    _imageFileName = m.imagePath;
    _expiry ??= m.expiry;
    _type = m.type;
  }

  // ---------- الصورة ----------

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null) return;
    final saved = await ImageStore.saveFile(File(picked.path));
    if (!mounted) return;
    final replaced = _imageFileName;
    setState(() => _imageFileName = saved);
    // الصورة المستبدَلة لم تعد مشار إليها من أي مكان
    if (replaced != null && replaced != _target?.imagePath) {
      unawaited(ImageStore.deleteFile(replaced));
    }
  }

  /// إزالة الصورة تحذف ملفها إن لم يكن هو صورة السجل المحفوظ أصلاً
  /// (المحفوظة يحذفها `store.delete` أو استبدال ناجح عند الحفظ).
  void _removeImage() {
    final dropped = _imageFileName;
    setState(() => _imageFileName = null);
    if (dropped != null && dropped != _target?.imagePath) {
      unawaited(ImageStore.deleteFile(dropped));
    }
  }

  /// إضافة كمية واردة إلى الرصيد الحالي بدل استبداله بالخطأ.
  ///
  /// السيناريو الشائع: أخوك يمسح باركوداً موجوداً بعد فاتورة توريد جديدة.
  /// حقل الكمية يعرض الرصيد الحالي (4 مثلاً)؛ كتابة «10» فوقه تستبدله فيصبح
  /// 10 لا 14. هذا الزر يفتح إدخالاً للوارد فقط ويجمعه هو مع الرصيد.
  Future<void> _addQuantity() async {
    final controller = TextEditingController();
    final added = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('📦 إضافة كمية واردة'),
        content: TextField(
          key: const Key('addQuantityDialogField'),
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'العدد الوارد في الفاتورة',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, parseLocalizedInt(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, parseLocalizedInt(controller.text)),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (added == null || added <= 0 || !mounted) return;

    final current = parseLocalizedInt(_quantity.text) ?? 0;
    setState(() => _quantity.text = (current + added).toString());
    _toast('أُضيف $added — الرصيد الآن ${current + added}');
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? DateTime(now.year + 1, now.month),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 15),
      helpText: 'تاريخ انتهاء الصلاحية',
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  // ---------- الحفظ ----------

  Future<void> _save() async {
    // حارس ضغط مزدوج: بلا هذا السطر كان نقران سريعان على "حفظ" (شائع على
    // شاشات بطيئة الاستجابة) يُنفّذان استدعاءين متوازيين لـ _save، وبما أن
    // كل استدعاء يولّد معرّفاً مختلفاً (microsecond) كانت تُحفظ مادتان
    // منفصلتان بنفس البيانات تماماً بلا أي رسالة خطأ.
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    // نص غير قابل للقراءة كرقم يُرفض صراحةً — حفظه صفراً كان يدهس السعر
    // الحقيقي لمادة موجودة بلا أي تنبيه. الحقل الفارغ يبقى صفراً كما كان.
    final parsedPrice = parseLocalizedNumber(_price.text);
    final parsedQty = parseLocalizedInt(_quantity.text);
    if (_price.text.trim().isNotEmpty && parsedPrice == null) {
      _toast('السعر غير صالح — اكتب أرقاماً فقط', color: AppColors.danger);
      return;
    }
    if (_quantity.text.trim().isNotEmpty && parsedQty == null) {
      _toast('الكمية غير صالحة — اكتب عدداً صحيحاً', color: AppColors.danger);
      return;
    }

    final typedBarcode = _barcode.text.trim();

    // سجل جديد بباركود يملكه سجل آخر = فقدان بيانات صامت، لا مجرد تكرار.
    //
    // القاعدة تحمل فهرساً فريداً على barcode، و`upsert` يستعمل
    // ConflictAlgorithm.replace — وسلوك SQLite لـINSERT OR REPLACE عند تعارض
    // قيد فريد هو **حذف الصف المتعارض** ثم الإدراج، لا رمي خطأ. فكتابة
    // باركود موجود يدوياً (بلا مسح، وبلا ضغط «تم» فلا يعمل _autoFill) كانت
    // تمحو الدواء القديم بكميته وسعره وتضع مكانه السجل الجديد بلا أي تحذير.
    // الفحص هنا هو ما يمنع ذلك — القيد وحده لا «يحمي»، بل يحذف بصمت.
    // وعند التعديل أيضاً: تغيير باركود مادة إلى باركود مادة أخرى يحذف الأخرى
    // بالطريقة نفسها. هنا لا نتبنّاها (تضيع تعديلات المستخدم) بل نرفض بتنبيه.
    if (_target != null && typedBarcode.isNotEmpty) {
      final owner = await widget.store.findByBarcode(typedBarcode);
      if (!mounted) return;
      if (owner != null && owner.id != _target!.id) {
        await _showBarcodeTaken(owner);
        return;
      }
    }

    if (_target == null && typedBarcode.isNotEmpty) {
      final byBarcode = await widget.store.findByBarcode(typedBarcode);
      if (!mounted) return;
      if (byBarcode != null) {
        final adopt = await _confirmDuplicateBarcode(byBarcode);
        if (!mounted || adopt != true) return;
        setState(() => _adoptExisting(byBarcode));
        return; // صار تعديلاً للسجل الموجود بدل استبداله صامتاً
      }
    }

    // مادة جديدة بلا باركود قد تكرّر اسم مادة موجودة فعلاً — الاسم وحده
    // (حالة أغلب المستلزمات) لا يحميه أي قيد في القاعدة.
    if (_target == null && typedBarcode.isEmpty) {
      final match = widget.store.findExistingByName(_name.text.trim(), _type);
      if (match != null) {
        final choice = await _confirmDuplicateName(match);
        if (!mounted || choice == null) return;
        if (choice) {
          setState(() => _adoptExisting(match));
          return; // يعدّل السجل الموجود الآن بدل حفظ سجل جديد فوراً
        }
        // choice == false: تابع الحفظ كسجل منفصل عن قصد المستخدم
      }
    }

    setState(() => _saving = true);
    final now = DateTime.now().millisecondsSinceEpoch;
    // سالب مرفوض هنا أيضاً — لا شيء يمنع كتابته يدوياً في الحقل
    final enteredPrice = (parsedPrice ?? 0).clamp(0, double.infinity);
    final enteredQty = (parsedQty ?? 0).clamp(0, 1 << 31);
    final medicine =
        _target?.copyWith(
          barcode: _barcode.text.trim(),
          name: _name.text.trim(),
          price: enteredPrice.toDouble(),
          quantity: enteredQty,
          imagePath: _imageFileName,
          clearImage: _imageFileName == null,
          expiryDate: _expiry?.millisecondsSinceEpoch,
          clearExpiry: _expiry == null,
          type: _type,
          category: _isSupply ? _category.text.trim() : null,
          clearCategory: !_isSupply || _category.text.trim().isEmpty,
          updatedAt: now,
        ) ??
        Medicine(
          id: 'med_${now}_${DateTime.now().microsecond}',
          barcode: _barcode.text.trim(),
          name: _name.text.trim(),
          price: enteredPrice.toDouble(),
          quantity: enteredQty,
          imagePath: _imageFileName,
          expiryDate: _expiry?.millisecondsSinceEpoch,
          type: _type,
          category: _isSupply ? _categoryOrNull() : null,
          createdAt: now,
          updatedAt: now,
        );

    try {
      await widget.store.save(medicine);
    } catch (e) {
      // بلا هذا الالتقاط كان فشل الحفظ (قرص ممتلئ، قاعدة مقفلة) يوقف
      // الدوّارة فقط بلا رسالة ولا إغلاق — فيظن المستخدم أن التطبيق «لا
      // يحفظ» ويعيد المحاولة بلا فائدة. نُبقي النموذج مفتوحاً ببياناته.
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('تعذّر الحفظ: $e', color: AppColors.danger);
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  String? _categoryOrNull() {
    final t = _category.text.trim();
    return t.isEmpty ? null : t;
  }

  /// يسأل عند اكتشاف مادة تحمل الباركود نفسه.
  ///
  /// لا خيار «سجل منفصل» هنا بخلاف حوار الاسم: الفهرس الفريد على `barcode`
  /// يجعل السجلين مستحيلين — محاولة الحفظ تحذف القديم صامتاً. فالخياران
  /// الحقيقيان الوحيدان: تعديل الموجود، أو الإلغاء.
  /// يعيد: true = عدّل الموجود · null/false = إلغاء.
  Future<bool?> _confirmDuplicateBarcode(Medicine match) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('⚠️ الباركود مسجَّل لمادة أخرى'),
        content: Text(
          'الباركود «${match.barcode}» يخص «${match.name}» المسجّلة لديك '
          'بالفعل — الكمية ${match.quantity} بسعر ${formatPrice(match.price)} '
          'د.ع.\n\n'
          'لا يمكن حفظ مادتين بنفس الباركود. «تعديل الموجود» يفتحه للتحديث '
          '(يدعم "+" لإضافة الوارد إلى الرصيد الحالي).',
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تعديل الموجود'),
          ),
        ],
      ),
    );
  }

  /// تنبيه عند تعديل باركود مادة إلى باركود تملكه مادة أخرى — لا حفظ.
  Future<void> _showBarcodeTaken(Medicine owner) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('⚠️ الباركود مسجَّل لمادة أخرى'),
        content: Text(
          'الباركود «${owner.barcode}» يخص «${owner.name}» — الكمية '
          '${owner.quantity} بسعر ${formatPrice(owner.price)} د.ع.\n\n'
          'لا يمكن حفظ مادتين بنفس الباركود. صحّح الباركود، أو ادمج المادتين '
          'من «مراجعة التكرارات» في الإعدادات.',
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  /// يسأل عند اكتشاف مادة بنفس الاسم بلا باركود لتمييزها.
  /// يعيد: true = عدّل الموجود · false = احفظ سجلاً منفصلاً · null = إلغاء.
  Future<bool?> _confirmDuplicateName(Medicine match) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('⚠️ مادة بنفس الاسم موجودة'),
        content: Text(
          '«${match.name}» مسجّلة لديك بالفعل — الكمية ${match.quantity} '
          'بسعر ${formatPrice(match.price)} د.ع.\n\n'
          'تعديل الموجود يفتحه للتحديث (يدعم "+" لإضافة الوارد). '
          'الحفظ كسجل منفصل يُبقي الاثنين قائمين.',
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('سجل منفصل'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تعديل الموجود'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = ImageStore.fullPathSync(_imageFileName);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit
              ? (_isSupply ? 'تعديل مستلزم' : 'تعديل دواء')
              : (_isSupply ? 'إضافة مستلزم جديد' : 'إضافة دواء جديد'),
        ),
        backgroundColor: AppColors.bgCard,
      ),
      body: AbsorbPointer(
        absorbing: _looking || _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ----- النوع -----
              const _Label('🗂️ النوع'),
              SegmentedButton<ItemType>(
                segments: [
                  for (final t in ItemType.values)
                    ButtonSegment(value: t, label: Text(t.label)),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),

              // ----- الباركود -----
              const SizedBox(height: 20),
              const _Label('📊 الباركود'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('barcodeField'),
                      controller: _barcode,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'أدخل الباركود يدوياً أو امسحه',
                      ),
                      onFieldSubmitted: (v) {
                        if (v.trim().isNotEmpty) _autoFill(v.trim());
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 52,
                    width: 52,
                    child: FilledButton(
                      onPressed: _scan,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.primary,
                      ),
                      child: const Icon(Icons.qr_code_scanner, size: 26),
                    ),
                  ),
                ],
              ),
              // بيانات إضافية استُخرجت من رمز GS1 نفسه
              if (_lastScan?.isGs1 == true && _lastScan!.hasExtraData) ...[
                const SizedBox(height: 10),
                _Gs1Chips(scan: _lastScan!),
              ],
              if (_looking) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'جاري البحث عن معلومات الدواء...',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],

              // ----- الصورة -----
              const SizedBox(height: 20),
              _Label(_isSupply ? '📷 صورة المستلزم' : '📷 صورة الدواء'),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imagePath != null)
                      Image.file(File(imagePath), fit: BoxFit.cover)
                    else
                      const Center(
                        child: Text('💊', style: TextStyle(fontSize: 48)),
                      ),
                    if (imagePath != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: CircleAvatar(
                          backgroundColor: AppColors.danger,
                          radius: 16,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: _removeImage,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('كاميرا'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('معرض'),
                    ),
                  ),
                ],
              ),

              // ----- الاسم -----
              const SizedBox(height: 20),
              _Label(_isSupply ? '🩹 اسم المستلزم *' : '💊 اسم الدواء *'),
              TextFormField(
                key: const Key('nameField'),
                controller: _name,
                decoration: InputDecoration(
                  hintText: _isSupply ? 'أدخل اسم المستلزم' : 'أدخل اسم الدواء',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
              ),

              // ----- نوع المادة (الشكل الصيدلاني) — للمستلزمات فقط -----
              if (_isSupply) ...[
                const SizedBox(height: 20),
                const _Label('🧪 نوع المادة (اختياري)'),
                TextFormField(
                  key: const Key('categoryField'),
                  controller: _category,
                  decoration: const InputDecoration(
                    hintText: 'مثل: Tablet، Cream، Syrup…',
                  ),
                ),
              ],

              // ----- السعر والكمية -----
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('💰 السعر (د.ع)'),
                        TextFormField(
                          key: const Key('priceField'),
                          controller: _price,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(hintText: '0'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('📦 الكمية'),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                key: const Key('quantityField'),
                                controller: _quantity,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: '0',
                                ),
                              ),
                            ),
                            // إعادة تعبئة مخزون موجود: إضافة وارد جديد فوق
                            // الرصيد الحالي بدل استبداله عن طريق الخطأ
                            if (_isEdit) ...[
                              const SizedBox(width: 6),
                              SizedBox(
                                height: 52,
                                width: 44,
                                child: OutlinedButton(
                                  onPressed: _addQuantity,
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    foregroundColor: AppColors.success,
                                  ),
                                  child: const Icon(Icons.add, size: 20),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ----- تاريخ الصلاحية -----
              const SizedBox(height: 20),
              const _Label('📅 تاريخ الصلاحية (اختياري)'),
              InkWell(
                onTap: _pickExpiry,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    suffixIcon: _expiry == null
                        ? const Icon(Icons.calendar_today, size: 18)
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _expiry = null),
                          ),
                  ),
                  child: Text(
                    _expiry == null
                        ? 'غير محدد'
                        : '${_expiry!.year}/'
                              '${_expiry!.month.toString().padLeft(2, '0')}/'
                              '${_expiry!.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: _expiry == null
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  // تعطيل مرئي فوري — يمنع نافذة الضغط المزدوج بلا انتظار
                  // إعادة بناء الإطار التالي، بالإضافة إلى حارس _saving
                  // الداخلي في _save() نفسها (دفاع مزدوج).
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _isEdit
                        ? 'حفظ التعديلات'
                        : (_isSupply ? 'حفظ المستلزم' : 'حفظ الدواء'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شرائح تعرض ما قرأناه من رمز GS1 إضافة للباركود.
class _Gs1Chips extends StatelessWidget {
  const _Gs1Chips({required this.scan});

  final Gs1Result scan;

  @override
  Widget build(BuildContext context) {
    final expiry = scan.expiryDate;
    final soon =
        expiry != null && expiry.difference(DateTime.now()).inDays < 180;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (expiry != null)
          _chip(
            '📅 الصلاحية: ${expiry.year}/${expiry.month.toString().padLeft(2, '0')}',
            soon ? AppColors.warning : AppColors.success,
          ),
        if (scan.batch != null)
          _chip('🏷️ وجبة: ${scan.batch}', AppColors.textMuted),
      ],
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(
      text,
      textDirection: TextDirection.rtl,
      style: TextStyle(fontSize: 11, color: color),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
