import 'dart:math' as math;

/// Crops commonly grown under protection (greenhouse/tunnel) by smallholder
/// farmers in this app's target market. `mixedVegetables` is the generic
/// fallback used before a farmer picks a specific crop.
enum GreenhouseCropType {
  mixedVegetables,
  tomato,
  cucumber,
  bellPepper,
  lettuce,
  cabbage,
  watermelon,
  spinach,
}

extension GreenhouseCropTypeX on GreenhouseCropType {
  String get label {
    switch (this) {
      case GreenhouseCropType.mixedVegetables:
        return 'Mixed vegetables';
      case GreenhouseCropType.tomato:
        return 'Tomato';
      case GreenhouseCropType.cucumber:
        return 'Cucumber';
      case GreenhouseCropType.bellPepper:
        return 'Bell pepper';
      case GreenhouseCropType.lettuce:
        return 'Lettuce';
      case GreenhouseCropType.cabbage:
        return 'Cabbage';
      case GreenhouseCropType.watermelon:
        return 'Watermelon';
      case GreenhouseCropType.spinach:
        return 'Spinach';
    }
  }
}

/// Per-crop spacing, support, and cost profile used to size a greenhouse
/// planting layout and estimate a setup budget. Unit costs are typical
/// smallholder-market NGN estimates, not live prices - the UI labels them
/// as a starting point farmers should adjust for their own market.
class GreenhouseCropProfile {
  const GreenhouseCropProfile({
    required this.plantSpacingM,
    required this.rowSpacingM,
    required this.trellisHeightM,
    required this.needsTrellis,
    required this.seedlingCostNaira,
    required this.supportCostPerPlantNaira,
    required this.cycleDays,
    required this.heightNote,
  });

  final double plantSpacingM;
  final double rowSpacingM;

  /// 0 for ground crops that don't need vertical support.
  final double trellisHeightM;
  final bool needsTrellis;
  final double seedlingCostNaira;

  /// Stake/twine/clip cost per plant for trellised crops - 0 otherwise.
  final double supportCostPerPlantNaira;
  final int cycleDays;
  final String heightNote;
}

const Map<GreenhouseCropType, GreenhouseCropProfile> greenhouseCropProfiles =
    <GreenhouseCropType, GreenhouseCropProfile>{
  GreenhouseCropType.mixedVegetables: GreenhouseCropProfile(
    plantSpacingM: 0.35,
    rowSpacingM: 0.60,
    trellisHeightM: 1.5,
    needsTrellis: false,
    seedlingCostNaira: 40,
    supportCostPerPlantNaira: 0,
    cycleDays: 60,
    heightNote:
        'A general mix of crops - keep at least 1.8-2.0 m of clear roof height for airflow and easy work access.',
  ),
  GreenhouseCropType.tomato: GreenhouseCropProfile(
    plantSpacingM: 0.45,
    rowSpacingM: 0.75,
    trellisHeightM: 2.0,
    needsTrellis: true,
    seedlingCostNaira: 60,
    supportCostPerPlantNaira: 250,
    cycleDays: 75,
    heightNote:
        'Tomato needs a trellis or stake line around 2.0 m tall so vines can be trained upward as they grow.',
  ),
  GreenhouseCropType.cucumber: GreenhouseCropProfile(
    plantSpacingM: 0.40,
    rowSpacingM: 0.90,
    trellisHeightM: 2.2,
    needsTrellis: true,
    seedlingCostNaira: 55,
    supportCostPerPlantNaira: 280,
    cycleDays: 55,
    heightNote:
        'Cucumber climbs fast - a trellis/net around 2.2 m tall keeps fruit clean and off the ground.',
  ),
  GreenhouseCropType.bellPepper: GreenhouseCropProfile(
    plantSpacingM: 0.40,
    rowSpacingM: 0.70,
    trellisHeightM: 1.2,
    needsTrellis: true,
    seedlingCostNaira: 60,
    supportCostPerPlantNaira: 180,
    cycleDays: 80,
    heightNote:
        'Bell pepper only needs light staking around 1.0-1.2 m to stop branches breaking under fruit weight.',
  ),
  GreenhouseCropType.lettuce: GreenhouseCropProfile(
    plantSpacingM: 0.25,
    rowSpacingM: 0.30,
    trellisHeightM: 0,
    needsTrellis: false,
    seedlingCostNaira: 20,
    supportCostPerPlantNaira: 0,
    cycleDays: 35,
    heightNote:
        'Lettuce is a low ground crop - no trellis needed, just enough roof clearance (about 1.5 m) to work comfortably.',
  ),
  GreenhouseCropType.cabbage: GreenhouseCropProfile(
    plantSpacingM: 0.40,
    rowSpacingM: 0.50,
    trellisHeightM: 0,
    needsTrellis: false,
    seedlingCostNaira: 25,
    supportCostPerPlantNaira: 0,
    cycleDays: 70,
    heightNote:
        'Cabbage stays low and wide - no support needed, plan for wider row spacing instead of height.',
  ),
  GreenhouseCropType.watermelon: GreenhouseCropProfile(
    plantSpacingM: 0.60,
    rowSpacingM: 1.20,
    trellisHeightM: 1.8,
    needsTrellis: true,
    seedlingCostNaira: 70,
    supportCostPerPlantNaira: 320,
    cycleDays: 85,
    heightNote:
        'Watermelon can be trellised vertically (with fruit slings) at about 1.8 m, or left to sprawl if you have the floor space instead.',
  ),
  GreenhouseCropType.spinach: GreenhouseCropProfile(
    plantSpacingM: 0.20,
    rowSpacingM: 0.25,
    trellisHeightM: 0,
    needsTrellis: false,
    seedlingCostNaira: 15,
    supportCostPerPlantNaira: 0,
    cycleDays: 30,
    heightNote:
        'Spinach is a fast, low ground crop - no trellis needed, just tight spacing to maximise beds.',
  ),
};

