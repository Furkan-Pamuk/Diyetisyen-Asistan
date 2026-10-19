import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/grocery_category.dart';
import '../models/disposal.dart';
import '../models/inventory_item.dart';
import '../models/menu_entry.dart';
import '../models/recipe.dart';
import '../models/order_cart.dart';
import '../models/order_line.dart';
import '../models/stock_batch.dart';
import '../models/supplier.dart';
import '../models/supplier_order.dart';
import '../models/user_note.dart';
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

  /// Üretim tablosu haftalık mod: gün gün kişi sayısı ("hafta-gün" -> sayı).
  /// Sağ üstteki tek kutu tüm güne yazar; gün kartından ayrı ayrı değişir.
  Map<String, int> prodServings = {};

  /// Arşivlik haftalık üretim kayıtları (yeniden bakılabilir).
  List<ProductionArchive> productionArchives = [];

  // ---------- Sipariş sepeti ----------

  List<OrderCartItem> orderCart = [];

  int get cartCount => orderCart.length;

  double get cartTotalQty =>
      orderCart.fold(0, (s, e) => s + e.quantity);

  /// Sepete ekle; aynı ürün varsa miktarı birleştirir.
  Future<void> addToCart({
    required String itemId,
    required String name,
    required String unitKey,
    required double quantity,
    String? supplierId,
  }) async {
    if (quantity <= 0) return;
    final i = orderCart.indexWhere((e) => e.itemId == itemId);
    if (i >= 0) {
      orderCart[i].quantity += quantity;
      if (supplierId != null) orderCart[i].supplierId = supplierId;
    } else {
      orderCart.add(OrderCartItem(
        itemId: itemId,
        name: name,
        unitKey: unitKey,
        quantity: quantity,
        supplierId: supplierId,
      ));
    }
    await save();
  }

  Future<void> updateCartQty(String id, double qty) async {
    final i = orderCart.indexWhere((e) => e.id == id);
    if (i == -1) return;
    if (qty <= 0) {
      orderCart.removeAt(i);
    } else {
      orderCart[i].quantity = qty;
    }
    await save();
  }

  Future<void> removeFromCart(String id) async {
    orderCart.removeWhere((e) => e.id == id);
    await save();
  }

  Future<void> clearCart() async {
    orderCart.clear();
    await save();
  }

  /// Sepeti tedarikçi siparişine dönüştürür ve sepeti boşaltır.
  /// Kalemler sipariş notuna yazılır (ürün: miktar).
  /// [ids] verilirse yalnız o kalemler dönüştürülür.
  Future<SupplierOrder?> cartToOrder(
      {String? supplierId, List<String>? ids}) async {
    final items = ids == null
        ? List<OrderCartItem>.from(orderCart)
        : orderCart.where((e) => ids.contains(e.id)).toList();
    if (items.isEmpty) return null;
    Supplier supplier = defaultSupplier;
    if (supplierId != null) {
      try {
        supplier =
            suppliers.firstWhere((s) => s.id == supplierId);
      } catch (_) {
        supplier = defaultSupplier;
      }
    }
    final lines = items.map((e) {
      final sup = e.supplierId != null
          ? ' [${supplierNameById(e.supplierId!)}]'
          : '';
      return '• ${e.name}: ${e.formattedQty()}$sup';
    }).join('\n');
    final now = DateTime.now();
    final order = SupplierOrder(
      title: 'Sepet siparişi (${items.length} kalem)',
      supplierName: supplier.name,
      supplierId: supplier.id,
      orderDate: now,
      pickupDate: now.add(const Duration(days: 2)),
      status: SupplierOrderStatus.scheduled,
      notes: lines,
      items: items
          .map((e) => OrderLine(
                itemId: e.itemId,
                name: e.name,
                unitKey: e.unitKey,
                orderedQty: e.quantity,
              ))
          .toList(),
    );
    supplierOrders.add(order);
    orderCart.removeWhere((e) => items.any((i) => i.id == e.id));
    await save();
    await NotificationService.instance.reschedule(order);
    return order;
  }

  /// Sepetteki tedarikçi gruplarının her birini ayrı siparişe dönüştürür.
  Future<List<SupplierOrder>> cartToOrdersByGroup() async {
    final groups = cartGroupedBySupplier();
    final created = <SupplierOrder>[];
    for (final entry in groups.entries) {
      final order = await cartToOrder(
        supplierId: entry.key == 'unassigned' ? null : entry.key,
        ids: entry.value.map((e) => e.id).toList(),
      );
      if (order != null) created.add(order);
    }
    return created;
  }

  /// Sepet kalemlerini tedarikçiye göre gruplar.
  /// Anahtar: supplierId veya 'unassigned'.
  Map<String, List<OrderCartItem>> cartGroupedBySupplier() {
    final map = <String, List<OrderCartItem>>{};
    for (final e in orderCart) {
      map.putIfAbsent(e.supplierId ?? 'unassigned', () => []).add(e);
    }
    // Tedarikçi adına göre sıralı grup listesi için çağrılan yerde sıralanır.
    return map;
  }

  List<String> cartGroupOrder() {
    final keys = cartGroupedBySupplier().keys.toList();
    keys.sort((a, b) {
      if (a == 'unassigned') return 1;
      if (b == 'unassigned') return -1;
      return supplierNameById(a)
          .toLowerCase()
          .compareTo(supplierNameById(b).toLowerCase());
    });
    return keys;
  }

  Future<void> setCartItemSupplier(String id, String? supplierId) async {
    final i = orderCart.indexWhere((e) => e.id == id);
    if (i == -1) return;
    orderCart[i].supplierId = supplierId;
    await save();
  }

  // ---------- Profil (fotoğraf + isim + ünvan) ----------

  String profileName = '';
  String profileTitle = '';
  /// JPEG baytlarının base64 hali (küçük avatar, cihazda + bulutta saklanır).
  String profilePhotoBase64 = '';

  bool get hasProfile =>
      profileName.trim().isNotEmpty || profileTitle.trim().isNotEmpty;

  /// Karşılama satırı: "Hoşgeldiniz, Melike" / boşsa "Hoş Geldiniz".
  String get greetingName {
    final n = profileName.trim();
    if (n.isEmpty) return '';
    return n.split(RegExp(r'\s+')).first;
  }

  Future<void> updateProfile({String? name, String? title}) async {
    if (name != null) profileName = name.trim();
    if (title != null) profileTitle = title.trim();
    await save();
  }

  Future<void> setProfilePhoto(String base64) async {
    profilePhotoBase64 = base64;
    await save();
  }

  Future<void> clearProfilePhoto() async {
    profilePhotoBase64 = '';
    await save();
  }

  // ---------- Notlar (yazılı + sesli) ----------

  List<UserNote> notes = [];

  /// Ses baytları: SADECE bu cihazda (ayrı anahtar, buluta gitmez).
  final Map<String, String> _noteAudioBase64 = {};

  bool noteHasAudio(String id) =>
      _noteAudioBase64.containsKey(id) ||
      notes.any((n) => n.id == id && n.hasAudio);

  String? noteAudioBase64(String id) => _noteAudioBase64[id];

  Future<UserNote> addNote(String text, {bool hasAudio = false}) async {
    final note = UserNote(text: text.trim(), hasAudio: hasAudio);
    notes.insert(0, note);
    await save();
    return note;
  }

  Future<void> updateNoteText(String id, String text) async {
    final i = notes.indexWhere((n) => n.id == id);
    if (i == -1) return;
    notes[i].text = text.trim();
    await save();
  }

  Future<void> deleteNote(String id) async {
    notes.removeWhere((n) => n.id == id);
    _noteAudioBase64.remove(id);
    await _saveAudioLocal();
    await NotificationService.instance.cancelNote(id);
    await save();
  }

  /// Nota tarih-saat hatırlatıcısı kurar (null = iptal).
  Future<void> setNoteReminder(String id, DateTime? at) async {
    final i = notes.indexWhere((n) => n.id == id);
    if (i == -1) return;
    notes[i].reminderAt = at;
    if (at == null) {
      await NotificationService.instance.cancelNote(id);
    } else {
      await NotificationService.instance
          .scheduleNoteReminder(id, notes[i].text, at);
    }
    await save();
  }

  Future<void> setNoteAudio(String id, String base64) async {
    _noteAudioBase64[id] = base64;
    final i = notes.indexWhere((n) => n.id == id);
    if (i >= 0) notes[i].hasAudio = true;
    await _saveAudioLocal();
    await save();
  }

  Future<void> _saveAudioLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          '$_storageKey-note-audio', jsonEncode(_noteAudioBase64));
    } catch (e) {
      debugPrint('Audio save failed: $e');
    }
  }

  Future<void> _loadAudioLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_storageKey-note-audio');
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _noteAudioBase64
        ..clear()
        ..addEntries(map.entries.map((e) =>
            MapEntry(e.key, e.value as String)));
      // Silinmiş notların seslerini temizle.
      _noteAudioBase64.removeWhere(
          (id, _) => !notes.any((n) => n.id == id));
    } catch (e) {
      debugPrint('Audio load failed: $e');
    }
  }

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

  /// "Sipariş Verdim": sipariş durumunu bekliyora alır.
  Future<void> markOrdered(SupplierOrder order) async {
    order.status = SupplierOrderStatus.ordered;
    await updateOrder(order);
  }

  // ---------- Stok parti girişleri (giriş tarihi + miktar) ----------

  List<StockBatch> stockBatches = [];

  List<StockBatch> batchesFor(String itemId) {
    final list =
        stockBatches.where((b) => b.itemId == itemId).toList();
    list.sort((a, b) => a.entryDate.compareTo(b.entryDate));
    return list;
  }

  DateTime? oldestEntryDate(String itemId) {
    final list = batchesFor(itemId);
    return list.isEmpty ? null : list.first.entryDate;
  }

  Future<void> _addBatch(
      String itemId, double qty, String source) async {
    if (qty <= 0) return;
    stockBatches.add(StockBatch(
      itemId: itemId,
      quantity: qty,
      source: source,
    ));
  }

  Future<void> deleteBatch(String id) async {
    stockBatches.removeWhere((b) => b.id == id);
    await save();
  }

  // ---------- İmha tutanağı (şablon + formlar) ----------

  DisposalTemplate disposalTemplate = DisposalTemplate();
  List<DisposalForm> disposalForms = [];

  Future<void> saveDisposalTemplate(DisposalTemplate t) async {
    disposalTemplate = t;
    await save();
  }

  Future<void> addDisposalForm(DisposalForm f) async {
    disposalForms.insert(0, f);
    await save();
  }

  Future<void> updateDisposalForm(DisposalForm f) async {
    final i = disposalForms.indexWhere((e) => e.id == f.id);
    if (i == -1) return;
    disposalForms[i] = f;
    await save();
  }

  Future<void> deleteDisposalForm(String id) async {
    disposalForms.removeWhere((e) => e.id == id);
    await save();
  }

  /// İmha miktarlarını stoktan düşer (bir kez; tekrar basılamaz).
  Future<void> deductDisposalStock(String formId) async {
    DisposalForm? form;
    try {
      form = disposalForms.firstWhere((e) => e.id == formId);
    } catch (_) {
      return;
    }
    if (form.stockDeducted) return;
    for (final line in form.lines) {
      InventoryItem? item;
      if (line.itemId != null) {
        item = itemById(line.itemId!);
      }
      item ??= itemByName(line.productName);
      if (item != null && line.quantity > 0) {
        item.currentStock =
            (item.currentStock - line.quantity)
                .clamp(0, double.infinity)
                .toDouble();
      }
    }
    form.stockDeducted = true;
    await save();
  }

  // ---------- Teslim alma (mal kabul) + arşiv ----------

  List<GoodsReceipt> receipts = [];

  InventoryItem? itemByName(String name) {
    final q = name.trim().toLowerCase();
    if (q.isEmpty) return null;
    try {
      return inventory
          .firstWhere((e) => e.name.trim().toLowerCase() == q);
    } catch (_) {
      return null;
    }
  }

  /// Siparişi teslim alır: gelen miktarlar stoğa işlenir, sipariş
  /// "Teslim Alındı" olur, detay arşive kaydedilir.
  /// Silinen kalemler listede olmaz; yeni ürünler stoklara açılır.
  Future<GoodsReceipt?> receiveOrder(
    String orderId,
    List<ReceiptInput> inputs, {
    String note = '',
  }) async {
    final oi = supplierOrders.indexWhere((e) => e.id == orderId);
    if (oi == -1) return null;
    final order = supplierOrders[oi];
    final lines = <ReceiptLine>[];
    for (final input in inputs) {
      InventoryItem? item = itemById(input.itemId ?? '');
      item ??= itemByName(input.name);
      if (item == null && input.receivedQty > 0) {
        item = InventoryItem(
          name: input.name.trim(),
          category: input.category ?? GroceryCategory.freshProduce,
          unit: input.unitKey == 'piece'
              ? StockUnit.piece
              : StockUnit.gram,
          currentStock: 0,
          warehouseStock: 0,
          minThreshold: 0,
        );
        inventory.add(item);
      }
      if (item != null && input.receivedQty > 0) {
        item.currentStock += input.receivedQty;
        item.warehouseStock += input.receivedQty;
        await _addBatch(
            item.id, input.receivedQty, 'Sipariş: ${order.title}');
      }
      lines.add(ReceiptLine(
        name: input.name.trim(),
        unitKey: input.unitKey,
        orderedQty: input.orderedQty,
        receivedQty: input.receivedQty,
      ));
    }
    order.status = SupplierOrderStatus.pickedUp;
    final receipt = GoodsReceipt(
      orderId: order.id,
      orderTitle: order.title,
      supplierName: order.supplierName,
      supplierId: order.supplierId,
      lines: lines,
      note: note.trim(),
    );
    receipts.insert(0, receipt);
    await save();
    await NotificationService.instance.reschedule(order);
    await generateGroceryList();
    return receipt;
  }

  /// Stok ekranından doğrudan mal kabul (siparişsiz): stoğa işlenir
  /// ve teslimat arşivine kaydedilir.
  Future<GoodsReceipt?> logDirectReceipt({
    required String itemId,
    required double quantity,
    String? supplierId,
    String note = '',
  }) async {
    final item = itemById(itemId);
    if (item == null || quantity <= 0) return null;
    item.currentStock += quantity;
    item.warehouseStock += quantity;
    String supName = '';
    if (supplierId != null) supName = supplierNameById(supplierId);
    await _addBatch(
        item.id, quantity, supName.isEmpty ? 'Doğrudan' : supName);
    final receipt = GoodsReceipt(
      orderTitle: 'Doğrudan mal kabul',
      supplierName: supName,
      supplierId: supplierId,
      lines: [
        ReceiptLine(
          name: item.name,
          unitKey: item.unit.key,
          orderedQty: quantity,
          receivedQty: quantity,
        ),
      ],
      note: note.trim(),
    );
    receipts.insert(0, receipt);
    await save();
    return receipt;
  }

  Future<void> deleteReceipt(String id) async {
    receipts.removeWhere((e) => e.id == id);
    await save();
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
    final list = inventory.where((e) => e.isWarning).toList();
    list.sort((a, b) => a.currentStock.compareTo(b.currentStock));
    return list;
  }

  /// Kırmızı: kritik eşikte/below. Sarı: uyarı eşiğinde ama kritik üstü.
  List<InventoryItem> get criticalStockItems {
    final list = inventory.where((e) => e.isCritical).toList();
    list.sort((a, b) => a.currentStock.compareTo(b.currentStock));
    return list;
  }

  List<InventoryItem> get warningStockItems {
    final list = inventory
        .where((e) => e.isWarning && !e.isCritical)
        .toList();
    list.sort((a, b) => a.currentStock.compareTo(b.currentStock));
    return list;
  }

  List<String> get stockAlertMessages => inventory
      .where((e) => e.isWarning)
      .map((e) => e.alertMessage())
      .toList();

  Future<void> setThresholds(
      String itemId, double warn, double critical) async {
    final item = itemById(itemId);
    if (item == null) return;
    var w = warn.clamp(0, double.infinity).toDouble();
    var c = critical.clamp(0, double.infinity).toDouble();
    if (w < c) w = c; // uyarı kritik altına düşemez
    item.warnThreshold = w;
    item.minThreshold = c;
    await save();
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
    await _addBatch(itemId, qty, 'Mal kabul');
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

  /// Yemek adına göre tarif bulur (birebir, yoksa büyük/küçük harf
  /// duyarsız). Bulamazsa null döner — içe aktarma bunu "reçete eksik"
  /// uyarısı için kullanır.
  Recipe? findRecipeByName(String name) {
    final q = name.trim().toLowerCase();
    if (q.isEmpty) return null;
    try {
      return recipes.firstWhere((r) => r.name.trim().toLowerCase() == q);
    } catch (_) {
      return null;
    }
  }

  /// Bulamazsa boş reçeteli taslak tarif oluşturur (reçete eksik
  /// uyarısı verir, kullanıcı Reçeteler sayfasında doldurur).
  Future<Recipe> findOrCreateRecipeByName(String name) async {
    final found = findRecipeByName(name);
    if (found != null) return found;
    final created = Recipe(
      name: name.trim(),
      description: 'Menüden aktarıldı — reçete bekleniyor',
      servingsDefault: 1,
      ingredients: [],
    );
    recipes.add(created);
    await save();
    return created;
  }

  bool recipeNeedsAttention(Recipe recipe) => recipe.ingredients.isEmpty;

  // ---------- Haftalık menü üretim hesabı (reçeteler tek kişilik) ----------

  static const int defaultProdServings = 100;

  String _prodKey(int week, int day) => '$week-$day';

  /// Günlük kişi sayısı (üretim tablosu). Varsayılan 100.
  int prodServingsFor(int week, int day) =>
      prodServings[_prodKey(week, day)] ?? defaultProdServings;

  Future<void> setProdServings(int week, int day, int value) async {
    prodServings[_prodKey(week, day)] = value.clamp(1, 10000);
    await save();
  }

  /// Sağ üstteki tek kutu: tüm haftaya aynı sayıyı yazar.
  Future<void> setProdServingsWeek(int week, int value) async {
    final v = value.clamp(1, 10000);
    for (var d = 0; d < 7; d++) {
      prodServings[_prodKey(week, d)] = v;
    }
    await save();
  }

  /// Haftanın gün gün kişi sayıları (arşiv + toplam için).
  Map<int, int> prodServingsOfWeek(int week) => {
        for (var d = 0; d < 7; d++) d: prodServingsFor(week, d),
      };

  /// Belirli günün malzeme toplamları: itemId -> toplam gram/adet.
  /// Reçeteler tek kişilik kabul edilir: toplam = porsiyon_miktarı × porsiyon.
  Map<String, double> menuDayTotals(int dayIndex, [int weekIndex = 0]) {
    final totals = <String, double>{};
    for (final e in weeklyMenu) {
      if (e.dayIndex != dayIndex || e.weekIndex != weekIndex) continue;
      final recipe = recipeById(e.recipeId);
      if (recipe == null) continue;
      for (final ing in recipe.ingredients) {
        totals[ing.itemId] =
            (totals[ing.itemId] ?? 0) + ing.amountPerServing * e.servings;
      }
    }
    return totals;
  }

  /// Üretim tablosu için: günün tüm yemekleri GLOBAL kişi sayısıyla
  /// hesaplanır (öğünlük kişi kutusu yok, sağ üstteki tek sayı geçerli).
  Map<String, double> menuDayTotalsForServings(
      int dayIndex, int weekIndex, int servings) {
    final totals = <String, double>{};
    for (final e in weeklyMenu) {
      if (e.dayIndex != dayIndex || e.weekIndex != weekIndex) continue;
      final recipe = recipeById(e.recipeId);
      if (recipe == null) continue;
      for (final ing in recipe.ingredients) {
        totals[ing.itemId] =
            (totals[ing.itemId] ?? 0) + ing.amountPerServing * servings;
      }
    }
    return totals;
  }

  /// Tüm haftanın malzeme toplamları (7 gün).
  Map<String, double> menuWeekTotals([int weekIndex = 0]) {
    final totals = <String, double>{};
    for (var d = 0; d < 7; d++) {
      menuDayTotals(d, weekIndex).forEach((k, v) {
        totals[k] = (totals[k] ?? 0) + v;
      });
    }
    return totals;
  }

  /// Haftanın tamamı GLOBAL kişi sayısıyla (üretim tablosu).
  Map<String, double> menuWeekTotalsForServings(
      int weekIndex, int servings) {
    final totals = <String, double>{};
    for (var d = 0; d < 7; d++) {
      menuDayTotalsForServings(d, weekIndex, servings).forEach((k, v) {
        totals[k] = (totals[k] ?? 0) + v;
      });
    }
    return totals;
  }

  /// Haftanın tamamı GÜN GÜN kişi sayılarıyla (üretim tablosu yeni davranış).
  Map<String, double> menuWeekTotalsForDailyServings(int weekIndex) {
    final totals = <String, double>{};
    for (var d = 0; d < 7; d++) {
      menuDayTotalsForServings(d, weekIndex, prodServingsFor(weekIndex, d))
          .forEach((k, v) {
        totals[k] = (totals[k] ?? 0) + v;
      });
    }
    return totals;
  }

  /// Kümülatif gün sonu stok projeksiyonu: hafta başı stoktan başlayıp
  /// 0..dayIndex günlerinin harcamalarını düşer.
  /// Dönen map: itemId -> o gün sonu kalan (gün gün kişi sayılarıyla).
  Map<String, double> endOfDayStock(int dayIndex, int weekIndex) {
    final cumulative = <String, double>{};
    for (var d = 0; d <= dayIndex; d++) {
      menuDayTotalsForServings(d, weekIndex, prodServingsFor(weekIndex, d))
          .forEach((k, v) {
        cumulative[k] = (cumulative[k] ?? 0) + v;
      });
    }
    final result = <String, double>{};
    for (final item in inventory) {
      result[item.id] = item.currentStock - (cumulative[item.id] ?? 0);
    }
    return result;
  }

  // ---------- Üretim arşivi ----------

  Future<ProductionArchive> archiveWeekProduction(int weekIndex) async {
    final servings = prodServingsOfWeek(weekIndex);
    final totals = menuWeekTotalsForDailyServings(weekIndex);
    final names = <String, String>{};
    final units = <String, String>{};
    for (final id in totals.keys) {
      final item = itemById(id);
      names[id] = item?.name ?? '?';
      units[id] = item?.unit.key ?? 'gram';
    }
    final archive = ProductionArchive(
      weekIndex: weekIndex,
      weekLabel: MenuEntry.weeks[weekIndex],
      servingsByDay: servings,
      totals: totals,
      itemNames: names,
      itemUnits: units,
    );
    productionArchives.insert(0, archive);
    await save();
    return archive;
  }

  Future<void> deleteArchive(String id) async {
    productionArchives.removeWhere((a) => a.id == id);
    await save();
  }

  /// Reçetesi eksik (hiç malzemesi yok) menü satırları — uyarı için.
  List<MenuEntry> menuEntriesMissingRecipe([int? weekIndex]) {
    return weeklyMenu.where((e) {
      if (weekIndex != null && e.weekIndex != weekIndex) return false;
      final r = recipeById(e.recipeId);
      return r == null || r.ingredients.isEmpty;
    }).toList();
  }

  /// Günlük üretim: o günün tüm öğünlerini stoktan düşer.
  Future<Map<String, double>> produceMenuDay(int dayIndex,
      [int weekIndex = 0]) async {
    final entries = weeklyMenu
        .where((e) => e.dayIndex == dayIndex && e.weekIndex == weekIndex)
        .toList();
    final totals = menuDayTotals(dayIndex, weekIndex);
    totals.forEach((itemId, amount) {
      final item = itemById(itemId);
      if (item != null) {
        item.currentStock =
            (item.currentStock - amount).clamp(0, double.infinity).toDouble();
      }
    });
    for (final e in entries) {
      final recipe = recipeById(e.recipeId);
      productionLogs.insert(
        0,
        ProductionLog(
          recipeId: e.recipeId,
          recipeName: recipe?.name ?? 'Menü yemeği',
          servingsMade: e.servings,
          deductions: {
            for (final ing in (recipe?.ingredients ?? <RecipeIngredient>[]))
              ing.itemId: ing.amountPerServing * e.servings,
          },
        ),
      );
    }
    await save();
    await generateGroceryList();
    return totals;
  }

  /// Günlük üretim (üretim tablosu): tüm öğünler GLOBAL kişi sayısıyla.
  Future<Map<String, double>> produceMenuDayForServings(
      int dayIndex, int weekIndex, int servings) async {
    final entries = weeklyMenu
        .where((e) => e.dayIndex == dayIndex && e.weekIndex == weekIndex)
        .toList();
    final totals = menuDayTotalsForServings(dayIndex, weekIndex, servings);
    totals.forEach((itemId, amount) {
      final item = itemById(itemId);
      if (item != null) {
        item.currentStock =
            (item.currentStock - amount).clamp(0, double.infinity).toDouble();
      }
    });
    for (final e in entries) {
      final recipe = recipeById(e.recipeId);
      productionLogs.insert(
        0,
        ProductionLog(
          recipeId: e.recipeId,
          recipeName: recipe?.name ?? 'Menü yemeği',
          servingsMade: servings,
          deductions: {
            for (final ing in (recipe?.ingredients ?? <RecipeIngredient>[]))
              ing.itemId: ing.amountPerServing * servings,
          },
        ),
      );
    }
    await save();
    await generateGroceryList();
    return totals;
  }

  /// Haftalık üretim: 7 günün tamamını tek seferde stoktan düşer.
  Future<Map<String, double>> produceMenuWeek([int weekIndex = 0]) async {
    final totals = menuWeekTotals(weekIndex);
    totals.forEach((itemId, amount) {
      final item = itemById(itemId);
      if (item != null) {
        item.currentStock =
            (item.currentStock - amount).clamp(0, double.infinity).toDouble();
      }
    });
    productionLogs.insert(
      0,
      ProductionLog(
        recipeId: 'haftalik-menu-$weekIndex',
        recipeName: 'Haftalık menü (${MenuEntry.weeks[weekIndex]})',
        servingsMade:
            weeklyMenu.where((e) => e.weekIndex == weekIndex).fold<int>(
                0, (s, e) => s + e.servings),
        deductions: totals,
      ),
    );
    await save();
    await generateGroceryList();
    return totals;
  }

  /// Haftalık üretim (üretim tablosu): 7 gün GLOBAL kişi sayısıyla.
  Future<Map<String, double>> produceMenuWeekForServings(
      int weekIndex, int servings) async {
    final totals = menuWeekTotalsForServings(weekIndex, servings);
    totals.forEach((itemId, amount) {
      final item = itemById(itemId);
      if (item != null) {
        item.currentStock =
            (item.currentStock - amount).clamp(0, double.infinity).toDouble();
      }
    });
    final count =
        weeklyMenu.where((e) => e.weekIndex == weekIndex).length;
    productionLogs.insert(
      0,
      ProductionLog(
        recipeId: 'haftalik-menu-$weekIndex',
        recipeName:
            'Haftalık menü (${MenuEntry.weeks[weekIndex]}, $servings kişi)',
        servingsMade: servings * count,
        deductions: totals,
      ),
    );
    await save();
    await generateGroceryList();
    return totals;
  }

  /// Günlük üretim (üretim tablosu): o günün kayıtlı günlük kişi sayısıyla.
  Future<Map<String, double>> produceMenuDayForDaily(
      int dayIndex, int weekIndex) async {
    return produceMenuDayForServings(
        dayIndex, weekIndex, prodServingsFor(weekIndex, dayIndex));
  }

  /// Haftalık üretim (üretim tablosu): gün gün kişi sayılarıyla.
  Future<Map<String, double>> produceMenuWeekForDaily(
      int weekIndex) async {
    final totals = menuWeekTotalsForDailyServings(weekIndex);
    totals.forEach((itemId, amount) {
      final item = itemById(itemId);
      if (item != null) {
        item.currentStock =
            (item.currentStock - amount).clamp(0, double.infinity).toDouble();
      }
    });
    final totalServings = weeklyMenu
        .where((e) => e.weekIndex == weekIndex)
        .fold<int>(0, (s, e) => s + prodServingsFor(weekIndex, e.dayIndex));
    productionLogs.insert(
      0,
      ProductionLog(
        recipeId: 'haftalik-menu-$weekIndex',
        recipeName:
            'Haftalık menü (${MenuEntry.weeks[weekIndex]}, gün gün kişi)',
        servingsMade: totalServings,
        deductions: totals,
      ),
    );
    await save();
    await generateGroceryList();
    return totals;
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
        'prodServings': prodServings,
        'archives':
            productionArchives.map((e) => e.toJson()).toList(),
        'cart': orderCart.map((e) => e.toJson()).toList(),
        'receipts': receipts.map((e) => e.toJson()).toList(),
        'batches': stockBatches.map((e) => e.toJson()).toList(),
        'disposalTemplate': disposalTemplate.toJson(),
        'disposalForms':
            disposalForms.map((e) => e.toJson()).toList(),
        'profile': {
          'name': profileName,
          'title': profileTitle,
          'photo': profilePhotoBase64,
        },
        'notes': notes.map((e) => e.toJson()).toList(),
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
    try {
      prodServings = ((j['prodServings'] as Map?) ?? {}).map(
        (k, v) => MapEntry(k as String, (v as num).toInt()),
      );
    } catch (_) {
      prodServings = {};
    }
    try {
      productionArchives = ((j['archives'] as List?) ?? [])
          .map((e) =>
              ProductionArchive.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      productionArchives = [];
    }
    try {
      orderCart = ((j['cart'] as List?) ?? [])
          .map((e) =>
              OrderCartItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      orderCart = [];
    }
    try {
      receipts = ((j['receipts'] as List?) ?? [])
          .map((e) =>
              GoodsReceipt.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      receipts = [];
    }
    try {
      stockBatches = ((j['batches'] as List?) ?? [])
          .map((e) =>
              StockBatch.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      stockBatches = [];
    }
    try {
      if (j['disposalTemplate'] != null) {
        disposalTemplate = DisposalTemplate.fromJson(
            Map<String, dynamic>.from(j['disposalTemplate'] as Map));
      }
    } catch (_) {}
    try {
      disposalForms = ((j['disposalForms'] as List?) ?? [])
          .map((e) =>
              DisposalForm.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      disposalForms = [];
    }
    // Eski kayıtlar: partisi olmayan ürünlere mevcut stoktan açılış partisi.
    if (inventory.isNotEmpty) {
      final withBatch = stockBatches.map((b) => b.itemId).toSet();
      var added = false;
      for (final item in inventory) {
        if (!withBatch.contains(item.id) && item.currentStock > 0) {
          stockBatches.add(StockBatch(
            itemId: item.id,
            quantity: item.currentStock,
            source: 'Mevcut stok',
          ));
          added = true;
        }
      }
      if (added) _saveLocal();
    }
    try {
      final p = (j['profile'] as Map?) ?? {};
      profileName = (p['name'] as String?) ?? '';
      profileTitle = (p['title'] as String?) ?? '';
      profilePhotoBase64 = (p['photo'] as String?) ?? '';
    } catch (_) {
      profileName = '';
      profileTitle = '';
      profilePhotoBase64 = '';
    }
    try {
      notes = ((j['notes'] as List?) ?? [])
          .map((e) =>
              UserNote.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      notes = [];
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
      await _loadAudioLocal();
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
  bool _syncStarting = false;

  DocumentReference get _userDoc => FirebaseFirestore.instance
      .collection('users')
      .doc(_syncUid);

  /// Starts syncing with the cloud account. Last-write-wins:
  /// the newer side (local or cloud) overwrites the other.
  /// Re-entrant çağrılara karşı korumalı (art arda build'lerden
  /// birden çok kez tetiklenebilir).
  Future<void> enableSync(String uid) async {
    if (_syncUid == uid || _syncStarting) return;
    _syncStarting = true;
    try {
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
          } else if (remoteTime == null ||
              updatedAt.isAfter(remoteTime)) {
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
    } finally {
      _syncStarting = false;
    }
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
    for (final item in inventory) {
      stockBatches.add(StockBatch(
        itemId: item.id,
        quantity: item.currentStock,
        source: 'Başlangıç stoku',
      ));
    }

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
