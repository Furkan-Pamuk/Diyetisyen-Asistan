import 'package:excel/excel.dart';
import '../models/recipe.dart';

Future<List<Recipe>> parseExcelMenu(List<int> bytes) async {
  final wb = Excel.decodeBytes(bytes);
  final recipes = <Recipe>[];
  for (final name in wb.tables.keys) {
    final rows = wb.tables[name]!.rows;
    if (rows.isEmpty) continue;
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final dishName = row.isNotEmpty ? (row[0]?.value?.toString() ?? '').trim() : '';
      if (dishName.isEmpty || dishName.length < 2) continue;
      // Create a basic recipe line; exact ingredient mapping depends on column layout.
      recipes.add(Recipe(
        name: dishName,
        description: 'Excel: $name',
        servingsDefault: 4,
      ));
    }
  }
  return recipes;
}
