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
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
  bool get isOutOfStock => quantity == 0;
  bool get isLowStock => quantity > 0 && quantity <= 5;
  double get totalValue => price * quantity;

  DateTime? get expiry => expiryDate == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(expiryDate!);

  bool get isExpired {
    final e = expiry;
    return e != null && e.isBefore(DateTime.now());
  }

  /// تنتهي صلاحيته خلال ستة أشهر.
  bool get isExpiringSoon {
    final e = expiry;
    if (e == null) return false;
    final days = e.difference(DateTime.now()).inDays;
    return days >= 0 && days <= 180;
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
    createdAt: _asMillis(map['createdAt']),
    updatedAt: _asMillis(map['updatedAt']),
  );

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
