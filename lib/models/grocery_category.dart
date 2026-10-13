import 'package:flutter/material.dart';

/// The three fixed procurement groups.
enum GroceryCategory { freshProduce, dryGoods, meatDairy }

extension GroceryCategoryX on GroceryCategory {
  String get shortName {
    switch (this) {
      case GroceryCategory.freshProduce:
        return 'Hal';
      case GroceryCategory.dryGoods:
        return 'Kuru Gıda';
      case GroceryCategory.meatDairy:
        return 'Et Süt';
    }
  }

  String get displayName {
    switch (this) {
      case GroceryCategory.freshProduce:
        return 'Fresh Produce (Hal)';
      case GroceryCategory.dryGoods:
        return 'Dry Goods (Kuru Gıda)';
      case GroceryCategory.meatDairy:
        return 'Meat & Dairy (Et Süt)';
    }
  }

  IconData get icon {
    switch (this) {
      case GroceryCategory.freshProduce:
        return Icons.eco;
      case GroceryCategory.dryGoods:
        return Icons.inventory_2;
      case GroceryCategory.meatDairy:
        return Icons.shopping_cart;
    }
  }

  Color get tint {
    switch (this) {
      case GroceryCategory.freshProduce:
        return Colors.green;
      case GroceryCategory.dryGoods:
        return Colors.orange;
      case GroceryCategory.meatDairy:
        return Colors.red;
    }
  }

  String get key => name;

  static GroceryCategory fromKey(String key) {
    return GroceryCategory.values.firstWhere(
      (e) => e.name == key,
      orElse: () => GroceryCategory.freshProduce,
    );
  }
}

enum StockUnit { gram, piece }

extension StockUnitX on StockUnit {
  String get abbreviation => this == StockUnit.gram ? 'g' : 'adet';
  String get key => name;
  static StockUnit fromKey(String key) =>
      key == 'piece' ? StockUnit.piece : StockUnit.gram;
}
