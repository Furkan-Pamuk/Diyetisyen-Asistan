import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order_cart.dart';
import '../services/pdf_service.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';

/// Sipariş sepeti: tedarikçiye göre gruplu kalemler, satır bazında
/// tedarikçi değiştirme, grup grup veya toplu siparişe dönüştürme,
/// PDF olarak kaydetme/paylaşma.
class OrderCartScreen extends StatefulWidget {
  const OrderCartScreen({super.key});

  @override
  State<OrderCartScreen> createState() => _OrderCartScreenState();
}

class _OrderCartScreenState extends State<OrderCartScreen> {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cart = store.orderCart;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sipariş Sepeti'),
        actions: [
          if (cart.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'PDF olarak kaydet/paylaş',
              onPressed: () => _sharePdf(context),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Sepeti boşalt',
              onPressed: () => _confirmClear(context),
            ),
          ],
        ],
      ),
      body: cart.isEmpty
          ? const EmptyState(
              icon: Icons.add_shopping_cart_outlined,
              title: 'Sepet boş',
              subtitle:
                  'Stok uyarılarındaki veya üretim planındaki "Sipariş Ver" düğmeleriyle ürün ekleyin.')
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      for (final groupKey in store.cartGroupOrder())
                        _GroupCard(groupKey: groupKey),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton.icon(
                    onPressed: () async {
                      final orders = await context
                          .read<AppStore>()
                          .cartToOrdersByGroup();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          SnackBar(
                              content: Text(orders.isEmpty
                                  ? 'Sepet boş.'
                                  : '${orders.length} tedarikçiye ${orders.length} sipariş oluşturuldu.')),
                        );
                      }
                    },
                    icon: const Icon(
                        Icons.local_shipping_outlined),
                    label: Text(
                        'Tüm Grupları Siparişe Dönüştür (${cart.length} kalem)'),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _sharePdf(BuildContext context) async {
    final store = context.read<AppStore>();
    final groups = <String, List<Map<String, String>>>{};
    for (final key in store.cartGroupOrder()) {
      final title = key == 'unassigned'
          ? 'Atanmamis'
          : store.supplierNameById(key);
      groups[title] = store
          .cartGroupedBySupplier()[key]!
          .map((e) => {'name': e.name, 'qty': e.formattedQty()})
          .toList();
    }
    try {
      await PdfService.shareCartPdf(
          groups: groups, filename: 'siparis-sepeti.pdf');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF oluşturulamadı: $e')),
        );
      }
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sepet boşaltılsın mı?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Boşalt')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppStore>().clearCart();
    }
  }
}

class _GroupCard extends StatelessWidget {
  final String groupKey;
  const _GroupCard({required this.groupKey});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final items =
        store.cartGroupedBySupplier()[groupKey] ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    final title = groupKey == 'unassigned'
        ? 'Tedarikçisiz'
        : store.supplierNameById(groupKey);

    return Card(
      margin:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.store, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('$title (${items.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final order = await context
                        .read<AppStore>()
                        .cartToOrder(
                          supplierId: groupKey == 'unassigned'
                              ? null
                              : groupKey,
                          ids: items.map((e) => e.id).toList(),
                        );
                    if (context.mounted && order != null) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        SnackBar(
                            content: Text(
                                'Sipariş oluşturuldu: ${order.title}')),
                      );
                    }
                  },
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Grubu Siparişe Dönüştür'),
                ),
              ],
            ),
            const Divider(height: 12),
            for (final e in items) _CartRow(item: e),
          ],
        ),
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  final OrderCartItem item;
  const _CartRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child:
            const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) =>
          context.read<AppStore>().removeFromCart(item.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(
                      Icons.remove_circle_outline,
                      size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => context
                      .read<AppStore>()
                      .updateCartQty(item.id,
                          item.quantity - _step(item)),
                ),
                SizedBox(
                  width: 92,
                  child: Text(
                    item.formattedQty(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => context
                      .read<AppStore>()
                      .updateCartQty(item.id,
                          item.quantity + _step(item)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String?>(
              initialValue: item.supplierId,
              decoration: const InputDecoration(
                labelText: 'Tedarikçi',
                prefixIcon: Icon(Icons.store, size: 18),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tedarikçisiz')),
                for (final s in store.suppliers)
                  DropdownMenuItem<String?>(
                      value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => context
                  .read<AppStore>()
                  .setCartItemSupplier(item.id, v),
            ),
          ],
        ),
      ),
    );
  }

  double _step(OrderCartItem e) =>
      (e.unitKey == 'gram' ? 100.0 : 1.0);
}
