import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
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
  DateTime updatedAt = DateTime.now();

  /// True when Firebase initialized (set by main). Without it: local mode.
  bool firebaseReady = false;

  /// "Hesapsız devam et" choice, persisted separately.
  bool localOnly = false;

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

  List<MenuEntry> menuForDay(int dayIndex, [int weekIndex = 0]) {
    final list = weeklyMenu
        .where((e) => e.dayIndex == dayIndex && e.weekIndex == weekIndex)
        .toList();
    int mealRank(String meal) {
      final i = MenuEntry.meals.indexOf(meal);
      return i == -1 ? 99 : i;
    }

    list.sort((a, b) => mealRank(a.meal).compareTo(mealRank(b.meal)));
    return list;
  }

  /// Total planned servings per recipe, aggregated from the whole
  /// menu program (all 4 weeks for monthly planning).
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

  /// Manually added grocery item (e.g. from autocomplete suggestions).
  Future<void> addGroceryItem(GroceryItem item) async {
    groceryItems.add(item);
    groceryItems.sort((a, b) {
      final ca = GroceryCategory.values.indexOf(a.category);
      final cb = GroceryCategory.values.indexOf(b.category);
      if (ca != cb) return ca.compareTo(cb);
      return a.name.compareTo(b.name);
    });
    await save();
  }

  Future<void> deleteGroceryItem(String id) async {
    groceryItems.removeWhere((e) => e.id == id);
    await save();
  }

  // ---------- Recipes ----------

  Future<void> addRecipe(Recipe recipe) async {
    recipes.add(recipe);
    await save();
  }

  Future<void> updateRecipe(Recipe recipe) async {
    final i = recipes.indexWhere((e) => e.id == recipe.id);
    if (i == -1) return;
    recipes[i] = recipe;
    await save();
  }

  /// Deletes a recipe and removes its lines from the plan and the menu.
  Future<void> deleteRecipe(String id) async {
    recipes.removeWhere((e) => e.id == id);
    weeklyPlan.removeWhere((e) => e.recipeId == id);
    weeklyMenu.removeWhere((e) => e.recipeId == id);
    await save();
    await generateGroceryList();
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

  // ---------- Persistence (local + cloud) ----------

  Map<String, dynamic> snapshotMap() => {
        'orders': supplierOrders.map((e) => e.toJson()).toList(),
        'inventory': inventory.map((e) => e.toJson()).toList(),
        'recipes': recipes.map((e) => e.toJson()).toList(),
        'logs': productionLogs.map((e) => e.toJson()).toList(),
        'grocery': groceryItems.map((e) => e.toJson()).toList(),
        'plan': weeklyPlan.map((e) => e.toJson()).toList(),
        'suppliers': suppliers.map((e) => e.toJson()).toList(),
        'menu': weeklyMenu.map((e) => e.toJson()).toList(),
        'weekStart': weekStart.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Future<void> save() async {
    updatedAt = DateTime.now();
    notifyListeners();
    await _saveLocal();
    _schedulePush();
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(snapshotMap()));
      await prefs.setBool('$_storageKey-local-only', localOnly);
    } catch (e) {
      debugPrint('Save failed: $e');
    }
  }

  void _applySnapshot(Map<String, dynamic> j) {
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
    weekStart = DateTime.tryParse(j['weekStart'] as String? ?? '') ??
        DateTime.now();
    updatedAt = DateTime.tryParse(j['updatedAt'] as String? ?? '') ??
        DateTime.now();
  }

  Future<bool> loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      localOnly =
          prefs.getBool('$_storageKey-local-only') ?? false;
      final raw = prefs.getString(_storageKey);
      if (raw == null) return false;
      _applySnapshot(jsonDecode(raw) as Map<String, dynamic>);
      return true;
    } catch (e) {
      debugPrint('Load failed: $e');
      return false;
    }
  }

  // ---------- Cloud sync (Firebase, same account = same data) ----------

  String? _syncUid;
  bool get syncOn => _syncUid != null;
  StreamSubscription<DocumentSnapshot>? _syncSub;
  Timer? _pushTimer;

  DocumentReference get _userDoc => FirebaseFirestore.instance
      .collection('users')
      .doc(_syncUid);

  /// Starts syncing with the cloud account. Last-write-wins:
  /// the newer side (local or cloud) overwrites the other.
  Future<void> enableSync(String uid) async {
    if (_syncUid == uid) return;
    await _syncSub?.cancel();
    _syncUid = uid;
    try {
      final snap = await _userDoc.get();
      final data = snap.data() as Map<String, dynamic>?;
      if (data != null) {
        final remoteTime =
            DateTime.tryParse(data['updatedAt'] as String? ?? '');
        if (remoteTime != null && remoteTime.isAfter(updatedAt)) {
          _applySnapshot(Map<String, dynamic>.from(data));
          await _saveLocal();
        } else if (remoteTime == null || updatedAt.isAfter(remoteTime)) {
          await _pushNow();
        }
      } else {
        await _pushNow(); // first login: upload local data
      }
      _syncSub = _userDoc.snapshots().listen((s) {
        final d = s.data() as Map<String, dynamic>?;
        if (d == null) return;
        final remoteTime =
            DateTime.tryParse(d['updatedAt'] as String? ?? '');
        if (remoteTime != null && remoteTime.isAfter(updatedAt)) {
          _applySnapshot(Map<String, dynamic>.from(d));
          _saveLocal();
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('Sync failed: $e');
    }
    notifyListeners();
  }

  Future<void> disableSync() async {
    await _syncSub?.cancel();
    _pushTimer?.cancel();
    _syncSub = null;
    _syncUid = null;
    await _saveLocal();
    notifyListeners();
  }

  void _schedulePush() {
    if (_syncUid == null) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(seconds: 1), _pushNow);
  }

  Future<void> _pushNow() async {
    if (_syncUid == null) return;
    try {
      await _userDoc.set(snapshotMap());
    } catch (e) {
      debugPrint('Push failed: $e');
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
    final potato = mk('Patates', GroceryCategory.freshProduce, StockUnit.gram, 3000, 5000, 1000);
    final onion = mk('Soğan', GroceryCategory.freshProduce, StockUnit.gram, 2000, 4000, 1000);
    final lettuce = mk('Marul', GroceryCategory.freshProduce, StockUnit.piece, 6, 20, 5);
    final banana = mk('Muz', GroceryCategory.freshProduce, StockUnit.piece, 6, 20, 4);
    final mandarin = mk('Mandalina', GroceryCategory.freshProduce, StockUnit.piece, 10, 30, 6);
    final orange = mk('Portakal', GroceryCategory.freshProduce, StockUnit.piece, 8, 24, 6);
    final mince = mk('Kıyma', GroceryCategory.meatDairy, StockUnit.gram, 2000, 4000, 1500);
    final yogurt = mk('Yoğurt', GroceryCategory.meatDairy, StockUnit.gram, 2500, 4000, 1000);
    final bulgur = mk('Bulgur', GroceryCategory.dryGoods, StockUnit.gram, 3000, 5000, 1500);
    final chickpea = mk('Nohut', GroceryCategory.dryGoods, StockUnit.gram, 2500, 4000, 1000);
    inventory = [tomato, cucumber, apple, lentils, rice, oats, chicken, milk, eggs,
      potato, onion, lettuce, banana, mandarin, orange, mince, yogurt, bulgur, chickpea];

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
    final icliKofte = Recipe(name: 'İçli Köfte', description: '6 kişilik',
        servingsDefault: 6,
        ingredients: [ing(bulgur, 80), ing(mince, 100), ing(onion, 30)]);
    final tavukSote = Recipe(name: 'Tavuk Sote', description: '4 kişilik',
        servingsDefault: 4,
        ingredients: [ing(chicken, 150), ing(tomato, 80), ing(onion, 30)]);
    final bulgurPilav = Recipe(name: 'Bulgur Pilavı', description: '4 kişilik',
        servingsDefault: 4,
        ingredients: [ing(bulgur, 70), ing(onion, 20)]);
    final cacik = Recipe(name: 'Cacık', description: '2 kişilik',
        servingsDefault: 2,
        ingredients: [ing(yogurt, 150), ing(cucumber, 60)]);
    final menemen = Recipe(name: 'Menemen', description: '2 kişilik',
        servingsDefault: 2,
        ingredients: [ing(eggs, 2), ing(tomato, 100)]);
    final kisir = Recipe(name: 'Kısır', description: '4 kişilik',
        servingsDefault: 4,
        ingredients: [ing(bulgur, 60), ing(tomato, 50), ing(onion, 15)]);
    final cobanSalata = Recipe(name: 'Çoban Salata', description: '2 kişilik',
        servingsDefault: 2,
        ingredients: [ing(tomato, 80), ing(cucumber, 60), ing(onion, 20)]);
    final etliNohut = Recipe(name: 'Etli Nohut', description: '4 kişilik',
        servingsDefault: 4,
        ingredients: [ing(chickpea, 70), ing(mince, 60), ing(onion, 20)]);
    final meyveSalata = Recipe(name: 'Meyve Salatası', description: '2 kişilik',
        servingsDefault: 2,
        ingredients: [ing(apple, 1), ing(banana, 1), ing(orange, 1), ing(mandarin, 2)]);
    final mercimekKofte = Recipe(name: 'Mercimek Köftesi', description: '4 kişilik',
        servingsDefault: 4,
        ingredients: [ing(lentils, 50), ing(bulgur, 40), ing(onion, 20)]);
    final firinTavuk = Recipe(name: 'Fırın Tavuk Patates', description: '4 kişilik',
        servingsDefault: 4,
        ingredients: [ing(chicken, 150), ing(potato, 120), ing(onion, 20)]);
    final yogurtCorba = Recipe(name: 'Yoğurt Çorbası', description: '4 kişilik',
        servingsDefault: 4,
        ingredients: [ing(yogurt, 120), ing(rice, 20)]);
    recipes = [soup, chickenSalad, oatmeal, omelette, icliKofte, tavukSote,
      bulgurPilav, cacik, menemen, kisir, cobanSalata, etliNohut, meyveSalata,
      mercimekKofte, firinTavuk, yogurtCorba];

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
