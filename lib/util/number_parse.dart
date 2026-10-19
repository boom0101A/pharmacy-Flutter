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
