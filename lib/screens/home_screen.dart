import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import 'agenda_screen.dart';
import 'dashboard_screen.dart';
import 'disposal_screen.dart';
import 'inventory_screen.dart';
import 'production_table_screen.dart';
import 'profile_screen.dart';
import 'recipe_book_screen.dart';
import 'recipes_screen.dart';
import 'supplier_orders_screen.dart';

/// Scope to allow nested widgets (e.g., Dashboard cards) to switch navigation tabs easily.
class TabNavigationScope extends InheritedWidget {
  final Function(int) navigateTo;
  const TabNavigationScope({
    required this.navigateTo,
    required super.child,
    super.key,
  });

  static TabNavigationScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabNavigationScope>();

  @override
  bool updateShouldNotify(covariant TabNavigationScope oldWidget) => false;
}

class _NavItem {
  final String title;
  final String category;
  final IconData icon;
  final IconData activeIcon;
  final int Function(AppStore store)? badgeCount;

  const _NavItem({
    required this.title,
    required this.category,
    required this.icon,
    required this.activeIcon,
    this.badgeCount,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const List<Widget> _pages = [
    DashboardScreen(),
    InventoryScreen(),
    SupplierOrdersScreen(),
    RecipesScreen(),
    RecipeBookScreen(),
    ProductionTableScreen(),
    ProfileScreen(),
    DisposalScreen(),
    AgendaScreen(),
  ];

  static final List<_NavItem> _navItems = [
    _NavItem(
      title: 'Özet & Panel',
      category: 'GENEL',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      badgeCount: (s) => s.attentionOrders.length + s.lowStockItems.length,
    ),
    _NavItem(
      title: 'Stok Yönetimi',
      category: 'ENVANTER & TEDARİK',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
      badgeCount: (s) => s.lowStockItems.length,
    ),
    _NavItem(
      title: 'Siparişler',
      category: 'ENVANTER & TEDARİK',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      badgeCount: (s) => s.attentionOrders.length,
    ),
    const _NavItem(
      title: 'Tarifler',
      category: 'MUTFAK & PLANLAMA',
      icon: Icons.restaurant_menu_outlined,
      activeIcon: Icons.restaurant_menu_rounded,
    ),
    const _NavItem(
      title: 'Reçeteler (1 Porsiyon)',
      category: 'MUTFAK & PLANLAMA',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
    ),
    const _NavItem(
      title: 'Üretim Tablosu',
      category: 'MUTFAK & PLANLAMA',
      icon: Icons.table_chart_outlined,
      activeIcon: Icons.table_chart_rounded,
    ),
    const _NavItem(
      title: 'Profil',
      category: 'GENEL',
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
    ),
    _NavItem(
      title: 'İmha Tutanağı',
      category: 'ENVANTER & TEDARİK',
      icon: Icons.delete_outline,
      activeIcon: Icons.delete_rounded,
      badgeCount: (s) => s.disposalForms.length,
    ),
    _NavItem(
      title: 'Aylık Ajanda',
      category: 'GENEL',
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
      badgeCount: (s) => s.agendaForDay(DateTime.now()).length,
    ),
  ];

  void _onSelect(int index) {
    setState(() => _index = index);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 960;

    return TabNavigationScope(
      navigateTo: _onSelect,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: isDesktop ? null : _buildMobileDrawer(context),
        body: isDesktop ? _buildDesktopLayout(context) : _buildMobileLayout(context),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // Sidebar Navigation
        SizedBox(
          width: 270,
          child: _buildSidebar(context),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: AppColors.divider),
        // Main Content Area
        Expanded(
          child: IndexedStack(
            index: _index,
            children: _pages,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: _index,
            children: _pages,
          ),
        ),
        _buildBottomNav(context),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final store = context.watch<AppStore>();

    // Group items by category
    final categories = <String, List<_NavItem>>{};
    for (final item in _navItems) {
      categories.putIfAbsent(item.category, () => []).add(item);
    }

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Brand Logo & Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.spa_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Diyetisyen',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: AppColors.text,
                              ),
                            ),
                            Text(
                              'Mutfak & Klinik Asistanı',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fmtFullDay(DateTime.now()),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            // Nav Items List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                children: [
                  for (final entry in categories.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
                      child: Text(
                        entry.key,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    for (final item in entry.value)
                      _buildSidebarTile(item, store),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            // Sidebar Footer: User / Sync status
            _buildSidebarFooter(context, store),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarTile(_NavItem item, AppStore store) {
    final itemIndex = _navItems.indexOf(item);
    final isSelected = _index == itemIndex;
    final badge = item.badgeCount?.call(store) ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected ? AppColors.primaryMuted : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _onSelect(itemIndex),
          borderRadius: BorderRadius.circular(12),
          hoverColor: AppColors.surfaceVariant,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isSelected ? item.activeIcon : item.icon,
                  size: 20,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.primary : AppColors.text,
                    ),
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badge',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter(BuildContext context, AppStore store) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 17,
            backgroundColor: AppColors.primaryMuted,
            child: Icon(Icons.person, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  store.syncOn ? 'Bulut Bağlı' : 'Yerel Çalışma',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  store.syncOn ? 'Veriler eşitleniyor' : 'Cihazda kayıtlı',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (store.syncOn)
            IconButton(
              icon: const Icon(Icons.logout_rounded, size: 18),
              tooltip: 'Çıkış Yap',
              onPressed: () async {
                await context.read<AppStore>().disableSync();
                await FirebaseAuth.instance.signOut();
              },
            )
          else if (store.firebaseReady)
            IconButton(
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              tooltip: 'Giriş Yap / Eşitle',
              onPressed: () async {
                store.localOnly = false;
                await store.save();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final store = context.watch<AppStore>();
    final attention = store.attentionOrders.length + store.lowStockItems.length;

    // Mobile primary 5 destinations (4 main + 1 "More" menu)
    final mobileIndex = _index < 4 ? _index : 4;

    return NavigationBar(
      selectedIndex: mobileIndex,
      onDestinationSelected: (i) {
        if (i == 4) {
          _scaffoldKey.currentState?.openDrawer();
        } else {
          _onSelect(i);
        }
      },
      destinations: [
        NavigationDestination(
          icon: Badge(
            isLabelVisible: attention > 0,
            label: Text('$attention'),
            child: const Icon(Icons.grid_view_outlined),
          ),
          selectedIcon: const Icon(Icons.grid_view_rounded),
          label: 'Özet',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: store.lowStockItems.isNotEmpty,
            label: Text('${store.lowStockItems.length}'),
            child: const Icon(Icons.inventory_2_outlined),
          ),
          selectedIcon: const Icon(Icons.inventory_2_rounded),
          label: 'Stok',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: store.attentionOrders.isNotEmpty,
            label: Text('${store.attentionOrders.length}'),
            child: const Icon(Icons.receipt_long_outlined),
          ),
          selectedIcon: const Icon(Icons.receipt_long_rounded),
          label: 'Siparişler',
        ),
        const NavigationDestination(
          icon: Icon(Icons.restaurant_menu_outlined),
          selectedIcon: Icon(Icons.restaurant_menu_rounded),
          label: 'Tarifler',
        ),
        const NavigationDestination(
          icon: Icon(Icons.menu_rounded),
          label: 'Daha Fazla',
        ),
      ],
    );
  }

  Widget _buildMobileDrawer(BuildContext context) {
    return Drawer(
      child: _buildSidebar(context),
    );
  }
}
