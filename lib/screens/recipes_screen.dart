import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/recipe.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';

class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Üretim')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Tarifler',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Colors.grey.shade700)),
          ),
          for (final r in store.recipes)
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
    final remaining = total >= 0
        ? (item.currentStock - total).clamp(0, double.infinity).toDouble()
        : 0.0;
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
