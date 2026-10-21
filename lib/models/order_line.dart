import 'package:uuid/uuid.dart';

import 'grocery_category.dart';

const _uuid = Uuid();

/// Sipariş kalemi: hangi ürün, ne kadar istendi.
/// Teslim almada gelen miktar ayrıca girilir.
class OrderLine {
  final String id;
  String? itemId; // stokta eşleşirse
  String name;
  String unitKey; // 'gram' | 'piece'
  double orderedQty;

  OrderLine({
    String? id,
    this.itemId,
    required this.name,
    required this.unitKey,
    required this.orderedQty,
  }) : id = id ?? _uuid.v4();

  bool get isGram => unitKey == 'gram';

  String formattedOrdered() =>
      StockUnitX.fromKey(unitKey).format(orderedQty);

  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
        id: j['id'] as String?,
        itemId: j['itemId'] as String?,
        name: j['name'] as String,
        unitKey: j['unit'] as String,
        orderedQty: (j['orderedQty'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemId': itemId,
        'name': name,
        'unit': unitKey,
        'orderedQty': orderedQty,
      };
}

/// Teslim alma kaydı (arşiv): hangi tedarikçiden, ne zaman,
/// hangi üründen ne kadar istendi/geldi.
class GoodsReceipt {
  final String id;
  String? orderId;
  String orderTitle;
  String supplierName;
  String? supplierId;
  DateTime receivedAt;
  List<ReceiptLine> lines;
  String note;

  GoodsReceipt({
    String? id,
    this.orderId,
    required this.orderTitle,
    required this.supplierName,
    this.supplierId,
    DateTime? receivedAt,
    required this.lines,
    this.note = '',
  })  : id = id ?? _uuid.v4(),
        receivedAt = receivedAt ?? DateTime.now();

  factory GoodsReceipt.fromJson(Map<String, dynamic> j) =>
      GoodsReceipt(
        id: j['id'] as String?,
        orderId: j['orderId'] as String?,
        orderTitle: (j['orderTitle'] as String?) ?? '',
        supplierName: (j['supplierName'] as String?) ?? '',
        supplierId: j['supplierId'] as String?,
        receivedAt:
            DateTime.tryParse(j['receivedAt'] as String? ?? '') ??
                DateTime.now(),
        lines: ((j['lines'] as List?) ?? [])
            .map((e) => ReceiptLine.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
        note: (j['note'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderId': orderId,
        'orderTitle': orderTitle,
        'supplierName': supplierName,
        'supplierId': supplierId,
        'receivedAt': receivedAt.toIso8601String(),
        'lines': lines.map((e) => e.toJson()).toList(),
        'note': note,
      };
}

class ReceiptLine {
  String name;
  String unitKey;
  double orderedQty;
  double receivedQty;
  ReceiptLine({
    required this.name,
    required this.unitKey,
    required this.orderedQty,
    required this.receivedQty,
  });

  bool get isGram => unitKey == 'gram';

  String _fmt(double v) =>
      StockUnitX.fromKey(unitKey).format(v);

  String formattedOrdered() => _fmt(orderedQty);
  String formattedReceived() => _fmt(receivedQty);

  factory ReceiptLine.fromJson(Map<String, dynamic> j) =>
      ReceiptLine(
        name: j['name'] as String,
        unitKey: j['unit'] as String,
        orderedQty: (j['orderedQty'] as num).toDouble(),
        receivedQty: (j['receivedQty'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'unit': unitKey,
        'orderedQty': orderedQty,
        'receivedQty': receivedQty,
      };
}

/// Teslim alma ekranından gelen düzenlenebilir satır.
/// Yeni ürünler için kategori de taşınır (stoklara doğru açılması için).
class ReceiptInput {
  String? itemId;
  String name;
  String unitKey;
  double orderedQty;
  double receivedQty;
  GroceryCategory? category;

  ReceiptInput({
    this.itemId,
    required this.name,
    required this.unitKey,
    required this.orderedQty,
    required this.receivedQty,
    this.category,
  });
}
