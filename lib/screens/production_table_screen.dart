import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/grocery_category.dart';
import '../models/recipe.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';

/// Production table: left = dish name, middle = recipe (ingredients + amounts per serving),
/// right = number of people / servings. On confirm, stock is deducted automatically.
class ProductionTableScreen extends StatefulWidget {
  const ProductionTableScreen({super.key});

  @override
  State<ProductionTableScreen> createState() => _ProductionTableScreenState();
}

class _RowItem {
  Recipe recipe;
  int servings;
  _RowItem({required this.recipe, required this.servings});
}

class _ProductionTableScreenState extends State<ProductionTableScreen> {
  final List<_RowItem> _items = [];

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    if (store.recipes.isNotEmpty) {
      _items.add(_RowItem(
        recipe: store.recipes.first,
        servings: store.recipes.first.servingsDefault,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final hasShortageOverall = _items.any((i) {
      final preview = store.previewProduction(i.recipe, i.servings);
      return preview.any((r) => r.remaining < 0);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Üretim Planı / Reçete Tablosu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_chart),
            tooltip: 'Satır ekle',
            onPressed: () => _addRow(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _items.isEmpty ? null : () => _runProduction(context),
        icon: const Icon(Icons.checklist_rtl),
        label: const Text('Stoktan Düş'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: 3 columns
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text('Yemek',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('Reçete (malzeme / porsiyon)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: Text('Kişi',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.list_alt,
                              size: 48, color: Color(0xFF6C7280)),
                          const SizedBox(height: 12),
                          const Text('Henüz üretim satırı yok'),
                          TextButton(
                            onPressed: () => _addRow(context),
                            child: const Text('Satır Ekle'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) => _RowCard(
                        item: _items[i],
                        index: i,
                        onRemove: () => setState(() => _items.removeAt(i)),
                        onServingsChanged: (newVal) => setState(
                            () => _items[i].servings = newVal),
                      ),
                    ),
            ),
            if (hasShortageOverall)
              Card(
                color: const Color(0xFFFFF3E0),
                child: ListTile(
                  leading: const Icon(Icons.warning, color: Colors.orange),
                  title: const Text(
                      'Bazı satırlarda ürün yetersiz — üretim yine yapılır, stok sıfıra sabitlenir.'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _addRow(BuildContext context) async {
    final store = context.read<AppStore>();
    final picked = await showDialog<Recipe>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Yemek Seç'),
        children: store.recipes.map((r) => SimpleDialogOption(
          child: Text(r.name),
          onPressed: () => Navigator.pop(ctx, r),
        )).toList(),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _items.add(_RowItem(
            recipe: picked,
            servings: picked.servingsDefault,
          )));
    }
  }

  void _runProduction(BuildContext context) {
    final store = context.read<AppStore>();
    for (final item in _items) {
      final preview = store.previewProduction(item.recipe, item.servings);
      final totals = <String, double>{};
      for (final row in preview) {
        totals[row.item.id] = row.needed;
      }
      store.produceCustom(
        recipe: item.recipe,
        servings: item.servings,
        totals: totals,
      );
    }
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Üretim tamamlandı: ${_items.map((i) => i.recipe.name).join(', ')}')),
      );
    }
  }
}

class _RowCard extends StatelessWidget {
  final _RowItem item;
  final int index;
  final VoidCallback onRemove;
  final ValueChanged<int> onServingsChanged;

  const _RowCard({
    required this.item,
    required this.index,
    required this.onRemove,
    required this.onServingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<AppStore>(context);
    final preview = store.previewProduction(item.recipe, item.servings);
    final hasShortage = preview.any((r) => r.remaining < 0);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    item.recipe.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          size: 20),
                      tooltip: 'Servisi azalt',
                      onPressed: item.servings > 1
                          ? () => onServingsChanged(item.servings - 1)
                          : null,
                    ),
                    Text('${item.servings}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          size: 20),
                      tooltip: 'Servisi artır',
                      onPressed: () =>
                          onServingsChanged(item.servings + 1),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 22),
                  tooltip: 'Satırı sil',
                  onPressed: onRemove,
                ),
              ],
            ),
            const Divider(),
            // Recipe column: ingredients with amounts per serving
            ...preview.map((pr) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    '• ${pr.item.name} (${pr.item.unit.abbreviation}): ${pr.needed.toStringAsFixed(pr.item.unit == StockUnit.gram ? 0 : 0)} / porsiyon',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )),
            const SizedBox(height: 4),
            // Total column + shortage warning
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Toplam ihtiyaç: ${preview.map((r) => '${r.item.name}: ${r.needed.toStringAsFixed(r.item.unit == StockUnit.gram ? 0 : 0)} ${r.item.unit.abbreviation}').join(' • ')}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (hasShortage)
              const StatusBadge(
                  text: 'Stok yetersiz — düşülürse sıfıra sabitlenir',
                  color: Colors.orange),
          ],
        ),
      ),
    );
  }
}
