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

/// Farm operation type enumeration.
enum FarmType {
  crop,
  livestock,
  greenhouse,
  combined,
}

class FarmDocumentRecord {
  const FarmDocumentRecord({
    required this.id,
    required this.title,
    required this.type,
    required this.reference,
    required this.notes,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String type;
  final String reference;
  final String notes;
  final DateTime createdAt;

  FarmDocumentRecord copyWith({
    String? id,
    String? title,
    String? type,
    String? reference,
    String? notes,
    DateTime? createdAt,
  }) {
    return FarmDocumentRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'type': type,
        'reference': reference,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FarmDocumentRecord.fromJson(Map<String, dynamic> json) {
    return FarmDocumentRecord(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? 'Document',
      reference: json['reference'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Farm model representing a farmer's agricultural land.
class Farm {
  const Farm({
    required this.id,
    required this.name,
    required this.ward,
    required this.sizeHa,
    required this.farmType,
    required this.farmerCategory,
    required this.soilType,
    required this.waterSource,
    required this.createdAt,
    required this.updatedAt,
    required this.isSynced,
    this.coverImageBase64 = '',
    this.notes = '',
    this.temperatureCelsius = 0,
    this.humidityPercent = 0,
    this.soilMoisturePercent = 0,
    this.precipitationMm = 0,
    this.greenhouseCount = 0,
    this.greenhouseAreaHa = 0,
    this.cropCapacityHa = 0,
    this.livestockCapacity = 0,
    this.documents = const <FarmDocumentRecord>[],
  });

  final String id;
  final String name;
  final String ward;
  final double sizeHa;
  final FarmType farmType;
  final FarmerCategory farmerCategory;
  final SoilType soilType;
  final WaterSource waterSource;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final String coverImageBase64;
  final String notes;
  final double temperatureCelsius;
  final double humidityPercent;
  final double soilMoisturePercent;
  final double precipitationMm;
  final int greenhouseCount;
  final double greenhouseAreaHa;
  final double cropCapacityHa;
  final int livestockCapacity;
  final List<FarmDocumentRecord> documents;

  bool get supportsCrops => <FarmType>[FarmType.crop, FarmType.greenhouse, FarmType.combined].contains(farmType);
  bool get supportsLivestock => <FarmType>[FarmType.livestock, FarmType.combined].contains(farmType);
  bool get supportsGreenhouse => <FarmType>[FarmType.greenhouse, FarmType.combined].contains(farmType);

  Farm copyWith({
    String? id,
    String? name,
    String? ward,
    double? sizeHa,
    FarmType? farmType,
    FarmerCategory? farmerCategory,
    SoilType? soilType,
    WaterSource? waterSource,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    String? coverImageBase64,
    String? notes,
    double? temperatureCelsius,
    double? humidityPercent,
    double? soilMoisturePercent,
    double? precipitationMm,
    int? greenhouseCount,
    double? greenhouseAreaHa,
    double? cropCapacityHa,
    int? livestockCapacity,
    List<FarmDocumentRecord>? documents,
  }) {
    return Farm(
      id: id ?? this.id,
      name: name ?? this.name,
      ward: ward ?? this.ward,
      sizeHa: sizeHa ?? this.sizeHa,
      farmType: farmType ?? this.farmType,
      farmerCategory: farmerCategory ?? this.farmerCategory,
      soilType: soilType ?? this.soilType,
      waterSource: waterSource ?? this.waterSource,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      coverImageBase64: coverImageBase64 ?? this.coverImageBase64,
      notes: notes ?? this.notes,
      temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
      humidityPercent: humidityPercent ?? this.humidityPercent,
      soilMoisturePercent: soilMoisturePercent ?? this.soilMoisturePercent,
      precipitationMm: precipitationMm ?? this.precipitationMm,
      greenhouseCount: greenhouseCount ?? this.greenhouseCount,
      greenhouseAreaHa: greenhouseAreaHa ?? this.greenhouseAreaHa,
      cropCapacityHa: cropCapacityHa ?? this.cropCapacityHa,
      livestockCapacity: livestockCapacity ?? this.livestockCapacity,
      documents: documents ?? this.documents,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ward': ward,
        'sizeHa': sizeHa,
        'farmType': farmType.name,
        'farmerCategory': farmerCategory.name,
        'soilType': soilType.name,
        'waterSource': waterSource.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isSynced': isSynced,
        'coverImageBase64': coverImageBase64,
        'notes': notes,
        'temperatureCelsius': temperatureCelsius,
        'humidityPercent': humidityPercent,
        'soilMoisturePercent': soilMoisturePercent,
        'precipitationMm': precipitationMm,
        'greenhouseCount': greenhouseCount,
        'greenhouseAreaHa': greenhouseAreaHa,
        'cropCapacityHa': cropCapacityHa,
        'livestockCapacity': livestockCapacity,
        'documents': documents.map((FarmDocumentRecord item) => item.toJson()).toList(),
      };

  factory Farm.fromJson(Map<String, dynamic> json) => Farm(
        id: json['id'] as String,
        name: json['name'] as String,
        ward: json['ward'] as String,
        sizeHa: (json['sizeHa'] as num).toDouble(),
        farmType: FarmType.values.firstWhere(
          (e) => e.name == json['farmType'],
          orElse: () => FarmType.combined,
        ),
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
        isSynced: json['isSynced'] as bool? ?? false,
        coverImageBase64: json['coverImageBase64'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        temperatureCelsius: (json['temperatureCelsius'] as num?)?.toDouble() ?? 0,
        humidityPercent: (json['humidityPercent'] as num?)?.toDouble() ?? 0,
        soilMoisturePercent: (json['soilMoisturePercent'] as num?)?.toDouble() ?? 0,
        precipitationMm: (json['precipitationMm'] as num?)?.toDouble() ?? 0,
        greenhouseCount: (json['greenhouseCount'] as num?)?.toInt() ?? 0,
        greenhouseAreaHa: (json['greenhouseAreaHa'] as num?)?.toDouble() ?? 0,
        cropCapacityHa: (json['cropCapacityHa'] as num?)?.toDouble() ?? 0,
        livestockCapacity: (json['livestockCapacity'] as num?)?.toInt() ?? 0,
        documents: ((json['documents'] as List<dynamic>?) ?? <dynamic>[])
            .whereType<Map>()
            .map((Map item) => FarmDocumentRecord.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
      );
}
