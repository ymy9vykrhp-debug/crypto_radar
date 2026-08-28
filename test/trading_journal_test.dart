import 'package:crypto_radar/engines/backtest_engine.dart';
import 'package:crypto_radar/engines/journal_performance_engine.dart';
import 'package:crypto_radar/models/trading_journal_models.dart';
import 'package:crypto_radar/services/bybit_service.dart';
import 'package:crypto_radar/services/journal_controller.dart';
import 'package:crypto_radar/services/journal_store.dart';
import 'package:crypto_radar/services/storage/local_storage_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Personal Trading Journal', () {
    test(
      'manual trade calculates PnL, fees, percent, R and defaults research off',
      () {
        final TradeJournalEntry trade = _trade(id: 'long', exit: 102, fees: 1);

        expect(trade.source, TradeSource.manual);
        expect(trade.status, JournalTradeStatus.win);
        expect(trade.grossPnl, closeTo(20, 0.0001));
        expect(trade.netPnl, closeTo(19, 0.0001));
        expect(trade.pnlPercent, closeTo(19, 0.0001));
        expect(trade.plannedRiskReward, 3);
        expect(trade.resultR, closeTo(1.9, 0.0001));
        expect(trade.useForStrategyResearch, isFalse);
      },
    );

    test('SHORT calculation mirrors price movement and includes fees', () {
      final TradeJournalEntry trade = _trade(
        id: 'short',
        side: JournalTradeSide.short,
        stop: 101,
        tp1: 98,
        tp2: 97,
        exit: 98,
        fees: 2,
      );

      expect(trade.grossPnl, closeTo(20, 0.0001));
      expect(trade.netPnl, closeTo(18, 0.0001));
      expect(trade.resultR, closeTo(1.8, 0.0001));
    });

    test('open manual trade can be edited into a closed trade', () async {
      final _MemoryStorage storage = _MemoryStorage();
      final JournalController controller = _controller(storage);
      final TradeJournalEntry open = _trade(id: 'open');

      await controller.addManualTrade(open);
      expect(controller.trades.single.status, JournalTradeStatus.open);
      expect(controller.trades.single.netPnl, 0);

      await controller.updateManualTrade(
        open
            .copyWith(actualExit: 102, exitTime: DateTime(2026, 8, 27, 11))
            .withCalculatedStatus(),
      );

      expect(controller.trades.single.status, JournalTradeStatus.win);
      expect(controller.trades.single.exitTime, isNotNull);
      expect(controller.trades.single.netPnl, closeTo(20, 0.0001));

      final JournalController restored = _controller(storage);
      await restored.initialize();
      expect(restored.trades.single.status, JournalTradeStatus.win);
      controller.dispose();
      restored.dispose();
    });

    test(
      'manual trade edits and deletes are allowed, system facts are protected',
      () async {
        final JournalController controller = _controller(_MemoryStorage());
        final TradeJournalEntry manual = _trade(id: 'manual');
        await controller.addManualTrade(manual);
        await controller.updateManualTrade(manual.copyWith(myNotes: 'edited'));
        expect(controller.trades.single.myNotes, 'edited');
        await controller.deleteManualTrade('manual');
        expect(controller.trades, isEmpty);

        final TradeJournalEntry paper = _trade(
          id: 'paper',
          source: TradeSource.paper,
        );
        await controller.upsertExecutionTrade(paper);
        await expectLater(
          controller.deleteManualTrade('paper'),
          throwsA(isA<StateError>()),
        );
        controller.dispose();
      },
    );

    test('source, side and period filters do not mix execution sources', () {
      final DateTime now = DateTime(2026, 8, 27, 12);
      final List<TradeJournalEntry> trades = <TradeJournalEntry>[
        _trade(id: 'manual', exit: 102, time: now),
        _trade(
          id: 'paper',
          exit: 98,
          source: TradeSource.paper,
          time: now.subtract(const Duration(days: 2)),
        ),
        _trade(
          id: 'demo',
          exit: 102,
          source: TradeSource.bybitDemo,
          side: JournalTradeSide.short,
          stop: 101,
          tp1: 98,
          tp2: 97,
          time: now.subtract(const Duration(days: 40)),
        ),
      ];

      expect(
        JournalPerformanceEngine.filterTrades(
          trades,
          const JournalFilter(source: TradeSource.paper),
          now: now,
        ).single.id,
        'paper',
      );
      expect(
        JournalPerformanceEngine.filterTrades(
          trades,
          const JournalFilter(period: PerformancePeriod.sevenDays),
          now: now,
        ).map((TradeJournalEntry trade) => trade.id),
        containsAll(<String>['manual', 'paper']),
      );
      expect(
        JournalPerformanceEngine.filterTrades(
          trades,
          const JournalFilter(side: JournalTradeSide.short),
          now: now,
        ).single.id,
        'demo',
      );
      final PerformanceSnapshot winsOnly = JournalPerformanceEngine.performance(
        trades,
        const JournalSettings(startingBalance: 100),
        const JournalFilter(status: JournalTradeStatus.win),
        now: now,
      );
      expect(winsOnly.trades, 1);
      expect(winsOnly.losses, 0);
    });

    test(
      'calendar, daily, weekly and monthly summaries aggregate realized trades',
      () {
        final List<TradeJournalEntry> trades = <TradeJournalEntry>[
          _trade(id: 'a', exit: 102, time: DateTime(2026, 8, 27, 9)),
          _trade(id: 'b', exit: 98, time: DateTime(2026, 8, 27, 12)),
          _trade(id: 'c', exit: 103, time: DateTime(2026, 8, 28, 10)),
        ];

        final List<DailyJournalSummary> days =
            JournalPerformanceEngine.calendar(trades);
        expect(days, hasLength(2));
        expect(days.first.trades, hasLength(2));
        expect(days.first.wins, 1);
        expect(days.first.losses, 1);
        expect(
          JournalPerformanceEngine.weekly(trades, const JournalSettings()),
          hasLength(1),
        );
        final List<JournalPeriodSummary> months =
            JournalPerformanceEngine.monthly(trades, const JournalSettings());
        expect(months, hasLength(1));
        expect(months.single.bestWeek, isNotNull);
        expect(months.single.worstWeek, isNotNull);
      },
    );

    test(
      'equity, balance, win rate, profit factor and drawdown are deterministic',
      () {
        final List<TradeJournalEntry> trades = <TradeJournalEntry>[
          _trade(id: 'win', exit: 102, time: DateTime(2026, 8, 25, 9)),
          _trade(id: 'loss', exit: 98, time: DateTime(2026, 8, 26, 9)),
          _trade(id: 'win2', exit: 103, time: DateTime(2026, 8, 27, 9)),
        ];
        final PerformanceSnapshot result = JournalPerformanceEngine.performance(
          trades,
          const JournalSettings(startingBalance: 100),
          const JournalFilter(),
          now: DateTime(2026, 8, 27, 20),
        );

        expect(result.trades, 3);
        expect(result.wins, 2);
        expect(result.losses, 1);
        expect(result.winRate, closeTo(66.666, 0.01));
        expect(result.profitFactor, closeTo(2.5, 0.0001));
        expect(result.currentBalance, closeTo(130, 0.0001));
        expect(result.maxDrawdown, closeTo(20, 0.0001));
        expect(result.equity, hasLength(4));
        expect(result.bestDay?.netPnl, closeTo(30, 0.0001));
        expect(result.worstDay?.netPnl, closeTo(-20, 0.0001));
      },
    );

    test(
      'strategy, asset, LONG/SHORT and source statistics use journal records',
      () {
        final List<TradeJournalEntry> trades = <TradeJournalEntry>[
          _trade(id: 'a', exit: 102, strategy: 'Sweep'),
          _trade(
            id: 'b',
            exit: 98,
            strategy: 'BOS',
            symbol: 'ETHUSDT',
            source: TradeSource.paper,
          ),
          _trade(
            id: 'c',
            exit: 98,
            strategy: 'Sweep',
            side: JournalTradeSide.short,
            stop: 101,
            tp1: 98,
            tp2: 97,
          ),
        ];

        expect(JournalPerformanceEngine.byStrategy(trades), hasLength(2));
        expect(JournalPerformanceEngine.byAsset(trades), hasLength(2));
        expect(JournalPerformanceEngine.bySide(trades), hasLength(2));
        expect(JournalPerformanceEngine.bySource(trades), hasLength(2));
      },
    );

    test('historical strategy snapshot survives settings changes', () async {
      final _MemoryStorage storage = _MemoryStorage();
      final JournalController controller = _controller(storage);
      final TradeJournalEntry trade = _trade(
        id: 'snapshot',
        exit: 102,
        context: const TradeContextSnapshot(
          strategyVersion: 'v1',
          riskPercent: 2,
        ),
      );
      await controller.addManualTrade(trade);
      await controller.updateJournalSettings(
        const JournalSettings(startingBalance: 500),
      );

      expect(controller.trades.single.contextSnapshot.strategyVersion, 'v1');
      expect(controller.trades.single.contextSnapshot.riskPercent, 2);
      expect(controller.trades.single.useForStrategyResearch, isFalse);
      controller.dispose();
    });
  });
}