/// A full sizing + setup-budget plan for one greenhouse, either derived
/// from a known area or backed out from a target plant count.
class GreenhousePlan {
  const GreenhousePlan({
    required this.cropType,
    required this.usableAreaM2,
    required this.plantSpacingM,
    required this.rowSpacingM,
    required this.estimatedPlantSlots,
    required this.trellisHeightM,
    required this.needsTrellis,
    required this.heightNote,
    required this.coverCostNaira,
    required this.seedlingCostNaira,
    required this.supportCostNaira,
    required this.substrateCostNaira,
    required this.dripLineCostNaira,
    required this.totalBudgetNaira,
  });

  final GreenhouseCropType cropType;
  final double usableAreaM2;
  final double plantSpacingM;
  final double rowSpacingM;
  final int estimatedPlantSlots;
  final double trellisHeightM;
  final bool needsTrellis;
  final String heightNote;
  final double coverCostNaira;
  final double seedlingCostNaira;
  final double supportCostNaira;
  final double substrateCostNaira;
  final double dripLineCostNaira;
  final double totalBudgetNaira;
}

/// Typical smallholder-market NGN unit costs used for the budget estimate.
/// These are deliberately simple, round reference figures - the UI must
/// label them as adjustable starting estimates, not live market prices.
class GreenhouseCostReference {
  static const double coverPerM2Naira = 800;
  static const double dripLinePerMeterNaira = 150;
  static const double substratePerM2Naira = 900;
}

class GreenhousePlannerService {
  const GreenhousePlannerService._();

  /// Builds a plan from a known usable area (m²) for the given crop.
  static GreenhousePlan planForArea({
    required double usableAreaM2,
    required GreenhouseCropType cropType,
  }) {
    final GreenhouseCropProfile profile = greenhouseCropProfiles[cropType]!;
    final int estimatedPlantSlots = math.max(
      1,
      (usableAreaM2 / (profile.plantSpacingM * profile.rowSpacingM)).floor(),
    );
    return _buildPlan(
      cropType: cropType,
      profile: profile,
      usableAreaM2: usableAreaM2,
      estimatedPlantSlots: estimatedPlantSlots,
    );
  }

  /// Backs out the usable area (and resulting plan) needed to fit a target
  /// plant count of the given crop - used when a farmer knows what they
  /// want to grow but not yet how big a greenhouse they need.
  static GreenhousePlan planForTargetPlantCount({
    required int targetPlantCount,
    required GreenhouseCropType cropType,
  }) {
    final GreenhouseCropProfile profile = greenhouseCropProfiles[cropType]!;
    final double usableAreaM2 =
        targetPlantCount * profile.plantSpacingM * profile.rowSpacingM;
    return _buildPlan(
      cropType: cropType,
      profile: profile,
      usableAreaM2: usableAreaM2,
      estimatedPlantSlots: targetPlantCount,
    );
  }

  static GreenhousePlan _buildPlan({
    required GreenhouseCropType cropType,
    required GreenhouseCropProfile profile,
    required double usableAreaM2,
    required int estimatedPlantSlots,
  }) {
    final double coverCostNaira =
        usableAreaM2 * GreenhouseCostReference.coverPerM2Naira;
    final double seedlingCostNaira =
        estimatedPlantSlots * profile.seedlingCostNaira;
    final double supportCostNaira = profile.needsTrellis
        ? estimatedPlantSlots * profile.supportCostPerPlantNaira
        : 0;
    final double substrateCostNaira =
        usableAreaM2 * GreenhouseCostReference.substratePerM2Naira;
    final double dripLineMeters = usableAreaM2 / profile.rowSpacingM;
    final double dripLineCostNaira =
        dripLineMeters * GreenhouseCostReference.dripLinePerMeterNaira;
    final double totalBudgetNaira = coverCostNaira +
        seedlingCostNaira +
        supportCostNaira +
        substrateCostNaira +
        dripLineCostNaira;

    return GreenhousePlan(
      cropType: cropType,
      usableAreaM2: usableAreaM2,
      plantSpacingM: profile.plantSpacingM,
      rowSpacingM: profile.rowSpacingM,
      estimatedPlantSlots: estimatedPlantSlots,
      trellisHeightM: profile.trellisHeightM,
      needsTrellis: profile.needsTrellis,
      heightNote: profile.heightNote,
      coverCostNaira: coverCostNaira,
      seedlingCostNaira: seedlingCostNaira,
      supportCostNaira: supportCostNaira,
      substrateCostNaira: substrateCostNaira,
      dripLineCostNaira: dripLineCostNaira,
      totalBudgetNaira: totalBudgetNaira,
    );
  }
}
