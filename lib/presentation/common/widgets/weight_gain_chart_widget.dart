import 'package:flutter/material.dart';

import '../../../domain/models/livestock.dart';
import 'app_card.dart';

/// Displays weight-over-time chart from production logs,
/// with target vs actual comparison per growth stage.
class WeightGainChartWidget extends StatelessWidget {
  const WeightGainChartWidget({
    super.key,
    required this.livestock,
  });

  final Livestock livestock;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<LivestockProductionRecord> logs = livestock.productionLogs
        .where((LivestockProductionRecord r) => r.weightKg > 0)
        .toList(growable: false)
      ..sort((LivestockProductionRecord a, LivestockProductionRecord b) =>
          a.recordedAt.compareTo(b.recordedAt));

    // Build growth stage targets based on livestock species
    final List<_GrowthStageTarget> stageTargets = _buildStageTargets();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.show_chart_rounded, size: 20),
            const SizedBox(width: 8),
            Text(
              'Weight Gain',
              style: theme.textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Track weight progression across growth stages',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),

        if (logs.isEmpty && stageTargets.isEmpty)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No weight records yet. Add production logs with weight to see growth trends.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          )
        else ...[
          // Chart area
          Container(
            height: 200,
            padding: const EdgeInsets.only(top: 20, right: 12, bottom: 4),
            child: _WeightChart(
              logs: logs,
              stageTargets: stageTargets,
              maxWeight: _calculateMaxWeight(logs, stageTargets),
              theme: theme,
            ),
          ),

          const SizedBox(height: 16),

          // Legend
          Row(
            children: <Widget>[
              _LegendDot(color: theme.colorScheme.primary, label: 'Recorded weight'),
              const SizedBox(width: 16),
              _LegendDot(
                color: Colors.orange,
                label: 'Stage target',
              ),
              const SizedBox(width: 16),
              _LegendDot(
                color: theme.colorScheme.outlineVariant,
                label: 'Growth stages',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Stage target breakdown
          ...stageTargets.map(
            (_GrowthStageTarget target) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          target.stageLabel,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Target: ${target.targetWeightKg.toStringAsFixed(1)} kg',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (target.actualWeightKg > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: target.actualWeightKg >= target.targetWeightKg
                            ? Colors.green.withOpacity(0.15)
                            : Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${target.actualWeightKg.toStringAsFixed(1)} kg',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color:
                              target.actualWeightKg >= target.targetWeightKg
                                  ? Colors.green
                                  : Colors.orange,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (logs.isEmpty && stageTargets.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              color: theme.colorScheme.tertiaryContainer.withOpacity(0.25),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: theme.colorScheme.tertiary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Add production logs with weight to see how actual growth compares to stage targets.',
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  List<_GrowthStageTarget> _buildStageTargets() {
    final List<AnimalGrowthStage> stages = AnimalGrowthStage.values;
    final List<_GrowthStageTarget> targets = <_GrowthStageTarget>[];
    final double baseWeight = livestock.averageWeightKg > 0
        ? livestock.averageWeightKg
        : _defaultBaseWeight();

    for (int i = 0; i < stages.length; i++) {
      final AnimalGrowthStage stage = stages[i];
      final double multiplier = _stageWeightMultiplier(stage);
      final double targetWeight = baseWeight * multiplier;

      // Find the closest production log weight recorded around this stage
      double actualWeight = 0;
      if (livestock.growthStage == stage) {
        actualWeight = livestock.averageWeightKg;
      } else if (livestock.productionLogs.isNotEmpty) {
        // Use the most recent weight as reference for past stages
        final List<LivestockProductionRecord> sortedLogs =
            livestock.productionLogs
                .where((LivestockProductionRecord r) => r.weightKg > 0)
                .toList(growable: false)
              ..sort((LivestockProductionRecord a, LivestockProductionRecord b) =>
                  a.recordedAt.compareTo(b.recordedAt));

        if (sortedLogs.isNotEmpty) {
          // If it's a past stage or early stage, use first available weight
          if (i <= AnimalGrowthStage.values.indexOf(livestock.growthStage)) {
            actualWeight = sortedLogs.last.weightKg;
          }
        }
      }

      targets.add(_GrowthStageTarget(
        stage: stage,
        stageLabel: _growthStageLabel(stage),
        targetWeightKg: targetWeight,
        actualWeightKg: actualWeight,
      ));
    }

    return targets;
  }

  double _stageWeightMultiplier(AnimalGrowthStage stage) {
    switch (stage) {
      case AnimalGrowthStage.starter:
        return 0.3;
      case AnimalGrowthStage.grower:
        return 0.6;
      case AnimalGrowthStage.mature:
        return 0.9;
      case AnimalGrowthStage.breeding:
        return 1.0;
      case AnimalGrowthStage.finishing:
        return 1.1;
    }
  }

  double _defaultBaseWeight() {
    switch (livestock.species) {
      case LivestockSpecies.goat:
        return 25;
      case LivestockSpecies.chicken:
        return 1.5;
      case LivestockSpecies.pig:
        return 50;
      case LivestockSpecies.cattle:
        return 200;
      case LivestockSpecies.sheep:
        return 30;
    }
  }

  double _calculateMaxWeight(
    List<LivestockProductionRecord> logs,
    List<_GrowthStageTarget> targets,
  ) {
    double max = 0;
    for (final LivestockProductionRecord log in logs) {
      if (log.weightKg > max) max = log.weightKg;
    }
    for (final _GrowthStageTarget target in targets) {
      if (target.targetWeightKg > max) max = target.targetWeightKg;
    }
    if (livestock.averageWeightKg > max) max = livestock.averageWeightKg;
    return max > 0 ? max * 1.15 : 10; // Add 15% headroom
  }

  String _growthStageLabel(AnimalGrowthStage stage) {
    switch (stage) {
      case AnimalGrowthStage.starter:
        return 'Starter';
      case AnimalGrowthStage.grower:
        return 'Grower';
      case AnimalGrowthStage.mature:
        return 'Mature';
      case AnimalGrowthStage.breeding:
        return 'Breeding';
      case AnimalGrowthStage.finishing:
        return 'Finishing';
    }
  }
}

class _GrowthStageTarget {
  const _GrowthStageTarget({
    required this.stage,
    required this.stageLabel,
    required this.targetWeightKg,
    required this.actualWeightKg,
  });

  final AnimalGrowthStage stage;
  final String stageLabel;
  final double targetWeightKg;
  final double actualWeightKg;
}

class _WeightChart extends StatelessWidget {
  const _WeightChart({
    required this.logs,
    required this.stageTargets,
    required this.maxWeight,
    required this.theme,
  });

  final List<LivestockProductionRecord> logs;
  final List<_GrowthStageTarget> stageTargets;
  final double maxWeight;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double chartWidth = constraints.maxWidth;
        final double chartHeight = constraints.maxHeight;

        return CustomPaint(
          size: Size(chartWidth, chartHeight),
          painter: _WeightChartPainter(
            logs: logs,
            stageTargets: stageTargets,
            maxWeight: maxWeight,
            chartColor: theme.colorScheme.primary,
            gridColor: theme.colorScheme.outlineVariant.withOpacity(0.3),
            stageColor: theme.colorScheme.outlineVariant,
            targetColor: Colors.orange,
            achievedColor: Colors.green,
          ),
        );
      },
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  _WeightChartPainter({
    required this.logs,
    required this.stageTargets,
    required this.maxWeight,
    required this.chartColor,
    required this.gridColor,
    required this.stageColor,
    required this.targetColor,
    required this.achievedColor,
  });

  final List<LivestockProductionRecord> logs;
  final List<_GrowthStageTarget> stageTargets;
  final double maxWeight;
  final Color chartColor;
  final Color gridColor;
  final Color stageColor;
  final Color targetColor;
  final Color achievedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double paddingLeft = 40;
    final double paddingRight = 16;
    final double paddingTop = 8;
    final double paddingBottom = 24;
    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    // Draw horizontal grid lines
    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    const int gridLines = 4;
    for (int i = 0; i <= gridLines; i++) {
      final double y =
          paddingTop + chartHeight - (chartHeight * i / gridLines);
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(paddingLeft + chartWidth, y),
        gridPaint,
      );

      // Draw Y-axis labels
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: '${(maxWeight * i / gridLines).toStringAsFixed(0)} kg',
          style: TextStyle(
            color: chartColor.withOpacity(0.5),
            fontSize: 9,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: paddingLeft - 8);
      textPainter.paint(
        canvas,
        Offset(paddingLeft - textPainter.width - 4, y - textPainter.height / 2),
      );
    }

    // Draw stage background zones
    if (stageTargets.isNotEmpty) {
      final double stageWidth = chartWidth / stageTargets.length;
      for (int i = 0; i < stageTargets.length; i++) {
        final double x = paddingLeft + stageWidth * i;
        final Paint stagePaint = Paint()
          ..color = stageColor.withOpacity(0.08);
        canvas.drawRect(
          Rect.fromLTWH(x, paddingTop, stageWidth, chartHeight),
          stagePaint,
        );

        // Stage label
        final TextPainter labelPainter = TextPainter(
          text: TextSpan(
            text: stageTargets[i].stageLabel.substring(0, 3),
            style: TextStyle(
              color: stageColor.withOpacity(0.6),
              fontSize: 8,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: stageWidth);
        labelPainter.paint(
          canvas,
          Offset(
            x + stageWidth / 2 - labelPainter.width / 2,
            paddingTop + chartHeight + 6,
          ),
        );
      }
    }

    // Draw stage target lines (horizontal dashed)
    if (stageTargets.isNotEmpty) {
      final double stageWidth = chartWidth / stageTargets.length;
      final Paint targetPaint = Paint()
        ..color = targetColor.withOpacity(0.4)
        ..strokeWidth = 1.0;

      for (int i = 0; i < stageTargets.length; i++) {
        final double targetY =
            paddingTop + chartHeight * (1 - stageTargets[i].targetWeightKg / maxWeight);
        final double stageX = paddingLeft + stageWidth * i;
        final double dashWidth = 4;
        final double dashSpace = 3;
        double startX = stageX;
        while (startX < stageX + stageWidth) {
          canvas.drawLine(
            Offset(startX, targetY),
            Offset(
                startX + dashWidth > stageX + stageWidth
                    ? stageX + stageWidth
                    : startX + dashWidth,
                targetY),
            targetPaint,
          );
          startX += dashWidth + dashSpace;
        }
      }
    }

    // Draw weight line
    if (logs.length >= 2) {
      final Paint linePaint = Paint()
        ..color = chartColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final Path path = Path();
      final List<Offset> points = <Offset>[];

      final DateTime firstDate = logs.first.recordedAt;
      final DateTime lastDate = logs.last.recordedAt;
      final double totalDays =
          lastDate.difference(firstDate).inDays.clamp(1, 365).toDouble();

      for (int i = 0; i < logs.length; i++) {
        final double daysFromStart =
            logs[i].recordedAt.difference(firstDate).inDays.toDouble();
        final double x =
            paddingLeft + (daysFromStart / totalDays) * chartWidth;
        final double y =
            paddingTop + chartHeight * (1 - logs[i].weightKg / maxWeight);
        points.add(Offset(x, y));
      }

      if (points.isNotEmpty) {
        path.moveTo(points.first.dx, points.first.dy);
        for (int i = 1; i < points.length; i++) {
          path.lineTo(points[i].dx, points[i].dy);
        }
        canvas.drawPath(path, linePaint);

        // Draw dots at each data point
        final Paint dotPaint = Paint()
          ..color = chartColor
          ..style = PaintingStyle.fill;
        for (final Offset point in points) {
          canvas.drawCircle(point, 4, dotPaint);
          canvas.drawCircle(
            point,
            4,
            Paint()
              ..color = chartColor.withOpacity(0.2)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }

        // Draw value labels above dots (show first, last, and any peaks)
        if (points.length <= 6) {
          for (int i = 0; i < points.length; i++) {
            final TextPainter valuePainter = TextPainter(
              text: TextSpan(
                text: '${logs[i].weightKg.toStringAsFixed(1)} kg',
                style: TextStyle(
                  color: chartColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            valuePainter.paint(
              canvas,
              Offset(
                points[i].dx - valuePainter.width / 2,
                points[i].dy - valuePainter.height - 6,
              ),
            );
          }
        }
      }
    } else if (logs.length == 1) {
      // Single data point
      final double x = paddingLeft + chartWidth / 2;
      final double y =
          paddingTop + chartHeight * (1 - logs.first.weightKg / maxWeight);

      final Paint dotPaint = Paint()
        ..color = chartColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 6, dotPaint);

      final TextPainter valuePainter = TextPainter(
        text: TextSpan(
          text: '${logs.first.weightKg.toStringAsFixed(1)} kg',
          style: TextStyle(
            color: chartColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      valuePainter.paint(
        canvas,
        Offset(x - valuePainter.width / 2, y - valuePainter.height - 8),
      );

      final TextPainter notePainter = TextPainter(
        text: TextSpan(
          text: 'Add more weight records to see trends',
          style: TextStyle(
            color: chartColor.withOpacity(0.5),
            fontSize: 9,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      notePainter.paint(
        canvas,
        Offset(x - notePainter.width / 2, y + 12),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) => true;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

