import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/farm.dart';
import '../../providers/farm_provider.dart';

/// Lightweight service to accept device telemetry and apply it to farms.
class DeviceSyncService {
  DeviceSyncService(this._ref);

  final Ref _ref;

  /// Apply a device reading snapshot to a farm and trigger repository update.
  Future<void> applyDeviceReading({
    required String farmId,
    double? temperatureCelsius,
    double? humidityPercent,
    double? soilMoisturePercent,
    double? precipitationMm,
  }) async {
    final FarmsNotifier farmsNotifier = _ref.read(farmsProvider.notifier);
    final Farm? farm = await farmsNotifier.getFarmById(farmId);
    if (farm == null) return;

    final Farm updated = farm.copyWith(
      temperatureCelsius: temperatureCelsius ?? farm.temperatureCelsius,
      humidityPercent: humidityPercent ?? farm.humidityPercent,
      soilMoisturePercent: soilMoisturePercent ?? farm.soilMoisturePercent,
      precipitationMm: precipitationMm ?? farm.precipitationMm,
      updatedAt: DateTime.now(),
      isSynced: false,
    );

    await farmsNotifier.updateFarm(updated);
  }
}

final deviceSyncServiceProvider = Provider<DeviceSyncService>((ref) {
  return DeviceSyncService(ref);
});
