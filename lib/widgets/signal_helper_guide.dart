/// Помощник для новичков - объясняет каждый сигнал как для начинающего
/// Показывает галочки и простые объяснения

import 'package:flutter/material.dart';

import '../models/filter_performance_models.dart';
import '../models/signal_models.dart';

/// Элемент проверки условия с объяснением
class SignalConditionCheck {
  const SignalConditionCheck({
	required this.label,
	required this.isActive,
	required this.explanation,
	required this.emoji,
	this.importance = SignalImportance.medium,
  });

  final String label;
  final bool isActive;
  final String explanation;
  final String emoji;
  final SignalImportance importance;

  Color get color {
	if (!isActive) return Colors.grey;
	switch (importance) {
	  case SignalImportance.critical:
		return Colors.red;
	  case SignalImportance.high:
		return Colors.orange;
	  case SignalImportance.medium:
		return Colors.blue;
	  case SignalImportance.low:
		return Colors.green;
	}
  }

  String get statusText => isActive ? 'ДА ✓' : 'НЕТ ✗';
}

enum SignalImportance { critical, high, medium, low }

/// Помощник сигнала - объясняет новичку что происходит
class SignalHelperGuide extends StatefulWidget {
  const SignalHelperGuide({
	super.key,
	required this.signal,
	required this.conditions,
	required this.overallConfidence,
  });

  final RadarSignal signal;
  final List<SignalConditionCheck> conditions;
  final double overallConfidence;

  @override
  State<SignalHelperGuide> createState() => _SignalHelperGuideState();
}

class _SignalHelperGuideState extends State<SignalHelperGuide> {
  late bool _isExpanded;

  @override
  void initState() {
	super.initState();
	_isExpanded = false;
  }

