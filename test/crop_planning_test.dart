import 'package:farmsynchub/core/services/crop_planning.dart';
import 'package:farmsynchub/data/services/crop_advice_catalog.dart';
import 'package:farmsynchub/domain/models/crop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final CropAdviceProfile? maize = CropAdviceCatalog.detect('Maize');
  final CropAdviceProfile? unknown = CropAdviceCatalog.detect('Unknown crop');

  group('CropPlanning', () {
    test('detects maize and leaves unknown crops without a profile', () {
      expect(maize, isNotNull);
      expect(unknown, isNull);
    });

    test('cycle days: known crop, unknown crop and protected growing', () {
      expect(
          CropPlanning.suggestedCycleDays(maize, CropStage.seeding, false), 110);
      expect(
          CropPlanning.suggestedCycleDays(maize, CropStage.seeding, true), 103);
      expect(
          CropPlanning.suggestedCycleDays(unknown, CropStage.seeding, false), 90);
    });

    test('yield scales with area, stage and protected environment', () {
      expect(
        CropPlanning.suggestedYieldKg(maize, 1, CropStage.seeding, false),
        closeTo(4200, 1e-9),
      );
      expect(
        CropPlanning.suggestedYieldKg(maize, 2, CropStage.seeding, false),
        closeTo(8400, 1e-9),
      );
      expect(
        CropPlanning.suggestedYieldKg(maize, 1, CropStage.seeding, true),
        closeTo(4620, 1e-6),
      );
      expect(
        CropPlanning.suggestedYieldKg(maize, 1, CropStage.fruiting, false),
        closeTo(4200 * 0.92, 1e-6),
      );
      expect(
        CropPlanning.suggestedYieldKg(unknown, 1, CropStage.seeding, false),
        closeTo(2500, 1e-9),
      );
    });
  });

  test('Hausa and French crop names are recognised', () {
    expect(CropAdviceCatalog.detect('Masara')?.name, 'Maize');
    expect(CropAdviceCatalog.detect('Tomate')?.name, 'Tomato');
    expect(CropAdviceCatalog.detect('Rogo')?.name, 'Cassava');
    expect(CropAdviceCatalog.detect('Pomme de terre')?.name, 'Potato');
    expect(CropAdviceCatalog.detect('Dankalin hausa')?.name, 'Sweet potato');
  });
}
