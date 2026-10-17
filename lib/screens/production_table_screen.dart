import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/grocery_category.dart';
import '../models/menu_entry.dart';
import '../models/recipe.dart';
import '../services/excel_parser.dart';
import '../services/pdf_service.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';
import '../widgets/order_qty_sheet.dart';

/// Üretim tablosu — iki yöntem:
/// 1) Manuel: satır satır yemek + kişi sayısı, stoktan düş.
/// 2) Haftalık Menü: Excel/PDF menü içe aktar → haftalık tabloya yansır.
///    Her yemeğin yanında "Reçete düzenle", reçetesi eksikse uyarı.
///    Sağ üstte kişi sayısı + Üret butonu; Üret toplam malzemeyi gösterir.
///    Ardından gün-gün veya haftalık stoktan düşme.
class ProductionTableScreen extends StatefulWidget {
  const ProductionTableScreen({super.key});

  @override
  State<ProductionTableScreen> createState() => _ProductionTableScreenState();
}

class _RowItem {
  String recipeId;
  int servings;
  _RowItem({required this.recipeId, required this.servings});
}

class _ProductionTableScreenState extends State<ProductionTableScreen> {
  int _mode = 1; // 0 = Manuel, 1 = Haftalık Menü
  final List<_RowItem> _items = [];
  bool _seeded = false;