  @override
  Widget build(BuildContext context) {
	final activeConditions =
		widget.conditions.where((c) => c.isActive).toList();
	final confidence = widget.overallConfidence
		.toStringAsFixed(0); // 87% confidence
	final entryPrice =
		((widget.signal.entryLow + widget.signal.entryHigh) / 2)
			.toStringAsFixed(2);
	final risk = (widget.signal.entryPrice - widget.signal.stop)
		.abs()
		.toStringAsFixed(2);
	final reward = (widget.signal.tp1 - widget.signal.entryPrice)
		.abs()
		.toStringAsFixed(2);
	final rRatio = (double.parse(reward) / double.parse(risk))
		.toStringAsFixed(1);

	return Card(
	  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
	  elevation: 4,
	  child: Container(
		decoration: BoxDecoration(
		  border: Border(
			left: BorderSide(
			  color: _getConfidenceColor(widget.overallConfidence),
			  width: 6,
			),
		  ),
		  borderRadius: BorderRadius.circular(4),
		),
		child: Column(
		  children: [
			// Заголовок
			InkWell(
			  onTap: () {
				setState(() {
				  _isExpanded = !_isExpanded;
				});
			  },
			  child: Padding(
				padding: const EdgeInsets.all(16),
				child: Row(
				  children: [
					// Иконка помощника
					Container(
					  padding: const EdgeInsets.all(12),
					  decoration: BoxDecoration(
						color: _getConfidenceColor(widget.overallConfidence)
							.withOpacity(0.2),
						borderRadius: BorderRadius.circular(8),
					  ),
					  child: const Text(
						'🧑‍🏫',
						style: TextStyle(fontSize: 24),
					  ),
					),
					const SizedBox(width: 12),

					// Заголовок
					Expanded(
					  child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
						  Text(
							'Помощник сигнала',
							style: Theme.of(context)
								.textTheme
								.titleMedium
								?.copyWith(fontWeight: FontWeight.bold),
						  ),
						  Text(
							'Что здесь происходит и почему входить',
							style: Theme.of(context)
								.textTheme
								.bodySmall
								?.copyWith(color: Colors.grey),
						  ),
						],
					  ),
					),

					// Уверенность
					Container(
					  padding: const EdgeInsets.symmetric(
						horizontal: 12,
						vertical: 6,
					  ),
					  decoration: BoxDecoration(
						color: _getConfidenceColor(widget.overallConfidence)
							.withOpacity(0.2),
						border: Border.all(
						  color: _getConfidenceColor(widget.overallConfidence),
						),
						borderRadius: BorderRadius.circular(12),
					  ),
					  child: Text(
						'$confidence%',
						style: TextStyle(
						  fontWeight: FontWeight.bold,
						  color: _getConfidenceColor(widget.overallConfidence),
						  fontSize: 14,
						),
					  ),
					),

					const SizedBox(width: 8),
					Icon(
					  _isExpanded ? Icons.expand_less : Icons.expand_more,
					),
				  ],
				),
			  ),
			),

			if (_isExpanded) ...[
			  const Divider(height: 1),
			  Padding(
				padding: const EdgeInsets.all(16),
				child: Column(
				  crossAxisAlignment: CrossAxisAlignment.start,
				  children: [
					// Короткое объяснение
					_buildExplanationBox(context),

					const SizedBox(height: 16),

					// Галочки условий
					Text(
					  '✓ Что совпало (${activeConditions.length} из ${widget.conditions.length}):',
					  style: Theme.of(context).textTheme.titleSmall,
					),
					const SizedBox(height: 12),
					..._buildConditions(context),

					const SizedBox(height: 20),

					// Расчёты для входа
					_buildEntryCalculations(
					  context,
					  entryPrice,
					  risk,
					  reward,
					  rRatio,
					),

					const SizedBox(height: 20),

					// Рекомендации новичку
					_buildNewbieAdvice(context),

					const SizedBox(height: 16),

					// Кнопка "Я готов входить"
					SizedBox(
					  width: double.infinity,
					  child: ElevatedButton.icon(
						onPressed: () {
						  _showReadyDialog(context);
						},
						icon: const Icon(Icons.check_circle),
						label: const Text(
						  'Я готов входить!',
						  style: TextStyle(fontSize: 16),
						),
						style: ElevatedButton.styleFrom(
						  backgroundColor: _getConfidenceColor(
							widget.overallConfidence,
						  ),
						  padding: const EdgeInsets.symmetric(vertical: 14),
						),
					  ),
					),
				  ],
				),
			  ),
			],
		  ],
		),
	  ),
	);
  }

  /// Объяснение сигнала простыми словами
  Widget _buildExplanationBox(BuildContext context) {
	String explanation = _getSimpleExplanation();

	return Container(
	  padding: const EdgeInsets.all(12),
	  decoration: BoxDecoration(
		color: Colors.blue.shade50,
		border: Border.all(color: Colors.blue.shade200),
		borderRadius: BorderRadius.circular(8),
	  ),
	  child: Column(
		crossAxisAlignment: CrossAxisAlignment.start,
		children: [
		  Text(
			'Простыми словами:',
			style: Theme.of(context)
				.textTheme
				.bodyMedium
				?.copyWith(fontWeight: FontWeight.bold),
		  ),
		  const SizedBox(height: 8),
		  Text(
			explanation,
			style: Theme.of(context).textTheme.bodySmall?.copyWith(
				  height: 1.6,
				),
		  ),
		],
	  ),
	);
  }

  /// Галочки для каждого условия
  List<Widget> _buildConditions(BuildContext context) {
	return widget.conditions.map((condition) {
	  return Padding(
		padding: const EdgeInsets.only(bottom: 12),
		child: Row(
		  crossAxisAlignment: CrossAxisAlignment.start,
		  children: [
			// Галочка или крест
			Container(
			  width: 32,
			  height: 32,
			  decoration: BoxDecoration(
				color: condition.color.withOpacity(0.2),
				border: Border.all(color: condition.color, width: 2),
				borderRadius: BorderRadius.circular(6),
			  ),
			  child: Center(
				child: Text(
				  condition.emoji,
				  style: const TextStyle(fontSize: 16),
				),
			  ),
			),
			const SizedBox(width: 12),

			// Текст условия и объяснение
			Expanded(
			  child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
				  Row(
					children: [
					  Expanded(
						child: Text(
						  condition.label,
						  style: Theme.of(context)
							  .textTheme
							  .bodyMedium
							  ?.copyWith(
								fontWeight: FontWeight.w600,
								color: condition.isActive
									? Colors.black87
									: Colors.grey,
							  ),
						),
					  ),
					  Container(
						padding: const EdgeInsets.symmetric(
						  horizontal: 8,
						  vertical: 2,
						),
						decoration: BoxDecoration(
						  color: condition.color.withOpacity(0.15),
						  borderRadius: BorderRadius.circular(4),
						),
						child: Text(
						  condition.statusText,
						  style: TextStyle(
							fontSize: 12,
							fontWeight: FontWeight.bold,
							color: condition.color,
						  ),
						),
					  ),
					],
				  ),
				  const SizedBox(height: 4),
				  Text(
					condition.explanation,
					style: Theme.of(context).textTheme.bodySmall?.copyWith(
						  color: Colors.grey.shade600,
						  height: 1.4,
						),
				  ),
				],
			  ),
			),
		  ],
		),
	  );
	}).toList();
  }

  /// Расчёты для входа
  Widget _buildEntryCalculations(
	BuildContext context,
	String entry,
	String risk,
	String reward,
	String ratio,
  ) {
	return Container(
	  padding: const EdgeInsets.all(12),
	  decoration: BoxDecoration(
		color: Colors.green.shade50,
		border: Border.all(color: Colors.green.shade200),
		borderRadius: BorderRadius.circular(8),
	  ),
	  child: Column(
		crossAxisAlignment: CrossAxisAlignment.start,
		children: [
		  Text(
			'📊 Расчёты для входа:',
			style: Theme.of(context)
				.textTheme
				.bodyMedium
				?.copyWith(fontWeight: FontWeight.bold),
		  ),
		  const SizedBox(height: 10),
		  _buildCalculationRow(
			'Цена входа',
			'\$$entry',
			'Вот в эту цену ты входишь в позицию',
			Colors.blue,
		  ),
		  const SizedBox(height: 8),
		  _buildCalculationRow(
			'Риск (где стоп)',
			'-\$$risk',
			'Максимум что потеряешь если ошибся',
			Colors.red,
		  ),
		  const SizedBox(height: 8),
		  _buildCalculationRow(
			'Прибыль (цель)',
			'+\$$reward',
			'Сколько можешь заработать если прав',
			Colors.green,
		  ),
		  const SizedBox(height: 8),
		  _buildCalculationRow(
			'Соотношение',
			'1:$ratio',
			'За каждый доллар риска ты заработаешь $ratio',
			Colors.orange,
		  ),
		],
	  ),
	);
  }

  /// Одна строка расчёта
  Widget _buildCalculationRow(
	String label,
	String value,
	String tooltip,
	Color color,
  ) {
	return Row(
	  children: [
		Container(
		  width: 8,
		  height: 8,
		  decoration: BoxDecoration(
			color: color,
			borderRadius: BorderRadius.circular(2),
		  ),
		),
		const SizedBox(width: 12),
		Expanded(
		  child: Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
			  Text(
				label,
				style: const TextStyle(fontSize: 12, color: Colors.grey),
			  ),
			  Text(
				value,
				style: const TextStyle(
				  fontSize: 14,
				  fontWeight: FontWeight.bold,
				),
			  ),
			],
		  ),
		),
		Expanded(
		  child: Text(
			tooltip,
			style: TextStyle(
			  fontSize: 11,
			  color: Colors.grey.shade600,
			),
			textAlign: TextAlign.right,
		  ),
		),
	  ],
	);
  }

  /// Советы новичку
  Widget _buildNewbieAdvice(BuildContext context) {
	return Container(
	  padding: const EdgeInsets.all(12),
	  decoration: BoxDecoration(
		color: Colors.amber.shade50,
		border: Border.all(color: Colors.amber.shade200),
		borderRadius: BorderRadius.circular(8),
	  ),
	  child: Column(
		crossAxisAlignment: CrossAxisAlignment.start,
		children: [
		  Text(
			'💡 Советы для новичка:',
			style: Theme.of(context)
				.textTheme
				.bodyMedium
				?.copyWith(fontWeight: FontWeight.bold),
		  ),
		  const SizedBox(height: 10),
		  _buildAdviceTip('✓ Всегда ставь стоп-лосс где система говорит'),
		  const SizedBox(height: 8),
		  _buildAdviceTip(
			  '✓ Не меняй цели - они рассчитаны математически'),
		  const SizedBox(height: 8),
		  _buildAdviceTip(
			  '✓ Ждите подтверждения цены в зоне входа (±0.2%)'),
		  const SizedBox(height: 8),
		  _buildAdviceTip(
			  '⚠️ Если количество ✓ меньше 3 - подожди лучшего сигнала'),
		],
	  ),
	);
  }

  /// Одна строка совета
  Widget _buildAdviceTip(String text) {
	return Text(
	  text,
	  style: const TextStyle(
		fontSize: 12,
		height: 1.6,
		color: Colors.grey,
	  ),
	);
  }

  /// Получить простое объяснение сигнала
  String _getSimpleExplanation() {
	final direction = widget.signal.direction == SignalDirection.long
		? 'вверх ⬆️'
		: 'вниз ⬇️';
	final components = widget.signal.activeSignalComponents;
	final componentCount = components.length;

	String explanation =
		'Несколько факторов подтвердили, что цена должна пойти $direction. ';

	if (componentCount >= 5) {
	  explanation +=
		  'Сигнал очень сильный - целых $componentCount сигналов совпало! 🔥';
	} else if (componentCount >= 3) {
	  explanation +=
		  'Хороший сигнал - $componentCount ключевых фактора указывают в одну сторону.';
	} else {
	  explanation += 'Сигнал слабоват - подожди ещё условий.';
	}

	return explanation;
  }

  /// Цвет на основе доверия
  Color _getConfidenceColor(double confidence) {
	if (confidence >= 80) return Colors.green;
	if (confidence >= 65) return Colors.lightGreen;
	if (confidence >= 50) return Colors.amber;
	if (confidence >= 35) return Colors.orange;
	return Colors.red;
  }

  /// Диалог "Готов входить"
  void _showReadyDialog(BuildContext context) {
	showDialog(
	  context: context,
	  builder: (context) => AlertDialog(
		title: const Text('✓ Готовишься входить?'),
		content: Column(
		  mainAxisSize: MainAxisSize.min,
		  crossAxisAlignment: CrossAxisAlignment.start,
		  children: [
			const Text('Убедись что:'),
			const SizedBox(height: 12),
			_buildChecklist('Стоп-лосс установлен на месте (снизу/сверху)'),
			_buildChecklist('Размер позиции соответствует твоему риску (1-2%)'),
			_buildChecklist('Ты NOT в режиме "погорячиться"'),
			_buildChecklist('Рынок ПО ПРЕЖНЕМУ в нужной зоне цены'),
			_buildChecklist('Твоё состояние позволяет торговать спокойно'),
		  ],
		),
		actions: [
		  TextButton(
			onPressed: () => Navigator.pop(context),
			child: const Text('Подожди ещё'),
		  ),
		  ElevatedButton(
			onPressed: () {
			  Navigator.pop(context);
			  ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
				  content: Text(
					'🎯 Давай! Вход на ${widget.signal.entryPrice}. '
					'Удачи! Помни про стоп! 🍀',
				  ),
				  duration: Duration(seconds: 5),
				),
			  );
			},
			style: ElevatedButton.styleFrom(
			  backgroundColor: Colors.green,
			),
			child: const Text('Я готов! Входу!'),
		  ),
		],
	  ),
	);
  }

  /// Элемент чек-листа
  Widget _buildChecklist(String text) {
	return Padding(
	  padding: const EdgeInsets.only(bottom: 8),
	  child: Row(
		crossAxisAlignment: CrossAxisAlignment.start,
		children: [
		  const Padding(
			padding: EdgeInsets.only(top: 2),
			child: Text('☑️', style: TextStyle(fontSize: 14)),
		  ),
		  const SizedBox(width: 8),
		  Expanded(
			child: Text(
			  text,
			  style: const TextStyle(fontSize: 12),
			),
		  ),
		],
	  ),
	);
  }
}

