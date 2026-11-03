import 'package:flutter/widgets.dart';

import '../services/app_settings.dart';

/// يعيد بناء الواجهة كلها **مرة واحدة** حين تتغيّر اللغة أو عملة العرض أو
/// سعر الصرف — وفقط حينها.
///
/// الأسعار (`formatMoney`) ونصوص الخدمات (`L10n.current`) تُقرأ من
/// [AppSettings] مباشرة بلا اعتماد في شجرة الواجهة، فلا شيء يعيد بناءها
/// تلقائياً عند التبديل. كان ذلك يحدث بالصدفة: السمة تُبنى من جديد مع كل
/// إشعار من الإعدادات فتُعاد الواجهة كلها مع حركة تبديل سمة (200ms) — حتى
/// عند حفظ معرّف الصيدلية. الآن: السمة ثابتة، والتحديث مقصود ومحدود.
class DisplayPrefsScope extends StatefulWidget {
  const DisplayPrefsScope({super.key, required this.child});

  final Widget child;

  @override
  State<DisplayPrefsScope> createState() => _DisplayPrefsScopeState();
}

class _DisplayPrefsScopeState extends State<DisplayPrefsScope> {
  final _settings = AppSettings.instance;

  /// يُحسب عند الإنشاء لا عند أول قراءة: `late` بقيمة كسولة كانت تُقرأ أول
  /// مرة داخل [_onSettings] بعد التغيير نفسه، فلا يُرى أي فرق.
  late String _prefs;

  String _current() =>
      '${_settings.language}|${_settings.currency}|${_settings.usdRate}';

  @override
  void initState() {
    super.initState();
    _prefs = _current();
    _settings.addListener(_onSettings);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() {
    final next = _current();
    if (next == _prefs || !mounted) return;
    _prefs = next;
    // كل عنصر تحتنا يُبنى من جديد (حالته محفوظة: لا شيء يُنشأ من الصفر)
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
