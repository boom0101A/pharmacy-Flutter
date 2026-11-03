import 'package:flutter/services.dart';

/// لوحات المفاتيح العربية تكتب `١٢٥٠`، وأسعار الدينار تُكتب كثيراً `1,250` —
/// `double.tryParse` يرفض الاثنين فكان السعر يُحفظ صفراً بصمت.
String _normalize(String input) {
  final b = StringBuffer();
  for (final c in input.trim().runes) {
    if (c >= 0x0660 && c <= 0x0669) {
      b.writeCharCode(0x30 + c - 0x0660);
    } else if (c >= 0x06F0 && c <= 0x06F9) {
      b.writeCharCode(0x30 + c - 0x06F0);
    } else if (c == 0x066B) {
      b.write('.');
    } else if (c == 0x2C || c == 0x066C || c == 0x20 || c == 0xA0) {
      continue; // فواصل آلاف ومسافات
    } else {
      b.writeCharCode(c);
    }
  }
  return b.toString();
}

/// `null` للنص الفارغ أو غير الصالح.
double? parseLocalizedNumber(String input) {
  final s = _normalize(input);
  return s.isEmpty ? null : double.tryParse(s);
}

/// `null` للنص الفارغ أو غير الصالح أو الكسري.
int? parseLocalizedInt(String input) {
  final s = _normalize(input);
  return s.isEmpty ? null : int.tryParse(s);
}

/// يجمّع الجزء الصحيح بفاصلة كل ثلاث خانات: `1234567` ⇒ `1,234,567`.
String _group(String digits) {
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
    b.write(digits[i]);
  }
  return b.toString();
}

/// السعر كما يُكتب في خانته: `1764` ⇒ `1,764`، `1234.5` ⇒ `1,234.5`.
///
/// أرقام لاتينية وفاصلة `,` — مطابق لما يكتبه
/// [ThousandsSeparatorInputFormatter] حرفياً، ويقرؤه [parseLocalizedNumber].
String formatPriceInput(num value) {
  final negative = value < 0;
  final v = value.abs();
  final raw = v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  final dot = raw.indexOf('.');
  final whole = dot < 0 ? raw : raw.substring(0, dot);
  final fraction = dot < 0 ? '' : raw.substring(dot);
  return '${negative ? '-' : ''}${_group(whole)}$fraction';
}

/// فواصل الآلاف أثناء الكتابة في خانات الأسعار (الدينار يُقرأ `1,764` لا
/// `1764`).
///
/// يوحّد الأرقام العربية-الهندية إلى لاتينية، ويقبل نقطة عشرية واحدة، ويبقي
/// المؤشر بعد الرقم نفسه الذي كان بعده — الكتابة أو الحذف في الوسط لا
/// يقفزان به إلى آخر النص.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final sel = newValue.selection.baseOffset;
    final cursor = sel < 0 || sel > text.length ? text.length : sel;

    // الأرقام والنقطة فقط، ومعها عدد ما بقي منها قبل المؤشر
    final raw = StringBuffer();
    var keptBefore = 0;
    var hasDot = false;
    var i = 0;
    for (final c in text.runes) {
      String? kept;
      if (c >= 0x30 && c <= 0x39) {
        kept = String.fromCharCode(c);
      } else if (c >= 0x0660 && c <= 0x0669) {
        kept = String.fromCharCode(0x30 + c - 0x0660);
      } else if (c >= 0x06F0 && c <= 0x06F9) {
        kept = String.fromCharCode(0x30 + c - 0x06F0);
      } else if ((c == 0x2E || c == 0x066B) && !hasDot) {
        hasDot = true;
        kept = '.';
      }
      if (kept != null) {
        raw.write(kept);
        if (i < cursor) keptBefore++;
      }
      i += String.fromCharCode(c).length;
    }

    var s = raw.toString();
    if (s.isEmpty) {
      return const TextEditingValue(
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    if (s.startsWith('.')) {
      s = '0$s';
      if (keptBefore > 0) keptBefore++;
    }

    final dot = s.indexOf('.');
    final formatted = dot < 0
        ? _group(s)
        : '${_group(s.substring(0, dot))}${s.substring(dot)}';

    // المؤشر بعد keptBefore من غير الفواصل
    var offset = 0;
    for (
      var seen = 0;
      offset < formatted.length && seen < keptBefore;
      offset++
    ) {
      if (formatted[offset] != ',') seen++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// أرقام عربية-هندية وفارسية ⇒ أرقام لاتينية، وبقية النص كما هو.
///
/// للبحث: الباركود محفوظ بأرقام لاتينية، ولوحة المفاتيح العربية تكتب `٦٢٨…`
/// فلا يطابق شيئاً.
String normalizeDigits(String input) {
  final b = StringBuffer();
  for (final c in input.runes) {
    if (c >= 0x0660 && c <= 0x0669) {
      b.writeCharCode(0x30 + c - 0x0660);
    } else if (c >= 0x06F0 && c <= 0x06F9) {
      b.writeCharCode(0x30 + c - 0x06F0);
    } else {
      b.writeCharCode(c);
    }
  }
  return b.toString();
}
