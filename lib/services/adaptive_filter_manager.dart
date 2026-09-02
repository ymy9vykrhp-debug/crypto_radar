/// Менеджер для управления фильтрами
/// Включение/отключение, сохранение конфигураций, экспорт/импорт

import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../models/filter_performance_models.dart';
import 'adaptive_signal_brain.dart';

/// Управление конфигурацией фильтров
class FilterManager extends ChangeNotifier {
  FilterManager(this._brain);

  final AdaptiveSignalBrain _brain;

  /// История сохранённых конфигураций
  final Map<String, String> _savedConfigurations = <String, String>{};

  // Getters
  AdaptiveSignalBrain get brain => _brain;

  Map<String, String> get savedConfigurations =>
	  Map<String, String>.unmodifiable(_savedConfigurations);

  /// Получить список всех включённых фильтров
  List<FilterPerformanceMetrics> getEnabledFilters() {
	return _brain.filterMetrics.values
		.where((m) => m.enabled)
		.toList();
  }

  /// Получить список всех отключённых фильтров
  List<FilterPerformanceMetrics> getDisabledFilters() {
	return _brain.filterMetrics.where((key, m) => !m.enabled).values.toList();
  }

  /// Включить фильтр
  void enableFilter(String componentCode) {
	_brain.enableFilter(componentCode);
	notifyListeners();
  }

  /// Отключить фильтр
  void disableFilter(String componentCode) {
	_brain.disableFilter(componentCode);
	notifyListeners();
  }

  /// Переключить фильтр
  void toggleFilter(String componentCode) {
	_brain.toggleFilter(componentCode);
	notifyListeners();
  }

  /// Включить все фильтры
  void enableAllFilters() {
	for (final metrics in _brain.filterMetrics.values) {
	  metrics.enabled = true;
	}
	notifyListeners();
  }

  /// Отключить все фильтры
  void disableAllFilters() {
	for (final metrics in _brain.filterMetrics.values) {
	  metrics.enabled = false;
	}
	notifyListeners();
  }

  /// Применить автоматические рекомендации системы
  /// Отключит плохие фильтры и включит хорошие
  void applyAutoOptimization({
	double hotThreshold = 75.0, // Win rate для включения
	double coldThreshold = 45.0, // Win rate для отключения
	int minSignals = 10, // Минимум сделок для рекомендации
  }) {
	// Отключить холодные фильтры
	final cold = _brain.getColdFilters(
	  maxWinRate: coldThreshold,
	  minSignals: minSignals,
	);
	for (final metrics in cold) {
	  _brain.disableFilter(metrics.componentName);
	}

	// Включить горячие фильтры
	final hot = _brain.getHotFilters(
	  minWinRate: hotThreshold,
	  minSignals: minSignals,
	);
	for (final metrics in hot) {
	  _brain.enableFilter(metrics.componentName);
	}

	if (kDebugMode) {
	  print(
		'🎯 Auto-optimization: Disabled ${cold.length} cold filters, '
		'Enabled ${hot.length} hot filters',
	  );
	}

	notifyListeners();
  }

  /// Сохранить текущей конфигурацию с названием
  void saveConfiguration(String name) {
	_savedConfigurations[name] = _brain.exportFilterConfiguration();
	if (kDebugMode) {
	  print('💾 Configuration saved: $name');
	}
	notifyListeners();
  }

  /// Загрузить сохранённую конфигурацию
  void loadConfiguration(String name) {
	final config = _savedConfigurations[name];
	if (config != null) {
	  _brain.importFilterConfiguration(config);
	  if (kDebugMode) {
		print('📂 Configuration loaded: $name');
	  }
	  notifyListeners();
	}
  }

  /// Удалить сохранённую конфигурацию
  void deleteConfiguration(String name) {
	_savedConfigurations.remove(name);
	if (kDebugMode) {
	  print('🗑️ Configuration deleted: $name');
	}
	notifyListeners();
  }

  /// Получить список всех сохранённых конфигураций
  List<String> getSavedConfigurationNames() {
	return _savedConfigurations.keys.toList();
  }

