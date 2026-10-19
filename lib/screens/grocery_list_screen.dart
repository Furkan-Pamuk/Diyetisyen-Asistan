import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/suggestions.dart';
import '../main.dart';
import '../models/grocery_category.dart';
import '../models/inventory_item.dart';
import '../models/recipe.dart';
import '../services/pdf_service.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';
import '../widgets/product_name_field.dart';
import 'production_table_screen.dart';

class GroceryListScreen extends StatefulWidget {
  const GroceryListScreen({super.key});

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  bool _generating = false;

  Future<void> _generate(BuildContext context) async {
    if (_generating) return; // çift dokunuş koruması
    setState(() => _generating = true);
    try {
      await context.read<AppStore>().generateGroceryList();
      if (context.mounted) {
        final n = context.read<AppStore>().groceryItems.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Liste güncellendi ($n kalem).')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Liste oluşturulamadı: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final grouped = store.groceryGrouped();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alışveriş Listesi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'PDF olarak kaydet/paylaş',
            onPressed: store.groceryItems.isEmpty
                ? null
                : () => _sharePdf(context),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Paylaş',
            onPressed: store.groceryItems.isEmpty
                ? null
                : () => _share(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAdd(context),
        icon: const Icon(Icons.add),
        label: const Text('Ürün Ekle'),
      ),
      body: ListView(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title:
                        Text('Hafta Başı: ${fmtDay(store.weekStart)}'),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: store.weekStart,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null && context.mounted) {
                        store.weekStart = picked;
                        store.save();
                      }
                    },
                  ),
                  FilledButton.icon(
                    onPressed: _generating
                        ? null
                        : () => _generate(context),
                    icon: _generating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    label: Text(_generating
                        ? 'Oluşturuluyor…'
                        : 'Listeyi Oluştur / Yenile'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const ProductionTableScreen()),
                    ),
                    icon: const Icon(Icons.table_chart),
                    label: Text(store.groceryUsesMenu
                        ? 'Üretim Tablosu (${store.weeklyMenu.length} öğün)'
                        : 'Üretim Tablosu (menü boş — plan kullanılıyor)'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    store.groceryUsesMenu
                        ? 'Liste menüden hesaplanır (${store.weeklyMenu.map((e) => e.weekIndex).toSet().length} hafta, ${store.weeklyMenu.length} öğün).'
                        : 'Menü boşken liste haftalık plandan hesaplanır.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _openPlan(context),
                    child: const Text('Haftalık Planı Düzenle'),
                  ),
                ],
              ),
            ),
          ),
          if (store.groceryItems.isEmpty)
            const EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Liste boş',
              subtitle:
                  'Stok yeterli ya da plan boş. Plan ekleyip listeyi oluşturun.',
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                      value: store.groceryProgress),
                  const SizedBox(height: 4),
                  Text(
                    '${store.groceryItems.where((e) => e.isPurchased).length}/${store.groceryItems.length} tamamlandı',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            for (final cat in GroceryCategory.values)
              if (grouped[cat]!.isNotEmpty) ...[
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(
                    children: [
                      Icon(cat.icon, size: 18, color: cat.tint),
                      const SizedBox(width: 6),
                      Text(
                        '${cat.displayName} — ${grouped[cat]!.length}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cat.tint),
                      ),
                    ],
                  ),
                ),
                for (final item in grouped[cat]!)
                  Dismissible(
                    key: ValueKey(item.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child:
                          const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => context
                        .read<AppStore>()
                        .deleteGroceryItem(item.id),
                    child: CheckboxListTile(
                      value: item.isPurchased,
                      activeColor: Colors.green,
                      onChanged: (_) => context
                          .read<AppStore>()
                          .togglePurchased(item),
                      title: Text(item.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: item.isPurchased
                                ? TextDecoration.lineThrough
                                : null,
                          )),
                      subtitle: Text(
                        item.isGram
                            ? 'Stok: ${item.currentStockAtGeneration.toStringAsFixed(0)} g vardı'
                            : 'Stok: ${item.currentStockAtGeneration.toStringAsFixed(0)} adet vardı',
                      ),
                      secondary: Text(
                        item.formattedRequired(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cat.tint,
                          decoration: item.isPurchased
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
          ],
        ],
      ),
    );
  }

  void _openPlan(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const WeeklyPlanSheet(),
    );
  }

  Future<void> _sharePdf(BuildContext context) async {
    final store = context.read<AppStore>();
    final groups = <String, List<Map<String, String>>>{};
    for (final cat in GroceryCategory.values) {
      final items =
          store.groceryItems.where((e) => e.category == cat).toList();
      if (items.isEmpty) continue;
      groups[cat.displayName] = items
          .map((e) => {
                'name':
                    '${e.name}${e.isPurchased ? " (alindi)" : ""}',
                'qty': e.formattedRequired(),
              })
          .toList();
    }
    try {
      await PdfService.shareGroceryPdf(
        weekLabel: 'Hafta: ${fmtDay(store.weekStart)}',
        groups: groups,
        filename: 'alisveris-listesi.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF oluşturulamadı: $e')),
        );
      }
    }
  }

  void _openAdd(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddGroceryItemSheet(),
    );
  }

  void _share(BuildContext context) {
    final store = context.read<AppStore>();
    final buf = StringBuffer(
        'Haftalık Alışveriş — ${fmtDay(store.weekStart)}\n\n');
    for (final cat in GroceryCategory.values) {
      final items =
          store.groceryItems.where((e) => e.category == cat).toList();
      if (items.isEmpty) continue;
      buf.writeln('== ${cat.displayName} ==');
      for (final i in items) {
        buf.writeln(
            '• ${i.name}: ${i.formattedRequired()}${i.isPurchased ? " ✓" : ""}');
      }
      buf.writeln();
    }
    Share.share(buf.toString(), subject: 'Haftalık Alışveriş Listesi');
  }
}

