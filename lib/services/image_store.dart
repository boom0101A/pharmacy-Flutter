import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
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

  /// تهيئة مبكرة عند إقلاع التطبيق حتى تعمل [fullPathSync] و[invoicePathSync].
  static Future<void> init() async {
    await _imagesDir();
    await _invoicesDir();
  }

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

  // ---------- صور الفواتير ----------
  //
  // مجلد منفصل عن صور المواد: تنظيف الصور اليتيمة (SyncService) يحذف من
  // مجلد المواد كل ملف لا تشير إليه مادة — وصفحة الفاتورة لا تشير إليها مادة.

  static Directory? _invDir;

  static Future<Directory> _invoicesDir() async {
    if (_invDir != null) return _invDir!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'invoice_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _invDir = dir;
    return dir;
  }

  static String? invoicePathSync(String? fileName) {
    if (fileName == null || fileName.isEmpty || _invDir == null) return null;
    return p.join(_invDir!.path, fileName);
  }

  /// أطول بُعد لصفحة فاتورة محفوظة — يكفي لقراءة الأرقام بالتكبير.
  static const invoiceMaxSide = 1600;

  /// يحفظ صفحة فاتورة مصغّرة (~300 كيلوبايت) ويرجع اسم ملفها.
  static Future<String> saveInvoicePage(File source) async {
    final dir = await _invoicesDir();
    final out = await compute(shrinkInvoicePage, await source.readAsBytes());
    final name = 'inv_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(p.join(dir.path, name)).writeAsBytes(out);
    return name;
  }

  /// دالة عليا تعمل في عزلة منفصلة. صورة لا تُفكّ تُحفظ كما هي.
  @visibleForTesting
  static Uint8List shrinkInvoicePage(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final upright = img.bakeOrientation(decoded);
    final longest = math.max(upright.width, upright.height);
    final out = longest <= invoiceMaxSide
        ? upright
        : upright.width >= upright.height
        ? img.copyResize(upright, width: invoiceMaxSide)
        : img.copyResize(upright, height: invoiceMaxSide);
    return img.encodeJpg(out, quality: 80);
  }

  static Future<void> deleteInvoicePage(String fileName) async {
    final path = invoicePathSync(fileName);
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  static Future<void> deleteFile(String? fileName) async {
    final path = fullPathSync(fileName);
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