  // Haftalık mod durumu
  int _week = 0;
  late final TextEditingController _globalServingsCtrl;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _globalServingsCtrl = TextEditingController(text: '100');
  }

  @override
  void dispose() {
    _globalServingsCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seeded) {
      _seeded = true;
      final store = context.read<AppStore>();
      for (final r in store.recipes) {
        _items.add(_RowItem(recipeId: r.id, servings: r.servingsDefault));
      }
    }
  }

  int get _globalServings =>
      int.tryParse(_globalServingsCtrl.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Üretim Planı / Reçete Tablosu'),
        actions: [
          if (_mode == 0) ...[
            IconButton(
              icon: const Icon(Icons.playlist_add),
              tooltip: 'Eksik yemekleri ekle (tüm tarifler)',
              onPressed: () => _addAllMissing(),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Satır ekle',
              onPressed: () => _addRow(context),
            ),
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Tabloyu temizle',
              onPressed: _items.isEmpty
                  ? null
                  : () => setState(() => _items.clear()),
            ),
          ] else ...[
            IconButton(
              icon: _importing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_file),
              tooltip: 'Haftalık menü içe aktar (Excel)',
              onPressed: _importing ? null : () => _importMenu(context),
            ),
          ],
        ],
      ),
      floatingActionButton: _mode == 0
          ? FloatingActionButton.extended(
              onPressed:
                  _items.isEmpty ? null : () => _runProduction(context),
              icon: const Icon(Icons.checklist_rtl),
              label: const Text('Stoktan Düş'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                    value: 0,
                    label: Text('Manuel Üretim'),
                    icon: Icon(Icons.edit, size: 16)),
                ButtonSegment(
                    value: 1,
                    label: Text('Haftalık Menü'),
                    icon: Icon(Icons.calendar_month, size: 16)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
          Expanded(
            child: _mode == 0
                ? _buildManual(context)
                : _buildWeekly(context),
          ),
        ],
      ),
    );
  }

  // ================= MANUEL MOD (mevcut davranış) =================

  Widget _buildManual(BuildContext context) {
    final store = context.watch<AppStore>();
    bool hasShortageOverall = false;
    for (final it in _items) {
      final recipe = store.recipeById(it.recipeId);
      if (recipe == null) continue;
      final preview = store.previewProduction(recipe, it.servings);
      if (preview.any((r) => r.item.currentStock - r.needed < 0)) {
        hasShortageOverall = true;
        break;
      }
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Yemek',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 5,
                  child: Text('Reçete (ürün • porsiyon miktarı)',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                SizedBox(width: 8),
                SizedBox(
                  width: 150,
                  child: Text('Kişi sayısı',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_items.length} satır • Reçeteyi satır içinde düzenleyip Kaydet’e basın; aynı yemek yeniden eklenince kayıtlı reçete gelir.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.list_alt,
                            size: 48, color: Color(0xFF6C7280)),
                        const SizedBox(height: 12),
                        const Text('Henüz üretim satırı yok'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton.tonal(
                              onPressed: () => _addRow(context),
                              child: const Text('Satır Ekle'),
                            ),
                            FilledButton(
                              onPressed: () => _addAllMissing(),
                              child: const Text('Tüm Yemekleri Ekle'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) => _RowCard(
                      key: ValueKey(
                          '${_items[i].recipeId}#$i-${_items.length}'),
                      recipeId: _items[i].recipeId,
                      servings: _items[i].servings,
                      onRemove: () =>
                          setState(() => _items.removeAt(i)),
                      onServingsChanged: (newVal) => setState(
                          () => _items[i].servings = newVal),
                    ),
                  ),
          ),
          if (hasShortageOverall)
            const Card(
              color: Color(0xFFFFF3E0),
              child: ListTile(
                leading: Icon(Icons.warning, color: Colors.orange),
                title: Text(
                    'Bazı satırlarda ürün yetersiz — üretim yine yapılır, stok sıfıra sabitlenir.'),
              ),
            ),
        ],
      ),
    );
  }

  void _addAllMissing() {
    final store = context.read<AppStore>();
    setState(() {
      final existing = _items.map((e) => e.recipeId).toSet();
      for (final r in store.recipes) {
        if (!existing.contains(r.id)) {
          _items.add(_RowItem(recipeId: r.id, servings: r.servingsDefault));
        }
      }
    });
  }

  Future<void> _addRow(BuildContext context) async {
    final store = context.read<AppStore>();
    final picked = await showDialog<Recipe>(
      context: context,
      builder: (ctx) => _RecipePickerDialog(recipes: store.recipes),
    );
    if (picked != null && mounted) {
      setState(() => _items.add(_RowItem(
            recipeId: picked.id,
            servings: picked.servingsDefault,
          )));
    }
  }

  void _runProduction(BuildContext context) {
    final store = context.read<AppStore>();
    for (final item in _items) {
      final recipe = store.recipeById(item.recipeId);
      if (recipe == null) continue;
      store.updateRecipe(recipe);
      final preview = store.previewProduction(recipe, item.servings);
      final totals = <String, double>{};
      for (final row in preview) {
        totals[row.item.id] = row.needed;
      }
      store.produceCustom(
        recipe: recipe,
        servings: item.servings,
        totals: totals,
      );
    }
    if (context.mounted) {
      final names = _items
          .map((i) => store.recipeById(i.recipeId)?.name ?? '?')
          .join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Üretim tamamlandı: $names')),
      );
      _showStockAlerts(context);
    }
  }

  // ================= HAFTALIK MENÜ MODU =================

  Widget _buildWeekly(BuildContext context) {
    final store = context.watch<AppStore>();
    final missing =
        store.menuEntriesMissingRecipe(_week).length;
    final weekEntries =
        store.weeklyMenu.where((e) => e.weekIndex == _week).toList();
    final global = _globalServings;
    final globalValid = global >= 1 && global <= 10000;
    return Column(
      children: [
        // Hafta seçici
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: List.generate(4, (w) {
              final count = store.weeklyMenu
                  .where((e) => e.weekIndex == w)
                  .length;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ChoiceChip(
                  label: Text(
                      '${MenuEntry.weeks[w]}${count > 0 ? ' ($count)' : ''}'),
                  selected: _week == w,
                  onSelected: (_) => setState(() => _week = w),
                ),
              );
            }),
          ),
        ),
        // Sağ üst: toplam kişi sayısı + tümüne uygula + Üret + Arşiv
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${MenuEntry.weeks[_week]} • ${weekEntries.length} öğün',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            if (missing > 0)
                              Row(
                                children: [
                                  const Icon(Icons.warning,
                                      size: 14, color: Colors.red),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '$missing öğünün reçetesi eksik!',
                                      style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              )
                            else if (weekEntries.isNotEmpty)
                              const Text('Tüm reçeteler hazır.',
                                  style: TextStyle(
                                      color: Colors.green, fontSize: 12)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _globalServingsCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: 'Kişi sayısı',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            errorText: globalValid
                                ? null
                                : '1-10000 arası',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: (weekEntries.isEmpty || !globalValid)
                            ? null
                            : () => _showWeekTotals(context),
                        icon: const Icon(Icons.factory, size: 16),
                        label: const Text('Üret'),
                        style: FilledButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF1B5E20)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (!globalValid || weekEntries.isEmpty)
                              ? null
                              : () => _applyGlobalToWeek(global),
                          icon: const Icon(Icons.groups, size: 16),
                          label: const Text(
                              'Sayıyı tüm haftaya yaz'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: weekEntries.isEmpty
                              ? null
                              : () => _saveArchive(context),
                          icon: const Icon(Icons.archive, size: 16),
                          label: const Text('Arşive Kaydet'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openArchive(context),
                          icon:
                              const Icon(Icons.history, size: 16),
                          label: Text(
                              'Arşiv (${store.productionArchives.length})'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _importing ? null : () => _importMenu(context),
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('İçe Aktar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addMenuEntry(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Öğün Ekle'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: weekEntries.isEmpty
                      ? null
                      : () => _clearWeek(context),
                  icon: const Icon(Icons.delete_sweep, size: 16),
                  label: const Text('Temizle'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: weekEntries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month,
                            size: 48,
                            color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                            'Bu haftada menü yok.\nExcel’den içe aktarın veya Menü Programı’ndan ekleyin.',
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: 7,
                  itemBuilder: (ctx, d) => _WeekDayCard(
                      dayIndex: d, weekIndex: _week),
                ),
        ),
      ],
    );
  }

  /// Sağ üstteki sayı tüm haftanın günlerine yazılır.
  Future<void> _applyGlobalToWeek(int global) async {
    final store = context.read<AppStore>();
    await store.setProdServingsWeek(_week, global);
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${MenuEntry.weeks[_week]} tüm günlere $global kişi yazıldı.')),
      );
    }
  }

  Future<void> _saveArchive(BuildContext context) async {
    final store = context.read<AppStore>();
    final archive = await store.archiveWeekProduction(_week);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Arşive kaydedildi: ${archive.weekLabel} (${archive.totals.length} malzeme).')),
      );
      setState(() {});
    }
  }

  void _openArchive(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ArchiveSheet(),
    );
  }

  /// Elle öğün ekleme (Menü Programı kalktığı için burada).
  Future<void> _addMenuEntry(BuildContext context) async {
    final store = context.read<AppStore>();
    if (store.recipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Önce Reçeteler’den tarif ekleyin.')),
      );
      return;
    }
    int day = 0;
    String meal = MenuEntry.meals[1];
    Recipe? picked;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setD) {
          return AlertDialog(
            title: const Text('Öğün Ekle'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: day,
                    decoration:
                        const InputDecoration(labelText: 'Gün'),
                    items: List.generate(
                        7,
                        (i) => DropdownMenuItem(
                            value: i,
                            child:
                                Text(MenuEntry.days[i]))),
                    onChanged: (v) => setD(() => day = v!),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: meal,
                    decoration:
                        const InputDecoration(labelText: 'Öğün'),
                    items: MenuEntry.meals
                        .map((m) => DropdownMenuItem(
                            value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) => setD(() => meal = v!),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final r = await showDialog<Recipe>(
                        context: ctx,
                        builder: (_) => _RecipePickerDialog(
                            recipes: store.recipes),
                      );
                      if (r != null) setD(() => picked = r);
                    },
                    icon: const Icon(Icons.search, size: 16),
                    label: Text(picked?.name ?? 'Yemek seç'),
                  ),
                  Text(
                    'Kişi sayısı o günün kutusundan alınır (şu an: ${store.prodServingsFor(_week, day)}).',
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Vazgeç')),
              FilledButton(
                  onPressed: picked == null
                      ? null
                      : () => Navigator.pop(ctx, true),
                  child: const Text('Ekle')),
            ],
          );
        });
      },
    );
    if (ok != true || picked == null || !mounted) return;
    await store.addMenuEntry(MenuEntry(
      weekIndex: _week,
      dayIndex: day,
      meal: meal,
      recipeId: picked!.id,
      servings: store.prodServingsFor(_week, day),
    ));
    await store.generateGroceryList();
    setState(() {});
  }

  Future<void> _clearWeek(BuildContext context) async {
    final store = context.read<AppStore>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${MenuEntry.weeks[_week]} temizlensin mi?'),
        content: const Text(
            'Bu haftadaki tüm menü satırları silinir. Tarifler ve stok etkilenmez.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Temizle')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    store.weeklyMenu.removeWhere((e) => e.weekIndex == _week);
    await store.save();
    await store.generateGroceryList();
    setState(() {});
  }

  // ---------- Excel/PDF içe aktarma ----------

  Future<void> _importMenu(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv', 'pdf'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final name = file.name.toLowerCase();
    if (name.endsWith('.pdf')) {
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('PDF içe aktarma'),
          content: const Text(
              'PDF menülerin otomatik okunması yakında eklenecek.\n\nŞimdilik lütfen menüyü Excel (.xlsx) olarak kaydedip 다시 deneyin — aynı içe aktarma düğmesi Excel’i haftalık tabloya yansıtır. Dilerseniz Menü Programı sekmesinden de elle ekleyebilirsiniz.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tamam')),
          ],
        ),
      );
      return;
    }
    final bytes = file.bytes;
    if (bytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Dosya okunamadı, tekrar deneyin.')),
        );
      }
      return;
    }
    setState(() => _importing = true);
    try {
      // Excel paketi xlsx/xls okur; csv gelirse Excel decode edemezse
      // basit virgül ayrımıyla ele al.
      List<ImportedMenuRow> rows;
      try {
        rows = parseWeeklyMenu(bytes,
            defaultServings: _globalServings >= 1
                ? _globalServings
                : 100);
      } catch (_) {
        rows = _parseCsvFallback(String.fromCharCodes(bytes));
      }
      if (rows.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '${file.name}: menü satırı bulunamadı. Gün (Pazartesi…) ve yemek adları içeren bir Excel yükleyin.')),
          );
        }
        return;
      }
      final store = context.read<AppStore>();
      int added = 0;
      int matched = 0;
      for (final r in rows) {
        final recipe = await store.findOrCreateRecipeByName(r.dish);
        if (recipe.ingredients.isNotEmpty) matched++;
        // Aynı gün+öğün+yemek varsa porsiyonu güncelle, yoksa ekle.
        MenuEntry? existing;
        try {
          existing = store.weeklyMenu.firstWhere((e) =>
              e.weekIndex == _week &&
              e.dayIndex == r.dayIndex &&
              e.meal == r.meal &&
              e.recipeId == recipe.id);
        } catch (_) {
          existing = null;
        }
        if (existing != null) {
          existing.servings = r.servings;
        } else {
          await store.addMenuEntry(MenuEntry(
            weekIndex: _week,
            dayIndex: r.dayIndex,
            meal: r.meal,
            recipeId: recipe.id,
            servings: r.servings,
          ));
        }
        added++;
      }
      await store.generateGroceryList();
      final missingCount =
          store.menuEntriesMissingRecipe(_week).length;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${file.name}: $added satır aktarıldı ($matched eşleşen reçete).${missingCount > 0 ? ' $missingCount öğünün reçetesi eksik — düzenleyin!' : ''}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      setState(() {});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İçe aktarma hatası: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  List<ImportedMenuRow> _parseCsvFallback(String text) {
    // Çok basit CSV: her satırda gün + yemek arar.
    final rows = <ImportedMenuRow>[];
    final lines = text.split(RegExp(r'[\r\n]+'));
    int day = -1;
    for (final line in lines) {
      final cells =
          line.split(RegExp(r'[;,|\t]')).map((s) => s.trim()).toList();
      if (cells.every((c) => c.isEmpty)) continue;
      final joined = cells.join(' | ');
      final lower = joined.toLowerCase();
      const dayKeys = [
        'pazartesi',
        'salı',
        'sali',
        'çarşamba',
        'carsamba',
        'perşembe',
        'persembe',
        'cumartesi',
        'cuma',
        'pazar'
      ];
      int? found;
      if (lower.contains('pazartesi')) {
        found = 0;
      } else if (lower.contains('salı') || lower.contains('sali')) {
        found = 1;
      } else if (lower.contains('çarşamba') ||
          lower.contains('carsamba')) {
        found = 2;
      } else if (lower.contains('perşembe') ||
          lower.contains('persembe')) {
        found = 3;
      } else if (lower.contains('cumartesi')) {
        found = 5;
      } else if (lower.contains('cuma')) {
        found = 4;
      } else if (lower.contains('pazar')) {
        found = 6;
      }
      // kullanılmayan değişken yok; gün bulunduysa güncelle.
      if (found != null) day = found;
      if (day < 0) continue;
      for (final c in cells) {
        if (c.length < 2) continue;
        if (RegExp(r'^[0-9\s.,]+$').hasMatch(c)) continue;
        final lc = c.toLowerCase();
        if (dayKeys.any((k) => lc == k)) continue;
        rows.add(ImportedMenuRow(
          dayIndex: day,
          meal: 'Öğle',
          dish: c,
          servings: 100,
        ));
      }
    }
    return rows;
  }

  // ---------- Üret: toplam malzeme + günlük/haftalık düş ----------

  Future<void> _showWeekTotals(BuildContext context) async {
    final store = context.read<AppStore>();
    final servings = store.prodServingsOfWeek(_week);
    final totals = store.menuWeekTotalsForDailyServings(_week);
    final missing = store.menuEntriesMissingRecipe(_week);
    if (totals.isEmpty && missing.isEmpty) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TotalsSheet(
        weekIndex: _week,
        servingsByDay: servings,
        totals: totals,
        missingCount: missing.length,
        onDeductDay: (day) async {
          await store.produceMenuDayForDaily(day, _week);
          if (context.mounted) {
            Navigator.pop(context);
            _showStockAlerts(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      '${MenuEntry.days[day]} üretimi stoktan düşüldü.')),
            );
          }
        },
        onDeductWeek: () async {
          await store.produceMenuWeekForDaily(_week);
          if (context.mounted) {
            Navigator.pop(context);
            _showStockAlerts(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      '${MenuEntry.weeks[_week]} tamamı stoktan düşüldü.')),
            );
          }
        },
      ),
    );
  }

  void _showStockAlerts(BuildContext context) {
    final store = context.read<AppStore>();
    final critical = store.criticalStockItems;
    final warning = store.warningStockItems;
    if (critical.isEmpty && warning.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stok Uyarıları'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final it in critical)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.error,
                          color: Colors.red, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${it.name} kritik stok! (kalan: ${it.formattedStock()})',
                          style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              for (final it in warning)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Colors.orange, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${it.name} azalan stok! (kalan: ${it.formattedStock()})',
                          style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}

/// Haftanın bir gününün kartı: yemekler + reçete düzenle + eksik uyarısı.
/// Kişi sayısı gün bazında düzenlenir; gün sonu stok kümülatif gösterilir.
class _WeekDayCard extends StatefulWidget {
  final int dayIndex;
  final int weekIndex;
  const _WeekDayCard(
      {required this.dayIndex, required this.weekIndex});

  @override
  State<_WeekDayCard> createState() => _WeekDayCardState();
}

class _WeekDayCardState extends State<_WeekDayCard> {
  late final TextEditingController _dayCtrl;
  bool _showEndStock = false;

  @override
  void initState() {
    super.initState();
    _dayCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final entries = store.menuForDay(widget.dayIndex, widget.weekIndex);
    if (entries.isEmpty) return const SizedBox.shrink();
    final dayServings =
        store.prodServingsFor(widget.weekIndex, widget.dayIndex);
    if (_dayCtrl.text != '$dayServings') {
      _dayCtrl.text = '$dayServings';
    }
    final dayTotals = store.menuDayTotalsForServings(
        widget.dayIndex, widget.weekIndex, dayServings);
    final endStock =
        store.endOfDayStock(widget.dayIndex, widget.weekIndex);
    final negCount =
        endStock.values.where((v) => v < 0).length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    MenuEntry.days[widget.dayIndex],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Text('${entries.length} öğün',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _dayCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'Kişi',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (v) => _commitDay(v),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n >= 1 && n <= 10000) {
                        store.setProdServings(
                            widget.weekIndex, widget.dayIndex, n);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => _deductDay(context, dayServings),
                  child: const Text('Günü Düş'),
                ),
              ],
            ),
            const Divider(),
            for (final e in entries)
              _MenuEntryTile(
                  entry: e,
                  weekIndex: widget.weekIndex,
                  servings: dayServings),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Günlük harcama ($dayServings kişi): ${_formatTotals(context, dayTotals)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () =>
                  setState(() => _showEndStock = !_showEndStock),
              child: Row(
                children: [
                  Icon(
                    _showEndStock
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 18,
                  ),
                  Expanded(
                    child: Text(
                      'Gün sonu stoğu (hafta başından kümülatif)${negCount > 0 ? ' — $negCount kalem eksiye düşüyor!' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: negCount > 0
                            ? Colors.red
                            : Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_showEndStock)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: negCount > 0
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: negCount > 0
                          ? Colors.red.shade200
                          : Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final en in _sortedEndStock(
                        context, endStock, dayTotals))
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 1),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                en.$2,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Text(
                              en.$3,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: en.$4,
                              ),
                            ),
                            if (en.$4 == Colors.red)
                              IconButton(
                                icon: const Icon(
                                    Icons.add_shopping_cart,
                                    size: 16),
                                tooltip: 'Sipariş Ver',
                                color: Colors.red,
                                padding: EdgeInsets.zero,
                                constraints:
                                    const BoxConstraints(),
                                onPressed: () {
                                  final store = context
                                      .read<AppStore>();
                                  final item =
                                      store.itemById(en.$1);
                                  if (item == null) return;
                                  final short =
                                      (dayTotals[en.$1] ?? 0) -
                                          item.currentStock;
                                  openOrderQtySheet(
                                    context,
                                    itemId: item.id,
                                    suggestedQty:
                                        suggestedTopUp(store,
                                            item.id,
                                            projectedShortfall:
                                                short > 0
                                                    ? short
                                                    : 0),
                                    reason:
                                        '${MenuEntry.days[widget.dayIndex]} sonu stok yetersiz kalıyor.',
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Gün sonu listesi: önce eksiye düşenler, sonra kalanlar (ada göre).
  /// Dönen kayıtlar: (itemId, ürün adı, "kalan metni", renk).
  List<(String, String, String, Color)> _sortedEndStock(
      BuildContext context,
      Map<String, double> endStock,
      Map<String, double> dayTotals) {
    final store = context.read<AppStore>();
    final rows = <(String, String, String, Color, double)>[];
    for (final id in dayTotals.keys) {
      final item = store.itemById(id);
      if (item == null) continue;
      final left = endStock[id] ?? item.currentStock;
      final Color c;
      if (left < 0) {
        c = Colors.red;
      } else if (left <= item.minThreshold) {
        c = Colors.red;
      } else if (left <= item.warnThreshold) {
        c = Colors.orange;
      } else {
        c = Colors.green.shade800;
      }
      rows.add((
        id,
        item.name,
        '${item.formatAmount(left < 0 ? 0 : left)}${left < 0 ? ' (eksik: ${item.formatAmount(-left)})' : ''}',
        c,
        left
      ));
    }
    rows.sort((a, b) => a.$5.compareTo(b.$5));
    return rows.map((r) => (r.$1, r.$2, r.$3, r.$4)).toList();
  }

  String _formatTotals(
      BuildContext context, Map<String, double> totals) {
    final store = context.read<AppStore>();
    if (totals.isEmpty) return '—';
    return totals.entries.map((en) {
      final item = store.itemById(en.key);
      if (item == null) return '?';
      return '${item.name}: ${item.formatAmount(en.value)}';
    }).join(' • ');
  }

  void _commitDay(String v) {
    final n = int.tryParse(v) ?? 100;
    context.read<AppStore>().setProdServings(
        widget.weekIndex, widget.dayIndex, n.clamp(1, 10000));
  }

  Future<void> _deductDay(BuildContext context, int servings) async {
    final store = context.read<AppStore>();
    await store.produceMenuDayForServings(
        widget.dayIndex, widget.weekIndex, servings);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${MenuEntry.days[widget.dayIndex]} ($servings kişi) stoktan düşüldü.')),
      );
    }
  }
}

/// Menü satırı: yemek adı + öğün + reçete düzenle.
/// Kişi sayısı globaldir (sağ üstteki tek kutu); burada düzenlenmez.
/// Reçetesi eksikse kırmızı uyarı rozeti.
class _MenuEntryTile extends StatefulWidget {
  final MenuEntry entry;
  final int weekIndex;
  final int servings;
  const _MenuEntryTile(
      {required this.entry,
      required this.weekIndex,
      required this.servings});

  @override
  State<_MenuEntryTile> createState() => _MenuEntryTileState();
}

class _MenuEntryTileState extends State<_MenuEntryTile> {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final recipe = store.recipeById(widget.entry.recipeId);
    final missing = recipe == null || recipe.ingredients.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        recipe?.name ?? 'Silinmiş tarif',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (missing)
                      const StatusBadge(
                          text: 'Reçete eksik!', color: Colors.red),
                  ],
                ),
                Text(
                  '${widget.entry.meal} • ${widget.servings} kişi',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (!missing)
                  Text(
                    recipe.ingredients.map((ing) {
                      final item = store.itemById(ing.itemId);
                      final n = item?.name ?? '?';
                      final u = item?.unit.abbreviation ?? '';
                      return '$n ${ing.amountPerServing.toStringAsFixed(ing.amountPerServing >= 100 ? 0 : 1)} $u';
                    }).join(' • '),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey.shade600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: recipe == null
                          ? null
                          : () => _editRecipe(context, recipe.id),
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('Reçete düzenle'),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: 'Öğünü sil',
                      onPressed: () => context
                          .read<AppStore>()
                          .deleteMenuEntry(widget.entry.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Chip(
            label: Text('${widget.servings} kişi'),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  void _editRecipe(BuildContext context, String recipeId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MenuRecipeEditSheet(recipeId: recipeId),
    );
  }
}

/// Menü içinden reçete düzenleme: ürün + 1 kişilik miktar.
/// Kaydet kalıcı olur (aynı yemek her yerde güncel reçeteyle gelir).
class _MenuRecipeEditSheet extends StatefulWidget {
  final String recipeId;
  const _MenuRecipeEditSheet({required this.recipeId});

  @override
  State<_MenuRecipeEditSheet> createState() =>
      _MenuRecipeEditSheetState();
}

class _MenuRecipeEditSheetState
    extends State<_MenuRecipeEditSheet> {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final recipe = store.recipeById(widget.recipeId);
    if (recipe == null) return const SizedBox.shrink();

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
            Text('Reçete düzenle — ${recipe.name}',
                style: Theme.of(context).textTheme.titleLarge),
            const Text('Miktarlar 1 kişilik (tek porsiyon) girilir.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            for (var i = 0; i < recipe.ingredients.length; i++)
              _EditLine(
                  recipe: recipe,
                  index: i,
                  onChanged: () => setState(() {}),
                  onDeleted: () => setState(
                      () => recipe.ingredients.removeAt(i))),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    if (store.inventory.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Önce stoklara ürün ekleyin.')),
                      );
                      return;
                    }
                    setState(() => recipe.ingredients.add(
                        RecipeIngredient(
                            itemId: store.inventory.first.id,
                            amountPerServing: 0)));
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Malzeme ekle'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () async {
                    await store.updateRecipe(recipe);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                '${recipe.name} reçetesi kaydedildi')),
                      );
                    }
                  },
                  child: const Text('Kaydet'),
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

