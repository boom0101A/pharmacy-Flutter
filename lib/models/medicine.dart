import '../services/pharmacy_prefs.dart';

/// نوع المادة — الأدوية والمستلزمات الطبية لهما مسارا إدخال مختلفان تماماً.
enum ItemType {
  medicine('medicine', '💊 دواء'),
  supply('supply', '🩹 مستلزم طبي');

  const ItemType(this.code, this.label);

  /// القيمة المخزّنة في قاعدة البيانات — ثابتة لا تتغير بتغير الواجهة.
  final String code;
  final String label;

  static ItemType fromCode(Object? raw) {
    final c = raw?.toString().trim();
    return ItemType.values.firstWhere(
      (t) => t.code == c,
      orElse: () => ItemType.medicine, // الافتراضي: البيانات القديمة كلها أدوية
    );
  }
}

class Medicine {
  final String id;
  final String barcode;
  final String name;
  final double price;
  final int quantity;

  /// مسار الصورة على القرص (داخل مجلد التطبيق) — وليس base64
  final String? imagePath;

  /// تاريخ انتهاء الصلاحية بالمللي ثانية — يُقرأ من رمز GS1 أو من العلبة.
  final int? expiryDate;

  /// دواء أم مستلزم طبي — يحدد في أي قسم يظهر.
  final ItemType type;

  /// الشكل الصيدلاني للدواء (قرص/شراب/كريم/قطرة...) كما يُطبع في عمود
  /// «نوع المواد» بفواتير بعض المجهّزين. يُعرض ويُكتب للأدوية فقط؛ قيم قديمة
  /// حُفظت لمستلزمات (قبل 2026-10) تبقى في السجل لكنها لا تُعرض.
  final String? category;

  /// الشركة المصنّعة أو الوكيل — للأدوية والمستلزمات.
  final String? company;

  /// أكّد المستخدم أن المادة بلا باركود فعلاً (تحضير، علبة بلا رمز) — فلا
  /// تُعدّ «ناقصة» بسبب الباركود.
  final bool noBarcode;

  /// حد تنبيه المخزون المنخفض لهذه المادة (سريعة البيع تحتاج حداً أعلى).
  /// null = الحد العام للصيدلية ([PharmacyPrefs.lowStockDefault]).
  final int? minQuantity;

  final int createdAt;
  final int updatedAt;

