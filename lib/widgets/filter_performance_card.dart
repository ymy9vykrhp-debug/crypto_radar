/// Widget для красивого отображения метрик одного фильтра

import 'package:flutter/material.dart';

import '../models/filter_performance_models.dart';
import '../services/adaptive_filter_manager.dart';

/// Карточка с метриками одного фильтра
class FilterPerformanceCard extends StatelessWidget {
  const FilterPerformanceCard({
	super.key,
	required this.metrics,
	required this.filterManager,
	this.onToggle,
	this.showDetailedMetrics = false,
  });

  final FilterPerformanceMetrics metrics;
  final FilterManager filterManager;
  final VoidCallback? onToggle;
  final bool showDetailedMetrics;

  Color _getHealthColor(FilterHealthStatus status) {
	switch (status) {
	  case FilterHealthStatus.excellent:
		return Colors.green;
	  case FilterHealthStatus.good:
		return Colors.lightGreen;
	  case FilterHealthStatus.acceptable:
		return Colors.amber;
	  case FilterHealthStatus.warning:
		return Colors.orange;
	  case FilterHealthStatus.poor:
		return Colors.red;
	}
  }

  String _getHealthEmoji(FilterHealthStatus status) {
	switch (status) {
	  case FilterHealthStatus.excellent:
		return '✅';
	  case FilterHealthStatus.good:
		return '✅';
	  case FilterHealthStatus.acceptable:
		return '🟡';
	  case FilterHealthStatus.warning:
		return '⚠️';
	  case FilterHealthStatus.poor:
		return '❌';
	}
  }

  @override
  Widget build(BuildContext context) {
	final Color healthColor = _getHealthColor(metrics.healthStatus);
	final String emoji = _getHealthEmoji(metrics.healthStatus);

	return Card(
	  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
	  elevation: 2,
	  child: Container(
		decoration: BoxDecoration(
		  border: Border(
			left: BorderSide(color: healthColor, width: 4),
		  ),
		  borderRadius: BorderRadius.circular(4),
		),
		child: ExpansionTile(
		  title: Row(
			children: [
			  Text(
				'$emoji ${metrics.componentName}',
				style: Theme.of(context).textTheme.bodyLarge?.copyWith(
					  fontWeight: FontWeight.bold,
					),
			  ),
			  const SizedBox(width: 12),
			  Container(
				padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
				decoration: BoxDecoration(
				  color: healthColor.withOpacity(0.2),
				  border: Border.all(color: healthColor),
				  borderRadius: BorderRadius.circular(12),
				),
				child: Text(
				  '${metrics.winRate.toStringAsFixed(1)}%',
				  style: TextStyle(
					fontSize: 12,
					fontWeight: FontWeight.bold,
					color: healthColor,
				  ),
				),
			  ),
			],
		  ),
		  subtitle: Text(
			'Signals: ${metrics.signalCount} | R: ${metrics.averageR.toStringAsFixed(2)} | Weight: ${metrics.weight.toStringAsFixed(2)}x',
			style: Theme.of(context).textTheme.bodySmall,
		  ),
		  trailing: GestureDetector(
			onTap: onToggle,
			child: Container(
			  padding: const EdgeInsets.all(8),
			  decoration: BoxDecoration(
				color: metrics.enabled ? Colors.green : Colors.grey,
				borderRadius: BorderRadius.circular(20),
			  ),
			  child: Text(
				metrics.enabled ? '✓' : '✕',
				style: const TextStyle(
				  color: Colors.white,
				  fontWeight: FontWeight.bold,
				),
			  ),
			),
		  ),
		  children: [
			Padding(
			  padding: const EdgeInsets.all(16),
			  child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
				  // Basic metrics
				  _buildMetricRow(
					context,
					'Signals / Success',
					'${metrics.signalCount} / ${metrics.successCount}',
				  ),
				  _buildMetricRow(
					context,
					'Win Rate',
					'${metrics.winRate.toStringAsFixed(2)}%',
					highlight: true,
				  ),
				  _buildMetricRow(
					context,
					'Average Profit',
					'${metrics.averageProfit.toStringAsFixed(3)}%',
				  ),
				  _buildMetricRow(
					context,
					'Average R',
					metrics.averageR.toStringAsFixed(2),
				  ),

				  if (showDetailedMetrics) ...[
					const Divider(),
					Text(
					  'Advanced Metrics',
					  style: Theme.of(context).textTheme.labelLarge,
					),
					const SizedBox(height: 8),
					_buildMetricRow(
					  context,
					  'Sharpe Ratio',
					  metrics.sharpeRatio.toStringAsFixed(2),
					),
					_buildMetricRow(
					  context,
					  'Sortino Ratio',
					  metrics.sortinoRatio.toStringAsFixed(2),
					),
					_buildMetricRow(
					  context,
					  'Max Drawdown',
					  '-${metrics.maxDrawdown.toStringAsFixed(2)}%',
					),
					_buildMetricRow(
					  context,
					  'Profit Factor',
					  metrics.profitFactor.toStringAsFixed(2),
					),
					_buildMetricRow(
					  context,
					  'Current Weight',
					  '${metrics.weight.toStringAsFixed(2)}x',
					  highlight: true,
					),
				  ],

				  const SizedBox(height: 12),
				  // Recommendation
				  if (metrics.signalCount >= 10) ...[
					Container(
					  padding: const EdgeInsets.all(12),
					  decoration: BoxDecoration(
						color: healthColor.withOpacity(0.1),
						border: Border.all(color: healthColor, width: 1),
						borderRadius: BorderRadius.circular(8),
					  ),
					  child: Row(
						children: [
						  Text(
							emoji,
							style: const TextStyle(fontSize: 20),
						  ),
						  const SizedBox(width: 8),
						  Expanded(
							child: Text(
							  filterManager.getRecommendationForFilter(
									metrics.componentName,
								  ) ??
								  'Monitor this filter',
							  style: Theme.of(context)
								  .textTheme
								  .bodySmall
								  ?.copyWith(
									fontWeight: FontWeight.w500,
									color: healthColor,
								  ),
							),
						  ),
						],
					  ),
					),
				  ],

				  // Toggle button
				  const SizedBox(height: 12),
				  SizedBox(
					width: double.infinity,
					child: ElevatedButton.icon(
					  onPressed: onToggle,
					  icon: Icon(
						metrics.enabled
							? Icons.toggle_on
							: Icons.toggle_off,
					  ),
					  label: Text(
						metrics.enabled ? 'Disable' : 'Enable',
					  ),
					  style: ElevatedButton.styleFrom(
						backgroundColor: metrics.enabled
							? Colors.red.shade300
							: Colors.green.shade300,
					  ),
					),
				  ),
				],
			  ),
			),
		  ],
		),
	  ),
	);
  }

  Widget _buildMetricRow(
	BuildContext context,
	String label,
	String value, {
	bool highlight = false,
  }) {
	return Padding(
	  padding: const EdgeInsets.symmetric(vertical: 4),
	  child: Row(
		mainAxisAlignment: MainAxisAlignment.spaceBetween,
		children: [
		  Text(
			label,
			style: Theme.of(context).textTheme.bodySmall?.copyWith(
				  fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
				),
		  ),
		  Text(
			value,
			style: Theme.of(context).textTheme.bodySmall?.copyWith(
				  fontWeight: FontWeight.bold,
				  color: highlight ? Colors.blue : null,
				),
		  ),
		],
	  ),
	);
  }
}
