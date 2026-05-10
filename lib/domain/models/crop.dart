/// Crop growth stage enumeration.
enum CropStage {
  seeding,
  germination,
  vegetative,
  flowering,
  fruiting,
}

/// Crop status enumeration.
enum CropStatus {
  planted,
  growing,
  ready,
  harvested,
}


/// Crop model representing planted crops on a farm.
class Crop {
  const Crop({
    required this.id,
    required this.farmId,
    required this.name,
    required this.variety,
    required this.areaHa,
    required this.plantingDate,
    required this.expectedHarvestDate,
    required this.currentStage,
    required this.status,
    required this.totalInputCost,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.isSynced,
  });

  final String id;
  final String farmId;
  final String name;
  final String variety;
  final double areaHa;
  final DateTime plantingDate;
  final DateTime expectedHarvestDate;
  final CropStage currentStage;
  final CropStatus status;
  final double totalInputCost;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  Map<String, dynamic> toJson() => {
        'id': id,
        'farmId': farmId,
        'name': name,
        'variety': variety,
        'areaHa': areaHa,
        'plantingDate': plantingDate.toIso8601String(),
        'expectedHarvestDate': expectedHarvestDate.toIso8601String(),
        'currentStage': currentStage.name,
        'status': status.name,
        'totalInputCost': totalInputCost,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isSynced': isSynced,
      };

  factory Crop.fromJson(Map<String, dynamic> json) => Crop(
        id: json['id'] as String,
        farmId: json['farmId'] as String,
        name: json['name'] as String,
        variety: json['variety'] as String,
        areaHa: (json['areaHa'] as num).toDouble(),
        plantingDate: DateTime.parse(json['plantingDate'] as String),
        expectedHarvestDate: DateTime.parse(json['expectedHarvestDate'] as String),
        currentStage: CropStage.values.firstWhere(
          (e) => e.name == json['currentStage'],
        ),
        status: CropStatus.values.firstWhere(
          (e) => e.name == json['status'],
        ),
        totalInputCost: (json['totalInputCost'] as num).toDouble(),
        notes: json['notes'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        isSynced: json['isSynced'] as bool,
      );
}