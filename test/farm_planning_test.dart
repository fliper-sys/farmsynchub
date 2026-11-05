import 'package:farmsynchub/core/services/farm_planning.dart';
import 'package:farmsynchub/domain/models/farm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FarmPlanning', () {
    test('returns zero for a farm with no size', () {
      for (final FarmType type in FarmType.values) {
        expect(FarmPlanning.suggestedCropCapacity(0, type), 0);
        expect(FarmPlanning.suggestedLivestockCapacity(0, type), 0);
        expect(FarmPlanning.suggestedGreenhouseArea(0, type), 0);
        expect(FarmPlanning.suggestedGreenhouseUnits(0, type), 0);
      }
    });

    test('crop farms reserve most land for crops and keep no animals', () {
      expect(FarmPlanning.suggestedCropCapacity(2, FarmType.crop),
          closeTo(1.6, 1e-9));
      expect(FarmPlanning.suggestedLivestockCapacity(2, FarmType.crop), 0);
      expect(FarmPlanning.suggestedGreenhouseUnits(2, FarmType.crop), 0);
    });

    test('livestock farms suggest animals and no crop land', () {
      expect(FarmPlanning.suggestedCropCapacity(2, FarmType.livestock), 0);
      expect(FarmPlanning.suggestedLivestockCapacity(2, FarmType.livestock), 36);
    });

    test('greenhouse and combined farms always suggest at least one unit', () {
      expect(FarmPlanning.suggestedGreenhouseUnits(0.1, FarmType.greenhouse), 1);
      expect(FarmPlanning.suggestedGreenhouseUnits(1, FarmType.greenhouse), 5);
      expect(FarmPlanning.suggestedGreenhouseUnits(0.1, FarmType.combined), 1);
      expect(FarmPlanning.suggestedGreenhouseUnits(1.4, FarmType.combined), 4);
    });
  });
}
