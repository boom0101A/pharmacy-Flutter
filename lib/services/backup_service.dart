import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/medicine_db.dart';
import '../models/invoice.dart';
import '../models/medicine.dart';
import '../l10n/l10n.dart';

/// نسخة احتياطية إلى ملف على الجهاز — مستقلة تماماً عن الحساب والسحابة.
///
/// **لماذا هذا ضروري:** هوية المزامنة مجهولة ومربوطة بالتثبيت. إلغاء تثبيت
/// التطبيق (وهو مطلوب مرة واحدة عند تغيير مفتاح التوقيع) يمسح قاعدة SQLite
/// **ويولّد هوية جديدة**، فتبقى سجلات السحابة مملوكة للهوية القديمة ولا يراها
/// الجهاز. ملف النسخة الاحتياطية هو ما يعيد كل شيء في تلك الحالة.
class BackupService {
  BackupService._();

  /// صيغة الملف — لو تغيّر الشكل مستقبلاً نعرف كيف نقرأ القديم.
  static const _formatVersion = 1;

  /// كتابة كل المواد إلى ملف JSON. يعيد مسار الملف.
  ///
  /// الصور لا تُضمَّن (قد تبلغ مئات الميغابايت) — تُذكر أسماؤها فقط.
  static Future<String> export() async {
    final items = await MedicineDb.instance.getAll();
    final invoices = await MedicineDb.instance.allInvoices();
    final payload = {
      'format': _formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'count': items.length,
      'items': items.map((m) => m.toMap()).toList(),
      // سجل الفواتير بلا صورها (محلية وكبيرة)
      'invoices': invoices.map((i) => i.toCloud()).toList(),
    };

    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File(p.join(dir.path, 'saydaliyati-backup-$stamp.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    await pruneOld(dir);
    return file.path;
  }

  /// كم نسخة تبقى داخل التطبيق — كل «حفظ نسخة» كان يضيف ملفاً بلا حذف.
  /// النسخ الحقيقية الآمنة هي ما شاركه المستخدم خارج الهاتف.
  static const keepLocal = 5;

  /// يحذف نسخ التطبيق الأقدم ويُبقي أحدث [keep]. لا يرمي.
  @visibleForTesting
  static Future<void> pruneOld(Directory dir, {int keep = keepLocal}) async {
    try {
      final files = await dir
          .list()
          .where(
            (e) =>
                e is File &&
                p.basename(e.path).startsWith('saydaliyati-backup-'),
          )
          .cast<File>()
          .toList();
      if (files.length <= keep) return;
      // الاسم يحمل ختم الوقت بصيغة ISO فيُرتَّب أبجدياً كترتيبه الزمني
      files.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
      for (final old in files.skip(keep)) {
        await old.delete();
      }
    } catch (e) {
      debugPrint('تعذّر تنظيف النسخ القديمة: $e');
    }
  }

  /// قراءة ملف نسخة احتياطية وإرجاع المواد التي فيه.
  ///
  /// لا يكتب شيئاً في القاعدة — القرار للمستدعي بعد عرض العدد على المستخدم.
  static Future<BackupContents> read(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return BackupContents(error: L10n.current.backupNotFound);
      }
      return parse(await file.readAsString());
    } catch (e) {
      debugPrint('تعذّرت قراءة النسخة الاحتياطية: $e');
      return BackupContents(error: L10n.current.backupReadFailed('$e'));
    }
  }

  /// قراءة نسخة احتياطية من نصها مباشرة — ملف مختار من خارج التطبيق يصل
  /// أحياناً كرابط محتوى بلا مسار قرص، فنقرأ نصه بدل فتحه كملف.
  static BackupContents parse(String json) {
    try {
      final root = jsonDecode(json);
      if (root is! Map) {
        return BackupContents(error: L10n.current.backupInvalid);
      }

      final rawItems = root['items'];
      if (rawItems is! List) {
        return BackupContents(error: L10n.current.backupNoItems);
      }

      final items = <Medicine>[];
      var skipped = 0;
      for (final raw in rawItems) {
        // سجل تالف واحد يجب ألا يُفقد بقية النسخة الاحتياطية
        try {
          if (raw is! Map) {
            skipped++;
            continue;
          }
          items.add(Medicine.fromMap(Map<String, Object?>.from(raw)));
        } catch (_) {
          skipped++;
        }
      }

      // نسخ أقدم بلا فواتير — تُقرأ عادياً
      final invoices = <Invoice>[];
      final rawInvoices = root['invoices'];
      if (rawInvoices is List) {
        for (final raw in rawInvoices) {
          try {
            if (raw is Map) {
              invoices.add(Invoice.fromMap(Map<String, Object?>.from(raw)));
            }
          } catch (_) {
            skipped++;
          }
        }
      }

      return BackupContents(items: items, invoices: invoices, skipped: skipped);
    } catch (e) {
      debugPrint('تعذّرت قراءة النسخة الاحتياطية: $e');
      return BackupContents(error: L10n.current.backupReadFailed('$e'));
    }
  }

  /// أحدث ملف نسخة احتياطية موجود، أو null.
  static Future<File?> latest() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files =
          (await Directory(
            dir.path,
          ).list().where((e) => e is File).cast<File>().toList())..removeWhere(
            (f) => !p.basename(f.path).startsWith('saydaliyati-backup-'),
          );
      if (files.isEmpty) return null;
      files.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );
      return files.first;
    } catch (_) {
      return null;
    }
  }
}

class BackupContents {
  final List<Medicine> items;
  final List<Invoice> invoices;

  /// سجلات تعذّرت قراءتها ولم توقف الاستيراد.
  final int skipped;
  final String? error;

  const BackupContents({
    this.items = const [],
    this.invoices = const [],
    this.skipped = 0,
    this.error,
  });

  bool get ok => error == null;
}