class _EditLine extends StatefulWidget {
  final Recipe recipe;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onDeleted;
  const _EditLine(
      {required this.recipe,
      required this.index,
      required this.onChanged,
      required this.onDeleted});

  @override
  State<_EditLine> createState() => _EditLineState();
}

class _EditLineState extends State<_EditLine> {
  late TextEditingController _ctrl;

  RecipeIngredient get _ing =>
      widget.recipe.ingredients[widget.index];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: _ing.amountPerServing
            .toStringAsFixed(_ing.amountPerServing >= 100 ? 0 : 1));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (store.itemById(_ing.itemId) == null &&
        store.inventory.isNotEmpty) {
      _ing.itemId = store.inventory.first.id;
    }
    final item = store.itemById(_ing.itemId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: DropdownButtonFormField<String>(
              initialValue: _ing.itemId,
              decoration: const InputDecoration(
                  labelText: 'Ürün',
                  border: OutlineInputBorder(),
                  isDense: true),
              items: store.inventory
                  .map((it) => DropdownMenuItem(
                      value: it.id,
                      child: Text(
                          '${it.name} (${it.unit.abbreviation})',
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _ing.itemId = v);
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '1 kişilik',
                suffixText: item?.unit.abbreviation ?? '',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                final n =
                    double.tryParse(v.replaceAll(',', '.'));
                if (n != null && n >= 0) {
                  _ing.amountPerServing = n;
                  widget.onChanged();
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: widget.onDeleted,
          ),
        ],
      ),
    );
  }
}

