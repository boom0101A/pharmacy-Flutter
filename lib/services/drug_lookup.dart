import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../db/medicine_db.dart';
import 'barcode_registry.dart';
import 'gs1_parser.dart';
import 'image_store.dart';

enum LookupSource { local, registry, openFoodFacts, openFda }

class DrugInfo {
  final LookupSource source;
  final String name;

  /// اسم ملف الصورة بعد حفظها محلياً (إن وُجدت صورة).
  final String? imageFileName;
  final double? price;
  final int? quantity;

  /// عدد الصيدليات التي أكّدت هذا الاسم (للقاموس المشترك فقط).
  final int? confirmations;

  const DrugInfo({
    required this.source,
    required this.name,
    this.imageFileName,
    this.price,
    this.quantity,
    this.confirmations,
  });

  String get sourceLabel => switch (source) {
    LookupSource.local => 'قاعدتك المحلية',
    LookupSource.registry => 'قاموس الصيدليات المشترك',
    LookupSource.openFoodFacts => 'Open Food Facts',
    LookupSource.openFda => 'FDA',
  };

  /// أولوية الثقة عند تعدد المصادر المستجيبة — الأصغر أوثق.
  int get trustRank => switch (source) {
    LookupSource.local => 0,
    LookupSource.registry => 1,
    LookupSource.openFda => 2,
    LookupSource.openFoodFacts => 3,
  };
}

/// البحث عن بيانات الدواء بالباركود.
///
/// الاستراتيجية:
///   1. المصادر الفورية (المحلي ثم القاموس المشترك) بالترتيب — أقل من ثانية.
///   2. ذاكرة الفشل: باركود بُحث عنه مؤخراً فلم يوجد ⇒ توقف فوري.
///   3. المصادر الخارجية **بالتوازي** مع نافذة انتظار قصيرة، والأوثق يفوز.
class DrugLookup {
  DrugLookup._();

  static const _httpTimeout = Duration(seconds: 6);

  /// نافذة جمع الردود من المصادر الخارجية قبل اختيار الأوثق.
  static const _graceWindow = Duration(milliseconds: 1500);

  static Future<DrugInfo?> byBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;

    final variants = Gs1Parser.lookupVariants(code);
    final db = MedicineDb.instance;

    // ---- 1) القاعدة المحلية: الأدق لأنها بياناتك أنت ----
    final local = await db.findByAnyBarcode(variants);
    if (local != null) {
      return DrugInfo(
        source: LookupSource.local,
        name: local.name,
        imageFileName: local.imagePath,
        price: local.price,
        quantity: local.quantity,
      );
    }

    // ---- 2) القاموس المشترك: تغطية السوق المحلي ----
    for (final variant in variants) {
      final entry = await BarcodeRegistry.lookup(variant);
      if (entry != null) {
        await db.clearMiss(variants);
        return DrugInfo(
          source: LookupSource.registry,
          name: entry.name,
          imageFileName: entry.imageFileName,
          confirmations: entry.confirmations,
        );
      }
    }

    // ---- 3) بحثنا عنه مؤخراً ولم نجده ⇒ لا نضيّع وقت المستخدم ----
    if (await db.isRecentMiss(code)) {
      debugPrint('تخطّي البحث الخارجي: $code مسجّل كغير معروف');
      return null;
    }

    // ---- 4) بلا إنترنت ⇒ لا فائدة من انتظار المهل ----
    if (!await _hasNetwork()) {
      debugPrint('لا يوجد اتصال — تخطّي المصادر الخارجية');
      return null; // لا يُسجَّل كفشل بحث: نحن لم نبحث أصلاً
    }

    // ---- 5) المصادر الخارجية بالتوازي ----
    final result = await _queryExternalInParallel(variants);

