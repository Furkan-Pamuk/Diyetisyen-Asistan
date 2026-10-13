import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/supplier.dart';
import '../models/supplier_order.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';

enum StatusFilter { active, all, attention }

class SupplierOrdersScreen extends StatefulWidget {
  const SupplierOrdersScreen({super.key});

  @override
  State<SupplierOrdersScreen> createState() => _SupplierOrdersScreenState();
}

class _SupplierOrdersScreenState extends State<SupplierOrdersScreen> {
  StatusFilter _filter = StatusFilter.active;
  String? _supplierFilterId; // null = all suppliers

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    List<SupplierOrder> filtered;
    switch (_filter) {
      case StatusFilter.active:
        filtered = store.activeOrders;
        break;
      case StatusFilter.all:
        filtered = List.of(store.supplierOrders)
          ..sort((a, b) => a.orderDate.compareTo(b.orderDate));
        break;
      case StatusFilter.attention:
        filtered = store.attentionOrders;
        break;
    }
    if (_supplierFilterId != null) {
      filtered = filtered
          .where((o) =>
              o.supplierId == _supplierFilterId ||
              (o.supplierId == null &&
                  o.supplierName ==
                      store.supplierNameById(_supplierFilterId!)))
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tedarikçiler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.store),
            tooltip: 'Tedarikçi yönetimi',
            onPressed: () => _openSuppliers(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openForm(context, null),
            tooltip: 'Sipariş ekle',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: DropdownButtonFormField<String?>(
              // Reset when the supplier set changes (e.g. deletion),
              // so initialValue never points to a removed supplier.
              key: ValueKey(
                  store.suppliers.map((s) => s.id).join(',')),
              initialValue: store.suppliers.any((s) => s.id == _supplierFilterId)
                  ? _supplierFilterId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Tedarikçi filtresi',
                prefixIcon: Icon(Icons.store),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('Tümü')),
                for (final s in store.suppliers)
                  DropdownMenuItem<String?>(
                      value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _supplierFilterId = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<StatusFilter>(
              segments: const [
                ButtonSegment(value: StatusFilter.active, label: Text('Aktif')),
                ButtonSegment(value: StatusFilter.all, label: Text('Tümü')),
                ButtonSegment(value: StatusFilter.attention, label: Text('Acil')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'Sipariş yok',
                    subtitle: 'Seçili filtrede sipariş bulunamadı.')
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final o = filtered[i];
                      return Dismissible(
                        key: ValueKey(o.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) =>
                            context.read<AppStore>().deleteOrder(o.id),
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(o.title,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                    ),
                                    StatusBadge(
                                      text: o.status.displayName,
                                      color: o.status.isActive
                                          ? Colors.blue
                                          : Colors.grey,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.store,
                                        size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      context
                                          .read<AppStore>()
                                          .supplierNameOf(o),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Sipariş: ${fmtDay(o.orderDate)} • Teslim: ${fmtDay(o.pickupDate)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                CountdownText(
                                    days: o.orderCountdown, prefix: 'Sipariş:'),
                                if (o.status != SupplierOrderStatus.scheduled)
                                  CountdownText(
                                      days: o.pickupCountdown,
                                      prefix: 'Teslim:'),
                                if (o.notes.isNotEmpty)
                                  Text(o.notes,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    FilledButton.tonal(
                                      onPressed: o.status.isActive
                                          ? () => context
                                              .read<AppStore>()
                                              .markPickedUp(o)
                                          : null,
                                      child: const Text('Teslim Alındı'),
                                    ),
                                    const Spacer(),
                                    OutlinedButton(
                                      onPressed: () => _openForm(context, o),
                                      child: const Text('Düzenle'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context, SupplierOrder? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => OrderFormSheet(existing: existing),
    );
  }

  void _openSuppliers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SuppliersSheet(),
    );
  }
}

class OrderFormSheet extends StatefulWidget {
  final SupplierOrder? existing;
  const OrderFormSheet({super.key, this.existing});

  @override
  State<OrderFormSheet> createState() => _OrderFormSheetState();
}

class _OrderFormSheetState extends State<OrderFormSheet> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late String _supplierId;
  late DateTime _orderDate;
  late DateTime _pickupDate;
  late SupplierOrderStatus _status;
  late bool _reminder;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    final fallback = store.suppliers.isNotEmpty
        ? store.suppliers.first.id
        : 'Supplier X';
    _supplierId = e?.supplierId ?? fallback;
    if (!store.suppliers.any((s) => s.id == _supplierId)) {
      _supplierId = fallback;
    }
    _orderDate = e?.orderDate ?? DateTime.now();
    _pickupDate =
        e?.pickupDate ?? DateTime.now().add(const Duration(days: 2));
    _status = e?.status ?? SupplierOrderStatus.scheduled;
    _reminder = e?.reminderEnabled ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (!store.suppliers.any((s) => s.id == _supplierId) &&
        store.suppliers.isNotEmpty) {
      _supplierId = store.suppliers.first.id;
    }
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
            Text(widget.existing == null ? 'Yeni Sipariş' : 'Siparişi Düzenle',
                style: Theme.of(context).textTheme.titleLarge),
            TextField(
                controller: _title,
                decoration: const InputDecoration(
                    labelText: 'Başlık (örn. Haftalık sebze)')),
            DropdownButtonFormField<String>(
              initialValue: _supplierId,
              decoration: const InputDecoration(
                  labelText: 'Tedarikçi',
                  prefixIcon: Icon(Icons.store)),
              items: store.suppliers
                  .map((s) => DropdownMenuItem(
                      value: s.id, child: Text(s.name)))
                  .toList(),
              onChanged: (v) => setState(() => _supplierId = v!),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Sipariş: ${fmtDay(_orderDate)}'),
              trailing: const Icon(Icons.calendar_month),
              onTap: () => _pickDate(true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Teslim: ${fmtDay(_pickupDate)}'),
              trailing: const Icon(Icons.calendar_month),
              onTap: () => _pickDate(false),
            ),
            DropdownButtonFormField<SupplierOrderStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Durum'),
              items: SupplierOrderStatus.values
                  .map((s) => DropdownMenuItem(
                      value: s, child: Text(s.displayName)))
                  .toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hatırlatıcı'),
              value: _reminder,
              onChanged: (v) => setState(() => _reminder = v),
            ),
            TextField(
                controller: _notes,
                decoration:
                    const InputDecoration(labelText: 'Notlar'),
                maxLines: 2),
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
                    onPressed: _title.text.trim().isEmpty ||
                            _pickupDate.isBefore(_orderDate)
                        ? null
                        : _save,
                    child: const Text('Kaydet'),
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

  Future<void> _pickDate(bool isOrder) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isOrder ? _orderDate : _pickupDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isOrder) {
          _orderDate = picked;
        } else {
          _pickupDate = picked;
        }
      });
    }
  }

