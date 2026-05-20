import 'farm_activity.dart';

/// Livestock species enumeration.
enum LivestockSpecies {
  goat,
  chicken,
  pig,
  cattle,
  sheep,
}

/// Livestock purpose enumeration.
enum LivestockPurpose {
  meat,
  milk,
  eggs,
  breeding,
}

/// Housing type enumeration.
enum HousingType {
  freeRange,
  barn,
  shed,
  coop,
}

/// Livestock model representing animals on a farm.
class Livestock {
  const Livestock({
    required this.id,
    required this.farmId,
    required this.species,
    required this.breed,
    required this.count,
    required this.maleCount,
    required this.femaleCount,
    required this.purpose,
    required this.housingLocation,
    required this.acquisitionDate,
    required this.estimatedValue,
    required this.vaccinationStatus,
    required this.healthScore,
    required this.createdAt,
    required this.updatedAt,
    required this.isSynced,
    this.profileImageBase64 = '',
    this.todoItems = const <FarmTodoItem>[],
    this.inputRecords = const <FarmInputRecord>[],
    this.stockNotes = '',
    this.intelligenceNotes = '',
    this.lastIntelligenceSyncAt,
  });

  final String id;
  final String farmId;
  final LivestockSpecies species;
  final String breed;
  final int count;
  final int maleCount;
  final int femaleCount;
  final LivestockPurpose purpose;
  final HousingType housingLocation;
  final DateTime acquisitionDate;
  final double estimatedValue;
  final int vaccinationStatus;
  final int healthScore;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final String profileImageBase64;
  final List<FarmTodoItem> todoItems;
  final List<FarmInputRecord> inputRecords;
  final String stockNotes;
  final String intelligenceNotes;
  final DateTime? lastIntelligenceSyncAt;

  int get openTaskCount => todoItems.where((FarmTodoItem item) => !item.isCompleted).length;
  double get syncedInputCost => inputRecords.fold<double>(0, (double sum, FarmInputRecord item) => sum + item.totalCost);

  Map<String, dynamic> toJson() => {
        'id': id,
        'farmId': farmId,
        'species': species.name,
        'breed': breed,
        'count': count,
        'maleCount': maleCount,
        'femaleCount': femaleCount,
        'purpose': purpose.name,
        'housingLocation': housingLocation.name,
        'acquisitionDate': acquisitionDate.toIso8601String(),
        'estimatedValue': estimatedValue,
        'vaccinationStatus': vaccinationStatus,
        'healthScore': healthScore,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isSynced': isSynced,
        'profileImageBase64': profileImageBase64,
        'todoItems': todoItems.map((FarmTodoItem item) => item.toJson()).toList(),
        'inputRecords': inputRecords.map((FarmInputRecord item) => item.toJson()).toList(),
        'stockNotes': stockNotes,
        'intelligenceNotes': intelligenceNotes,
        'lastIntelligenceSyncAt': lastIntelligenceSyncAt?.toIso8601String(),
      };

  factory Livestock.fromJson(Map<String, dynamic> json) => Livestock(
        id: json['id'] as String? ?? '',
        farmId: json['farmId'] as String? ?? '',
        species: LivestockSpecies.values.firstWhere(
          (e) => e.name == json['species'],
          orElse: () => LivestockSpecies.goat,
        ),
        breed: json['breed'] as String? ?? 'Unknown',
        count: (json['count'] as num?)?.toInt() ?? 0,
        maleCount: (json['maleCount'] as num?)?.toInt() ?? 0,
        femaleCount: (json['femaleCount'] as num?)?.toInt() ?? 0,
        purpose: LivestockPurpose.values.firstWhere(
          (e) => e.name == json['purpose'],
          orElse: () => LivestockPurpose.meat,
        ),
        housingLocation: HousingType.values.firstWhere(
          (e) => e.name == json['housingLocation'],
          orElse: () => HousingType.shed,
        ),
        acquisitionDate: DateTime.tryParse(json['acquisitionDate'] as String? ?? '') ?? DateTime.now(),
        estimatedValue: (json['estimatedValue'] as num?)?.toDouble() ?? 0,
        vaccinationStatus: (json['vaccinationStatus'] as num?)?.toInt() ?? 0,
        healthScore: (json['healthScore'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
        isSynced: json['isSynced'] as bool? ?? false,
        profileImageBase64: json['profileImageBase64'] as String? ?? '',
        todoItems: _jsonObjectList(json['todoItems'])
            .map(FarmTodoItem.fromJson)
            .toList(),
        inputRecords: _jsonObjectList(json['inputRecords'])
            .map(FarmInputRecord.fromJson)
            .toList(),
        stockNotes: json['stockNotes'] as String? ?? '',
        intelligenceNotes: json['intelligenceNotes'] as String? ?? '',
        lastIntelligenceSyncAt: DateTime.tryParse(json['lastIntelligenceSyncAt'] as String? ?? ''),
      );

  Livestock copyWith({
    String? farmId,
    LivestockSpecies? species,
    String? breed,
    int? count,
    int? maleCount,
    int? femaleCount,
    LivestockPurpose? purpose,
    HousingType? housingLocation,
    DateTime? acquisitionDate,
    double? estimatedValue,
    int? vaccinationStatus,
    int? healthScore,
    DateTime? updatedAt,
    bool? isSynced,
    String? profileImageBase64,
    List<FarmTodoItem>? todoItems,
    List<FarmInputRecord>? inputRecords,
    String? stockNotes,
    String? intelligenceNotes,
    DateTime? lastIntelligenceSyncAt,
  }) =>
      Livestock(
        id: id,
        farmId: farmId ?? this.farmId,
        species: species ?? this.species,
        breed: breed ?? this.breed,
        count: count ?? this.count,
        maleCount: maleCount ?? this.maleCount,
        femaleCount: femaleCount ?? this.femaleCount,
        purpose: purpose ?? this.purpose,
        housingLocation: housingLocation ?? this.housingLocation,
        acquisitionDate: acquisitionDate ?? this.acquisitionDate,
        estimatedValue: estimatedValue ?? this.estimatedValue,
        vaccinationStatus: vaccinationStatus ?? this.vaccinationStatus,
        healthScore: healthScore ?? this.healthScore,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isSynced: isSynced ?? this.isSynced,
        profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
        todoItems: todoItems ?? this.todoItems,
        inputRecords: inputRecords ?? this.inputRecords,
        stockNotes: stockNotes ?? this.stockNotes,
        intelligenceNotes: intelligenceNotes ?? this.intelligenceNotes,
        lastIntelligenceSyncAt: lastIntelligenceSyncAt ?? this.lastIntelligenceSyncAt,
      );
}

List<Map<String, dynamic>> _jsonObjectList(Object? value) {
  if (value is! Iterable) {
    return <Map<String, dynamic>>[];
  }
  return value
      .whereType<Map>()
      .map((Map item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}
