import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'app_settings.dart';
import 'image_store.dart';

/// نتيجة البحث في قاعدة الباركود المشتركة.
class RegistryEntry {
  final String name;

  /// اسم ملف الصورة بعد حفظها محلياً (إن وُجدت).
  final String? imageFileName;

  /// عدد الصيدليات التي أكّدت هذا الاسم — مؤشر ثقة.
  final int confirmations;

  const RegistryEntry({
    required this.name,
    this.imageFileName,
    this.confirmations = 1,
  });
}

/// قاعدة باركود مشتركة بين كل مستخدمي التطبيق.
///
/// الفكرة: قواعد البيانات العالمية (OpenFoodFacts / FDA) لا تغطي أدوية
/// السوق العربي. لذلك يبني المستخدمون قاعدتهم بأنفسهم: أول من يدخل دواءً
/// غير معروف يساهم باسمه وصورته، فيجده الجميع جاهزاً في المرة التالية.
///
/// **لا تُشارك الأسعار ولا الكميات إطلاقاً** — بيانات تجارية خاصة بكل صيدلية.
class BarcodeRegistry {
  BarcodeRegistry._();

  static const _collection = 'barcodes';

  /// حد أقصى آمن للصورة المشتركة (مستند Firestore يقبل 1 ميجابايت).
  static const _maxThumbBytes = 120 * 1024;
  static const _thumbWidth = 400;

  static FirebaseFirestore? _db;

  /// تُستدعى من SyncService بعد تهيئة Firebase بنجاح.
  static void attach(FirebaseFirestore db) => _db = db;

  static bool get isEnabled => _db != null;

  // ---------------------------------------------------------------
  //  قراءة
  // ---------------------------------------------------------------

  static Future<RegistryEntry?> lookup(String barcode) async {
    final db = _db;
    final code = barcode.trim();
    if (db == null || code.isEmpty) return null;

    try {
      final doc = await db.collection(_collection).doc(code).get();
      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      final name = (data['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) return null;

      return RegistryEntry(
        name: name,
        imageFileName: await _decodeThumb(data['thumb']),
        confirmations: (data['confirmations'] as num?)?.toInt() ?? 1,
      );
    } catch (e) {
      debugPrint('تعذّر البحث في قاعدة الباركود المشتركة: $e');
      return null;
    }
  }

  static Future<String?> _decodeThumb(Object? thumb) async {
    if (thumb is! String || thumb.isEmpty) return null;
    try {
      return await ImageStore.saveBytes(base64Decode(thumb));
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------
  //  مساهمة
  // ---------------------------------------------------------------

  /// رفع دواء إلى القاعدة المشتركة بعد حفظه محلياً.
  /// لا يرمي استثناءً أبداً — فشل المساهمة لا يعني فشل الحفظ.
  static Future<void> contribute({
    required String barcode,
    required String name,
    String? imageFileName,
  }) async {
    final db = _db;
    final code = barcode.trim();
    if (db == null || code.isEmpty || name.trim().isEmpty) return;

    // المستخدم يستفيد من القاموس دائماً، لكنه يختار متى يساهم فيه
    if (!AppSettings.instance.contributeToRegistry) return;

    try {
      final ref = db.collection(_collection).doc(code);
      final existing = await ref.get();

      // إن كان موجوداً بنفس الاسم وله صورة، نكتفي بزيادة عدّاد التأكيد
      if (existing.exists) {
        final data = existing.data() ?? {};
        final sameName =
            (data['name'] as String?)?.trim().toLowerCase() ==
            name.trim().toLowerCase();
        final hasThumb = (data['thumb'] as String?)?.isNotEmpty ?? false;

        if (sameName && hasThumb) {
          await ref.update({'confirmations': FieldValue.increment(1)});
          return;
        }

        // نضيف الصورة الناقصة فقط دون المساس بالاسم الموجود
        if (sameName && !hasThumb) {
          final thumb = await _buildThumb(imageFileName);
          if (thumb != null) {
            await ref.update({
              'thumb': thumb,
              'confirmations': FieldValue.increment(1),
            });
          }
          return;
        }

        // اسم مختلف: لا نستبدل مساهمة غيرنا، نسجّلها كاقتراح فقط
        await ref.update({
          'alternateNames': FieldValue.arrayUnion([name.trim()]),
        });
        return;
      }

      // مساهمة جديدة
      await ref.set({
        'barcode': code,
        'name': name.trim(),
        'thumb': await _buildThumb(imageFileName),
        'confirmations': 1,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('تعذّرت المساهمة في قاعدة الباركود المشتركة: $e');
    }
  }

  /// تصغير الصورة إلى مصغّرة خفيفة صالحة للتخزين داخل مستند Firestore.
  static Future<String?> _buildThumb(String? imageFileName) async {
    final path = ImageStore.fullPathSync(imageFileName);
    if (path == null) return null;

    try {
      final file = File(path);
      if (!await file.exists()) return null;

      // العمل الثقيل خارج خيط الواجهة
      final bytes = await compute(_resizeBytes, await file.readAsBytes());
      if (bytes == null || bytes.length > _maxThumbBytes) return null;
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('تعذّر إنشاء مصغّرة الصورة: $e');
      return null;
    }
  }

  /// يعمل في isolate منفصل — يجب أن تكون دالة عليا.
  static Uint8List? _resizeBytes(Uint8List original) {
    final decoded = img.decodeImage(original);
    if (decoded == null) return null;
    final resized = img.copyResize(decoded, width: _thumbWidth);
    return img.encodeJpg(resized, quality: 70);
  }
}
