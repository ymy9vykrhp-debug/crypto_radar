/// Расширение для SignalEngine с поддержкой адаптивной системы
/// Определяет какие компоненты (фильтры) активны для каждого сигнала

import '../models/filter_performance_models.dart';
import '../models/market_models.dart';
import '../models/signal_models.dart';

/// Helper класс для определения активных компонентов сигнала
class SignalComponentDetector {
  /// Определить какие компоненты активны для данного сигнала
  static List<SignalComponent> detectActiveComponents(
	RadarSignal signal,
	MarketSnapshot snapshot,
  ) {
	final List<SignalComponent> components = <SignalComponent>[];

	// 1. Price Action Pattern
	if (_isValidPriceActionPattern(signal, snapshot)) {
	  components.add(SignalComponent.priceActionPattern);
	}

	// 2. Fibonacci уровни
	if (_isFibonacciLevel(signal, snapshot)) {
	  components.add(SignalComponent.fibonacci38Level);
	}

	// 3. Volume Spike
	if (signal.relativeVolume > 1.4) {
	  components.add(SignalComponent.volumeSpike);
	}

	// 4. RSI Oversold/Overbought
	if (_isRsiExtreme(signal)) {
	  if (signal.rsi < 30) {
		components.add(SignalComponent.rsiOversold);
	  } else if (signal.rsi > 70) {
		components.add(SignalComponent.rsiOverbought);
	  }
	}

	// 5. Trend выше 200MA
	if (signal.ema200 > 0 && signal.referencePrice > signal.ema200) {
	  components.add(SignalComponent.trendAbove200ma);
	}

	// 6. Trend выше 50MA
	if (signal.ema50 > 0 && signal.referencePrice > signal.ema50) {
	  components.add(SignalComponent.trendAbove50ma);
	}

	// 7. MACD Crossover
	if (_isMacdCrossover(signal)) {
	  components.add(SignalComponent.macdCrossover);
	}

	// 8. Support/Resistance Bounce
	if (_isSupportBounce(signal)) {
	  components.add(SignalComponent.supportBounce);
	}

	// 9. Structural Breakout
	if (signal.bos != Bias.neutral || signal.choch != Bias.neutral) {
	  components.add(SignalComponent.structuralBreakout);
	}

	// 10. Liquidity Sweep
	if (signal.liquiditySweepConfirmed) {
	  components.add(SignalComponent.liquiditySweep);
	}

	return components;
  }

  /// Проверить валидный ли Price Action паттерн
  static bool _isValidPriceActionPattern(
	RadarSignal signal,
	MarketSnapshot snapshot,
  ) {
	// Простой критерий: есть ли структура (BOS или CHOCH)
	if (signal.bos != Bias.neutral || signal.choch != Bias.neutral) {
	  return true;
	}

	// Или если есть хороший pin bar (малая тень)
	// Это упрощённая проверка
	return signal.qualityFlags.contains(TradeQualityFlag.goodEntry);
  }

  /// Проверить находится ли цена на уровне Фибоначчи
  static bool _isFibonacciLevel(
	RadarSignal signal,
	MarketSnapshot snapshot,
  ) {
	// Упрощённая проверка: если цена близко к одному из уровней МА
	// В реальной системе нужно вычислять реальные Fib уровни
	const double fibTolerance = 0.3; // 0.3%

	// Проверим близость к 38.2% и 50% уровням (условно)
	final double testLevel1 = signal.referencePrice * 0.99; // -1%
	final double testLevel2 = signal.referencePrice * 0.995; // -0.5%

	return (signal.referencePrice - testLevel1).abs() /
			signal.referencePrice *
			100 <
		fibTolerance;
  }

  /// Проверить экстремальные значения RSI
  static bool _isRsiExtreme(RadarSignal signal) {
	return signal.rsi < 30 || signal.rsi > 70;
  }

  /// Проверить пересечение MACD
  static bool _isMacdCrossover(RadarSignal signal) {
	// MACD crossover если значение меняется знак
	return signal.macd.abs() < 0.5; // Близко к нулевой линии
  }

  /// Проверить отскок от поддержки
  static bool _isSupportBounce(RadarSignal signal) {
	// Если была ликвидностная развёртка вниз, а потом отскок вверх
	return signal.liquidityBias == Bias.bullish &&
		signal.trend5m != Bias.bearish;
  }
}

/// Расширение для RadarSignal с методами для работы с компонентами
extension RadarSignalComponents on RadarSignal {
  /// Получить строку описания всех активных компонентов
  String getComponentsDescription() {
	if (activeSignalComponents.isEmpty) {
	  return 'No components';
	}

	return activeSignalComponents
		.map((c) => c.label)
		.toList()
		.join(', ');
  }

  /// Получить количество активных компонентов
  int getComponentCount() => activeSignalComponents.length;

  /// Проверить содержит ли сигнал конкретный компонент
  bool hasComponent(SignalComponent component) {
	return activeSignalComponents.contains(component);
  }

  /// Получить метрику "confluency" - сколько компонентов совпадают
  /// Чем больше компонентов, тем выше уверенность
  double getConfluencyScore() {
	// Каждый компонент добавляет определённый % к уверенности
	// 1-2 компонента = базовая уверенность
	// 3-4 компонента = хорошая уверенность
	// 5+ компонентов = отличная уверенность

	const double baseScore = 50.0;
	const double scorePerComponent = 10.0;
	const double maxScore = 100.0;

	final double calculatedScore =
		baseScore + (activeSignalComponents.length * scorePerComponent);
	return calculatedScore.clamp(0.0, maxScore);
  }
}
