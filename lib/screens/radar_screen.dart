import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../engines/backtest_engine.dart';
import '../localization/app_strings.dart';
import '../models/market_models.dart';
import '../models/live_market_models.dart';
import '../models/navigation_models.dart';
import '../models/signal_models.dart';
import '../models/trade_alert_models.dart';
import '../services/app_preferences_controller.dart';
import '../services/bybit_service.dart';
import '../services/crypto_universe_controller.dart';
import '../services/journal_controller.dart';
import '../services/journal_store.dart';
import '../services/live_price_service.dart';
import '../services/notification_sound_service.dart';
import '../services/trade_alert_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_navigation.dart';
import '../widgets/product_components.dart';
import '../widgets/trade_signal_alert_dialog.dart';
import 'asset_workspace_screen.dart';
import 'asset_explorer_screen.dart';
import 'integrations_screen.dart';
import 'journal_screen.dart';
import 'market_scanner_screen.dart';
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
  late final http.Client _client;
  late final BybitService _repository;
  late final CryptoUniverseController _universeController;
  late final JournalController _journalController;
  late final Future<void> _journalReady;
  late final LivePriceService _livePriceService;
  late final TradeAlertController _tradeAlertController;
  final NotificationSoundPlayer _soundPlayer =
      const SystemNotificationSoundPlayer();
  Timer? _refreshTimer;
  AppSection _section = AppSection.home;
  MarketSectionView _marketView = MarketSectionView.explorer;
  WorkspaceSection _workspaceSection = WorkspaceSection.overview;
  String _selectedSymbol = 'FARTCOINUSDT';
  MarketUpdateMode _updateMode = MarketUpdateMode.economy15s;
  final ValueNotifier<LivePriceTick?> _livePrice =
      ValueNotifier<LivePriceTick?>(null);
  int _seenAnalysisRevision = 0;
  LiveConnectionStatus _renderedLiveStatus = LiveConnectionStatus.offline;
  bool _showingTradeAlert = false;
  bool _loading = false;
  String? _error;
  MarketSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _client = http.Client();
    _repository = BybitService(_client);
    _universeController = CryptoUniverseController(service: _repository);
    _journalController = JournalController(
      store: JournalStore(),
      backtestEngine: BacktestEngine(bybitService: _repository),
    );
    _journalReady = _journalController.initialize();
    _tradeAlertController = TradeAlertController();
    _livePriceService = LivePriceService()..addListener(_onLivePriceChanged);
    _universeController.initialize();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _livePriceService
      ..removeListener(_onLivePriceChanged)
      ..dispose();
    _tradeAlertController.dispose();
    _livePrice.dispose();
    _universeController.dispose();
    _journalController.dispose();
    _client.close();
    super.dispose();
  }

  void _restartTimer() {
    _refreshTimer?.cancel();
    if (_updateMode != MarketUpdateMode.economy15s || !widget.autoStart) {
      return;
    }
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
      await _journalReady;
      _tradeAlertController.prime(_journalController.signals);
      await _journalController.processLiveSnapshot(result);
      if (!mounted) return;
      setState(() => _snapshot = result);
      final TradeAlert? alert = _tradeAlertController.evaluate(
        _journalController.signals.where(
          (RadarSignal signal) => signal.symbol == result.symbol,
        ),
      );
      if (alert != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _presentTradeAlert(alert, result),
        );
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onLivePriceChanged() {
    if (!mounted || _updateMode != MarketUpdateMode.live) return;
    final int revision = _livePriceService.analysisRevision;
    if (revision > _seenAnalysisRevision) {
      _seenAnalysisRevision = revision;
      if (widget.autoStart) unawaited(_refresh());
    }
    final LivePriceTick? tick = _livePriceService.latestTick;
    if (tick == null || tick.symbol != _selectedSymbol) {
      if (_livePrice.value != null) _livePrice.value = null;
    } else if (_livePrice.value?.price != tick.price ||
        _livePrice.value?.receivedAt != tick.receivedAt) {
      _livePrice.value = tick;
    }
    if (_renderedLiveStatus != _livePriceService.status) {
      _renderedLiveStatus = _livePriceService.status;
      setState(() {});
    }
  }

  Future<void> _setUpdateMode(MarketUpdateMode mode) async {
    if (_updateMode == mode) return;
    setState(() => _updateMode = mode);
    _refreshTimer?.cancel();
    if (mode == MarketUpdateMode.live) {
      _seenAnalysisRevision = _livePriceService.analysisRevision;
      if (widget.autoStart) {
        await _livePriceService.start(_selectedSymbol);
        if (_snapshot == null) unawaited(_refresh());
      }
    } else {
      _livePrice.value = null;
      await _livePriceService.stop();
      _restartTimer();
    }
  }

  Future<void> _presentTradeAlert(
    TradeAlert alert,
    MarketSnapshot snapshot,
  ) async {
    if (!mounted ||
        _showingTradeAlert ||
        alert.signal.symbol != snapshot.symbol) {
      return;
    }
    _showingTradeAlert = true;
    if (widget.preferences.soundEnabled) {
      await _soundPlayer.playStrongAlert();
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => TradeSignalAlertDialog(
        alert: alert,
        snapshot: snapshot,
        onOpenMarket: () => _openWorkspace(WorkspaceSection.overview),
        onWhy: () => _openWorkspace(WorkspaceSection.why),
      ),
    );
    _showingTradeAlert = false;
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

  Future<void> _selectSymbol(String? symbol) async {
    if (symbol == null || symbol == _selectedSymbol) return;
    setState(() {
      _selectedSymbol = symbol;
      _snapshot = null;
      _error = null;
      _workspaceSection = WorkspaceSection.overview;
    });
    if (_updateMode == MarketUpdateMode.live && widget.autoStart) {
      unawaited(_livePriceService.switchSymbol(symbol));
    }
    while (_loading && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (mounted && _selectedSymbol == symbol) await _refresh();
  }

  void _openAsset(String symbol) {
    setState(() {
      _section = AppSection.market;
      _marketView = MarketSectionView.workspace;
    });
    _selectSymbol(symbol);
  }

  void _selectSection(AppSection section) {
    setState(() => _section = section);
  }

  void _openWorkspace(WorkspaceSection section) {
    setState(() {
      _section = AppSection.market;
      _marketView = MarketSectionView.workspace;
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
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _connectionStatusChip(),
              ),
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
        if (_section == AppSection.home) _buildAssetToolbar(),
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
              _connectionStatusChip(),
              const SizedBox(width: 10),
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
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget assetButton = OutlinedButton.icon(
            // The button keeps the familiar pair label while opening the
            // dynamic Asset Explorer instead of a hardcoded dropdown.
            onPressed: () {
              setState(() {
                _section = AppSection.market;
                _marketView = MarketSectionView.explorer;
              });
            },
            icon: const Icon(Icons.currency_bitcoin_rounded),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _displaySymbol(_selectedSymbol),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
          final Widget modeControl = SegmentedButton<MarketUpdateMode>(
            showSelectedIcon: false,
            segments: MarketUpdateMode.values
                .map<ButtonSegment<MarketUpdateMode>>(
                  (MarketUpdateMode mode) => ButtonSegment<MarketUpdateMode>(
                    value: mode,
                    label: Text(mode.label),
                  ),
                )
                .toList(growable: false),
            selected: <MarketUpdateMode>{_updateMode},
            onSelectionChanged: widget.autoStart
                ? (Set<MarketUpdateMode> selection) =>
                      unawaited(_setUpdateMode(selection.first))
                : null,
          );
          final Widget refresh = IconButton.filledTonal(
            tooltip: strings.refreshNow,
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          );
          final Widget controls = Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[modeControl, const SizedBox(width: 8), refresh],
          );
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 9, 12, 9),
            child: constraints.maxWidth < 650
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      assetButton,
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerRight, child: controls),
                    ],
                  )
                : Row(
                    children: <Widget>[
                      Expanded(child: assetButton),
                      const SizedBox(width: 8),
                      controls,
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _connectionStatusChip() {
    final RadarSemanticColors semantic = Theme.of(context)
        .extension<RadarSemanticColors>()!;
    if (_updateMode == MarketUpdateMode.economy15s) {
      return ProductStatusChip(
        label: '15s',
        color: semantic.neutral,
        icon: Icons.timer_outlined,
      );
    }
    final LiveConnectionStatus status = _livePriceService.status;
    final Color color = switch (status) {
      LiveConnectionStatus.live => semantic.bullish,
      LiveConnectionStatus.connecting => semantic.warning,
      LiveConnectionStatus.offline => semantic.bearish,
    };
    return ProductStatusChip(
      label: status.label,
      color: color,
      icon: status == LiveConnectionStatus.live
          ? Icons.bolt_rounded
          : status == LiveConnectionStatus.connecting
          ? Icons.sync_rounded
          : Icons.cloud_off_rounded,
    );
  }

  String _displaySymbol(String symbol) {
    if (symbol.endsWith('USDT') && symbol.length > 4) {
      return '${symbol.substring(0, symbol.length - 4)} / USDT';
    }
    return symbol;
  }

  Widget _buildSectionContent() {
    switch (_section) {
      case AppSection.home:
        if (_snapshot == null) return _buildEmptyState();
        return ProductDashboardScreen(
          snapshot: _snapshot!,
          journalController: _journalController,
          livePrice: _livePrice,
          onWhy: () => _openWorkspace(WorkspaceSection.why),
          onOpenWorkspace: () => _openWorkspace(WorkspaceSection.overview),
        );
      case AppSection.market:
        return _buildMarketContent();
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

  Widget _buildMarketContent() {
    final AppStrings strings = context.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _marketChip(
                    view: MarketSectionView.explorer,
                    icon: Icons.travel_explore_rounded,
                    label: 'Asset Explorer',
                  ),
                  const SizedBox(width: 8),
                  _marketChip(
                    view: MarketSectionView.scanner,
                    icon: Icons.radar_rounded,
                    label: 'Scanner',
                  ),
                  const SizedBox(width: 8),
                  _marketChip(
                    view: MarketSectionView.workspace,
                    icon: Icons.space_dashboard_outlined,
                    label:
                        '${strings.pick('Рабочее пространство', 'Workspace')} · $_selectedSymbol',
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: switch (_marketView) {
            MarketSectionView.explorer => AssetExplorerScreen(
              controller: _universeController,
              selectedSymbol: _selectedSymbol,
              selectedSnapshot: _snapshot,
              onSelect: _openAsset,
            ),
            MarketSectionView.scanner => MarketScannerScreen(
              controller: _universeController,
              onSelect: _openAsset,
            ),
            MarketSectionView.workspace =>
              _snapshot == null
                  ? _buildEmptyState()
                  : AssetWorkspaceScreen(
                      snapshot: _snapshot!,
                      journalController: _journalController,
                      bybitService: _repository,
                      livePrice: _livePrice,
                      selected: _workspaceSection,
                      onSelected: (WorkspaceSection value) =>
                          setState(() => _workspaceSection = value),
                    ),
          },
        ),
      ],
    );
  }

  Widget _marketChip({
    required MarketSectionView view,
    required IconData icon,
    required String label,
  }) {
    return ChoiceChip(
      selected: _marketView == view,
      avatar: Icon(icon, size: 17),
      label: Text(label),
      onSelected: (_) => setState(() => _marketView = view),
    );
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
