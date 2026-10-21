import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/disposal.dart';
import '../models/grocery_category.dart';
import '../models/stock_batch.dart';
import '../services/disposal_excel.dart';
import '../services/pdf_service.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';
import '../widgets/product_name_field.dart';

/// İmha Tutanağı (SA.08-F.01): bir kez şablon oluşturulur, şablondan
/// ayrı formlar doldurulup kaydedilir, PDF alınır. Stok giriş tarihleri
/// partilerden otomatik gelir; imha miktarı istenirse stoktan düşer.
class DisposalScreen extends StatefulWidget {
  const DisposalScreen({super.key});

  @override
  State<DisposalScreen> createState() => _DisposalScreenState();
}

class _DisposalScreenState extends State<DisposalScreen> {
  int _tab = 0; // 0 = Formlar, 1 = Şablon

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('İmha Tutanağı'),
        actions: [
          if (_tab == 0)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Şablondan yeni form',
              onPressed: () => _openForm(context, null),
            ),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(context, null),
              icon: const Icon(Icons.add),
              label: const Text('Yeni Form'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                    value: 0,
                    label: Text('Formlar'),
                    icon: Icon(Icons.description_outlined,
                        size: 16)),
                ButtonSegment(
                    value: 1,
                    label: Text('Şablon'),
                    icon: Icon(Icons.settings_outlined,
                        size: 16)),
              ],
              selected: {_tab},
              onSelectionChanged: (s) =>
                  setState(() => _tab = s.first),
            ),
          ),
          Expanded(
            child: _tab == 0
                ? _formsList(context, store)
                : _TemplateEditor(
                    key: ValueKey(store
                        .disposalTemplate.hashCode),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _formsList(BuildContext context, AppStore store) {
    final forms = store.disposalForms;
    if (forms.isEmpty) {
      return const EmptyState(
        icon: Icons.description_outlined,
        title: 'Form yok',
        subtitle:
            'Şablonu bir kez ayarlayın, sonra "Yeni Form" ile tutanak doldurun.',
      );
    }
    return ListView.builder(
      itemCount: forms.length,
      itemBuilder: (ctx, i) {
        final f = forms[i];
        final first = f.lines.isNotEmpty
            ? f.lines.first.productName
            : '(boş)';
        return Card(
          margin:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: Icon(
              f.stockDeducted
                  ? Icons.check_circle
                  : Icons.pending_actions,
              color: f.stockDeducted
                  ? Colors.green
                  : Colors.orange,
            ),
            title: Text(
              '${f.docNo} • $first${f.lines.length > 1 ? ' +${f.lines.length - 1}' : ''}',
              style:
                  const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
                '${_fmtDay(f.createdAt)} • ${f.lines.length} kalem • ${f.toplamBedel.toStringAsFixed(0)} ₺${f.stockDeducted ? ' • stoktan düşüldü' : ''}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.grid_on, size: 20),
                  tooltip: 'Şirket Excel formunda indir',
                  onPressed: () => _exportExcelForm(context, f),
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf,
                      size: 20),
                  tooltip: 'PDF yazdır/paylaş',
                  onPressed: () => _printForm(context, f),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: 'Düzenle',
                  onPressed: () => _openForm(context, f),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Sil',
                  onPressed: () =>
                      _confirmDelete(context, f.id),
                ),
              ],
            ),
            onTap: () => _openForm(context, f),
          ),
        );
      },
    );
  }

  void _openForm(BuildContext context, DisposalForm? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DisposalFormSheet(existing: existing),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Form silinsin mi?'),
        content: const Text(
            'Arşivden kaldırılır. Stok hareketi geri alınmaz.'),
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
      await context.read<AppStore>().deleteDisposalForm(id);
    }
  }

  Future<void> _printForm(
      BuildContext context, DisposalForm f) async {    String d(DateTime? x) => x == null
        ? '-'
        : '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.${x.year}';
    try {
      await PdfService.shareDisposalPdf(
        header: {
          'docNo': f.docNo,
          'revNo': f.revNo,
          'revDate': f.revDate == null ? '-' : d(f.revDate),
          'createdAt': d(f.createdAt),
        },
        lines: f.lines
            .map((l) => {
                  'urun': l.productName,
                  'miktar':
                      '${l.quantity.toStringAsFixed(l.quantity >= 100 ? 0 : 1)} ${StockUnitX.fromKey(l.unitKey).abbreviation}',
                  'uretim': d(l.uretimTarihi),
                  'giris': d(l.dolapGirisTarihi),
                  'skt': d(l.skt),
                  'gun': l.sktGunFarki > 0
                      ? '${l.sktGunFarki} gün'
                      : '-',
                  'bozulma': l.bozulma,
                  'neden': l.imhaNedeni,
                  'bedel':
                      '${l.tahminiBedel.toStringAsFixed(0)} TL',
                })
            .toList(),
        sections: {
          'uygunsuzluk': f.uygunsuzlukNedenleri,
          'gerceklesen': f.gerceklesenFaaliyet,
          'planlanan': f.planlananFaaliyet,
          'asci': f.asciAdi,
          'yonetici': f.yoneticiAdi,
          'bolge': f.bolgeAdi,
          'imzaTarihi':
              f.imzaTarihi == null ? '' : d(f.imzaTarihi),
          'toplam':
              '${f.toplamBedel.toStringAsFixed(0)} TL',
        },
        filename: 'imha-tutanagi.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF oluşturulamadı: $e')),
        );
      }
    }
  }

  String _fmtDay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  /// Şirket Excel şablonunu verilerle doldurup indirir/paylaşır.
  /// Biçim (birleştirme, logo, stiller) birebir korunur.
  Future<void> _exportExcelForm(
      BuildContext context, DisposalForm f) async {
    try {
      final tpl = await rootBundle
          .load('assets/imha_tutanak_sablonu.xlsx');
      final bytes = await buildFilledDisposalExcel(
        templateBytes: tpl.buffer.asUint8List(),
        form: f,
      );
      final extra =
          f.lines.length > 7 ? ' (ilk 7 satır)' : '';
      await Share.shareXFiles(
        [
          XFile.fromData(bytes,
              name: 'imha-tutanagi.xlsx',
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        ],
        text: 'İmha Tutanağı (${f.docNo})$extra',
      );
      if (context.mounted && f.lines.length > 7) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Excel formda 7 satır var: ilk 7 ürün yazıldı, tamamı PDF’te.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel oluşturulamadı: $e')),
        );
      }
    }
  }
}

