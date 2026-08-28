import '../models/trading_journal_models.dart';

class JournalFilter {
  const JournalFilter({
    this.period = PerformancePeriod.all,
    this.source,
    this.symbol = '',
    this.strategy = '',
    this.status,
    this.side,
  });

  final PerformancePeriod period;
  final TradeSource? source;
  final String symbol;
  final String strategy;
  final JournalTradeStatus? status;
  final JournalTradeSide? side;

  JournalFilter copyWith({
    PerformancePeriod? period,
    TradeSource? source,
    bool clearSource = false,
    String? symbol,
    String? strategy,
    JournalTradeStatus? status,
    bool clearStatus = false,
    JournalTradeSide? side,
    bool clearSide = false,
  }) => JournalFilter(
    period: period ?? this.period,
    source: clearSource ? null : source ?? this.source,
    symbol: symbol ?? this.symbol,
    strategy: strategy ?? this.strategy,
    status: clearStatus ? null : status ?? this.status,
    side: clearSide ? null : side ?? this.side,
  );
}

class EquityPoint {
  const EquityPoint({
    required this.time,
    required this.balance,
    required this.tradeId,
  });

  final DateTime time;
  final double balance;
  final String tradeId;
}

class PerformanceSnapshot {
  const PerformanceSnapshot({
    required this.startingBalance,
    required this.openingBalance,
    required this.currentBalance,
    required this.netPnl,
    required this.returnPercent,
    required this.netR,
    required this.trades,
    required this.openTrades,
    required this.wins,
    required this.losses,
    required this.breakEven,
    required this.winRate,
    required this.profitFactor,
    required this.maxDrawdown,
    required this.maxDrawdownPercent,
    required this.averageR,
    required this.averageWin,
    required this.averageLoss,
    required this.bestTrade,
    required this.worstTrade,
    required this.bestDay,
    required this.worstDay,
    required this.largestWinStreak,
    required this.largestLossStreak,
    required this.disciplineScore,
    required this.equity,
  });

  final double startingBalance;
  final double openingBalance;
  final double currentBalance;
  final double netPnl;
  final double returnPercent;
  final double netR;
  final int trades;
  final int openTrades;
  final int wins;
  final int losses;
  final int breakEven;
  final double winRate;
  final double profitFactor;
  final double maxDrawdown;
  final double maxDrawdownPercent;
  final double averageR;
  final double averageWin;
  final double averageLoss;
  final TradeJournalEntry? bestTrade;
  final TradeJournalEntry? worstTrade;
  final DailyJournalSummary? bestDay;
  final DailyJournalSummary? worstDay;
  final int largestWinStreak;
  final int largestLossStreak;
  final int disciplineScore;
  final List<EquityPoint> equity;
}

class DailyJournalSummary {
  const DailyJournalSummary({
    required this.date,
    required this.trades,
    required this.wins,
    required this.losses,
    required this.breakEven,
    required this.netPnl,
    required this.netR,
    required this.winRate,
    required this.profitFactor,
    required this.bestTrade,
    required this.worstTrade,
    required this.dailyDrawdown,
    required this.disciplineScore,
  });

  final DateTime date;
  final List<TradeJournalEntry> trades;
  final int wins;
  final int losses;
  final int breakEven;
  final double netPnl;
  final double netR;
  final double winRate;
  final double profitFactor;
  final TradeJournalEntry? bestTrade;
  final TradeJournalEntry? worstTrade;
  final double dailyDrawdown;
  final int disciplineScore;
}

class JournalPeriodSummary {
  const JournalPeriodSummary({
    required this.start,
    required this.end,
    required this.trades,
    required this.netPnl,
    required this.netR,
    required this.winRate,
    required this.profitFactor,
    required this.drawdown,
    required this.bestDay,
    required this.worstDay,
    required this.bestWeek,
    required this.worstWeek,
    required this.bestStrategy,
    required this.worstStrategy,
    required this.bestAsset,
    required this.worstAsset,
    required this.mostCommonMistake,
    required this.disciplineScore,
  });

