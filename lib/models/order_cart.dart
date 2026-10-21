import 'package:uuid/uuid.dart';

import 'grocery_category.dart';

const _uuid = Uuid();

/// Sipariş sepeti satırı: stok uyarısından veya üretim projeksiyonundan
/// eklenen, henüz siparişe dönüşmemiş ürün.
class OrderCartItem {
  final String id;
  String itemId;
  String name;
  String unitKey; // 'gram' | 'piece'
  double quantity;
  String? supplierId;
  DateTime addedAt;

  OrderCartItem({
    String? id,
    required this.itemId,
    required this.name,
    required this.unitKey,
    required this.quantity,
    this.supplierId,
    DateTime? addedAt,
  })  : id = id ?? _uuid.v4(),
        addedAt = addedAt ?? DateTime.now();

  bool get isGram => unitKey == 'gram';

  String formattedQty() =>
      StockUnitX.fromKey(unitKey).format(quantity);

  factory OrderCartItem.fromJson(Map<String, dynamic> j) =>
      OrderCartItem(
        id: j['id'] as String?,
        itemId: j['itemId'] as String,
        name: j['name'] as String,
        unitKey: j['unit'] as String,
        quantity: (j['quantity'] as num).toDouble(),
        supplierId: j['supplierId'] as String?,
        addedAt: DateTime.tryParse(j['addedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemId': itemId,
        'name': name,
        'unit': unitKey,
        'quantity': quantity,
        'supplierId': supplierId,
        'addedAt': addedAt.toIso8601String(),
      };
}