/// Üret sonucu: toplam harcanan malzeme + günlük/haftalık düşme butonları.
class _TotalsSheet extends StatelessWidget {
  final int weekIndex;
  final Map<int, int> servingsByDay;
  final Map<String, double> totals;
  final int missingCount;
  final Future<void> Function(int day) onDeductDay;
  final Future<void> Function() onDeductWeek;

  const _TotalsSheet({
    required this.weekIndex,
    required this.servingsByDay,
    required this.totals,
    required this.missingCount,
    required this.onDeductDay,
    required this.onDeductWeek,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final entries = totals.entries.toList()
      ..sort((a, b) {
        final ia = store.itemById(a.key);
        final ib = store.itemById(b.key);
        return (ia?.name ?? '').compareTo(ib?.name ?? '');
      });

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
            Text(
                '${MenuEntry.weeks[weekIndex]} — Toplam Malzeme (gün gün kişi)',
                style: Theme.of(context).textTheme.titleLarge),
            Text(
              'Pzt ${servingsByDay[0]} • Sal ${servingsByDay[1]} • Çar ${servingsByDay[2]} • Per ${servingsByDay[3]} • Cum ${servingsByDay[4]} • Cmt ${servingsByDay[5]} • Paz ${servingsByDay[6]}',
              style:
                  const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const Text(
                'Reçeteler tek kişilik kabul edilip günün kişi sayısıyla çarpıldı.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            if (missingCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.warning,
                        color: Colors.red, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$missingCount öğünün reçetesi eksik — toplam eksik olabilir. Önce reçeteleri düzenleyin.',
                        style: const TextStyle(
                            color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            for (final en in entries)
              Builder(builder: (_) {
                final item = store.itemById(en.key);
                if (item == null) return const SizedBox.shrink();
                final short = item.currentStock - en.value < 0;
                final shortfall =
                    short ? en.value - item.currentStock : 0.0;
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(item.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13))),
                      Text(
                        '${item.formatAmount(en.value)} (stok: ${item.formattedStock()})',
                        style: TextStyle(
                            fontSize: 12,
                            color: short ? Colors.red : null,
                            fontWeight: short
                                ? FontWeight.bold
                                : null),
                      ),
                      if (short)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.warning,
                              size: 14, color: Colors.red),
                        ),
                      if (short)
                        IconButton(
                          icon: const Icon(
                              Icons.add_shopping_cart,
                              size: 18),
                          tooltip: 'Sipariş Ver',
                          color: Colors.red,
                          onPressed: () => openOrderQtySheet(
                            context,
                            itemId: item.id,
                            suggestedQty: suggestedTopUp(
                                store, item.id,
                                projectedShortfall: shortfall),
                            reason:
                                'Haftalık üretimde ${item.formatAmount(shortfall)} açık veriyor.',
                          ),
                        ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 12),
            const Text('Gün gün stoktan düş:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(
                  7,
                  (d) => ActionChip(
                        label: Text(MenuEntry.daysShort[d]),
                        onPressed: () => onDeductDay(d),
                      )),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => onDeductWeek(),
              icon: const Icon(Icons.checklist_rtl),
              label: const Text('Haftalık Stoktan Düş'),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20)),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _sharePdf(context),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF olarak kaydet/paylaş'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat (düşmeden çık)'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _sharePdf(BuildContext context) async {
    final store = context.read<AppStore>();
    final servingsLine = List.generate(
            7, (d) => '${MenuEntry.daysShort[d]} ${servingsByDay[d] ?? 0}')
        .join(' • ');
    final items = totals.entries.map((en) {
      final item = store.itemById(en.key);
      return {
        'name': item?.name ?? '?',
        'qty': item != null
            ? item.formatAmount(en.value)
            : en.value.toStringAsFixed(0)
      };
    }).toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));
    try {
      await PdfService.shareWeekTotalsPdf(
        weekLabel: MenuEntry.weeks[weekIndex],
        servingsLine: servingsLine,
        items: items,
        filename: 'haftalik-uretim.pdf',
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

/// Aramalı yemek seçici: yazdıkça tarifler süzülür.
class _RecipePickerDialog extends StatefulWidget {
  final List<Recipe> recipes;
  const _RecipePickerDialog({required this.recipes});

  @override
  State<_RecipePickerDialog> createState() => _RecipePickerDialogState();
}

class _RecipePickerDialogState extends State<_RecipePickerDialog> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.recipes
        : widget.recipes
            .where((r) => r.name.toLowerCase().contains(q))
            .toList();
    return AlertDialog(
      title: const Text('Yemek Seç'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Ara (örn. menemen)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Eşleşen yemek yok'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final r = filtered[i];
                        return ListTile(
                          title: Text(r.name),
                          subtitle: Text(
                              '${r.ingredients.length} malzeme • varsayılan ${r.servingsDefault} kişi'),
                          onTap: () => Navigator.pop(context, r),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
      ],
    );
  }
}

/// Üretim arşivi: kaydedilmiş haftalık üretimlere geri dönüp bakma.
class _ArchiveSheet extends StatelessWidget {
  const _ArchiveSheet();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final archives = store.productionArchives;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Üretim Arşivi (${archives.length})',
              style: Theme.of(context).textTheme.titleLarge),
          const Text(
              'Arşive Kaydet ile haftalık üretim verileri burada saklanır.',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Flexible(
            child: archives.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                          'Henüz arşiv kaydı yok.\nHaftalık menüde "Arşive Kaydet"e basın.',
                          textAlign: TextAlign.center),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: archives.length,
                    itemBuilder: (ctx, i) {
                      final a = archives[i];
                      return Card(
                        margin:
                            const EdgeInsets.symmetric(vertical: 4),
                        child: ExpansionTile(
                          leading: const Icon(Icons.archive),
                          title: Text(
                            '${a.weekLabel} — ${_fmtDate(a.date)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                          subtitle: Text(
                            'Pzt ${a.servingsByDay[0] ?? 0} • Sal ${a.servingsByDay[1] ?? 0} • Çar ${a.servingsByDay[2] ?? 0} • Per ${a.servingsByDay[3] ?? 0} • Cum ${a.servingsByDay[4] ?? 0} • Cmt ${a.servingsByDay[5] ?? 0} • Paz ${a.servingsByDay[6] ?? 0}',
                            style:
                                const TextStyle(fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 20),
                            tooltip: 'Arşivi sil',
                            onPressed: () => context
                                .read<AppStore>()
                                .deleteArchive(a.id),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 0, 16, 12),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  for (final en in a.totals.entries)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 1),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              a.itemNames[en.key] ??
                                                  '?',
                                              style: const TextStyle(
                                                  fontSize: 12),
                                            ),
                                          ),
                                          Text(
                                            _fmtAmount(en.value,
                                                a.itemUnits[en.key] ??
                                                    'gram'),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.bold),
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

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _fmtAmount(double v, String unitKey) {
    if (unitKey == 'piece') return '${v.toStringAsFixed(0)} adet';
    if (v >= 1000) {
      return '${(v / 1000).toStringAsFixed(2)} kg (${v.toStringAsFixed(0)} g)';
    }
    return '${v.toStringAsFixed(0)} g';
  }
}

class _RowCard extends StatefulWidget {
  final String recipeId;
  final int servings;
  final VoidCallback onRemove;
  final ValueChanged<int> onServingsChanged;

  const _RowCard({
    super.key,
    required this.recipeId,
    required this.servings,
    required this.onRemove,
    required this.onServingsChanged,
  });

  @override
  State<_RowCard> createState() => _RowCardState();
}

class _RowCardState extends State<_RowCard> {
  late TextEditingController _servingsCtrl;
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    _servingsCtrl = TextEditingController(text: '${widget.servings}');
  }

  @override
  void didUpdateWidget(covariant _RowCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.servings != widget.servings &&
        _servingsCtrl.text != '${widget.servings}') {
      _servingsCtrl.text = '${widget.servings}';
    }
  }

