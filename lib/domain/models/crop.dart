import 'farm_activity.dart';
import 'photo_journal_entry.dart';

enum LandSizeUnit {
  hectares,
  plots,
}

extension LandSizeUnitX on LandSizeUnit {
  String get label {
    switch (this) {
      case LandSizeUnit.hectares:
        return 'Hectares';
      case LandSizeUnit.plots:
        return 'Plots';
    }
  }

  String get shortLabel {
    switch (this) {
      case LandSizeUnit.hectares:
        return 'ha';
      case LandSizeUnit.plots:
        return 'plots';
    }
  }
}

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
    required this.cycleLengthDays,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.isSynced,
    this.profileImageBase64 = '',
    this.landSizeValue = 0,
    this.landSizeUnit = LandSizeUnit.hectares,
    this.targetYieldKg = 0,
    this.protectedEnvironment = false,
    this.todoItems = const <FarmTodoItem>[],
    this.inputRecords = const <FarmInputRecord>[],
    this.intelligenceNotes = '',
    this.lastIntelligenceSyncAt,
    this.photoJournal = const <PhotoJournalEntry>[],
    this.isFavorite = false,
  });

  final String id;
  final String farmId;
  final String name;
  final String variety;
  final double areaHa;
  final double landSizeValue;
  final LandSizeUnit landSizeUnit;
  final DateTime plantingDate;
  final DateTime expectedHarvestDate;
  final CropStage currentStage;
  final CropStatus status;
  final double totalInputCost;
  final int cycleLengthDays;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final String profileImageBase64;
  final double targetYieldKg;
  final bool protectedEnvironment;
  final List<FarmTodoItem> todoItems;
  final List<FarmInputRecord> inputRecords;
  final String intelligenceNotes;
  final DateTime? lastIntelligenceSyncAt;
  final List<PhotoJournalEntry> photoJournal;
  final bool isFavorite;

  int get openTaskCount => todoItems.where((FarmTodoItem item) => !item.isCompleted).length;
  double get syncedInputCost => inputRecords.fold<double>(0, (double sum, FarmInputRecord item) => sum + item.totalCost);
  int get daysSincePlanting => DateTime.now().difference(plantingDate).inDays;
  int get daysToHarvest => expectedHarvestDate.difference(DateTime.now()).inDays;
  double get areaInPlots => areaHa / 0.0648;
  String get landSizeLabel => landSizeUnit == LandSizeUnit.plots
      ? '${landSizeValue.toStringAsFixed(1)} plots'
      : '${landSizeValue.toStringAsFixed(2)} ha';
  double get growthProgress {
    if (cycleLengthDays <= 0) {
      return 0;
    }
    final double progress = daysSincePlanting / cycleLengthDays;
    return progress.clamp(0, 1).toDouble();
  }

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
        'cycleLengthDays': cycleLengthDays,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isSynced': isSynced,
        'profileImageBase64': profileImageBase64,
        'landSizeValue': landSizeValue,
        'landSizeUnit': landSizeUnit.name,
        'targetYieldKg': targetYieldKg,
        'protectedEnvironment': protectedEnvironment,
        'todoItems': todoItems.map((FarmTodoItem item) => item.toJson()).toList(),
        'inputRecords': inputRecords.map((FarmInputRecord item) => item.toJson()).toList(),
        'intelligenceNotes': intelligenceNotes,
        'lastIntelligenceSyncAt': lastIntelligenceSyncAt?.toIso8601String(),
        'photoJournal':
            photoJournal.map((PhotoJournalEntry item) => item.toJson()).toList(),
        'isFavorite': isFavorite,
      };

  factory Crop.fromJson(Map<String, dynamic> json) => Crop(
        id: json['id'] as String? ?? '',
        farmId: json['farmId'] as String? ?? '',
        name: json['name'] as String? ?? 'Unnamed crop',
        variety: json['variety'] as String? ?? 'Unknown',
        areaHa: (json['areaHa'] as num?)?.toDouble() ?? 0,
        plantingDate: DateTime.tryParse(json['plantingDate'] as String? ?? '') ?? DateTime.now(),
        expectedHarvestDate: DateTime.tryParse(json['expectedHarvestDate'] as String? ?? '') ??
            DateTime.now().add(const Duration(days: 90)),
        currentStage: CropStage.values.firstWhere(
          (e) => e.name == json['currentStage'],
          orElse: () => CropStage.seeding,
        ),
        status: CropStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => CropStatus.planted,
        ),
        totalInputCost: (json['totalInputCost'] as num?)?.toDouble() ?? 0,
        cycleLengthDays: (json['cycleLengthDays'] as num?)?.toInt() ??
            (DateTime.tryParse(json['expectedHarvestDate'] as String? ?? '') ?? DateTime.now().add(const Duration(days: 90)))
                .difference(DateTime.tryParse(json['plantingDate'] as String? ?? '') ?? DateTime.now())
                .inDays,
        notes: json['notes'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
        isSynced: json['isSynced'] as bool? ?? false,
        profileImageBase64: json['profileImageBase64'] as String? ?? '',
        landSizeValue: _landSizeValueFromJson(json),
        landSizeUnit: LandSizeUnit.values.firstWhere(
          (LandSizeUnit value) => value.name == json['landSizeUnit'],
          orElse: () => LandSizeUnit.hectares,
        ),
        targetYieldKg: (json['targetYieldKg'] as num?)?.toDouble() ?? 0,
        protectedEnvironment: json['protectedEnvironment'] as bool? ?? false,
        todoItems: _jsonObjectList(json['todoItems'])
            .map(FarmTodoItem.fromJson)
            .toList(),
        inputRecords: _jsonObjectList(json['inputRecords'])
            .map(FarmInputRecord.fromJson)
            .toList(),
        intelligenceNotes: json['intelligenceNotes'] as String? ?? '',
        lastIntelligenceSyncAt: DateTime.tryParse(json['lastIntelligenceSyncAt'] as String? ?? ''),
        photoJournal: _jsonObjectList(json['photoJournal'])
            .map(PhotoJournalEntry.fromJson)
            .toList(),
        isFavorite: json['isFavorite'] as bool? ?? false,
      );

  Crop copyWith({
    String? farmId,
    String? name,
    String? variety,
    double? areaHa,
    DateTime? plantingDate,
    DateTime? expectedHarvestDate,
    CropStage? currentStage,
    CropStatus? status,
    double? totalInputCost,
    int? cycleLengthDays,
    String? notes,
    DateTime? updatedAt,
    bool? isSynced,
    String? profileImageBase64,
    double? landSizeValue,
    LandSizeUnit? landSizeUnit,
    double? targetYieldKg,
    bool? protectedEnvironment,
    List<FarmTodoItem>? todoItems,
    List<FarmInputRecord>? inputRecords,
    String? intelligenceNotes,
    DateTime? lastIntelligenceSyncAt,
    List<PhotoJournalEntry>? photoJournal,
    bool? isFavorite,
  }) =>
      Crop(
        id: id,
        farmId: farmId ?? this.farmId,
        name: name ?? this.name,
        variety: variety ?? this.variety,
        areaHa: areaHa ?? this.areaHa,
        plantingDate: plantingDate ?? this.plantingDate,
        expectedHarvestDate: expectedHarvestDate ?? this.expectedHarvestDate,
        currentStage: currentStage ?? this.currentStage,
        status: status ?? this.status,
        totalInputCost: totalInputCost ?? this.totalInputCost,
        cycleLengthDays: cycleLengthDays ?? this.cycleLengthDays,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isSynced: isSynced ?? this.isSynced,
        profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
        landSizeValue: landSizeValue ?? this.landSizeValue,
        landSizeUnit: landSizeUnit ?? this.landSizeUnit,
        targetYieldKg: targetYieldKg ?? this.targetYieldKg,
        protectedEnvironment: protectedEnvironment ?? this.protectedEnvironment,
        todoItems: todoItems ?? this.todoItems,
        inputRecords: inputRecords ?? this.inputRecords,
        intelligenceNotes: intelligenceNotes ?? this.intelligenceNotes,
        lastIntelligenceSyncAt: lastIntelligenceSyncAt ?? this.lastIntelligenceSyncAt,
        photoJournal: photoJournal ?? this.photoJournal,
        isFavorite: isFavorite ?? this.isFavorite,
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

double _landSizeValueFromJson(Map<String, dynamic> json) {
  final double areaHa = (json['areaHa'] as num?)?.toDouble() ?? 0;
  final String unit = json['landSizeUnit'] as String? ?? LandSizeUnit.hectares.name;
  final double raw = (json['landSizeValue'] as num?)?.toDouble() ?? areaHa;
  if (unit == LandSizeUnit.plots.name) {
    return raw == areaHa ? areaHa / 0.0648 : raw;
  }
  return raw;
}
