import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:farmsynchub/core/services/market_data_service.dart';

void main() {
  test('uses the configured API base URL and key when present', () async {
    final List<String> seenHeaders = <String>[];
    final _FakeClient client = _FakeClient((http.Request request) {
      seenHeaders.add(request.headers['Authorization'] ?? '');
      return http.Response(
        jsonEncode(<String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'product': 'Maize',
              'price': 250,
              'unit': 'kg',
              'market': 'Jos',
              'source': 'Configured API',
            },
          ],
        }),
        200,
      );
    });

    final MarketDataService service = MarketDataService(
      client: client,
      baseUrl: 'https://example.com/api/market-prices',
      apiKey: 'test-key',
    );

    final List<MarketPricePoint> result = await service.fetchNearbyMarketPrices(
      location: 'Jos',
      products: <String>['maize'],
    );

    expect(result, hasLength(1));
    expect(result.single.productName, 'Maize');
    expect(result.single.marketName, 'Jos');
    expect(seenHeaders.single, 'Bearer test-key');
  });
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final http.Response Function(http.Request request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final http.Response response = _handler(request as http.Request);
    return http.StreamedResponse(Stream<List<int>>.fromIterable(<List<int>>[utf8.encode(response.body)]), response.statusCode, headers: response.headers);
  }
}
