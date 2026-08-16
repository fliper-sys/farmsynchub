import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/weather_reading_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/farm.dart';
import '../../../../providers/farm_provider.dart';
import '../../farms/farm_detail_screen.dart';

class WeatherPill extends ConsumerWidget {
  const WeatherPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    final String? activeFarmId = ref.watch(activeFarmProvider);
    Farm? activeFarm;
    for (final Farm farm in farms) {
      if (farm.id == activeFarmId) {
        activeFarm = farm;
        break;
      }
    }
    activeFarm ??= farms.isNotEmpty ? farms.first : null;

    if (activeFarm == null || _looksLikeSeededPlaceholder(activeFarm)) {
      return _LiveMonitoringEmptyCard(
        farmName: activeFarm?.name ?? 'Farm',
        farmId: activeFarm?.id,
      );
    }

    final WeatherLocation location = WeatherReadingService.resolveLocation(farm: activeFarm);
    return FutureBuilder<WeatherReading>(
      future: const WeatherReadingService().fetchCurrent(
        latitude: location.latitude,
        longitude: location.longitude,
      ),
      builder: (BuildContext context, AsyncSnapshot<WeatherReading> snapshot) {
        final WeatherReading? reading = snapshot.data;
        final Farm farm = activeFarm!;
        final double temperature = reading?.temperatureCelsius ?? farm.temperatureCelsius;
        final double humidity = reading?.humidityPercent ?? farm.humidityPercent;
        final double soil = reading?.soilMoisturePercent ?? farm.soilMoisturePercent;
        final double rain = reading?.precipitationMm ?? farm.precipitationMm;
        final bool loading = snapshot.connectionState == ConnectionState.waiting && reading == null;

        return _MonitoringPanel(
          farmName: farm.name,
          farmId: farm.id,
          loading: loading,
          temperature: temperature,
          humidity: humidity,
          soil: soil,
          rain: rain,
          isFallback: snapshot.hasError,
        );
      },
    );
  }
}

class _LiveMonitoringEmptyCard extends StatefulWidget {
  const _LiveMonitoringEmptyCard({required this.farmName, this.farmId});

  final String farmName;
  final String? farmId;

  @override
  State<_LiveMonitoringEmptyCard> createState() => _LiveMonitoringEmptyCardState();
}

class _LiveMonitoringEmptyCardState extends State<_LiveMonitoringEmptyCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _WeatherShell(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => CustomPaint(painter: _SeedlingPainter(_controller.value)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(Icons.eco_rounded, color: AppColors.premiumGreen, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.farmName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.premiumGreen,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'No Live Readings Yet',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Update the farm metrics with live temperature, humidity, rainfall, and soil moisture to populate this feed.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _UpdateReadingsButton(farmId: widget.farmId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonitoringPanel extends StatelessWidget {
  const _MonitoringPanel({
    required this.farmName,
    required this.farmId,
    required this.loading,
    required this.temperature,
    required this.humidity,
    required this.soil,
    required this.rain,
    required this.isFallback,
  });

  final String farmName;
  final String farmId;
  final bool loading;
  final double temperature;
  final double humidity;
  final double soil;
  final double rain;
  final bool isFallback;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String title = loading
        ? 'Fetching live readings'
        : isFallback
            ? 'Saved readings shown'
            : 'Live readings active';
    return _WeatherShell(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.monitor_heart_rounded, color: AppColors.premiumGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    farmName,
                    style: theme.textTheme.titleMedium?.copyWith(color: AppColors.premiumGreen, fontWeight: FontWeight.w800),
                  ),
                ),
                _UpdateReadingsButton(farmId: farmId),
              ],
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              loading ? 'Connecting to the weather feed...' : '${temperature.toStringAsFixed(1)} C with ${humidity.toStringAsFixed(0)}% humidity',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(child: _ReadingChip(label: 'Temp', value: loading ? '--' : '${temperature.toStringAsFixed(1)} C')),
                const SizedBox(width: 10),
                Expanded(child: _ReadingChip(label: 'Humidity', value: loading ? '--' : '${humidity.toStringAsFixed(0)}%')),
                const SizedBox(width: 10),
                Expanded(child: _ReadingChip(label: 'Rain', value: loading ? '--' : '${rain.toStringAsFixed(0)} mm')),
                const SizedBox(width: 10),
                Expanded(child: _ReadingChip(label: 'Soil', value: loading ? '--' : '${soil.toStringAsFixed(0)}%')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateReadingsButton extends StatelessWidget {
  const _UpdateReadingsButton({required this.farmId});

  final String? farmId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? id = farmId;
    return IconButton(
      tooltip: id == null ? null : 'Update readings',
      visualDensity: VisualDensity.compact,
      icon: Icon(Icons.more_vert_rounded, color: theme.colorScheme.onSurfaceVariant),
      onPressed: id == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FarmDetailScreen(
                    farmId: id,
                    initialSection: 'operationProfile',
                  ),
                ),
              ),
    );
  }
}

class _WeatherShell extends StatelessWidget {
  const _WeatherShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minHeight: 218),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const <Color>[Color(0xFF0E1723), Color(0xFF101827)]
              : const <Color>[Color(0xFFF4FBEF), Color(0xFFEFF7E8)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: <BoxShadow>[
          BoxShadow(color: theme.colorScheme.shadow.withOpacity(isDark ? 0.34 : 0.10), blurRadius: 26, offset: const Offset(0, 16)),
          BoxShadow(color: AppColors.premiumGreen.withOpacity(isDark ? 0.10 : 0.08), blurRadius: 28),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: child,
      ),
    );
  }
}

