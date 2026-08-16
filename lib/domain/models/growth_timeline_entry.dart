import 'crop.dart';

/// A single entry in a crop's growth timeline — captures stage transitions,
/// photos, measurements, and notes for visual growth history.
class GrowthTimelineEntry {
  const GrowthTimelineEntry({
    required this.id,
    required this.cropId,
    required this.stage,
    required this.recordedAt,
    this.photoBase64 = '',
    this.notes = '',
    this.heightCm = 0,
    this.leafCount = 0,
    this.createdAt,
  });

  final String id;
  final String cropId;
  final CropStage stage;
  final DateTime recordedAt;
  final String photoBase64;
  final String notes;
  final double heightCm;
  final int leafCount;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'cropId': cropId,
        'stage': stage.name,
        'recordedAt': recordedAt.toIso8601String(),
        'photoBase64': photoBase64,
        'notes': notes,
        'heightCm': heightCm,
        'leafCount': leafCount,
        'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      };

  factory GrowthTimelineEntry.fromJson(Map<String, dynamic> json) =>
      GrowthTimelineEntry(
        id: json['id'] as String? ?? '',
        cropId: json['cropId'] as String? ?? '',
        stage: CropStage.values.firstWhere(
          (CropStage e) => e.name == json['stage'],
          orElse: () => CropStage.seeding,
        ),
        recordedAt:
            DateTime.tryParse(json['recordedAt'] as String? ?? '') ?? DateTime.now(),
        photoBase64: json['photoBase64'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        heightCm: (json['heightCm'] as num?)?.toDouble() ?? 0,
        leafCount: (json['leafCount'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );

  GrowthTimelineEntry copyWith({
    CropStage? stage,
    DateTime? recordedAt,
    String? photoBase64,
    String? notes,
    double? heightCm,
    int? leafCount,
  }) =>
      GrowthTimelineEntry(
        id: id,
        cropId: cropId,
        stage: stage ?? this.stage,
        recordedAt: recordedAt ?? this.recordedAt,
        photoBase64: photoBase64 ?? this.photoBase64,
        notes: notes ?? this.notes,
        heightCm: heightCm ?? this.heightCm,
        leafCount: leafCount ?? this.leafCount,
        createdAt: createdAt,
      );
}
