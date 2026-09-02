/// Модели для аудита и логирования каждого сигнала
/// и его результатов

import 'filter_performance_models.dart';

/// Результат сделки по сигналу
enum TradeResult {
  success,      // Цена пошла в нужную сторону на 0.4%+
  partial,      // Частичный успех (дошла до 80% цели)
  stopped,      // Стоп-лосс сработал
  cancelled,    // Сигнал отменён
  pending,      // Ещё не закрыта
}

/// Полный лог одного сигнала и его результата
class SignalAuditEntry {
  SignalAuditEntry({
	required this.id,
	required this.symbol,
	required this.direction,
	required this.timestamp,
	required this.activeComponents,
	this.entryPrice = 0.0,
	this.stopLoss = 0.0,
	this.targetPrice = 0.0,
	this.confidence = 0.0,
	this.result = TradeResult.pending,
	this.finalPrice = 0.0,
	this.profitPercent = 0.0,
	this.rMultiple = 0.0,
	this.closedAt,
	this.notes = '',
  });

  /// Уникальный ID сигнала
  final String id;

  /// Символ (BTCUSDT, ETHUSDT и т.д.)
  final String symbol;

  /// Направление (LONG/SHORT)
  final String direction;

  /// Время когда был сгенерирован сигнал
  final DateTime timestamp;

  /// List компонентов которые сгенерировали этот сигнал
  final List<SignalComponent> activeComponents;

  /// Точка входа
  double entryPrice;

  /// Стоп-лосс
  double stopLoss;

  /// Целевая цена
  double targetPrice;

  /// Уверенность сигнала (%)
  double confidence;

  /// Результат сделки
  TradeResult result;

  /// Финальная цена закрытия
  double finalPrice;

  /// Прибыль/убыток в %
  double profitPercent;

  /// R-multiple (profit / risk)
  double rMultiple;

  /// Время когда сделка была закрыта
  DateTime? closedAt;

  /// Заметки (причина закрытия, обучение и т.д.)
  String notes;

  /// Был ли это успешный сигнал
  bool get isSuccessful => result == TradeResult.success;

  /// Время жизни сигнала в минутах
  int get lifeMinutes {
	if (closedAt == null) {
	  return DateTime.now().difference(timestamp).inMinutes;
	}
	return closedAt!.difference(timestamp).inMinutes;
  }

  /// Сериализация для хранения
  Map<String, dynamic> toJson() {
	return {
	  'id': id,
	  'symbol': symbol,
	  'direction': direction,
	  'timestamp': timestamp.toIso8601String(),
	  'activeComponents': activeComponents.map((c) => c.code).toList(),
	  'entryPrice': entryPrice,
	  'stopLoss': stopLoss,
	  'targetPrice': targetPrice,
	  'confidence': confidence,
	  'result': result.toString(),
	  'finalPrice': finalPrice,
	  'profitPercent': profitPercent,
	  'rMultiple': rMultiple,
	  'closedAt': closedAt?.toIso8601String(),
	  'notes': notes,
	};
  }

  /// Десериализация из JSON
  static SignalAuditEntry fromJson(Map<String, dynamic> json) {
	// Маппируем коды компонентов обратно в enum
	final List<SignalComponent> components = (json['activeComponents'] as List?)
		?.map((code) {
		  try {
			return SignalComponent.values.firstWhere((c) => c.code == code);
		  } catch (_) {
			return null;
		  }
		})
		.whereType<SignalComponent>()
		.toList() ??
		[];

	TradeResult result = TradeResult.pending;
	try {
	  final String resultStr = json['result'] as String? ?? '';
	  if (resultStr.contains('success')) result = TradeResult.success;
	  else if (resultStr.contains('partial')) result = TradeResult.partial;
	  else if (resultStr.contains('stopped')) result = TradeResult.stopped;
	  else if (resultStr.contains('cancelled')) result = TradeResult.cancelled;
	} catch (_) {}

	return SignalAuditEntry(
	  id: json['id'] as String,
	  symbol: json['symbol'] as String,
	  direction: json['direction'] as String,
	  timestamp: DateTime.parse(json['timestamp'] as String),
	  activeComponents: components,
	  entryPrice: (json['entryPrice'] as num?)?.toDouble() ?? 0.0,
	  stopLoss: (json['stopLoss'] as num?)?.toDouble() ?? 0.0,
	  targetPrice: (json['targetPrice'] as num?)?.toDouble() ?? 0.0,
	  confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
	  result: result,
	  finalPrice: (json['finalPrice'] as num?)?.toDouble() ?? 0.0,
	  profitPercent: (json['profitPercent'] as num?)?.toDouble() ?? 0.0,
	  rMultiple: (json['rMultiple'] as num?)?.toDouble() ?? 0.0,
	  closedAt:
		  json['closedAt'] != null ? DateTime.parse(json['closedAt'] as String) : null,
	  notes: json['notes'] as String? ?? '',
	);
  }

  @override
  String toString() {
	return 'SignalAudit('
		'$symbol $direction, '
		'components: ${activeComponents.length}, '
		'result: ${result.toString()}, '
		'profit: ${profitPercent.toStringAsFixed(2)}%)';
  }
}
