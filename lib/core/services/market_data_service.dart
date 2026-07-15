import 'dart:convert';

import 'package:http/http.dart' as http;

class MarketDataService {
  MarketDataService({
    http.Client? client,
    this.baseUrl,
    this.apiKey,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String? baseUrl;
  final String? apiKey;

  Future<List<MarketPricePoint>> fetchNearbyMarketPrices({
    required String location,
    required List<String> products,
  }) async {
    if (location.trim().isEmpty || products.isEmpty) {
      return const <MarketPricePoint>[];
    }

    final Uri? endpoint = _buildEndpoint(location, products);
    if (endpoint == null) {
      return const <MarketPricePoint>[];
    }

    try {
      final http.Response response = await _client
          .get(
            endpoint,
            headers: <String, String>{
              if ((apiKey ?? '').trim().isNotEmpty) 'Authorization': 'Bearer ${apiKey!.trim()}',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return const <MarketPricePoint>[];
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final List<dynamic> items = _extractItems(decoded);
        return items
            .whereType<Map<String, dynamic>>()
            .map((Map<String, dynamic> item) => MarketPricePoint.fromJson(item))
            .where((MarketPricePoint point) => point.productName.isNotEmpty)
            .toList(growable: false);
      }

      return const <MarketPricePoint>[];
    } catch (_) {
      return const <MarketPricePoint>[];
    }
  }

  List<dynamic> _extractItems(Map<String, dynamic> payload) {
    for (final String key in <String>['data', 'products', 'results', 'marketPrices']) {
      final dynamic value = payload[key];
      if (value is List<dynamic>) {
        return value;
      }
    }

    final dynamic nested = payload['data'];
    if (nested is Map<String, dynamic>) {
      for (final String key in <String>['data', 'products', 'results', 'marketPrices']) {
        final dynamic value = nested[key];
        if (value is List<dynamic>) {
          return value;
        }
      }
    }

    return const <dynamic>[];
  }

  Uri? _buildEndpoint(String location, List<String> products) {
    final String normalizedLocation = location.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
    final String queryProducts = products.take(4).join(',').toLowerCase();
    final String configuredBaseUrl = (baseUrl ?? '').trim();
    if (configuredBaseUrl.isEmpty) {
      return null;
    }

    final Uri baseUri = Uri.parse(configuredBaseUrl);
    return baseUri.replace(
      queryParameters: <String, String>{
        if (baseUri.queryParameters.containsKey('location'))
          'location': normalizedLocation
        else
          'location': normalizedLocation,
        'products': queryProducts,
      },
    );
  }
}

class MarketPricePoint {
  const MarketPricePoint({
    required this.productName,
    required this.price,
    required this.unit,
    required this.marketName,
    required this.source,
  });

  final String productName;
  final double price;
  final String unit;
  final String marketName;
  final String source;

  factory MarketPricePoint.fromJson(Map<String, dynamic> json) {
    final String productName = ((json['productName'] ?? json['product'] ?? '') as String).toString().trim();
    final String marketName = ((json['marketName'] ?? json['market'] ?? 'Nearby market') as String).toString().trim();
    final String unit = ((json['unit'] ?? 'unit') as String).toString().trim();
    final String source = ((json['source'] ?? 'Market feed') as String).toString().trim();

    return MarketPricePoint(
      productName: productName,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      unit: unit,
      marketName: marketName,
      source: source,
    );
  }
}
