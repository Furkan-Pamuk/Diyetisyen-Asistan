import 'package:flutter_test/flutter_test.dart';

import 'package:dietitian_flutter/models/grocery_category.dart';
import 'package:dietitian_flutter/models/inventory_item.dart';
import 'package:dietitian_flutter/models/supplier_order.dart';

void main() {
  test('overdue order needs attention', () {
    final order = SupplierOrder(
      title: 'test',
      orderDate: DateTime.now().subtract(const Duration(days: 1)),
      pickupDate: DateTime.now().add(const Duration(days: 5)),
    );
    expect(order.orderAlert, AlertLevel.overdue);
    expect(order.needsAttention, isTrue);
  });

  test('order due today gives no warning', () {
    final now = DateTime.now();
    final order = SupplierOrder(
      title: 'bugünkü sipariş',
      orderDate: DateTime(now.year, now.month, now.day),
      pickupDate:
          DateTime(now.year, now.month, now.day).add(const Duration(days: 3)),
    );
    expect(order.orderCountdown, 0);
    expect(order.orderAlert, AlertLevel.ok);
    expect(order.needsAttention, isFalse);
  });

  test('orders sort newest first', () {
    final old = SupplierOrder(
      title: 'eski',
      orderDate: DateTime(2026, 1, 1),
      pickupDate: DateTime(2026, 1, 3),
      createdAt: DateTime(2026, 1, 1, 10),
    );
    final fresh = SupplierOrder(
      title: 'yeni',
      orderDate: DateTime(2026, 1, 1),
      pickupDate: DateTime(2026, 1, 3),
      createdAt: DateTime(2026, 1, 2, 10),
    );
    final list = [old, fresh]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    expect(list.first.title, 'yeni');
  });

  test('low stock detection and ratio', () {
    final item = InventoryItem(
      name: 'Pirinç',
      category: GroceryCategory.dryGoods,
      unit: StockUnit.gram,
      currentStock: 100,
      warehouseStock: 5000,
      minThreshold: 2000,
    );
    expect(item.isLowStock, isTrue);
    expect(item.stockRatio, closeTo(0.02, 0.0001));
  });

  test('deficit rounding rule', () {
    expect((1250.4).roundToDouble(), 1250.0);
    expect((2.2).ceilToDouble(), 3.0);
  });
}