    if (result == null) {
      await db.recordMiss(code);
    } else {
      await db.clearMiss(variants);
    }
    return result;
  }

  /// يطلق كل المصادر الخارجية معاً ويعيد الأوثق ضمن نافذة قصيرة.
  static Future<DrugInfo?> _queryExternalInParallel(
    List<String> variants,
  ) async {
    // نستعلم بالصيغة القياسية (EAN-13 بلا أصفار بادئة) لأنها الأشيع خارجياً
    final code = _preferredExternalForm(variants);

    final completer = Completer<DrugInfo?>();
    final results = <DrugInfo>[];
    var pending = 2;

    void onResult(DrugInfo? info) {
      if (info != null && info.name.trim().isNotEmpty) results.add(info);
      pending--;
      // كل المصادر ردّت ⇒ لا داعي لانتظار بقية النافذة
      if (pending == 0 && !completer.isCompleted) {
        completer.complete(_best(results));
      }
    }

    // لا نستخدم await هنا عمداً — الهدف تشغيلها في وقت واحد
    unawaited(
      _openFoodFacts(code).then(onResult).catchError((_) => onResult(null)),
    );
    unawaited(_openFda(code).then(onResult).catchError((_) => onResult(null)));

    // النافذة تضمن ألا ننتظر المصدر البطيء إن كان لدينا رد مقبول
    Timer(_graceWindow, () {
      if (!completer.isCompleted) completer.complete(_best(results));
    });

    // حد أقصى مطلق حتى لو تعطّل كل شيء
    return completer.future.timeout(
      _httpTimeout + const Duration(seconds: 1),
      onTimeout: () => _best(results),
    );
  }

  static DrugInfo? _best(List<DrugInfo> results) {
    if (results.isEmpty) return null;
    results.sort((a, b) => a.trustRank.compareTo(b.trustRank));
    return results.first;
  }

  /// الصيغة الأنسب للاستعلام الخارجي: بلا أصفار بادئة إن كانت 13 خانة.
  static String _preferredExternalForm(List<String> variants) {
    for (final v in variants) {
      if (v.length == 13) return v;
    }
    return variants.first;
  }

  static Future<bool> _hasNetwork() async {
    try {
      final status = await Connectivity().checkConnectivity().timeout(
        const Duration(seconds: 2),
      );
      return !status.contains(ConnectivityResult.none) && status.isNotEmpty;
    } catch (_) {
      // تعذّر الفحص ⇒ نفترض وجود اتصال ولا نمنع البحث
      return true;
    }
  }

  // -----------------------------------------------------------------
  //  المصادر الخارجية
  // -----------------------------------------------------------------

  static Future<DrugInfo?> _openFoodFacts(String code) async {
    try {
      final uri = Uri.https(
        'world.openfoodfacts.org',
        '/api/v0/product/${Uri.encodeComponent(code)}.json',
      );
      final res = await http.get(uri).timeout(_httpTimeout);
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 1) return null;
      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      final name =
          (product['product_name_ar'] ??
                  product['product_name'] ??
                  product['generic_name'] ??
                  '')
              .toString()
              .trim();
      final imageUrl =
          (product['image_front_url'] ?? product['image_url'] ?? '')
              .toString()
              .trim();

      if (name.isEmpty) return null;

      return DrugInfo(
        source: LookupSource.openFoodFacts,
        name: name,
        imageFileName: await _downloadImage(imageUrl),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<DrugInfo?> _openFda(String code) async {
    try {
      // الباركود قد يأتي من إدخال يدوي حر — نرمّزه بدل حقنه في الرابط كما هو
      final uri = Uri.https('api.fda.gov', '/drug/ndc.json', {
        'search': 'package_ndc:"$code"',
        'limit': '1',
      });
      final res = await http.get(uri).timeout(_httpTimeout);
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final results = data['results'] as List?;
      if (results == null || results.isEmpty) return null;

      final product = results.first as Map<String, dynamic>;
      final name = (product['brand_name'] ?? product['generic_name'] ?? '')
          .toString()
          .trim();
      if (name.isEmpty) return null;

      return DrugInfo(source: LookupSource.openFda, name: name);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _downloadImage(String url) async {
    if (url.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(url)).timeout(_httpTimeout);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      final ext = url.toLowerCase().endsWith('.png') ? '.png' : '.jpg';
      return ImageStore.saveBytes(res.bodyBytes, ext: ext);
    } catch (_) {
      return null;
    }
  }
}
