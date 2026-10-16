import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_store.dart';
import 'dashboard_screen.dart';
import 'supplier_orders_screen.dart';
import 'inventory_screen.dart';
import 'production_table_screen.dart';
import 'menu_screen.dart';
import 'recipes_screen.dart';
import 'grocery_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _pages = [
    DashboardScreen(),
    SupplierOrdersScreen(),
    InventoryScreen(),
    RecipesScreen(),
    MenuScreen(),
    GroceryListScreen(),
    ProductionTableScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final attention = store.attentionOrders.length + store.lowStockItems.length;
    final pending =
        store.groceryItems.where((e) => !e.isPurchased).length;

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: attention > 0,
              label: Text('$attention'),
              child: const Icon(Icons.home),
            ),
            label: 'Özet',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: store.attentionOrders.isNotEmpty,
              label: Text('${store.attentionOrders.length}'),
              child: const Icon(Icons.local_shipping),
            ),
            label: 'Tedarikçi',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: store.lowStockItems.isNotEmpty,
              label: Text('${store.lowStockItems.length}'),
              child: const Icon(Icons.inventory_2),
            ),
            label: 'Stok',
          ),
          const NavigationDestination(
            icon: Icon(Icons.restaurant),
            label: 'Üretim',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: store.weeklyMenu.isNotEmpty,
              label: Text('${store.weeklyMenu.length}'),
              child: const Icon(Icons.calendar_month),
            ),
            label: 'Menü',
          ),
          NavigationDestination(
            icon: const Icon(Icons.table_chart),
            label: 'Üretim Tablosu',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'Alışveriş',
          ),
        ],
      ),
    );
  }
}