/// Şablon düzenleyici: bir kez ayarlanır, yeni formlara varsayılan gelir.
class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor({super.key});

  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  late final TextEditingController _doc;
  late final TextEditingController _rev;
  late final TextEditingController _asci;
  late final TextEditingController _yonetici;
  late final TextEditingController _bolge;
  late final TextEditingController _neden;
  late final TextEditingController _uygunsuzluk;
  DateTime? _revDate;

  @override
  void initState() {
    super.initState();
    final t = context.read<AppStore>().disposalTemplate;
    _doc = TextEditingController(text: t.docNo);
    _rev = TextEditingController(text: t.revNo);
    _asci = TextEditingController(text: t.asciAdi);
    _yonetici = TextEditingController(text: t.yoneticiAdi);
    _bolge = TextEditingController(text: t.bolgeAdi);
    _neden = TextEditingController(text: t.defaultImhaNedeni);
    _uygunsuzluk =
        TextEditingController(text: t.defaultUygunsuzluk);
    _revDate = t.revDate;
  }

  @override
  void dispose() {
    _doc.dispose();
    _rev.dispose();
    _asci.dispose();
    _yonetici.dispose();
    _bolge.dispose();
    _neden.dispose();
    _uygunsuzluk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
            'Şablon bir kez ayarlanır. "Yeni Form" her zaman bu değerlerle açılır; formda yine değiştirilebilir.'),
        const SizedBox(height: 12),
        TextField(
            controller: _doc,
            decoration: const InputDecoration(
                labelText: 'Doküman No',
                border: OutlineInputBorder(),
                isDense: true)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                  controller: _rev,
                  decoration: const InputDecoration(
                      labelText: 'Revizyon No',
                      border: OutlineInputBorder(),
                      isDense: true)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: _revDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (p != null) setState(() => _revDate = p);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Revizyon Tarihi',
                      border: OutlineInputBorder(),
                      isDense: true),
                  child: Text(_revDate == null
                      ? 'Seçilmedi'
                      : '${_revDate!.day}.${_revDate!.month}.${_revDate!.year}'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
            controller: _asci,
            decoration: const InputDecoration(
                labelText: 'Aşçıbaşı / Sorumlu (varsayılan)',
                border: OutlineInputBorder(),
                isDense: true)),
        const SizedBox(height: 8),
        TextField(
            controller: _yonetici,
            decoration: const InputDecoration(
                labelText: 'İşletme Yöneticisi (varsayılan)',
                border: OutlineInputBorder(),
                isDense: true)),
        const SizedBox(height: 8),
        TextField(
            controller: _bolge,
            decoration: const InputDecoration(
                labelText: 'Bölge Müdürü (varsayılan)',
                border: OutlineInputBorder(),
                isDense: true)),
        const SizedBox(height: 8),
        TextField(
            controller: _neden,
            decoration: const InputDecoration(
                labelText: 'Varsayılan İmha Nedeni',
                border: OutlineInputBorder(),
                isDense: true),
            maxLines: 2),
        const SizedBox(height: 8),
        TextField(
            controller: _uygunsuzluk,
            decoration: const InputDecoration(
                labelText: 'Varsayılan Uygunsuzluk Nedeni',
                border: OutlineInputBorder(),
                isDense: true),
            maxLines: 2),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            await context.read<AppStore>().saveDisposalTemplate(
                  DisposalTemplate(
                    docNo: _doc.text.trim().isEmpty
                        ? 'SA.08-F.01'
                        : _doc.text.trim(),
                    revNo: _rev.text.trim(),
                    revDate: _revDate,
                    asciAdi: _asci.text.trim(),
                    yoneticiAdi: _yonetici.text.trim(),
                    bolgeAdi: _bolge.text.trim(),
                    defaultImhaNedeni: _neden.text.trim(),
                    defaultUygunsuzluk:
                        _uygunsuzluk.text.trim(),
                  ),
                );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Şablon kaydedildi.')),
              );
            }
          },
          child: const Text('Şablonu Kaydet'),
        ),
      ],
    );
  }
}

