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

enum StockUnit { gram, kilogram, piece, roll, box, pack }

extension StockUnitX on StockUnit {
  String get abbreviation {
    switch (this) {
      case StockUnit.gram:
        return 'g';
      case StockUnit.kilogram:
        return 'kg';
      case StockUnit.piece:
        return 'adet';
      case StockUnit.roll:
        return 'rulo';
      case StockUnit.box:
        return 'koli';
      case StockUnit.pack:
        return 'paket';
    }
  }

  String get displayName {
    switch (this) {
      case StockUnit.gram:
        return 'Gram (g)';
      case StockUnit.kilogram:
        return 'Kilogram (kg)';
      case StockUnit.piece:
        return 'Adet';
      case StockUnit.roll:
        return 'Rulo';
      case StockUnit.box:
        return 'Koli';
      case StockUnit.pack:
        return 'Paket';
    }
  }

  /// Tartılan (ondalıklı) birimler: gram, kilogram.
  bool get isWeighed =>
      this == StockUnit.gram || this == StockUnit.kilogram;

  /// Sayılan (tam sayı) birimler: adet, rulo, koli, paket.
  bool get isCountable => !isWeighed;

  /// Miktarı birime uygun biçimlendirir.
  String format(double amount) {
    switch (this) {
      case StockUnit.gram:
        if (amount >= 1000) {
          return '${(amount / 1000).toStringAsFixed(2)} kg (${amount.toStringAsFixed(0)} g)';
        }
        return '${amount.toStringAsFixed(0)} g';
      case StockUnit.kilogram:
        return '${_trim(amount)} kg';
      case StockUnit.piece:
      case StockUnit.roll:
      case StockUnit.box:
      case StockUnit.pack:
        return '${amount.toStringAsFixed(0)} $abbreviation';
    }
  }

  /// Slider/adım için taban büyüklük (aynı birimden).
  double get baseStep {
    switch (this) {
      case StockUnit.gram:
        return 100;
      case StockUnit.kilogram:
        return 0.5;
      case StockUnit.piece:
      case StockUnit.roll:
      case StockUnit.box:
      case StockUnit.pack:
        return 1;
    }
  }

  String get key => name;

  static String _trim(double v) =>
      v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

  static StockUnit fromKey(String key) {
    switch (key) {
      case 'gram':
        return StockUnit.gram;
      case 'kilogram':
      case 'kg':
        return StockUnit.kilogram;
      case 'piece':
      case 'adet':
        return StockUnit.piece;
      case 'roll':
      case 'rulo':
        return StockUnit.roll;
      case 'box':
      case 'koli':
        return StockUnit.box;
      case 'pack':
      case 'paket':
        return StockUnit.pack;
      default:
        return StockUnit.gram;
    }
  }
}