class WeeklyPlanSheet extends StatefulWidget {
  const WeeklyPlanSheet({super.key});

  @override
  State<WeeklyPlanSheet> createState() => _WeeklyPlanSheetState();
}

class _WeeklyPlanSheetState extends State<WeeklyPlanSheet> {
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Haftalık Plan',
              style: Theme.of(context).textTheme.titleLarge),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Tarif ara',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: recipes.length,
              itemBuilder: (ctx, i) {
                final r = recipes[i];
                final servings = store.servingsFor(r.id);
                return ListTile(
                  title: Text(r.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(servings == 0
                      ? 'planda yok'
                      : '$servings porsiyon planlı'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: servings > 0
                            ? () => context
                                .read<AppStore>()
                                .setServings(r.id, servings - 2)
                            : null,
                      ),
                      Text('$servings pors.'),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => context
                            .read<AppStore>()
                            .setServings(r.id, servings + 2),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          FilledButton(
            onPressed: () {
              context.read<AppStore>().generateGroceryList();
              Navigator.pop(context);
            },
            child: const Text('Bitti — Listeyi Yenile'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Manual product entry with live suggestions.
/// Typing "m" suggests Mandalina, Muz, ...; picking one auto-fills
/// category and unit.
class AddGroceryItemSheet extends StatefulWidget {
  const AddGroceryItemSheet({super.key});

  @override
  State<AddGroceryItemSheet> createState() => _AddGroceryItemSheetState();
}

class _AddGroceryItemSheetState extends State<AddGroceryItemSheet> {
  String _name = '';
  GroceryCategory _category = GroceryCategory.freshProduce;
  StockUnit _unit = StockUnit.gram;
  final _amountCtrl = TextEditingController();

  double get _amount =>
      double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;

  void _onNameChanged(String text, SuggestedProduct? match) {
    setState(() {
      _name = text.trim();
      if (match != null) {
        _category = match.category;
        _unit = match.unit;
      }
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _name.isNotEmpty && _amount > 0;
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
            Text('Listeye Ürün Ekle',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ProductNameField(onChanged: _onNameChanged),
            const SizedBox(height: 12),
            DropdownButtonFormField<GroceryCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                  isDense: true),
              items: GroceryCategory.values
                  .map((c) => DropdownMenuItem(
                      value: c, child: Text(c.displayName)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            SegmentedButton<StockUnit>(
              segments: const [
                ButtonSegment(value: StockUnit.gram, label: Text('Gram (g)')),
                ButtonSegment(value: StockUnit.piece, label: Text('Adet')),
              ],
              selected: {_unit},
              onSelectionChanged: (s) => setState(() => _unit = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: false),
              decoration: InputDecoration(
                labelText: _unit == StockUnit.gram
                    ? 'Miktar (g)'
                    : 'Miktar (adet)',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
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
                    onPressed: valid
                        ? () {
                            final store = context.read<AppStore>();
                            InventoryItem? match;
                            try {
                              match = store.inventory.firstWhere(
                                  (e) =>
                                      e.name.toLowerCase() ==
                                      _name.toLowerCase());
                            } catch (_) {}
                            store.addGroceryItem(GroceryItem(
                              name: _name,
                              category: _category,
                              unitKey: _unit.key,
                              requiredAmount: _amount,
                              currentStockAtGeneration:
                                  match?.currentStock ?? 0,
                              weekStart: store.weekStart,
                            ));
                            Navigator.pop(context);
                          }
                        : null,
                    child: const Text('Ekle'),
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
}
