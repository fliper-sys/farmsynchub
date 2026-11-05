import '../../domain/models/livestock.dart';

/// Starting-point suggestions for how long a group takes to mature and how
/// much it eats and drinks. Shared by the livestock form and the guided
/// livestock wizard so both always suggest the same numbers.
abstract final class LivestockPlanning {
  static int suggestedMaturityMonths(
    LivestockSpecies species,
    LivestockPurpose purpose,
    int ageMonths,
    AnimalGrowthStage stage,
  ) {
    final int base = switch (species) {
      LivestockSpecies.chicken => switch (purpose) {
          LivestockPurpose.eggs => 5,
          LivestockPurpose.meat => 2,
          LivestockPurpose.breeding => 6,
          LivestockPurpose.milk => 3,
        },
      LivestockSpecies.goat => switch (purpose) {
          LivestockPurpose.milk => 18,
          LivestockPurpose.breeding => 24,
          LivestockPurpose.meat => 12,
          LivestockPurpose.eggs => 12,
        },
      LivestockSpecies.pig => switch (purpose) {
          LivestockPurpose.breeding => 10,
          LivestockPurpose.meat => 7,
          LivestockPurpose.milk => 7,
          LivestockPurpose.eggs => 7,
        },
      LivestockSpecies.cattle => switch (purpose) {
          LivestockPurpose.milk => 24,
          LivestockPurpose.breeding => 30,
          LivestockPurpose.meat => 24,
          LivestockPurpose.eggs => 24,
        },
      LivestockSpecies.sheep => switch (purpose) {
          LivestockPurpose.meat => 12,
          LivestockPurpose.milk => 18,
          LivestockPurpose.breeding => 18,
          LivestockPurpose.eggs => 12,
        },
      LivestockSpecies.rabbit => switch (purpose) {
          LivestockPurpose.meat => 5,
          LivestockPurpose.breeding => 7,
          LivestockPurpose.milk => 5,
          LivestockPurpose.eggs => 5,
        },
      LivestockSpecies.duck => switch (purpose) {
          LivestockPurpose.eggs => 5,
          LivestockPurpose.meat => 3,
          LivestockPurpose.breeding => 6,
          LivestockPurpose.milk => 3,
        },
      LivestockSpecies.fish => switch (purpose) {
          LivestockPurpose.meat => 6,
          LivestockPurpose.breeding => 8,
          LivestockPurpose.milk => 6,
          LivestockPurpose.eggs => 6,
        },
      LivestockSpecies.snail => switch (purpose) {
          LivestockPurpose.meat => 10,
          LivestockPurpose.breeding => 12,
          LivestockPurpose.milk => 10,
          LivestockPurpose.eggs => 10,
        },
    };
    final int stageAdjustment = switch (stage) {
      AnimalGrowthStage.starter => -1,
      AnimalGrowthStage.grower => 0,
      AnimalGrowthStage.mature => 2,
      AnimalGrowthStage.breeding => 4,
      AnimalGrowthStage.finishing => 1,
    };
    final int ageAdjustment = ageMonths >= base ? 0 : -1;
    return (base + stageAdjustment + ageAdjustment).clamp(1, 120);
  }

