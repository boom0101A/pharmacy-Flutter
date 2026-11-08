import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/medicine.dart';
import '../state/medicine_store.dart';
import '../theme.dart';
import '../util/money.dart';
import 'glass.dart';

/// تنبيهات «الباركود مسجَّل لمادة أخرى» وحذف تلك المادة — مشتركة بين نموذج
/// المادة وشاشة «إكمال البيانات» فيتطابق السلوك في كل مكان يُدخل فيه باركود.

/// زر «🗑️ حذف المرتبط» داخل تنبيه الباركود المسجَّل.
Widget deleteBarcodeOwnerButton(BuildContext context, VoidCallback onPressed) =>
    TextButton(
      key: const Key('deleteBarcodeOwner'),
      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
      onPressed: onPressed,
      child: Text(context.l10n.formDeleteOwner),
    );

/// تنبيه: الباركود يخص [owner] — لا يُحفظ. يعيد true إن اختار المستخدم
/// حذف المادة المالكة، وnull عند «حسناً» أو الإغلاق.
Future<bool?> showBarcodeOwnerDialog(BuildContext context, Medicine owner) {
  return showGlassDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: Text(context.l10n.formBarcodeTakenTitle),
      content: Text(
        context.l10n.formBarcodeOwnerBody(
          owner.barcode,
          owner.name,
          owner.quantity,
          formatMoney(owner.price),
        ),
        style: const TextStyle(fontSize: 13, height: 1.6),
      ),
      actions: [
        deleteBarcodeOwnerButton(context, () => Navigator.pop(ctx, true)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.ok),
        ),
      ],
    ),
  );
}

/// يحذف [owner] بعد تأكيد صريح بالاسم والكمية والسعر. يعيد true إن حُذفت
/// فعلاً (فصار الباركود حراً)، وfalse عند الإلغاء أو الفشل.
Future<bool> deleteBarcodeOwner(
  BuildContext context,
  MedicineStore store,
  Medicine owner,
) async {
  final l10n = context.l10n;
  final ok = await showGlassDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      // «المستلزم» لا «الدواء» حين تكون المادة المرتبطة مستلزماً طبياً
      title: Text(
        owner.type == ItemType.supply
            ? l10n.formDeleteOwnerTitleSupply
            : l10n.formDeleteOwnerTitle,
      ),
      content: Text(
        l10n.formDeleteOwnerBody(
          owner.name,
          owner.barcode,
          owner.quantity,
          formatMoney(owner.price),
        ),
        style: const TextStyle(fontSize: 13, height: 1.6),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('confirmDeleteOwner'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  void toast(String text, {Color? color}) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  try {
    await store.delete(owner);
  } catch (e) {
    toast(l10n.formSaveFailed('$e'), color: AppColors.danger);
    return false;
  }
  HapticFeedback.mediumImpact();
  toast(l10n.formOwnerDeleted(owner.name));
  return true;
}
