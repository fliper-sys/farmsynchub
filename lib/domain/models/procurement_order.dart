enum ProcurementOrderStatus {
  pending,
  ordered,
  delivered,
  cancelled,
}

class ProcurementOrder {
  const ProcurementOrder({
    required this.id,
    required this.farmId,
    required this.providerName,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalAmount,
    required this.orderDate,
    required this.expectedDeliveryDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.isSynced,
    this.notes = '',
  });

  final String id;
  final String farmId;
  final String providerName;
  final String productName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalAmount;
  final DateTime orderDate;
  final DateTime expectedDeliveryDate;
  final ProcurementOrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final String notes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'farmId': farmId,
        'providerName': providerName,
        'productName': productName,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'totalAmount': totalAmount,
        'orderDate': orderDate.toIso8601String(),
        'expectedDeliveryDate': expectedDeliveryDate.toIso8601String(),
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isSynced': isSynced,
        'notes': notes,
      };

  factory ProcurementOrder.fromJson(Map<String, dynamic> json) => ProcurementOrder(
        id: json['id'] as String? ?? '',
        farmId: json['farmId'] as String? ?? '',
        providerName: json['providerName'] as String? ?? '',
        productName: json['productName'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] as String? ?? 'unit',
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
        orderDate: DateTime.tryParse(json['orderDate'] as String? ?? '') ?? DateTime.now(),
        expectedDeliveryDate: DateTime.tryParse(json['expectedDeliveryDate'] as String? ?? '') ?? DateTime.now(),
        status: ProcurementOrderStatus.values.firstWhere(
          (ProcurementOrderStatus value) => value.name == json['status'],
          orElse: () => ProcurementOrderStatus.pending,
        ),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
        isSynced: json['isSynced'] as bool? ?? false,
        notes: json['notes'] as String? ?? '',
      );

  ProcurementOrder copyWith({
    String? id,
    String? farmId,
    String? providerName,
    String? productName,
    double? quantity,
    String? unit,
    double? unitPrice,
    double? totalAmount,
    DateTime? orderDate,
    DateTime? expectedDeliveryDate,
    ProcurementOrderStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    String? notes,
  }) {
    return ProcurementOrder(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      providerName: providerName ?? this.providerName,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      totalAmount: totalAmount ?? this.totalAmount,
      orderDate: orderDate ?? this.orderDate,
      expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      notes: notes ?? this.notes,
    );
  }
}
