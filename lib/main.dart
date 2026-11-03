import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'screens/launch_flow.dart';
import 'services/app_settings.dart';
import 'services/image_store.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';
import 'state/medicine_store.dart';
import 'theme.dart';
import 'widgets/glass.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // الواجهة فوراً: شاشة الشعار تظهر والخدمات تُهيّأ خلفها
  runApp(const PharmacyApp(initialize: _initServices));
}

Future<void> _initServices() async {
  // غياب .env يعطّل قراءة الفواتير بالذكاء الاصطناعي فقط — لا يجوز أن يمنع
  // إقلاع التطبيق. بقية الميزات (المخزون، الباركود، المزامنة) تعمل بلاه.
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('تعذّر تحميل .env — قراءة الفواتير معطّلة: $e');
  }
  await ImageStore.init();
  await AppSettings.instance.init();
  // تهيئة الإشعارات قبل بناء الرئيسية — يلتقط أيضاً حمولة الإشعار الذي فتح
  // التطبيق (إن وُجد) فتصبح جاهزة قبل أول إطار لها.
  await NotificationService.instance.init();
  await SyncService.instance.init();
}

class PharmacyApp extends StatefulWidget {
  const PharmacyApp({super.key, required this.initialize});

  final Future<void> Function() initialize;

  @override
  State<PharmacyApp> createState() => _PharmacyAppState();
}

class _PharmacyAppState extends State<PharmacyApp> {
  final _store = MedicineStore();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'صيدليتي',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // تعريب مكوّنات Material نفسها — منتقي التاريخ كان يظهر بالإنجليزية
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // التطبيق عربي بالكامل — من اليمين إلى اليسار
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        // تثبيت حجم الخط ضمن حدود آمنة حتى لا تنكسر البطاقات
        // إذا كان المستخدم مفعّلاً خطاً كبيراً في إعدادات النظام
        child: MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.15,
          // خلفية «الشفق» الثابتة تحت كل الشاشات — الشاشات شفافة فوقها
          child: Stack(
            fit: StackFit.expand,
            children: [const AuroraBackground(), child!],
          ),
        ),
      ),
      home: LaunchFlow(
        initialize: widget.initialize,
        home: (_) => HomeScreen(store: _store),
      ),
    );
  }
}
