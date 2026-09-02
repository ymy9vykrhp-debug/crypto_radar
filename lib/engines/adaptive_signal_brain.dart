/// Адаптивный интеллектуальный мозг системы сигналов
/// Анализирует результаты и автоматически адаптируется

import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../models/filter_performance_models.dart';
import '../models/signal_audit_models.dart';

/// Главный мозг адаптивной системы сигналов
/// Отслеживает производительность каждого фильтра
/// и пересчитывает веса в реальном времени
class AdaptiveSignalBrain extends ChangeNotifier {
  AdaptiveSignalBrain();

  /// Реестр всех фильтров и их метрик
  final Map<String, FilterPerformanceMetrics> _filterMetrics =
	  <String, FilterPerformanceMetrics>{};

  /// Лог всех сигналов и их результатов
  final List<SignalAuditEntry> _signalAuditLog = <SignalAuditEntry>[];

  /// Последние обновления для истории
  DateTime? _lastUpdated;

  // Getters
  Map<String, FilterPerformanceMetrics> get filterMetrics =>
	  Map<String, FilterPerformanceMetrics>.unmodifiable(_filterMetrics);

  List<SignalAuditEntry> get auditLog =>
	  List<SignalAuditEntry>.unmodifiable(_signalAuditLog);

  int get totalSignalsRecorded => _signalAuditLog.length;

  int get totalSuccessfulSignals =>
	  _signalAuditLog.where((entry) => entry.isSuccessful).length;

  double get overallWinRate {
	if (_signalAuditLog.isEmpty) return 0.0;
	return (totalSuccessfulSignals / _signalAuditLog.length) * 100.0;
  }

  DateTime? get lastUpdated => _lastUpdated;

  /// Инициализировать фильтры по умолчанию
  void initializeDefaultFilters() {
	for (final component in SignalComponent.values) {
	  _filterMetrics[component.code] = FilterPerformanceMetrics(
		componentName: component.label,
	  );
	}
	_lastUpdated = DateTime.now();
	notifyListeners();
  }

  /// Записать новый сигнал с его компонентами
  void recordSignal({
	required String id,
	required String symbol,
	required String direction,
	required List<SignalComponent> activeComponents,
	required double entryPrice,
	required double stopLoss,
	required double targetPrice,
	required double confidence,
  }) {
	final entry = SignalAuditEntry(
	  id: id,
	  symbol: symbol,
	  direction: direction,
	  timestamp: DateTime.now(),
	  activeComponents: activeComponents,
	  entryPrice: entryPrice,
	  stopLoss: stopLoss,
	  targetPrice: targetPrice,
	  confidence: confidence,
	);

	_signalAuditLog.add(entry);

	// Убедиться что все компоненты инициализированы
	for (final component in activeComponents) {
	  if (!_filterMetrics.containsKey(component.code)) {
		_filterMetrics[component.code] =
			FilterPerformanceMetrics(componentName: component.label);
	  }
	}

	_lastUpdated = DateTime.now();
	notifyListeners();
  }

  /// Записать результат закрытой сделки
  /// Это обновит метрики всех фильтров которые были в этом сигнале
  void recordTradeResult({
	required String signalId,
	required TradeResult result,
	required double finalPrice,
	required double profitPercent,
	required double rMultiple,
	String notes = '',
  }) {
	// Найти соответствующую запись в логе
	final entryIndex = _signalAuditLog.indexWhere((e) => e.id == signalId);
	if (entryIndex == -1) {
	  if (kDebugMode) {
		print('❌ Signal $signalId not found in audit log');
	  }
	  return;
	}

	final entry = _signalAuditLog[entryIndex];

	// Обновить запись сигнала
	entry.result = result;
	entry.finalPrice = finalPrice;
	entry.profitPercent = profitPercent;
	entry.rMultiple = rMultiple;
	entry.closedAt = DateTime.now();
	entry.notes = notes;

	// Определить был ли сигнал успешным
	final bool success = result == TradeResult.success ||
		result == TradeResult.partial;

	if (kDebugMode) {
	  print(
		'✅ Signal recorded: $signalId - '
		'Result: ${result.toString()}, '
		'Profit: ${profitPercent.toStringAsFixed(2)}%, '
		'Components: ${entry.activeComponents.length}',
	  );
	}

	// Обновить метрики для каждого компонента который был в этом сигнале
	for (final component in entry.activeComponents) {
	  final metrics = _filterMetrics[component.code];
	  if (metrics != null) {
		metrics.recordTradeResult(
		  success: success,
		  profitPercent: profitPercent,
		  rMultiple: rMultiple,
		);
	  }
	}

	_lastUpdated = DateTime.now();
	notifyListeners();
  }