  @override
  void dispose() {
    _servingsCtrl.dispose();
    super.dispose();
  }

  void _setServings(int v) {
    final clamped = v.clamp(1, 10000);
    widget.onServingsChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final recipe = store.recipeById(widget.recipeId);
    if (recipe == null) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: ListTile(
          title: const Text('Silinmiş tarif'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: widget.onRemove,
          ),
        ),
      );
    }

    final preview = store.previewProduction(recipe, widget.servings);
    final hasShortage =
        preview.any((r) => r.item.currentStock - r.needed < 0);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recipe.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        '${recipe.ingredients.length} malzeme',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            size: 20),
                        tooltip: 'Azalt',
                        onPressed: widget.servings > 1
                            ? () => _setServings(widget.servings - 1)
                            : null,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _servingsCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            labelText: 'Kişi',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (v) {
                            final n = int.tryParse(v) ?? widget.servings;
                            _setServings(n);
                          },
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null && n >= 1 && n <= 10000) {
                              widget.onServingsChanged(n);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline,
                            size: 20),
                        tooltip: 'Artır',
                        onPressed: () =>
                            _setServings(widget.servings + 1),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 22),
                  tooltip: 'Satırı sil',
                  onPressed: widget.onRemove,
                ),
                IconButton(
                  icon: Icon(_expanded
                      ? Icons.expand_less
                      : Icons.expand_more),
                  tooltip: _expanded ? 'Daralt' : 'Reçeteyi aç',
                  onPressed: () =>
                      setState(() => _expanded = !_expanded),
                ),
              ],
            ),
            const Divider(),
            if (_expanded) ...[
              ...recipe.ingredients.asMap().entries.map((entry) {
                final idx = entry.key;
                final ing = entry.value;
                return _IngredientEditRow(
                  key: ValueKey('${recipe.id}:${ing.id}'),
                  recipe: recipe,
                  ingredientIndex: idx,
                  onChanged: () => setState(() {}),
                  onDeleted: () => setState(() {
                    recipe.ingredients.removeAt(idx);
                  }),
                );
              }),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _addIngredient(context, store, recipe),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Malzeme ekle'),
                  ),
                  const Spacer(),
                  FilledButton.tonal(
                    onPressed: () async {
                      await store.updateRecipe(recipe);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  '${recipe.name} reçetesi kaydedildi')),
                        );
                        setState(() {});
                      }
                    },
                    child: const Text('Reçeteyi Kaydet'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ] else ...[
              Text(
                recipe.ingredients.map((ing) {
                  final item = store.itemById(ing.itemId);
                  final name = item?.name ?? '?';
                  final unit = item?.unit.abbreviation ?? '';
                  return '$name ${ing.amountPerServing.toStringAsFixed(ing.amountPerServing >= 100 ? 0 : 1)} $unit';
                }).join(' • '),
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
            ],
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Toplam (${widget.servings} kişi): ${preview.map((r) => '${r.item.name}: ${r.needed.toStringAsFixed(r.item.unit == StockUnit.gram ? 0 : 0)} ${r.item.unit.abbreviation} (stok: ${r.item.formattedStock()})').join(' • ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (hasShortage)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: StatusBadge(
                    text: 'Stok yetersiz — düşülürse sıfıra sabitlenir',
                    color: Colors.orange),
              ),
          ],
        ),
      ),
    );
  }

  void _addIngredient(
      BuildContext context, AppStore store, Recipe recipe) {
    if (store.inventory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Önce stoklara ürün ekleyin.')),
      );
      return;
    }
    setState(() {
      recipe.ingredients.add(RecipeIngredient(
        itemId: store.inventory.first.id,
        amountPerServing: 0,
      ));
    });
  }
}

