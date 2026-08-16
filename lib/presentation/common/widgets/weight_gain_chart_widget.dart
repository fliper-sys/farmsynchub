import 'dart:math' as math;

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
              maxWeight: _calculateMaxWeight(logs, stageTargets),
              matureWeightKg: livestock.averageWeightKg > 0
                  ? livestock.averageWeightKg
                  : _defaultBaseWeight(),
              maturityDays: livestock.targetMaturityMonths > 0
                  ? livestock.targetMaturityMonths * 30
                  : _maturityDays(),
              referenceDate: logs.isNotEmpty ? logs.first.recordedAt : livestock.createdAt,
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
                label: 'Expected growth',
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

      // Only the animal's current stage has a real "actual" reading — past
      // stages don't have their own logged weight, so showing the latest
      // reading against every earlier stage would overstate how much was
      // achieved at that point in time.
      final double actualWeight =
          livestock.growthStage == stage ? livestock.averageWeightKg : 0;

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
      case LivestockSpecies.rabbit:
        return 2.5;
      case LivestockSpecies.duck:
        return 3;
      case LivestockSpecies.fish:
        return 1;
      case LivestockSpecies.snail:
        return 0.15;
    }
  }

  /// Typical days to reach mature weight, used to shape the expected
  /// growth curve. Independent of purpose (unlike [FeedCalculatorService]'s
  /// maturity estimate) since the chart shows one reference curve per animal.
  int _maturityDays() {
    switch (livestock.species) {
      case LivestockSpecies.goat:
        return 540;
      case LivestockSpecies.chicken:
        return 150;
      case LivestockSpecies.pig:
        return 210;
      case LivestockSpecies.cattle:
        return 730;
      case LivestockSpecies.sheep:
        return 365;
      case LivestockSpecies.rabbit:
        return 150;
      case LivestockSpecies.duck:
        return 150;
      case LivestockSpecies.fish:
        return 180;
      case LivestockSpecies.snail:
        return 300;
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
    if (_defaultBaseWeight() > max) max = _defaultBaseWeight();
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
    required this.maxWeight,
    required this.matureWeightKg,
    required this.maturityDays,
    required this.referenceDate,
    required this.theme,
  });

  final List<LivestockProductionRecord> logs;
  final double maxWeight;
  final double matureWeightKg;
  final int maturityDays;
  final DateTime referenceDate;
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
            maxWeight: maxWeight,
            matureWeightKg: matureWeightKg,
            maturityDays: maturityDays,
            referenceDate: referenceDate,
            chartColor: theme.colorScheme.primary,
            gridColor: theme.colorScheme.outlineVariant.withOpacity(0.3),
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
    required this.maxWeight,
    required this.matureWeightKg,
    required this.maturityDays,
    required this.referenceDate,
    required this.chartColor,
    required this.gridColor,
    required this.targetColor,
    required this.achievedColor,
  });

  final List<LivestockProductionRecord> logs;
  final double maxWeight;
  final double matureWeightKg;
  final int maturityDays;
  final DateTime referenceDate;
  final Color chartColor;
  final Color gridColor;
  final Color targetColor;
  final Color achievedColor;

  /// Expected weight at [day] days of age, modelled as an exponential
  /// approach to the species' mature weight (reaches ~95% of mature
  /// weight at [maturityDays]).
  double _expectedWeightAtDay(int day) {
    if (maturityDays <= 0) return matureWeightKg;
    final double t = day / maturityDays;
    return matureWeightKg * (1 - math.exp(-3 * t));
  }

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

    // Shared time axis: runs from the reference date (first log, or the
    // animal's record date if no logs yet) out to whichever is further —
    // the last recorded weight or the species' typical maturity age — so
    // the expected-growth curve and the actual readings line up correctly.
    final int lastLogDayOffset = logs.isNotEmpty
        ? logs.last.recordedAt.difference(referenceDate).inDays
        : 0;
    final int totalDays = math.max(math.max(lastLogDayOffset, maturityDays), 1);

    // Draw expected growth curve (smooth dashed curve to the mature weight)
    final Paint targetPaint = Paint()
      ..color = targetColor.withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const int curveSamples = 40;
    final List<Offset> curvePoints = <Offset>[];
    for (int i = 0; i <= curveSamples; i++) {
      final int day = (totalDays * i / curveSamples).round();
      final double weight = _expectedWeightAtDay(day);
      final double x = paddingLeft + (day / totalDays) * chartWidth;
      final double y = paddingTop + chartHeight * (1 - weight / maxWeight);
      curvePoints.add(Offset(x, y));
    }
    for (int i = 0; i < curvePoints.length - 1; i++) {
      final Offset start = curvePoints[i];
      final Offset end = curvePoints[i + 1];
      final double segmentLength = (end - start).distance;
      const double dashWidth = 4;
      const double dashSpace = 3;
      double covered = 0;
      while (covered < segmentLength) {
        final double next = math.min(covered + dashWidth, segmentLength);
        canvas.drawLine(
          Offset.lerp(start, end, covered / segmentLength)!,
          Offset.lerp(start, end, next / segmentLength)!,
          targetPaint,
        );
        covered += dashWidth + dashSpace;
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

      for (int i = 0; i < logs.length; i++) {
        final double daysFromStart =
            logs[i].recordedAt.difference(referenceDate).inDays.toDouble();
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

