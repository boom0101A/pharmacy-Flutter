import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/medicine.dart';
import '../services/app_settings.dart';
import '../services/image_store.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import '../state/medicine_store.dart';
import '../theme.dart';
import '../widgets/medicine_card.dart';
import '../widgets/smooth_route.dart';
import 'form_screen.dart';
import 'invoice_scan_screen.dart';
import 'scanner_screen.dart';
import 'settings_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final MedicineStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final TabController _tabs;
  bool _filtersOpen = false;

  /// المواد التي عُرضت مرة على الأقل — تمنع تكرار حركة الدخول عند التمرير.
  final _animated = <String>{};

  MedicineStore get store => widget.store;
  ItemType get type => store.activeType;
  bool get isSupplies => type == ItemType.supply;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: ItemType.values.length, vsync: this)
      ..addListener(_onTabChanged);
    store.addListener(_onStoreChanged);
    store.load().then((_) => _ensureNotificationPermissions());

    // نستمع لحمولة الإشعار — إن نقر المستخدم على إشعار «قاربة الانتهاء»،
    // نبدّل التبويب ونطبّق الفلتر مباشرة فيرى ما يهمّه فوراً.
    NotificationService.instance.addListener(_onNotificationTap);
    // إن فُتح التطبيق أصلاً بنقر إشعار (كان مغلقاً)، الحمولة جاهزة الآن —
    // نستهلكها بعد بناء أول إطار (قبله setState محظور).
    WidgetsBinding.instance.addPostFrameCallback((_) => _onNotificationTap());
  }

  /// طلب أذونات الإشعارات **بعد** بناء الواجهة لا قبلها.
  ///
  /// إذن الإنذارات الدقيقة يفتح شاشة إعدادات النظام؛ طلبه قبل `runApp()` كان
  /// يترك المستخدم أمام شاشة سوداء بلا أي واجهة حتى يعود منها.
  Future<void> _ensureNotificationPermissions() async {
    if (!mounted) return;
    if (!AppSettings.instance.stockNotificationsEnabled) return;
    await NotificationService.instance.requestPermissions();
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    store.removeListener(_onStoreChanged);
    NotificationService.instance.removeListener(_onNotificationTap);
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // يُستدعى مرتين لكل تبديل (بداية الحركة ونهايتها) — نتصرف عند الاستقرار
    final target = ItemType.values[_tabs.index];
    if (target == store.activeType) return;

    HapticFeedback.selectionClick();
    store.setActiveType(target);
    // لكل قسم كلمة بحثه — نعيد الحقل إلى ما تركه المستخدم في هذا القسم
    _searchController.text = store.keyword;
    setState(() => _filtersOpen = false);
  }

  void _onStoreChanged() {
    if (!mounted) return;
    // مزامنة عكسية: لو غيّرت جهة خارجية (مثل نقر إشعار) القسمَ النشط في
    // المخزن، نحرّك المؤشر ليطابقه. بلا هذا يتحدّث المخزن لكن التبويب يبقى
    // على القسم القديم فتظهر بيانات قسم وعنوان قسم آخر.
    final target = ItemType.values.indexOf(store.activeType);
    if (_tabs.index != target) {
      _tabs.animateTo(target);
    }
    setState(() {});
  }

  /// يُستدعى عند وصول حمولة إشعار (سواء التطبيق مفتوح أو فتحه الإشعار للتوّ).
  /// يفكّك الحمولة إلى قسم + فلتر، ويطبّقهما، ثم يُبلغ الخدمة أنه استهلكها
  /// حتى لا تُطبَّق مرتين.
  void _onNotificationTap() {
    final payload = NotificationService.instance.pendingPayload;
    if (payload == null || !mounted) return;
    _applyPayload(payload);
    NotificationService.instance.consumePendingPayload();
  }

  /// يفكّك حمولة `"type:medicine|filter:expiringSoon"` ويطبّقها على المخزن.
  ///
  /// [store.toggleQuickFilter] تقلب الحالة — لو كان الفلتر مفعّلاً مسبقاً
  /// سيُطفَأ. نستدعي [resetFilters] أولاً حتى تأتي كل نقرة إشعار بالحالة
  /// المتوقَّعة بغضّ النظر عن ما كان مفعّلاً قبل.
  void _applyPayload(String payload) {
    ItemType? targetType;
    QuickFilter? targetFilter;

    for (final part in payload.split('|')) {
      final kv = part.split(':');
      if (kv.length != 2) continue;
      final key = kv[0];
      final value = kv[1];
      if (key == 'type') {
        for (final t in ItemType.values) {
          if (t.name == value) targetType = t;
        }
      } else if (key == 'filter') {
        for (final f in QuickFilter.values) {
          if (f.name == value) targetFilter = f;
        }
      }
    }

    if (targetType != null) store.setActiveType(targetType);
    if (targetFilter != null) {
      _searchController.clear();
      store.setKeyword('');
      store.resetFilters();
      store.toggleQuickFilter(targetFilter);
      // نفتح لوحة الفلاتر تلقائياً كإشارة بصرية أن الفلتر مطبَّق فعلاً
      setState(() => _filtersOpen = true);
    }
  }

  Future<void> _openForm({Medicine? existing, bool scanFirst = false}) async {
    await Navigator.of(context).push(
      SmoothPageRoute(
        builder: (_) => MedicineFormScreen(
          store: store,
          existing: existing,
          openScannerOnStart: scanFirst,
          // الإضافة الجديدة تُنسب إلى القسم المفتوح
          initialType: existing?.type ?? type,
        ),
      ),
    );
  }

  /// مسح باركود لملء حقل البحث — الفلترة تعمل مباشرة على `barcode` في
  /// `MedicineStore._matches`، فأي رمز ممسوح يظهر مطابقه فوراً (إن وُجد).
  Future<void> _scanIntoSearch() async {
    final code = await Navigator.of(
      context,
    ).push<String>(SmoothPageRoute(builder: (_) => const ScannerScreen()));
    if (code == null || !mounted) return;
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    _searchController.text = trimmed;
    store.setKeyword(trimmed);
  }

  /// تصوير فاتورة مجهّز → مراجعة الأسطر وأنواعها → حفظها دفعة واحدة.
  /// يعمل فقط عند وجود مفتاح Gemini — الزر يختفي بلا مفتاح.
  Future<void> _openInvoiceScan() async {
    final result = await Navigator.of(context).push<InvoiceSaveResult>(
      SmoothPageRoute(
        builder: (_) => InvoiceScanScreen(store: store, initialType: type),
      ),
    );

    if (result == null || result.items.isEmpty || !mounted) return;

    // ملخّص صادق: يميّز المادة الجديدة عن المُدمَجة مع مخزون موجود، بدل
    // عدّاد عام لا يفرّق بينهما — هذا ما كان المستخدم يفتقده ليعرف أن
    // الفاتورة لم تُضِف مكرراً بل دمجته مع ما لديه فعلاً.
    final parts = <String>[
      if (result.addedNew > 0) 'أُضيفت ${result.addedNew} مادة جديدة',
      if (result.mergedExisting > 0)
        'دُمجت ${result.mergedExisting} مع مواد موجودة مسبقاً',
    ];
    if (result.mergedWithinInvoice > 0) {
      parts.add(
        '(${result.mergedWithinInvoice} منها مكرَّر داخل الفاتورة نفسها)',
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${parts.join(' · ')}'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  /// مهلة التراجع بعد الحذف — كافية لتصحيح ضغطة خاطئة بلا إبطاء العمل.
  static const _undoWindow = Duration(seconds: 5);

  /// حذف فوري + شريط «تراجع» — بديل عن حوار «هل أنت متأكد؟» الذي كان يُبطئ
  /// كل حذف بضغطتين، مع نفس الأمان: الحذف الحقيقي لا يلمس القاعدة إلا بعد
  /// انتهاء المهلة بلا تراجع.
  void _deleteWithUndo(Medicine medicine) {
    store.hideForPendingDelete(medicine.id);
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('🗑️ حُذف "${medicine.name}"'),
          duration: _undoWindow,
          action: SnackBarAction(
            label: 'تراجع',
            textColor: AppColors.warning,
            onPressed: () => store.cancelPendingDelete(medicine.id),
          ),
        ),
      ).closed.then((reason) {
        // أي سبب إغلاق غير الضغط على «تراجع» يعني تأكيداً ضمنياً للحذف —
        // بما فيها انتهاء المهلة وحلول حذف آخر مكانه.
        if (reason != SnackBarClosedReason.action) {
          store.commitPendingDelete(medicine);
        }
      });
  }

  void _viewImage(Medicine medicine) {
    final path = ImageStore.fullPathSync(medicine.imagePath);
    if (path == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Hero(
          tag: 'medicine-image-${medicine.id}',
          child: InteractiveViewer(child: Image.file(File(path))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _tabBar(),
            _searchRow(),
            // فتح/طي لوحة الفلاتر بحركة انزلاق ناعمة
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _filtersOpen
                  ? _filterPanel()
                  : const SizedBox(width: double.infinity),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: store.hasActiveFilters
                  ? _resultsInfo(store.visible.length)
                  : const SizedBox(width: double.infinity),
            ),
            Expanded(
              child: store.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  // انتقال حقيقي بين القسمين: ينزلقان مع الإصبع ويمكن سحبهما
                  : TabBarView(
                      controller: _tabs,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        for (final t in ItemType.values) _sectionGrid(t),
                      ],
                    ),
            ),
          ],
        ),
      ),
      // تبديل الأزرار بين القسمين بتلاشٍ وانزلاق بدل استبدال مفاجئ
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.35),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: _actionButtons(),
      ),
    );
  }

  Widget _actionButtons() {
    // الأزرار الثلاثة تتجاوز عرض الشاشات الضيقة (320). التصغير المتناسب عند
    // الحاجة فقط يبقيها كلها ظاهرة ومضغوطة، بلا تغيير على الشاشات العادية.
    return ConstrainedBox(
      // المفتاح هنا لا على الصف الداخلي: AnimatedSwitcher يقارن مفتاح ابنه
      // المباشر ليقرر أن المحتوى تغيّر ويشغّل الانتقال
      key: ValueKey('fabs-${type.code}'),
      constraints: BoxConstraints(
        // clamp يحمي من عرض صفري لحظي أثناء إعادة التخطيط (قيد غير سويّ يرمي)
        maxWidth: (MediaQuery.sizeOf(context).width - 32).clamp(
          1.0,
          double.infinity,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: _actionRow(),
      ),
    );
  }

  Widget _actionRow() {
    final hasInvoice = AppSettings.instance.hasGeminiKey;
    // ثلاثة أزرار عريضة لا تتسع للهواتف الضيقة: «مسح باركود» يصير أيقونة
    // فقط هناك، ويبقى «فاتورة ذكية» باسمه لأنه الأقل وضوحاً بلا نص.
    final compactScan = hasInvoice && MediaQuery.sizeOf(context).width < 400;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // قراءة الفاتورة متاحة في القسمين — الأسطر تُصنَّف في شاشة المراجعة.
        // تختفي تلقائياً إن غاب مفتاح Gemini (لا فائدة من زرّ يفتح خطأ).
        if (hasInvoice) ...[
          FloatingActionButton.extended(
            heroTag: 'invoice-${type.code}',
            onPressed: _openInvoiceScan,
            backgroundColor: AppColors.warning,
            icon: const Icon(Icons.receipt_long),
            label: const Text('فاتورة ذكية'),
          ),
          const SizedBox(width: 10),
        ],
        if (compactScan)
          FloatingActionButton(
            heroTag: 'scan-${type.code}',
            onPressed: () => _openForm(scanFirst: true),
            backgroundColor: AppColors.primary,
            tooltip: 'مسح باركود',
            child: const Icon(Icons.qr_code_scanner),
          )
        else
          FloatingActionButton.extended(
            heroTag: 'scan-${type.code}',
            onPressed: () => _openForm(scanFirst: true),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('مسح باركود'),
          ),
        const SizedBox(width: 10),
        FloatingActionButton(
          heroTag: 'add-${type.code}',
          onPressed: () => _openForm(),
          backgroundColor: AppColors.success,
          child: const Icon(Icons.add),
        ),
      ],
    );
  }

  /// شبكة قسم واحد — كل قسم يحتفظ بموضع تمريره الخاص عبر PageStorageKey.
  Widget _sectionGrid(ItemType sectionType) {
    final items = store.visibleFor(sectionType);

    if (items.isEmpty) {
      return _emptyState(sectionType);
    }

    return RefreshIndicator(
      onRefresh: () => store.refreshFromCloud(manual: true),
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      child: GridView.builder(
        key: PageStorageKey('grid-${sectionType.code}'),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.60,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final m = items[i];
          // `add` يعيد true مرة واحدة لكل مادة: أول ظهور فقط يتحرك،
          // وإعادة التدوير أثناء التمرير لا تعيد الحركة
          final firstAppearance = _animated.add(m.id);
          return MedicineCard(
            index: i,
            animate: firstAppearance,
            medicine: m,
            onEdit: () => _openForm(existing: m),
            onDelete: () => _deleteWithUndo(m),
            onImageTap: () => _viewImage(m),
          );
        },
      ),
    );
  }

  Widget _tabBar() {
    return Container(
      color: AppColors.bgCard,
      child: TabBar(
        controller: _tabs,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        tabs: [
          for (final t in ItemType.values)
            Tab(
              height: 46,
              // «🩹 مستلزم طبي (1)» لا يتّسع في نصف شاشة عرضها 320؛
              // التصغير عند الحاجة أفضل من قصّ النص أو من شريط فيضان
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('${t.label}  (${store.countOf(t)})'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF12405C), AppColors.bgCard],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // الاسم يتقلّص أولاً: مؤشر المزامنة وزر الإعدادات أهم وظيفياً
              const Expanded(
                child: Text(
                  '💊 صيدليتي',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const _SyncIndicator(),
              IconButton(
                icon: const Icon(Icons.settings, size: 20),
                color: AppColors.textSecondary,
                onPressed: () => showSettingsSheet(context, store),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: isSupplies ? 'عدد المستلزمات' : 'عدد الأدوية',
                  value: store.totalCount.toDouble(),
                  decimals: 0,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(
                  label: store.missingPriceCount == 0
                      ? 'القيمة الإجمالية (د.ع)'
                      : 'القيمة (${store.missingPriceCount} بلا سعر)',
                  value: store.totalValue,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: store.setKeyword,
              decoration: InputDecoration(
                hintText: isSupplies
                    ? 'ابحث في المستلزمات بالاسم...'
                    : 'ابحث بالاسم أو الباركود...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: store.keyword.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          store.setKeyword('');
                        },
                      ),
              ),
            ),
          ),
          // زر مسح الباركود إلى جانب البحث — سريع للأدوية التي حُفظت بباركود،
          // فبدل الطباعة اليدوية يمسح الرمز فيظهر مطابقه فوراً في القائمة.
          const SizedBox(width: 8),
          SizedBox(
            height: 52,
            width: 52,
            child: FilledButton(
              onPressed: _scanIntoSearch,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: AppColors.primary,
              ),
              child: const Icon(Icons.qr_code_scanner, size: 24),
            ),
          ),
          const SizedBox(width: 8),
          Badge(
            isLabelVisible: store.activeFilterCount > 0,
            label: Text(store.activeFilterCount.toString()),
            child: SizedBox(
              height: 52,
              width: 52,
              child: OutlinedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _filtersOpen = !_filtersOpen);
                },
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                // دوران ربع لفة عند فتح اللوحة — يربط الزر بما ظهر تحته
                child: AnimatedRotation(
                  turns: _filtersOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    _filtersOpen ? Icons.filter_alt : Icons.filter_alt_outlined,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterPanel() {
    // اللوحة أطول من نصف الشاشة على الهواتف الصغيرة. بلا هذا السقف كانت تدفع
    // الشبكة خارج الشاشة ويظهر شريط الفيضان الأصفر؛ الآن تمرّر داخلها.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.45;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('📌 فلترة سريعة'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip('⏳ قريبة الانتهاء', QuickFilter.expiringSoon),
                _chip('⚠️ مخزون منخفض (≤5)', QuickFilter.lowStock),
                _chip('🚫 نفذ من المخزن', QuickFilter.outOfStock),
                _chip('📊 بدون باركود', QuickFilter.noBarcode),
                _chip('📷 لديه صورة', QuickFilter.hasImage),
                _chip('🖼️ بدون صورة', QuickFilter.noImage),
              ],
            ),
            const SizedBox(height: 14),
            const _SectionLabel('💰 نطاق السعر (د.ع)'),
            _RangeRow(
              // مفتاح لكل قسم: حقول النطاق تُبنى من جديد عند تبديل التبويب
              // فلا تعرض قيمة القسم الآخر
              key: ValueKey('price-${type.code}'),
              onChanged: (min, max) => store.setPriceRange(
                min == null ? null : double.tryParse(min),
                max == null ? null : double.tryParse(max),
              ),
            ),
            const SizedBox(height: 14),
            const _SectionLabel('📦 نطاق الكمية'),
            _RangeRow(
              key: ValueKey('qty-${type.code}'),
              onChanged: (min, max) => store.setQuantityRange(
                min == null ? null : int.tryParse(min),
                max == null ? null : int.tryParse(max),
              ),
            ),
            const SizedBox(height: 14),
            const _SectionLabel('🔃 ترتيب حسب'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _sortChip('🕐 الأحدث', SortField.date),
                _sortChip('🔤 الاسم', SortField.name),
                _sortChip('💲 السعر', SortField.price),
                _sortChip('📦 الكمية', SortField.quantity),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: store.resetFilters,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('إعادة تعيين الفلاتر'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, QuickFilter filter) {
    final selected = store.quickFilters.contains(filter);
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        store.toggleQuickFilter(filter);
      },
      backgroundColor: AppColors.bgDark,
      selectedColor: AppColors.primary.withValues(alpha: 0.25),
      side: const BorderSide(color: AppColors.border),
      showCheckmark: false,
    );
  }

  Widget _sortChip(String label, SortField field) {
    final active = store.sortField == field;
    return ChoiceChip(
      label: Text(
        active ? '$label ${store.sortAscending ? '▲' : '▼'}' : label,
        style: const TextStyle(fontSize: 12),
      ),
      selected: active,
      onSelected: (_) => store.setSort(field),
      backgroundColor: AppColors.bgDark,
      selectedColor: AppColors.primary.withValues(alpha: 0.25),
      side: const BorderSide(color: AppColors.border),
      showCheckmark: false,
    );
  }

  Widget _resultsInfo(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Flexible + ellipsis يمنعان فيضان الصف على الشاشات الضيقة عند
          // ازدياد عدد الخانات (مثلاً «عرض 1234 من أصل 5678 مستلزم»).
          Flexible(
            child: Text(
              'عرض $count من أصل ${store.totalCount} '
              '${isSupplies ? 'مستلزم' : 'دواء'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              _searchController.clear();
              store.clearAll();
            },
            child: const Text('✕ مسح الفلاتر', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(ItemType sectionType) {
    final supplies = sectionType == ItemType.supply;
    final filtered = store.countOf(sectionType) > 0;

    // ظهور لطيف بدل قفزة مفاجئة عند إفراغ النتائج
    return TweenAnimationBuilder<double>(
      key: ValueKey('empty-${sectionType.code}-$filtered'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: child,
        ),
      ),
      child: ListView(
        // قائمة لا Center حتى يبقى السحب للتحديث ممكناً في القسم الفارغ
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 70),
          Text(
            filtered
                ? '🔍'
                : supplies
                ? '🩹'
                : '💊',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 56),
          ),
          const SizedBox(height: 12),
          Text(
            filtered
                ? 'لا توجد نتائج مطابقة'
                : supplies
                ? 'لا توجد مستلزمات بعد'
                : 'لا توجد أدوية بعد',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            filtered
                ? 'جرّب تغيير البحث أو الفلاتر'
                : supplies
                ? 'اضغط "قراءة فاتورة" لإضافة موادها دفعة واحدة'
                : 'اضغط "مسح باركود" للبدء',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// مؤشر حالة المزامنة مع Firestore.
class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator();

  @override
  Widget build(BuildContext context) {
    final sync = SyncService.instance;
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final color = switch (sync.status) {
          SyncStatus.synced => AppColors.success,
          SyncStatus.syncing => AppColors.primary,
          SyncStatus.offline => AppColors.warning,
          SyncStatus.error => AppColors.danger,
          SyncStatus.disabled => AppColors.textMuted,
        };
        return InkWell(
          onTap: () => _showDetails(context, sync),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sync.status == SyncStatus.syncing)
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.circle, size: 10, color: color),
                const SizedBox(width: 6),
                // «مزامنة سحابية ✓» أطول نص في الترويسة — يُقصّ ولا يفيض
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    sync.statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (sync.lastError != null) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// عرض سبب فشل المزامنة بالتفصيل عند الضغط على المؤشر.
  void _showDetails(BuildContext context, SyncService sync) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(sync.statusLabel),
        content: SingleChildScrollView(
          child: Text(
            sync.lastError ?? 'كل شيء يعمل بشكل سليم ✅',
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }
}

/// صندوق إحصاء يعدّ رقمه تصاعدياً بدل أن يقفز.
///
/// الفائدة ليست زخرفية: عند تبديل التبويب يتغيّر الرقمان معاً، والعدّ المتدرّج
/// يجعل العين تتابع التغيير بدل أن تفاجأ به.
class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
    this.decimals = 0,
  });

  final String label;
  final double value;
  final Color color;
  final int decimals;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
    decoration: BoxDecoration(
      color: AppColors.bgDark.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        TweenAnimationBuilder<double>(
          // `begin` يُستعمل في أول بناء فقط، فتبدأ القيمة ثابتة بلا استعراض؛
          // وكل تغيّر لاحق في `end` يُعدّ من القيمة الحالية إلى الجديدة.
          tween: Tween(begin: value, end: value),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Text(
            decimals == 0 ? formatPrice(v.round()) : formatPrice(v),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            label,
            key: ValueKey(label),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

class _RangeRow extends StatefulWidget {
  const _RangeRow({super.key, required this.onChanged});

  final void Function(String? min, String? max) onChanged;

  @override
  State<_RangeRow> createState() => _RangeRowState();
}

class _RangeRowState extends State<_RangeRow> {
  final _min = TextEditingController();
  final _max = TextEditingController();

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(
    _min.text.trim().isEmpty ? null : _min.text.trim(),
    _max.text.trim().isEmpty ? null : _max.text.trim(),
  );

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _field(_min, 'من')),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text('—', style: TextStyle(color: AppColors.textMuted)),
      ),
      Expanded(child: _field(_max, 'إلى')),
    ],
  );

  Widget _field(TextEditingController c, String hint) => TextField(
    controller: c,
    keyboardType: TextInputType.number,
    onChanged: (_) => _emit(),
    decoration: InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}