TradeJournalEntry _trade({
  required String id,
  TradeSource source = TradeSource.manual,
  JournalTradeSide side = JournalTradeSide.long,
  String symbol = 'BTCUSDT',
  String strategy = 'Sweep',
  DateTime? time,
  double entry = 100,
  double stop = 99,
  double tp1 = 102,
  double tp2 = 103,
  double? exit,
  double fees = 0,
  TradeContextSnapshot context = const TradeContextSnapshot(),
}) {
  final DateTime tradeTime = time ?? DateTime(2026, 8, 27, 10);
  final TradeJournalEntry entryModel = TradeJournalEntry(
    id: id,
    source: source,
    createdAt: tradeTime,
    tradeTime: tradeTime,
    symbol: symbol,
    side: side,
    plannedEntry: entry,
    stopLoss: stop,
    tp1: tp1,
    tp2: tp2,
    actualEntry: entry,
    actualExit: exit,
    exitTime: exit == null ? null : tradeTime.add(const Duration(hours: 1)),
    positionSize: 1000,
    margin: 100,
    leverage: 10,
    fees: fees,
    strategy: strategy,
    timeframe: '5m',
    status: exit == null
        ? JournalTradeStatus.open
        : JournalTradeStatus.breakEven,
    entryReason: EntryReason.liquiditySweep,
    entryReasonText: '',
    myNotes: '',
    tags: const <TradeTag>{},
    whatWasGood: '',
    whatWasWrong: '',
    whatShouldChange: '',
    useForStrategyResearch: false,
    contextSnapshot: context,
  );
  return entryModel.withCalculatedStatus();
}

JournalController _controller(_MemoryStorage storage) {
  final MockClient client = MockClient(
    (http.Request request) async => http.Response('{}', 500),
  );
  return JournalController(
    store: JournalStore(backend: storage),
    backtestEngine: BacktestEngine(bybitService: BybitService(client)),
  );
}

class _MemoryStorage implements LocalStorageBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
