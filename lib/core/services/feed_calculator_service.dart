import '../../domain/models/livestock.dart';

/// Reusable service for calculating feed, water, and maturity estimates
/// for livestock groups based on species, growth stage, purpose, and age.
class FeedCalculatorService {
  /// Calculates suggested maturity months for a livestock group.
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

  /// Calculates daily feed per animal (kg) based on species, stage, age, and
  /// purpose. When [actualWeightKg] is supplied (the group's recorded
  /// average weight), the estimate is nudged up or down to reflect animals
  /// that are heavier or lighter than typical for their stage, instead of
  /// always returning the same flat number regardless of measured growth.
  static double feedPerAnimalKg(
    LivestockSpecies species,
    AnimalGrowthStage stage,
    int ageMonths,
    LivestockPurpose purpose, {
    double? actualWeightKg,
  }) {
    final double ageFactor = ageMonths < 4 ? 0.85 : ageMonths < 12 ? 1.0 : 1.15;
    final double purposeFactor = purpose == LivestockPurpose.breeding ? 1.05 : 1.0;
    final double conditionFactor =
        _conditionFactor(species, stage, actualWeightKg);
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
    return base * ageFactor * purposeFactor * conditionFactor;
  }

  /// Calculates daily water per animal (litres) based on species, stage,
  /// age, and purpose. [actualWeightKg] applies the same condition-based
  /// nudge used in [feedPerAnimalKg] since heavier animals also drink more.
  static double waterPerAnimalLitres(
    LivestockSpecies species,
    AnimalGrowthStage stage,
    int ageMonths,
    LivestockPurpose purpose, {
    double? actualWeightKg,
  }) {
    final double ageFactor = ageMonths < 4 ? 0.9 : ageMonths < 12 ? 1.0 : 1.1;
    final double stageFactor = switch (stage) {
      AnimalGrowthStage.starter => 0.9,
      AnimalGrowthStage.grower => 1.0,
      AnimalGrowthStage.mature => 1.05,
      AnimalGrowthStage.breeding => 1.1,
      AnimalGrowthStage.finishing => 1.0,
    };
    final double purposeFactor = purpose == LivestockPurpose.milk ? 1.1 : 1.0;
    final double conditionFactor =
        _conditionFactor(species, stage, actualWeightKg);
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
    return base * ageFactor * stageFactor * purposeFactor * conditionFactor;
  }

  /// Reference mature (adult) weight per species, used as the basis for
  /// [_conditionFactor]'s expected-weight-at-stage calculation.
  static double _matureWeightKg(LivestockSpecies species) {
    switch (species) {
      case LivestockSpecies.goat:
        return 25;
      case LivestockSpecies.chicken:
        return 1.5;
      case LivestockSpecies.pig:
        return 50;
      case LivestockSpecies.cattle:
        return 200;
      case LivestockSpecies.sheep:
        return 30;
      case LivestockSpecies.rabbit:
        return 2.5;
      case LivestockSpecies.duck:
        return 3;
      case LivestockSpecies.fish:
        return 1;
      case LivestockSpecies.snail:
        return 0.15;
    }
  }

  static double _stageWeightMultiplier(AnimalGrowthStage stage) {
    switch (stage) {
      case AnimalGrowthStage.starter:
        return 0.3;
      case AnimalGrowthStage.grower:
        return 0.6;
      case AnimalGrowthStage.mature:
        return 0.9;
      case AnimalGrowthStage.breeding:
        return 1.0;
      case AnimalGrowthStage.finishing:
        return 1.1;
    }
  }

  /// Compares a recorded average weight against the expected weight for
  /// the species/stage and returns a multiplier (clamped to +/-30%) so
  /// under- or over-weight groups get an adjusted ration instead of the
  /// flat stage default.
  static double _conditionFactor(
    LivestockSpecies species,
    AnimalGrowthStage stage,
    double? actualWeightKg,
  ) {
    if (actualWeightKg == null || actualWeightKg <= 0) {
      return 1.0;
    }
    final double expectedWeightKg =
        _matureWeightKg(species) * _stageWeightMultiplier(stage);
    if (expectedWeightKg <= 0) {
      return 1.0;
    }
    return (actualWeightKg / expectedWeightKg).clamp(0.7, 1.3);
  }

  /// Returns a feeding advice string based on livestock parameters.
  static String feedingAdvice(
    LivestockSpecies species,
    AnimalGrowthStage stage,
    LivestockPurpose purpose,
    int count,
    double feedPerAnimal,
  ) {
    final double groupFeed = feedPerAnimal * count;
    final String animal = _speciesLabel(species).toLowerCase();

    if (species == LivestockSpecies.chicken && purpose == LivestockPurpose.eggs) {
      return 'These $animal need ${groupFeed.toStringAsFixed(1)} kg of layer feed daily. '
          'Provide balanced layer mash with calcium, clean water, and collect eggs at least twice daily. '
          'Monitor shell quality and adjust feed if egg production drops.';
    }
    if (species == LivestockSpecies.chicken) {
      return 'These $animal need ${groupFeed.toStringAsFixed(1)} kg of broiler feed daily. '
          'Use quality finisher feed, keep feeders clean, and check weight gain weekly.';
    }

    switch (stage) {
      case AnimalGrowthStage.starter:
        return 'Young $animal need ${groupFeed.toStringAsFixed(1)} kg of starter feed daily. '
            'Provide smaller, frequent rations and ensure easy access to clean water.';
      case AnimalGrowthStage.grower:
        return 'Growing $animal need ${groupFeed.toStringAsFixed(1)} kg of grower feed daily. '
            'Track feed conversion ratio and adjust portions based on weight gain.';
      case AnimalGrowthStage.mature:
        return 'Mature $animal need ${groupFeed.toStringAsFixed(1)} kg of maintenance feed daily. '
            'Keep feeding schedule consistent and monitor body condition scores.';
      case AnimalGrowthStage.breeding:
        return 'Breeding $animal need ${groupFeed.toStringAsFixed(1)} kg of enriched feed daily. '
            'Ensure adequate minerals, vitamins, and clean water for fertility support.';
      case AnimalGrowthStage.finishing:
        return 'Finishing $animal need ${groupFeed.toStringAsFixed(1)} kg of finisher feed daily. '
            'Focus on efficient weight gain and prepare for market timing.';
    }
  }

  static String _speciesLabel(LivestockSpecies species) {
    switch (species) {
      case LivestockSpecies.goat:
        return 'Goats';
      case LivestockSpecies.chicken:
        return 'Chickens';
      case LivestockSpecies.pig:
        return 'Pigs';
      case LivestockSpecies.cattle:
        return 'Cattle';
      case LivestockSpecies.sheep:
        return 'Sheep';
      case LivestockSpecies.rabbit:
        return 'Rabbits';
      case LivestockSpecies.duck:
        return 'Ducks';
      case LivestockSpecies.fish:
        return 'Fish';
      case LivestockSpecies.snail:
        return 'Snails';
    }
  }
}
