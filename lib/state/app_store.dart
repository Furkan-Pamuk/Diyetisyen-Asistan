import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/grocery_category.dart';
import '../models/inventory_item.dart';
import '../models/menu_entry.dart';
import '../models/recipe.dart';
import '../models/supplier.dart';
import '../models/supplier_order.dart';
import '../services/notification_service.dart';

const _storageKey = 'dietitian-assistant-v1';

class ProductionPreviewRow {
  final InventoryItem item;
  final double needed;
  final double remaining;
  ProductionPreviewRow(this.item, this.needed, this.remaining);
}

/// Central state: supplier orders, inventory, recipes, production, grocery.
/// Mirrors the SwiftUI AppStore logic 1:1.
class AppStore extends ChangeNotifier {
  List<SupplierOrder> supplierOrders = [];
  List<InventoryItem> inventory = [];
  List<Recipe> recipes = [];
  List<ProductionLog> productionLogs = [];
  List<GroceryItem> groceryItems = [];
  List<WeeklyPlanEntry> weeklyPlan = [];
  List<Supplier> suppliers = [];
  List<MenuEntry> weeklyMenu = [];
  DateTime weekStart = DateTime.now();

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> init() async {
    final ok = await loadFromDisk();
    if (!ok) loadSampleData();
    _loaded = true;
    notifyListeners();
  }

  // ---------- Suppliers ----------

  List<SupplierOrder> get activeOrders {
    final list = supplierOrders.where((o) => o.status.isActive).toList();
    list.sort((a, b) => a.orderDate.compareTo(b.orderDate));
    return list;
  }

  List<SupplierOrder> get attentionOrders {
    final list = supplierOrders.where((o) => o.needsAttention).toList();
    list.sort((a, b) => a.orderDate.compareTo(b.orderDate));
    return list;
  }

  Future<void> addOrder(SupplierOrder order) async {
    supplierOrders.add(order);
    await save();
    await NotificationService.instance.reschedule(order);
  }

  Future<void> updateOrder(SupplierOrder order) async {
    final i = supplierOrders.indexWhere((e) => e.id == order.id);
    if (i == -1) return;
    supplierOrders[i] = order;
    await save();
    await NotificationService.instance.reschedule(order);
  }

  Future<void> deleteOrder(String id) async {
    supplierOrders.removeWhere((e) => e.id == id);
    await save();
    await NotificationService.instance.cancel(id);
  }

  Future<void> markPickedUp(SupplierOrder order) async {
    order.status = SupplierOrderStatus.pickedUp;
    await updateOrder(order);
  }

  // ---------- Supplier directory ----------

  Supplier get defaultSupplier => suppliers.isNotEmpty
      ? suppliers.first
      : Supplier(name: 'Supplier X');

  String supplierNameOf(SupplierOrder order) {
    if (order.supplierId != null) {
      try {
        return suppliers
            .firstWhere((s) => s.id == order.supplierId)
            .name;
      } catch (_) {}
    }
    return order.supplierName;
  }

  List<SupplierOrder> ordersForSupplier(String? supplierId) {
    if (supplierId == null) return List.of(supplierOrders);
    return supplierOrders
        .where((o) =>
            o.supplierId == supplierId ||
            (o.supplierId == null && o.supplierName == supplierNameById(supplierId)))
        .toList();
  }

  String supplierNameById(String id) {
    try {
      return suppliers.firstWhere((s) => s.id == id).name;
    } catch (_) {
      return 'Supplier X';
    }
  }

  Future<void> addSupplier(Supplier s) async {
    suppliers.add(s);
    await save();
  }

  Future<void> updateSupplier(Supplier s) async {
    final i = suppliers.indexWhere((e) => e.id == s.id);
    if (i == -1) return;
    suppliers[i] = s;
    // Keep order display names in sync.
    for (final o in supplierOrders) {
      if (o.supplierId == s.id) o.supplierName = s.name;
    }
    await save();
  }

