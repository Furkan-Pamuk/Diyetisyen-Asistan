import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Named supplier. Orders reference a supplier via [SupplierOrder.supplierId].
class Supplier {
  final String id;
  String name;
  String phone;
  String note;

  Supplier({
    String? id,
    required this.name,
    this.phone = '',
    this.note = '',
  }) : id = id ?? _uuid.v4();

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
        id: j['id'] as String?,
        name: j['name'] as String,
        phone: (j['phone'] as String?) ?? '',
        note: (j['note'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'note': note,
      };
}
