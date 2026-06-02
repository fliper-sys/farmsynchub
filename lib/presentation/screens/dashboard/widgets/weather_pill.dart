import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/farm.dart';
import '../../../../providers/farm_provider.dart';
import '../../../common/widgets/farm_scene_artwork.dart';

/// Illustrated environmental snapshot card for the selected farm.
class WeatherPill extends ConsumerWidget {
  const WeatherPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    final String? activeFarmId = ref.watch(activeFarmProvider);
    Farm? activeFarm;
    if (activeFarmId != null && activeFarmId.trim().isNotEmpty) {
      for (final Farm farm in farms) {
        if (farm.id == activeFarmId) {
          activeFarm = farm;
          break;
        }
      }
    }
    activeFarm ??= farms.isNotEmpty ? farms.first : null;

    if (activeFarm == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'No farm readings yet',
              style: theme.textTheme.titleLarge?.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a farm and record its environmental readings to see temperature and humidity here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
        );
    }

    if (_looksLikeSeededPlaceholder(activeFarm)) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.thermostat_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activeFarm.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'No live readings yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Update the farm metrics with the latest temperature, humidity, soil moisture, and rainfall values to populate this feed.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    final _WeatherSnapshot snapshot = _WeatherSnapshot.fromFarm(activeFarm);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFD98E),
            Color(0xFFF7BF66),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.amberAccent.withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: Opacity(
              opacity: 0.28,
              child: FarmSceneArtwork(
                height: 180,
                variant: FarmArtworkVariant.dashboard,
                borderRadius: BorderRadius.all(Radius.circular(30)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.thermostat_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activeFarm.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${snapshot.temperature.toStringAsFixed(1)} C',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AppColors.primary,
                    fontSize: 30,
                  ),
                ),
                Text(
                  snapshot.summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary.withOpacity(0.76),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MetricChip(
                        label: 'Humidity',
                        value: '${snapshot.humidity.toStringAsFixed(0)}%',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricChip(
                        label: 'Soil Moisture',
                        value: '${snapshot.soilMoisture.toStringAsFixed(0)}%',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricChip(
                        label: 'Precipitation',
                        value: '${snapshot.precipitation.toStringAsFixed(0)} mm',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherSnapshot {
  const _WeatherSnapshot({
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
    required this.precipitation,
    required this.summary,
  });

  final double temperature;
  final double humidity;
  final double soilMoisture;
  final double precipitation;
  final String summary;

  factory _WeatherSnapshot.fromFarm(Farm farm) {
    final double temperature = farm.temperatureCelsius;
    final double humidityValue = farm.humidityPercent;
    final double soilValue = farm.soilMoisturePercent;
    final double rainValue = farm.precipitationMm;

    String summary;
    if (rainValue > 12) {
      summary = 'Rainfall watch';
    } else if (temperature >= 32) {
      summary = 'Heat stress watch';
    } else if (soilValue < 40) {
      summary = 'Irrigation recommended';
    } else {
      summary = 'Field-ready conditions';
    }

    return _WeatherSnapshot(
      temperature: temperature,
      humidity: humidityValue,
      soilMoisture: soilValue,
      precipitation: rainValue,
      summary: summary,
    );
  }
}

bool _looksLikeSeededPlaceholder(Farm farm) {
  return farm.temperatureCelsius == 24 &&
      farm.humidityPercent == 60 &&
      farm.soilMoisturePercent == 52 &&
      farm.precipitationMm == 6;
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.primary.withOpacity(0.70),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
