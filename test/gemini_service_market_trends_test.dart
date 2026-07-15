import 'package:flutter_test/flutter_test.dart';

import 'package:farmsynchub/core/services/gemini_service.dart';

void main() {
  test('builds a local market trend insight from the selected location and trend data', () {
    final String insight = GeminiService.instance.buildLocalMarketTrendInsight(
      location: 'Jos',
      trendData: <Map<String, dynamic>>[
        <String, dynamic>{
          'productName': 'Maize',
          'currentPrice': 250.0,
          'previousAverage': 220.0,
          'proposedFuturePrice': 265.0,
          'unit': 'kg',
          'trendPercent': 13.6,
          'direction': 'rising',
        },
      ],
    );

    expect(insight, contains('Jos'));
    expect(insight, contains('Maize'));
    expect(insight, contains('Future estimate'));
  });
}