  /// Экспортировать все сохранённые конфигурации в JSON
  String exportAllConfigurations() {
	final Map<String, dynamic> data = {
	  'timestamp': DateTime.now().toIso8601String(),
	  'configurations': _savedConfigurations,
	};
	return jsonEncode(data);
  }

  /// Импортировать конфигурации из JSON
  void importAllConfigurations(String jsonString) {
	try {
	  final Map<String, dynamic> data = jsonDecode(jsonString);
	  final Map<String, dynamic> configs =
		  data['configurations'] as Map<String, dynamic>? ?? {};

	  for (final entry in configs.entries) {
		_savedConfigurations[entry.key] = entry.value as String;
	  }

	  if (kDebugMode) {
		print('✅ Imported ${_savedConfigurations.length} configurations');
	  }
	  notifyListeners();
	} catch (e) {
	  if (kDebugMode) {
		print('❌ Failed to import configurations: $e');
	  }
	}
  }

  /// Получить отчёт по всем фильтрам
  String getDetailedReport() {
	final buffer = StringBuffer();
	buffer.writeln('═════════════════════════════════════════════');
	buffer.writeln('📊 ADAPTIVE SIGNAL BRAIN - DETAILED REPORT');
	buffer.writeln('═════════════════════════════════════════════\n');

	buffer.writeln(
	  '📈 Overall Statistics:\n'
	  '  Total Signals: ${_brain.totalSignalsRecorded}\n'
	  '  Successful: ${_brain.totalSuccessfulSignals}\n'
	  '  Win Rate: ${_brain.overallWinRate.toStringAsFixed(2)}%\n',
	);

	// Горячие фильтры
	final hot = _brain.getHotFilters();
	if (hot.isNotEmpty) {
	  buffer.writeln('\n✅ HOT FILTERS (Win Rate > 75%):');
	  for (final filter in hot) {
		buffer.writeln('  • ${filter.componentName}');
		buffer.writeln('    Win Rate: ${filter.winRate.toStringAsFixed(1)}%');
		buffer.writeln('    Sharpe: ${filter.sharpeRatio.toStringAsFixed(2)}');
		buffer.writeln('    Sortino: ${filter.sortinoRatio.toStringAsFixed(2)}');
		buffer.writeln('    Weight: ${filter.weight.toStringAsFixed(2)}x');
		buffer.writeln('    Status: ${filter.enabled ? '✅ ENABLED' : '❌ DISABLED'}\n');
	  }
	}

	// Холодные фильтры
	final cold = _brain.getColdFilters();
	if (cold.isNotEmpty) {
	  buffer.writeln('\n❌ COLD FILTERS (Win Rate < 45%):');
	  for (final filter in cold) {
		buffer.writeln('  • ${filter.componentName}');
		buffer.writeln('    Win Rate: ${filter.winRate.toStringAsFixed(1)}%');
		buffer.writeln('    Sharpe: ${filter.sharpeRatio.toStringAsFixed(2)}');
		buffer.writeln('    Status: ${filter.enabled ? '⚠️ SHOULD DISABLE' : '✅ DISABLED'}\n');
	  }
	}

	// Нейтральные фильтры
	final all = _brain.filterMetrics.values.toList();
	final neutral = all
		.where((f) =>
			f.winRate > 45 && f.winRate < 75 && f.signalCount > 0)
		.toList();
	if (neutral.isNotEmpty) {
	  buffer.writeln('\n🟡 NEUTRAL FILTERS (45-75% Win Rate):');
	  for (final filter in neutral) {
		buffer.writeln('  • ${filter.componentName}');
		buffer.writeln('    Win Rate: ${filter.winRate.toStringAsFixed(1)}%');
		buffer.writeln('    Signals: ${filter.signalCount}\n');
	  }
	}

	// Фильтры без данных
	final noData = all.where((f) => f.signalCount == 0).toList();
	if (noData.isNotEmpty) {
	  buffer
		  .writeln('\n➖ FILTERS WITH NO DATA (${noData.length} filters)');
	}

	buffer.writeln('\n═════════════════════════════════════════════');

	return buffer.toString();
  }

  @override
  String toString() {
	return 'FilterManager('
		'enabled: ${getEnabledFilters().length}, '
		'disabled: ${getDisabledFilters().length})';
  }
}
