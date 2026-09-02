/// Модели для отслеживания производительности каждого фильтра/индикатора
/// в адаптивной системе сигналов

import 'dart:math';

/// Enum всех возможных компонентов сигнала (фильтров)
enum SignalComponent {
  priceActionPattern,      // Паттерны свечей (Pin Bar, Engulfing и т.д.)
  fibonacci38Level,        // Откат на уровень Фибоначчи 38.2%
  fibonacci50Level,        // Откат на уровень Фибоначчи 50.0%
  fibonacci61Level,        // Откат на уровень Фибоначчи 61.8%
  volumeSpike,             // Объём выше среднего
  rsiOversold,             // RSI выход из перепроданности
  rsiOverbought,           // RSI выход из перекупленности
  trendAbove200ma,         // Цена выше 200-периодной МА
  trendAbove50ma,          // Цена выше 50-периодной МА
  macdCrossover,           // Пересечение MACD
  supportBounce,           // Отскок от поддержки
  resistanceBreakout,      // Пробой сопротивления
  liquiditySweep,          // Sweep ликвидности
  structuralBreakout,      // Пробой структуры (BOS/CHOCH)
}

extension SignalComponentLabel on SignalComponent {
  String get label {
	switch (this) {
	  case SignalComponent.priceActionPattern:
		return 'Price Action Pattern';
	  case SignalComponent.fibonacci38Level:
		return 'Fib 38.2% Level';
	  case SignalComponent.fibonacci50Level:
		return 'Fib 50.0% Level';
	  case SignalComponent.fibonacci61Level:
		return 'Fib 61.8% Level';
	  case SignalComponent.volumeSpike:
		return 'Volume Spike';
	  case SignalComponent.rsiOversold:
		return 'RSI Oversold';
	  case SignalComponent.rsiOverbought:
		return 'RSI Overbought';
	  case SignalComponent.trendAbove200ma:
		return 'Trend 200MA';
	  case SignalComponent.trendAbove50ma:
		return 'Trend 50MA';
	  case SignalComponent.macdCrossover:
		return 'MACD Crossover';
	  case SignalComponent.supportBounce:
		return 'Support Bounce';
	  case SignalComponent.resistanceBreakout:
		return 'Resistance Breakout';
	  case SignalComponent.liquiditySweep:
		return 'Liquidity Sweep';
	  case SignalComponent.structuralBreakout:
		return 'Structural Breakout';
	}
  }

  String get code => name;
}

/// Статус фильтра (рекомендация системы)
enum FilterHealthStatus {
  excellent,    // > 80% win rate, отличные метрики
  good,         // 65-80% win rate, хороший фильтр
  acceptable,   // 50-65% win rate, нормальный
  warning,      // 35-50% win rate, нужно пересмотреть
  poor,         // < 35% win rate, рекомендуется отключить
}

/// Метрики производительности одного фильтра
class FilterPerformanceMetrics {
  FilterPerformanceMetrics({
	required this.componentName,
	this.signalCount = 0,
	this.successCount = 0,
	this.profitList = const <double>[],
	this.rList = const <double>[],
	this.enabled = true,
	this.weight = 1.0,
	this.lastUpdated,
  });

  /// Название фильтра
  final String componentName;

  /// Сколько сигналов содержали этот фильтр
  int signalCount;

  /// Из них, сколько были успешными (цена прошла +0.4% без стопа)
  int successCount;

  /// Список всех прибылей/убытков в процентах
  List<double> profitList;

  /// Список всех R-multiple значений (profit/risk)
  List<double> rList;

  /// Включен ли фильтр в текущей конфигурации
  bool enabled;

  /// Динамический вес фильтра (0.5 - 1.5), влияет на confidence score
  double weight;

  /// Последнее обновление метрик
  DateTime? lastUpdated;

  /// Win Rate (%) - сколько % сигналов с этим фильтром были успешными
  double get winRate {
	if (signalCount == 0) return 0.0;
	return (successCount / signalCount) * 100.0;
  }

  /// Средний заработок в R-multiple
  double get averageR {
	if (rList.isEmpty) return 0.0;
	final double sum = rList.fold<double>(0.0, (a, b) => a + b);
	return sum / rList.length;
  }

  /// Средняя прибыль в %
  double get averageProfit {
	if (profitList.isEmpty) return 0.0;
	final double sum = profitList.fold<double>(0.0, (a, b) => a + b);
	return sum / profitList.length;
  }

  /// Стандартное отклонение прибылей (волатильность результатов)
  double get standardDeviation {
	if (profitList.isEmpty) return 0.0;
	final double mean = averageProfit;
	final double variance = profitList.fold<double>(
	  0.0,
	  (sum, profit) => sum + ((profit - mean) * (profit - mean)),
	) / profitList.length;
	return variance > 0 ? variance.toStringAsFixed(4) as double : 0.0;
  }

