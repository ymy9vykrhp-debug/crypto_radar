/// РџРѕРјРѕС‰РЅРёРє РґР»СЏ РЅРѕРІРёС‡РєРѕРІ - РѕР±СЉСЏСЃРЅСЏРµС‚ РєР°Р¶РґС‹Р№ СЃРёРіРЅР°Р» РєР°Рє РґР»СЏ РЅР°С‡РёРЅР°СЋС‰РµРіРѕ
/// РџРѕРєР°Р·С‹РІР°РµС‚ РіР°Р»РѕС‡РєРё Рё РїСЂРѕСЃС‚С‹Рµ РѕР±СЉСЏСЃРЅРµРЅРёСЏ

import 'package:flutter/material.dart';

import '../models/filter_performance_models.dart';
import '../models/signal_models.dart';

/// Р­Р»РµРјРµРЅС‚ РїСЂРѕРІРµСЂРєРё СѓСЃР»РѕРІРёСЏ СЃ РѕР±СЉСЏСЃРЅРµРЅРёРµРј
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

  String get statusText => isActive ? 'Р”Рђ вњ“' : 'РќР•Рў вњ—';
}

enum SignalImportance { critical, high, medium, low }

/// РџРѕРјРѕС‰РЅРёРє СЃРёРіРЅР°Р»Р° - РѕР±СЉСЏСЃРЅСЏРµС‚ РЅРѕРІРёС‡РєСѓ С‡С‚Рѕ РїСЂРѕРёСЃС…РѕРґРёС‚
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
			// Р—Р°РіРѕР»РѕРІРѕРє
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
					// РРєРѕРЅРєР° РїРѕРјРѕС‰РЅРёРєР°
					Container(
					  padding: const EdgeInsets.all(12),
					  decoration: BoxDecoration(
						color: _getConfidenceColor(widget.overallConfidence)
							.withOpacity(0.2),
						borderRadius: BorderRadius.circular(8),
					  ),
					  child: const Text(
						'рџ§‘вЂЌрџЏ«',
						style: TextStyle(fontSize: 24),
					  ),
					),
					const SizedBox(width: 12),

					// Р—Р°РіРѕР»РѕРІРѕРє
					Expanded(
					  child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
						  Text(
							'РџРѕРјРѕС‰РЅРёРє СЃРёРіРЅР°Р»Р°',
							style: Theme.of(context)
								.textTheme
								.titleMedium
								?.copyWith(fontWeight: FontWeight.bold),
						  ),
						  Text(
							'Р§С‚Рѕ Р·РґРµСЃСЊ РїСЂРѕРёСЃС…РѕРґРёС‚ Рё РїРѕС‡РµРјСѓ РІС…РѕРґРёС‚СЊ',
							style: Theme.of(context)
								.textTheme
								.bodySmall
								?.copyWith(color: Colors.grey),
						  ),
						],
					  ),
					),

					// РЈРІРµСЂРµРЅРЅРѕСЃС‚СЊ
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
					// РљРѕСЂРѕС‚РєРѕРµ РѕР±СЉСЏСЃРЅРµРЅРёРµ
					_buildExplanationBox(context),

					const SizedBox(height: 16),

					// Р“Р°Р»РѕС‡РєРё СѓСЃР»РѕРІРёР№
					Text(
					  'вњ“ Р§С‚Рѕ СЃРѕРІРїР°Р»Рѕ (${activeConditions.length} РёР· ${widget.conditions.length}):',
					  style: Theme.of(context).textTheme.titleSmall,
					),
					const SizedBox(height: 12),
					..._buildConditions(context),

					const SizedBox(height: 20),

					// Р Р°СЃС‡С‘С‚С‹ РґР»СЏ РІС…РѕРґР°
					_buildEntryCalculations(
					  context,
					  entryPrice,
					  risk,
					  reward,
					  rRatio,
					),

					const SizedBox(height: 20),

					// Р РµРєРѕРјРµРЅРґР°С†РёРё РЅРѕРІРёС‡РєСѓ
					_buildNewbieAdvice(context),

					const SizedBox(height: 16),

					// РљРЅРѕРїРєР° "РЇ РіРѕС‚РѕРІ РІС…РѕРґРёС‚СЊ"
					SizedBox(
					  width: double.infinity,
					  child: ElevatedButton.icon(
						onPressed: () {
						  _showReadyDialog(context);
						},
						icon: const Icon(Icons.check_circle),
						label: const Text(
						  'РЇ РіРѕС‚РѕРІ РІС…РѕРґРёС‚СЊ!',
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

  /// РћР±СЉСЏСЃРЅРµРЅРёРµ СЃРёРіРЅР°Р»Р° РїСЂРѕСЃС‚С‹РјРё СЃР»РѕРІР°РјРё
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
			'РџСЂРѕСЃС‚С‹РјРё СЃР»РѕРІР°РјРё:',
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

  /// Р“Р°Р»РѕС‡РєРё РґР»СЏ РєР°Р¶РґРѕРіРѕ СѓСЃР»РѕРІРёСЏ
  List<Widget> _buildConditions(BuildContext context) {
	return widget.conditions.map((condition) {
	  return Padding(
		padding: const EdgeInsets.only(bottom: 12),
		child: Row(
		  crossAxisAlignment: CrossAxisAlignment.start,
		  children: [
			// Р“Р°Р»РѕС‡РєР° РёР»Рё РєСЂРµСЃС‚
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

			// РўРµРєСЃС‚ СѓСЃР»РѕРІРёСЏ Рё РѕР±СЉСЏСЃРЅРµРЅРёРµ
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

  /// Р Р°СЃС‡С‘С‚С‹ РґР»СЏ РІС…РѕРґР°
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
			'рџ“Љ Р Р°СЃС‡С‘С‚С‹ РґР»СЏ РІС…РѕРґР°:',
			style: Theme.of(context)
				.textTheme
				.bodyMedium
				?.copyWith(fontWeight: FontWeight.bold),
		  ),
		  const SizedBox(height: 10),
		  _buildCalculationRow(
			'Р¦РµРЅР° РІС…РѕРґР°',
			'\$$entry',
			'Р’РѕС‚ РІ СЌС‚Сѓ С†РµРЅСѓ С‚С‹ РІС…РѕРґРёС€СЊ РІ РїРѕР·РёС†РёСЋ',
			Colors.blue,
		  ),
		  const SizedBox(height: 8),
		  _buildCalculationRow(
			'Р РёСЃРє (РіРґРµ СЃС‚РѕРї)',
			'-\$$risk',
			'РњР°РєСЃРёРјСѓРј С‡С‚Рѕ РїРѕС‚РµСЂСЏРµС€СЊ РµСЃР»Рё РѕС€РёР±СЃСЏ',
			Colors.red,
		  ),
		  const SizedBox(height: 8),
		  _buildCalculationRow(
			'РџСЂРёР±С‹Р»СЊ (С†РµР»СЊ)',
			'+\$$reward',
			'РЎРєРѕР»СЊРєРѕ РјРѕР¶РµС€СЊ Р·Р°СЂР°Р±РѕС‚Р°С‚СЊ РµСЃР»Рё РїСЂР°РІ',
			Colors.green,
		  ),
		  const SizedBox(height: 8),
		  _buildCalculationRow(
			'РЎРѕРѕС‚РЅРѕС€РµРЅРёРµ',
			'1:$ratio',
			'Р—Р° РєР°Р¶РґС‹Р№ РґРѕР»Р»Р°СЂ СЂРёСЃРєР° С‚С‹ Р·Р°СЂР°Р±РѕС‚Р°РµС€СЊ $ratio',
			Colors.orange,
		  ),
		],
	  ),
	);
  }

  /// РћРґРЅР° СЃС‚СЂРѕРєР° СЂР°СЃС‡С‘С‚Р°
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

  /// РЎРѕРІРµС‚С‹ РЅРѕРІРёС‡РєСѓ
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
			'рџ’Ў РЎРѕРІРµС‚С‹ РґР»СЏ РЅРѕРІРёС‡РєР°:',
			style: Theme.of(context)
				.textTheme
				.bodyMedium
				?.copyWith(fontWeight: FontWeight.bold),
		  ),
		  const SizedBox(height: 10),
		  _buildAdviceTip('вњ“ Р’СЃРµРіРґР° СЃС‚Р°РІСЊ СЃС‚РѕРї-Р»РѕСЃСЃ РіРґРµ СЃРёСЃС‚РµРјР° РіРѕРІРѕСЂРёС‚'),
		  const SizedBox(height: 8),
		  _buildAdviceTip(
			  'вњ“ РќРµ РјРµРЅСЏР№ С†РµР»Рё - РѕРЅРё СЂР°СЃСЃС‡РёС‚Р°РЅС‹ РјР°С‚РµРјР°С‚РёС‡РµСЃРєРё'),
		  const SizedBox(height: 8),
		  _buildAdviceTip(
			  'вњ“ Р–РґРёС‚Рµ РїРѕРґС‚РІРµСЂР¶РґРµРЅРёСЏ С†РµРЅС‹ РІ Р·РѕРЅРµ РІС…РѕРґР° (В±0.2%)'),
		  const SizedBox(height: 8),
		  _buildAdviceTip(
			  'вљ пёЏ Р•СЃР»Рё РєРѕР»РёС‡РµСЃС‚РІРѕ вњ“ РјРµРЅСЊС€Рµ 3 - РїРѕРґРѕР¶РґРё Р»СѓС‡С€РµРіРѕ СЃРёРіРЅР°Р»Р°'),
		],
	  ),
	);
  }

  /// РћРґРЅР° СЃС‚СЂРѕРєР° СЃРѕРІРµС‚Р°
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

  /// РџРѕР»СѓС‡РёС‚СЊ РїСЂРѕСЃС‚РѕРµ РѕР±СЉСЏСЃРЅРµРЅРёРµ СЃРёРіРЅР°Р»Р°
  String _getSimpleExplanation() {
	final direction = widget.signal.direction == SignalDirection.long
		? 'РІРІРµСЂС… в¬†пёЏ'
		: 'РІРЅРёР· в¬‡пёЏ';
	final components = widget.signal.activeSignalComponents;
	final componentCount = components.length;

	String explanation =
		'РќРµСЃРєРѕР»СЊРєРѕ С„Р°РєС‚РѕСЂРѕРІ РїРѕРґС‚РІРµСЂРґРёР»Рё, С‡С‚Рѕ С†РµРЅР° РґРѕР»Р¶РЅР° РїРѕР№С‚Рё $direction. ';

	if (componentCount >= 5) {
	  explanation +=
		  'РЎРёРіРЅР°Р» РѕС‡РµРЅСЊ СЃРёР»СЊРЅС‹Р№ - С†РµР»С‹С… $componentCount СЃРёРіРЅР°Р»РѕРІ СЃРѕРІРїР°Р»Рѕ! рџ”Ґ';
	} else if (componentCount >= 3) {
	  explanation +=
		  'РҐРѕСЂРѕС€РёР№ СЃРёРіРЅР°Р» - $componentCount РєР»СЋС‡РµРІС‹С… С„Р°РєС‚РѕСЂР° СѓРєР°Р·С‹РІР°СЋС‚ РІ РѕРґРЅСѓ СЃС‚РѕСЂРѕРЅСѓ.';
	} else {
	  explanation += 'РЎРёРіРЅР°Р» СЃР»Р°Р±РѕРІР°С‚ - РїРѕРґРѕР¶РґРё РµС‰С‘ СѓСЃР»РѕРІРёР№.';
	}

	return explanation;
  }

  /// Р¦РІРµС‚ РЅР° РѕСЃРЅРѕРІРµ РґРѕРІРµСЂРёСЏ
  Color _getConfidenceColor(double confidence) {
	if (confidence >= 80) return Colors.green;
	if (confidence >= 65) return Colors.lightGreen;
	if (confidence >= 50) return Colors.amber;
	if (confidence >= 35) return Colors.orange;
	return Colors.red;
  }

  /// Р”РёР°Р»РѕРі "Р“РѕС‚РѕРІ РІС…РѕРґРёС‚СЊ"
  void _showReadyDialog(BuildContext context) {
	showDialog(
	  context: context,
	  builder: (context) => AlertDialog(
		title: const Text('вњ“ Р“РѕС‚РѕРІРёС€СЊСЃСЏ РІС…РѕРґРёС‚СЊ?'),
		content: Column(
		  mainAxisSize: MainAxisSize.min,
		  crossAxisAlignment: CrossAxisAlignment.start,
		  children: [
			const Text('РЈР±РµРґРёСЃСЊ С‡С‚Рѕ:'),
			const SizedBox(height: 12),
			_buildChecklist('РЎС‚РѕРї-Р»РѕСЃСЃ СѓСЃС‚Р°РЅРѕРІР»РµРЅ РЅР° РјРµСЃС‚Рµ (СЃРЅРёР·Сѓ/СЃРІРµСЂС…Сѓ)'),
			_buildChecklist('Р Р°Р·РјРµСЂ РїРѕР·РёС†РёРё СЃРѕРѕС‚РІРµС‚СЃС‚РІСѓРµС‚ С‚РІРѕРµРјСѓ СЂРёСЃРєСѓ (1-2%)'),
			_buildChecklist('РўС‹ NOT РІ СЂРµР¶РёРјРµ "РїРѕРіРѕСЂСЏС‡РёС‚СЊСЃСЏ"'),
			_buildChecklist('Р С‹РЅРѕРє РџРћ РџР Р•Р–РќР•РњРЈ РІ РЅСѓР¶РЅРѕР№ Р·РѕРЅРµ С†РµРЅС‹'),
			_buildChecklist('РўРІРѕС‘ СЃРѕСЃС‚РѕСЏРЅРёРµ РїРѕР·РІРѕР»СЏРµС‚ С‚РѕСЂРіРѕРІР°С‚СЊ СЃРїРѕРєРѕР№РЅРѕ'),
		  ],
		),
		actions: [
		  TextButton(
			onPressed: () => Navigator.pop(context),
			child: const Text('РџРѕРґРѕР¶РґРё РµС‰С‘'),
		  ),
		  ElevatedButton(
			onPressed: () {
			  Navigator.pop(context);
			  ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
				  content: Text(
					'рџЋЇ Р”Р°РІР°Р№! Р’С…РѕРґ РЅР° ${widget.signal.entryPrice}. '
					'РЈРґР°С‡Рё! РџРѕРјРЅРё РїСЂРѕ СЃС‚РѕРї! рџЌЂ',
				  ),
				  duration: Duration(seconds: 5),
				),
			  );
			},
			style: ElevatedButton.styleFrom(
			  backgroundColor: Colors.green,
			),
			child: const Text('РЇ РіРѕС‚РѕРІ! Р’С…РѕРґСѓ!'),
		  ),
		],
	  ),
	);
  }

  /// Р­Р»РµРјРµРЅС‚ С‡РµРє-Р»РёСЃС‚Р°
  Widget _buildChecklist(String text) {
	return Padding(
	  padding: const EdgeInsets.only(bottom: 8),
	  child: Row(
		crossAxisAlignment: CrossAxisAlignment.start,
		children: [
		  const Padding(
			padding: EdgeInsets.only(top: 2),
			child: Text('в‘пёЏ', style: TextStyle(fontSize: 14)),
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

/// Factory РґР»СЏ СЃРѕР·РґР°РЅРёСЏ СѓСЃР»РѕРІРёР№ РёР· СЃРёРіРЅР°Р»Р°
class SignalConditionFactory {
  static List<SignalConditionCheck> createFromSignal(RadarSignal signal) {
	final conditions = <SignalConditionCheck>[];

	// 1. Price Action
	if (signal.activeSignalComponents.contains(SignalComponent.priceActionPattern)) {
	  conditions.add(
		SignalConditionCheck(
		  label: 'рџ•ЇпёЏ Price Action (РџР°С‚С‚РµСЂРЅ СЃРІРµС‡РµР№)',
		  isActive: true,
		  emoji: 'вњ“',
		  explanation:
			  'РЎРІРµС‡Р° СЃС„РѕСЂРјРёСЂРѕРІР°Р»Р° С…РѕСЂРѕС€РёР№ РїР°С‚С‚РµСЂРЅ (pin bar, engulfing Рё С‚.Рґ.) '
			  '- СЌС‚Рѕ РїРѕРєР°Р·С‹РІР°РµС‚, С‡С‚Рѕ РїСЂРѕРґР°РІС†С‹/РїРѕРєСѓРїР°С‚РµР»Рё РЅРµ РІ СЃРѕСЃС‚РѕСЏРЅРёРё РґР°РІРёС‚СЊ РґР°Р»СЊС€Рµ.',
		  importance: SignalImportance.critical,
		),
	  );
	}

	// 2. Fibonacci
	if (signal.activeSignalComponents
		.contains(SignalComponent.fibonacci38Level)) {
	  conditions.add(
		SignalConditionCheck(
		  label: 'вљ–пёЏ Fibonacci 38.2%',
		  isActive: true,
		  emoji: 'вњ“',
		  explanation:
			  'Р¦РµРЅР° РѕС‚РєР°С‚РёР»Р°СЃСЊ РЅР° Р·РѕР»РѕС‚РѕР№ СѓСЂРѕРІРµРЅСЊ Р¤РёР±РѕРЅР°С‡С‡Рё - СЌС‚Рѕ РјРµСЃС‚Рѕ '
			  'РіРґРµ С‡Р°СЃС‚Рѕ РїСЂРѕРёСЃС…РѕРґРёС‚ РѕС‚СЃРєРѕРє. Р’РµСЂРѕСЏС‚РЅРѕСЃС‚СЊ РЅР° РЅР°С€РµР№ СЃС‚РѕСЂРѕРЅРµ.',
		  importance: SignalImportance.high,
		),
	  );
	}

	// 3. Volume
	if (signal.activeSignalComponents.contains(SignalComponent.volumeSpike)) {
	  conditions.add(
		SignalConditionCheck(
		  label: 'рџ“Љ РћР±СЉС‘Рј СЃРїР°Р№Рє',
		  isActive: true,
		  emoji: 'вњ“',
		  explanation:
			  'РћР±СЉС‘Рј С‚РѕСЂРіРѕРІР»Рё СЂРµР·РєРѕ РІРѕР·СЂРѕСЃ - СЌС‚Рѕ Р·РЅР°С‡РёС‚, С‡С‚Рѕ Р·Р° СЃРёРіРЅР°Р» СЃС‚РѕРёС‚ '
			  'Р Р•РђР›Р¬РќР«Р• РґРµРЅСЊРіРё С‚СЂРµР№РґРµСЂРѕРІ. РќРµ С€СѓРј, Р° РјР°С‚РµСЂРёР°Р».',
		  importance: SignalImportance.high,
		),
	  );
	}

	// 4. RSI
	if (signal.activeSignalComponents.contains(SignalComponent.rsiOversold)) {
	  conditions.add(
		SignalConditionCheck(
		  label: 'рџ”ґ RSI Oversold',
		  isActive: true,
		  emoji: 'вњ“',
		  explanation:
			  'РРЅРґРёРєР°С‚РѕСЂ RSI РїРѕРєР°Р·С‹РІР°РµС‚ С‡С‚Рѕ СЂС‹РЅРѕРє "РїРµСЂРµРїСЂРѕРґР°РЅ" - Р·РЅР°С‡РёС‚ '
			  'РІРµСЂРѕСЏС‚РЅРµРµ РІСЃРµРіРѕ Р±СѓРґРµС‚ РѕС‚СЃРєРѕРє РІРІРµСЂС…. Р›СЋРґРё РїР°РЅРёРєСѓСЋС‚ - СЌС‚Рѕ С…РѕСЂРѕС€Рѕ РґР»СЏ РЅР°СЃ!',
		  importance: SignalImportance.medium,
		),
	  );
	}

	// 5. Trend
	if (signal.activeSignalComponents.contains(SignalComponent.trendAbove200ma)) {
	  conditions.add(
		SignalConditionCheck(
		  label: 'рџ“€ РўСЂРµРЅРґ РІС‹С€Рµ 200MA',
		  isActive: true,
		  emoji: 'вњ“',
		  explanation:
			  'Р¦РµРЅР° Р’Р«РЁР• РґРѕР»РіРѕСЃСЂРѕС‡РЅРѕР№ СЃРєРѕР»СЊР·СЏС‰РµР№ СЃСЂРµРґРЅРµР№ - РіР»РѕР±Р°Р»СЊРЅС‹Р№ С‚СЂРµРЅРґ '
			  'РЅР°С€РµР№ СЃС‚РѕСЂРѕРЅС‹. Р’РµСЂРѕСЏС‚РЅРѕСЃС‚СЊ РїРѕР±РµРґС‹ РІС‹С€Рµ.',
		  importance: SignalImportance.medium,
		),
	  );
	}

	// Р”РѕР±Р°РІРёС‚СЊ "РЅРµР°РєС‚РёРІРЅС‹Рµ" СѓСЃР»РѕРІРёСЏ РґР»СЏ РїСЂРёРјРµСЂР°
	if (signal.activeSignalComponents.length < 4) {
	  if (!signal.activeSignalComponents
		  .contains(SignalComponent.priceActionPattern)) {
		conditions.add(
		  SignalConditionCheck(
			label: 'рџ•ЇпёЏ Price Action (РџР°С‚С‚РµСЂРЅ СЃРІРµС‡РµР№)',
			isActive: false,
			emoji: 'вњ—',
			explanation:
				'РЎРІРµС‡Р° РЅРµ РѕР±СЂР°Р·РѕРІР°Р»Р° С‡С‘С‚РєРёР№ РїР°С‚С‚РµСЂРЅ - РЅРµРјРЅРѕРіРѕ СЃР»Р°Р±РѕРІР°С‚Рѕ РґР»СЏ РІС…РѕРґР°.',
			importance: SignalImportance.critical,
		  ),
		);
	  }
	}

	return conditions;
  }
}

