import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../engines/adaptive_grid_engine.dart';
import '../engines/manual_assistant_engine.dart';
import '../models/exchange_confirmation_models.dart';
import '../models/market_models.dart';
import '../models/position_calculator_models.dart';
import '../models/signal_models.dart';
import 'exchange_confirmation_provider.dart';
import 'live_price_service.dart';
import 'market_data_provider.dart';
import 'storage/local_storage_backend.dart';

class ManualAssistantController extends ChangeNotifier {
  ManualAssistantController({
    required this.provider,
    required this.live,
    this.confirmationProvider,
    LocalStorageBackend? storage,
    DateTime Function()? clock,
  }) : _storage = storage ?? createLocalStorageBackend(),
       _clock = clock ?? DateTime.now;
  final MarketDataProvider provider;
  final LivePriceService live;
  final ExchangeConfirmationProvider? confirmationProvider;
  final LocalStorageBackend _storage;
  final DateTime Function() _clock;
  final Map<String, MarketSnapshot> markets = {};
  final Map<String, String> errors = {};
  final Set<String> loading = {};
  final List<Map<String, Object?>> history = [];
  ManualPosition? position;
  AssistantResult? result;
  AdaptiveGridAssessment? grid;
  ExchangeConfirmationSnapshot? binanceConfirmation;
  String? confirmationError;
  AssistantMode mode = AssistantMode.continuation;
  double balance = 0, riskPercent = .5, minPotentialPercent = 1;
  int maxLeverage = 5;
  FeeModel fees = const FeeModel();
  String? storageError;
  Timer? _refreshTimer, _clockTimer;
  bool _disposed = false, _started = false;
  bool liveEnabled = true;
  bool liveChanging = false;
  int _lastLiveAnalysisRevision = 0;
  Future<void> _writes = Future.value();
  static const _key = 'manual_assistant_v1';

