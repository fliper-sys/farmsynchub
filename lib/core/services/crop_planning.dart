import '../../data/services/crop_advice_catalog.dart';
import '../../domain/models/crop.dart';

/// Starting-point suggestions for how long a crop takes and what it may
/// yield. Shared by the crop form and the guided crop wizard so both always
/// suggest the same numbers.
abstract final class CropPlanning {
  static const Map<String, int> _baseCycleDays = <String, int>{
    'maize': 110,
    'rice': 120,
    'sorghum': 110,
    'millet': 90,
    'wheat': 125,
    'cassava': 360,
    'yam': 270,
    'sweet potato': 120,
    'potato': 100,
    'bean': 70,
    'cowpea': 75,
    'groundnut': 110,
    'soybean': 100,
    'tomato': 110,
    'pepper': 150,
    'onion': 150,
    'okra': 65,
    'cabbage': 90,
  };

  static const Map<String, double> _yieldPerHa = <String, double>{
    'maize': 4200,
    'rice': 5200,
    'sorghum': 2600,
    'millet': 1800,
    'wheat': 3500,
    'cassava': 24000,
    'yam': 12000,
    'sweet potato': 15000,
    'potato': 17000,
    'bean': 1200,
    'cowpea': 1000,
    'groundnut': 1700,
    'soybean': 2400,
    'tomato': 22000,
    'pepper': 13000,
    'onion': 20000,
    'okra': 8500,
    'cabbage': 28000,
  };

  /// Days from planting to harvest. Unknown crops use 90 days; growing under
  /// cover shortens the cycle by a week.
  static int suggestedCycleDays(
    CropAdviceProfile? profile,
    CropStage stage,
    bool protectedEnvironment,
  ) {
    final String key = profile?.name.toLowerCase().trim() ?? '';
    final int base = _baseCycleDays[key] ?? 90;
    final int protectedBonus = protectedEnvironment ? -7 : 0;
    return (base + protectedBonus).clamp(45, 540);
  }

  /// Expected harvest in kilograms for [areaHa] hectares. Unknown crops use
  /// 2,500 kg per hectare; protected growing adds 10%.
  static double suggestedYieldKg(
    CropAdviceProfile? profile,
    double areaHa,
    CropStage stage,
    bool protectedEnvironment,
  ) {
    final String key = profile?.name.toLowerCase().trim() ?? '';
    final double base = _yieldPerHa[key] ?? 2500;
    final double stageFactor = switch (stage) {
      CropStage.seeding => 1.0,
      CropStage.germination => 0.98,
      CropStage.vegetative => 1.0,
      CropStage.flowering => 0.96,
      CropStage.fruiting => 0.92,
    };
    final double environmentFactor = protectedEnvironment ? 1.1 : 1.0;
    return areaHa * base * stageFactor * environmentFactor;
  }
}
