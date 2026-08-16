class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.farmId,
    required this.name,
    required this.category,
    required this.unit,
    required this.availableQuantity,
    required this.unitPrice,
    required this.createdAt,
    required this.updatedAt,
    this.costPrice = 0,
    this.emoji = '🌾',
    this.expiryDate,
    this.lowStockThreshold,
  });

  final String id;
  final String farmId;
  final String name;
  final String category;
  final String unit;
  final double availableQuantity;
  final double unitPrice;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double costPrice;
  final String emoji;
  final DateTime? expiryDate;
  final double? lowStockThreshold;

  bool get isLowStock =>
      lowStockThreshold != null && availableQuantity <= lowStockThreshold!;

  bool isExpiringWithin(Duration window, {DateTime? referenceDate}) {
    if (expiryDate == null) {
      return false;
    }
    final DateTime now = referenceDate ?? DateTime.now();
    return !expiryDate!.isBefore(now) && expiryDate!.isBefore(now.add(window));
  }

  InventoryItem copyWith({
    String? id,
    String? farmId,
    String? name,
    String? category,
    String? unit,
    double? availableQuantity,
    double? unitPrice,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? costPrice,
    String? emoji,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    double? lowStockThreshold,
    bool clearLowStockThreshold = false,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      unitPrice: unitPrice ?? this.unitPrice,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      costPrice: costPrice ?? this.costPrice,
      emoji: emoji ?? this.emoji,
      expiryDate: clearExpiryDate ? null : expiryDate ?? this.expiryDate,
      lowStockThreshold: clearLowStockThreshold
          ? null
          : lowStockThreshold ?? this.lowStockThreshold,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'farmId': farmId,
        'name': name,
        'category': category,
        'unit': unit,
        'availableQuantity': availableQuantity,
        'unitPrice': unitPrice,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'costPrice': costPrice,
        'emoji': emoji,
        'expiryDate': expiryDate?.toIso8601String(),
        'lowStockThreshold': lowStockThreshold,
      };

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String,
      farmId: json['farmId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      unit: json['unit'] as String? ?? 'unit',
      availableQuantity: (json['availableQuantity'] as num?)?.toDouble() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0,
      emoji: json['emoji'] as String? ?? '🌾',
      expiryDate: DateTime.tryParse(json['expiryDate'] as String? ?? ''),
      lowStockThreshold: (json['lowStockThreshold'] as num?)?.toDouble(),
    );
  }
}
