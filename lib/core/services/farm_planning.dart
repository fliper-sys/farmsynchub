import 'dart:math' as math;

import '../../domain/models/farm.dart';

/// Starting-point suggestions for how much a farm can hold, derived from its
/// size and type. Shared by the farm form and the guided farm wizard so both
/// always suggest the same numbers.
abstract final class FarmPlanning {
  /// Hectares that can sensibly go under crops.
  static double suggestedCropCapacity(double sizeHa, FarmType farmType) {
    if (sizeHa <= 0) {
      return 0;
    }
    final double factor = switch (farmType) {
      FarmType.crop => 0.8,
      FarmType.livestock => 0.0,
      FarmType.greenhouse => 0.25,
      FarmType.combined => 0.55,
    };
    return sizeHa * factor;
  }

  /// Number of animals the land can keep without crowding.
  static int suggestedLivestockCapacity(double sizeHa, FarmType farmType) {
    if (sizeHa <= 0) {
      return 0;
    }
    final double factor = switch (farmType) {
      FarmType.crop => 0.0,
      FarmType.livestock => 18,
      FarmType.greenhouse => 0.0,
      FarmType.combined => 10,
    };
    return (sizeHa * factor).round();
  }

  /// Hectares that can go under greenhouses.
  static double suggestedGreenhouseArea(double sizeHa, FarmType farmType) {
    if (sizeHa <= 0) {
      return 0;
    }
    final double factor = switch (farmType) {
      FarmType.crop => 0.0,
      FarmType.livestock => 0.0,
      FarmType.greenhouse => 0.18,
      FarmType.combined => 0.12,
    };
    return sizeHa * factor;
  }

  /// How many greenhouse units fit.
  static int suggestedGreenhouseUnits(double sizeHa, FarmType farmType) {
    if (sizeHa <= 0) {
      return 0;
    }
    return switch (farmType) {
      FarmType.crop => 0,
      FarmType.livestock => 0,
      FarmType.greenhouse => math.max(1, (sizeHa / 0.2).floor()),
      FarmType.combined => math.max(1, (sizeHa / 0.35).floor()),
    };
  }
}
