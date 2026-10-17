import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// هوية الجهاز في السحابة — مصادقة مجهولة بلا أي تسجيل دخول يراه المستخدم.
///
/// الغرض ليس معرفة *من* المستخدم، بل إعطاء بياناته **مالكاً** تستطيع قواعد
/// Firestore التحقق منه. بدون ذلك تبقى المجموعة مفتوحة لأي شخص يملك مفتاح
/// الواجهة المستخرَج من ملف APK.
///
/// الحساب المجهول ثابت على الجهاز ما دام التطبيق مثبّتاً؛ إلغاء التثبيت يفقده،
/// ولهذا تبقى SQLite هي المصدر الأساسي والسحابة نسخة احتياطية.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  String? _uid;

  /// معرّف المالك الحالي، أو null إذا تعذّرت المصادقة (يعمل التطبيق محلياً).
  String? get uid => _uid;
  bool get isSignedIn => _uid != null;

  /// سبب فشل المصادقة — يُعرض في تفاصيل مؤشر المزامنة.
  String? _error;
  String? get error => _error;

  /// لا ترمي استثناءً أبداً: فشل المصادقة يعني «محلي فقط» لا انهيار التطبيق.
  Future<void> init() async {
    try {
      final auth = FirebaseAuth.instance;
      final current = auth.currentUser ?? (await auth.signInAnonymously()).user;
      _uid = current?.uid;
      _error = _uid == null ? 'تعذّر إنشاء هوية الجهاز' : null;
    } on FirebaseAuthException catch (e) {
      _uid = null;
      _error = switch (e.code) {
        // الأشيع: لم يُفعَّل مزوّد Anonymous في Console
        'operation-not-allowed' =>
          'المصادقة المجهولة غير مفعّلة في Firebase.\n'
              'الحل: Console ← Authentication ← Sign-in method ← Anonymous ← Enable.',
        'network-request-failed' => 'لا يوجد اتصال — المزامنة موقوفة مؤقتاً.',
        _ => 'تعذّرت المصادقة: ${e.code}',
      };
      debugPrint('فشل تسجيل الدخول المجهول: ${e.code}');
    } catch (e) {
      _uid = null;
      _error = 'تعذّرت المصادقة: $e';
      debugPrint('فشل تسجيل الدخول المجهول: $e');
    }
  }
}