  const Medicine({
    required this.id,
    required this.barcode,
    required this.name,
    required this.price,
    required this.quantity,
    this.imagePath,
    this.expiryDate,
    this.type = ItemType.medicine,
    this.category,
    this.company,
    this.noBarcode = false,
    this.minQuantity,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
  bool get isOutOfStock => quantity == 0;

  /// الحد الفعلي: الخاص بالمادة إن وُجد، وإلا العام للصيدلية.
  int get lowStockThreshold =>
      minQuantity ?? PharmacyPrefs.instance.lowStockDefault;

  bool get isLowStock => quantity > 0 && quantity <= lowStockThreshold;

  /// نفدت فعلاً: كميتها صفر ولها سعر. المادة بلا سعر وبلا كمية ليست «نافدة»
  /// بل تسجيل لم يكتمل (مُسحت ولم تُسعَّر).
  bool get isSoldOut => quantity == 0 && price > 0;

  /// بيانات ناقصة: بلا سعر، أو بلا باركود ما لم يُؤكَّد أنها بلا باركود.
  bool get isIncomplete => price <= 0 || (barcode.trim().isEmpty && !noBarcode);
  double get totalValue => price * quantity;

  DateTime? get expiry => expiryDate == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(expiryDate!);

  bool get isExpired {
    final e = expiry;
    return e != null && e.isBefore(DateTime.now());
  }

  /// «قريبة»: خلال 90 يوماً (كانت 180 — شيء ما كان يقترب دائماً فيتكرّر
  /// التنبيه نفسه كل يوم بلا قيمة).
  static const soonDays = 90;

  /// «عاجلة»: خلال 30 يوماً.
  static const urgentDays = 30;

  /// الأيام المتبقية حتى الانتهاء بالنسبة إلى [now] (سالبة للمنتهية).
  /// بالأيام **التقويمية** كمركز التنبيهات وصفحة المادة — المدة المنقضية
  /// كانت تعدّ «90 يوماً و13 ساعة» 90 فتظهر المادة «قريبة» في الفلتر وحده.
  int? daysToExpiry([DateTime? now]) {
    final e = expiry;
    if (e == null) return null;
    final n = now ?? DateTime.now();
    return DateTime(
      e.year,
      e.month,
      e.day,
    ).difference(DateTime(n.year, n.month, n.day)).inDays;
  }

  bool get isExpiringSoon {
    final days = daysToExpiry();
    return !isExpired && days != null && days >= 0 && days <= soonDays;
  }

  bool get isExpiringUrgent {
    final days = daysToExpiry();
    return !isExpired && days != null && days >= 0 && days <= urgentDays;
  }

  Medicine copyWith({
    String? barcode,
    String? name,
    double? price,
    int? quantity,
    String? imagePath,
    bool clearImage = false,
    int? expiryDate,
    bool clearExpiry = false,
    ItemType? type,
    String? category,
    bool clearCategory = false,
    String? company,
    bool clearCompany = false,
    bool? noBarcode,
    int? minQuantity,
    bool clearMinQuantity = false,
    int? updatedAt,
  }) {
    return Medicine(
      id: id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      expiryDate: clearExpiry ? null : (expiryDate ?? this.expiryDate),
      type: type ?? this.type,
      category: clearCategory ? null : (category ?? this.category),
      company: clearCompany ? null : (company ?? this.company),
      noBarcode: noBarcode ?? this.noBarcode,
      minQuantity: clearMinQuantity ? null : (minQuantity ?? this.minQuantity),
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'barcode': barcode,
    'name': name,
    'price': price,
    'quantity': quantity,
    'imagePath': imagePath,
    'expiryDate': expiryDate,
    'itemType': type.code,
    'category': category,
    'company': company,
    'noBarcode': noBarcode ? 1 : 0,
    'minQuantity': minQuantity,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  /// متسامح مع البيانات القديمة القادمة من نسخة الويب، حيث كانت الأرقام
  /// تُحفظ أحياناً كنصوص والتواريخ كنص ISO أو Timestamp.
  factory Medicine.fromMap(Map<String, Object?> map) => Medicine(
    id: map['id'].toString(),
    // القيد الفريد الجزئي في القاعدة يقارن نصياً حرفياً — "   " لا يساوي
    // "" فيُعامَل كباركود صالح، فيصطدم استيراد ثانٍ به بصمت عبر الاستبدال.
    // التقليم هنا يطبّع كل مصدر بيانات خارجي (نسخة احتياطية، سحابة، ويب).
    barcode: _asText(map['barcode']).trim(),
    name: _asText(map['name']),
    price: _asDouble(map['price']),
    quantity: _asDouble(map['quantity']).round(),
    imagePath: map['imagePath'] as String?,
    expiryDate: map['expiryDate'] == null ? null : _asMillis(map['expiryDate']),
    type: ItemType.fromCode(map['itemType']),
    category: map['category'] as String?,
    company: map['company'] as String?,
    noBarcode: _asBool(map['noBarcode']),
    minQuantity: map['minQuantity'] == null
        ? null
        : _asDouble(map['minQuantity']).round(),
    createdAt: _asMillis(map['createdAt']),
    updatedAt: _asMillis(map['updatedAt']),
  );

  /// 1/0 من sqflite، وقيم السحابة أياً كانت (null للسجلات الأقدم).
  static bool _asBool(Object? v) => switch (v) {
    bool b => b,
    num n => n != 0,
    String s => s == '1' || s.toLowerCase() == 'true',
    _ => false,
  };

  static String _asText(Object? v) => v == null ? '' : v.toString();

  static double _asDouble(Object? v) => switch (v) {
    num n => n.toDouble(),
    String s => double.tryParse(s.trim()) ?? 0,
    _ => 0,
  };

  /// يقبل: رقم بالمللي ثانية، نص رقمي، نص ISO، أو Timestamp من Firestore.
  static int _asMillis(Object? v) {
    switch (v) {
      case num n:
        return n.toInt();
      case String s:
        final asNum = int.tryParse(s.trim());
        if (asNum != null) return asNum;
        return DateTime.tryParse(s)?.millisecondsSinceEpoch ?? 0;
      case null:
        return 0;
      default:
        // Timestamp من Firestore يعرض millisecondsSinceEpoch عبر توافق البط
        try {
          return (v as dynamic).millisecondsSinceEpoch as int;
        } catch (_) {
          return 0;
        }
    }
  }
}