  Future<void> initialize({bool start = true}) async {
    try {
      final raw = await _storage.read(_key);
      if (_disposed) return;
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final storedBalance = (j['balance'] as num?)?.toDouble() ?? 0;
        final storedRisk = (j['riskPercent'] as num?)?.toDouble() ?? .5;
        final storedPotential =
            (j['minPotentialPercent'] as num?)?.toDouble() ?? 1;
        balance = storedBalance.isFinite && storedBalance >= 0
            ? storedBalance
            : 0;
        riskPercent = storedRisk.isFinite && storedRisk > 0 && storedRisk <= 2
            ? storedRisk
            : .5;
        minPotentialPercent = storedPotential.isFinite && storedPotential >= 0
            ? storedPotential
            : 1;
        maxLeverage = ((j['maxLeverage'] as num?)?.toInt() ?? 5)
            .clamp(1, 10)
            .toInt();
        mode = j['mode'] == 'scalp'
            ? AssistantMode.scalp
            : AssistantMode.continuation;
        if (j['fees'] is Map)
          fees = FeeModel.fromJson(Map<String, dynamic>.from(j['fees']));
        if (j['position'] is Map)
          position = ManualPosition.fromJson(
            Map<String, dynamic>.from(j['position']),
          );
        for (final record in (j['history'] as List? ?? [])) {
          history.add(Map<String, Object?>.from(record as Map));
        }
      }
    } catch (_) {
      storageError = 'Не удалось прочитать сохранённую позицию. Не перезаписывайте данные: сохраните экспорт и проверьте позицию на бирже.';
    }
    if (_disposed) return;
    if (start && !_started) {
      _started = true;
      live.addListener(_onLiveChanged);
      if (liveEnabled) await live.start('FARTCOINUSDT');
      _lastLiveAnalysisRevision = live.analysisRevision;
      if (_disposed) return;
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) { if (liveEnabled) unawaited(refresh()); },
      );
      _clockTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => recalculate(),
      );
      if (liveEnabled) unawaited(refresh());
    }
    recalculate();
  }

  Future<void> setLiveEnabled(bool enabled) async {
    if (_disposed || liveChanging || liveEnabled == enabled) return;
    liveChanging = true;
    liveEnabled = enabled;
    notifyListeners();
    try {
      if (enabled && _started) {
        await live.start('FARTCOINUSDT');
        if (!_disposed) unawaited(refresh());
      } else {
        await live.stop();
      }
    } finally {
      liveChanging = false;
      if (!_disposed) recalculate();
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final List<Future<void>> work = <Future<void>>[
      ...<String>['FARTCOINUSDT', 'BTCUSDT', 'ETHUSDT', 'SOLUSDT'].map(_load),
      if (confirmationProvider != null) _loadConfirmation(),
    ];
    await Future.wait(work);
  }

  Future<void> _loadConfirmation() async {
    final ExchangeConfirmationProvider? source = confirmationProvider;
    if (_disposed || source == null || loading.contains('BINANCE:FARTCOINUSDT')) {
      return;
    }
    loading.add('BINANCE:FARTCOINUSDT');
    notifyListeners();
    try {
      binanceConfirmation = await source.load('FARTCOINUSDT');
      confirmationError = null;
    } catch (error) {
      if (!_disposed) confirmationError = '$error';
    } finally {
      loading.remove('BINANCE:FARTCOINUSDT');
      recalculate();
    }
  }

  void _onLiveChanged() {
    if (_disposed || !liveEnabled) return;
    final int revision = live.analysisRevision;
    if (revision != _lastLiveAnalysisRevision) {
      _lastLiveAnalysisRevision = revision;
      // A newly closed 1m candle must refresh the full multi-timeframe analysis
      // immediately instead of waiting for the next 15-second fallback tick.
      unawaited(refresh());
    }
    recalculate();
  }

  Future<void> _load(String symbol) async {
    if (_disposed || !loading.add(symbol)) return;
    notifyListeners();
    try {
      final snapshot = await provider.load(symbol);
      if (_disposed) return;
      if (snapshot.symbol != symbol) throw StateError('Неверный инструмент');
      markets[symbol] = snapshot;
      errors.remove(symbol);
    } catch (error) {
      if (!_disposed) errors[symbol] = '$error';
    } finally {
      loading.remove(symbol);
      recalculate();
    }
  }

  void recalculate() {
    if (_disposed) return;
    final market = markets['FARTCOINUSDT'];
    if (market != null) {
      try {
        result = ManualAssistantEngine.evaluate(
          market: market,
          btc: markets['BTCUSDT'],
          eth: markets['ETHUSDT'],
          sol: markets['SOLUSDT'],
          binance: binanceConfirmation,
          tick: live.latestTick,
          now: _clock().toUtc(),
          mode: mode,
          balance: balance,
          riskPercent: riskPercent,
          maxLeverage: maxLeverage,
          fees: fees,
          minPotentialPercent: minPotentialPercent,
          position: position,
        );
        grid = AdaptiveGridEngine.evaluate(
          market: market,
          maximumLeverage: maxLeverage,
        );
        errors.remove('analysis');
      } catch (e) {
        result = null;
        grid = null;
        errors['analysis'] = 'Расчёт недоступен: $e';
      }
    }
    notifyListeners();
  }

  void configure({
    required double equity,
    required double risk,
    required int leverage,
    required double potential,
    required double fee,
    required double slippage,
  }) {
    if (![equity, risk, potential, fee, slippage].every((v) => v.isFinite) ||
        equity < 0 ||
        risk <= 0 ||
        risk > 2 ||
        leverage < 1 ||
        leverage > 10 ||
        potential < 0 ||
        potential > 20 ||
        fee < 0 ||
        fee > 1 ||
        slippage < 0 ||
        slippage > 1) {
      throw ArgumentError(
        'Баланс ≥0, риск 0–2%, плечо 1–10, потенциал 0–20%, расходы 0–1%',
      );
    }
    balance = equity;
    riskPercent = risk;
    maxLeverage = leverage;
    minPotentialPercent = potential;
    fees = fees.copyWith(
      takerFeePercent: fee,
      entrySlippagePercent: slippage,
      targetSlippagePercent: slippage,
      stopSlippagePercent: slippage,
    );
    _save();
    recalculate();
  }

  void setMode(AssistantMode value) {
    mode = value;
    _save();
    recalculate();
  }

  void recordOpen({
    required SignalDirection side,
    required double entry,
    required double stop,
    required double quantity,
  }) {
    if (position != null) throw StateError('Сначала закройте текущую запись');
    final sign = side == SignalDirection.long ? 1 : -1;
    if (![entry, stop, quantity].every((v) => v.isFinite && v > 0) ||
        (entry - stop) * sign <= 0) {
      throw ArgumentError('Неверные Entry, SL или количество');
    }
    position = ManualPosition(
      side: side,
      entry: entry,
      stop: stop,
      initialStop: stop,
      quantity: quantity,
      openedAt: _clock().toUtc(),
      qualityAtOpen: result?.quality,
      entryLowAtOpen: result?.decision.entryLow,
      entryHighAtOpen: result?.decision.entryHigh,
      plannedTargets: List<double>.unmodifiable(result?.targets ?? const <double>[]),
    );
    _record('OPEN');
  }

  void recordStop(double stop) {
    position = position!.protect(stop);
    _record('STOP');
  }

  void recordPartial(double remaining) {
    position = position!.reduce(remaining);
    _record('PARTIAL');
  }

  void recordClose() {
    if (position == null) return;
    history.add({
      'event': 'CLOSE',
      'time': _clock().toUtc().toIso8601String(),
      'position': position!.toJson(),
    });
    position = null;
    _save();
    recalculate();
  }

  void _record(String event) {
    history.add({
      'event': event,
      'time': _clock().toUtc().toIso8601String(),
      'position': position!.toJson(),
    });
    _save();
    recalculate();
  }

  Map<String, Object?> _data() => {
    'balance': balance,
    'riskPercent': riskPercent,
    'maxLeverage': maxLeverage,
    'minPotentialPercent': minPotentialPercent,
    'fees': fees.toJson(),
    'mode': mode.name,
    'position': position?.toJson(),
    'history': history,
  };
  String export() => const JsonEncoder.withIndent('  ').convert(_data());
  Future<String> exportLegacy() async {
    final data = <String, String?>{};
    for (final key in [
      'crypto_radar_signals_v1',
      'crypto_radar_backtests_v1',
      'crypto_radar_personal_trades_v1',
      'crypto_radar_trading_notes_v1',
      'crypto_radar_review_notes_v1',
      'crypto_radar_journal_settings_v1',
    ]) {
      data[key] = await _storage.read(key);
    }
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  void _save() {
    if (storageError != null) throw StateError(storageError!);
    final payload = jsonEncode(_data());
    _writes = _writes.then((_) => _storage.write(_key, payload)).catchError((
      Object error,
    ) {
      if (!_disposed) {
        storageError = 'Ошибка сохранения: $error';
        notifyListeners();
      }
    });
  }

  Future<void> flush() => _writes;
  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    _clockTimer?.cancel();
    live.removeListener(_onLiveChanged);
    live.dispose();
    super.dispose();
  }
}