  /// Получить метрики конкретного фильтра
  FilterPerformanceMetrics? getFilterMetrics(String componentCode) {
	return _filterMetrics[componentCode];
  }

  /// Получить все фильтры отсортированные по win rate (лучшие - первые)
  List<FilterPerformanceMetrics> getFiltersRankedByPerformance() {
	final List<FilterPerformanceMetrics> metrics = _filterMetrics.values
		.where((m) => m.signalCount > 0)
		.toList();
	metrics.sort((a, b) => b.winRate.compareTo(a.winRate));
	return metrics;
  }

  /// Получить гарячие фильтры (win rate > 75% и минимум 10 сделок)
  List<FilterPerformanceMetrics> getHotFilters({
	double minWinRate = 75.0,
	int minSignals = 10,
  }) {
	return _filterMetrics.values
		.where((m) => m.winRate >= minWinRate && m.signalCount >= minSignals)
		.toList();
  }

  /// Получить холодные/плохие фильтры (win rate < 45% и минимум 10 сделок)
  List<FilterPerformanceMetrics> getColdFilters({
	double maxWinRate = 45.0,
	int minSignals = 10,
  }) {
	return _filterMetrics.values
		.where((m) => m.winRate <= maxWinRate && m.signalCount >= minSignals)
		.toList();
  }

  /// Переключить включение/отключение фильтра
  void toggleFilter(String componentCode) {
	final metrics = _filterMetrics[componentCode];
	if (metrics != null) {
	  metrics.enabled = !metrics.enabled;
	  _lastUpdated = DateTime.now();
	  notifyListeners();
	}
  }

  /// Включить фильтр
  void enableFilter(String componentCode) {
	final metrics = _filterMetrics[componentCode];
	if (metrics != null && !metrics.enabled) {
	  metrics.enabled = true;
	  _lastUpdated = DateTime.now();
	  notifyListeners();
	}
  }

  /// Отключить фильтр
  void disableFilter(String componentCode) {
	final metrics = _filterMetrics[componentCode];
	if (metrics != null && metrics.enabled) {
	  metrics.enabled = false;
	  _lastUpdated = DateTime.now();
	  notifyListeners();
	}
  }

  /// Получить рекомендацию по фильтру
  /// Возвращает строка с рекомендацией (если есть)
  String? getRecommendationForFilter(String componentCode) {
	final metrics = _filterMetrics[componentCode];
	if (metrics == null) return null;

	if (metrics.signalCount < 10) {
	  return 'Need more data (${metrics.signalCount} signals)';
	}

	if (metrics.winRate < 40) {
	  return '❌ DISABLE: Win rate ${metrics.winRate.toStringAsFixed(1)}% is too low';
	}

	if (metrics.winRate >= 80) {
	  return '✅ EXCELLENT: Keep this filter, ${metrics.winRate.toStringAsFixed(1)}% win rate';
	}

	if (metrics.winRate >= 65) {
	  return '✅ GOOD: Keep this filter';
	}

	return null;
  }

