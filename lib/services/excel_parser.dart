import 'package:excel/excel.dart';
import '../models/recipe.dart';

/// Excel'den gelen tek menü satırı: gün + öğün + yemek + kişi sayısı.
class ImportedMenuRow {
  final int dayIndex; // 0 = Pazartesi ... 6 = Pazar
  final String meal;
  final String dish;
  final int servings;
  ImportedMenuRow({
    required this.dayIndex,
    required this.meal,
    required this.dish,
    required this.servings,
  });
}

int? _dayFromText(String text) {
  final t = text.toLowerCase();
  // Uzun isimler önce (cumartesi içinde cuma geçtiği için).
  const days = [
    ['pazartesi', 'pzt'],
    ['salı', 'sali', 'sal'],
    ['çarşamba', 'carsamba', 'çar', 'car'],
    ['perşembe', 'persembe', 'per'],
    ['cumartesi', 'cmt'],
    ['cuma', 'cum'],
    ['pazar', 'paz'],
  ];
  for (var i = 0; i < days.length; i++) {
    for (final key in days[i]) {
      if (t.contains(key)) {
        // Kısa "sal"/"car" gibi anahtarlar tek başına hücredeyse kabul et.
        if (key.length <= 3) {
          final clean = t.replaceAll(RegExp(r'[^a-zçğıöşü]'), '');
          if (clean == key) return i;
          if (t.contains('salı') || t.contains('sali')) return 1;
          continue;
        }
        return i;
      }
    }
  }
  return null;
}

String _mealFromText(String text, String fallback) {
  final t = text.toLowerCase();
  if (t.contains('kahvaltı') || t.contains('kahvalti')) return 'Kahvaltı';
  if (t.contains('ara öğün') ||
      t.contains('ara ogun') ||
      t.contains('araöğün')) {
    return 'Ara Öğün';
  }
  if (t.contains('öğle') || t.contains('ogle') || t.contains('oglen')) {
    return 'Öğle';
  }
  if (t.contains('akşam') || t.contains('aksam')) return 'Akşam';
  return fallback;
}

int _servingsFromCells(List<String> cells) {
  for (final c in cells) {
    final n = int.tryParse(c.replaceAll(RegExp(r'[^0-9]'), ''));
    if (n != null && n >= 1 && n <= 10000) return n;
  }
  return 0; // 0 = varsayılan kullanılacak
}

/// Haftalık menü Excel'ini ayrıştırır.
/// Beklenen düzen esnektir: gün adları satırlarda, yemek adları hücrelerde.
/// Sayı içeren hücre porsiyon sayılır.
List<ImportedMenuRow> parseWeeklyMenu(List<int> bytes,
    {int defaultServings = 100}) {
  final wb = Excel.decodeBytes(bytes);
  final rows = <ImportedMenuRow>[];
  for (final sheetName in wb.tables.keys) {
    final table = wb.tables[sheetName];
    if (table == null) continue;
    int currentDay = -1;
    String currentMeal = 'Öğle';
    for (final row in table.rows) {
      final cells = row
          .map((c) => (c?.value?.toString() ?? '').trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (cells.isEmpty) continue;
      final joined = cells.join(' | ');
      final day = _dayFromText(joined);
      if (day != null) {
        currentDay = day;
        currentMeal = _mealFromText(joined, currentMeal);
        // Gün başlığı satırında yemek de olabilir ("Pazartesi - Mercimek").
        final dishes = _dishesFromCells(cells);
        for (final d in dishes) {
          if (currentDay >= 0) {
            rows.add(ImportedMenuRow(
              dayIndex: currentDay,
              meal: _mealFromText(joined, currentMeal),
              dish: d,
              servings: _servingsFromCells(cells) == 0
                  ? defaultServings
                  : _servingsFromCells(cells),
            ));
          }
        }
        continue;
      }
      if (currentDay < 0) continue; // gün görülmeden yemek ekleme
      currentMeal = _mealFromText(joined, currentMeal);
      final servings = _servingsFromCells(cells);
      for (final d in _dishesFromCells(cells)) {
        rows.add(ImportedMenuRow(
          dayIndex: currentDay,
          meal: currentMeal,
          dish: d,
          servings: servings == 0 ? defaultServings : servings,
        ));
      }
    }
  }
  return rows;
}

/// Hücrelerden yemek adlarını çıkarır: sayı/gün/öğün hücrelerini atlar,
/// uzun metinleri virgül/noktalı virgül/eğik çizgi ile böler.
List<String> _dishesFromCells(List<String> cells) {
  final out = <String>[];
  final skip = RegExp(
      r'^(pazartesi|salı|sali|çarşamba|carsamba|perşembe|persembe|cuma|cumartesi|pazar|pzt|sal|çar|car|per|cum|cmt|paz|kahvaltı|kahvalti|öğle|ogle|akşam|aksam|ara öğün|ara ogun|gün|hafta|menu|menü|tarih|kişi|porsiyon|adet|gram|kg)$');
  for (final raw in cells) {
    final cell = raw.trim();
    if (cell.isEmpty) continue;
    // Salt sayı hücreleri porsiyondur, yemek değil.
    if (RegExp(r'^[0-9\s.,]+$').hasMatch(cell)) continue;
    if (_dayFromText(cell) != null && cell.length < 15) continue;
    final parts = cell.split(RegExp(r'[,;|/•\n]+'));
    for (var p in parts) {
      p = p.trim().replaceAll(RegExp(r'^[0-9.)(\-\s]+'), '');
      if (p.length < 2) continue;
      if (skip.hasMatch(p.toLowerCase())) continue;
      if (p.toLowerCase().contains('tutanak') ||
          p.toLowerCase().contains('imha') ||
          p.toLowerCase().contains('form')) {
        continue;
      }
      out.add(p);
    }
  }
  return out;
}

@Deprecated('Use parseWeeklyMenu instead')
Future<List<Recipe>> parseExcelMenu(List<int> bytes) async {
  final rows = parseWeeklyMenu(bytes);
  final seen = <String>{};
  final recipes = <Recipe>[];
  for (final r in rows) {
    final key = r.dish.toLowerCase();
    if (seen.add(key)) {
      recipes.add(Recipe(
        name: r.dish,
        description: 'Excel menüden',
        servingsDefault: 1,
      ));
    }
  }
  return recipes;
}
