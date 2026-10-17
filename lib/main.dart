import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'services/app_settings.dart';
import 'services/image_store.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';
import 'state/medicine_store.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // غياب .env يعطّل قراءة الفواتير بالذكاء الاصطناعي فقط — لا يجوز أن يمنع
  // إقلاع التطبيق. بقية الميزات (المخزون، الباركود، المزامنة) تعمل بلاه.
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('تعذّر تحميل .env — قراءة الفواتير معطّلة: $e');
  }
  await ImageStore.init();
  await AppSettings.instance.init();
  // تهيئة الإشعارات قبل runApp — يلتقط أيضاً حمولة الإشعار الذي فتح التطبيق
  // (إن وُجد) فتصبح جاهزة قبل بناء أول شاشة.
  await NotificationService.instance.init();
  await SyncService.instance.init();
  runApp(const PharmacyApp());
}

class PharmacyApp extends StatefulWidget {
  const PharmacyApp({super.key});

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
          child: child!,
        ),
      ),
      home: HomeScreen(store: _store),
    );
  }
}