/// Tek reçete satırı: ürün seçimi + porsiyon başına miktar (elle düzenlenir).
class _IngredientEditRow extends StatefulWidget {
  final Recipe recipe;
  final int ingredientIndex;
  final VoidCallback onChanged;
  final VoidCallback onDeleted;
  const _IngredientEditRow({
    super.key,
    required this.recipe,
    required this.ingredientIndex,
    required this.onChanged,
    required this.onDeleted,
  });

  @override
  State<_IngredientEditRow> createState() => _IngredientEditRowState();
}

class _IngredientEditRowState extends State<_IngredientEditRow> {
  late TextEditingController _amountCtrl;

  RecipeIngredient get _ing =>
      widget.recipe.ingredients[widget.ingredientIndex];

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: _fmt(_ing.amountPerServing));
  }

  @override
  void didUpdateWidget(covariant _IngredientEditRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ingredientIndex != widget.ingredientIndex ||
        oldWidget.recipe.id != widget.recipe.id) {
      _amountCtrl.text = _fmt(_ing.amountPerServing);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) => v.toStringAsFixed(v >= 100 ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (store.itemById(_ing.itemId) == null && store.inventory.isNotEmpty) {
      _ing.itemId = store.inventory.first.id;
    }
    final item = store.itemById(_ing.itemId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: DropdownButtonFormField<String>(
              initialValue: _ing.itemId,
              decoration: const InputDecoration(
                labelText: 'Ürün',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: store.inventory
                  .map((it) => DropdownMenuItem(
                        value: it.id,
                        child: Text('${it.name} (${it.unit.abbreviation})',
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _ing.itemId = v;
                });
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: false),
              decoration: InputDecoration(
                labelText: 'Porsiyon (g/adet)',
                suffixText: item?.unit.abbreviation ?? '',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                final n =
                    double.tryParse(v.replaceAll(',', '.'));
                if (n != null && n >= 0) {
                  _ing.amountPerServing = n;
                  widget.onChanged();
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Malzemeyi sil',
            onPressed: widget.onDeleted,
          ),
        ],
      ),
    );
  }
}
