import 'farm_activity.dart';
import 'photo_journal_entry.dart';

/// Livestock species enumeration.
enum LivestockSpecies {
  goat,
  chicken,
  pig,
  cattle,
  sheep,
  rabbit,
  duck,
  fish,
  snail,
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

/// Animal growth stage enumeration.
enum AnimalGrowthStage {
  starter,
  grower,
  mature,
  breeding,
  finishing,
}

enum LivestockRecordPeriod {
  daily,
  weekly,
  monthly,
}

class LivestockProductionRecord {
  const LivestockProductionRecord({
    required this.id,
    required this.period,
    required this.recordedAt,
    required this.createdAt,
    required this.updatedAt,
    this.weightKg = 0,
    this.feedKg = 0,
    this.eggCount = 0,
    this.eggUnit = '',
    this.notes = '',
  });

  final String id;
  final LivestockRecordPeriod period;
  final DateTime recordedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double weightKg;
  final double feedKg;
  final int eggCount;
  final String eggUnit;
  final String notes;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'period': period.name,
        'recordedAt': recordedAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'weightKg': weightKg,
        'feedKg': feedKg,
        'eggCount': eggCount,
        'eggUnit': eggUnit,
        'notes': notes,
      };

  factory LivestockProductionRecord.fromJson(Map<String, dynamic> json) {
    return LivestockProductionRecord(
      id: json['id'] as String? ?? '',
      period: LivestockRecordPeriod.values.firstWhere(
        (LivestockRecordPeriod value) => value.name == json['period'],
        orElse: () => LivestockRecordPeriod.daily,
      ),
      recordedAt: DateTime.tryParse(json['recordedAt'] as String? ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0,
      feedKg: (json['feedKg'] as num?)?.toDouble() ?? 0,
      eggCount: (json['eggCount'] as num?)?.toInt() ?? 0,
      eggUnit: json['eggUnit'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }

  LivestockProductionRecord copyWith({
    LivestockRecordPeriod? period,
    DateTime? recordedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? weightKg,
    double? feedKg,
    int? eggCount,
    String? eggUnit,
    String? notes,
  }) {
    return LivestockProductionRecord(
      id: id,
      period: period ?? this.period,
      recordedAt: recordedAt ?? this.recordedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      weightKg: weightKg ?? this.weightKg,
      feedKg: feedKg ?? this.feedKg,
      eggCount: eggCount ?? this.eggCount,
      eggUnit: eggUnit ?? this.eggUnit,
      notes: notes ?? this.notes,
    );
  }
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
    required this.growthStage,
    required this.averageAgeMonths,
    required this.targetMaturityMonths,
    required this.createdAt,
    required this.updatedAt,
    required this.isSynced,
    this.emoji = '🐾',
    this.profileImageBase64 = '',
    this.coverImageBase64 = '',
    this.averageWeightKg = 0,
    this.dailyFeedKg = 0,
    this.dailyWaterLitres = 0,
    this.mortalityCount = 0,
    this.todoItems = const <FarmTodoItem>[],
    this.inputRecords = const <FarmInputRecord>[],
    this.productionLogs = const <LivestockProductionRecord>[],
    this.stockNotes = '',
    this.intelligenceNotes = '',
    this.lastIntelligenceSyncAt,
    this.photoJournal = const <PhotoJournalEntry>[],
    this.feedReminderEnabled = false,
    this.feedReminderHour = 7,
    this.feedReminderMinute = 0,
    this.isFavorite = false,
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
  final AnimalGrowthStage growthStage;
  final int averageAgeMonths;
  final int targetMaturityMonths;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final String emoji;
  final String profileImageBase64;
  final String coverImageBase64;
  final double averageWeightKg;
  final double dailyFeedKg;
  final double dailyWaterLitres;
  final int mortalityCount;
  final List<FarmTodoItem> todoItems;
  final List<FarmInputRecord> inputRecords;
  final List<LivestockProductionRecord> productionLogs;
  final String stockNotes;
  final String intelligenceNotes;
  final DateTime? lastIntelligenceSyncAt;
  final List<PhotoJournalEntry> photoJournal;
  final bool feedReminderEnabled;
  final int feedReminderHour;
  final int feedReminderMinute;
  final bool isFavorite;

  int get openTaskCount => todoItems.where((FarmTodoItem item) => !item.isCompleted).length;
  double get syncedInputCost => inputRecords.fold<double>(0, (double sum, FarmInputRecord item) => sum + item.totalCost);
  double get growthProgress {
    if (targetMaturityMonths <= 0) {
      return 0;
    }
    final double progress = averageAgeMonths / targetMaturityMonths;
    return progress.clamp(0, 1).toDouble();
  }

  /// Daily feed-log entries: production log records with period == daily
  /// and a positive feedKg, one per calendar day the group was marked fed.
  List<LivestockProductionRecord> get feedLogEntries => productionLogs
      .where((LivestockProductionRecord record) =>
          record.period == LivestockRecordPeriod.daily && record.feedKg > 0)
      .toList(growable: false);

  bool wasFedOn(DateTime day) {
    final DateTime target = DateTime(day.year, day.month, day.day);
    return feedLogEntries.any((LivestockProductionRecord record) {
      final DateTime recordDay = DateTime(
          record.recordedAt.year, record.recordedAt.month, record.recordedAt.day);
      return recordDay == target;
    });
  }

  bool get wasFedToday => wasFedOn(DateTime.now());

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
        'growthStage': growthStage.name,
        'averageAgeMonths': averageAgeMonths,
        'targetMaturityMonths': targetMaturityMonths,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isSynced': isSynced,
        'emoji': emoji,
        'profileImageBase64': profileImageBase64,
        'coverImageBase64': coverImageBase64,
        'averageWeightKg': averageWeightKg,
        'dailyFeedKg': dailyFeedKg,
        'dailyWaterLitres': dailyWaterLitres,
        'mortalityCount': mortalityCount,
        'todoItems': todoItems.map((FarmTodoItem item) => item.toJson()).toList(),
        'inputRecords': inputRecords.map((FarmInputRecord item) => item.toJson()).toList(),
        'productionLogs': productionLogs.map((LivestockProductionRecord item) => item.toJson()).toList(),
        'stockNotes': stockNotes,
        'intelligenceNotes': intelligenceNotes,
        'lastIntelligenceSyncAt': lastIntelligenceSyncAt?.toIso8601String(),
        'photoJournal':
            photoJournal.map((PhotoJournalEntry item) => item.toJson()).toList(),
        'feedReminderEnabled': feedReminderEnabled,
        'feedReminderHour': feedReminderHour,
        'feedReminderMinute': feedReminderMinute,
        'isFavorite': isFavorite,
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
        growthStage: AnimalGrowthStage.values.firstWhere(
          (e) => e.name == json['growthStage'],
          orElse: () => AnimalGrowthStage.grower,
        ),
        averageAgeMonths: (json['averageAgeMonths'] as num?)?.toInt() ?? 0,
        targetMaturityMonths: (json['targetMaturityMonths'] as num?)?.toInt() ?? 12,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
        isSynced: json['isSynced'] as bool? ?? false,
        emoji: json['emoji'] as String? ?? '🐾',
        profileImageBase64: json['profileImageBase64'] as String? ?? '',
        coverImageBase64: json['coverImageBase64'] as String? ?? '',
        averageWeightKg: (json['averageWeightKg'] as num?)?.toDouble() ?? 0,
        dailyFeedKg: (json['dailyFeedKg'] as num?)?.toDouble() ?? 0,
        dailyWaterLitres: (json['dailyWaterLitres'] as num?)?.toDouble() ?? 0,
        mortalityCount: (json['mortalityCount'] as num?)?.toInt() ?? 0,
        todoItems: _jsonObjectList(json['todoItems'])
            .map(FarmTodoItem.fromJson)
            .toList(),
        inputRecords: _jsonObjectList(json['inputRecords'])
            .map(FarmInputRecord.fromJson)
            .toList(),
        productionLogs: _jsonObjectList(json['productionLogs'])
            .map(LivestockProductionRecord.fromJson)
            .toList(),
        stockNotes: json['stockNotes'] as String? ?? '',
        intelligenceNotes: json['intelligenceNotes'] as String? ?? '',
        lastIntelligenceSyncAt: DateTime.tryParse(json['lastIntelligenceSyncAt'] as String? ?? ''),
        photoJournal: _jsonObjectList(json['photoJournal'])
            .map(PhotoJournalEntry.fromJson)
            .toList(),
        feedReminderEnabled: json['feedReminderEnabled'] as bool? ?? false,
        feedReminderHour: (json['feedReminderHour'] as num?)?.toInt() ?? 7,
        feedReminderMinute: (json['feedReminderMinute'] as num?)?.toInt() ?? 0,
        isFavorite: json['isFavorite'] as bool? ?? false,
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
    AnimalGrowthStage? growthStage,
    int? averageAgeMonths,
    int? targetMaturityMonths,
    DateTime? updatedAt,
    bool? isSynced,
    String? emoji,
    String? profileImageBase64,
    String? coverImageBase64,
    double? averageWeightKg,
    double? dailyFeedKg,
    double? dailyWaterLitres,
    int? mortalityCount,
    List<FarmTodoItem>? todoItems,
    List<FarmInputRecord>? inputRecords,
    List<LivestockProductionRecord>? productionLogs,
    String? stockNotes,
    String? intelligenceNotes,
    DateTime? lastIntelligenceSyncAt,
    List<PhotoJournalEntry>? photoJournal,
    bool? feedReminderEnabled,
    int? feedReminderHour,
    int? feedReminderMinute,
    bool? isFavorite,
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
        growthStage: growthStage ?? this.growthStage,
        averageAgeMonths: averageAgeMonths ?? this.averageAgeMonths,
        targetMaturityMonths: targetMaturityMonths ?? this.targetMaturityMonths,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isSynced: isSynced ?? this.isSynced,
        emoji: emoji ?? this.emoji,
        profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
        coverImageBase64: coverImageBase64 ?? this.coverImageBase64,
        averageWeightKg: averageWeightKg ?? this.averageWeightKg,
        dailyFeedKg: dailyFeedKg ?? this.dailyFeedKg,
        dailyWaterLitres: dailyWaterLitres ?? this.dailyWaterLitres,
        mortalityCount: mortalityCount ?? this.mortalityCount,
        todoItems: todoItems ?? this.todoItems,
        inputRecords: inputRecords ?? this.inputRecords,
        productionLogs: productionLogs ?? this.productionLogs,
        stockNotes: stockNotes ?? this.stockNotes,
        intelligenceNotes: intelligenceNotes ?? this.intelligenceNotes,
        lastIntelligenceSyncAt: lastIntelligenceSyncAt ?? this.lastIntelligenceSyncAt,
        photoJournal: photoJournal ?? this.photoJournal,
        feedReminderEnabled: feedReminderEnabled ?? this.feedReminderEnabled,
        feedReminderHour: feedReminderHour ?? this.feedReminderHour,
        feedReminderMinute: feedReminderMinute ?? this.feedReminderMinute,
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
