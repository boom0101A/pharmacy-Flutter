import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_settings.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../state/medicine_store.dart';
import '../theme.dart';
import 'pairing_sheet.dart';

/// لوحة الإعدادات — تُفتح من أيقونة الترس في الترويسة.
Future<void> showSettingsSheet(BuildContext context, MedicineStore store) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.bgCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
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
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '⚙️ الإعدادات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
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
                    'إشعار عند فتح التطبيق إذا كان هناك أدوية منتهية أو '
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
                  contentPadding: EdgeInsets.zero,
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
                    color: AppColors.bgDark,
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
                const Divider(color: AppColors.border),
                const SizedBox(height: 10),
                _backupSection(context),

                const SizedBox(height: 22),
                const Divider(color: AppColors.border),
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
        'ملف على جهازك يحفظ كل المواد. اصنعه قبل أي إلغاء تثبيت — إلغاء '
        'التثبيت يمسح البيانات المحلية ويغيّر هوية المزامنة.',
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
            child: FilledButton.icon(
              onPressed: () => _export(context),
              icon: const Icon(Icons.save_alt, size: 18),
              label: const Text('حفظ نسخة'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _import(context),
              icon: const Icon(Icons.restore, size: 18),
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
              uid == null ? Icons.cloud_off : Icons.fingerprint,
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
      final path = await BackupService.export();
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text('✅ حُفظت النسخة'),
          content: SelectableText(
            'المسار:\n$path\n\nانسخ هذا الملف إلى مكان آمن (بطاقة ذاكرة أو '
            'حاسوب) قبل أي إلغاء تثبيت.',
            style: const TextStyle(fontSize: 12, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) _toast(context, 'تعذّر الحفظ: $e');
    }
  }

  Future<void> _import(BuildContext context) async {
    final file = await BackupService.latest();
    if (!context.mounted) return;

    if (file == null) {
      _toast(context, 'لا توجد نسخة احتياطية على هذا الجهاز');
      return;
    }

    final contents = await BackupService.read(file.path);
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
            child: FilledButton.icon(
              onPressed: () => showSharePairingSheet(context),
              icon: const Icon(Icons.qr_code_2, size: 18),
              label: const Text('مشاركة مع جهاز آخر'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => showJoinPairingSheet(context, store),
              icon: const Icon(Icons.link, size: 18),
              label: const Text('الانضمام إلى مخزون'),
            ),
          ),
        ],
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
