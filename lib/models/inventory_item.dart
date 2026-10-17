import 'package:uuid/uuid.dart';
import 'grocery_category.dart';

const _uuid = Uuid();

/// Warehouse-aware stock item.
/// Reconciliation rule: production deducts from [currentStock] only;
/// receiving shipments adds to both [currentStock] and [warehouseStock].
///
/// Two-level alerting:
/// - [warnThreshold] (sarı "Azalan stok"): stock at/below this warns.
/// - [minThreshold] (kırmızı "Kritik stok"): stock at/below this is critical.
class InventoryItem {
  final String id;
  String name;
  GroceryCategory category;
  StockUnit unit;
  double currentStock;
  double warehouseStock;
  double minThreshold;
  double warnThreshold;
  double? pricePerUnit;

  InventoryItem({
    String? id,
    required this.name,
    required this.category,
    required this.unit,
    required this.currentStock,
    required this.warehouseStock,
    required this.minThreshold,
    double? warnThreshold,
    this.pricePerUnit,
  })  : warnThreshold = warnThreshold ?? minThreshold * 2,
        id = id ?? _uuid.v4() {
    // Uyarı eşiği kritik eşikten küçük olamaz.
    if (warnThreshold == null && minThreshold > 0) {
      this.warnThreshold = minThreshold * 2;
    }
    if (this.warnThreshold < minThreshold) {
      this.warnThreshold = minThreshold;
    }
  }

  bool get isCritical => currentStock <= minThreshold;
  bool get isWarning => currentStock <= warnThreshold;
  bool get isLowStock => isWarning;
  bool get isOutOfStock => currentStock <= 0;

  /// 0 = kritik, 1 = uyarı, 2 = normal
  int get alertLevel {
    if (isCritical) return 0;
    if (isWarning) return 1;
    return 2;
  }

  String alertMessage() {
    if (isOutOfStock) return '$name tükendi!';
    if (isCritical) return '$name kritik stok!';
    if (isWarning) return '$name azalan stok!';
    return '';
  }

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

  factory InventoryItem.fromJson(Map<String, dynamic> j) {
    final min = (j['minThreshold'] as num).toDouble();
    final warnRaw = j['warnThreshold'] as num?;
    return InventoryItem(
      id: j['id'] as String?,
      name: j['name'] as String,
      category: GroceryCategoryX.fromKey(j['category'] as String),
      unit: StockUnitX.fromKey(j['unit'] as String),
      currentStock: (j['currentStock'] as num).toDouble(),
      warehouseStock: (j['warehouseStock'] as num).toDouble(),
      minThreshold: min,
      warnThreshold: warnRaw?.toDouble() ?? min * 2,
      pricePerUnit: (j['pricePerUnit'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.key,
        'unit': unit.key,
        'currentStock': currentStock,
        'warehouseStock': warehouseStock,
        'minThreshold': minThreshold,
        'warnThreshold': warnThreshold,
        'pricePerUnit': pricePerUnit,
      };
}
