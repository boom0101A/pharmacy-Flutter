import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/medicine.dart';
import '../services/app_settings.dart';
import '../services/gs1_parser.dart';
import '../services/image_store.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import '../state/medicine_store.dart';
import '../theme.dart';
import '../util/number_parse.dart';
import '../widgets/glass.dart';
import '../widgets/medicine_card.dart';
import '../widgets/smooth_route.dart';
import 'complete_data_screen.dart';
import 'duplicates_screen.dart';
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
    store.load().then((_) {
      _announcePriceRepair();
      return _ensureNotificationPermissions();
    });

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
  /// رسالة لمرة واحدة بعد تصحيح أسعار قرأتها الفاتورة الذكية أصغر بألف مرة.
  void _announcePriceRepair() {
    final n = store.priceRepairCount;
    if (n == 0 || !mounted) return;
    store.priceRepairCount = 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('صُحّح سعر $n مادة قرأتها الفاتورة الذكية خطأً'),
        duration: const Duration(seconds: 6),
      ),
    );
  }

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
        // إشعار قديم مجدول قبل إزالة فلتر «نفذ» يحمل outOfStock
        final name = value == 'outOfStock' ? QuickFilter.lowStock.name : value;
        for (final f in QuickFilter.values) {
          if (f.name == name) targetFilter = f;
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
    // رمز GS1 يحمل الصلاحية والوجبة مع الباركود — المخزون يحفظ الباركود وحده
    final trimmed = Gs1Parser.parse(code.trim()).barcode.trim();
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
  static const _undoWindow = Duration(seconds: 4);

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
          // زر الإجراء يجعل الشريط ثابتاً افتراضياً (Flutter الحديث) فيتجاهل
          // المهلة ولا يُغلق — والحذف الحقيقي يحدث عند الإغلاق فقط أدناه.
          persist: false,
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
    showGlassDialog(
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
            // الفحص التلقائي للتكرار: شريط هادئ يظهر فقط عند وجود تكرار
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: designEase,
              alignment: Alignment.topCenter,
              child: store.duplicateGroupCount > 0
                  ? _duplicatesBar(store.duplicateGroupCount)
                  : const SizedBox(width: double.infinity),
            ),
            // فلتر «بيانات ناقصة» مفعّل: الطريق المختصر لإكمالها مادةً مادة
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: designEase,
              alignment: Alignment.topCenter,
              child:
                  store.quickFilters.contains(QuickFilter.incomplete) &&
                      store.incompleteCountOf(type) > 0
                  ? _noticeBar(
                      key: const Key('completeDataBar'),
                      icon: '📝',
                      text:
                          '${store.incompleteCountOf(type)} مادة بياناتها ناقصة',
                      action: 'إكمال البيانات',
                      onTap: _openCompleteData,
                    )
                  : const SizedBox(width: double.infinity),
            ),
            // فتح/طي لوحة الفلاتر بحركة انزلاق ناعمة
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: designEase,
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
      // شريط زجاجي عائم بعرض الشاشة (dock في ملف التصميم)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // تبديل الأزرار بين القسمين بتلاشٍ وانزلاق بدل استبدال مفاجئ
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: designEase,
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

  /// شريط الأزرار الزجاجي العائم (dock) — ضبابية حقيقية لأنه يعلو القائمة المتحركة.
  Widget _actionButtons() {
    return SizedBox(
      // المفتاح هنا: AnimatedSwitcher يقارن مفتاح ابنه المباشر ليقرر أن
      // المحتوى تغيّر ويشغّل الانتقال
      key: ValueKey('fabs-${type.code}'),
      // clamp يحمي من عرض صفري لحظي أثناء إعادة التخطيط (قيد غير سويّ يرمي)
      width: (MediaQuery.sizeOf(context).width - 24).clamp(1.0, 720.0),
      child: GlassSurface(
        blur: true,
        radius: 28,
        color: const Color(0x8C0E182A),
        borderColor: AppColors.borderHi,
        padding: const EdgeInsets.all(8),
        child: _actionRow(),
      ),
    );
  }

  Widget _actionRow() {
    final hasInvoice = AppSettings.instance.hasGeminiKey;
    // ثلاثة أزرار عريضة لا تتسع للهواتف الضيقة: «مسح باركود» يصير أيقونة
    // فقط هناك، ويبقى «فاتورة ذكية» باسمه لأنه الأقل وضوحاً بلا نص.
    final compactScan = hasInvoice && MediaQuery.sizeOf(context).width < 400;
    final scan = _DockButton(
      gradient: AppGradients.brand,
      foreground: AppColors.onGradient,
      icon: Icons.qr_code_scanner_rounded,
      label: compactScan ? null : 'مسح باركود',
      tooltip: 'مسح باركود',
      onPressed: () => _openForm(scanFirst: true),
    );
    return Row(
      children: [
        // قراءة الفاتورة متاحة في القسمين — الأسطر تُصنَّف في شاشة المراجعة.
        // تختفي تلقائياً إن غاب مفتاح Gemini (لا فائدة من زرّ يفتح خطأ).
        if (hasInvoice) ...[
          Expanded(
            child: _DockButton(
              gradient: AppGradients.warning,
              foreground: const Color(0xFF3A2400),
              icon: Icons.receipt_long_rounded,
              label: 'فاتورة ذكية',
              onPressed: _openInvoiceScan,
            ),
          ),
          const SizedBox(width: 8),
          scan,
        ] else
          Expanded(child: scan),
        const SizedBox(width: 8),
        _DockButton(
          gradient: AppGradients.success,
          foreground: const Color(0xFF032B1E),
          icon: Icons.add_rounded,
          tooltip: 'إضافة',
          onPressed: () => _openForm(),
        ),
      ],
    );
  }

  /// شبكة قسم واحد — كل قسم يحتفظ بموضع تمريره الخاص عبر PageStorageKey.
  Widget _sectionGrid(ItemType sectionType) {
    final items = store.visibleFor(sectionType);

    if (items.isEmpty) {
      // السحب للتحديث يعمل في القسم الفارغ أيضاً — أول تشغيل بعد الانضمام
      // لمخزون مشترك يبدأ فارغاً تماماً
      return RefreshIndicator(
        onRefresh: () => store.refreshFromCloud(manual: true),
        color: AppColors.primary,
        backgroundColor: AppColors.bgCard,
        child: _emptyState(sectionType),
      );
    }

    return RefreshIndicator(
      onRefresh: () => store.refreshFromCloud(manual: true),
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      child: GridView.builder(
        key: PageStorageKey('grid-${sectionType.code}'),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
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

  /// كبسولة زجاجية بمؤشر متدرّج ينزلق بين القسمين (`.tabs` في ملف التصميم).
  Widget _tabBar() {
    return GlassSurface(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(4),
      radius: 18,
      shadow: false,
      child: TabBar(
        controller: _tabs,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(14),
        indicator: BoxDecoration(
          gradient: AppGradients.brand,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x592DD4BF),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        labelColor: AppColors.onGradient,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13.5,
          fontWeight: FontWeight.bold,
        ),
        tabs: [
          for (final t in ItemType.values)
            Tab(
              height: 40,
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

  /// بطاقة زجاجية متدرّجة (تيل/أزرق/بنفسجي). بلا ضبابية حقيقية: لا شيء يتحرك
  /// خلفها (الخلفية ثابتة ومضبّبة أصلاً)، وكانت تُعاد في كل إطار بلا أثر مرئي.
  Widget _header() {
    return GlassSurface(
      radius: 28,
      gradient: AppGradients.header,
      borderColor: AppColors.borderHi,
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -.2,
                  ),
                ),
              ),
              const _SyncIndicator(),
              IconButton(
                icon: const Icon(Icons.settings_rounded, size: 20),
                color: AppColors.textSecondary,
                onPressed: () => showSettingsSheet(context, store),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: store.keyword.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
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
          GlassSquareButton(
            filled: true,
            tooltip: 'مسح باركود في البحث',
            onPressed: _scanIntoSearch,
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 24),
          ),
          const SizedBox(width: 8),
          Badge(
            isLabelVisible: store.activeFilterCount > 0,
            backgroundColor: AppColors.danger,
            label: Text(store.activeFilterCount.toString()),
            child: GlassSquareButton(
              active: _filtersOpen,
              tooltip: 'الفلاتر',
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _filtersOpen = !_filtersOpen);
              },
              // نصف لفة عند فتح اللوحة — يربط الزر بما ظهر تحته
              icon: AnimatedRotation(
                turns: _filtersOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                child: Icon(
                  _filtersOpen
                      ? Icons.filter_alt_rounded
                      : Icons.filter_alt_outlined,
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

    return GlassSurface(
      radius: 22,
      color: AppColors.glassStrong,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(14),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
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
                  _chip('⚠️ منخفض أو نافد (≤5)', QuickFilter.lowStock),
                  _chip(
                    '📝 بيانات ناقصة (${store.incompleteCountOf(type)})',
                    QuickFilter.incomplete,
                  ),
                  _chip('📊 بدون باركود', QuickFilter.noBarcode),
                  _chip('📷 لديه صورة', QuickFilter.hasImage),
                  _chip('🖼️ بدون صورة', QuickFilter.noImage),
                ],
              ),
              const SizedBox(height: 14),
              const _SectionLabel('💰 نطاق السعر (د.ع)'),
              _RangeRow(
                // مفتاح لكل قسم ولكل إعادة تعيين: الحقول تُبنى من جديد بقيم
                // المخزن فلا تعرض قيمة القسم الآخر ولا رقماً أُلغي فلتره
                key: ValueKey('price-${type.code}-${store.filterResetCount}'),
                initialMin: _fmt(store.priceMin),
                initialMax: _fmt(store.priceMax),
                onChanged: (min, max) => store.setPriceRange(
                  min == null ? null : parseLocalizedNumber(min),
                  max == null ? null : parseLocalizedNumber(max),
                ),
              ),
              const SizedBox(height: 14),
              const _SectionLabel('📦 نطاق الكمية'),
              _RangeRow(
                key: ValueKey('qty-${type.code}-${store.filterResetCount}'),
                initialMin: _fmt(store.qtyMin),
                initialMax: _fmt(store.qtyMax),
                onChanged: (min, max) => store.setQuantityRange(
                  min == null ? null : parseLocalizedInt(min),
                  max == null ? null : parseLocalizedInt(max),
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
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('إعادة تعيين الفلاتر'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _fmt(num? v) => v == null
      ? null
      : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());

  Widget _chip(String label, QuickFilter filter) {
    final selected = store.quickFilters.contains(filter);
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        store.toggleQuickFilter(filter);
      },
      backgroundColor: const Color(0x0FFFFFFF),
      selectedColor: const Color(0x332DD4BF),
      side: BorderSide(
        color: selected ? const Color(0x992DD4BF) : AppColors.border,
      ),
      showCheckmark: false,
    );
  }

  Widget _sortChip(String label, SortField field) {
    final active = store.sortField == field;
    final selected = active;
    return ChoiceChip(
      label: Text(
        active ? '$label ${store.sortAscending ? '▲' : '▼'}' : label,
        style: const TextStyle(fontSize: 12),
      ),
      selected: active,
      onSelected: (_) => store.setSort(field),
      backgroundColor: const Color(0x0FFFFFFF),
      selectedColor: const Color(0x332DD4BF),
      side: BorderSide(
        color: selected ? const Color(0x992DD4BF) : AppColors.border,
      ),
      showCheckmark: false,
    );
  }

  /// «🔍 N تكرارات تحتاج مراجعة» — يفتح المراجعة بضغطة.
  Widget _duplicatesBar(int count) => _noticeBar(
    key: const Key('duplicatesBar'),
    icon: '🔍',
    text:
        '$count ${count == 1 ? 'مجموعة تكرار تحتاج' : 'تكرارات تحتاج'} مراجعة',
    action: 'مراجعة',
    onTap: _openDuplicates,
  );

  /// شريط تنبيه هادئ بلون التحذير مع زر إجراء.
  Widget _noticeBar({
    required Key key,
    required String icon,
    required String text,
    required String action,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: const Color(0x1FFBBF24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x66FBBF24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: key,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ),
                Text(
                  action,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
                const Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCompleteData() async {
    await Navigator.of(context).push(
      SmoothPageRoute<void>(
        builder: (_) => CompleteDataScreen(store: store, type: type),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openDuplicates() async {
    await Navigator.of(context).push(
      SmoothPageRoute<void>(builder: (_) => DuplicatesScreen(store: store)),
    );
    if (mounted) setState(() {});
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
          // دائرة زجاجية حول الرمز (`.empty .e` في ملف التصميم)
          Center(
            child: SizedBox.square(
              dimension: 110,
              child: GlassSurface(
                radius: 55,
                shadow: false,
                child: Center(
                  child: Text(
                    filtered
                        ? '🔍'
                        : supplies
                        ? '🩹'
                        : '💊',
                    style: const TextStyle(fontSize: 52),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
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
                : supplies && AppSettings.instance.hasGeminiKey
                ? 'اضغط «فاتورة ذكية» لإضافة موادها دفعة واحدة'
                : supplies
                ? 'اضغط «+» لإضافة أول مستلزم'
                : 'اضغط «مسح باركود» للبدء',
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
        // كبسولة زجاجية بنقطة متوهّجة (`.sync` في ملف التصميم). التوهّج
        // ثابت: النبض المستمر يعيد الرسم بلا توقف طوال فتح التطبيق.
        return Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => _showDetails(context, sync),
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
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
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: .55),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
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
                      Icons.info_outline_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// عرض سبب فشل المزامنة بالتفصيل عند الضغط على المؤشر.
  void _showDetails(BuildContext context, SyncService sync) {
    showGlassDialog(
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
  Widget build(BuildContext context) => GlassSurface(
    radius: 18,
    color: const Color(0x5906101E),
    shadow: false,
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
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
  const _RangeRow({
    super.key,
    required this.onChanged,
    this.initialMin,
    this.initialMax,
  });

  final void Function(String? min, String? max) onChanged;
  final String? initialMin;
  final String? initialMax;

  @override
  State<_RangeRow> createState() => _RangeRowState();
}

class _RangeRowState extends State<_RangeRow> {
  late final _min = TextEditingController(text: widget.initialMin);
  late final _max = TextEditingController(text: widget.initialMax);

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

/// زر داخل الشريط الزجاجي السفلي: تدرّج + لمعان + ضغطة نابضية، بارتفاع 52.
/// بلا [label] يصير أيقونة مربعة 52×52.
class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.gradient,
    required this.foreground,
    required this.icon,
    required this.onPressed,
    this.label,
    this.tooltip,
  });

  final Gradient gradient;
  final Color foreground;
  final IconData icon;
  final VoidCallback onPressed;
  final String? label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final text = label;
    Widget button = GradientButton(
      onPressed: onPressed,
      gradient: gradient,
      foreground: foreground,
      height: 52,
      radius: 20,
      glow: const Color(0x4D000000),
      padding: EdgeInsets.symmetric(horizontal: text == null ? 14 : 16),
      child: text == null
          ? Icon(icon, size: 24)
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 24),
                  const SizedBox(width: 8),
                  Text(text, maxLines: 1),
                ],
              ),
            ),
    );
    if (tooltip != null) button = Tooltip(message: tooltip!, child: button);
    return button;
  }
}