/// Form doldurma: ürün satırları + bölümler + imzalar + stoktan düş + yazdır.
class DisposalFormSheet extends StatefulWidget {
  final DisposalForm? existing;
  const DisposalFormSheet({super.key, required this.existing});

  @override
  State<DisposalFormSheet> createState() => _DisposalFormSheetState();
}

class _DisposalFormSheetState extends State<DisposalFormSheet> {
  late DisposalForm _form;
  bool _isNew = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing == null) {
      final t = context.read<AppStore>().disposalTemplate;
      _form = DisposalForm.fromTemplate(t);
      _isNew = true;
    } else {
      _form = widget.existing!;
    }
  }

  String _d(DateTime? x) => x == null
      ? 'Seçilmedi'
      : '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.${x.year}';

  Future<DateTime?> _pick(DateTime? initial) => showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
      );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
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
            Row(
              children: [
                Expanded(
                  child: Text(
                      _isNew
                          ? 'Yeni İmha Tutanağı'
                          : 'Tutanak Düzenle',
                      style:
                          Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  icon: const Icon(Icons.grid_on),
                  tooltip:
                      'Şirket Excel formunda indir (.xlsx)',
                  onPressed: () => _exportExcel(context),
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'PDF yazdır/paylaş',
                  onPressed: () => _print(context),
                ),
              ],
            ),
            Text('${_form.docNo} • Rev ${_form.revNo}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('Ürünler (${_form.lines.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    final t =
                        store.disposalTemplate;
                    _form.lines.add(DisposalLine(
                      imhaNedeni: t.defaultImhaNedeni,
                    ));
                  }),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Satır Ekle'),
                ),
              ],
            ),
            for (int i = 0; i < _form.lines.length; i++)
              _lineCard(context, store, i),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(
                  text: _form.uygunsuzlukNedenleri)
                ..selection = TextSelection.collapsed(
                    offset: _form
                        .uygunsuzlukNedenleri.length),
              decoration: const InputDecoration(
                  labelText: 'Uygunsuzluğun Nedenleri',
                  border: OutlineInputBorder(),
                  isDense: true),
              maxLines: 2,
              onChanged: (v) =>
                  _form.uygunsuzlukNedenleri = v,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(
                  text: _form.gerceklesenFaaliyet)
                ..selection = TextSelection.collapsed(
                    offset:
                        _form.gerceklesenFaaliyet.length),
              decoration: const InputDecoration(
                  labelText:
                      'Gerçekleşen Düzeltici Faaliyet',
                  border: OutlineInputBorder(),
                  isDense: true),
              maxLines: 2,
              onChanged: (v) =>
                  _form.gerceklesenFaaliyet = v,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(
                  text: _form.planlananFaaliyet)
                ..selection = TextSelection.collapsed(
                    offset:
                        _form.planlananFaaliyet.length),
              decoration: const InputDecoration(
                  labelText:
                      'Planlanan Düzeltici Faaliyet',
                  border: OutlineInputBorder(),
                  isDense: true),
              maxLines: 2,
              onChanged: (v) =>
                  _form.planlananFaaliyet = v,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _nameField(
                        'Aşçıbaşı / Sorumlu',
                        _form.asciAdi,
                        (v) => _form.asciAdi = v)),
                const SizedBox(width: 8),
                Expanded(
                    child: _nameField(
                        'İşletme Yöneticisi',
                        _form.yoneticiAdi,
                        (v) =>
                            _form.yoneticiAdi = v)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _nameField(
                        'Bölge Müdürü',
                        _form.bolgeAdi,
                        (v) => _form.bolgeAdi = v)),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final p =
                          await _pick(_form.imzaTarihi);
                      if (p != null) {
                        setState(
                            () => _form.imzaTarihi = p);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'İmza Tarihi',
                          border: OutlineInputBorder(),
                          isDense: true),
                      child: Text(_d(_form.imzaTarihi)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_form.stockDeducted)
              OutlinedButton.icon(
                onPressed: _form.lines.isEmpty
                    ? null
                    : () => _deductStock(context),
                icon: const Icon(
                    Icons.inventory_2_outlined),
                label: const Text(
                    'İmha miktarlarını stoktan düş'),
              )
            else
              const Card(
                color: Color(0xFFE8F5E9),
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.check_circle,
                      color: Colors.green),
                  title: Text('Stoktan düşüldü',
                      style: TextStyle(fontSize: 13)),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Kapat'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
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

  Widget _nameField(String label, String initial,
      ValueChanged<String> onChanged) {
    return TextField(
      controller: TextEditingController(text: initial)
        ..selection =
            TextSelection.collapsed(offset: initial.length),
      decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true),
      onChanged: onChanged,
    );
  }

  Widget _lineCard(
      BuildContext context, AppStore store, int index) {
    final line = _form.lines[index];
    final matched = line.itemId != null
        ? store.itemById(line.itemId!)
        : null;
    final List<StockBatch> batches = line.itemId != null
        ? store.batchesFor(line.itemId!)
        : <StockBatch>[];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ProductNameField(
                    label: 'Ürün adı',
                    initialText: line.productName,
                    onChanged: (text, match) =>
                        setState(() {
                      line.productName = text.trim();
                      if (match != null) {
                        final found = store
                            .itemByName(match.name);
                        if (found != null) {
                          line.itemId = found.id;
                          line.unitKey =
                              found.unit.key;
                          line.dolapGirisTarihi ??=
                              store.oldestEntryDate(
                                  found.id);
                        }
                      }
                    }),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20),
                  tooltip: 'Satırı sil',
                  onPressed: () => setState(
                      () => _form.lines.removeAt(index)),
                ),
              ],
            ),
            if (matched != null)
              Padding(
                padding:
                    const EdgeInsets.only(top: 4),
                child: Text(
                  'Stok: ${matched.formattedStock()} eşleşti.',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.green),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<
                      String>(
                    initialValue: line.unitKey,
                    decoration: const InputDecoration(
                        labelText: 'Birim',
                        border: OutlineInputBorder(),
                        isDense: true),
                    items: StockUnit.values
                        .map((u) => DropdownMenuItem(
                            value: u.key,
                            child: Text(u.displayName)))
                        .toList(),
                    onChanged: (v) => setState(
                        () => line.unitKey = v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(
                        text: line.quantity.toStringAsFixed(
                            line.quantity >= 100
                                ? 0
                                : 1))
                      ..selection =
                          TextSelection.collapsed(
                              offset: line.quantity
                                  .toStringAsFixed(
                                      line.quantity >=
                                              100
                                          ? 0
                                          : 1)
                                  .length),
                    keyboardType: const TextInputType
                        .numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Miktar',
                        border: OutlineInputBorder(),
                        isDense: true),
                    onChanged: (v) {
                      final n = double.tryParse(
                          v.replaceAll(',', '.'));
                      if (n != null && n >= 0) {
                        line.quantity = n;
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(
                        text: line.tahminiBedel
                            .toStringAsFixed(0))
                      ..selection =
                          TextSelection.collapsed(
                              offset: line.tahminiBedel
                                  .toStringAsFixed(0)
                                  .length),
                    keyboardType: const TextInputType
                        .numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Bedel (₺)',
                        border: OutlineInputBorder(),
                        isDense: true),
                    onChanged: (v) {
                      final n = double.tryParse(
                          v.replaceAll(',', '.'));
                      if (n != null && n >= 0) {
                        line.tahminiBedel = n;
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (batches.isNotEmpty)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                    labelText:
                        'Stok girişi (tarih + miktar)',
                    border: OutlineInputBorder(),
                    isDense: true),
                items: [
                  for (final b in batches)
                    DropdownMenuItem(
                        value:
                            '${b.entryDate.toIso8601String()}|${b.quantity}',
                        child: Text(
                            '${_d(b.entryDate)} • ${b.quantity.toStringAsFixed(0)} (${b.source})',
                            overflow:
                                TextOverflow.ellipsis)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  final parts = v.split('|');
                  setState(() {
                    line.dolapGirisTarihi =
                        DateTime.tryParse(parts[0]);
                  });
                },
              )
            else
              _dateRow(
                  'Dolaba Giriş Tarihi',
                  line.dolapGirisTarihi,
                  (d) => setState(
                      () => line.dolapGirisTarihi = d)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _dateRow(
                        'Üretim Tarihi',
                        line.uretimTarihi,
                        (d) => setState(
                            () => line.uretimTarihi = d))),
                const SizedBox(width: 8),
                Expanded(
                    child: _dateRow(
                        'SKT',
                        line.skt,
                        (d) => setState(
                            () => line.skt = d))),
              ],
            ),
            if (line.sktGunFarki > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'SKT ${line.sktGunFarki} gün geçmiş.',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                      fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller:
                  TextEditingController(text: line.bozulma)
                    ..selection =
                        TextSelection.collapsed(
                            offset:
                                line.bozulma.length),
              decoration: const InputDecoration(
                  labelText: 'Bozulma varsa, nedir?',
                  border: OutlineInputBorder(),
                  isDense: true),
              onChanged: (v) => line.bozulma = v,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(
                  text: line.imhaNedeni)
                ..selection =
                    TextSelection.collapsed(
                        offset:
                            line.imhaNedeni.length),
              decoration: const InputDecoration(
                  labelText: 'İmha Nedeni',
                  border: OutlineInputBorder(),
                  isDense: true),
              onChanged: (v) => line.imhaNedeni = v,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateRow(String label, DateTime? value,
      ValueChanged<DateTime?> onPick) {
    return InkWell(
      onTap: () async {
        final p = await _pick(value);
        if (p != null) onPick(p);
      },
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true),
        child: Text(_d(value)),
      ),
    );
  }

  Future<void> _save() async {
    final store = context.read<AppStore>();
    if (_isNew) {
      await store.addDisposalForm(_form);
      _isNew = false;
    } else {
      await store.updateDisposalForm(_form);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tutanak kaydedildi.')),
      );
      setState(() {});
    }
  }

  Future<void> _deductStock(BuildContext context) async {
    final store = context.read<AppStore>();
    await _save();
    await store.deductDisposalStock(_form.id);
    if (!context.mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Miktarlar stoktan düşüldü.')),
    );
  }

  Future<void> _exportExcel(BuildContext context) async {
    await _save();
    try {
      final tpl = await rootBundle
          .load('assets/imha_tutanak_sablonu.xlsx');
      final bytes = await buildFilledDisposalExcel(
        templateBytes: tpl.buffer.asUint8List(),
        form: _form,
      );
      await Share.shareXFiles(
        [
          XFile.fromData(bytes,
              name: 'imha-tutanagi.xlsx',
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        ],
        text: 'İmha Tutanağı (${_form.docNo})',
      );
      if (context.mounted && _form.lines.length > 7) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Excel formda 7 satır var: ilk 7 ürün yazıldı, tamamı PDF’te.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel oluşturulamadı: $e')),
        );
      }
    }
  }

  Future<void> _print(BuildContext context) async {    await _save();
    final f = _form;
    String d(DateTime? x) => x == null
        ? '-'
        : '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.${x.year}';
    try {
      await PdfService.shareDisposalPdf(
        header: {
          'docNo': f.docNo,
          'revNo': f.revNo,
          'revDate': f.revDate == null ? '-' : d(f.revDate),
          'createdAt': d(f.createdAt),
        },
        lines: f.lines
            .map((l) => {
                  'urun': l.productName,
                  'miktar':
                      '${l.quantity.toStringAsFixed(l.quantity >= 100 ? 0 : 1)} ${StockUnitX.fromKey(l.unitKey).abbreviation}',
                  'uretim': d(l.uretimTarihi),
                  'giris': d(l.dolapGirisTarihi),
                  'skt': d(l.skt),
                  'gun': l.sktGunFarki > 0
                      ? '${l.sktGunFarki} gün'
                      : '-',
                  'bozulma': l.bozulma,
                  'neden': l.imhaNedeni,
                  'bedel':
                      '${l.tahminiBedel.toStringAsFixed(0)} TL',
                })
            .toList(),
        sections: {
          'uygunsuzluk': f.uygunsuzlukNedenleri,
          'gerceklesen': f.gerceklesenFaaliyet,
          'planlanan': f.planlananFaaliyet,
          'asci': f.asciAdi,
          'yonetici': f.yoneticiAdi,
          'bolge': f.bolgeAdi,
          'imzaTarihi':
              f.imzaTarihi == null ? '' : d(f.imzaTarihi),
          'toplam':
              '${f.toplamBedel.toStringAsFixed(0)} TL',
        },
        filename: 'imha-tutanagi.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF oluşturulamadı: $e')),
        );
      }
    }
  }
}
