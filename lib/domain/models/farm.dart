/// Farmer category enumeration.
enum FarmerCategory {
  subsistence,
  semiCommercial,
  marketOriented,
}

/// Soil type enumeration.
enum SoilType {
  clay,
  sandy,
  loamy,
  silt,
}

/// Water source enumeration.
enum WaterSource {
  rainfall,
  borehole,
  river,
  dam,
  irrigation,
}

/// Farm model representing a farmer's agricultural land.
class Farm {
  const Farm({
    required this.id,
    required this.name,
    required this.ward,
    required this.sizeHa,
    required this.farmerCategory,
    required this.soilType,
    required this.waterSource,
    required this.createdAt,
    required this.updatedAt,
    required this.isSynced,
  });

  final String id;
  final String name;
  final String ward;
  final double sizeHa;
  final FarmerCategory farmerCategory;
  final SoilType soilType;
  final WaterSource waterSource;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  Farm copyWith({
    String? id,
    String? name,
    String? ward,
    double? sizeHa,
    FarmerCategory? farmerCategory,
    SoilType? soilType,
    WaterSource? waterSource,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return Farm(
      id: id ?? this.id,
      name: name ?? this.name,
      ward: ward ?? this.ward,
      sizeHa: sizeHa ?? this.sizeHa,
      farmerCategory: farmerCategory ?? this.farmerCategory,
      soilType: soilType ?? this.soilType,
      waterSource: waterSource ?? this.waterSource,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ward': ward,
        'sizeHa': sizeHa,
        'farmerCategory': farmerCategory.name,
        'soilType': soilType.name,
        'waterSource': waterSource.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isSynced': isSynced,
      };

  factory Farm.fromJson(Map<String, dynamic> json) => Farm(
        id: json['id'] as String,
        name: json['name'] as String,
        ward: json['ward'] as String,
        sizeHa: (json['sizeHa'] as num).toDouble(),
        farmerCategory: FarmerCategory.values.firstWhere(
          (e) => e.name == json['farmerCategory'],
        ),
        soilType: SoilType.values.firstWhere(
          (e) => e.name == json['soilType'],
        ),
        waterSource: WaterSource.values.firstWhere(
          (e) => e.name == json['waterSource'],
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        isSynced: json['isSynced'] as bool,
      );
}
