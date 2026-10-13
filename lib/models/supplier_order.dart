import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum SupplierOrderStatus {
  scheduled,
  ordered,
  ready,
  pickedUp,
  cancelled,
}

extension SupplierOrderStatusX on SupplierOrderStatus {
  String get displayName {
    switch (this) {
      case SupplierOrderStatus.scheduled:
        return 'Scheduled';
      case SupplierOrderStatus.ordered:
        return 'Ordered';
      case SupplierOrderStatus.ready:
        return 'Ready for Pickup';
      case SupplierOrderStatus.pickedUp:
        return 'Picked Up';
      case SupplierOrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isActive =>
      this != SupplierOrderStatus.pickedUp &&
      this != SupplierOrderStatus.cancelled;

  String get key => name;

  static SupplierOrderStatus fromKey(String key) {
    return SupplierOrderStatus.values.firstWhere(
      (e) => e.name == key,
      orElse: () => SupplierOrderStatus.scheduled,
    );
  }
}

enum AlertLevel { overdue, dueToday, dueSoon, ok }

class SupplierOrder {
  final String id;
  String supplierName;
  String? supplierId;
  String title;
  DateTime orderDate;
  DateTime pickupDate;
  SupplierOrderStatus status;
  String notes;
  bool reminderEnabled;

  SupplierOrder({
    String? id,
    this.supplierName = 'Supplier X',
    this.supplierId,
    required this.title,
    required this.orderDate,
    required this.pickupDate,
    this.status = SupplierOrderStatus.scheduled,
    this.notes = '',
    this.reminderEnabled = true,
  }) : id = id ?? _uuid.v4();

  static int daysUntil(DateTime date, [DateTime? now]) {
    final n = now ?? DateTime.now();
    final a = DateTime(n.year, n.month, n.day);
    final b = DateTime(date.year, date.month, date.day);
    return b.difference(a).inDays;
  }

  int get orderCountdown => daysUntil(orderDate);
  int get pickupCountdown => daysUntil(pickupDate);

  AlertLevel get orderAlert {
    if (!status.isActive) return AlertLevel.ok;
    if (orderCountdown < 0) return AlertLevel.overdue;
    if (orderCountdown == 0) return AlertLevel.dueToday;
    if (orderCountdown <= 2) return AlertLevel.dueSoon;
    return AlertLevel.ok;
  }

  AlertLevel get pickupAlert {
    if (!status.isActive) return AlertLevel.ok;
    if (status != SupplierOrderStatus.ordered &&
        status != SupplierOrderStatus.ready) {
      return AlertLevel.ok;
    }
    if (pickupCountdown < 0) return AlertLevel.overdue;
    if (pickupCountdown == 0) return AlertLevel.dueToday;
    if (pickupCountdown <= 2) return AlertLevel.dueSoon;
    return AlertLevel.ok;
  }

  bool get needsAttention =>
      orderAlert != AlertLevel.ok || pickupAlert != AlertLevel.ok;

  factory SupplierOrder.fromJson(Map<String, dynamic> j) => SupplierOrder(
        id: j['id'] as String?,
        supplierName: (j['supplierName'] as String?) ?? 'Supplier X',
        supplierId: j['supplierId'] as String?,
        title: j['title'] as String,
        orderDate: DateTime.parse(j['orderDate'] as String),
        pickupDate: DateTime.parse(j['pickupDate'] as String),
        status: SupplierOrderStatusX.fromKey(j['status'] as String),
        notes: (j['notes'] as String?) ?? '',
        reminderEnabled: (j['reminderEnabled'] as bool?) ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'supplierName': supplierName,
        'supplierId': supplierId,
        'title': title,
        'orderDate': orderDate.toIso8601String(),
        'pickupDate': pickupDate.toIso8601String(),
        'status': status.key,
        'notes': notes,
        'reminderEnabled': reminderEnabled,
      };
}
