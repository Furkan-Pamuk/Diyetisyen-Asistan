import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/grocery_category.dart';
import '../models/inventory_item.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';
import '../widgets/order_qty_sheet.dart';
import '../widgets/product_name_field.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _search = '';
  bool _lowOnly = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final filtered = store.inventory.where((e) {
      if (_lowOnly && !e.isWarning) return false;
      if (_search.isNotEmpty &&
          !e.name.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.alertLevel.compareTo(b.alertLevel) != 0
          ? a.alertLevel.compareTo(b.alertLevel)
          : a.currentStock.compareTo(b.currentStock));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Yönetimi'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.warning,
              color: _lowOnly ? Colors.orange : null,
            ),
            tooltip: 'Uyarı + Kritik',
            onPressed: () => setState(() => _lowOnly = !_lowOnly),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openAdd(context),
            tooltip: 'Ekle',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SearchBar(
              hintText: 'Ürün ara',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ),
      ),
      body: filtered.isEmpty
          ? const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Stok bulunamadı',
              subtitle: 'Aramayı değiştirin veya yeni ürün ekleyin.')
          : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final item = filtered[i];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(item.category.icon,
                                size: 18, color: item.category.tint),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(item.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ),
                            if (item.isOutOfStock)
                              const StatusBadge(
                                text: 'Tükendi',
                                color: Colors.red,
                              )
                            else if (item.isCritical)
                              const StatusBadge(
                                text: 'Kritik',
                                color: Colors.red,
                              )
                            else if (item.isWarning)
                              const StatusBadge(
                                text: 'Azalan',
                                color: Colors.orange,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _openThresholds(context, item),
                          borderRadius: BorderRadius.circular(4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  '${item.category.shortName} • Kalan: ${item.formattedStock()} • Uyarı: ${item.formatAmount(item.warnThreshold)} • Kritik: ${item.formatAmount(item.minThreshold)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.edit,
                                  size: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => _openCapacity(context, item),
                          borderRadius: BorderRadius.circular(4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'Depo: ${item.formatAmount(item.warehouseStock)} (düzenle)',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.edit,
                                  size: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => _openBatches(context, item),
                          borderRadius: BorderRadius.circular(4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'Girişler: ${context.watch<AppStore>().batchesFor(item.id).length} parti (tarih + miktar için dokun)',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.history,
                                  size: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        StockBar(ratio: item.stockRatio),
                        const SizedBox(height: 8),
                        Builder(builder: (_) {
                          // Dar ekranda sıkışmayı önlemek için tam genişlik satır;
                          // adım deponun %5'i (en az bir taban adım) ki
                          // değişim gözle görünür olsun.
                          final step = (item.warehouseStock * 0.05)
                              .clamp(item.unit.baseStep, 1000000.0)
                              .toDouble();
                          final stepLabel =
                              item.unit.format(step);
                          return Column(
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                        Icons.remove_circle_outline),
                                    tooltip: 'Azalt ($stepLabel)',
                                    onPressed: () => context
                                        .read<AppStore>()
                                        .adjustStock(
                                            item.id, -step),
                                  ),
                                  Expanded(
                                    child: Builder(builder: (_) {
                                      // Slider range follows warehouse capacity,
                                      // so huge depots (e.g. 100000 kg) stay usable.
                                      final sliderMax = max(
                                          max(item.warehouseStock * 2,
                                              item.currentStock * 1.2),
                                          100.0);
                                      return Slider(
                                        value: item.currentStock
                                            .clamp(0, sliderMax)
                                            .toDouble(),
                                        max: sliderMax,
                                        divisions: 50,
                                        label: item.formattedStock(),
                                        onChanged: (v) => context
                                            .read<AppStore>()
                                            .setStock(item.id, v),
                                      );
                                    }),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.add_circle_outline),
                                    tooltip: 'Artır ($stepLabel)',
                                    onPressed: () => context
                                        .read<AppStore>()
                                        .adjustStock(
                                            item.id, step),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.tonal(
                                      onPressed: () => _openReceive(
                                          context, item),
                                      child:
                                          const Text('Mal Kabul'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _openConsume(
                                              context, item),
                                      icon: const Icon(
                                          Icons.remove_circle_outline,
                                          size: 18),
                                      label:
                                          const Text('Tüketim'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }),
                        if (item.isWarning)
                          Padding(
                            padding:
                                const EdgeInsets.only(top: 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    openOrderQtySheet(
                                  context,
                                  itemId: item.id,
                                  suggestedQty:
                                      suggestedTopUp(
                                          context.read<AppStore>(),
                                          item.id),
                                  reason: item.isOutOfStock
                                      ? '${item.name} tükendi! Acil sipariş önerilir.'
                                      : item.isCritical
                                          ? '${item.name} kritik stokta! Kritik eşiğin altına düştü.'
                                          : '${item.name} azalan stokta! Uyarı eşiğine yaklaşıyor.',
                                ),
                                icon: const Icon(
                                    Icons.add_shopping_cart,
                                    size: 18),
                                label: Text(item.isCritical
                                    ? 'Sipariş Ver (kritik!)'
                                    : 'Sipariş Ver'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: item.isCritical
                                      ? Colors.red
                                      : Colors.orange.shade800,
                                  side: BorderSide(
                                      color: item.isCritical
                                          ? Colors.red
                                          : Colors.orange),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _openAdd(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const InventoryFormSheet(),
    );
  }

  void _openReceive(BuildContext context, InventoryItem item) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ReceiveSheet(itemId: item.id, name: item.name),
    );
  }

  void _openConsume(BuildContext context, InventoryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ConsumeSheet(itemId: item.id),
    );
  }

  void _openCapacity(BuildContext context, InventoryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CapacitySheet(itemId: item.id),
    );
  }

  void _openThresholds(BuildContext context, InventoryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ThresholdSheet(itemId: item.id),
    );
  }

  void _openBatches(BuildContext context, InventoryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BatchListSheet(itemId: item.id),
    );
  }
}

class InventoryFormSheet extends StatefulWidget {
  const InventoryFormSheet({super.key});

  @override
  State<InventoryFormSheet> createState() => _InventoryFormSheetState();
}

class _InventoryFormSheetState extends State<InventoryFormSheet> {
  final _name = TextEditingController();
  final _stock = TextEditingController(text: '1000');
  final _critical = TextEditingController(text: '500');
  final _warn = TextEditingController(text: '1000');
  GroceryCategory _cat = GroceryCategory.freshProduce;
  StockUnit _unit = StockUnit.gram;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Yeni Ürün',
                style: Theme.of(context).textTheme.titleLarge),
            ProductNameField(
              onChanged: (text, match) => setState(() {
                _name.text = text;
                if (match != null) {
                  _cat = match.category;
                  _unit = match.unit;
                }
              }),
            ),
            DropdownButtonFormField<GroceryCategory>(
              initialValue: _cat,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: GroceryCategory.values
                  .map((c) => DropdownMenuItem(
                      value: c, child: Text(c.displayName)))
                  .toList(),
              onChanged: (v) => setState(() => _cat = v!),
            ),
            DropdownButtonFormField<StockUnit>(
              initialValue: _unit,
              decoration:
                  const InputDecoration(labelText: 'Birim'),
              items: StockUnit.values
                  .map((u) => DropdownMenuItem(
                      value: u, child: Text(u.displayName)))
                  .toList(),
              onChanged: (v) => setState(() => _unit = v!),
            ),
            TextField(
                controller: _stock,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: 'Stok (${_unit.abbreviation})')),
            TextField(
                controller: _critical,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Kritik eşik (kırmızı)',
                    helperText: 'Bu değer ve altı = kritik stok')),
            TextField(
                controller: _warn,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Uyarı eşiği (sarı)',
                    helperText:
                        'Bu değer ve altı = azalan stok (kritikten büyük olmalı)')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _name.text.trim().isEmpty
                  ? null
                  : () {
                      final s =
                          double.tryParse(_stock.text) ?? 0;
                      final c =
                          double.tryParse(_critical.text) ?? 0;
                      var w = double.tryParse(_warn.text) ?? c * 2;
                      if (w < c) w = c;
                      context.read<AppStore>().addInventoryItem(
                            InventoryItem(
                              name: _name.text.trim(),
                              category: _cat,
                              unit: _unit,
                              currentStock: s,
                              warehouseStock: s,
                              minThreshold: c,
                              warnThreshold: w,
                            ),
                          );
                      Navigator.pop(context);
                    },
              child: const Text('Kaydet'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class ReceiveSheet extends StatefulWidget {
  final String itemId;
  final String name;
  const ReceiveSheet({super.key, required this.itemId, required this.name});

  @override
  State<ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends State<ReceiveSheet> {
  final _qty = TextEditingController(text: '1000');
  final _note = TextEditingController();
  String? _supplierId;

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    _supplierId ??= store.suppliers.isNotEmpty
        ? store.suppliers.first.id
        : null;
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
            Text('Mal Kabul — ${widget.name}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
                controller: _qty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Gelen miktar',
                    border: OutlineInputBorder(),
                    isDense: true)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _supplierId,
              decoration: const InputDecoration(
                  labelText: 'Tedarikçi (arşiv için)',
                  border: OutlineInputBorder(),
                  isDense: true),
              items: [
                const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tedarikçisiz')),
                for (final s in store.suppliers)
                  DropdownMenuItem<String?>(
                      value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) =>
                  setState(() => _supplierId = v),
            ),
            const SizedBox(height: 8),
            TextField(
                controller: _note,
                decoration: const InputDecoration(
                    labelText: 'Not (opsiyonel)',
                    border: OutlineInputBorder(),
                    isDense: true),
                maxLines: 2),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final q = double.tryParse(
                        _qty.text.replaceAll(',', '.')) ??
                    0;
                if (q <= 0) return;
                context.read<AppStore>().logDirectReceipt(
                      itemId: widget.itemId,
                      quantity: q,
                      supplierId: _supplierId,
                      note: _note.text,
                    );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Stoğa işlendi ve teslimat arşivine kaydedildi.')),
                );
              },
              child: const Text('Onayla ve Arşive Kaydet'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Edits warehouse capacity (depo boyutu), e.g. rice from 5 kg to 100000 kg.
/// The fill bar (currentStock / warehouseStock) follows automatically.
class CapacitySheet extends StatefulWidget {
  final String itemId;
  const CapacitySheet({super.key, required this.itemId});

  @override
  State<CapacitySheet> createState() => _CapacitySheetState();
}

class _CapacitySheetState extends State<CapacitySheet> {
  late final TextEditingController _ctrl;

  static const _kgChips = <String, double>{
    '5 kg': 5000,
    '25 kg': 25000,
    '100 kg': 100000,
    '1 ton': 1000000,
    '100 ton': 100000000,
  };

  static const _tonChips = <String, double>{
    '5 kg': 5,
    '25 kg': 25,
    '100 kg': 100,
    '1 ton': 1000,
    '100 ton': 100000,
  };

  static const _pieceChips = <String, double>{
    '10': 10,
    '30': 30,
    '100': 100,
    '500': 500,
    '1000': 1000,
  };

  Map<String, double> _chipsFor(StockUnit unit) {
    switch (unit) {
      case StockUnit.gram:
        return _kgChips;
      case StockUnit.kilogram:
        return _tonChips;
      case StockUnit.piece:
      case StockUnit.roll:
      case StockUnit.box:
      case StockUnit.pack:
        return _pieceChips;
    }
  }

  @override
  void initState() {
    super.initState();
    final item = context.read<AppStore>().itemById(widget.itemId);
    final v = item?.warehouseStock ?? 0;
    final text = item != null && item.unit.isWeighed
        ? v.toStringAsFixed(v >= 100 ? 0 : 1)
        : v.toStringAsFixed(0);
    _ctrl = TextEditingController(text: text);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _value =>
      double.tryParse(_ctrl.text.replaceAll(',', '.')) ?? -1;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final item = store.itemById(widget.itemId);
    if (item == null) return const SizedBox.shrink();

    final valid = _value >= 0;
    final ratio = valid && _value > 0
        ? (item.currentStock / _value).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final chips = _chipsFor(item.unit);

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Depo Boyutu — ${item.name}',
                style: Theme.of(context).textTheme.titleLarge),
            Text('Kalan stok: ${item.formattedStock()}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: false),
              decoration: InputDecoration(
                labelText: 'Kapasite (${item.unit.abbreviation})',
                suffixText: item.unit.abbreviation,
                border: const OutlineInputBorder(),
                errorText: valid ? null : '0 veya üzeri bir sayı girin',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: chips.entries
                  .map((e) => ActionChip(
                        label: Text(e.key),
                        onPressed: () => setState(() {
                          _ctrl.text = e.value.toStringAsFixed(0);
                        }),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Text(
              'Önizleme doluluk: %${(ratio * 100).toStringAsFixed(1)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            StockBar(ratio: ratio),
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
                            store.setWarehouseCapacity(
                                item.id, _value);
                            Navigator.pop(context);
                          }
                        : null,
                    child: const Text('Kaydet'),
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

/// Manuel tüketim: kullanıldıkça stoktan düşer.
/// Miktar yazılır, onayda stoktan düşülür.
class ConsumeSheet extends StatefulWidget {
  final String itemId;
  const ConsumeSheet({super.key, required this.itemId});

  @override
  State<ConsumeSheet> createState() => _ConsumeSheetState();
}

class _ConsumeSheetState extends State<ConsumeSheet> {
  final _qty = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  double get _value =>
      double.tryParse(_qty.text.replaceAll(',', '.')) ?? -1;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final item = store.itemById(widget.itemId);
    if (item == null) return const SizedBox.shrink();
    final valid = _value > 0 && _value <= item.currentStock;
    final after = valid ? item.currentStock - _value : item.currentStock;

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
            Text('Tüketim — ${item.name}',
                style: Theme.of(context).textTheme.titleLarge),
            Text('Mevcut: ${item.formattedStock()}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _qty,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText:
                    'Kullanılan miktar (${item.unit.abbreviation})',
                border: const OutlineInputBorder(),
                errorText: _qty.text.isEmpty
                    ? null
                    : (valid
                        ? null
                        : '0 ile ${item.formattedStock()} arasında girin'),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                  labelText: 'Not (opsiyonel, örn. akşam servisi)',
                  border: OutlineInputBorder(),
                  isDense: true),
            ),
            if (valid) ...[
              const SizedBox(height: 8),
              Text('Kalan: ${item.formatAmount(after)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
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
                        ? () async {
                            await store.adjustStock(
                                item.id, -_value);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                    content: Text(
                                        '${item.name}: ${item.formatAmount(_value)} düşüldü${_note.text.trim().isNotEmpty ? ' (${_note.text.trim()})' : ''}. Kalan: ${item.formatAmount(after)}')),
                              );
                            }
                          }
                        : null,
                    child: const Text('Stoktan Düş'),
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

/// Parti giriş geçmişi: her malzemenin stoğa giriş tarihi + miktarı.
class BatchListSheet extends StatelessWidget {
  final String itemId;
  const BatchListSheet({super.key, required this.itemId});

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final item = store.itemById(itemId);
    final batches = store.batchesFor(itemId).reversed.toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Stok Girişleri — ${item?.name ?? ''}',
              style: Theme.of(context).textTheme.titleLarge),
          Text(
              '${batches.length} parti • İmha tutanağındaki "Dolaba Giriş Tarihi" buradan gelir.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Flexible(
            child: batches.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Kayıtlı giriş yok.'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: batches.length,
                    itemBuilder: (ctx, i) {
                      final b = batches[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                            Icons.login_outlined,
                            size: 20),
                        title: Text(
                          item != null
                              ? item.formatAmount(b.quantity)
                              : '${b.quantity}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                            '${_d(b.entryDate)} • ${b.source.isEmpty ? 'Kaynaksız' : b.source}'),
                        trailing: IconButton(
                          icon: const Icon(
                              Icons.delete_outline,
                              size: 20),
                          tooltip: 'Partiyi sil',
                          onPressed: () => context
                              .read<AppStore>()
                              .deleteBatch(b.id),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Uyarı (sarı) ve kritik (kırmızı) eşiklerini düzenler.
/// Kalan stok uyarı eşiğine inince "X azalan stok", kritik eşiğe
/// inince "X kritik stok" uyarısı verilir.
class ThresholdSheet extends StatefulWidget {
  final String itemId;
  const ThresholdSheet({super.key, required this.itemId});

  @override
  State<ThresholdSheet> createState() => _ThresholdSheetState();
}

class _ThresholdSheetState extends State<ThresholdSheet> {
  late final TextEditingController _warnCtrl;
  late final TextEditingController _criticalCtrl;

  @override
  void initState() {
    super.initState();
    final item = context.read<AppStore>().itemById(widget.itemId);
    String txt(double v) => item != null && item.unit.isWeighed
        ? v.toStringAsFixed(1)
        : v.toStringAsFixed(0);
    _warnCtrl =
        TextEditingController(text: txt(item?.warnThreshold ?? 0));
    _criticalCtrl = TextEditingController(
        text: txt(item?.minThreshold ?? 0));
  }

  @override
  void dispose() {
    _warnCtrl.dispose();
    _criticalCtrl.dispose();
    super.dispose();
  }

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? -1;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final item = store.itemById(widget.itemId);
    if (item == null) return const SizedBox.shrink();
    final w = _parse(_warnCtrl);
    final c = _parse(_criticalCtrl);
    final valid = w >= 0 && c >= 0 && w >= c;
    final unit = item.unit.abbreviation;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stok Eşikleri — ${item.name}',
                style: Theme.of(context).textTheme.titleLarge),
            Text('Kalan: ${item.formattedStock()}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _warnCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: false),
              decoration: InputDecoration(
                labelText: 'Uyarı eşiği (sarı) — $unit',
                helperText: 'Bu değer ve altı: "${item.name} azalan stok!"',
                border: const OutlineInputBorder(),
                prefixIcon:
                    const Icon(Icons.warning_amber, color: Colors.orange),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _criticalCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: false),
              decoration: InputDecoration(
                labelText: 'Kritik eşik (kırmızı) — $unit',
                helperText: 'Bu değer ve altı: "${item.name} kritik stok!"',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.error, color: Colors.red),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (!valid)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Uyarı eşiği 0’dan büyük ve kritik eşikten küçük olamaz.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
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
                    onPressed: valid
                        ? () async {
                            await store.setThresholds(
                                item.id, w, c);
                            if (context.mounted) Navigator.pop(context);
                          }
                        : null,
                    child: const Text('Kaydet'),
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