  static double feedPerAnimalKg(
    LivestockSpecies species,
    AnimalGrowthStage stage,
    int ageMonths,
    LivestockPurpose purpose,
  ) {
    final double ageFactor = ageMonths < 4
        ? 0.85
        : ageMonths < 12
            ? 1.0
            : 1.15;
    final double purposeFactor =
        purpose == LivestockPurpose.breeding ? 1.05 : 1.0;
    final double base = switch (species) {
      LivestockSpecies.chicken => switch (stage) {
          AnimalGrowthStage.starter => 0.05,
          AnimalGrowthStage.grower => 0.09,
          AnimalGrowthStage.mature => 0.12,
          AnimalGrowthStage.breeding => 0.13,
          AnimalGrowthStage.finishing => 0.10,
        },
      LivestockSpecies.goat => switch (stage) {
          AnimalGrowthStage.starter => 0.6,
          AnimalGrowthStage.grower => 0.9,
          AnimalGrowthStage.mature => 1.1,
          AnimalGrowthStage.breeding => 1.2,
          AnimalGrowthStage.finishing => 1.0,
        },
      LivestockSpecies.pig => switch (stage) {
          AnimalGrowthStage.starter => 0.8,
          AnimalGrowthStage.grower => 1.6,
          AnimalGrowthStage.mature => 2.2,
          AnimalGrowthStage.breeding => 2.0,
          AnimalGrowthStage.finishing => 2.3,
        },
      LivestockSpecies.cattle => switch (stage) {
          AnimalGrowthStage.starter => 4.0,
          AnimalGrowthStage.grower => 6.0,
          AnimalGrowthStage.mature => 8.0,
          AnimalGrowthStage.breeding => 9.0,
          AnimalGrowthStage.finishing => 7.0,
        },
      LivestockSpecies.sheep => switch (stage) {
          AnimalGrowthStage.starter => 0.5,
          AnimalGrowthStage.grower => 0.8,
          AnimalGrowthStage.mature => 1.0,
          AnimalGrowthStage.breeding => 1.1,
          AnimalGrowthStage.finishing => 0.9,
        },
      LivestockSpecies.rabbit => switch (stage) {
          AnimalGrowthStage.starter => 0.05,
          AnimalGrowthStage.grower => 0.09,
          AnimalGrowthStage.mature => 0.13,
          AnimalGrowthStage.breeding => 0.15,
          AnimalGrowthStage.finishing => 0.12,
        },
      LivestockSpecies.duck => switch (stage) {
          AnimalGrowthStage.starter => 0.06,
          AnimalGrowthStage.grower => 0.12,
          AnimalGrowthStage.mature => 0.16,
          AnimalGrowthStage.breeding => 0.18,
          AnimalGrowthStage.finishing => 0.14,
        },
      LivestockSpecies.fish => switch (stage) {
          AnimalGrowthStage.starter => 0.01,
          AnimalGrowthStage.grower => 0.03,
          AnimalGrowthStage.mature => 0.05,
          AnimalGrowthStage.breeding => 0.05,
          AnimalGrowthStage.finishing => 0.04,
        },
      LivestockSpecies.snail => switch (stage) {
          AnimalGrowthStage.starter => 0.01,
          AnimalGrowthStage.grower => 0.02,
          AnimalGrowthStage.mature => 0.03,
          AnimalGrowthStage.breeding => 0.035,
          AnimalGrowthStage.finishing => 0.03,
        },
    };
    return base * ageFactor * purposeFactor;
  }

  static double waterPerAnimalLitres(
    LivestockSpecies species,
    AnimalGrowthStage stage,
    int ageMonths,
    LivestockPurpose purpose,
  ) {
    final double ageFactor = ageMonths < 4
        ? 0.9
        : ageMonths < 12
            ? 1.0
            : 1.1;
    final double stageFactor = switch (stage) {
      AnimalGrowthStage.starter => 0.9,
      AnimalGrowthStage.grower => 1.0,
      AnimalGrowthStage.mature => 1.05,
      AnimalGrowthStage.breeding => 1.1,
      AnimalGrowthStage.finishing => 1.0,
    };
    final double purposeFactor = purpose == LivestockPurpose.milk ? 1.1 : 1.0;
    final double base = switch (species) {
      LivestockSpecies.chicken => 0.25,
      LivestockSpecies.goat => 4.0,
      LivestockSpecies.pig => 6.0,
      LivestockSpecies.cattle => 25.0,
      LivestockSpecies.sheep => 2.5,
      LivestockSpecies.rabbit => 0.4,
      LivestockSpecies.duck => 0.8,
      LivestockSpecies.fish => 0.0,
      LivestockSpecies.snail => 0.05,
    };
    return base * ageFactor * stageFactor * purposeFactor;
  }
}
