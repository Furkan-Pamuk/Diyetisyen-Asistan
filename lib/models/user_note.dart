import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Paneldeki notlar: yazılı metin + isteğe bağlı ses kaydı.
/// Ses baytları bulutta şişmesin diye YALNIZCA cihazda saklanır;
/// metin ve başlık tüm cihazlara eşitlenir.
class UserNote {
  final String id;
  String text;
  DateTime createdAt;
  bool hasAudio;
  DateTime? reminderAt;

  UserNote({
    String? id,
    required this.text,
    DateTime? createdAt,
    this.hasAudio = false,
    this.reminderAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  factory UserNote.fromJson(Map<String, dynamic> j) => UserNote(
        id: j['id'] as String?,
        text: (j['text'] as String?) ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
        hasAudio: (j['hasAudio'] as bool?) ?? false,
        reminderAt: j['reminderAt'] == null
            ? null
            : DateTime.tryParse(j['reminderAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'hasAudio': hasAudio,
        'reminderAt': reminderAt?.toIso8601String(),
      };
}
