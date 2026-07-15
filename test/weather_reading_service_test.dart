import 'package:flutter_test/flutter_test.dart';

import 'package:farmsynchub/core/services/weather_reading_service.dart';
import 'package:farmsynchub/domain/models/farm.dart';

void main() {
  group('WeatherReadingService location resolution', () {
    test('falls back to Jos South coordinates when no farm coordinates are present', () {
      final WeatherLocation location = WeatherReadingService.resolveLocation(farm: null);

      expect(location.latitude, closeTo(9.8965, 0.0001));
      expect(location.longitude, closeTo(8.8583, 0.0001));
    });

    test('uses the farm coordinates when they are available', () {
      final Farm farm = Farm(
        id: 'farm-1',
        name: 'Sample farm',
        ward: 'Jos South',
        sizeHa: 2.5,
        farmType: FarmType.crop,
        farmerCategory: FarmerCategory.marketOriented,
        soilType: SoilType.loamy,
        waterSource: WaterSource.rainfall,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        isSynced: true,
        latitude: 12.34,
        longitude: 56.78,
      );

      final WeatherLocation location = WeatherReadingService.resolveLocation(farm: farm);

      expect(location.latitude, 12.34);
      expect(location.longitude, 56.78);
    });
  });
}
