import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// One line of the weekly menu program: which recipe, which day, which meal.
class MenuEntry {
  final String id;
  int dayIndex; // 0 = Pazartesi ... 6 = Pazar
  String meal; // Kahvaltı / Öğle / Akşam / Ara Öğün
  String recipeId;
  int servings;

  MenuEntry({
    String? id,
    required this.dayIndex,
    required this.meal,
    required this.recipeId,
    required this.servings,
  }) : id = id ?? _uuid.v4();

  static const days = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  static const daysShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  static const meals = ['Kahvaltı', 'Öğle', 'Akşam', 'Ara Öğün'];

  factory MenuEntry.fromJson(Map<String, dynamic> j) => MenuEntry(
        id: j['id'] as String?,
        dayIndex: (j['dayIndex'] as num).toInt(),
        meal: j['meal'] as String,
        recipeId: j['recipeId'] as String,
        servings: (j['servings'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'dayIndex': dayIndex,
        'meal': meal,
        'recipeId': recipeId,
        'servings': servings,
      };
}