  /// Deletes a supplier; orders pointing to it fall back to the first
  /// remaining supplier. The last supplier cannot be deleted.
  Future<bool> deleteSupplier(String id) async {
    if (suppliers.length <= 1) return false;
    suppliers.removeWhere((e) => e.id == id);
    final fallback = suppliers.first;
    for (final o in supplierOrders) {
      if (o.supplierId == id) {
        o.supplierId = fallback.id;
        o.supplierName = fallback.name;
      }
    }
    await save();
    return true;
  }

  // ---------- Inventory ----------

  List<InventoryItem> get lowStockItems {
    final list = inventory.where((e) => e.isLowStock).toList();
    list.sort((a, b) => a.currentStock.compareTo(b.currentStock));
    return list;
  }

  InventoryItem? itemById(String id) {
    try {
      return inventory.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> adjustStock(String itemId, double delta) async {
    final item = itemById(itemId);
    if (item == null) return;
    item.currentStock =
        (item.currentStock + delta).clamp(0, double.infinity).toDouble();
    await save();
  }

  Future<void> setStock(String itemId, double value) async {
    final item = itemById(itemId);
    if (item == null) return;
    item.currentStock = value.clamp(0, double.infinity).toDouble();
    await save();
  }

  Future<void> receiveShipment(String itemId, double qty) async {
    final item = itemById(itemId);
    if (item == null) return;
    item.currentStock += qty;
    item.warehouseStock += qty;
    await save();
  }

  /// Manually sets warehouse capacity (depo boyutu). The fill bar
  /// (currentStock / warehouseStock) adjusts automatically.
  Future<void> setWarehouseCapacity(String itemId, double value) async {
    final item = itemById(itemId);
    if (item == null) return;
    item.warehouseStock = value.clamp(0, double.infinity).toDouble();
    await save();
  }

  Future<void> addInventoryItem(InventoryItem item) async {
    inventory.add(item);
    await save();
  }

  /// Produce recipe: reconcile warehouse inventory with usage.
  Map<String, double> produce(Recipe recipe, int servings) {
    final deductions = <String, double>{};
    for (final ing in recipe.ingredients) {
      final amount = ing.amountPerServing * servings;
      deductions[ing.itemId] = amount;
      final item = itemById(ing.itemId);
      if (item != null) {
        item.currentStock =
            (item.currentStock - amount).clamp(0, double.infinity).toDouble();
      }
    }
    productionLogs.insert(
      0,
      ProductionLog(
        recipeId: recipe.id,
        recipeName: recipe.name,
        servingsMade: servings,
        deductions: deductions,
      ),
    );
    save();
    return deductions;
  }

  /// Produce with manually edited totals (itemId -> total amount).
  /// Stock is decremented by the exact values the user confirmed.
  Map<String, double> produceCustom({
    required Recipe recipe,
    required int servings,
    required Map<String, double> totals,
  }) {
    final deductions = Map<String, double>.from(totals);
    deductions.forEach((itemId, amount) {
      final item = itemById(itemId);
      if (item != null) {
        item.currentStock =
            (item.currentStock - amount).clamp(0, double.infinity).toDouble();
      }
    });
    productionLogs.insert(
      0,
      ProductionLog(
        recipeId: recipe.id,
        recipeName: recipe.name,
        servingsMade: servings,
        deductions: deductions,
      ),
    );
    save();
    return deductions;
  }

  List<ProductionPreviewRow> previewProduction(Recipe recipe, int servings) {
    final rows = <ProductionPreviewRow>[];
    for (final ing in recipe.ingredients) {
      final item = itemById(ing.itemId);
      if (item == null) continue;
      final needed = ing.amountPerServing * servings;
      rows.add(ProductionPreviewRow(
          item, needed, (item.currentStock - needed).clamp(0, double.infinity)));
    }
    return rows;
  }

  // ---------- Weekly menu program ----------

  List<MenuEntry> menuForDay(int dayIndex) {
    final list =
        weeklyMenu.where((e) => e.dayIndex == dayIndex).toList();
    int mealRank(String meal) {
      final i = MenuEntry.meals.indexOf(meal);
      return i == -1 ? 99 : i;
    }

    list.sort((a, b) => mealRank(a.meal).compareTo(mealRank(b.meal)));
    return list;
  }

  /// Total planned servings per recipe, aggregated from the menu.
  Map<String, int> menuServingsByRecipe() {
    final map = <String, int>{};
    for (final e in weeklyMenu) {
      map[e.recipeId] = (map[e.recipeId] ?? 0) + e.servings;
    }
    return map;
  }

  Future<void> addMenuEntry(MenuEntry e) async {
    weeklyMenu.add(e);
    await save();
  }

  Future<void> updateMenuEntry(MenuEntry e) async {
    final i = weeklyMenu.indexWhere((x) => x.id == e.id);
    if (i == -1) return;
    weeklyMenu[i] = e;
    await save();
  }

  Future<void> deleteMenuEntry(String id) async {
    weeklyMenu.removeWhere((e) => e.id == id);
    await save();
  }

  // ---------- Weekly plan + grocery ----------

  Recipe? recipeById(String id) {
    try {
      return recipes.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  int servingsFor(String recipeId) {
    try {
      return weeklyPlan.firstWhere((e) => e.recipeId == recipeId).plannedServings;
    } catch (_) {
      return 0;
    }
  }

  Future<void> setServings(String recipeId, int value) async {
    final i = weeklyPlan.indexWhere((e) => e.recipeId == recipeId);
    if (i >= 0) {
      if (value <= 0) {
        weeklyPlan.removeAt(i);
      } else {
        weeklyPlan[i].plannedServings = value;
      }
    } else if (value > 0) {
      weeklyPlan.add(WeeklyPlanEntry(recipeId: recipeId, plannedServings: value));
    }
    await save();
  }

  /// Deficit = totalNeed - currentStock; only positive deficits become items.
  /// When the menu program is non-empty it is the source of truth;
  /// otherwise the legacy weekly plan is used.
  bool get groceryUsesMenu => weeklyMenu.isNotEmpty;

  Future<void> generateGroceryList() async {
    final totals = <String, double>{};
    if (groceryUsesMenu) {
      final byRecipe = menuServingsByRecipe();
      byRecipe.forEach((recipeId, servings) {
        final recipe = recipeById(recipeId);
        if (recipe == null) return;
        for (final ing in recipe.ingredients) {
          totals[ing.itemId] =
              (totals[ing.itemId] ?? 0) + ing.amountPerServing * servings;
        }
      });
    } else {
      for (final entry in weeklyPlan) {
        final recipe = recipeById(entry.recipeId);
        if (recipe == null) continue;
        for (final ing in recipe.ingredients) {
          totals[ing.itemId] =
              (totals[ing.itemId] ?? 0) + ing.amountPerServing * entry.plannedServings;
        }
      }
    }
    final result = <GroceryItem>[];
    totals.forEach((itemId, total) {
      final item = itemById(itemId);
      if (item == null) return;
      final deficit = total - item.currentStock;
      if (deficit <= 0.5) return;
      result.add(GroceryItem(
        name: item.name,
        category: item.category,
        unitKey: item.unit.key,
        requiredAmount: item.unit == StockUnit.piece
            ? deficit.ceilToDouble()
            : deficit.roundToDouble(),
        currentStockAtGeneration: item.currentStock,
        weekStart: weekStart,
      ));
    });
    result.sort((a, b) {
      final ca = GroceryCategory.values.indexOf(a.category);
      final cb = GroceryCategory.values.indexOf(b.category);
      if (ca != cb) return ca.compareTo(cb);
      return a.name.compareTo(b.name);
    });
    groceryItems = result;
    await save();
  }

  Future<void> togglePurchased(GroceryItem item) async {
    item.isPurchased = !item.isPurchased;
    await save();
  }

  Map<GroceryCategory, List<GroceryItem>> groceryGrouped() {
    return {
      for (final c in GroceryCategory.values)
        c: groceryItems.where((e) => e.category == c).toList(),
    };
  }

  double get groceryProgress {
    if (groceryItems.isEmpty) return 0;
    final done = groceryItems.where((e) => e.isPurchased).length;
    return done / groceryItems.length;
  }

  // ---------- Persistence ----------

  Future<void> save() async {
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode({
        'orders': supplierOrders.map((e) => e.toJson()).toList(),
        'inventory': inventory.map((e) => e.toJson()).toList(),
        'recipes': recipes.map((e) => e.toJson()).toList(),
        'logs': productionLogs.map((e) => e.toJson()).toList(),
        'grocery': groceryItems.map((e) => e.toJson()).toList(),
        'plan': weeklyPlan.map((e) => e.toJson()).toList(),
        'suppliers': suppliers.map((e) => e.toJson()).toList(),
        'menu': weeklyMenu.map((e) => e.toJson()).toList(),
        'weekStart': weekStart.toIso8601String(),
      });
      await prefs.setString(_storageKey, data);
    } catch (e) {
      debugPrint('Save failed: $e');
    }
  }

  Future<bool> loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return false;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      supplierOrders = ((j['orders'] as List?) ?? [])
          .map((e) => SupplierOrder.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      inventory = ((j['inventory'] as List?) ?? [])
          .map((e) => InventoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      recipes = ((j['recipes'] as List?) ?? [])
          .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      productionLogs = ((j['logs'] as List?) ?? [])
          .map((e) => ProductionLog.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      groceryItems = ((j['grocery'] as List?) ?? [])
          .map((e) => GroceryItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      weeklyPlan = ((j['plan'] as List?) ?? [])
          .map((e) => WeeklyPlanEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      // New keys with migration for data saved by older versions.
      try {
        suppliers = ((j['suppliers'] as List?) ?? [])
            .map((e) => Supplier.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        suppliers = [];
      }
      if (suppliers.isEmpty) {
        suppliers = [Supplier(name: 'Supplier X', note: 'Varsayılan tedarikçi')];
      }
      for (final o in supplierOrders) {
        if (o.supplierId == null ||
            !suppliers.any((s) => s.id == o.supplierId)) {
          try {
            final match = suppliers.firstWhere((s) => s.name == o.supplierName);
            o.supplierId = match.id;
            o.supplierName = match.name;
          } catch (_) {
            o.supplierId = suppliers.first.id;
            o.supplierName = suppliers.first.name;
          }
        }
      }
      try {
        weeklyMenu = ((j['menu'] as List?) ?? [])
            .map((e) => MenuEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        weeklyMenu = [];
      }
      weekStart = DateTime.parse(j['weekStart'] as String);
      return true;
    } catch (e) {
      debugPrint('Load failed: $e');
      return false;
    }
  }

  void loadSampleData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime day(int offset) => today.add(Duration(days: offset));

    InventoryItem mk(String name, GroceryCategory c, StockUnit u, double stock,
        double warehouse, double min) {
      return InventoryItem(
          name: name,
          category: c,
          unit: u,
          currentStock: stock,
          warehouseStock: warehouse,
          minThreshold: min);
    }

    final tomato = mk('Domates', GroceryCategory.freshProduce, StockUnit.gram, 2500, 5000, 1000);
    final cucumber = mk('Salatalık', GroceryCategory.freshProduce, StockUnit.gram, 800, 3000, 1000);
    final apple = mk('Elma', GroceryCategory.freshProduce, StockUnit.piece, 12, 30, 10);
    final lentils = mk('Kırmızı Mercimek', GroceryCategory.dryGoods, StockUnit.gram, 4000, 5000, 1500);
    final rice = mk('Pirinç', GroceryCategory.dryGoods, StockUnit.gram, 1200, 5000, 2000);
    final oats = mk('Yulaf', GroceryCategory.dryGoods, StockUnit.gram, 3000, 3000, 1000);
    final chicken = mk('Tavuk Göğsü', GroceryCategory.meatDairy, StockUnit.gram, 1500, 4000, 1500);
    final milk = mk('Süt', GroceryCategory.meatDairy, StockUnit.gram, 2000, 3000, 1000);
    final eggs = mk('Yumurta', GroceryCategory.meatDairy, StockUnit.piece, 8, 30, 12);
    inventory = [tomato, cucumber, apple, lentils, rice, oats, chicken, milk, eggs];

    RecipeIngredient ing(InventoryItem item, double amount) =>
        RecipeIngredient(itemId: item.id, amountPerServing: amount);

    final soup = Recipe(name: 'Mercimek Çorbası', description: '4 kişilik klasik',
        servingsDefault: 4,
        ingredients: [ing(lentils, 60), ing(rice, 15), ing(tomato, 50)]);
    final chickenSalad = Recipe(name: 'Tavuk Salata', description: 'Yüksek protein',
        servingsDefault: 2,
        ingredients: [ing(chicken, 150), ing(tomato, 100), ing(cucumber, 80)]);
    final oatmeal = Recipe(name: 'Yulaflı Kahvaltı', description: 'Süt + elma + yulaf',
        servingsDefault: 1,
        ingredients: [ing(oats, 50), ing(milk, 200), ing(apple, 1)]);
    final omelette = Recipe(name: 'Sebzeli Omlet', description: '2 kişilik',
        servingsDefault: 2,
        ingredients: [ing(eggs, 2), ing(tomato, 60), ing(milk, 50)]);
    recipes = [soup, chickenSalad, oatmeal, omelette];

    final supX = Supplier(name: 'Supplier X', note: 'Varsayılan tedarikçi');
    final supHal = Supplier(name: 'Hal Tedarikçisi', note: 'Sebze & meyve');
    final supEt = Supplier(name: 'Et-Süt Tedarikçisi', note: 'Et & süt ürünleri');
    suppliers = [supX, supHal, supEt];

    supplierOrders = [
      SupplierOrder(
          supplierName: supHal.name,
          supplierId: supHal.id,
          title: 'Haftalık sebze siparişi',
          orderDate: day(1),
          pickupDate: day(3),
          status: SupplierOrderStatus.scheduled,
          notes: 'Domates + salatalık'),
      SupplierOrder(
          supplierName: supEt.name,
          supplierId: supEt.id,
          title: 'Et & süt alımı',
          orderDate: day(-1),
          pickupDate: day(1),
          status: SupplierOrderStatus.ordered,
          notes: 'Tavuk + süt + yumurta'),
      SupplierOrder(
          supplierName: supX.name,
          supplierId: supX.id,
          title: 'Kuru gıda ikmali',
          orderDate: day(-9),
          pickupDate: day(-7),
          status: SupplierOrderStatus.pickedUp,
          notes: 'Mercimek + pirinç'),
    ];

    weeklyPlan = [
      WeeklyPlanEntry(recipeId: soup.id, plannedServings: 20),
      WeeklyPlanEntry(recipeId: chickenSalad.id, plannedServings: 16),
      WeeklyPlanEntry(recipeId: oatmeal.id, plannedServings: 10),
      WeeklyPlanEntry(recipeId: omelette.id, plannedServings: 8),
    ];
    // Sample menu mirrors the same totals (soup 20, chicken 16, oatmeal 10, omelette 8).
    weeklyMenu = [
      MenuEntry(dayIndex: 0, meal: 'Kahvaltı', recipeId: oatmeal.id, servings: 4),
      MenuEntry(dayIndex: 0, meal: 'Öğle', recipeId: soup.id, servings: 8),
      MenuEntry(dayIndex: 1, meal: 'Akşam', recipeId: chickenSalad.id, servings: 8),
      MenuEntry(dayIndex: 2, meal: 'Öğle', recipeId: soup.id, servings: 12),
      MenuEntry(dayIndex: 2, meal: 'Akşam', recipeId: omelette.id, servings: 4),
      MenuEntry(dayIndex: 3, meal: 'Akşam', recipeId: chickenSalad.id, servings: 8),
      MenuEntry(dayIndex: 3, meal: 'Kahvaltı', recipeId: oatmeal.id, servings: 6),
      MenuEntry(dayIndex: 4, meal: 'Akşam', recipeId: omelette.id, servings: 4),
    ];
    weekStart = today;
    generateGroceryList();
  }
}
