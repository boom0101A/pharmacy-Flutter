import 'package:intl/intl.dart';

import '../services/app_settings.dart';
import 'number_parse.dart';

/// الأسعار تُخزَّن وتُزامَن **بالدينار دائماً**. الدولار عملة عرض وإدخال
/// فقط، بسعر الصرف الذي يضبطه المستخدم (`AppSettings.usdRate`) — فتبديلها
/// لا يغيّر شيئاً في البيانات ولا على الأجهزة الأخرى.

final _iqdFormat = NumberFormat.decimalPattern('ar');
final _usdFormat = NumberFormat('#,##0.00', 'en');

bool get _usd =>
    AppSettings.instance.currency == 'USD' &&
    AppSettings.instance.usdRate != null;

/// رمز العملة الحالية: «د.ع» أو «IQD» (حسب اللغة) أو «$».
String currencyLabel({bool iqdOnly = false}) {
  if (!iqdOnly && _usd) return r'$';
  return AppSettings.instance.language == 'en' ? 'IQD' : 'د.ع';
}

/// سعر مخزَّن بالدينار كما يُعرض: `7,877 د.ع` أو `7,877 IQD` أو `$6.01`.
///
/// [iqdOnly] للفاتورة الذكية وسجل الفواتير: تطابق الورقة المطبوعة بالدينار.
String formatMoney(num iqd, {bool iqdOnly = false}) {
  final number = formatMoneyNumber(iqd, iqdOnly: iqdOnly);
  if (!iqdOnly && _usd) return '\$$number';
  return '$number ${currencyLabel(iqdOnly: true)}';
}

/// الرقم وحده بعملة العرض (حين يظهر الرمز في عنوان منفصل): `7,877` أو `6.01`.
String formatMoneyNumber(num iqd, {bool iqdOnly = false}) => !iqdOnly && _usd
    ? _usdFormat.format(toDisplay(iqd))
    // الدينار بلا كسور: مجموع «سعر × كمية» قد يحمل كسراً من سعر قديم فيطول
    // الرقم ويُقصّ في الترويسة («31,550,331.6»)
    : _iqdFormat.format(iqd.round());

/// دينار ⇒ عملة العرض.
double toDisplay(num iqd) =>
    _usd ? iqd / AppSettings.instance.usdRate! : iqd.toDouble();

/// عملة العرض ⇒ دينار (بلا كسور مع الدولار — الدينار لا كسور فيه).
double fromDisplay(num value) => _usd
    ? (value * AppSettings.instance.usdRate!).roundToDouble()
    : value.toDouble();

/// نص خانة سعر لقيمة مخزَّنة بالدينار، بعملة العرض: `7,877` أو `6.01`.
String priceInputText(num iqd) {
  if (!_usd) return formatPriceInput(iqd);
  final usd = (toDisplay(iqd) * 100).round() / 100;
  return formatPriceInput(usd);
}

/// قيمة خانة سعر بالدينار للحفظ؛ `null` للفارغ أو غير الصالح.
///
/// [originalIqd]: إن بقي النص كما مُلئ من [priceInputText] يُعاد الدينار
/// الأصلي حرفياً — تعديل مادة بلا لمس سعرها لا يغيّره بتقريب الدولار.
double? priceFromInput(String text, {num? originalIqd}) {
  if (originalIqd != null && text.trim() == priceInputText(originalIqd)) {
    return originalIqd.toDouble();
  }
  final value = parseLocalizedNumber(text);
  return value == null ? null : fromDisplay(value);
}
