import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../screens/crop_screen.dart';
import '../widgets/smooth_route.dart';
import 'image_store.dart';
import 'product_cropper.dart';

/// بديل منتقي الصور للاختبارات — يعيد مسار الصورة أو null.
typedef PickImagePath = Future<String?> Function(ImageSource source);

/// تصوير/اختيار صورة مادة → القص التلقائي مع التأكيد → حفظها في مجلد الصور.
///
/// يعيد اسم الملف المحفوظ، أو null إن ألغى المستخدم في أي خطوة. مشترك بين
/// نموذج الإضافة وشاشة «إكمال البيانات» حتى يبقى المسار واحداً.
Future<String?> pickProductImage(
  BuildContext context,
  ImageSource source, {
  ProductCropper cropper = const ProductCropper(),
  PickImagePath? pickImagePath,
}) async {
  final path = pickImagePath != null
      ? await pickImagePath(source)
      : (await ImagePicker().pickImage(
          source: source,
          // دقة أعلى للقص؛ الناتج يُصغَّر إلى 1200 بعده (ProductCropper)
          maxWidth: 2400,
          imageQuality: 85,
        ))?.path;
  if (path == null || !context.mounted) return null;
  // القص حول العلبة تلقائياً مع تأكيد المستخدم؛ الرجوع يُلغي التغيير
  final chosen = await Navigator.of(context).push<File>(
    SmoothPageRoute(
      builder: (_) => CropScreen(file: File(path), cropper: cropper),
    ),
  );
  if (chosen == null) return null;
  final saved = await ImageStore.saveFile(chosen);
  // نُسخت إلى مجلد الصور — المؤقتة (القص وملف المنتقي) لم تعد لازمة
  for (final temp in {chosen.path, path}) {
    unawaited(File(temp).delete().then((_) {}, onError: (_) {}));
  }
  return saved;
}
