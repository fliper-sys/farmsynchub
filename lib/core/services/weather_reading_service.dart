import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/farm.dart';

class WeatherLocation {
  const WeatherLocation({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

class WeatherReading {
  const WeatherReading({
    required this.temperatureCelsius,
    required this.humidityPercent,
    required this.precipitationMm,
    this.soilMoisturePercent,
    required this.observedAt,
  });

  final double temperatureCelsius;
  final double humidityPercent;
  final double precipitationMm;
  final double? soilMoisturePercent;
  final DateTime observedAt;
}

class WeatherReadingService {
  const WeatherReadingService({http.Client? client}) : _client = client;

  static const WeatherLocation defaultLocation = WeatherLocation(
    latitude: 9.8965,
    longitude: 8.8583,
  );

  final http.Client? _client;

  static WeatherLocation resolveLocation({Farm? farm}) {
    if (farm != null && farm.latitude != null && farm.longitude != null) {
      return WeatherLocation(latitude: farm.latitude!, longitude: farm.longitude!);
    }
    return defaultLocation;
  }

  Future<WeatherReading> fetchCurrent({
    required double latitude,
    required double longitude,
  }) async {
    final Uri uri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      <String, String>{
        'latitude': latitude.toStringAsFixed(5),
        'longitude': longitude.toStringAsFixed(5),
        'current': 'temperature_2m,relative_humidity_2m,precipitation',
        'hourly': 'soil_moisture_0_to_1cm',
        'forecast_days': '1',
        'timezone': 'auto',
      },
    );

    final http.Client client = _client ?? http.Client();
    final http.Response response = await client.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Weather API returned ${response.statusCode}.');
    }

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    final Map<String, dynamic> current = Map<String, dynamic>.from(data['current'] as Map? ?? <String, dynamic>{});
    final DateTime observedAt = DateTime.tryParse(current['time'] as String? ?? '') ?? DateTime.now();

    return WeatherReading(
      temperatureCelsius: _doubleValue(current['temperature_2m']),
      humidityPercent: _doubleValue(current['relative_humidity_2m']),
      precipitationMm: _doubleValue(current['precipitation']),
      soilMoisturePercent: _soilMoisturePercent(data, observedAt),
      observedAt: observedAt,
    );
  }

  static double _doubleValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _soilMoisturePercent(Map<String, dynamic> data, DateTime observedAt) {
    final Map<String, dynamic> hourly = Map<String, dynamic>.from(data['hourly'] as Map? ?? <String, dynamic>{});
    final List<dynamic> times = hourly['time'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> values = hourly['soil_moisture_0_to_1cm'] as List<dynamic>? ?? <dynamic>[];
    if (times.isEmpty || values.isEmpty) {
      return null;
    }

    int bestIndex = 0;
    Duration bestDistance = const Duration(days: 365);
    for (int index = 0; index < times.length && index < values.length; index++) {
      final DateTime? time = DateTime.tryParse(times[index].toString());
      if (time == null) {
        continue;
      }
      final Duration distance = observedAt.difference(time).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }

    final double volumetric = _doubleValue(values[bestIndex]);
    if (volumetric <= 0) {
      return null;
    }
    return (volumetric * 100).clamp(0, 100).toDouble();
  }
}
