import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/grocery_category.dart';
import '../models/order_line.dart';
import '../models/supplier.dart';
import '../models/supplier_order.dart';
import '../state/app_store.dart';

/// "Sipariş Ver" penceresi: miktar girilir, doğrudan
/// "Sipariş Verilecekler"e planlı sipariş açılır.
/// [suggestedQty] çağrıldığı bağlama göre hesaplanır
/// (örn. uyarı eşiğine kadar eksik, haftalık açık).
class OrderQtySheet extends StatefulWidget {
  final String itemId;
  final double suggestedQty;
  final String? reason;
  const OrderQtySheet({
    super.key,
    required this.itemId,
    required this.suggestedQty,
    this.reason,
  });

  @override
  State<OrderQtySheet> createState() => _OrderQtySheetState();
}

class _OrderQtySheetState extends State<OrderQtySheet> {
  late final TextEditingController _ctrl;
  String? _supplierId;

  @override
  void initState() {
    super.initState();
    final v = widget.suggestedQty <= 0 ? 0 : widget.suggestedQty;
    _ctrl = TextEditingController(
        text: v.toStringAsFixed(v >= 100 ? 0 : 1));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _qty =>
      double.tryParse(_ctrl.text.replaceAll(',', '.')) ?? -1;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final item = store.itemById(widget.itemId);
    if (item == null) return const SizedBox.shrink();
    _supplierId ??= store.suppliers.isNotEmpty
        ? store.suppliers.first.id
        : null;
    final valid = _qty > 0;

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
            Text('Sipariş Ver — ${item.name}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Stok: ${item.formattedStock()} • Uyarı: ${item.formatAmount(item.warnThreshold)} • Kritik: ${item.formatAmount(item.minThreshold)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (widget.reason != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.orange.shade200),
                ),
                child: Text(widget.reason!,
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Sipariş miktarı',
                suffixText: item.unit.abbreviation,
                border: const OutlineInputBorder(),
                errorText: valid ? null : '0’dan büyük olmalı',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _supplierId,
              decoration: const InputDecoration(
                labelText: 'Tedarikçi',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: store.suppliers
                  .map((s) => DropdownMenuItem(
                      value: s.id, child: Text(s.name)))
                  .toList(),
              onChanged: (v) => setState(() => _supplierId = v),
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
                  child: FilledButton.icon(
                    onPressed: valid
                        ? () async {
                            final now = DateTime.now();
                            Supplier supplier =
                                store.defaultSupplier;
                            if (_supplierId != null) {
                              try {
                                supplier =
                                    store.suppliers.firstWhere(
                                        (s) =>
                                            s.id == _supplierId);
                              } catch (_) {}
                            }
                            await store.addOrder(SupplierOrder(
                              title:
                                  '${item.name} siparişi',
                              supplierName: supplier.name,
                              supplierId: supplier.id,
                              orderDate: now,
                              pickupDate: now.add(
                                  const Duration(days: 2)),
                              status: SupplierOrderStatus
                                  .scheduled,
                              items: [
                                OrderLine(
                                  itemId: item.id,
                                  name: item.name,
                                  unitKey: item.unit.key,
                                  orderedQty: _qty,
                                )
                              ],
                            ));
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                    content: Text(
                                        '${item.name} siparişlere eklendi (${item.formatAmount(_qty)}).')),
                              );
                            }
                          }
                        : null,
                    icon: const Icon(Icons.receipt_long,
                        size: 18),
                    label: const Text('Sipariş Aç'),
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
}

/// Her yerden çağrılan kısayol.
void openOrderQtySheet(BuildContext context,
    {required String itemId,
    required double suggestedQty,
    String? reason}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => OrderQtySheet(
        itemId: itemId,
        suggestedQty: suggestedQty,
        reason: reason),
  );
}

/// Uyarı eşiğine tamamlayacak önerilen sipariş miktarı.
double suggestedTopUp(AppStore store, String itemId,
    {double? projectedShortfall}) {
  final item = store.itemById(itemId);
  if (item == null) return 0;
  final toWarn = item.warnThreshold - item.currentStock;
  final short = projectedShortfall ?? 0;
  final need = toWarn > short ? toWarn : short;
  if (need <= 0) return item.unit.baseStep;
  return item.unit.isCountable
      ? need.ceilToDouble()
      : need.roundToDouble();
}
