import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// كل نص عربي له ترجمة إنجليزية بنفس المتغيّرات — نص يُضاف للعربية وحدها
/// يظهر بالعربية وسط الواجهة الإنجليزية، ومتغيّر ناقص يُسقط رقماً أو اسماً.
void main() {
  Map<String, Object?> read(String lang) =>
      jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
          as Map<String, Object?>;

  Set<String> keys(Map<String, Object?> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  Set<String> placeholders(String text) =>
      RegExp(r'\{(\w+)[,}]').allMatches(text).map((m) => m.group(1)!).toSet();

  test('الملفان بالمفاتيح نفسها', () {
    final ar = keys(read('ar')), en = keys(read('en'));
    expect(ar.difference(en), isEmpty, reason: 'بلا ترجمة إنجليزية');
    expect(en.difference(ar), isEmpty, reason: 'إنجليزي بلا أصل عربي');
  });

  test('المتغيّرات نفسها في كل نص', () {
    final ar = read('ar'), en = read('en');
    final mismatched = [
      for (final k in keys(ar))
        if (!setEquals(
          placeholders(ar[k] as String),
          placeholders(en[k] as String),
        ))
          k,
    ];
    expect(mismatched, isEmpty);
  });

  test('لا نص إنجليزي فارغ ولا عربي فيه', () {
    final en = read('en');
    final arabic = RegExp(r'[؀-ۿ]');
    final bad = [
      for (final k in keys(en))
        if ((en[k] as String).trim().isEmpty ||
            arabic.hasMatch(en[k] as String))
          k,
    ];
    expect(bad, isEmpty);
  });
}

bool setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