  final DateTime start;
  final DateTime end;
  final int trades;
  final double netPnl;
  final double netR;
  final double winRate;
  final double profitFactor;
  final double drawdown;
  final DailyJournalSummary? bestDay;
  final DailyJournalSummary? worstDay;
  final JournalWeekHighlight? bestWeek;
  final JournalWeekHighlight? worstWeek;
  final String bestStrategy;
  final String worstStrategy;
  final String bestAsset;
  final String worstAsset;
  final TradeTag? mostCommonMistake;
  final int disciplineScore;
}

class JournalWeekHighlight {
  const JournalWeekHighlight({
    required this.start,
    required this.end,
    required this.netPnl,
  });

  final DateTime start;
  final DateTime end;
  final double netPnl;
}

class JournalGroupPerformance {
  const JournalGroupPerformance({
    required this.label,
    required this.trades,
    required this.wins,
    required this.losses,
    required this.netPnl,
    required this.netR,
    required this.winRate,
    required this.averageR,
    required this.profitFactor,
    required this.drawdown,
  });

  final String label;
  final int trades;
  final int wins;
  final int losses;
  final double netPnl;
  final double netR;
  final double winRate;
  final double averageR;
  final double profitFactor;
  final double drawdown;
}

class JournalPerformanceEngine {
  const JournalPerformanceEngine._();

  static List<TradeJournalEntry> filterTrades(
    Iterable<TradeJournalEntry> source,
    JournalFilter filter, {
    DateTime? now,
  }) {
    final _DateRange range = _range(filter.period, now ?? DateTime.now());
    final String symbol = normalizeJournalSymbol(filter.symbol);
    final String strategy = filter.strategy.trim().toLowerCase();
    final List<TradeJournalEntry> result = source
        .where((TradeJournalEntry trade) {
          final DateTime local = trade.tradeTime.toLocal();
          if (!range.contains(local)) return false;
          if (filter.source != null && trade.source != filter.source) {
            return false;
          }
          if (symbol.isNotEmpty && trade.symbol != symbol) return false;
          if (strategy.isNotEmpty &&
              !trade.strategy.toLowerCase().contains(strategy)) {
            return false;
          }
          if (filter.status != null && trade.status != filter.status) {
            return false;
          }
          if (filter.side != null && trade.side != filter.side) return false;
          return true;
        })
        .toList(growable: false);
    return result..sort(
      (TradeJournalEntry first, TradeJournalEntry second) =>
          second.tradeTime.compareTo(first.tradeTime),
    );
  }

