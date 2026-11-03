import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/medicine.dart';
import '../l10n/l10n.dart';
import 'alerts.dart';
import 'pharmacy_prefs.dart';

/// تنبيه صلاحية ومخزون مجدول يومياً عند الساعة 9 صباحاً — يظهر حتى والتطبيق
/// مغلق، بمحتوى مُحسَب سلفاً من آخر بيانات حصلنا عليها (`zonedSchedule` لا
/// يشغّل شيفرة Dart في وقت الظهور، فنُعيد الجدولة بعد كل تعديل بيانات لتبقى
/// قريبة الحداثة).
///
/// **لا إشعار فوري عند فتح التطبيق:** كان يوجد سابقاً، فصار يكرّر نفس النص
/// مرتين في اليوم نفسه بعد تفعيل الجدولة الحقيقية — ولا معنى لإشعار يخبرك
/// بما تراه أمامك وأنت داخل التطبيق أصلاً.
///
/// النقر على الإشعار يفتح التطبيق ويحمل `payload` نصياً بالصيغة
/// `"type:medicine|filter:expiringSoon"` — HomeScreen يستهلكه ويطبّق التبويب
/// والفلتر مباشرة، فيرى المستخدم الأدوية القريبة من الانتهاء فوراً.
class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'stock_alerts';
  static String get _channelName => L10n.current.notifChannel;
  static String get _channelDesc => L10n.current.notifChannelDesc;

  /// إشعار الجدولة اليومية.
  static const _dailyId = 1002;

  /// الوقت الافتراضي للإشعار اليومي — 9 صباحاً وقت الجهاز.
  static const _dailyHour = 9;
  static const _dailyMinute = 0;

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _tzInitialized = false;

  /// آخر حمولة (payload) وصلت من نقر إشعار — HomeScreen يستهلكها ويمسحها.
  /// null إن لم يُنقر إشعار، أو بعد الاستهلاك.
  String? _pendingPayload;
  String? get pendingPayload => _pendingPayload;

  /// تُستدعى من HomeScreen بعد تطبيق الحمولة — تمنع تكرار تطبيق نفس الفلتر
  /// عند إعادة بناء الواجهة أو الخروج والعودة.
  void consumePendingPayload() {
    if (_pendingPayload == null) return;
    _pendingPayload = null;
    notifyListeners();
  }

  /// هل قُرئت حمولة الإطلاق؟ — علَم مستقل عن نجاح بقية التهيئة.
  ///
  /// `getNotificationAppLaunchDetails()` يعيد **نفس** حمولة الإطلاق طوال عمر
  /// العملية. لو أُعيدت قراءتها بعد أن استهلكها HomeScreen، دهست حمولة نقرة
  /// أحدث وطُبِّق فلتر خاطئ. تُقرأ مرة واحدة فقط بحكم هذا العلَم.
  static bool _launchPayloadRead = false;

  /// دورة التهيئة الجارية — تُخزَّن كـFuture لا كبولياني.
  ///
  /// البولياني السابق كان يُضبط في نهاية `try` فقط، فأي رمية في الأثناء تجعل
  /// كل استدعاء لاحق يعيد التهيئة كاملة (إعادة إنشاء القناة، إعادة طلب
  /// الأذونات، وإعادة قراءة حمولة الإطلاق القديمة). وبما أن `init()` تُستدعى
  /// من عدة مسارات متوازية (`load` → `scheduleDailyDigest`، والإعدادات)،
  /// كان استدعاءان متزامنان يتصادمان داخل الإضافة عند طلب الإذن.
  static Future<void>? _initFuture;

  /// تهيئة القناة والمنطقة الزمنية — لا ترمي استثناءً أبداً.
  ///
  /// **لا تطلب أذونات النظام هنا:** طلب إذن الإنذارات الدقيقة يفتح شاشة
  /// إعدادات النظام ولا يكتمل حتى يعود المستخدم منها. استدعاؤها قبل
  /// `runApp()` كان يترك التطبيق بلا أي واجهة (شاشة سوداء) على أندرويد 12
  /// حيث `USE_EXACT_ALARM` غير موجود أصلاً. الأذونات تُطلب في
  /// [requestPermissions] من مسار لا يحجب الإقلاع.
  Future<void> init() => _initFuture ??= _doInit();

  Future<void> _doInit() async {
    try {
      // 1) المنطقة الزمنية — لازمة لـzonedSchedule (بلاها كل جدولة تفشل صامتة)
      if (!_tzInitialized) {
        tz.initializeTimeZones();
        try {
          final name = await FlutterTimezone.getLocalTimezone();
          tz.setLocalLocation(tz.getLocation(name));
        } catch (e) {
          // اسم منطقة غير معروف على بعض أجهزة OEM. الارتداد إلى UTC يُبقي
          // الجدولة تعمل (بفارق ساعات) بدل موتها الصامت للأبد — وهو ما كان
          // يحدث: علَم ثابت يبقى false فيتخطّى كل جدولة لاحقة بلا أي إشارة.
          debugPrint('تعذّرت قراءة منطقة الجهاز الزمنية — ارتداد إلى UTC: $e');
          tz.setLocalLocation(tz.getLocation('UTC'));
        }
        _tzInitialized = true;
      }

      // 2) قناة الإشعارات + معالج النقر
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        settings: const InitializationSettings(android: androidInit),
        onDidReceiveNotificationResponse: _onTap,
      );

      await _android?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.defaultImportance,
        ),
      );

      // 3) هل فُتح التطبيق أصلاً بضغطة على إشعار كان مجدولاً؟ — مرة واحدة
      if (!_launchPayloadRead) {
        _launchPayloadRead = true;
        final launchDetails = await _plugin.getNotificationAppLaunchDetails();
        if (launchDetails?.didNotificationLaunchApp == true) {
          final payload = launchDetails?.notificationResponse?.payload;
          if (payload != null && payload.isNotEmpty) {
            _pendingPayload = payload;
            // التهيئة صارت غير حاجبة للإقلاع، فقد يكون HomeScreen بُني قبل
            // وصولنا هنا — الإخطار يضمن أن يلتقطها مستمعه.
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('تعذّرت تهيئة التنبيهات المحلية: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// طلب أذونات النظام — يُستدعى بعد بناء الواجهة لا قبلها.
  ///
  /// إذن الإنذارات الدقيقة يفتح شاشة إعدادات النظام على أندرويد 12+، ولا
  /// يُطلب إلا إن لم يكن ممنوحاً أصلاً (على أندرويد 13+ يمنحه
  /// `USE_EXACT_ALARM` في manifest تلقائياً فلا تظهر شاشة).
  Future<void> requestPermissions() async {
    await init();
    try {
      await _android?.requestNotificationsPermission();
      final canExact = await _android?.canScheduleExactNotifications();
      if (canExact == false) {
        await _android?.requestExactAlarmsPermission();
      }
    } catch (e) {
      debugPrint('تعذّر طلب أذونات الإشعارات: $e');
    }
  }

  /// callback ثابت (لا يمسك حالة) — flutter_local_notifications يشترط ذلك
  /// لبقاء المعالج صحيحاً عبر عزلات الخلفية.
  static void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    instance._pendingPayload = payload;
    instance.notifyListeners();
  }

  /// يبني نص الملخّص من قائمة كل المواد (القسمين معاً)، أو null إن لم يكن
  /// هناك ما يستدعي تنبيهاً. دالة صِرفة قابلة للاختبار بلا لمس أي شيء خارجي.
  @visibleForTesting
  static String? buildSummary(List<Medicine> all) {
    final expired = all.where((m) => m.isExpired).length;
    // isExpiringSoon تُحسب بغضّ النظر عن انتهاء الصلاحية فعلياً — نستثني
    // المنتهي هنا حتى لا يُحسب في العدّين معاً
    final expiringSoon = all
        .where((m) => !m.isExpired && m.isExpiringSoon)
        .length;
    // النافد الحقيقي فقط — الصفر بلا سعر تسجيل ناقص لا مادة يجب طلبها
    final outOfStock = all.where((m) => m.isSoldOut).length;
    final lowStock = all.where((m) => m.isLowStock).length;

    final parts = <String>[
      if (expired > 0) L10n.current.notifExpired(expired),
      if (expiringSoon > 0) L10n.current.notifExpiring(expiringSoon),
      if (outOfStock > 0) L10n.current.notifOut(outOfStock),
      if (lowStock > 0) L10n.current.notifLow(lowStock),
    ];

    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// يحدّد الحمولة (payload) التي تُنقل عند نقر الإشعار — بأولوية:
  ///   1. صلاحية دواء (منتهي/قارب) → قسم الأدوية بفلتر «قاربة الانتهاء»
  ///   2. صلاحية مستلزم → قسم المستلزمات بفلتر «قاربة الانتهاء»
  ///   3. نافد من الأدوية → قسم الأدوية بفلتر «منخفض أو نافد»
  ///   4. نافد من المستلزمات → قسم المستلزمات بفلتر «منخفض أو نافد»
  ///   5. منخفض أدوية/مستلزمات → فلتر «منخفض»
  ///   6. بلا مشاكل → null (لا حمولة، الإشعار لن يُجدول أصلاً)
  ///
  /// الأولوية تخدم مطلب المستخدم: «خصوصاً للأدوية بحيث يفتح على القارب من
  /// الانتهاء أو المنتهي» — فما دام في الأدوية عنصر صلاحية، يُقصَد إليه أولاً.
  @visibleForTesting
  static String? computePayload(List<Medicine> all) {
    bool hasExpiryIssue(Medicine m) => m.isExpired || m.isExpiringSoon;

    final medicines = all.where((m) => m.type == ItemType.medicine);
    final supplies = all.where((m) => m.type == ItemType.supply);

    if (medicines.any(hasExpiryIssue)) {
      return 'type:medicine|filter:expiringSoon';
    }
    if (supplies.any(hasExpiryIssue)) {
      return 'type:supply|filter:expiringSoon';
    }
    // النافد يُعرض ضمن «منخفض أو نافد»
    if (medicines.any((m) => m.isSoldOut)) {
      return 'type:medicine|filter:lowStock';
    }
    if (supplies.any((m) => m.isSoldOut)) {
      return 'type:supply|filter:lowStock';
    }
    if (medicines.any((m) => m.isLowStock)) {
      return 'type:medicine|filter:lowStock';
    }
    if (supplies.any((m) => m.isLowStock)) {
      return 'type:supply|filter:lowStock';
    }
    return null;
  }

  /// حمولة النقر: تفتح مركز التنبيهات.
  static const alertsPayload = 'alerts';

  static const _weeklyId = 1003;
  static const _kNotified = 'notif_notified_keys';
  static const _kPlanned = 'notif_planned_keys';
  static const _kPlannedAt = 'notif_planned_at';

  /// ما يُبلَّغ عنه صباح [slot]: التنبيهات الحرجة **بتاريخ ذلك الصباح** التي
  /// لم يُبلَّغ عنها من قبل ولم تُخفَ بـ«تمّ». [notified] يُنظَّف مما انحلّ،
  /// فإن عادت المشكلة لاحقاً تُبلَّغ من جديد.
  @visibleForTesting
  static ({List<StockAlert> fresh, Set<String> notified}) planNew(
    List<Medicine> all, {
    required DateTime slot,
    required Set<String> notified,
    Set<String> dismissed = const {},
  }) {
    final critical = computeAlerts(
      all,
      now: slot,
      dismissed: dismissed,
    ).where((a) => a.isCritical).toList();
    final active = {for (final a in critical) a.key};
    final keep = notified.intersection(active);
    return (
      fresh: [
        for (final a in critical)
          if (!keep.contains(a.key)) a,
      ],
      notified: keep,
    );
  }

  /// سطر لكل مادة (حتى 5) ثم «و N أخرى».
  @visibleForTesting
  static ({List<String> lines}) buildAlertsContent(List<StockAlert> alerts) {
    final l = L10n.current;
    String line(StockAlert a) {
      final name = a.item.name;
      final days = a.daysLeft ?? 0;
      return switch (a.kind) {
        AlertKind.expired => l.notifLineExpired(name),
        AlertKind.urgent =>
          days <= 0 ? l.notifLineToday(name) : l.notifLineUrgent(name, days),
        AlertKind.out => l.notifLineOut(name),
        AlertKind.low => l.notifLineLow(name, a.item.quantity),
        AlertKind.soon => l.notifLineSoon(name, days),
      };
    }

    return (
      lines: [
        for (final a in alerts.take(5)) line(a),
        if (alerts.length > 5) l.notifMore(alerts.length - 5),
      ],
    );
  }

  NotificationDetails _details(List<String> lines) => NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      styleInformation: BigTextStyleInformation(lines.join('\n')),
    ),
  );

  /// يعيد جدولة الإشعارين بعد كل تغيير بيانات أو فتح للتطبيق:
  ///
  /// - **«جديد»:** مرة واحدة صباح 9:00 التالي، بأسماء ما لم يُبلَّغ عنه بعد.
  ///   لا جديد ← لا إشعار (كان يتكرّر النص نفسه يومياً).
  /// - **أسبوعي:** السبت 9:00 بملخّص كامل يشمل «القريبة».
  ///
  /// `zonedSchedule` لا يشغّل شيفرة عند الظهور، فما جُدول يُسجَّل «مخطَّطاً»
  /// ويصير «مُبلَّغاً عنه» عند أول فتح بعد موعده.
  Future<void> scheduleDailyDigest(List<Medicine> all) async {
    await init();
    if (!_tzInitialized) {
      debugPrint('لا منطقة زمنية مهيّأة — تُخُطّي الجدولة');
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      var notified = (prefs.getStringList(_kNotified) ?? const []).toSet();
      final plannedAt = prefs.getInt(_kPlannedAt);
      if (plannedAt != null &&
          DateTime.now().millisecondsSinceEpoch >= plannedAt) {
        notified.addAll(prefs.getStringList(_kPlanned) ?? const []);
        await prefs.remove(_kPlanned);
        await prefs.remove(_kPlannedAt);
      }

      final slot = _nextInstanceOf(_dailyHour, _dailyMinute);
      final dismissed = PharmacyPrefs.instance.alertDismissals;
      final plan = planNew(
        all,
        slot: slot,
        notified: notified,
        dismissed: dismissed,
      );
      notified = plan.notified;
      await prefs.setStringList(_kNotified, notified.toList());

      await _plugin.cancel(id: _dailyId);
      if (plan.fresh.isNotEmpty) {
        final lines = buildAlertsContent(plan.fresh).lines;
        await scheduleWithFallback(
          (mode) => _plugin.zonedSchedule(
            id: _dailyId,
            title: L10n.current.notifNewTitle(plan.fresh.length),
            body: lines.first,
            scheduledDate: slot,
            notificationDetails: _details(lines),
            payload: alertsPayload,
            androidScheduleMode: mode,
          ),
        );
        await prefs.setStringList(_kPlanned, [
          for (final a in plan.fresh) a.key,
        ]);
        await prefs.setInt(_kPlannedAt, slot.millisecondsSinceEpoch);
      }

      await _scheduleWeekly(all, dismissed);
    } catch (e) {
      debugPrint('تعذّرت جدولة الإشعارات: $e');
    }
  }

  Future<void> _scheduleWeekly(
    List<Medicine> all,
    Set<String> dismissed,
  ) async {
    await _plugin.cancel(id: _weeklyId);
    var slot = _nextInstanceOf(_dailyHour, _dailyMinute);
    while (slot.weekday != DateTime.saturday) {
      slot = slot.add(const Duration(days: 1));
    }
    final alerts = computeAlerts(all, now: slot, dismissed: dismissed);
    final summary = buildSummary(all);
    if (alerts.isEmpty || summary == null) return;
    final lines = [summary, ...buildAlertsContent(alerts).lines];
    await scheduleWithFallback(
      (mode) => _plugin.zonedSchedule(
        id: _weeklyId,
        title: L10n.current.notifWeeklyTitle,
        body: summary,
        scheduledDate: slot,
        notificationDetails: _details(lines),
        payload: alertsPayload,
        androidScheduleMode: mode,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      ),
    );
  }

  /// الجدولة الدقيقة أولاً، ثم غير الدقيقة إن رُفضت.
  ///
  /// من رفض إذن «المنبّهات الدقيقة» (أندرويد 12+) كانت كل جدولة ترمي
  /// `exact_alarms_not_permitted` فلا يصله أي إشعار يومي إطلاقاً — إشعار
  /// متأخر بضع دقائق أفضل بكثير من لا إشعار.
  @visibleForTesting
  static Future<void> scheduleWithFallback(
    Future<void> Function(AndroidScheduleMode mode) schedule,
  ) async {
    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (e) {
      debugPrint('الجدولة الدقيقة مرفوضة — جدولة غير دقيقة: $e');
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  /// يُلغي الإشعار المجدول — يُستدعى عند تعطيل مفتاح التنبيهات في الإعدادات.
  Future<void> cancelDailyDigest() async {
    try {
      await _plugin.cancel(id: _dailyId);
      await _plugin.cancel(id: _weeklyId);
    } catch (e) {
      debugPrint('تعذّر إلغاء الإشعار اليومي: $e');
    }
  }

  /// يحسب موعد التشغيل التالي: إن مضت الساعة اليوم، جدولها للغد.
  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
