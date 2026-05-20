import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/farm.dart';
import '../../../../providers/farm_provider.dart';
import '../../../common/widgets/farm_scene_artwork.dart';

/// Illustrated weather summary card.
class WeatherPill extends ConsumerWidget {
  const WeatherPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    final _WeatherSnapshot snapshot = _WeatherSnapshot.fromFarms(farms);

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

  factory _WeatherSnapshot.fromFarms(List<Farm> farms) {
    if (farms.isEmpty) {
      return const _WeatherSnapshot(
        temperature: 24,
        humidity: 60,
        soilMoisture: 52,
        precipitation: 6,
        summary: 'Field-ready conditions',
      );
    }

    double temp = 0;
    double humidity = 0;
    double soil = 0;
    double rain = 0;
    for (final Farm farm in farms) {
      temp += farm.temperatureCelsius;
      humidity += farm.humidityPercent;
      soil += farm.soilMoisturePercent;
      rain += farm.precipitationMm;
    }

    final double divisor = farms.length.toDouble();
    final double temperature = temp / divisor;
    final double humidityValue = humidity / divisor;
    final double soilValue = soil / divisor;
    final double rainValue = rain / divisor;

    return _WeatherSnapshot(
      temperature: temperature,
      humidity: humidityValue,
      soilMoisture: soilValue,
      precipitation: rainValue,
      summary: rainValue > 12
          ? 'Rainfall watch'
          : soilValue < 40
              ? 'Irrigation recommended'
              : 'Field-ready conditions',
    );
  }
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
