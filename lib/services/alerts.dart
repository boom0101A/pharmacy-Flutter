import '../models/medicine.dart';

/// أنواع التنبيه بالأولوية: الأخطر أولاً.
enum AlertKind {
  /// انتهت صلاحيتها.
  expired,

  /// تنتهي خلال [Medicine.urgentDays] يوماً.
  urgent,

  /// نفدت (صفر ولها سعر — الصفر بلا سعر تسجيل ناقص لا مادة نفدت).
  out,

  /// كميتها عند حد التنبيه أو دونه.
  low,

  /// تنتهي خلال [Medicine.soonDays] يوماً — للمتابعة لا للإزعاج: لا تُعدّ في
  /// الجرس ولا في إشعار «جديد»، وتظهر في التذكير الأسبوعي.
  soon,
}

/// تنبيه واحد لمادة واحدة.
class StockAlert {
  const StockAlert(this.item, this.kind, {this.daysLeft});

  final Medicine item;
  final AlertKind kind;

  /// للصلاحية: الأيام المتبقية بالنسبة إلى وقت الحساب (سالبة للمنتهية).
  final int? daysLeft;

  /// مفتاح «تمّ»: يحمل النوع، فلو صارت «العاجلة» منتهية يعود تنبيهها.
  String get key => '${item.id}:${kind.name}';

  /// يستحق الانتباه الآن (الجرس وإشعار «جديد»).
  bool get isCritical => kind != AlertKind.soon;
}

/// تنبيهات المخزون كما هي عند [now] — دالة نقية تُستعمل للجرس ومركز
/// التنبيهات، ولإشعار صباح الغد بحسابها **بتاريخ ذلك الصباح**.
///
/// تنبيه واحد لكل مادة لكل محور: الصلاحية (الأشد بين منتهية/عاجلة/قريبة)
/// والمخزون (نافدة/منخفضة). ما في [dismissed] («تمّ») لا يظهر.
List<StockAlert> computeAlerts(
  Iterable<Medicine> all, {
  required DateTime now,
  Set<String> dismissed = const {},
}) {
  final alerts = <StockAlert>[];
  for (final m in all) {
    final expiry = m.expiry;
    if (expiry != null) {
      // أيام تقويمية لا ساعات: «منتهية منذ 4 أيام» كما في صفحة المادة نفسها
      final days = DateTime(
        expiry.year,
        expiry.month,
        expiry.day,
      ).difference(DateTime(now.year, now.month, now.day)).inDays;
      final kind = expiry.isBefore(now)
          ? AlertKind.expired
          : days <= Medicine.urgentDays
          ? AlertKind.urgent
          : days <= Medicine.soonDays
          ? AlertKind.soon
          : null;
      if (kind != null) alerts.add(StockAlert(m, kind, daysLeft: days));
    }
    if (m.isSoldOut) {
      alerts.add(StockAlert(m, AlertKind.out));
    } else if (m.isLowStock) {
      alerts.add(StockAlert(m, AlertKind.low));
    }
  }
  alerts.removeWhere((a) => dismissed.contains(a.key));
  // بالأولوية، ثم الأقرب انتهاءً، ثم الأقل كمية
  alerts.sort((a, b) {
    final byKind = a.kind.index.compareTo(b.kind.index);
    if (byKind != 0) return byKind;
    final byDays = (a.daysLeft ?? 0).compareTo(b.daysLeft ?? 0);
    if (byDays != 0) return byDays;
    return a.item.quantity.compareTo(b.item.quantity);
  });
  return alerts;
}
