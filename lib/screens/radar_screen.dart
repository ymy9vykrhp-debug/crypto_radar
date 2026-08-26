import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../engines/backtest_engine.dart';
import '../localization/app_strings.dart';
import '../models/market_models.dart';
import '../models/navigation_models.dart';
import '../services/app_preferences_controller.dart';
import '../services/bybit_service.dart';
import '../services/journal_controller.dart';
import '../services/journal_store.dart';
import '../widgets/app_navigation.dart';
import '../widgets/product_components.dart';
import 'asset_workspace_screen.dart';
import 'integrations_screen.dart';
import 'journal_screen.dart';
import 'news_screen.dart';
import 'product_dashboard_screen.dart';
import 'research_screen.dart';
import 'settings_screen.dart';
import 'signals_screen.dart';

class CryptoRadarHome extends StatefulWidget {
  const CryptoRadarHome({
    super.key,
    this.autoStart = true,
    required this.preferences,
  });

  final bool autoStart;
  final AppPreferencesController preferences;

  @override
  State<CryptoRadarHome> createState() => _CryptoRadarHomeState();
}

class _CryptoRadarHomeState extends State<CryptoRadarHome> {
  static const Map<String, String> _symbols = <String, String>{
    'BTCUSDT': 'BTC / USDT',
    'FARTCOINUSDT': 'FARTCOIN / USDT',
  };

  late final http.Client _client;
  late final BybitService _repository;
  late final JournalController _journalController;
  Timer? _refreshTimer;
  AppSection _section = AppSection.home;
  WorkspaceSection _workspaceSection = WorkspaceSection.overview;
  String _selectedSymbol = 'FARTCOINUSDT';
  bool _autoRefresh = true;
  bool _loading = false;
  String? _error;
  MarketSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _client = http.Client();
    _repository = BybitService(_client);
    _journalController = JournalController(
      store: JournalStore(),
      backtestEngine: BacktestEngine(bybitService: _repository),
    );
    _journalController.initialize();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
      _restartTimer();
    } else {
      _autoRefresh = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _journalController.dispose();
    _client.close();
    super.dispose();
  }

  void _restartTimer() {
    _refreshTimer?.cancel();
    if (!_autoRefresh || !widget.autoStart) return;
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refresh(),
    );
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final MarketSnapshot result = await _repository.load(_selectedSymbol);
      if (!mounted || result.symbol != _selectedSymbol) return;
      await _journalController.processLiveSnapshot(result);
      if (!mounted) return;
      setState(() => _snapshot = result);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object error) {
    final String message = error.toString().replaceFirst('Exception: ', '');
    final AppStrings strings = context.strings;
    if (message.contains('TimeoutException')) {
      return strings.pick(
        'Bybit не ответил вовремя. Проверьте интернет и обновите ещё раз.',
        'Bybit did not respond in time. Check the connection and retry.',
      );
    }
    return strings.pick(
      'Не удалось обновить данные: $message',
      'Could not refresh data: $message',
    );
  }

  void _selectSymbol(String? symbol) {
    if (symbol == null || symbol == _selectedSymbol) return;
    setState(() {
      _selectedSymbol = symbol;
      _snapshot = null;
      _error = null;
      _workspaceSection = WorkspaceSection.overview;
    });
    _refresh();
  }

  void _selectSection(AppSection section) {
    setState(() => _section = section);
  }

  void _openWorkspace(WorkspaceSection section) {
    setState(() {
      _section = AppSection.market;
      _workspaceSection = section;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool desktop = constraints.maxWidth >= 980;
        if (desktop) {
          return Scaffold(
            body: Row(
              children: <Widget>[
                ProductNavigationRail(
                  selected: _section,
                  onSelected: _selectSection,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _buildWorkspace(desktop: true)),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(context.strings.appSection(_section)),
            actions: <Widget>[
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          drawer: ProductNavigationDrawer(
            selected: _section,
            onSelected: _selectSection,
          ),
          body: _buildWorkspace(desktop: false),
        );
      },
    );
  }

  Widget _buildWorkspace({required bool desktop}) {
    return Column(
      children: <Widget>[
        if (desktop) _buildDesktopHeader(),
        if (_section == AppSection.home || _section == AppSection.market)
          _buildAssetToolbar(),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null) _buildErrorBanner(_error!),
        Expanded(child: _buildSectionContent()),
      ],
    );
  }

  Widget _buildDesktopHeader() {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: <Widget>[
              Icon(appSectionIcon(_section), size: 21),
              const SizedBox(width: 9),
              Text(
                context.strings.appSection(_section),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (_loading)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssetToolbar() {
    final AppStrings strings = context.strings;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 9, 12, 9),
        child: Row(
          children: <Widget>[
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey<String>(_selectedSymbol),
                initialValue: _selectedSymbol,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: strings.instrument,
                  prefixIcon: const Icon(Icons.currency_bitcoin_rounded),
                ),
                items: _symbols.entries
                    .map<DropdownMenuItem<String>>(
                      (MapEntry<String, String> entry) =>
                          DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                    )
                    .toList(growable: false),
                onChanged: _loading ? null : _selectSymbol,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: strings.autoRefresh,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('15s'),
                  Switch(
                    value: _autoRefresh,
                    onChanged: (bool value) {
                      setState(() => _autoRefresh = value);
                      _restartTimer();
                    },
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: strings.refreshNow,
              onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContent() {
    switch (_section) {
      case AppSection.home:
        if (_snapshot == null) return _buildEmptyState();
        return ProductDashboardScreen(
          snapshot: _snapshot!,
          journalController: _journalController,
          onWhy: () => _openWorkspace(WorkspaceSection.why),
          onOpenWorkspace: () => _openWorkspace(WorkspaceSection.overview),
        );
      case AppSection.market:
        if (_snapshot == null) return _buildEmptyState();
        return AssetWorkspaceScreen(
          snapshot: _snapshot!,
          journalController: _journalController,
          bybitService: _repository,
          selected: _workspaceSection,
          onSelected: (WorkspaceSection value) =>
              setState(() => _workspaceSection = value),
        );
      case AppSection.signals:
        return SignalsScreen(
          controller: _journalController,
          selectedSymbol: _selectedSymbol,
        );
      case AppSection.journal:
        return JournalScreen(controller: _journalController);
      case AppSection.research:
        return ResearchScreen(controller: _journalController);
      case AppSection.news:
        return const NewsScreen();
      case AppSection.integrations:
        return const IntegrationsScreen();
      case AppSection.settings:
        return SettingsScreen(preferences: widget.preferences);
    }
  }

  Widget _buildErrorBanner(String message) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            TextButton(
              onPressed: _loading ? null : _refresh,
              child: Text(context.strings.pick('Повторить', 'Retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ProductEmptyState(
      icon: Icons.radar_rounded,
      title: context.strings.loadingMarket,
      message: widget.autoStart
          ? context.strings.pick(
              'Подождите первую загрузку данных выбранного актива.',
              'Wait for the first selected-asset data load.',
            )
          : context.strings.pick(
              'Автоматическая загрузка отключена в тестовом режиме.',
              'Automatic loading is disabled in test mode.',
            ),
      action: widget.autoStart
          ? null
          : OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.strings.refreshNow),
            ),
    );
  }
}
