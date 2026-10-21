import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/menu_entry.dart';
import '../models/supplier_order.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/motivation_card.dart';
import '../widgets/notes_card.dart';
import '../widgets/order_qty_sheet.dart';
import 'home_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 960;

    final now = DateTime.now();
    final wom = ((now.day - 1) ~/ 7).clamp(0, 3);
    final todayMenu = store.menuForDay(now.weekday - 1, wom);
    final totalServings = todayMenu.fold<int>(0, (sum, e) => sum + e.servings);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Genel Bakış'),
        actions: [
          _buildSyncIcon(context, store),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 16,
          vertical: 24,
        ),
        children: [
          // Welcome Banner
          _buildHeroBanner(context, store),
          const SizedBox(height: 24),

          // 3 Key Metric Cards
          _buildKpiGrid(context, store, todayMenu.length, totalServings, width),
          const SizedBox(height: 20),

          // Motivasyon kutusu (10 sn'de bir patenci kız kayar)
          const MotivationCard(),
          const SizedBox(height: 24),

          // Günün ajandası: menü + sipariş/teslim + hatırlatıcı + kritik stok
          _buildAgendaCard(context, store, todayMenu, now),
          const SizedBox(height: 24),

          // Main Content Area
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      _buildOrdersCard(context, store),
                      const SizedBox(height: 20),
                      _buildLowStockCard(context, store),
                      const SizedBox(height: 20),
                      _buildProductionCard(context, store),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      _buildTodayMenuCard(context, store, todayMenu, now),
                      const SizedBox(height: 20),
                      const NotesCard(),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            _buildOrdersCard(context, store),
            const SizedBox(height: 16),
            _buildLowStockCard(context, store),
            const SizedBox(height: 16),
            _buildTodayMenuCard(context, store, todayMenu, now),
            const SizedBox(height: 16),
            _buildProductionCard(context, store),
            const SizedBox(height: 16),
            const NotesCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncIcon(BuildContext context, AppStore store) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (store.syncOn) ...[
          const Tooltip(
            message: 'Bulut eşitlemesi açık',
            child: Icon(Icons.cloud_done_rounded, color: AppColors.success, size: 20),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Çıkış yap',
            onPressed: () async {
              await context.read<AppStore>().disableSync();
              await FirebaseAuth.instance.signOut();
            },
          ),
        ] else ...[
          const Tooltip(
            message: 'Yerel modda çalışıyorsunuz',
            child: Icon(Icons.cloud_off_rounded, color: AppColors.muted, size: 20),
          ),
          if (store.firebaseReady && store.localOnly)
            IconButton(
              icon: const Icon(Icons.login_rounded),
              tooltip: 'Giriş yap',
              onPressed: () async {
                store.localOnly = false;
                await store.save();
              },
            ),
        ],
      ],
    );
  }

  Widget _buildHeroBanner(BuildContext context, AppStore store) {
    final first = store.greetingName;
    final hasPhoto = store.profilePhotoBase64.isNotEmpty;
    ImageProvider? photo;
    if (hasPhoto) {
      try {
        photo = MemoryImage(
            const Base64Decoder().convert(store.profilePhotoBase64));
      } catch (_) {
        photo = null;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F5132), Color(0xFF13653F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F5132).withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        store.profileTitle.trim().isEmpty
                            ? 'KLİNİK & MUTFAK YÖNETİMİ'
                            : store.profileTitle
                                .trim()
                                .toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  first.isEmpty
                      ? 'Hoş Geldiniz 👋'
                      : 'Hoşgeldiniz, $first',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bugünkü üretim hedefleri, tedarikçi bildirimleri ve kritik stok durumunuz aşağıda özetlenmiştir.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor:
                  Colors.white.withValues(alpha: 0.15),
              backgroundImage: photo,
              child: photo == null
                  ? const Icon(Icons.eco_rounded,
                      size: 32, color: Colors.white)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(
    BuildContext context,
    AppStore store,
    int todayMealsCount,
    int totalServings,
    double screenWidth,
  ) {
    final nav = TabNavigationScope.of(context);
    final isDesktop = screenWidth >= 960;

    final cards = [
      StatCard(
        title: 'Stok Uyarıları',
        value:
            '${store.criticalStockItems.length}🔴 ${store.warningStockItems.length}🟡',
        subtitle: (store.criticalStockItems.isEmpty &&
                store.warningStockItems.isEmpty)
            ? 'Tüm seviyeler uygun'
            : 'Kritik/azalan ürünleri kontrol edin',
        icon: Icons.warning_amber_rounded,
        color: store.criticalStockItems.isNotEmpty
            ? AppColors.error
            : store.warningStockItems.isNotEmpty
                ? Colors.orange
                : AppColors.success,
        onTap: () => nav?.navigateTo(1), // Stok
      ),
      StatCard(
        title: 'Bekleyen Sipariş',
        value: '${store.attentionOrders.length}',
        subtitle: store.attentionOrders.isEmpty ? 'Gecikme yok' : 'Teslimat/sipariş tarihi yakın',
        icon: Icons.receipt_long_rounded,
        color: store.attentionOrders.isEmpty ? AppColors.muted : AppColors.warning,
        onTap: () => nav?.navigateTo(2), // Siparişler
      ),
      StatCard(
        title: 'Bugünkü Menü',
        value: '$todayMealsCount Öğün',
        subtitle: totalServings > 0 ? '$totalServings toplam porsiyon' : 'Menü girişi yok',
        icon: Icons.restaurant_rounded,
        color: AppColors.primary,
        onTap: () => nav?.navigateTo(5), // Üretim Tablosu
      ),
    ];

    if (isDesktop) {
      return Row(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            Expanded(child: cards[i]),
            if (i < cards.length - 1) const SizedBox(width: 16),
          ],
        ],
      );
    } else {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: screenWidth > 500 ? 2 : 1,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: screenWidth > 500 ? 1.6 : 2.2,
        children: cards,
      );
    }
  }

  Widget _buildOrdersCard(BuildContext context, AppStore store) {
    final nav = TabNavigationScope.of(context);

    return _ModernContainer(
      title: 'Dikkat Gereken Siparişler',
      actionText: 'Tümünü Gör',
      onAction: () => nav?.navigateTo(2),
      child: store.attentionOrders.isEmpty
          ? const _CleanEmptyRow(
              icon: Icons.check_circle_rounded,
              title: 'Harika! İşlem bekleyen sipariş bulunmuyor.',
            )
          : Column(
              children: [
                for (final o in store.attentionOrders.take(3))
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt_long_rounded,
                              size: 18, color: AppColors.warning),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                o.title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (o.orderCountdown != 0)
                                    CountdownText(
                                        days: o.orderCountdown,
                                        prefix: 'Sipariş:'),
                                  CountdownText(
                                      days: o.pickupCountdown,
                                      prefix: 'Teslim:'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  /// Günün ajandası: bugünkü menü, sipariş/teslim günleri,
  /// hatırlatıcılı notlar ve kritik stok özeti tek listede.
  Widget _buildAgendaCard(BuildContext context, AppStore store,
      List<MenuEntry> todayMenu, DateTime now) {
    final nav = TabNavigationScope.of(context);
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    String hm(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    final rows = <_AgendaRow>[];
    for (final e in todayMenu) {
      final r = store.recipeById(e.recipeId);
      rows.add(_AgendaRow(
        icon: Icons.restaurant_rounded,
        color: AppColors.primary,
        title: '${e.meal} • ${r?.name ?? 'Silinmiş tarif'}',
        subtitle: '${e.servings} kişi',
        tab: 5, // Üretim Tablosu
      ));
    }
    for (final o in store.supplierOrders) {
      if (!o.status.isActive) continue;
      if (sameDay(o.orderDate, now)) {
        rows.add(_AgendaRow(
          icon: Icons.shopping_cart_checkout_rounded,
          color: AppColors.info,
          title: 'Sipariş günü: ${o.title}',
          subtitle: store.supplierNameOf(o),
          tab: 2,
        ));
      } else if (o.orderCountdown < 0) {
        rows.add(_AgendaRow(
          icon: Icons.warning_amber_rounded,
          color: AppColors.error,
          title: 'Geciken sipariş: ${o.title}',
          subtitle: '${-o.orderCountdown} gün gecikti',
          tab: 2,
        ));
      }
      if (o.status == SupplierOrderStatus.ordered ||
          o.status == SupplierOrderStatus.ready) {
        if (sameDay(o.pickupDate, now)) {
          rows.add(_AgendaRow(
            icon: Icons.receipt_long_rounded,
            color: AppColors.warning,
            title: 'Teslim alma: ${o.title}',
            subtitle: store.supplierNameOf(o),
            tab: 2,
          ));
        } else if (o.pickupCountdown < 0) {
          rows.add(_AgendaRow(
            icon: Icons.warning_amber_rounded,
            color: AppColors.error,
            title: 'Geciken teslim: ${o.title}',
            subtitle: '${-o.pickupCountdown} gün gecikti',
            tab: 2,
          ));
        }
      }
    }
    for (final n in store.notes) {
      final at = n.reminderAt;
      if (at == null) continue;
      if (sameDay(at, now) || at.isBefore(now)) {
        rows.add(_AgendaRow(
          icon: Icons.alarm_on_rounded,
          color: const Color(0xFFD6336C),
          title: n.text.isEmpty ? '(boş not)' : n.text,
          subtitle: 'Hatırlatıcı: ${hm(at)}',
          tab: -1,
        ));
      }
    }
    for (final a in store.agendaForDay(now)) {
      rows.add(_AgendaRow(
        icon: Icons.event_note_rounded,
        color: AppColors.info,
        title: a.text,
        subtitle: 'Ajanda notu',
        tab: 8, // Aylık Ajanda
      ));
    }
    if (store.criticalStockItems.isNotEmpty) {
      rows.add(_AgendaRow(
        icon: Icons.inventory_2_rounded,
        color: AppColors.error,
        title:
            '${store.criticalStockItems.length} üründe kritik stok',
        subtitle: store.criticalStockItems
            .take(3)
            .map((e) => e.name)
            .join(', '),
        tab: 1,
      ));
    }

    return _ModernContainer(
      title: 'Günün Ajandası • ${fmtDay(now)} (${rows.length})',
      child: rows.isEmpty
          ? const _CleanEmptyRow(
              icon: Icons.event_available_rounded,
              title: 'Bugün planlı iş yok.',
            )
          : Column(
              children: [
                for (final r in rows)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.cardBorder),
                    ),
                    child: InkWell(
                      onTap: r.tab < 0
                          ? null
                          : () => nav?.navigateTo(r.tab),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: r.color
                                  .withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Icon(r.icon,
                                size: 18, color: r.color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.title,
                                  style:
                                      GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppColors.text,
                                  ),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  r.subtitle,
                                  style:
                                      GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    color: AppColors.muted,
                                  ),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (r.tab >= 0)
                            const Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: AppColors.muted),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildLowStockCard(BuildContext context, AppStore store) {    final nav = TabNavigationScope.of(context);
    final critical = store.criticalStockItems;
    final warning = store.warningStockItems;

    return _ModernContainer(
      title:
          'Stok Uyarıları (🔴 ${critical.length} kritik • 🟡 ${warning.length} azalan)',
      actionText: 'Stok Yönetimi',
      onAction: () => nav?.navigateTo(1),
      child: (critical.isEmpty && warning.isEmpty)
          ? const _CleanEmptyRow(
              icon: Icons.inventory_2_rounded,
              title: 'Tüm ürün stokları güvenli seviyede.',
            )
          : Column(
              children: [
                for (final item in [...critical, ...warning].take(6))
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: item.isCritical
                          ? Colors.red.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: item.isCritical
                              ? Colors.red.shade200
                              : Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (item.isCritical
                                    ? Colors.red
                                    : Colors.orange)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                              item.isCritical
                                  ? Icons.error
                                  : Icons.warning_amber,
                              size: 18,
                              color: item.isCritical
                                  ? Colors.red
                                  : Colors.orange),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.isCritical
                                          ? '${item.name} kritik stok!'
                                          : '${item.name} azalan stok!',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                  StatusBadge(
                                    text: item.isOutOfStock
                                        ? 'Tükendi'
                                        : item.isCritical
                                            ? 'Kritik'
                                            : 'Azalan',
                                    color: item.isOutOfStock
                                        ? AppColors.error
                                        : item.isCritical
                                            ? Colors.red
                                            : Colors.orange,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: StockBar(
                                      ratio: item.stockRatio,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Kalan: ${item.formattedStock()}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      openOrderQtySheet(
                                    context,
                                    itemId: item.id,
                                    suggestedQty:
                                        suggestedTopUp(store, item.id),
                                    reason: item.isOutOfStock
                                        ? '${item.name} tükendi! Acil sipariş önerilir.'
                                        : item.isCritical
                                            ? '${item.name} kritik stokta!'
                                            : '${item.name} azalan stokta!',
                                  ),
                                  icon: const Icon(
                                      Icons.add_shopping_cart,
                                      size: 16),
                                  label:
                                      const Text('Sipariş Ver'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        Colors.red.shade700,
                                    side: BorderSide(
                                        color:
                                            Colors.red.shade300),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildTodayMenuCard(
    BuildContext context,
    AppStore store,
    List<MenuEntry> todayMenu,
    DateTime now,
  ) {
    final nav = TabNavigationScope.of(context);
    final dayName = MenuEntry.days[now.weekday - 1];

    return _ModernContainer(
      title: 'Bugünkü Menü ($dayName)',
      actionText: 'Üretim Tablosu',
      onAction: () => nav?.navigateTo(5),
      child: todayMenu.isEmpty
          ? const _CleanEmptyRow(
              icon: Icons.restaurant_menu_rounded,
              title: 'Bugün için kayıtlı menü bulunmuyor.',
            )
          : Column(
              children: [
                for (final e in todayMenu)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primaryMuted,
                          child: Text(
                            e.meal.isNotEmpty ? e.meal.characters.first : '?',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                store.recipeById(e.recipeId)?.name ?? 'Tarif silinmiş',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.text,
                                ),
                              ),
                              Text(
                                e.meal,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Text(
                            '${e.servings} porsiyon',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildProductionCard(BuildContext context, AppStore store) {
    final nav = TabNavigationScope.of(context);

    return _ModernContainer(
      title: 'Son Üretimler',
      actionText: 'Üretim Tablosu',
      onAction: () => nav?.navigateTo(5),
      child: store.productionLogs.isEmpty
          ? const _CleanEmptyRow(
              icon: Icons.history_rounded,
              title: 'Henüz üretim geçmişi kaydı yok.',
            )
          : Column(
              children: [
                for (final log in store.productionLogs.take(3))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check_rounded, color: AppColors.primary, size: 18),
                    ),
                    title: Text(
                      '${log.recipeName} × ${log.servingsMade} porsiyon',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.text,
                      ),
                    ),
                    subtitle: Text(
                      '${fmtDay(log.date)} • ${log.deductions.length} stok kalemi düşüldü',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _AgendaRow {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final int tab; // -1 = işlem yok

  const _AgendaRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.tab,
  });
}

class _ModernContainer extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  final Widget child;

  const _ModernContainer({
    required this.title,
    this.actionText,
    this.onAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: -0.2,
                    color: AppColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (actionText != null && onAction != null)
                InkWell(
                  onTap: onAction,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      actionText!,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _CleanEmptyRow extends StatelessWidget {
  final IconData icon;
  final String title;

  const _CleanEmptyRow({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
