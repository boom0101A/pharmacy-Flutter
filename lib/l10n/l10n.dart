import 'package:flutter/widgets.dart';

import '../services/app_settings.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

/// نصوص الواجهة بلغة الإعدادات (العربية أو الإنجليزية).
///
/// البيانات نفسها — أسماء الأدوية والمجهّزين والشركات — لا تمرّ من هنا ولا
/// تُترجم.
extension L10nContext on BuildContext {
  /// من شجرة الواجهة (فتُعاد البناء عند تبديل اللغة)، وإلا لغة الإعدادات —
  /// شاشات تُبنى بلا مفوّض الترجمة (الاختبارات) تبقى تعمل.
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      L10n.current;
}

/// للنصوص خارج الواجهة: الإشعارات، رسائل المزامنة، تنبيهات أسطر الفاتورة.
class L10n {
  static AppLocalizations get current =>
      lookupAppLocalizations(Locale(AppSettings.instance.language));

  /// اتجاه الواجهة للغة الإعدادات.
  static TextDirection get direction => AppSettings.instance.language == 'en'
      ? TextDirection.ltr
      : TextDirection.rtl;
}
