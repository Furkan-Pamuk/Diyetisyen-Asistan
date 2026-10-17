import 'package:uuid/uuid.dart';
import 'grocery_category.dart';

const _uuid = Uuid();

class RecipeIngredient {
  final String id;
  String itemId;
  /// Amount consumed per single serving, in the item's native unit.
  double amountPerServing;

  RecipeIngredient({
    String? id,
    required this.itemId,
    required this.amountPerServing,
  }) : id = id ?? _uuid.v4();

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) =>
      RecipeIngredient(
        id: j['id'] as String?,
        itemId: j['itemId'] as String,
        amountPerServing: (j['amountPerServing'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemId': itemId,
        'amountPerServing': amountPerServing,
      };
}

class Recipe {
  final String id;
  String name;
  String description;
  int servingsDefault;
  List<RecipeIngredient> ingredients;

  Recipe({
    String? id,
    required this.name,
    this.description = '',
    this.servingsDefault = 4,
    List<RecipeIngredient>? ingredients,
  })  : id = id ?? _uuid.v4(),
        ingredients = ingredients ?? [];

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: j['id'] as String?,
        name: j['name'] as String,
        description: (j['description'] as String?) ?? '',
        servingsDefault: (j['servingsDefault'] as num?)?.toInt() ?? 4,
        ingredients: ((j['ingredients'] as List?) ?? [])
            .map((e) => RecipeIngredient.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'servingsDefault': servingsDefault,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
      };
}

class ProductionLog {
  final String id;
  String recipeId;
  String recipeName;
  int servingsMade;
  DateTime date;
  Map<String, double> deductions;

  ProductionLog({
    String? id,
    required this.recipeId,
    required this.recipeName,
    required this.servingsMade,
    DateTime? date,
    Map<String, double>? deductions,
  })  : id = id ?? _uuid.v4(),
        date = date ?? DateTime.now(),
        deductions = deductions ?? {};

  factory ProductionLog.fromJson(Map<String, dynamic> j) => ProductionLog(
        id: j['id'] as String?,
        recipeId: j['recipeId'] as String,
        recipeName: j['recipeName'] as String,
        servingsMade: (j['servingsMade'] as num).toInt(),
        date: DateTime.parse(j['date'] as String),
        deductions: ((j['deductions'] as Map?) ?? {}).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipeId': recipeId,
        'recipeName': recipeName,
        'servingsMade': servingsMade,
        'date': date.toIso8601String(),
        'deductions': deductions,
      };
}

/// Arşivlik haftalık üretim kaydı: hangi hafta, gün gün kaç kişi,
/// toplam ne kadar malzeme harcandı. Geri dönüp bakılabilir.
class ProductionArchive {
  final String id;
  DateTime date;
  int weekIndex;
  String weekLabel;
  Map<int, int> servingsByDay; // dayIndex -> kişi sayısı
  Map<String, double> totals; // itemId -> toplam gram/adet
  Map<String, String> itemNames; // itemId -> ürün adı (silinirse de görünsün)
  Map<String, String> itemUnits; // itemId -> 'gram' | 'piece'

  ProductionArchive({
    String? id,
    DateTime? date,
    required this.weekIndex,
    required this.weekLabel,
    required this.servingsByDay,
    required this.totals,
    required this.itemNames,
    required this.itemUnits,
  })  : id = id ?? _uuid.v4(),
        date = date ?? DateTime.now();

  factory ProductionArchive.fromJson(Map<String, dynamic> j) =>
      ProductionArchive(
        id: j['id'] as String?,
        date: DateTime.tryParse(j['date'] as String? ?? '') ??
            DateTime.now(),
        weekIndex: (j['weekIndex'] as num?)?.toInt() ?? 0,
        weekLabel: (j['weekLabel'] as String?) ?? '',
        servingsByDay: ((j['servingsByDay'] as Map?) ?? {}).map(
          (k, v) => MapEntry(int.parse(k as String), (v as num).toInt()),
        ),
        totals: ((j['totals'] as Map?) ?? {}).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
        itemNames: ((j['itemNames'] as Map?) ?? {}).map(
          (k, v) => MapEntry(k as String, v as String),
        ),
        itemUnits: ((j['itemUnits'] as Map?) ?? {}).map(
          (k, v) => MapEntry(k as String, v as String),
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'weekIndex': weekIndex,
        'weekLabel': weekLabel,
        'servingsByDay':
            servingsByDay.map((k, v) => MapEntry('$k', v)),
        'totals': totals,
        'itemNames': itemNames,
        'itemUnits': itemUnits,
      };
}

class WeeklyPlanEntry {
  final String id;
  String recipeId;
  int plannedServings;

  WeeklyPlanEntry({
    String? id,
    required this.recipeId,
    required this.plannedServings,
  }) : id = id ?? _uuid.v4();

  factory WeeklyPlanEntry.fromJson(Map<String, dynamic> j) => WeeklyPlanEntry(
        id: j['id'] as String?,
        recipeId: j['recipeId'] as String,
        plannedServings: (j['plannedServings'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipeId': recipeId,
        'plannedServings': plannedServings,
      };
}

class GroceryItem {
  final String id;
  String name;
  GroceryCategory category;
  String unitKey; // 'gram' | 'piece'
  double requiredAmount;
  double currentStockAtGeneration;
  bool isPurchased;
  DateTime weekStart;

  GroceryItem({
    String? id,
    required this.name,
    required this.category,
    required this.unitKey,
    required this.requiredAmount,
    required this.currentStockAtGeneration,
    this.isPurchased = false,
    required this.weekStart,
  }) : id = id ?? _uuid.v4();

  bool get isGram => unitKey == 'gram';

  String formattedRequired() {
    if (isGram) {
      if (requiredAmount >= 1000) {
        return '${(requiredAmount / 1000).toStringAsFixed(2)} kg (${requiredAmount.toStringAsFixed(0)} g)';
      }
      return '${requiredAmount.toStringAsFixed(0)} g';
    }
    return '${requiredAmount.toStringAsFixed(0)} adet';
  }

  factory GroceryItem.fromJson(Map<String, dynamic> j) => GroceryItem(
        id: j['id'] as String?,
        name: j['name'] as String,
        category: GroceryCategoryX.fromKey(j['category'] as String),
        unitKey: j['unit'] as String,
        requiredAmount: (j['requiredAmount'] as num).toDouble(),
        currentStockAtGeneration:
            (j['currentStockAtGeneration'] as num).toDouble(),
        isPurchased: (j['isPurchased'] as bool?) ?? false,
        weekStart: DateTime.parse(j['weekStart'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.key,
        'unit': unitKey,
        'requiredAmount': requiredAmount,
        'currentStockAtGeneration': currentStockAtGeneration,
        'isPurchased': isPurchased,
        'weekStart': weekStart.toIso8601String(),
      };
}
