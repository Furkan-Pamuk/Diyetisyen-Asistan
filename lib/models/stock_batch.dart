import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Stoğa her girişte tutulan parti kaydı: hangi ürün, ne kadar, ne zaman.
/// Mal kabul, sipariş teslimi ve açılış stokları buraya işlenir.
/// İmha tutanağındaki "Dolaba Giriş Tarihi" buradan otomatik gelir.
class StockBatch {
  final String id;
  String itemId;
  double quantity;
  DateTime entryDate;
  String source; // örn. "Mal kabul", "Sipariş: X", "Başlangıç stoku"

  StockBatch({
    String? id,
    required this.itemId,
    required this.quantity,
    DateTime? entryDate,
    this.source = '',
  })  : id = id ?? _uuid.v4(),
        entryDate = entryDate ?? DateTime.now();

  factory StockBatch.fromJson(Map<String, dynamic> j) =>
      StockBatch(
        id: j['id'] as String?,
        itemId: j['itemId'] as String,
        quantity: (j['quantity'] as num).toDouble(),
        entryDate:
            DateTime.tryParse(j['entryDate'] as String? ?? '') ??
                DateTime.now(),
        source: (j['source'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemId': itemId,
        'quantity': quantity,
        'entryDate': entryDate.toIso8601String(),
        'source': source,
      };
}