  static PerformanceSnapshot performance(
    Iterable<TradeJournalEntry> source,
    JournalSettings settings,
    JournalFilter filter, {
    DateTime? now,
  }) {
    final DateTime effectiveNow = now ?? DateTime.now();
    final _DateRange range = _range(filter.period, effectiveNow);
    final List<TradeJournalEntry> scoped = source
        .where((TradeJournalEntry trade) {
          if (filter.source != null && trade.source != filter.source) {
            return false;
          }
          final String symbol = normalizeJournalSymbol(filter.symbol);
          if (symbol.isNotEmpty && trade.symbol != symbol) return false;
          final String strategy = filter.strategy.trim().toLowerCase();
          if (strategy.isNotEmpty &&
              !trade.strategy.toLowerCase().contains(strategy)) {
            return false;
          }
          if (filter.status != null && trade.status != filter.status) {
            return false;
          }
          if (filter.side != null && trade.side != filter.side) return false;
          return true;
        })
        .toList(growable: false);
    final List<TradeJournalEntry> closed =
        scoped
            .where((TradeJournalEntry trade) => trade.isClosed)
            .toList(growable: false)
          ..sort(
            (TradeJournalEntry first, TradeJournalEntry second) =>
                _resultTime(first).compareTo(_resultTime(second)),
          );
    final List<TradeJournalEntry> selectedClosed = closed
        .where((TradeJournalEntry trade) => range.contains(_resultTime(trade)))
        .toList(growable: false);
    final int openTrades = scoped
        .where(
          (TradeJournalEntry trade) =>
              !trade.isClosed && range.contains(trade.tradeTime),
        )
        .length;
    final double realizedBefore = range.start == null
        ? 0.0
        : closed
              .where(
                (TradeJournalEntry trade) =>
                    _resultTime(trade).isBefore(range.start!),
              )
              .fold<double>(0.0, (double total, TradeJournalEntry trade) {
                return total + trade.netPnl;
              });
    final double openingBalance = settings.startingBalance + realizedBefore;
    double balance = openingBalance;
    double peak = balance;
    double maxDrawdown = 0.0;
    double maxDrawdownPercent = 0.0;
    final List<EquityPoint> equity = <EquityPoint>[];
    final DateTime openingTime =
        range.start ??
        (selectedClosed.isEmpty
            ? effectiveNow
            : _resultTime(selectedClosed.first));
    equity.add(
      EquityPoint(time: openingTime, balance: balance, tradeId: 'opening'),
    );
    for (final TradeJournalEntry trade in selectedClosed) {
      balance += trade.netPnl;
      if (balance > peak) peak = balance;
      final double drawdown = peak - balance;
      final double drawdownPercent = peak <= 0 ? 0.0 : drawdown / peak * 100.0;
      if (drawdown > maxDrawdown) maxDrawdown = drawdown;
      if (drawdownPercent > maxDrawdownPercent) {
        maxDrawdownPercent = drawdownPercent;
      }
      equity.add(
        EquityPoint(
          time: _resultTime(trade),
          balance: balance,
          tradeId: trade.id,
        ),
      );
    }
    final double netPnl = _sum(
      selectedClosed.map((TradeJournalEntry t) => t.netPnl),
    );
    final double netR = _sum(
      selectedClosed.map((TradeJournalEntry t) => t.resultR),
    );
    final List<TradeJournalEntry> wins = selectedClosed
        .where(
          (TradeJournalEntry trade) => trade.status == JournalTradeStatus.win,
        )
        .toList(growable: false);
    final List<TradeJournalEntry> losses = selectedClosed
        .where(
          (TradeJournalEntry trade) => trade.status == JournalTradeStatus.loss,
        )
        .toList(growable: false);
    final int breakEven = selectedClosed
        .where(
          (TradeJournalEntry trade) =>
              trade.status == JournalTradeStatus.breakEven,
        )
        .length;
    final double grossProfit = _sum(
      wins.map((TradeJournalEntry t) => t.netPnl),
    );
    final double grossLoss = _sum(
      losses.map((TradeJournalEntry t) => t.netPnl.abs()),
    );
    final (int winStreak, int lossStreak) = _streaks(selectedClosed);
    final TradeJournalEntry? best = _extreme(selectedClosed, best: true);
    final TradeJournalEntry? worst = _extreme(selectedClosed, best: false);
    final List<DailyJournalSummary> selectedDays = calendar(
      selectedClosed,
      settings: settings,
    );
    return PerformanceSnapshot(
      startingBalance: settings.startingBalance,
      openingBalance: openingBalance,
      currentBalance: balance,
      netPnl: netPnl,
      returnPercent: settings.startingBalance <= 0
          ? 0.0
          : netPnl / settings.startingBalance * 100.0,
      netR: netR,
      trades: selectedClosed.length,
      openTrades: openTrades,
      wins: wins.length,
      losses: losses.length,
      breakEven: breakEven,
      winRate: _percent(wins.length, selectedClosed.length),
      profitFactor: _profitFactor(grossProfit, grossLoss),
      maxDrawdown: maxDrawdown,
      maxDrawdownPercent: maxDrawdownPercent,
      averageR: _average(
        selectedClosed.map((TradeJournalEntry t) => t.resultR),
      ),
      averageWin: _average(wins.map((TradeJournalEntry t) => t.netPnl)),
      averageLoss: _average(losses.map((TradeJournalEntry t) => t.netPnl)),
      bestTrade: best,
      worstTrade: worst,
      bestDay: _extremeDay(selectedDays, best: true),
      worstDay: _extremeDay(selectedDays, best: false),
      largestWinStreak: winStreak,
      largestLossStreak: lossStreak,
      disciplineScore: disciplineScore(selectedClosed, settings: settings),
      equity: List<EquityPoint>.unmodifiable(equity),
    );
  }

