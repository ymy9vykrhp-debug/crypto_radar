/// Аналитический экран для просмотра и управления адаптивной системой
/// Показывает статистику по каждому фильтру и позволяет оптимизировать систему

import 'package:flutter/material.dart';

import '../engines/adaptive_signal_brain.dart';
import '../localization/app_strings.dart';
import '../models/filter_performance_models.dart';
import '../services/adaptive_filter_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/filter_performance_card.dart';
import '../widgets/product_components.dart';

class AdaptiveSystemAnalyticsScreen extends StatefulWidget {
  const AdaptiveSystemAnalyticsScreen({
	super.key,
	required this.brain,
	required this.filterManager,
  });

  final AdaptiveSignalBrain brain;
  final FilterManager filterManager;

  @override
  State<AdaptiveSystemAnalyticsScreen> createState() =>
	  _AdaptiveSystemAnalyticsScreenState();
}

class _AdaptiveSystemAnalyticsScreenState
	extends State<AdaptiveSystemAnalyticsScreen> {
  late TabController _tabController;

  @override
  void initState() {
	super.initState();
	_tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
	_tabController.dispose();
	super.dispose();
  }

  @override
  Widget build(BuildContext context) {
	final strings = context.strings;
	return Scaffold(
	  appBar: AppBar(
		title: const Text('🧠 Adaptive Brain Analytics'),
		bottom: TabBar(
		  controller: _tabController,
		  tabs: const [
			Tab(text: 'Overview'),
			Tab(text: 'Filters'),
			Tab(text: 'Recommendations'),
			Tab(text: 'Settings'),
		  ],
		),
	  ),
	  body: TabBarView(
		controller: _tabController,
		children: [
		  _buildOverviewTab(),
		  _buildFiltersTab(),
		  _buildRecommendationsTab(),
		  _buildSettingsTab(),
		],
	  ),
	);
  }

  /// TAB 1: Overview - общая статистика
  Widget _buildOverviewTab() {
	return AnimatedBuilder(
	  animation: widget.brain,
	  builder: (context, _) {
		return ListView(
		  padding: const EdgeInsets.all(16),
		  children: [
			// Header с общей статистикой
			Card(
			  elevation: 4,
			  child: Padding(
				padding: const EdgeInsets.all(16),
				child: Column(
				  crossAxisAlignment: CrossAxisAlignment.start,
				  children: [
					Text(
					  '📊 System Overview',
					  style: Theme.of(context).textTheme.titleLarge,
					),
					const SizedBox(height: 16),
					_buildStatTile(
					  'Total Signals',
					  widget.brain.totalSignalsRecorded.toString(),
					  Colors.blue,
					),
					const SizedBox(height: 12),
					_buildStatTile(
					  'Successful Trades',
					  widget.brain.totalSuccessfulSignals.toString(),
					  Colors.green,
					),
					const SizedBox(height: 12),
					_buildStatTile(
					  'Overall Win Rate',
					  '${widget.brain.overallWinRate.toStringAsFixed(2)}%',
					  Colors.orange,
					),
					const SizedBox(height: 12),
					_buildStatTile(
					  'Active Filters',
					  widget.filterManager.getEnabledFilters().length.toString(),
					  Colors.purple,
					),
				  ],
				),
			  ),
			),
			const SizedBox(height: 16),

			// Лучшие фильтры (Hot)
			if (widget.brain.getHotFilters().isNotEmpty)
			  Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
				  Padding(
					padding: const EdgeInsets.symmetric(vertical: 8),
					child: Text(
					  '✅ Top Performing Filters',
					  style: Theme.of(context).textTheme.titleMedium,
					),
				  ),
				  ...widget.brain
					  .getHotFilters()
					  .take(3)
					  .map(
						(metrics) => Padding(
						  padding: const EdgeInsets.only(bottom: 8),
						  child: Container(
							padding: const EdgeInsets.all(12),
							decoration: BoxDecoration(
							  color: Colors.green.withOpacity(0.1),
							  border: Border.all(
								color: Colors.green,
								width: 1,
							  ),
							  borderRadius: BorderRadius.circular(8),
							),
							child: Row(
							  mainAxisAlignment:
								  MainAxisAlignment.spaceBetween,
							  children: [
								Expanded(
								  child: Column(
									crossAxisAlignment:
										CrossAxisAlignment.start,
									children: [
									  Text(
										metrics.componentName,
										style: Theme.of(context)
											.textTheme
											.bodyLarge
											?.copyWith(
											  fontWeight: FontWeight.bold,
											),
									  ),
									  Text(
										'${metrics.winRate.toStringAsFixed(1)}% | ${metrics.averageR.toStringAsFixed(2)}R',
										style: Theme.of(context)
											.textTheme
											.bodySmall,
									  ),
									],
								  ),
								),
								Chip(
								  label: Text(
									'${metrics.weight.toStringAsFixed(2)}x',
									style:
										const TextStyle(color: Colors.white),
								  ),
								  backgroundColor: Colors.green,
								),
							  ],
							),
						  ),
						),
					  )
					  .toList(),
				],
			  ),

			const SizedBox(height: 16),

			// Плохие фильтры (Cold)
			if (widget.brain.getColdFilters().isNotEmpty)
			  Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
				  Padding(
					padding: const EdgeInsets.symmetric(vertical: 8),
					child: Text(
					  '❌ Underperforming Filters',
					  style: Theme.of(context).textTheme.titleMedium,
					),
				  ),
				  ...widget.brain
					  .getColdFilters()
					  .take(3)
					  .map(
						(metrics) => Padding(
						  padding: const EdgeInsets.only(bottom: 8),
						  child: Container(
							padding: const EdgeInsets.all(12),
							decoration: BoxDecoration(
							  color: Colors.red.withOpacity(0.1),
							  border:
								  Border.all(color: Colors.red, width: 1),
							  borderRadius: BorderRadius.circular(8),
							),
							child: Row(
							  mainAxisAlignment:
								  MainAxisAlignment.spaceBetween,
							  children: [
								Expanded(
								  child: Column(
									crossAxisAlignment:
										CrossAxisAlignment.start,
									children: [
									  Text(
										metrics.componentName,
										style: Theme.of(context)
											.textTheme
											.bodyLarge
											?.copyWith(
											  fontWeight: FontWeight.bold,
											),
									  ),
									  Text(
										'${metrics.winRate.toStringAsFixed(1)}% | ${metrics.averageR.toStringAsFixed(2)}R',
										style: Theme.of(context)
											.textTheme
											.bodySmall,
									  ),
									],
								  ),
								),
								Chip(
								  label: const Text(
									'DISABLE?',
									style:
										TextStyle(color: Colors.white),
								  ),
								  backgroundColor: Colors.red,
								),
							  ],
							),
						  ),
						),
					  )
					  .toList(),
				],
			  ),
		  ],
		);
	  },
	);
  }

  /// TAB 2: Filters - детальная таблица всех фильтров
  Widget _buildFiltersTab() {
	return AnimatedBuilder(
	  animation: widget.brain,
	  builder: (context, _) {
		final filters = widget.brain.getFiltersRankedByPerformance();

		if (filters.isEmpty) {
		  return Center(
			child: Column(
			  mainAxisAlignment: MainAxisAlignment.center,
			  children: [
				const Icon(Icons.info_outline, size: 64, color: Colors.grey),
				const SizedBox(height: 16),
				Text(
				  'No filter data yet',
				  style: Theme.of(context).textTheme.bodyLarge,
				),
			  ],
			),
		  );
		}

		return ListView(
		  children: [
			Padding(
			  padding: const EdgeInsets.all(16),
			  child: Text(
				'Filters ranked by Win Rate',
				style: Theme.of(context).textTheme.titleMedium,
			  ),
			),
			...filters
				.map(
				  (metrics) => FilterPerformanceCard(
					metrics: metrics,
					filterManager: widget.filterManager,
					showDetailedMetrics: true,
					onToggle: () {
					  setState(() {
						widget.filterManager.toggleFilter(
						  metrics.componentName,
						);
					  });
					},
				  ),
				)
				.toList(),
			const SizedBox(height: 32),
		  ],
		);
	  },
	);
  }

  /// TAB 3: Recommendations - автоматические рекомендации
  Widget _buildRecommendationsTab() {
	return AnimatedBuilder(
	  animation: widget.brain,
	  builder: (context, _) {
		final String report = widget.filterManager.getDetailedReport();

		return SingleChildScrollView(
		  padding: const EdgeInsets.all(16),
		  child: Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
			  // Кнопка автооптимизации
			  SizedBox(
				width: double.infinity,
				child: ElevatedButton.icon(
				  onPressed: () {
					widget.filterManager.applyAutoOptimization();
					ScaffoldMessenger.of(context).showSnackBar(
					  const SnackBar(
						content: Text('✅ Auto-optimization applied'),
						duration: Duration(seconds: 2),
					  ),
					);
				  },
				  icon: const Icon(Icons.auto_fix_high),
				  label: const Text(
					'Apply Auto-Optimization',
					style: TextStyle(fontSize: 16),
				  ),
				  style: ElevatedButton.styleFrom(
					backgroundColor: Theme.of(context).primaryColor,
					padding: const EdgeInsets.symmetric(vertical: 16),
				  ),
				),
			  ),
			  const SizedBox(height: 24),

			  // Отчёт
			  Container(
				padding: const EdgeInsets.all(16),
				decoration: BoxDecoration(
				  color: Colors.grey.shade900,
				  borderRadius: BorderRadius.circular(8),
				  border: Border.all(color: Colors.grey.shade700),
				),
				child: SelectableText(
				  report,
				  style: const TextStyle(
					fontFamily: 'monospace',
					fontSize: 12,
					color: Colors.green,
				  ),
				),
			  ),
			],
		  ),
		);
	  },
	);
  }

  /// TAB 4: Settings - управление конфигурациями
  Widget _buildSettingsTab() {
	return SingleChildScrollView(
	  padding: const EdgeInsets.all(16),
	  child: Column(
		crossAxisAlignment: CrossAxisAlignment.start,
		children: [
		  // Управление включением фильтров
		  Text(
			'Quick Actions',
			style: Theme.of(context).textTheme.titleMedium,
		  ),
		  const SizedBox(height: 12),
		  Row(
			children: [
			  Expanded(
				child: ElevatedButton(
				  onPressed: () {
					widget.filterManager.enableAllFilters();
					ScaffoldMessenger.of(context).showSnackBar(
					  const SnackBar(
						content: Text('✅ All filters enabled'),
					  ),
					);
				  },
				  child: const Text('Enable All'),
				),
			  ),
			  const SizedBox(width: 8),
			  Expanded(
				child: ElevatedButton(
				  onPressed: () {
					widget.filterManager.disableAllFilters();
					ScaffoldMessenger.of(context).showSnackBar(
					  const SnackBar(
						content: Text('❌ All filters disabled'),
					  ),
					);
				  },
				  style: ElevatedButton.styleFrom(
					backgroundColor: Colors.red,
				  ),
				  child: const Text('Disable All'),
				),
			  ),
			],
		  ),
		  const SizedBox(height: 24),

		  // Сохранённые конфигурации
		  Text(
			'Saved Configurations',
			style: Theme.of(context).textTheme.titleMedium,
		  ),
		  const SizedBox(height: 12),
		  AnimatedBuilder(
			animation: widget.filterManager,
			builder: (context, _) {
			  final configs =
				  widget.filterManager.getSavedConfigurationNames();

			  if (configs.isEmpty) {
				return Container(
				  padding: const EdgeInsets.all(12),
				  decoration: BoxDecoration(
					color: Colors.grey.shade200,
					borderRadius: BorderRadius.circular(8),
				  ),
				  child: Text(
					'No saved configurations',
					style: TextStyle(
					  color: Colors.grey.shade600,
					),
				  ),
				);
			  }

			  return Column(
				children: configs
					.map(
					  (name) => Card(
						child: ListTile(
						  title: Text(name),
						  trailing: PopupMenuButton<String>(
							onSelected: (value) {
							  if (value == 'load') {
								widget.filterManager.loadConfiguration(name);
							  } else if (value == 'delete') {
								widget.filterManager.deleteConfiguration(name);
							  }
							},
							itemBuilder: (BuildContext context) => [
							  const PopupMenuItem(
								value: 'load',
								child: Text('Load'),
							  ),
							  const PopupMenuItem(
								value: 'delete',
								child: Text('Delete'),
							  ),
							],
						  ),
						),
					  ),
					)
					.toList(),
			  );
			},
		  ),
		  const SizedBox(height: 24),

		  // Сохранить текущую конфигурацию
		  Text(
			'Save Current Configuration',
			style: Theme.of(context).textTheme.titleMedium,
		  ),
		  const SizedBox(height: 12),
		  TextField(
			decoration: InputDecoration(
			  hintText: 'Configuration name',
			  border: OutlineInputBorder(
				borderRadius: BorderRadius.circular(8),
			  ),
			),
			onSubmitted: (name) {
			  if (name.isNotEmpty) {
				widget.filterManager.saveConfiguration(name);
				ScaffoldMessenger.of(context).showSnackBar(
				  const SnackBar(
					content: Text('✅ Configuration saved'),
				  ),
				);
			  }
			},
		  ),
		],
	  ),
	);
  }

  Widget _buildStatTile(String label, String value, Color color) {
	return Row(
	  mainAxisAlignment: MainAxisAlignment.spaceBetween,
	  children: [
		Text(label),
		Container(
		  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
		  decoration: BoxDecoration(
			color: color.withOpacity(0.2),
			border: Border.all(color: color),
			borderRadius: BorderRadius.circular(8),
		  ),
		  child: Text(
			value,
			style: TextStyle(
			  fontWeight: FontWeight.bold,
			  color: color,
			  fontSize: 16,
			),
		  ),
		),
	  ],
	);
  }
}
