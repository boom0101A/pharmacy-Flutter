import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_settings.dart';
import '../services/auth_service.dart';
import '../services/backup_actions.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../state/medicine_store.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/smooth_route.dart';
import 'duplicates_screen.dart';
import 'linked_devices_sheet.dart';
import 'pairing_sheet.dart';

/// لوحة الإعدادات — تُفتح من أيقونة الترس في الترويسة.
Future<void> showSettingsSheet(BuildContext context, MedicineStore store) {
  return showGlassSheet(
    context: context,
    builder: (_) => _SettingsSheet(store: store),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({required this.store});

  final MedicineStore store;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;

    return SafeArea(
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                const SizedBox(height: 18),
                const Text(
                  '⚙️ الإعدادات',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  tileColor: const Color(0x0AFFFFFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  value: settings.stockNotificationsEnabled,
                  onChanged: (value) async {
                    await settings.setStockNotificationsEnabled(value);
                    if (value) {
                      // إعادة التفعيل: نُعيد جدولة الإشعار فوراً بأحدث بيانات
                      await NotificationService.instance.scheduleDailyDigest(
                        store.all,
                      );
                    } else {
                      // التعطيل: نُلغي الجدولة القائمة كي لا يفاجأ المستخدم
                      // بإشعار بعد أن أطفأ المفتاح
                      await NotificationService.instance.cancelDailyDigest();
                    }
                  },
                  activeThumbColor: AppColors.success,
                  title: const Text(
                    'تنبيهات الصلاحية والمخزون',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'إشعار يومي الساعة 9 صباحاً إذا كانت هناك مواد منتهية أو '
                    'قاربت الانتهاء أو مخزون منخفض/نافد.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  tileColor: const Color(0x0AFFFFFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  value: settings.contributeToRegistry,
                  onChanged: settings.setContributeToRegistry,
                  activeThumbColor: AppColors.success,
                  title: const Text(
                    'المساهمة في القاموس المشترك',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'إرسال اسم الدواء وصورته فقط عند حفظه، لمساعدة بقية '
                    'الصيدليات على التعرف عليه.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x0DFFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(
                        '✅ يُرسَل',
                        'الباركود + اسم الدواء + صورة مصغّرة',
                        AppColors.success,
                      ),
                      const SizedBox(height: 8),
                      _row(
                        '🔒 لا يُرسَل',
                        'السعر • الكمية • اسم صيدليتك • موقعك',
                        AppColors.danger,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                Text(
                  settings.contributeToRegistry
                      ? 'أنت تساهم حالياً — شكراً، هذا ما يجعل القاموس ينمو.'
                      : 'المساهمة موقوفة. ستبقى تستفيد من القاموس عند المسح، '
                            'لكن أدويتك لن تُضاف إليه.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 22),
                const GlassDivider(),
                const SizedBox(height: 10),
                _backupSection(context),

                const SizedBox(height: 22),
                const GlassDivider(),
                const SizedBox(height: 10),
                _sharingSection(context, store),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _backupSection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '💾 النسخة الاحتياطية',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      const Text(
        'ملف يحفظ كل المواد. عند الحفظ أرسله إلى واتساب أو Drive أو التنزيلات '
        '— إلغاء التثبيت يمسح ما بداخل التطبيق ويغيّر هوية المزامنة.',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          height: 1.6,
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: GradientFilled(
              gradient: AppGradients.success,
              foreground: const Color(0xFF032B1E),
              glow: const Color(0x4D10B981),
              child: FilledButton.icon(
                onPressed: () => _export(context),
                icon: const Icon(Icons.save_alt_rounded, size: 18),
                label: const Text('حفظ نسخة'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _import(context),
              icon: const Icon(Icons.restore_rounded, size: 18),
              label: const Text('استرجاع'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _identityRow(context),
    ],
  );

  /// عرض هوية المزامنة — تُطلب عند تشخيص «لماذا لا أرى بياناتي؟».
  Widget _identityRow(BuildContext context) {
    final uid = AuthService.instance.uid;
    return InkWell(
      onTap: uid == null
          ? null
          : () {
              Clipboard.setData(ClipboardData(text: uid));
              _toast(context, 'نُسخ معرّف المزامنة');
            },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              uid == null ? Icons.cloud_off_rounded : Icons.fingerprint_rounded,
              size: 16,
              color: uid == null ? AppColors.warning : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                uid == null
                    ? (AuthService.instance.error ?? 'المزامنة غير مفعّلة')
                    : 'معرّف المزامنة: ${uid.substring(0, 8)}… (اضغط للنسخ)',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    try {
      final path = await BackupActions.export();
      if (!context.mounted) return;
      // الملف في مجلد التطبيق الخاص: لا يراه تطبيق «الملفات» ويُمسح مع
      // إلغاء التثبيت. المشاركة هي الطريق الوحيد لإخراجه إلى مكان آمن.
      _toast(context, 'اختر أين تحفظ النسخة: واتساب، Drive، أو التنزيلات');
      await BackupActions.share(path);
    } catch (e) {
      if (context.mounted) _toast(context, 'تعذّر الحفظ: $e');
    }
  }

  /// أي فشل (ملف غير نصي، إذن مرفوض، قاعدة مقفلة) يصل للمستخدم كرسالة —
  /// كان يُرمى بلا التقاط فيبدو الزر وكأنه لا يفعل شيئاً.
  Future<void> _import(BuildContext context) async {
    try {
      await _runImport(context);
    } catch (e) {
      if (context.mounted) _toast(context, 'تعذّر الاسترجاع: $e');
    }
  }

  Future<void> _runImport(BuildContext context) async {
    final local = await BackupActions.latestLocal();
    if (!context.mounted) return;

    // نسخة محلية موجودة (بعد تحديث عادي) ⇒ نخيّر بينها وبين ملف خارجي.
    // بلا نسخة محلية (بعد إعادة تثبيت) ⇒ اختيار ملف مباشرة.
    var useLocal = false;
    if (local != null) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text('استرجاع من أين؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('اختيار ملف…'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('آخر نسخة على هذا الجهاز'),
            ),
          ],
        ),
      );
      if (choice == null || !context.mounted) return;
      useLocal = choice;
    }

    final BackupContents contents;
    if (useLocal) {
      contents = await BackupService.read(local!.path);
    } else {
      final text = await BackupActions.pickJson();
      if (text == null) return;
      contents = BackupService.parse(text);
    }
    if (!context.mounted) return;

    if (!contents.ok) {
      _toast(context, contents.error!);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('استرجاع النسخة'),
        content: Text(
          'الملف يحتوي ${contents.items.length} مادة.\n'
          'سيُضاف الجديد ويُحدَّث الأقدم — لا يُحذف شيء موجود.',
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('استرجع'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final r = await store.importBackup(contents.items);
    if (!context.mounted) return;
    _toast(
      context,
      'أُضيف ${r.added} · حُدّث ${r.updated} · بلا تغيير ${r.skipped}',
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _sharingSection(BuildContext context, MedicineStore store) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '🔗 مشاركة المخزون بين الأجهزة',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      const Text(
        'اربط هاتف زميل أو مساعدك بنفس المخزون — أي تعديل من أي جهاز يظهر '
        'للجميع.',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          height: 1.6,
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: GradientFilled(
              child: FilledButton.icon(
                onPressed: () => showSharePairingSheet(context),
                icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                label: const Text('مشاركة مع جهاز آخر'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => showJoinPairingSheet(context, store),
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('الانضمام إلى مخزون'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => showLinkedDevicesSheet(context),
          icon: const Icon(Icons.devices_rounded, size: 18),
          label: const Text('الأجهزة المرتبطة'),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            SmoothPageRoute<void>(
              builder: (_) => DuplicatesScreen(store: store),
            ),
          ),
          icon: const Icon(Icons.manage_search_rounded, size: 18),
          label: const Text('مراجعة التكرارات'),
        ),
      ),
    ],
  );

  Widget _row(String label, String value, Color color) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 78,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
      Expanded(
        child: Text(value, style: const TextStyle(fontSize: 12, height: 1.5)),
      ),
    ],
  );
}
