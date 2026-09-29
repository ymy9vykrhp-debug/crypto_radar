import 'dart:convert';

import 'package:crypto_radar/models/market_models.dart';
import 'package:crypto_radar/services/binance_confirmation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('normalizes public Binance klines into a confirmation snapshot', () async {
    final DateTime now = DateTime.utc(2026, 9, 28, 12);
    final MockClient client = MockClient((http.Request request) async {
      expect(request.url.host, 'fapi.binance.com');
      expect(request.url.path, '/fapi/v1/klines');
      return http.Response(jsonEncode(_klines(now)), 200);
    });
    final BinanceConfirmationService service = BinanceConfirmationService(
      client,
      clock: () => now,
    );

    final snapshot = await service.load('FARTCOINUSDT');

    expect(snapshot.venue, 'BINANCE');
    expect(snapshot.symbol, 'FARTCOINUSDT');
    expect(snapshot.price, greaterThan(100));
    expect(snapshot.updatedAt, now);
    expect(snapshot.trend5m, Bias.bullish);
    expect(snapshot.trend15m, Bias.bullish);
    expect(snapshot.trend1h, Bias.bullish);
    expect(snapshot.relativeVolume5m, greaterThan(1));
    expect(snapshot.isFreshAt(now), isTrue);
  });
}

List<List<Object>> _klines(DateTime now) {
  final List<List<Object>> result = <List<Object>>[];
  for (int i = 0; i < 10; i++) {
    final DateTime close = now.subtract(Duration(minutes: 9 - i));
    final double open = 100 + i * 0.15;
    final double closePrice = open + 0.18;
    result.add(<Object>[
      close.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
      open.toStringAsFixed(4),
      (closePrice + 0.08).toStringAsFixed(4),
      (open - 0.05).toStringAsFixed(4),
      closePrice.toStringAsFixed(4),
      (1000 + i * 150).toString(),
      close.millisecondsSinceEpoch,
    ]);
  }
  return result;
}