  static List<DailyJournalSummary> calendar(
    Iterable<TradeJournalEntry> source, {
    TradeSource? sourceFilter,
    JournalSettings settings = const JournalSettings(),
  }) {
    final Map<String, List<TradeJournalEntry>> byDay =
        <String, List<TradeJournalEntry>>{};
    for (final TradeJournalEntry trade in source) {
      if (!trade.isClosed ||
          (sourceFilter != null && trade.source != sourceFilter)) {
        continue;
      }
      byDay
          .putIfAbsent(dateKey(trade.tradeTime), () => <TradeJournalEntry>[])
          .add(trade);
    }
    final List<DailyJournalSummary> result =
        byDay.entries
            .map<DailyJournalSummary>((
              MapEntry<String, List<TradeJournalEntry>> row,
            ) {
              final DateTime day = DateTime.parse(row.key);
              return _daily(day, row.value, settings);
            })
            .toList(growable: false)
          ..sort(
            (DailyJournalSummary first, DailyJournalSummary second) =>
                first.date.compareTo(second.date),
          );
    return result;
  }

  static List<JournalGroupPerformance> byStrategy(
    Iterable<TradeJournalEntry> source,
  ) => _group(source, (TradeJournalEntry trade) {
    return trade.strategy.trim().isEmpty
        ? 'Unspecified'
        : trade.strategy.trim();
  });

  static List<JournalGroupPerformance> byAsset(
    Iterable<TradeJournalEntry> source,
  ) => _group(source, (TradeJournalEntry trade) => trade.symbol);

  static List<JournalGroupPerformance> bySide(
    Iterable<TradeJournalEntry> source,
  ) => _group(
    source,
    (TradeJournalEntry trade) => trade.side.name.toUpperCase(),
  );

  static List<JournalGroupPerformance> bySource(
    Iterable<TradeJournalEntry> source,
  ) => _group(
    source,
    (TradeJournalEntry trade) => trade.source.name.toUpperCase(),
  );

  static List<JournalPeriodSummary> weekly(
    Iterable<TradeJournalEntry> source,
    JournalSettings settings,
  ) => _periodSummaries(source, settings, weekly: true);

  static List<JournalPeriodSummary> monthly(
    Iterable<TradeJournalEntry> source,
    JournalSettings settings,
  ) => _periodSummaries(source, settings, weekly: false);

  static int disciplineScore(
    Iterable<TradeJournalEntry> source, {
    JournalSettings settings = const JournalSettings(),
  }) {
    int penalty = 0;
    for (final TradeJournalEntry trade in source) {
      if (trade.tags.contains(TradeTag.revenge)) penalty += 15;
      if (trade.tags.contains(TradeTag.fomo)) penalty += 10;
      if (trade.tags.contains(TradeTag.noConfirmation)) penalty += 10;
      if (trade.tags.contains(TradeTag.badEntry)) penalty += 8;
      if (trade.tags.contains(TradeTag.early)) penalty += 5;
      if (trade.plannedRiskReward > 0 && trade.plannedRiskReward < 1.0) {
        penalty += 5;
      }
    }
    final double? dailyLimit = settings.dailyMaxLoss;
    if (dailyLimit != null && dailyLimit > 0) {
      final Map<String, double> pnlByDay = <String, double>{};
      for (final TradeJournalEntry trade in source.where(
        (TradeJournalEntry trade) => trade.isClosed,
      )) {
        final String key = dateKey(trade.tradeTime);
        pnlByDay[key] = (pnlByDay[key] ?? 0.0) + trade.netPnl;
      }
      for (final double pnl in pnlByDay.values) {
        if (pnl < -dailyLimit) penalty += 12;
      }
    }
    return (100 - penalty).clamp(0, 100);
  }

