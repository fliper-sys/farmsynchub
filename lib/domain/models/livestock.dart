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
      };

  factory Livestock.fromJson(Map<String, dynamic> json) => Livestock(
        id: json['id'] as String,
        farmId: json['farmId'] as String,
        species: LivestockSpecies.values.firstWhere(
          (e) => e.name == json['species'],
        ),
        breed: json['breed'] as String,
        count: json['count'] as int,
        maleCount: json['maleCount'] as int,
        femaleCount: json['femaleCount'] as int,
        purpose: LivestockPurpose.values.firstWhere(
          (e) => e.name == json['purpose'],
        ),
        housingLocation: HousingType.values.firstWhere(
          (e) => e.name == json['housingLocation'],
        ),
        acquisitionDate: DateTime.parse(json['acquisitionDate'] as String),
        estimatedValue: (json['estimatedValue'] as num).toDouble(),
        vaccinationStatus: json['vaccinationStatus'] as int,
        healthScore: json['healthScore'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        isSynced: json['isSynced'] as bool,
      );
}