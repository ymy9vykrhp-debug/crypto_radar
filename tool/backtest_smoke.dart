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
        'avgR=${report.averageR.toStringAsFixed(2)} '
        'stopToTp1=${report.stopThenTp1Percent.toStringAsFixed(1)}%',
      );
      for (final comparison in report.executionComparisons) {
        stdout.writeln(
          '  ${comparison.profileId} trades=${comparison.trades} '
          'avgR=${comparison.averageR.toStringAsFixed(2)} '
          'pf=${comparison.profitFactor.toStringAsFixed(2)} '
          'stopToTarget='
          '${comparison.stopThenTargetPercent.toStringAsFixed(1)}% '
          'oos=${comparison.outOfSampleAverageR.toStringAsFixed(2)}R '
          'n=${comparison.outOfSampleTrades}',
        );
      }
    }
  } finally {
    client.close();
  }
}
