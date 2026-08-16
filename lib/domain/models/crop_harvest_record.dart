/// A single harvest event for a crop - lets a crop be harvested more than
/// once per cycle (e.g. tomatoes, okra) and gives "Yield/ha" a real actual
/// figure to compare against `Crop.targetYieldKg` instead of only ever
/// showing the target.
class CropHarvestRecord {
  const CropHarvestRecord({
    required this.id,
    required this.cropId,
    required this.harvestedAt,
    required this.quantity,
    required this.unit,
    this.unitPrice = 0,
    this.notes = '',
    this.createdAt,
  });

  final String id;
  final String cropId;
  final DateTime harvestedAt;
  final double quantity;
  final String unit;
  final double unitPrice;
  final String notes;
  final DateTime? createdAt;

  double get totalValue => quantity * unitPrice;

  /// Approximate kg-equivalent so harvests logged in different units can be
  /// summed into one actual-yield figure. A 50kg bag is the standard
  /// smallholder grain-bag size used across the app's target market.
  double get quantityInKg {
    switch (unit) {
      case 'ton':
        return quantity * 1000;
      case 'bags':
        return quantity * 50;
      default:
        return quantity;
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'cropId': cropId,
        'harvestedAt': harvestedAt.toIso8601String(),
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'notes': notes,
        'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      };

  factory CropHarvestRecord.fromJson(Map<String, dynamic> json) =>
      CropHarvestRecord(
        id: json['id'] as String? ?? '',
        cropId: json['cropId'] as String? ?? '',
        harvestedAt: DateTime.tryParse(json['harvestedAt'] as String? ?? '') ??
            DateTime.now(),
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] as String? ?? 'kg',
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
        notes: json['notes'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );
}