  static List<JournalGroupPerformance> _group(
    Iterable<TradeJournalEntry> source,
    String Function(TradeJournalEntry trade) keyOf,
  ) {
    final Map<String, List<TradeJournalEntry>> groups =
        <String, List<TradeJournalEntry>>{};
    for (final TradeJournalEntry trade in source.where(
      (TradeJournalEntry trade) => trade.isClosed,
    )) {
      groups.putIfAbsent(keyOf(trade), () => <TradeJournalEntry>[]).add(trade);
    }
    final List<JournalGroupPerformance> result =
        groups.entries
            .map<JournalGroupPerformance>((
              MapEntry<String, List<TradeJournalEntry>> row,
            ) {
              return _groupPerformance(row.key, row.value);
            })
            .toList(growable: false)
          ..sort(
            (JournalGroupPerformance first, JournalGroupPerformance second) =>
                second.netPnl.compareTo(first.netPnl),
          );
    return result;
  }

  static JournalGroupPerformance _groupPerformance(
    String label,
    List<TradeJournalEntry> trades,
  ) {
    final List<TradeJournalEntry> wins = trades
        .where((TradeJournalEntry trade) => trade.netPnl > 0)
        .toList(growable: false);
    final List<TradeJournalEntry> losses = trades
        .where((TradeJournalEntry trade) => trade.netPnl < 0)
        .toList(growable: false);
    final double profit = _sum(wins.map((TradeJournalEntry t) => t.netPnl));
    final double loss = _sum(
      losses.map((TradeJournalEntry t) => t.netPnl.abs()),
    );
    double equity = 0.0;
    double peak = 0.0;
    double drawdown = 0.0;
    final List<TradeJournalEntry> ordered = List<TradeJournalEntry>.of(trades)
      ..sort(
        (TradeJournalEntry first, TradeJournalEntry second) =>
            _resultTime(first).compareTo(_resultTime(second)),
      );
    for (final TradeJournalEntry trade in ordered) {
      equity += trade.netPnl;
      if (equity > peak) peak = equity;
      if (peak - equity > drawdown) drawdown = peak - equity;
    }
    return JournalGroupPerformance(
      label: label,
      trades: trades.length,
      wins: wins.length,
      losses: losses.length,
      netPnl: _sum(trades.map((TradeJournalEntry t) => t.netPnl)),
      netR: _sum(trades.map((TradeJournalEntry t) => t.resultR)),
      winRate: _percent(wins.length, trades.length),
      averageR: _average(trades.map((TradeJournalEntry t) => t.resultR)),
      profitFactor: _profitFactor(profit, loss),
      drawdown: drawdown,
    );
  }

  static DailyJournalSummary _daily(
    DateTime day,
    List<TradeJournalEntry> trades,
    JournalSettings settings,
  ) {
    final List<TradeJournalEntry> ordered = List<TradeJournalEntry>.of(trades)
      ..sort(
        (TradeJournalEntry first, TradeJournalEntry second) =>
            _resultTime(first).compareTo(_resultTime(second)),
      );
    final List<TradeJournalEntry> wins = ordered
        .where((TradeJournalEntry trade) => trade.netPnl > 0)
        .toList(growable: false);
    final List<TradeJournalEntry> losses = ordered
        .where((TradeJournalEntry trade) => trade.netPnl < 0)
        .toList(growable: false);
    double equity = 0.0;
    double peak = 0.0;
    double drawdown = 0.0;
    for (final TradeJournalEntry trade in ordered) {
      equity += trade.netPnl;
      if (equity > peak) peak = equity;
      if (peak - equity > drawdown) drawdown = peak - equity;
    }
    return DailyJournalSummary(
      date: DateTime(day.year, day.month, day.day),
      trades: List<TradeJournalEntry>.unmodifiable(ordered),
      wins: wins.length,
      losses: losses.length,
      breakEven: ordered.length - wins.length - losses.length,
      netPnl: _sum(ordered.map((TradeJournalEntry t) => t.netPnl)),
      netR: _sum(ordered.map((TradeJournalEntry t) => t.resultR)),
      winRate: _percent(wins.length, ordered.length),
      profitFactor: _profitFactor(
        _sum(wins.map((TradeJournalEntry t) => t.netPnl)),
        _sum(losses.map((TradeJournalEntry t) => t.netPnl.abs())),
      ),
      bestTrade: _extreme(ordered, best: true),
      worstTrade: _extreme(ordered, best: false),
      dailyDrawdown: drawdown,
      disciplineScore: disciplineScore(ordered, settings: settings),
    );
  }

