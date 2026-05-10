import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../common/widgets/farm_scene_artwork.dart';

/// Illustrated weather summary card.
class WeatherPill extends StatelessWidget {
  const WeatherPill({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

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
                  '18°C',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AppColors.primary,
                    fontSize: 30,
                  ),
                ),
                Text(
                  'Cloudy',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary.withOpacity(0.76),
                  ),
                ),
                const SizedBox(height: 18),
                const Row(
                  children: <Widget>[
                    Expanded(child: _MetricChip(label: 'Humidity', value: 'Good')),
                    SizedBox(width: 10),
                    Expanded(child: _MetricChip(label: 'Soil Moisture', value: 'Good')),
                    SizedBox(width: 10),
                    Expanded(child: _MetricChip(label: 'Precipitation', value: 'Low')),
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