/// Factory для создания условий из сигнала
class SignalConditionFactory {
  static List<SignalConditionCheck> createFromSignal(RadarSignal signal) {
	final conditions = <SignalConditionCheck>[];

	// 1. Price Action
	if (signal.activeSignalComponents.contains(SignalComponent.priceActionPattern)) {
	  conditions.add(
		SignalConditionCheck(
		  label: '🕯️ Price Action (Паттерн свечей)',
		  isActive: true,
		  emoji: '✓',
		  explanation:
			  'Свеча сформировала хороший паттерн (pin bar, engulfing и т.д.) '
			  '- это показывает, что продавцы/покупатели не в состоянии давить дальше.',
		  importance: SignalImportance.critical,
		),
	  );
	}

	// 2. Fibonacci
	if (signal.activeSignalComponents
		.contains(SignalComponent.fibonacci38Level)) {
	  conditions.add(
		SignalConditionCheck(
		  label: '⚖️ Fibonacci 38.2%',
		  isActive: true,
		  emoji: '✓',
		  explanation:
			  'Цена откатилась на золотой уровень Фибоначчи - это место '
			  'где часто происходит отскок. Вероятность на нашей стороне.',
		  importance: SignalImportance.high,
		),
	  );
	}

	// 3. Volume
	if (signal.activeSignalComponents.contains(SignalComponent.volumeSpike)) {
	  conditions.add(
		SignalConditionCheck(
		  label: '📊 Объём спайк',
		  isActive: true,
		  emoji: '✓',
		  explanation:
			  'Объём торговли резко возрос - это значит, что за сигнал стоит '
			  'РЕАЛЬНЫЕ деньги трейдеров. Не шум, а материал.',
		  importance: SignalImportance.high,
		),
	  );
	}

	// 4. RSI
	if (signal.activeSignalComponents.contains(SignalComponent.rsiOversold)) {
	  conditions.add(
		SignalConditionCheck(
		  label: '🔴 RSI Oversold',
		  isActive: true,
		  emoji: '✓',
		  explanation:
			  'Индикатор RSI показывает что рынок "перепродан" - значит '
			  'вероятнее всего будет отскок вверх. Люди паникуют - это хорошо для нас!',
		  importance: SignalImportance.medium,
		),
	  );
	}

	// 5. Trend
	if (signal.activeSignalComponents.contains(SignalComponent.trendAbove200ma)) {
	  conditions.add(
		SignalConditionCheck(
		  label: '📈 Тренд выше 200MA',
		  isActive: true,
		  emoji: '✓',
		  explanation:
			  'Цена ВЫШЕ долгосрочной скользящей средней - глобальный тренд '
			  'нашей стороны. Вероятность победы выше.',
		  importance: SignalImportance.medium,
		),
	  );
	}

	// Добавить "неактивные" условия для примера
	if (signal.activeSignalComponents.length < 4) {
	  if (!signal.activeSignalComponents
		  .contains(SignalComponent.priceActionPattern)) {
		conditions.add(
		  SignalConditionCheck(
			label: '🕯️ Price Action (Паттерн свечей)',
			isActive: false,
			emoji: '✗',
			explanation:
				'Свеча не образовала чёткий паттерн - немного слабовато для входа.',
			importance: SignalImportance.critical,
		  ),
		);
	  }
	}

	return conditions;
  }
}