  /// Sharpe Ratio (доход / волатильность)
  /// Чем выше, тем лучше соотношение прибыли к риску
  double get sharpeRatio {
	if (profitList.isEmpty) return 0.0;
	const double riskFreeRate = 0.0; // Ставка без риска (для крипто обычно 0)
	const double periods = 252.0; // Периоды в году

	final double mean = averageProfit;
	final double variance = profitList.fold<double>(
	  0.0,
	  (sum, profit) => sum + ((profit - mean) * (profit - mean)),
	) / profitList.length;
	final double stdDev = variance > 0 ? sqrt(variance) : 0.0;

	if (stdDev == 0) return 0.0;
	return ((mean - riskFreeRate) / stdDev) * (sqrt(periods));
  }

  /// Sortino Ratio (учитывает только вниз-волатильность)
  /// Штрафует только за убытки, не за колебания вверх
  double get sortinoRatio {
	if (profitList.isEmpty) return 0.0;
	const double riskFreeRate = 0.0;
	const double periods = 252.0;

	final double mean = averageProfit;

	// Считаем только вниз-волатильность (отклонения ниже среднего)
	final double downVariance = profitList.fold<double>(
	  0.0,
	  (sum, profit) {
		final double diff = profit - mean;
		return sum + (diff < 0 ? diff * diff : 0.0);
	  },
	) / profitList.length;

	final double downStdDev = downVariance > 0 ? sqrt(downVariance) : 0.0;

	if (downStdDev == 0) return averageProfit > 0 ? 999.0 : 0.0;
	return ((mean - riskFreeRate) / downStdDev) * (sqrt(periods));
  }

  /// Max Drawdown - самая большая просадка за весь период
  double get maxDrawdown {
	if (profitList.isEmpty) return 0.0;

	double peak = profitList.first;
	double maxDD = 0.0;

	for (final double profit in profitList) {
	  if (profit > peak) {
		peak = profit;
	  }
	  final double drawdown = peak - profit;
	  if (drawdown > maxDD) {
		maxDD = drawdown;
	  }
	}

	return maxDD;
  }

  /// Profit Factor - сумма прибылей / сумма убытков
  double get profitFactor {
	if (profitList.isEmpty) return 0.0;

	double totalProfit = 0.0;
	double totalLoss = 0.0;

	for (final double profit in profitList) {
	  if (profit > 0) {
		totalProfit += profit;
	  } else {
		totalLoss += profit.abs();
	  }
	}

	if (totalLoss == 0) return totalProfit > 0 ? 999.0 : 0.0;
	return totalProfit / totalLoss;
  }

  /// Статус здоровья фильтра (для UI и рекомендаций)
  FilterHealthStatus get healthStatus {
	final double wr = winRate;
	if (wr > 80) return FilterHealthStatus.excellent;
	if (wr > 65) return FilterHealthStatus.good;
	if (wr > 50) return FilterHealthStatus.acceptable;
	if (wr > 35) return FilterHealthStatus.warning;
	return FilterHealthStatus.poor;
  }

  /// Как инициализировать вес на основе win rate
  void updateWeightBasedOnPerformance() {
	// Базовый вес 0.5, максимум 1.5
	// Для каждого процента выше 50% добавляем 0.02x
	final double baseWeight = 0.5;
	final double performanceBonus = (winRate - 50.0) * 0.02;
	weight = (baseWeight + performanceBonus).clamp(0.3, 1.5);
	lastUpdated = DateTime.now();
  }

  /// Добавить результат одной сделки
  void recordTradeResult({
	required bool success,
	required double profitPercent,
	required double rMultiple,
  }) {
	signalCount++;
	if (success) successCount++;

	profitList = [...profitList, profitPercent];
	rList = [...rList, rMultiple];

	// Пересчитать вес после каждого нового результата
	updateWeightBasedOnPerformance();
  }

  /// Сериализация для хранения
  Map<String, dynamic> toJson() {
	return {
	  'componentName': componentName,
	  'signalCount': signalCount,
	  'successCount': successCount,
	  'profitList': profitList,
	  'rList': rList,
	  'enabled': enabled,
	  'weight': weight,
	  'lastUpdated': lastUpdated?.toIso8601String(),
	};
  }

  /// Десериализация из JSON
  static FilterPerformanceMetrics fromJson(Map<String, dynamic> json) {
	return FilterPerformanceMetrics(
	  componentName: json['componentName'] as String,
	  signalCount: json['signalCount'] as int? ?? 0,
	  successCount: json['successCount'] as int? ?? 0,
	  profitList: List<double>.from(
		(json['profitList'] as List?)?.cast<double>() ?? [],
	  ),
	  rList: List<double>.from(
		(json['rList'] as List?)?.cast<double>() ?? [],
	  ),
	  enabled: json['enabled'] as bool? ?? true,
	  weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
	  lastUpdated: json['lastUpdated'] != null
		  ? DateTime.parse(json['lastUpdated'] as String)
		  : null,
	);
  }

  @override
  String toString() {
	return 'FilterPerformanceMetrics('
		'name: $componentName, '
		'signals: $signalCount, '
		'winRate: ${winRate.toStringAsFixed(1)}%, '
		'sharpe: ${sharpeRatio.toStringAsFixed(2)}, '
		'weight: ${weight.toStringAsFixed(2)}x)';
  }
}
