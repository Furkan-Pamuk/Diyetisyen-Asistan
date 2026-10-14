import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/grocery_category.dart';
import '../models/menu_entry.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diyetisyen Asistanı'),
        actions: [
          if (store.syncOn)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Tooltip(
                message: 'Bulut eşitlemesi açık — her cihazda aynı veri',
                child: Icon(Icons.cloud_done, color: Colors.green),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Tooltip(
                message: 'Yerel mod (eşitleme kapalı)',
                child: Icon(Icons.cloud_off, color: Colors.grey),
              ),
            ),
          if (store.syncOn)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Çıkış yap',
              onPressed: () async {
                await context.read<AppStore>().disableSync();
                await FirebaseAuth.instance.signOut();
              },
            ),
          if (store.firebaseReady && store.localOnly && !store.syncOn)
            IconButton(
              icon: const Icon(Icons.login),
              tooltip: 'Hesapla giriş yap',
              onPressed: () async {
                store.localOnly = false;
                await store.save();
              },
            ),
        ],
      ),
      body: ListView(
        children: [
          _sectionTitle(context, 'Dikkat Gerekenler'),
          if (store.attentionOrders.isEmpty && store.lowStockItems.isEmpty)
            const ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('Her şey yolunda'),
            ),
          for (final o in store.attentionOrders)
            ListTile(
              title: Text(o.title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CountdownText(days: o.orderCountdown, prefix: 'Sipariş:'),
                  CountdownText(days: o.pickupCountdown, prefix: 'Teslim:'),
                ],
              ),
            ),
          _sectionTitle(
              context, 'Kritik Stok (${store.lowStockItems.length})'),
          for (final item in store.lowStockItems.take(5))
            ListTile(
              title: Text(item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Kalan: ${item.formattedStock()}'),
              trailing: StatusBadge(
                text: item.isOutOfStock ? 'Tükendi' : 'Kritik',
                color: Colors.red,
              ),
            ),
          _sectionTitle(context, 'Bugünkü Menü (${MenuEntry.days[DateTime.now().weekday - 1]})'),
          Builder(builder: (ctx) {
            final now = DateTime.now();
            final wom = ((now.day - 1) ~/ 7).clamp(0, 3);
            final today = store.menuForDay(now.weekday - 1, wom);
            if (today.isEmpty) {
              return const ListTile(
                  title: Text('Bugün için menü yok. Menü sekmesinden ekleyin.'));
            }
            return Column(
              children: [
                for (final e in today)
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.green.shade50,
                      child: Text(e.meal.characters.first,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(
                        store.recipeById(e.recipeId)?.name ?? 'Silinmiş tarif',
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text('${e.servings} pors.',
                        style: Theme.of(ctx).textTheme.bodySmall),
                  ),
              ],
            );
          }),
          _sectionTitle(context, 'Haftalık Alışveriş'),          if (store.groceryItems.isEmpty)
            const ListTile(title: Text('Liste henüz oluşturulmadı.'))
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: store.groceryProgress),
                  const SizedBox(height: 4),
                  Text(
                    '${store.groceryItems.where((e) => e.isPurchased).length}/${store.groceryItems.length} alındı',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  for (final c in GroceryCategory.values)
                    if (store.groceryItems
                        .where((e) => e.category == c && !e.isPurchased)
                        .isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(c.icon, size: 16, color: c.tint),
                            const SizedBox(width: 6),
                            Text(
                              '${c.shortName}: ${store.groceryItems.where((e) => e.category == c && !e.isPurchased).length} kalem',
                              style: TextStyle(color: c.tint),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          _sectionTitle(context, 'Son Üretimler'),
          for (final log in store.productionLogs.take(3))
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

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Colors.grey.shade700)),
    );
  }
}
