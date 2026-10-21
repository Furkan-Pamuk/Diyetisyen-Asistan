import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Aylık ajanda notu: belirli bir güne yazılan kısa not.
class AgendaEntry {
  final String id;
  DateTime day; // gün (yıl/ay/gün, saat sıfırlanır)
  String text;
  DateTime createdAt;

  AgendaEntry({
    String? id,
    required DateTime day,
    required this.text,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        day = DateTime(day.year, day.month, day.day),
        createdAt = createdAt ?? DateTime.now();

  static DateTime norm(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  factory AgendaEntry.fromJson(Map<String, dynamic> j) =>
      AgendaEntry(
        id: j['id'] as String?,
        day: DateTime.tryParse(j['day'] as String? ?? '') ??
            DateTime.now(),
        text: (j['text'] as String?) ?? '',
        createdAt: DateTime.tryParse(
                j['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'day': DateTime(day.year, day.month, day.day)
            .toIso8601String(),
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };
}
