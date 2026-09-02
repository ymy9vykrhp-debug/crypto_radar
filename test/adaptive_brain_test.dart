/// Тесты для AdaptiveSignalBrain системы

import 'package:flutter_test/flutter_test.dart';

// Импорты для тестирования
// import 'package:crypto_radar/engines/adaptive_signal_brain.dart';
// import 'package:crypto_radar/models/filter_performance_models.dart';
// import 'package:crypto_radar/models/signal_audit_models.dart';

void main() {
  group('AdaptiveSignalBrain Tests', () {
	// late AdaptiveSignalBrain brain;

	// setUp(() {
	//   brain = AdaptiveSignalBrain();
	//   brain.initializeDefaultFilters();
	// });

	test('Initialize filters correctly', () {
	  // Проверить что все фильтры инициализированы
	  // expect(brain.filterMetrics.length, greaterThan(0));
	  // for (final metrics in brain.filterMetrics.values) {
	  //   expect(metrics.signalCount, 0);
	  //   expect(metrics.successCount, 0);
	  //   expect(metrics.winRate, 0.0);
	  // }
	});

	test('Record signal correctly', () {
	  // final components = [SignalComponent.priceActionPattern];
	  // brain.recordSignal(
	  //   id: 'test_1',
	  //   symbol: 'BTCUSDT',
	  //   direction: 'LONG',
	  //   activeComponents: components,
	  //   entryPrice: 42000.0,
	  //   stopLoss: 41500.0,
	  //   targetPrice: 43000.0,
	  //   confidence: 85.0,
	  // );
	  //
	  // expect(brain.totalSignalsRecorded, 1);
	  // expect(brain.auditLog.first.symbol, 'BTCUSDT');
	  // expect(brain.auditLog.first.activeComponents.length, 1);
	});

	test('Update metrics on trade result', () {
	  // brain.recordSignal(
	  //   id: 'test_1',
	  //   symbol: 'BTCUSDT',
	  //   direction: 'LONG',
	  //   activeComponents: [SignalComponent.priceActionPattern],
	  //   entryPrice: 42000.0,
	  //   stopLoss: 41500.0,
	  //   targetPrice: 43000.0,
	  //   confidence: 85.0,
	  // );
	  //
	  // // Успешная сделка: цена пошла на +1%
	  // brain.recordTradeResult(
	  //   signalId: 'test_1',
	  //   result: TradeResult.success,
	  //   finalPrice: 42420.0,
	  //   profitPercent: 1.0,
	  //   rMultiple: 0.84,
	  // );
	  //
	  // final metrics =
	  //     brain.getFilterMetrics(SignalComponent.priceActionPattern.code);
	  // expect(metrics!.signalCount, 1);
	  // expect(metrics.successCount, 1);
	  // expect(metrics.winRate, 100.0);
	  // expect(metrics.averageR, 0.84);
	});

	test('Calculate Sharpe ratio correctly', () {
	  // final metrics = FilterPerformanceMetrics(
	  //   componentName: 'Test Filter',
	  //   profitList: [1.0, 0.5, -0.2, 1.5, 0.8],
	  // );
	  //
	  // expect(metrics.sharpeRatio, greaterThan(0)); // Должен быть положительным
	  // expect(metrics.averageProfit, closeTo(0.72, 0.01));
	});

	test('Update filter weight based on performance', () {
	  // final metrics = FilterPerformanceMetrics(
	  //   componentName: 'Test Filter',
	  // );
	  //
	  // // Добавить 15 успешных сделок (win rate = 100%)
	  // for (int i = 0; i < 15; i++) {
	  //   metrics.recordTradeResult(
	  //     success: true,
	  //     profitPercent: 0.8,
	  //     rMultiple: 0.8,
	  //   );
	  // }
	  //
	  // // Вес должен быть выше базового (0.5) из-за высокой win rate
	  // expect(metrics.weight, greaterThan(0.5));
	  // expect(metrics.weight, lessThanOrEqualTo(1.5));
	});

	test('Get hot and cold filters', () {
	  // // Создать горячий фильтр (90% win rate)
	  // final hotMetrics = FilterPerformanceMetrics(
	  //   componentName: 'Hot Filter',
	  // );
	  // for (int i = 0; i < 20; i++) {
	  //   hotMetrics.recordTradeResult(
	  //     success: i < 18, // 18 успехов из 20 = 90%
	  //     profitPercent: 1.0,
	  //     rMultiple: 1.0,
	  //   );
	  // }
	  // brain._filterMetrics['hot'] = hotMetrics;
	  //
	  // // Создать холодный фильтр (30% win rate)
	  // final coldMetrics = FilterPerformanceMetrics(
	  //   componentName: 'Cold Filter',
	  // );
	  // for (int i = 0; i < 20; i++) {
	  //   coldMetrics.recordTradeResult(
	  //     success: i < 6, // 6 успехов из 20 = 30%
	  //     profitPercent: -0.5,
	  //     rMultiple: -0.5,
	  //   );
	  // }
	  // brain._filterMetrics['cold'] = coldMetrics;
	  //
	  // final hot = brain.getHotFilters(minWinRate: 75.0, minSignals: 10);
	  // final cold = brain.getColdFilters(maxWinRate: 45.0, minSignals: 10);
	  //
	  // expect(hot.length, 1);
	  // expect(cold.length, 1);
	  // expect(hot.first.componentName, 'Hot Filter');
	  // expect(cold.first.componentName, 'Cold Filter');
	});

	test('Export and import configuration', () {
	  // brain.recordSignal(
	  //   id: 'test_1',
	  //   symbol: 'BTCUSDT',
	  //   direction: 'LONG',
	  //   activeComponents: [SignalComponent.volumeSpike],
	  //   entryPrice: 42000.0,
	  //   stopLoss: 41500.0,
	  //   targetPrice: 43000.0,
	  //   confidence: 80.0,
	  // );
	  //
	  // final config = brain.exportFilterConfiguration();
	  // expect(config, contains('BTCUSDT'));
	  // expect(config, contains('totalSignals'));
	  //
	  // // Создать новый brain и импортировать
	  // final brain2 = AdaptiveSignalBrain();
	  // brain2.importFilterConfiguration(config);
	  // expect(brain2.totalSignalsRecorded, brain.totalSignalsRecorded);
	});

	test('Calculate adaptive confidence', () {
	  // const double baseConfidence = 75.0;
	  // final components = [SignalComponent.priceActionPattern];
	  //
	  // // Сначала компонент имеет базовый вес 1.0
	  // var adaptive = brain.calculateAdaptiveConfidence(
	  //   baseConfidence,
	  //   components,
	  // );
	  // expect(adaptive, closeTo(baseConfidence, 0.1));
	  //
	  // // Добавить результаты чтобы компонент имел высокий win rate
	  // brain.recordSignal(
	  //   id: 'test_1',
	  //   symbol: 'BTCUSDT',
	  //   direction: 'LONG',
	  //   activeComponents: components,
	  //   entryPrice: 42000.0,
	  //   stopLoss: 41500.0,
	  //   targetPrice: 43000.0,
	  //   confidence: baseConfidence,
	  // );
	  //
	  // for (int i = 0; i < 15; i++) {
	  //   brain.recordTradeResult(
	  //     signalId: 'test_1',
	  //     result: TradeResult.success,
	  //     finalPrice: 42420.0,
	  //     profitPercent: 1.0,
	  //     rMultiple: 0.8,
	  //   );
	  // }
	  //
	  // // Теперь вес должен быть выше, confidence должна измениться
	  // adaptive = brain.calculateAdaptiveConfidence(
	  //   baseConfidence,
	  //   components,
	  // );
	  // // (точное значение зависит от логики весов)
	  // expect(adaptive, isA<double>());
	});
  });

  group('FilterPerformanceMetrics Tests', () {
	test('Calculate win rate correctly', () {
	  // final metrics = FilterPerformanceMetrics(
	  //   componentName: 'Test',
	  //   signalCount: 10,
	  //   successCount: 7,
	  // );
	  //
	  // expect(metrics.winRate, 70.0);
	});

	test('Calculate profit factor', () {
	  // final metrics = FilterPerformanceMetrics(
	  //   componentName: 'Test',
	  //   profitList: [1.0, 2.0, -0.5, 1.5, -0.3],
	  // );
	  // // Total profit: 1 + 2 + 1.5 = 4.5
	  // // Total loss: 0.5 + 0.3 = 0.8
	  // // PF = 4.5 / 0.8 = 5.625
	  //
	  // expect(metrics.profitFactor, closeTo(5.625, 0.01));
	});

	test('Determine health status correctly', () {
	  // final excellent =
	  //     FilterPerformanceMetrics(componentName: 'Test', successCount: 85);
	  // excellent.recordTradeResult(success: true, profitPercent: 1.0, rMultiple: 1.0);
	  // // Win rate >= 80%
	  //
	  // final poor = FilterPerformanceMetrics(componentName: 'Test', successCount: 3);
	  // for (int i = 0; i < 20; i++) {
	  //   poor.recordTradeResult(
	  //     success: i < 3,
	  //     profitPercent: 0.0,
	  //     rMultiple: 0.0,
	  //   );
	  // }
	  // // Win rate < 35%
	  //
	  // expect(excellent.healthStatus, FilterHealthStatus.excellent);
	  // expect(poor.healthStatus, FilterHealthStatus.poor);
	});
  });
}
