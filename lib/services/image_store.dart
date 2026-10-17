import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// يحفظ صور الأدوية كملفات داخل مجلد التطبيق ويخزن اسم الملف فقط في القاعدة.
/// (اسم الملف وليس المسار الكامل، حتى لا تنكسر الصور إذا تغير مسار التطبيق).
class ImageStore {
  ImageStore._();

  static Directory? _dir;

  static Future<Directory> _imagesDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'medicine_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  /// تهيئة مبكرة عند إقلاع التطبيق حتى تعمل [fullPathSync].
  static Future<void> init() => _imagesDir();

  /// مسار مجلد الصور (بعد [init]).
  static String? get dirPathSync => _dir?.path;

  /// المسار الكامل للصورة انطلاقاً من اسم الملف المخزّن.
  static String? fullPathSync(String? fileName) {
    if (fileName == null || fileName.isEmpty || _dir == null) return null;
    return p.join(_dir!.path, fileName);
  }

  /// نسخ ملف صورة (من الكاميرا أو المعرض) إلى مجلد التطبيق. يرجع اسم الملف.
  static Future<String> saveFile(File source) async {
    final dir = await _imagesDir();
    final ext = p.extension(source.path).isEmpty
        ? '.jpg'
        : p.extension(source.path).toLowerCase();
    final name = '${DateTime.now().microsecondsSinceEpoch}$ext';
    await source.copy(p.join(dir.path, name));
    return name;
  }

  /// حفظ بايتات صورة نُزّلت من الإنترنت. يرجع اسم الملف.
  static Future<String> saveBytes(
    List<int> bytes, {
    String ext = '.jpg',
  }) async {
    final dir = await _imagesDir();
    final name = '${DateTime.now().microsecondsSinceEpoch}$ext';
    await File(p.join(dir.path, name)).writeAsBytes(bytes);
    return name;
  }

  static Future<void> deleteFile(String? fileName) async {
    final path = fullPathSync(fileName);
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
