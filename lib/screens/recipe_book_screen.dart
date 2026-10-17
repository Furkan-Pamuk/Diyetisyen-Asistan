import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/grocery_category.dart';
import '../models/inventory_item.dart';
import '../models/recipe.dart';
import '../state/app_store.dart';
import '../widgets/product_name_field.dart';

/// Reçeteler — üretim tablosundaki yemeklerin 1 porsiyon (kişi başı)
/// reçete kartları. Bu sayfada kişi sayısı girişi YOK, her miktar
/// "1 porsiyon için" sabittir. Yeni yemek + malzeme + miktar elle girilebilir.
class RecipeBookScreen extends StatefulWidget {
  const RecipeBookScreen({super.key});

  @override
  State<RecipeBookScreen> createState() => _RecipeBookScreenState();
}

class _RecipeBookScreenState extends State<RecipeBookScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final q = _search.trim().toLowerCase();
    final recipes = List.of(q.isEmpty
        ? store.recipes
        : store.recipes.where((r) => r.name.toLowerCase().contains(q)))
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reçeteler (1 Porsiyon)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Yeni reçete',
            onPressed: () => _openForm(context, null),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SearchBar(
              hintText: 'Reçete ara (örn. menemen)',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Reçete Ekle'),
      ),
      body: recipes.isEmpty
          ? const Center(child: Text('Eşleşen reçete yok'))
          : ListView.builder(
              itemCount: recipes.length,
              itemBuilder: (ctx, i) {
                final r = recipes[i];
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('1 porsiyon',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              tooltip: 'Düzenle',
                              onPressed: () => _openForm(context, r),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.delete_outline, size: 20),
                              tooltip: 'Sil',
                              onPressed: () =>
                                  _confirmDelete(context, r),
                            ),
                          ],
                        ),
                        if (r.description.isNotEmpty)
                          Text(r.description,
                              style: Theme.of(context).textTheme.bodySmall),
                        const Divider(height: 16),
                        ...r.ingredients.map((ing) {
                          final item = store.itemById(ing.itemId);
                          final name = item?.name ?? 'Silinmiş ürün';
                          final unit = item?.unit.abbreviation ?? '';
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.restaurant,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 6),
                                Expanded(child: Text(name)),
                                Text(
                                  '${ing.amountPerServing.toStringAsFixed(ing.amountPerServing >= 100 ? 0 : 1)} $unit / kişi',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _openForm(BuildContext context, Recipe? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RecipeBookFormSheet(existing: existing),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Recipe recipe) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${recipe.name}" silinsin mi?'),
        content: const Text(
            'Reçete menü, plan ve üretim tablosundan da çıkarılır. Stok etkilenmez.'),
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

class _IngEdit {
  String? itemId;
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

/// Reçete ekleme/düzenleme — porsiyon SABİT 1, kişi sayısı girişi yok.
class _RecipeBookFormSheetState extends State<_RecipeBookFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _desc;
  final List<_IngEdit> _rows = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _desc = TextEditingController(text: e?.description ?? '');
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
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  bool _rowValid(AppStore store, _IngEdit row) {
    if (row.amount <= 0) return false;
    if (row.itemId != null) {
      return store.itemById(row.itemId!) != null;
    }
    return row.newName.trim().isNotEmpty;
  }

  bool _valid(AppStore store) {
    return _name.text.trim().isNotEmpty &&
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
            Text(
                widget.existing == null ? 'Yeni Reçete' : 'Reçeteyi Düzenle',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Tüm miktarlar 1 porsiyon (kişi başı) içindir.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Yemek adı (örn. Menemen)',
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('Malzemeler — 1 porsiyon (${_rows.length})',
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _rows.add(_IngEdit(
                      itemId: _defaultItemId(store), amount: 0))),
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
    final isNew =
        row.itemId == null || store.itemById(row.itemId!) == null;
    if (row.itemId != null && store.itemById(row.itemId!) == null) {
      row.itemId = null;
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
                labelText: '1 porsiyon için miktar',
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
        servingsDefault: 1,
        ingredients: ingredients,
      ));
    } else {
      final e = widget.existing!;
      e.name = _name.text.trim();
      e.description = _desc.text.trim();
      // Reçete tanımı gereği porsiyon bazı değişmez; üretim
      // sırasındaki kişi sayısı üretim tablosundan verilir.
      e.ingredients = ingredients;
      await store.updateRecipe(e);
    }
    if (mounted) Navigator.pop(context);
  }
}

class _RecipeBookFormSheet extends StatefulWidget {
  final Recipe? existing;
  const _RecipeBookFormSheet({required this.existing});

  @override
  State<_RecipeBookFormSheet> createState() => _RecipeBookFormSheetState();
}
