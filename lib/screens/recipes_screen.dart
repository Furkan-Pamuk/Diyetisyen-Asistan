import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/grocery_category.dart';
import '../models/inventory_item.dart';
import '../models/recipe.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';
import '../widgets/product_name_field.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final q = _search.trim().toLowerCase();
    final recipes = List.of(q.isEmpty
        ? store.recipes
        : store.recipes.where(
            (r) => r.name.toLowerCase().contains(q)))
      ..sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Üretim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Yeni tarif',
            onPressed: () => _openForm(context, null),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SearchBar(
              hintText: 'Tarif ara (örn. köfte)',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Tarif Ekle'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Tarifler (${recipes.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Colors.grey.shade700)),
          ),
          if (recipes.isEmpty)
            const ListTile(
                title: Text('Aramanla eşleşen tarif yok.')),
          for (final r in recipes)
            Card(
              margin:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(r.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          tooltip: 'Düzenle',
                          onPressed: () => _openForm(context, r),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: 'Sil',
                          onPressed: () => _confirmDelete(context, r),
                        ),
                        FilledButton(
                          onPressed: () => _openProduce(context, r),
                          child: const Text('Üret'),
                        ),
                      ],
                    ),
                    if (r.description.isNotEmpty)
                      Text(r.description,
                          style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(_summary(context, r),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Üretim Geçmişi',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Colors.grey.shade700)),
          ),
          if (store.productionLogs.isEmpty)
            const ListTile(title: Text('Henüz üretim yapılmadı.')),
          for (final log in store.productionLogs.take(10))
            ListTile(
              title: Text('${log.recipeName} × ${log.servingsMade}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  '${fmtDay(log.date)} • ${log.deductions.length} kalem düşüldü'),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  String _summary(BuildContext context, Recipe recipe) {
    final store = context.read<AppStore>();
    return recipe.ingredients.map((ing) {
      final item = store.itemById(ing.itemId);
      if (item == null) return '?';
      return '${item.name} ${item.formatAmount(ing.amountPerServing)}/porsiyon';
    }).join(' • ');
  }

  void _openProduce(BuildContext context, Recipe recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProduceSheet(recipeId: recipe.id),
    );
  }

  void _openForm(BuildContext context, Recipe? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => RecipeFormSheet(existing: existing),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Recipe recipe) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${recipe.name}" silinsin mi?'),
        content: const Text(
            'Tarif menü ve plandan da çıkarılacak. Stok etkilenmez.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppStore>().deleteRecipe(recipe.id);
    }
  }
}

/// Add / edit recipe with hand-editable ingredients.
/// Each line picks a stock item (or creates a new product on the fly)
/// plus amount per serving.
class RecipeFormSheet extends StatefulWidget {
  final Recipe? existing;
  const RecipeFormSheet({super.key, required this.existing});

  @override
  State<RecipeFormSheet> createState() => _RecipeFormSheetState();
}

class _IngEdit {
  String? itemId; // null = new product below
  final TextEditingController amountCtrl;
  String newName = '';
  GroceryCategory newCategory = GroceryCategory.freshProduce;
  StockUnit newUnit = StockUnit.gram;

  _IngEdit({this.itemId, required double amount})
      : amountCtrl = TextEditingController(
            text: amount.toStringAsFixed(amount >= 100 ? 0 : 1));

  void dispose() => amountCtrl.dispose();

  double get amount =>
      double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? -1;
}

