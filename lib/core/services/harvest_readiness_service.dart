import '../../domain/models/crop.dart';
import '../../domain/models/livestock.dart';

enum HarvestReadinessKind { crop, livestock }

class HarvestReadinessItem {
  const HarvestReadinessItem({
    required this.kind,
    required this.id,
    required this.farmId,
    required this.title,
    required this.detail,
  });

  final HarvestReadinessKind kind;
  final String id;
  final String farmId;
  final String title;
  final String detail;
}

/// Detects crops ready to harvest and livestock that reached finishing stage.
///
/// Deliberately read-only: it never creates inventory itself. It only
/// surfaces candidates so the owner can confirm the real harvested/sale
/// quantity through the existing record-harvest / record-ready-for-sale
/// flows, which are the only places that actually touch inventory.
class HarvestReadinessService {
  const HarvestReadinessService._();

  static List<HarvestReadinessItem> readyCrops(List<Crop> crops) {
    return crops
        .where((Crop crop) =>
            crop.status != CropStatus.harvested &&
            (crop.status == CropStatus.ready || crop.daysToHarvest <= 0))
        .map(
          (Crop crop) => HarvestReadinessItem(
            kind: HarvestReadinessKind.crop,
            id: crop.id,
            farmId: crop.farmId,
            title: '${crop.name} is ready to harvest',
            detail: crop.daysToHarvest < 0
                ? '${-crop.daysToHarvest} day${-crop.daysToHarvest == 1 ? '' : 's'} past expected harvest date'
                : 'Expected harvest date has arrived',
          ),
        )
        .toList(growable: false);
  }

  static List<HarvestReadinessItem> finishedLivestock(
      List<Livestock> livestock) {
    return livestock
        .where(
            (Livestock item) => item.growthStage == AnimalGrowthStage.finishing)
        .map(
          (Livestock item) => HarvestReadinessItem(
            kind: HarvestReadinessKind.livestock,
            id: item.id,
            farmId: item.farmId,
            title: '${item.count} ${item.breed} reached finishing stage',
            detail: 'Ready for a market weight check and sale listing',
          ),
        )
        .toList(growable: false);
  }

  static List<HarvestReadinessItem> all({
    required List<Crop> crops,
    required List<Livestock> livestock,
  }) {
    return <HarvestReadinessItem>[
      ...readyCrops(crops),
      ...finishedLivestock(livestock),
    ];
  }
}