  static List<JournalPeriodSummary> _periodSummaries(
    Iterable<TradeJournalEntry> source,
    JournalSettings settings, {
    required bool weekly,
  }) {
    final Map<String, List<TradeJournalEntry>> grouped =
        <String, List<TradeJournalEntry>>{};
    final Map<String, DateTime> starts = <String, DateTime>{};
    for (final TradeJournalEntry trade in source.where(
      (TradeJournalEntry trade) => trade.isClosed,
    )) {
      final DateTime local = trade.tradeTime.toLocal();
      final DateTime start = weekly
          ? DateTime(
              local.year,
              local.month,
              local.day,
            ).subtract(Duration(days: local.weekday - DateTime.monday))
          : DateTime(local.year, local.month);
      final String key = dateKey(start);
      starts[key] = start;
      grouped.putIfAbsent(key, () => <TradeJournalEntry>[]).add(trade);
    }
    final List<JournalPeriodSummary> result =
        grouped.entries
            .map<JournalPeriodSummary>((
              MapEntry<String, List<TradeJournalEntry>> row,
            ) {
              final DateTime start = starts[row.key]!;
              final DateTime end = weekly
                  ? start.add(const Duration(days: 6))
                  : DateTime(start.year, start.month + 1, 0);
              final List<DailyJournalSummary> days = calendar(
                row.value,
                settings: settings,
              );
              final List<JournalGroupPerformance> strategies = byStrategy(
                row.value,
              );
              final List<JournalGroupPerformance> assets = byAsset(row.value);
              final List<JournalPeriodSummary> weeks = weekly
                  ? const <JournalPeriodSummary>[]
                  : JournalPerformanceEngine.weekly(row.value, settings);
              final List<TradeJournalEntry> ordered =
                  List<TradeJournalEntry>.of(row.value)..sort(
                    (TradeJournalEntry first, TradeJournalEntry second) =>
                        _resultTime(first).compareTo(_resultTime(second)),
                  );
              final JournalGroupPerformance total = _groupPerformance(
                'total',
                ordered,
              );
              return JournalPeriodSummary(
                start: start,
                end: end,
                trades: ordered.length,
                netPnl: total.netPnl,
                netR: total.netR,
                winRate: total.winRate,
                profitFactor: total.profitFactor,
                drawdown: total.drawdown,
                bestDay: _extremeDay(days, best: true),
                worstDay: _extremeDay(days, best: false),
                bestWeek: _extremeWeek(weeks, best: true),
                worstWeek: _extremeWeek(weeks, best: false),
                bestStrategy: strategies.isEmpty ? '' : strategies.first.label,
                worstStrategy: strategies.isEmpty ? '' : strategies.last.label,
                bestAsset: assets.isEmpty ? '' : assets.first.label,
                worstAsset: assets.isEmpty ? '' : assets.last.label,
                mostCommonMistake: _mostCommonMistake(ordered),
                disciplineScore: disciplineScore(ordered, settings: settings),
              );
            })
            .toList(growable: false)
          ..sort(
            (JournalPeriodSummary first, JournalPeriodSummary second) =>
                second.start.compareTo(first.start),
          );
    return result;
  }

  static TradeJournalEntry? _extreme(
    Iterable<TradeJournalEntry> trades, {
    required bool best,
  }) {
    TradeJournalEntry? result;
    for (final TradeJournalEntry trade in trades) {
      if (result == null ||
          (best
              ? trade.netPnl > result.netPnl
              : trade.netPnl < result.netPnl)) {
        result = trade;
      }
    }
    return result;
  }

  static DailyJournalSummary? _extremeDay(
    Iterable<DailyJournalSummary> days, {
    required bool best,
  }) {
    DailyJournalSummary? result;
    for (final DailyJournalSummary day in days) {
      if (result == null ||
          (best ? day.netPnl > result.netPnl : day.netPnl < result.netPnl)) {
        result = day;
      }
    }
    return result;
  }

