import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/menu_entry.dart';
import '../state/app_store.dart';

/// Weekly menu program: day by day (Pazartesi-Pazar), meal by meal.
/// The grocery list is calculated from this menu when it is non-empty.
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late int _day;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now().weekday - 1; // 0 = Monday
    _day = today.clamp(0, 6);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final entries = store.menuForDay(_day);
    final totalServings =
        entries.fold<int>(0, (sum, e) => sum + e.servings);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Haftalık Menü'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Alışveriş listesini menüden oluştur',
            onPressed: () async {
              await context.read<AppStore>().generateGroceryList();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Alışveriş listesi menüden güncellendi.')),
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: store.recipes.isEmpty
            ? null
            : () => _openForm(context, null, _day),
        icon: const Icon(Icons.add),
        label: const Text('Öğün Ekle'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: List.generate(7, (i) {
                final count = store.menuForDay(i).length;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ChoiceChip(
                    label: Text(
                        '${MenuEntry.daysShort[i]}${count > 0 ? ' ($count)' : ''}'),
                    selected: _day == i,
                    onSelected: (_) => setState(() => _day = i),
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${MenuEntry.days[_day]} — ${entries.length} öğün, toplam $totalServings porsiyon',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.restaurant_menu,
                              size: 48,
                              color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            '${MenuEntry.days[_day]} için öğün yok',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Öğün Ekle ile tarif ve porsiyon seçin.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (ctx, i) {
                      final e = entries[i];
                      final recipe = store.recipeById(e.recipeId);
                      return Dismissible(
                        key: ValueKey(e.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete,
                              color: Colors.white),
                        ),
                        onDismissed: (_) => context
                            .read<AppStore>()
                            .deleteMenuEntry(e.id),
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade50,
                              child: Text(
                                e.meal.characters.first,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              recipe?.name ?? 'Silinmiş tarif',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                                '${e.meal} • ${e.servings} porsiyon'),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () =>
                                  _openForm(context, e, _day),
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

  void _openForm(BuildContext context, MenuEntry? existing, int day) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => MenuEntryFormSheet(existing: existing, day: day),
    );
  }
}

class MenuEntryFormSheet extends StatefulWidget {
  final MenuEntry? existing;
  final int day;
  const MenuEntryFormSheet(
      {super.key, required this.existing, required this.day});

  @override
  State<MenuEntryFormSheet> createState() => _MenuEntryFormSheetState();
}

class _MenuEntryFormSheetState extends State<MenuEntryFormSheet> {
  late int _day;
  late String _meal;
  late String _recipeId;
  late final TextEditingController _servingsCtrl;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    final e = widget.existing;
    _day = e?.dayIndex ?? widget.day;
    _meal = e?.meal ?? MenuEntry.meals[1];
    if (!MenuEntry.meals.contains(_meal)) {
      _meal = MenuEntry.meals.first;
    }
    _recipeId = e?.recipeId ?? '';
    if (_recipeId.isEmpty ||
        !store.recipes.any((r) => r.id == _recipeId)) {
      _recipeId =
          store.recipes.isNotEmpty ? store.recipes.first.id : '';
    }
    _servingsCtrl =
        TextEditingController(text: '${e?.servings ?? 4}');
  }

  int get _servings => int.tryParse(_servingsCtrl.text) ?? 0;
  bool get _valid =>
      _recipeId.isNotEmpty && _servings >= 1 && _servings <= 10000;

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
          children: [
            Text(widget.existing == null ? 'Öğün Ekle' : 'Öğünü Düzenle',
                style: Theme.of(context).textTheme.titleLarge),
            DropdownButtonFormField<int>(
              initialValue: _day,
              decoration: const InputDecoration(labelText: 'Gün'),
              items: List.generate(
                  7,
                  (i) => DropdownMenuItem(
                      value: i, child: Text(MenuEntry.days[i]))),
              onChanged: (v) => setState(() => _day = v!),
            ),
            DropdownButtonFormField<String>(
              initialValue: _meal,
              decoration: const InputDecoration(labelText: 'Öğün'),
              items: MenuEntry.meals
                  .map((m) =>
                      DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _meal = v!),
            ),
            DropdownButtonFormField<String>(
              initialValue: _recipeId.isEmpty ? null : _recipeId,
              decoration: const InputDecoration(labelText: 'Tarif'),
              items: store.recipes
                  .map((r) => DropdownMenuItem(
                      value: r.id, child: Text(r.name)))
                  .toList(),
              onChanged: (v) => setState(() => _recipeId = v!),
            ),
            TextField(
              controller: _servingsCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Porsiyon (1-10000)',
                errorText: (_servings >= 1 && _servings <= 10000)
                    ? null
                    : '1-10000 arası girin',
              ),
              onChanged: (_) => setState(() {}),
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
                    onPressed: _valid ? _save : null,
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

  Future<void> _save() async {
    final store = context.read<AppStore>();
    if (widget.existing == null) {
      await store.addMenuEntry(MenuEntry(
        dayIndex: _day,
        meal: _meal,
        recipeId: _recipeId,
        servings: _servings,
      ));
    } else {
      final e = widget.existing!;
      e.dayIndex = _day;
      e.meal = _meal;
      e.recipeId = _recipeId;
      e.servings = _servings;
      await store.updateMenuEntry(e);
    }
    await store.generateGroceryList();
    if (mounted) Navigator.pop(context);
  }
}