class _RecipeFormSheetState extends State<RecipeFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _servingsCtrl;
  final List<_IngEdit> _rows = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _desc = TextEditingController(text: e?.description ?? '');
    _servingsCtrl =
        TextEditingController(text: '${e?.servingsDefault ?? 4}');
    if (e != null) {
      for (final ing in e.ingredients) {
        _rows.add(_IngEdit(
            itemId: ing.itemId, amount: ing.amountPerServing));
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _servingsCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  int get _servings => int.tryParse(_servingsCtrl.text) ?? 0;

  bool _rowValid(AppStore store, _IngEdit row) {
    if (row.amount <= 0) return false;
    if (row.itemId != null) {
      return store.itemById(row.itemId!) != null;
    }
    return row.newName.trim().isNotEmpty;
  }

  bool _valid(AppStore store) {
    return _name.text.trim().isNotEmpty &&
        _servings >= 1 &&
        _servings <= 100 &&
        _rows.isNotEmpty &&
        _rows.every((r) => _rowValid(store, r));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final valid = _valid(store);
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'Yeni Tarif' : 'Tarifi Düzenle',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Yemek adı (örn. İçli Köfte)',
                  border: OutlineInputBorder(),
                  isDense: true),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _desc,
              decoration: const InputDecoration(
                  labelText: 'Açıklama (opsiyonel)',
                  border: OutlineInputBorder(),
                  isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _servingsCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Varsayılan porsiyon (1-100)',
                border: const OutlineInputBorder(),
                isDense: true,
                errorText: (_servings >= 1 && _servings <= 100)
                    ? null
                    : '1-100 arası',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('Malzemeler (${_rows.length})',
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  onPressed: () => setState(() =>
                      _rows.add(_IngEdit(itemId: _defaultItemId(store), amount: 100))),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Satır Ekle'),
                ),
              ],
            ),
            for (int i = 0; i < _rows.length; i++)
              _ingredientCard(context, store, i),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Vazgeç'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: valid ? _save : null,
                    child: const Text('Kaydet'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String? _defaultItemId(AppStore store) {
    return store.inventory.isNotEmpty ? store.inventory.first.id : null;
  }

  Widget _ingredientCard(
      BuildContext context, AppStore store, int index) {
    final row = _rows[index];
    final isNew = row.itemId == null ||
        store.itemById(row.itemId!) == null;
    if (row.itemId != null && store.itemById(row.itemId!) == null) {
      row.itemId = null; // fall back to new-product mode
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: isNew ? '__new__' : row.itemId,
                    decoration: const InputDecoration(
                        labelText: 'Stok ürünü',
                        border: OutlineInputBorder(),
                        isDense: true),
                    items: [
                      for (final item in store.inventory)
                        DropdownMenuItem(
                            value: item.id,
                            child: Text(
                                '${item.name} (${item.unit.abbreviation})',
                                overflow: TextOverflow.ellipsis)),
                      const DropdownMenuItem(
                          value: '__new__',
                          child: Text('+ Yeni ürün...')),
                    ],
                    onChanged: (v) => setState(() {
                      row.itemId = v == '__new__' ? null : v;
                    }),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Satırı sil',
                  onPressed: () => setState(() {
                    row.dispose();
                    _rows.removeAt(index);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isNew) ...[
              ProductNameField(
                label: 'Yeni ürün adı',
                initialText: row.newName,
                onChanged: (text, match) => setState(() {
                  row.newName = text.trim();
                  if (match != null) {
                    row.newCategory = match.category;
                    row.newUnit = match.unit;
                  }
                }),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<GroceryCategory>(
                      initialValue: row.newCategory,
                      decoration: const InputDecoration(
                          labelText: 'Kategori',
                          border: OutlineInputBorder(),
                          isDense: true),
                      items: GroceryCategory.values
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.shortName,
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => row.newCategory = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<StockUnit>(
                      initialValue: row.newUnit,
                      decoration: const InputDecoration(
                          labelText: 'Birim',
                          border: OutlineInputBorder(),
                          isDense: true),
                      items: const [
                        DropdownMenuItem(
                            value: StockUnit.gram,
                            child: Text('Gram (g)')),
                        DropdownMenuItem(
                            value: StockUnit.piece, child: Text('Adet')),
                      ],
                      onChanged: (v) =>
                          setState(() => row.newUnit = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: row.amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: false),
              decoration: InputDecoration(
                labelText: 'Porsiyon başına miktar',
                suffixText: _suffixFor(store, row),
                border: const OutlineInputBorder(),
                isDense: true,
                errorText: row.amount > 0 ? null : '0’dan büyük olmalı',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  String _suffixFor(AppStore store, _IngEdit row) {
    if (row.itemId != null) {
      final item = store.itemById(row.itemId!);
      if (item != null) return item.unit.abbreviation;
    }
    return row.newUnit.abbreviation;
  }

  Future<void> _save() async {
    final store = context.read<AppStore>();
    final ingredients = <RecipeIngredient>[];
    for (final row in _rows) {
      String itemId;
      if (row.itemId != null && store.itemById(row.itemId!) != null) {
        itemId = row.itemId!;
      } else {
        final created = InventoryItem(
          name: row.newName.trim(),
          category: row.newCategory,
          unit: row.newUnit,
          currentStock: 0,
          warehouseStock: 0,
          minThreshold: 0,
        );
        await store.addInventoryItem(created);
        itemId = created.id;
      }
      ingredients.add(RecipeIngredient(
          itemId: itemId, amountPerServing: row.amount));
    }
    if (widget.existing == null) {
      await store.addRecipe(Recipe(
        name: _name.text.trim(),
        description: _desc.text.trim(),
        servingsDefault: _servings,
        ingredients: ingredients,
      ));
    } else {
      final e = widget.existing!;
      e.name = _name.text.trim();
      e.description = _desc.text.trim();
      e.servingsDefault = _servings;
      e.ingredients = ingredients;
      await store.updateRecipe(e);
    }
    if (mounted) Navigator.pop(context);
  }
}

class ProduceSheet extends StatefulWidget {
  final String recipeId;
  const ProduceSheet({super.key, required this.recipeId});

  @override
  State<ProduceSheet> createState() => _ProduceSheetState();
}

class _ProduceSheetState extends State<ProduceSheet> {
  static const int minServings = 1;
  static const int maxServings = 10000;

  late final TextEditingController _servingsCtrl;
  final Map<String, TextEditingController> _totalCtrls = {};
  final Map<String, double> _perServing = {};
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    final recipe = store.recipeById(widget.recipeId)!;
    _servingsCtrl =
        TextEditingController(text: '${recipe.servingsDefault}');
    for (final ing in recipe.ingredients) {
      _perServing[ing.itemId] = ing.amountPerServing;
      _totalCtrls[ing.itemId] = TextEditingController(
        text: _fmtTotal(store, ing.itemId,
            ing.amountPerServing * recipe.servingsDefault),
      );
    }
    _initialized = true;
  }

  @override
  void dispose() {
    _servingsCtrl.dispose();
    for (final c in _totalCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmtTotal(AppStore store, String itemId, double value) {
    final item = store.itemById(itemId);
    if (item == null) return value.toStringAsFixed(0);
    if (item.unit.name == 'piece') return value.toStringAsFixed(0);
    return value.toStringAsFixed(value >= 100 ? 0 : 1);
  }

  int get _servings => int.tryParse(_servingsCtrl.text) ?? 0;
  bool get _servingsValid =>
      _servings >= minServings && _servings <= maxServings;

  /// Recalculates every total from the recipe when portions change.
  void _applyServings(int value) {
    final v = value.clamp(minServings, maxServings);
    final store = context.read<AppStore>();
    setState(() {
      _servingsCtrl.text = '$v';
      _perServing.forEach((itemId, per) {
        _totalCtrls[itemId]?.text = _fmtTotal(store, itemId, per * v);
      });
    });
  }

  void _resetToRecipe() {
    if (_servingsValid) _applyServings(_servings);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const SizedBox.shrink();
    final store = context.watch<AppStore>();
    final recipe = store.recipeById(widget.recipeId)!;

    // Live totals + remaining stock from the editable fields.
    final totals = <String, double>{};
    for (final ing in recipe.ingredients) {
      final raw = _totalCtrls[ing.itemId]?.text.replaceAll(',', '.') ?? '';
      totals[ing.itemId] = double.tryParse(raw) ?? -1;
    }
    final totalsValid = totals.values.every((v) => v >= 0);
    final hasShortage = totals.entries.any((e) {
      final item = store.itemById(e.key);
      return item != null && e.value >= 0 && item.currentStock - e.value < 0;
    });

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(recipe.name,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            // ---- Manual servings entry (e.g. 200 people) ----
            TextField(
              controller: _servingsCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Kişi / porsiyon sayısı ($minServings-$maxServings)',
                prefixIcon: const Icon(Icons.groups),
                errorText: _servingsValid ? null : '1-10000 arası girin',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _resetToRecipe(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Azalt',
                  onPressed: _servingsValid && _servings > minServings
                      ? () => _applyServings(_servings - 1)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Artır',
                  onPressed: _servingsValid && _servings < maxServings
                      ? () => _applyServings(_servings + 1)
                      : null,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    children: [50, 100, 200, 500]
                        .map((v) => ActionChip(
                              label: Text('$v'),
                              onPressed: () => _applyServings(v),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                const Expanded(
                  child: Text('Kullanılan malzemeler (düzenlenebilir):',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  onPressed: _resetToRecipe,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Tarife sıfırla'),
                ),
              ],
            ),
            for (final ing in recipe.ingredients)
              _ingredientRow(context, store, ing.itemId, totals),
            if (hasShortage)
              const Card(
                color: Color(0xFFFFF3E0),
                child: ListTile(
                  leading: Icon(Icons.warning, color: Colors.orange),
                  title: Text(
                    'Bazı ürünler yetersiz — yine de üretilebilir, stok sıfıra sabitlenir.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Vazgeç'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _servingsValid && totalsValid
                        ? () {
                            store.produceCustom(
                              recipe: recipe,
                              servings: _servings,
                              totals: totals,
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        '${recipe.name} × $_servings üretildi, stok güncellendi.')),
                              );
                            }
                          }
                        : null,
                    child: const Text('Üretimi Onayla'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _ingredientRow(BuildContext context, AppStore store, String itemId,
      Map<String, double> totals) {
    final item = store.itemById(itemId);
    if (item == null) return const SizedBox.shrink();
    final total = totals[itemId] ?? 0;
    final remaining =
        total >= 0 ? (item.currentStock - total).clamp(0, double.infinity).toDouble() : 0.0;
    final per = _perServing[itemId] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  'Tarif: ${item.formatAmount(per)}/porsiyon • Stok: ${item.formattedStock()} • Kalan: ${item.formatAmount(remaining)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (total >= 0 && remaining <= 0 && total > 0)
                  const StatusBadge(text: 'Yetersiz', color: Colors.red),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _totalCtrls[itemId],
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: false),
              decoration: InputDecoration(
                labelText: 'Toplam',
                suffixText: item.unit.name == 'piece' ? 'adet' : 'g',
                isDense: true,
                border: const OutlineInputBorder(),
                errorText: total >= 0 ? null : '?',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }
}
