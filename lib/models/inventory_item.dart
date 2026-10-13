import 'package:uuid/uuid.dart';
import 'grocery_category.dart';

const _uuid = Uuid();

/// Warehouse-aware stock item.
/// Reconciliation rule: production deducts from [currentStock] only;
/// receiving shipments adds to both [currentStock] and [warehouseStock].
class InventoryItem {
  final String id;
  String name;
  GroceryCategory category;
  StockUnit unit;
  double currentStock;
  double warehouseStock;
  double minThreshold;
  double? pricePerUnit;

  InventoryItem({
    String? id,
    required this.name,
    required this.category,
    required this.unit,
    required this.currentStock,
    required this.warehouseStock,
    required this.minThreshold,
    this.pricePerUnit,
  }) : id = id ?? _uuid.v4();

  bool get isLowStock => currentStock <= minThreshold;
  bool get isOutOfStock => currentStock <= 0;

  double get stockRatio {
    if (warehouseStock <= 0) return 0;
    return (currentStock / warehouseStock).clamp(0.0, 1.0).toDouble();
  }

  String formattedStock() => formatAmount(currentStock);

  String formatAmount(double amount) {
    if (unit == StockUnit.gram) {
      if (amount >= 1000) {
        return '${(amount / 1000).toStringAsFixed(2)} kg (${amount.toStringAsFixed(0)} g)';
      }
      return '${amount.toStringAsFixed(0)} g';
    }
    return '${amount.toStringAsFixed(0)} adet';
  }

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
        id: j['id'] as String?,
        name: j['name'] as String,
        category: GroceryCategoryX.fromKey(j['category'] as String),
        unit: StockUnitX.fromKey(j['unit'] as String),
        currentStock: (j['currentStock'] as num).toDouble(),
        warehouseStock: (j['warehouseStock'] as num).toDouble(),
        minThreshold: (j['minThreshold'] as num).toDouble(),
        pricePerUnit: (j['pricePerUnit'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.key,
        'unit': unit.key,
        'currentStock': currentStock,
        'warehouseStock': warehouseStock,
        'minThreshold': minThreshold,
        'pricePerUnit': pricePerUnit,
      };
}