  static JournalWeekHighlight? _extremeWeek(
    Iterable<JournalPeriodSummary> weeks, {
    required bool best,
  }) {
    JournalPeriodSummary? result;
    for (final JournalPeriodSummary week in weeks) {
      if (result == null ||
          (best ? week.netPnl > result.netPnl : week.netPnl < result.netPnl)) {
        result = week;
      }
    }
    return result == null
        ? null
        : JournalWeekHighlight(
            start: result.start,
            end: result.end,
            netPnl: result.netPnl,
          );
  }

  static TradeTag? _mostCommonMistake(Iterable<TradeJournalEntry> trades) {
    const Set<TradeTag> mistakes = <TradeTag>{
      TradeTag.badEntry,
      TradeTag.early,
      TradeTag.late,
      TradeTag.fomo,
      TradeTag.revenge,
      TradeTag.noConfirmation,
    };
    final Map<TradeTag, int> counts = <TradeTag, int>{};
    for (final TradeJournalEntry trade in trades) {
      for (final TradeTag tag in trade.tags.where(mistakes.contains)) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    TradeTag? result;
    int maximum = 0;
    for (final MapEntry<TradeTag, int> row in counts.entries) {
      if (row.value > maximum) {
        maximum = row.value;
        result = row.key;
      }
    }
    return result;
  }

  static (int, int) _streaks(List<TradeJournalEntry> ordered) {
    int currentWins = 0;
    int currentLosses = 0;
    int maximumWins = 0;
    int maximumLosses = 0;
    for (final TradeJournalEntry trade in ordered) {
      if (trade.status == JournalTradeStatus.win) {
        currentWins++;
        currentLosses = 0;
      } else if (trade.status == JournalTradeStatus.loss) {
        currentLosses++;
        currentWins = 0;
      } else {
        currentWins = 0;
        currentLosses = 0;
      }
      if (currentWins > maximumWins) maximumWins = currentWins;
      if (currentLosses > maximumLosses) maximumLosses = currentLosses;
    }
    return (maximumWins, maximumLosses);
  }

  static DateTime _resultTime(TradeJournalEntry trade) =>
      (trade.exitTime ?? trade.tradeTime).toLocal();

  static double _profitFactor(double profit, double loss) {
    if (loss == 0.0) return profit > 0 ? double.infinity : 0.0;
    return profit / loss;
  }

  static double _sum(Iterable<double> values) =>
      values.fold<double>(0.0, (double total, double value) => total + value);

  static double _average(Iterable<double> values) {
    double total = 0.0;
    int count = 0;
    for (final double value in values) {
      total += value;
      count++;
    }
    return count == 0 ? 0.0 : total / count;
  }

  static double _percent(int part, int total) =>
      total == 0 ? 0.0 : part / total * 100.0;

  static _DateRange _range(PerformancePeriod period, DateTime now) {
    final DateTime local = now.toLocal();
    final DateTime today = DateTime(local.year, local.month, local.day);
    final DateTime end = today.add(const Duration(days: 1));
    return switch (period) {
      PerformancePeriod.today => _DateRange(today, end),
      PerformancePeriod.sevenDays => _DateRange(
        today.subtract(const Duration(days: 6)),
        end,
      ),
      PerformancePeriod.thirtyDays => _DateRange(
        today.subtract(const Duration(days: 29)),
        end,
      ),
      PerformancePeriod.thisMonth => _DateRange(
        DateTime(today.year, today.month),
        end,
      ),
      PerformancePeriod.threeMonths => _DateRange(
        DateTime(today.year, today.month - 2),
        end,
      ),
      PerformancePeriod.sixMonths => _DateRange(
        DateTime(today.year, today.month - 5),
        end,
      ),
      PerformancePeriod.oneYear => _DateRange(
        DateTime(today.year - 1, today.month, today.day),
        end,
      ),
      PerformancePeriod.all => _DateRange(null, end),
    };
  }
}

class _DateRange {
  const _DateRange(this.start, this.end);

  final DateTime? start;
  final DateTime end;

  bool contains(DateTime value) {
    final DateTime local = value.toLocal();
    return (start == null || !local.isBefore(start!)) && local.isBefore(end);
  }
}