class _ReadingChip extends StatelessWidget {
  const _ReadingChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 5),
          Text(value, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SeedlingPainter extends CustomPainter {
  const _SeedlingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width * 0.74, size.height * 0.65);
    final Paint glow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          AppColors.premiumGreen.withOpacity(0.22),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.28));
    canvas.drawRect(Offset.zero & size, glow);

    final Paint soil = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFF6A4326), Color(0xFF2A1D17)],
      ).createShader(Rect.fromCenter(center: center.translate(0, 42), width: 220, height: 70));
    canvas.drawOval(Rect.fromCenter(center: center.translate(0, 46), width: 220, height: 70), soil);

    final double sway = math.sin(progress * math.pi * 2) * 4;
    final Paint stem = Paint()
      ..color = AppColors.premiumGreen
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center.translate(sway * 0.2, 34), center.translate(sway, -28), stem);

    final Paint leaf = Paint()..color = AppColors.premiumGreen;
    for (final double side in <double>[-1, 1]) {
      final Offset root = center.translate(sway, -20);
      final Offset tip = root.translate(side * 42, -24 + side * sway);
      final Path path = Path()
        ..moveTo(root.dx, root.dy)
        ..quadraticBezierTo(root.dx + side * 22, root.dy - 36, tip.dx, tip.dy)
        ..quadraticBezierTo(root.dx + side * 28, root.dy + 6, root.dx, root.dy);
      canvas.drawPath(path, leaf);
    }

    final Paint particle = Paint()..color = AppColors.premiumWarning.withOpacity(0.8);
    for (int i = 0; i < 10; i++) {
      final double t = (progress + i * 0.137) % 1;
      final double x = center.dx + math.cos(i * 1.8) * (44 + i * 8);
      final double y = center.dy - 16 - t * 90 + math.sin(i + progress * math.pi * 2) * 6;
      canvas.drawCircle(Offset(x, y), 1.6 + (1 - t) * 1.8, particle..color = AppColors.premiumWarning.withOpacity(1 - t));
    }
  }

  @override
  bool shouldRepaint(covariant _SeedlingPainter oldDelegate) => oldDelegate.progress != progress;
}

bool _looksLikeSeededPlaceholder(Farm farm) {
  return farm.temperatureCelsius == 24 &&
      farm.humidityPercent == 60 &&
      farm.soilMoisturePercent == 52 &&
      farm.precipitationMm == 6;
}
