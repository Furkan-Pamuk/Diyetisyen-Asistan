import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/grocery_category.dart';
import '../models/inventory_item.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';

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
      if (_lowOnly && !e.isLowStock) return false;
      if (_search.isNotEmpty &&
          !e.name.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Yönetimi'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.warning,
              color: _lowOnly ? Colors.orange : null,
            ),
            tooltip: 'Kritik',
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
                            if (item.isLowStock)
                              StatusBadge(
                                text: item.isOutOfStock
                                    ? 'Tükendi'
                                    : 'Kritik',
                                color: Colors.red,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _openCapacity(context, item),
                          borderRadius: BorderRadius.circular(4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  '${item.category.shortName} • Kalan: ${item.formattedStock()} • Depo: ${item.formatAmount(item.warehouseStock)}',
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
                        const SizedBox(height: 6),
                        StockBar(ratio: item.stockRatio),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () => context
                                        .read<AppStore>()
                                        .adjustStock(
                                            item.id,
                                            item.unit == StockUnit.gram
                                                ? -100
                                                : -1),
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
                                            .clamp(0, sliderMax),
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
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () => context
                                        .read<AppStore>()
                                        .adjustStock(
                                            item.id,
                                            item.unit == StockUnit.gram
                                                ? 100
                                                : 1),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: () => _openReceive(context, item),
                              child: const Text('Mal Kabul'),
                            ),
                          ],
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

  void _openCapacity(BuildContext context, InventoryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CapacitySheet(itemId: item.id),
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
  final _threshold = TextEditingController(text: '500');
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
            TextField(
                controller: _name,
                decoration:
                    const InputDecoration(labelText: 'Ürün adı')),
            DropdownButtonFormField<GroceryCategory>(
              initialValue: _cat,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: GroceryCategory.values
                  .map((c) => DropdownMenuItem(
                      value: c, child: Text(c.displayName)))
                  .toList(),
              onChanged: (v) => setState(() => _cat = v!),
            ),
            SegmentedButton<StockUnit>(
              segments: const [
                ButtonSegment(value: StockUnit.gram, label: Text('Gram (g)')),
                ButtonSegment(value: StockUnit.piece, label: Text('Adet')),
              ],
              selected: {_unit},
              onSelectionChanged: (s) => setState(() => _unit = s.first),
            ),
            TextField(
                controller: _stock,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: _unit == StockUnit.gram
                        ? 'Stok (g)'
                        : 'Stok (adet)')),
            TextField(
                controller: _threshold,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Kritik eşik')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _name.text.trim().isEmpty
                  ? null
                  : () {
                      final s =
                          double.tryParse(_stock.text) ?? 0;
                      context.read<AppStore>().addInventoryItem(
                            InventoryItem(
                              name: _name.text.trim(),
                              category: _cat,
                              unit: _unit,
                              currentStock: s,
                              warehouseStock: s,
                              minThreshold:
                                  double.tryParse(_threshold.text) ?? 0,
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Mal Kabul — ${widget.name}',
              style: Theme.of(context).textTheme.titleLarge),
          TextField(
              controller: _qty,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Gelen miktar')),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              final q = double.tryParse(_qty.text) ?? 0;
              if (q <= 0) return;
              context.read<AppStore>().receiveShipment(widget.itemId, q);
              Navigator.pop(context);
            },
            child: const Text('Onayla'),
          ),
          const SizedBox(height: 16),
        ],
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

  static const _pieceChips = <String, double>{
    '10': 10,
    '30': 30,
    '100': 100,
    '500': 500,
    '1000': 1000,
  };

  @override
  void initState() {
    super.initState();
    final item = context.read<AppStore>().itemById(widget.itemId);
    final v = item?.warehouseStock ?? 0;
    final text = item != null && item.unit == StockUnit.gram
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

    final isGram = item.unit == StockUnit.gram;
    final valid = _value >= 0;
    final ratio = valid && _value > 0
        ? (item.currentStock / _value).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final chips = isGram ? _kgChips : _pieceChips;

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
                labelText:
                    isGram ? 'Kapasite (gram)' : 'Kapasite (adet)',
                suffixText: isGram ? 'g' : 'adet',
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
