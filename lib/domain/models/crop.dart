import 'farm_activity.dart';

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
    this.profileImageBase64 = '',
    this.todoItems = const <FarmTodoItem>[],
    this.inputRecords = const <FarmInputRecord>[],
    this.intelligenceNotes = '',
    this.lastIntelligenceSyncAt,
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
  final String profileImageBase64;
  final List<FarmTodoItem> todoItems;
  final List<FarmInputRecord> inputRecords;
  final String intelligenceNotes;
  final DateTime? lastIntelligenceSyncAt;

  int get openTaskCount => todoItems.where((FarmTodoItem item) => !item.isCompleted).length;
  double get syncedInputCost => inputRecords.fold<double>(0, (double sum, FarmInputRecord item) => sum + item.totalCost);

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
        'profileImageBase64': profileImageBase64,
        'todoItems': todoItems.map((FarmTodoItem item) => item.toJson()).toList(),
        'inputRecords': inputRecords.map((FarmInputRecord item) => item.toJson()).toList(),
        'intelligenceNotes': intelligenceNotes,
        'lastIntelligenceSyncAt': lastIntelligenceSyncAt?.toIso8601String(),
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
        notes: json['notes'] as String? ?? '',
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
        intelligenceNotes: json['intelligenceNotes'] as String? ?? '',
        lastIntelligenceSyncAt: DateTime.tryParse(json['lastIntelligenceSyncAt'] as String? ?? ''),
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
    String? notes,
    DateTime? updatedAt,
    bool? isSynced,
    String? profileImageBase64,
    List<FarmTodoItem>? todoItems,
    List<FarmInputRecord>? inputRecords,
    String? intelligenceNotes,
    DateTime? lastIntelligenceSyncAt,
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
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isSynced: isSynced ?? this.isSynced,
        profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
        todoItems: todoItems ?? this.todoItems,
        inputRecords: inputRecords ?? this.inputRecords,
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
