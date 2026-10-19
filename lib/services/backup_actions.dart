import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'backup_service.dart';

/// عمليات النسخة الاحتياطية التي تلمس المنصّة (المشاركة واختيار الملفات).
/// حقول قابلة للاستبدال كي تختبر الواجهة بلا قنوات أندرويد حقيقية.
class BackupActions {
  BackupActions._();

  static Future<String> Function() export = BackupService.export;
  static Future<void> Function(String path) share = _share;
  static Future<File?> Function() latestLocal = BackupService.latest;

  /// نص ملف اختاره المستخدم، أو null إن ألغى.
  static Future<String?> Function() pickJson = _pickJson;

  static void reset() {
    export = BackupService.export;
    share = _share;
    latestLocal = BackupService.latest;
    pickJson = _pickJson;
  }

  static Future<void> _share(String path) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'application/json')],
        subject: 'نسخة احتياطية — صيدليتي',
      ),
    );
  }

  static Future<String?> _pickJson() async {
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty) return null;
    // ملف غير نصي لا يرمي هنا: يصل نصاً مشوّهاً فيرفضه BackupService.parse
    // برسالة «ليس نسخة احتياطية صالحة».
    return utf8.decode(await files.single.readAsBytes(), allowMalformed: true);
  }
}
