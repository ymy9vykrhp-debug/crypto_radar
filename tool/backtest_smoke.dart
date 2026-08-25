import 'dart:io';

import 'package:crypto_radar/engines/backtest_engine.dart';
import 'package:crypto_radar/services/bybit_service.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final http.Client client = http.Client();
  final BacktestEngine engine = BacktestEngine(
    bybitService: BybitService(client),
  );
  try {
    for (final String symbol in <String>['BTCUSDT', 'FARTCOINUSDT']) {
      final report = await engine.run(symbol);
      stdout.writeln(
        '$symbol signals=${report.signals} trades=${report.trades} '
        'winRate=${report.winRate.toStringAsFixed(1)} '
        'avgR=${report.averageR.toStringAsFixed(2)}',
      );
    }
  } finally {
    client.close();
  }
}
