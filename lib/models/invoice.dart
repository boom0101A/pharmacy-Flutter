import 'dart:convert';

/// سطر من فاتورة محفوظة — نسخة لما حُفظ لحظتها، لا رابط حي بالمخزون (الكمية
/// والسعر في المخزون يتغيّران بعدها بالبيع والتعديل).
class InvoiceRecordLine {
  const InvoiceRecordLine({
    required this.name,
    required this.quantity,
    required this.price,
    this.medicineId,
    this.merged = false,
    this.packSize,
    this.pricePerPack = true,
  });

  final String name;
  final int quantity;

  /// سعر شراء الوحدة.
  final double price;

  /// المادة في المخزون التي ذهب إليها السطر.
  final String? medicineId;

  /// أُضيف لمادة موجودة لا مادة جديدة.
  final bool merged;

  /// السطر بالكرتون: [quantity] كراتين، وفي كل كرتون [packSize] علبة.
  final int? packSize;

  /// [price] سعر الكرتون (لا العلبة) — حين [packSize] غير null.
  final bool pricePerPack;

  /// مجموع السطر كما في الورقة.
  double get total => packSize == null || pricePerPack
      ? price * quantity
      : price * quantity * packSize!;

  /// العلب التي دخلت المخزون.
  int get unitsAdded => packSize == null ? quantity : quantity * packSize!;

  /// سعر شراء العلبة الواحدة.
  double get unitPrice =>
      packSize != null && pricePerPack ? price / packSize! : price;

  Map<String, Object?> toMap() => {
    'name': name,
    'quantity': quantity,
    'price': price,
    'medicineId': medicineId,
    'merged': merged,
    if (packSize != null) 'packSize': packSize,
    if (packSize != null) 'pricePerPack': pricePerPack,
  };

  factory InvoiceRecordLine.fromMap(Map<String, Object?> m) =>
      InvoiceRecordLine(
        name: (m['name'] ?? '').toString(),
        quantity: (m['quantity'] as num?)?.toInt() ?? 0,
        price: (m['price'] as num?)?.toDouble() ?? 0,
        medicineId: m['medicineId'] as String?,
        merged: m['merged'] == true || m['merged'] == 1,
        packSize: (m['packSize'] as num?)?.toInt(),
        pricePerPack: m['pricePerPack'] != false && m['pricePerPack'] != 0,
      );
}

/// فاتورة مجهّز محفوظة: الرأس + نسخة الأسطر + صورها.
///
/// الصور **محلية** على الهاتف الذي صوّرها (رفعها يحتاج Firebase Storage
/// المدفوع) — لذلك لا تُرفع أسماؤها للسحابة، والفاتورة النازلة من هاتف آخر
/// بلا صور هنا.
class Invoice {
  const Invoice({
    required this.id,
    this.supplier,
    this.number,
    this.dateMs,
    this.dateText,
    this.total,
    this.lines = const [],
    this.imageFiles = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? supplier;
  final String? number;

  /// التاريخ إن أمكن تحويله، و[dateText] كما طُبع دائماً.
  final int? dateMs;
  final String? dateText;

  /// المجموع المطبوع في الفاتورة.
  final double? total;

  final List<InvoiceRecordLine> lines;

  /// أسماء ملفات الصفحات في مجلد صور الفواتير (محلية).
  final List<String> imageFiles;

  final int createdAt;
  final int updatedAt;

  /// مجموع الأسطر كما حُفظت — يُقارن بالمجموع المطبوع.
  double get linesTotal => lines.fold(0, (s, l) => s + l.total);

  int get itemsCount => lines.length;

  /// التاريخ المعروض: تاريخ الفاتورة إن عُرف، وإلا يوم حفظها.
  int get sortDate => dateMs ?? createdAt;

  Invoice copyWith({List<String>? imageFiles, int? updatedAt}) => Invoice(
    id: id,
    supplier: supplier,
    number: number,
    dateMs: dateMs,
    dateText: dateText,
    total: total,
    lines: lines,
    imageFiles: imageFiles ?? this.imageFiles,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// للقاعدة المحلية والنسخة الاحتياطية — الأسطر والصور كنص JSON.
  Map<String, Object?> toMap() => {
    'id': id,
    'supplier': supplier,
    'number': number,
    'dateMs': dateMs,
    'dateText': dateText,
    'total': total,
    'lines': jsonEncode([for (final l in lines) l.toMap()]),
    'imageFiles': jsonEncode(imageFiles),
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  /// للسحابة: الأسطر قائمة حقيقية، وبلا أسماء الصور (محلية لكل هاتف).
  Map<String, Object?> toCloud() => {
    'id': id,
    'supplier': supplier,
    'number': number,
    'dateMs': dateMs,
    'dateText': dateText,
    'total': total,
    'lines': [for (final l in lines) l.toMap()],
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  /// يقبل الصيغتين: JSON نصي (محلي) أو قائمة (سحابة).
  factory Invoice.fromMap(Map<String, Object?> m) {
    List<Object?> list(Object? v) => switch (v) {
      String s when s.isNotEmpty => (jsonDecode(s) as List).cast<Object?>(),
      List l => l.cast<Object?>(),
      _ => const [],
    };
    return Invoice(
      id: m['id'].toString(),
      supplier: m['supplier'] as String?,
      number: m['number'] as String?,
      dateMs: (m['dateMs'] as num?)?.toInt(),
      dateText: m['dateText'] as String?,
      total: (m['total'] as num?)?.toDouble(),
      lines: [
        for (final l in list(m['lines']))
          if (l is Map) InvoiceRecordLine.fromMap(l.cast<String, Object?>()),
      ],
      imageFiles: [
        for (final f in list(m['imageFiles']))
          if (f is String) f,
      ],
      createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}