  void _save() {
    final store = context.read<AppStore>();
    final supplierName = store.supplierNameById(_supplierId);
    if (widget.existing == null) {
      store.addOrder(SupplierOrder(
        title: _title.text.trim(),
        supplierName: supplierName,
        supplierId: _supplierId,
        orderDate: _orderDate,
        pickupDate: _pickupDate,
        status: _status,
        notes: _notes.text.trim(),
        reminderEnabled: _reminder,
      ));
    } else {
      final e = widget.existing!;
      e.title = _title.text.trim();
      e.supplierName = supplierName;
      e.supplierId = _supplierId;
      e.orderDate = _orderDate;
      e.pickupDate = _pickupDate;
      e.status = _status;
      e.notes = _notes.text.trim();
      e.reminderEnabled = _reminder;
      store.updateOrder(e);
    }
    Navigator.pop(context);
  }
}

/// Supplier directory: add / edit / delete suppliers.
class SuppliersSheet extends StatelessWidget {
  const SuppliersSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Tedarikçiler (${store.suppliers.length})',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              FilledButton.icon(
                onPressed: () => _openForm(context, null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Yeni'),
              ),
            ],
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: store.suppliers.length,
              itemBuilder: (ctx, i) {
                final s = store.suppliers[i];
                final orderCount = store.supplierOrders
                    .where((o) =>
                        o.supplierId == s.id || o.supplierName == s.name)
                    .length;
                return ListTile(
                  leading: const Icon(Icons.store),
                  title: Text(s.name,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    [
                      if (s.phone.isNotEmpty) s.phone,
                      if (s.note.isNotEmpty) s.note,
                      '$orderCount sipariş',
                    ].join(' • '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: 'Düzenle',
                        onPressed: () => _openForm(context, s),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: 'Sil',
                        onPressed: () => _confirmDelete(context, s),
                      ),
                    ],
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _openForm(BuildContext context, Supplier? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SupplierFormSheet(existing: existing),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Supplier s) async {
    final store = context.read<AppStore>();
    if (store.suppliers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Son tedarikçi silinemez.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${s.name}" silinsin mi?'),
        content: const Text(
            'Bu tedarikçinin siparişleri ilk tedarikçiye aktarılacak.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await store.deleteSupplier(s.id);
    }
  }
}

class SupplierFormSheet extends StatefulWidget {
  final Supplier? existing;
  const SupplierFormSheet({super.key, this.existing});

  @override
  State<SupplierFormSheet> createState() => _SupplierFormSheetState();
}

class _SupplierFormSheetState extends State<SupplierFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _phone = TextEditingController(text: widget.existing?.phone ?? '');
    _note = TextEditingController(text: widget.existing?.note ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              widget.existing == null ? 'Yeni Tedarikçi' : 'Tedarikçi Düzenle',
              style: Theme.of(context).textTheme.titleLarge),
          TextField(
              controller: _name,
              decoration:
                  const InputDecoration(labelText: 'Tedarikçi adı')),
          TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration:
                  const InputDecoration(labelText: 'Telefon (opsiyonel)')),
          TextField(
              controller: _note,
              decoration:
                  const InputDecoration(labelText: 'Not (opsiyonel)'),
              maxLines: 2),
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
                  onPressed: _name.text.trim().isEmpty ? null : _save,
                  child: const Text('Kaydet'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _save() {
    final store = context.read<AppStore>();
    if (widget.existing == null) {
      store.addSupplier(Supplier(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        note: _note.text.trim(),
      ));
    } else {
      final s = widget.existing!;
      s.name = _name.text.trim();
      s.phone = _phone.text.trim();
      s.note = _note.text.trim();
      store.updateSupplier(s);
    }
    Navigator.pop(context);
  }
}
