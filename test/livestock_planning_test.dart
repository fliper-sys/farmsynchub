import 'package:farmsynchub/core/services/livestock_planning.dart';
import 'package:farmsynchub/domain/models/livestock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maturity suggestion follows species, purpose, stage and age', () {
    // Goat for meat: base 12, grower +0, age below base -1.
    expect(
      LivestockPlanning.suggestedMaturityMonths(
        LivestockSpecies.goat,
        LivestockPurpose.meat,
        3,
        AnimalGrowthStage.grower,
      ),
      11,
    );
    // Breeding cattle already past the base age: 30 + 4.
    expect(
      LivestockPlanning.suggestedMaturityMonths(
        LivestockSpecies.cattle,
        LivestockPurpose.breeding,
        40,
        AnimalGrowthStage.breeding,
      ),
      34,
    );
  });

  test('feed grows with age and stage', () {
    final double young = LivestockPlanning.feedPerAnimalKg(
      LivestockSpecies.goat,
      AnimalGrowthStage.grower,
      2,
      LivestockPurpose.meat,
    );
    final double adult = LivestockPlanning.feedPerAnimalKg(
      LivestockSpecies.goat,
      AnimalGrowthStage.grower,
      24,
      LivestockPurpose.meat,
    );
    expect(young, closeTo(0.9 * 0.85, 1e-9));
    expect(adult, closeTo(0.9 * 1.15, 1e-9));
  });

  test('water is zero for fish and positive for cattle', () {
    expect(
      LivestockPlanning.waterPerAnimalLitres(
        LivestockSpecies.fish,
        AnimalGrowthStage.grower,
        6,
        LivestockPurpose.meat,
      ),
      0,
    );
    expect(
      LivestockPlanning.waterPerAnimalLitres(
        LivestockSpecies.cattle,
        AnimalGrowthStage.mature,
        30,
        LivestockPurpose.milk,
      ),
      closeTo(25 * 1.1 * 1.05 * 1.1, 1e-9),
    );
  });
}
