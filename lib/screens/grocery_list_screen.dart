import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../models/grocery_category.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';
import 'menu_screen.dart';

class GroceryListScreen extends StatelessWidget {
  const GroceryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final grouped = store.groceryGrouped();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alışveriş Listesi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Paylaş',
            onPressed: store.groceryItems.isEmpty
                ? null
                : () => _share(context),
          ),
        ],
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
                    onPressed: () =>
                        context.read<AppStore>().generateGroceryList(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Listeyi Oluştur / Yenile'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MenuScreen()),
                    ),
                    icon: const Icon(Icons.calendar_month),
                    label: Text(store.groceryUsesMenu
                        ? 'Menü Programı (${store.weeklyMenu.length} öğün)'
                        : 'Menü Programı (boş — plan kullanılıyor)'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    store.groceryUsesMenu
                        ? 'Liste menü programından hesaplanır.'
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
                  CheckboxListTile(
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

class WeeklyPlanSheet extends StatelessWidget {
  const WeeklyPlanSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Haftalık Plan',
              style: Theme.of(context).textTheme.titleLarge),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: store.recipes.length,
              itemBuilder: (ctx, i) {
                final r = store.recipes[i];
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
