import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/feed_calculator_service.dart';
import '../../../domain/models/livestock.dart';
import '../../../providers/livestock_provider.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Displays a feeding plan with daily feed/water requirements,
/// feeding advice, and scheduling buttons for a livestock group.
class FeedingPlanWidget extends ConsumerStatefulWidget {
  const FeedingPlanWidget({
    super.key,
    required this.livestock,
  });

  final Livestock livestock;

  @override
  ConsumerState<FeedingPlanWidget> createState() => _FeedingPlanWidgetState();
}

class _FeedingPlanWidgetState extends ConsumerState<FeedingPlanWidget> {
  bool _showingAdvice = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Livestock l = widget.livestock;

    final double feedPerAnimal = FeedCalculatorService.feedPerAnimalKg(
      l.species, l.growthStage, l.averageAgeMonths, l.purpose,
      actualWeightKg: l.averageWeightKg,
    );
    final double waterPerAnimal = FeedCalculatorService.waterPerAnimalLitres(
      l.species, l.growthStage, l.averageAgeMonths, l.purpose,
      actualWeightKg: l.averageWeightKg,
    );
    final double totalFeedKg = feedPerAnimal * l.count;
    final double totalWaterL = waterPerAnimal * l.count;
    final int suggestedMaturity = FeedCalculatorService.suggestedMaturityMonths(
      l.species, l.purpose, l.averageAgeMonths, l.growthStage,
    );
    final double currentDailyFeed = l.dailyFeedKg * l.count;
    final double currentDailyWater = l.dailyWaterLitres * l.count;
    final double feedVariance = currentDailyFeed > 0
        ? ((totalFeedKg - currentDailyFeed) / currentDailyFeed) * 100
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.restaurant_rounded, size: 20),
            const SizedBox(width: 8),
            Text(
              'Feeding Plan',
              style: theme.textTheme.titleLarge,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _showingAdvice = !_showingAdvice),
              icon: Icon(
                _showingAdvice ? Icons.expand_less : Icons.info_outline_rounded,
                size: 18,
              ),
              label: Text(_showingAdvice ? 'Hide advice' : 'Advice'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Feed & water requirement cards
        Row(
          children: <Widget>[
            Expanded(
              child: _MetricCard(
                icon: Icons.speed_rounded,
                label: 'Feed/head/day',
                value: '${feedPerAnimal.toStringAsFixed(feedPerAnimal < 1 ? 3 : 1)} kg',
                color: Colors.orange,
                theme: theme,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                icon: Icons.water_drop_rounded,
                label: 'Water/head/day',
                value: '${waterPerAnimal.toStringAsFixed(1)} L',
                color: Colors.blue,
                theme: theme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: _MetricCard(
                icon: Icons.group_rounded,
                label: 'Group daily feed',
                value: '${totalFeedKg.toStringAsFixed(1)} kg',
                color: Colors.orange.withOpacity(0.6),
                theme: theme,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                icon: Icons.water_rounded,
                label: 'Group daily water',
                value: '${totalWaterL.toStringAsFixed(0)} L',
                color: Colors.blue.withOpacity(0.6),
                theme: theme,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Current vs suggested comparison
        if (currentDailyFeed > 0 || currentDailyWater > 0) ...[
          AppCard(
            color: theme.colorScheme.tertiaryContainer.withOpacity(0.25),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Current vs Suggested',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _ComparisonRow(
                    label: 'Feed',
                    current: currentDailyFeed,
                    suggested: totalFeedKg,
                    unit: 'kg',
                    theme: theme,
                  ),
                  const SizedBox(height: 6),
                  _ComparisonRow(
                    label: 'Water',
                    current: currentDailyWater,
                    suggested: totalWaterL,
                    unit: 'L',
                    theme: theme,
                  ),
                  if (feedVariance.abs() > 15)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            feedVariance > 0
                                ? Icons.warning_amber_rounded
                                : Icons.info_outline_rounded,
                            size: 16,
                            color: feedVariance > 0
                                ? Colors.orange
                                : Colors.blue,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              feedVariance > 0
                                  ? 'You are feeding ${feedVariance.round()}% more than suggested. Consider adjusting portions.'
                                  : 'Suggested feeding is ${feedVariance.abs().round()}% higher than current. Increase gradually.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Maturity projection
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                const Icon(Icons.timeline_rounded, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Target maturity',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        l.averageAgeMonths >= suggestedMaturity
                            ? 'Matured at ${suggestedMaturity} months — ready for ${_purposeLabel(l.purpose)}'
                            : '${suggestedMaturity - l.averageAgeMonths} months remaining (target: $suggestedMaturity months)',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '$suggestedMaturity mo',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Advice section
        if (_showingAdvice)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AppCard(
              color: theme.colorScheme.primaryContainer.withOpacity(0.2),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.lightbulb_outline_rounded, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        FeedCalculatorService.feedingAdvice(
                          l.species, l.growthStage, l.purpose,
                          l.count, feedPerAnimal,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _purposeLabel(LivestockPurpose purpose) {
    switch (purpose) {
      case LivestockPurpose.meat:
        return 'meat/market';
      case LivestockPurpose.milk:
        return 'milking';
      case LivestockPurpose.eggs:
        return 'egg production';
      case LivestockPurpose.breeding:
        return 'breeding';
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: color.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.current,
    required this.suggested,
    required this.unit,
    required this.theme,
  });

  final String label;
  final double current;
  final double suggested;
  final String unit;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final double diff = suggested - current;
    final bool isUnder = diff > 0;
    final String diffLabel =
        '${isUnder ? '+' : ''}${diff.toStringAsFixed(diff < 1 ? 2 : 1)} $unit';

    return Row(
      children: <Widget>[
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            'Current: ${current.toStringAsFixed(1)} $unit',
            style: theme.textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: Text(
            'Suggested: ${suggested.toStringAsFixed(1)} $unit',
            style: theme.textTheme.bodySmall,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isUnder
                ? Colors.orange.withOpacity(0.15)
                : Colors.green.withOpacity(0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            diffLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isUnder ? Colors.orange : Colors.green,
            ),
          ),
        ),
      ],
    );
  }
}
