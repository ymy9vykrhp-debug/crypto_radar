/// Интеграция AdaptiveSignalBrain в торговый журнал
/// Автоматически обновляет метрики при добавлении/закрытии сделок

import 'package:flutter/foundation.dart';

import '../engines/adaptive_signal_brain.dart';
import '../models/filter_performance_models.dart';
import '../models/signal_audit_models.dart';
import '../models/signal_models.dart';
import '../models/trading_journal_models.dart';

/// Помощник для интеграции Brain с Journal
class BrainJournalIntegration {
  BrainJournalIntegration({required this.brain});

  final AdaptiveSignalBrain brain;

  /// Записать сигнал в brain при его создании
  void recordSignalInBrain(RadarSignal signal) {
	if (brain.filterMetrics.isEmpty) {
	  brain.initializeDefaultFilters();
	}

	brain.recordSignal(
	  id: signal.id,
	  symbol: signal.symbol,
	  direction: signal.direction.label,
	  activeComponents: signal.activeSignalComponents,
	  entryPrice: signal.entryPrice,
	  stopLoss: signal.stop,
	  targetPrice: signal.direction == SignalDirection.long
		  ? signal.tp1
		  : signal.stop - (signal.stop - signal.tp1),
	  confidence: _calculateConfidence(signal),
	);

	if (kDebugMode) {
	  print('✅ Signal recorded in brain: ${signal.symbol} ${signal.direction.label}');
	}
  }

  /// Обновить результат сделки в brain
  /// Вызывается когда сделка закрыта в журнале
  void recordTradeResultInBrain({
	required String signalId,
	required TradeJournalEntry entry,
  }) {
	// Определить результат сделки
	final TradeResult result = _determineTradeResult(entry);

	// Вычислить прибыль в %
	final double profitPercent = entry.profitableUsd / entry.entryPrice * 100;

	// Вычислить R-multiple
	final double risk = (entry.entryPrice - entry.stopLossPrice).abs();
	final double profit = (entry.exitPrice - entry.entryPrice).abs();
	final double rMultiple = risk > 0 ? profit / risk : 0.0;

	brain.recordTradeResult(
	  signalId: signalId,
	  result: result,
	  finalPrice: entry.exitPrice,
	  profitPercent: profitPercent,
	  rMultiple: rMultiple,
	  notes: entry.notes,
	);

	if (kDebugMode) {
	  print(
		'✅ Trade result recorded: $signalId - '
		'Result: ${result.toString()}, '
		'Profit: ${profitPercent.toStringAsFixed(2)}%',
	  );
	}
  }

  /// Обновить адаптивный confidence для всех новых сигналов
  /// на основе текущей производительности фильтров
  double getAdaptiveConfidenceForSignal(RadarSignal signal) {
	final baseConfidence = _calculateConfidence(signal);
	return brain.calculateAdaptiveConfidence(
	  baseConfidence,
	  signal.activeSignalComponents,
	);
  }

  /// Получить статистику для конкретного фильтра
  FilterStats? getFilterStatistics(SignalComponent component) {
	final metrics = brain.getFilterMetrics(component.code);
	if (metrics == null) return null;

	return FilterStats(
	  componentName: component.label,
	  signalCount: metrics.signalCount,
	  winCount: metrics.successCount,
	  winRate: metrics.winRate,
	  averageR: metrics.averageR,
	  sharpeRatio: metrics.sharpeRatio,
	  sortinoRatio: metrics.sortinoRatio,
	  weight: metrics.weight,
	);
  }

  /// Вычислить базовый confidence для сигнала
  double _calculateConfidence(RadarSignal signal) {
	// Используем score из сигнала если он есть
	if (signal.score > 0) {
	  return (signal.score / 100.0).clamp(0.0, 1.0) * 100.0;
	}

	// Или рассчитаем по компонентам
	double confidence = 50.0; // Базовая
	confidence += signal.activeSignalComponents.length * 8.0; // +8% за компонент
	return confidence.clamp(0.0, 100.0);
  }

  /// Определить результат сделки
  TradeResult _determineTradeResult(TradeJournalEntry entry) {
	// Если цена прошла более 0.4% в нужную сторону -> success
	if (entry.profitableUsd >= (entry.entryPrice * 0.004)) {
	  return TradeResult.success;
	}

	// Если цена прошла до 80% цели -> partial
	if (entry.profitableUsd >= (entry.entryPrice * 0.0032)) {
	  return TradeResult.partial;
	}

	// Если цена ушла в стоп -> stopped
	if (entry.exitPrice == entry.stopLossPrice) {
	  return TradeResult.stopped;
	}

	// Если сделка закрыта вручную с убытком -> cancelled
	return TradeResult.cancelled;
  }
}

/// Статистика по фильтру
class FilterStats {
  const FilterStats({
	required this.componentName,
	required this.signalCount,
	required this.winCount,
	required this.winRate,
	required this.averageR,
	required this.sharpeRatio,
	required this.sortinoRatio,
	required this.weight,
  });

  final String componentName;
  final int signalCount;
  final int winCount;
  final double winRate;
  final double averageR;
  final double sharpeRatio;
  final double sortinoRatio;
  final double weight;

  @override
  String toString() {
	return 'FilterStats('
		'name: $componentName, '
		'winRate: ${winRate.toStringAsFixed(1)}%, '
		'sharpe: ${sharpeRatio.toStringAsFixed(2)})';
  }
}