  /// Получить адаптивный вес для сигнала на основе его компонентов
  /// Веса зависят от текущей производительности фильтров
  double calculateAdaptiveConfidence(
	double baseConfidence,
	List<SignalComponent> activeComponents,
  ) {
	if (activeComponents.isEmpty) return baseConfidence;

	double weightedSum = 0.0;
	double totalWeight = 0.0;

	for (final component in activeComponents) {
	  final metrics = _filterMetrics[component.code];
	  if (metrics != null && metrics.enabled) {
		final double filterConfidence =
			(metrics.winRate / 100.0) * baseConfidence;
		final double filterWeight = metrics.weight;

		weightedSum += filterConfidence * filterWeight;
		totalWeight += filterWeight;
	  }
	}

	if (totalWeight == 0) return baseConfidence;
	return weightedSum / totalWeight;
  }

  /// Получить статистику по периодам
  /// Возвращает последние N сделок с их результатами
  List<SignalAuditEntry> getRecentSignals(int count) {
	if (_signalAuditLog.isEmpty) return [];
	final int startIndex =
		(_signalAuditLog.length - count).clamp(0, _signalAuditLog.length);
	return _signalAuditLog.sublist(startIndex);
  }

  /// Получить среднюю прибыль за последний период
  double getAverageProfitForPeriod(int daysBack) {
	final DateTime cutoff = DateTime.now().subtract(Duration(days: daysBack));
	final List<SignalAuditEntry> recent = _signalAuditLog
		.where((entry) => entry.timestamp.isAfter(cutoff))
		.toList();

	if (recent.isEmpty) return 0.0;

	final double totalProfit =
		recent.fold(0.0, (sum, entry) => sum + entry.profitPercent);
	return totalProfit / recent.length;
  }

  /// Экспортировать всю конфигурацию фильтров в JSON
  /// Для сохранения и восстановления оптимальных настроек
  String exportFilterConfiguration() {
	final Map<String, dynamic> config = {
	  'timestamp': DateTime.now().toIso8601String(),
	  'filters': _filterMetrics.values.map((m) => m.toJson()).toList(),
	  'overallStats': {
		'totalSignals': totalSignalsRecorded,
		'successfulSignals': totalSuccessfulSignals,
		'overallWinRate': overallWinRate,
	  },
	};
	return jsonEncode(config);
  }

  /// Импортировать конфигурацию фильтров из JSON
  void importFilterConfiguration(String jsonString) {
	try {
	  final Map<String, dynamic> config = jsonDecode(jsonString);
	  _filterMetrics.clear();

	  final List<dynamic> filters =
		  config['filters'] as List<dynamic>? ?? [];
	  for (final dynamic filterJson in filters) {
		final metrics = FilterPerformanceMetrics.fromJson(
		  filterJson as Map<String, dynamic>,
		);
		_filterMetrics[metrics.componentName] = metrics;
	  }

	  _lastUpdated = DateTime.now();
	  notifyListeners();

	  if (kDebugMode) {
		print(
		  '✅ Imported ${_filterMetrics.length} filter configurations',
		);
	  }
	} catch (e) {
	  if (kDebugMode) {
		print('❌ Failed to import filter config: $e');
	  }
	}
  }

  /// Сбросить все метрики (для полного перестарта)
  void resetAllMetrics() {
	_filterMetrics.clear();
	_signalAuditLog.clear();
	_lastUpdated = DateTime.now();
	notifyListeners();
  }

  /// Сбросить метрики конкретного фильтра
  void resetFilterMetrics(String componentCode) {
	final metrics = _filterMetrics[componentCode];
	if (metrics != null) {
	  _filterMetrics[componentCode] = FilterPerformanceMetrics(
		componentName: metrics.componentName,
	  );
	  _lastUpdated = DateTime.now();
	  notifyListeners();
	}
  }

  @override
  String toString() {
	return 'AdaptiveSignalBrain('
		'filters: ${_filterMetrics.length}, '
		'signals: ${_signalAuditLog.length}, '
		'winRate: ${overallWinRate.toStringAsFixed(1)}%)';
  }
}
