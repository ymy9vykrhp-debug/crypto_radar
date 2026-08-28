import '../utils/exchange_decimal.dart';

enum TradeSource { manual, paper, bybitDemo, live }

enum JournalTradeSide { long, short }

enum JournalTradeStatus { open, win, loss, breakEven }

enum EntryReason {
  radarSignal,
  manualAnalysis,
  telegramSignal,
  liquiditySweep,
  falseBreakout,
  bos,
  choch,
  fvg,
  orderBlock,
  supportResistance,
  news,
  other,
}

enum TradeTag {
  goodEntry,
  badEntry,
  early,
  late,
  fomo,
  revenge,
  noConfirmation,
  liquiditySweep,
  falseBreakout,
  bos,
  choch,
  fvg,
  orderBlock,
  news,
  manualIdea,
}

enum TradingNoteCategory { idea, observation, mistake, strategy, market, other }

enum JournalReviewPeriod { day, week, month }

enum PerformancePeriod {
  today,
  sevenDays,
  thirtyDays,
  thisMonth,
  threeMonths,
  sixMonths,
  oneYear,
  all,
}

class TradeContextSnapshot {
  const TradeContextSnapshot({
    this.strategyVersion = 'unknown',
    this.signalEngineVersion = 'unknown',
    this.dataEngineVersion = 'unknown',
    this.riskPercent = 0.0,
    this.radarSignalId = '',
    this.radarDecision = '',
    this.setupStage = '',
    this.executionReference = '',
  });

  final String strategyVersion;
  final String signalEngineVersion;
  final String dataEngineVersion;
  final double riskPercent;
  final String radarSignalId;
  final String radarDecision;
  final String setupStage;
  final String executionReference;

  Map<String, Object?> toJson() => <String, Object?>{
    'strategyVersion': strategyVersion,
    'signalEngineVersion': signalEngineVersion,
    'dataEngineVersion': dataEngineVersion,
    'riskPercent': ExchangeDecimal.canonical(riskPercent),
    'radarSignalId': radarSignalId,
    'radarDecision': radarDecision,
    'setupStage': setupStage,
    'executionReference': executionReference,
  };

  factory TradeContextSnapshot.fromJson(Object? raw) {
    final Map<String, dynamic> json = raw is Map<String, dynamic>
        ? raw
        : <String, dynamic>{};
    return TradeContextSnapshot(
      strategyVersion: json['strategyVersion']?.toString() ?? 'unknown',
      signalEngineVersion: json['signalEngineVersion']?.toString() ?? 'unknown',
      dataEngineVersion: json['dataEngineVersion']?.toString() ?? 'unknown',
      riskPercent: _double(json['riskPercent']),
      radarSignalId: json['radarSignalId']?.toString() ?? '',
      radarDecision: json['radarDecision']?.toString() ?? '',
      setupStage: json['setupStage']?.toString() ?? '',
      executionReference: json['executionReference']?.toString() ?? '',
    );
  }
}

class TradeJournalEntry {
  const TradeJournalEntry({
    required this.id,
    required this.source,
    required this.createdAt,
    required this.tradeTime,
    required this.symbol,
    required this.side,
    required this.plannedEntry,
    required this.stopLoss,
    required this.tp1,
    required this.tp2,
    required this.actualEntry,
    required this.positionSize,
    required this.margin,
    required this.leverage,
    required this.fees,
    required this.strategy,
    required this.timeframe,
    required this.status,
    required this.entryReason,
    required this.entryReasonText,
    required this.myNotes,
    required this.tags,
    required this.whatWasGood,
    required this.whatWasWrong,
    required this.whatShouldChange,
    required this.useForStrategyResearch,
    required this.contextSnapshot,
    this.tp3,
    this.actualExit,
    this.exitTime,
    this.mfeR,
    this.maeR,
    this.screenshotReference = '',
    this.chartSnapshotReference = '',
    this.replayReference = '',
  });

  factory TradeJournalEntry.manual({
    required String id,
    required DateTime now,
    required DateTime tradeTime,
    required String symbol,
    required JournalTradeSide side,
    required double plannedEntry,
    required double stopLoss,
    required double tp1,
    required double tp2,
    required double actualEntry,
    required double positionSize,
    required double margin,
    required double leverage,
    required double fees,
    required String strategy,
    required String timeframe,
    required EntryReason entryReason,
    String entryReasonText = '',
    String myNotes = '',
    Set<TradeTag> tags = const <TradeTag>{},
    double? tp3,
    double? actualExit,
    DateTime? exitTime,
    String whatWasGood = '',
    String whatWasWrong = '',
    String whatShouldChange = '',
    bool useForStrategyResearch = false,
    TradeContextSnapshot contextSnapshot = const TradeContextSnapshot(),
  }) {
    final TradeJournalEntry entry = TradeJournalEntry(
      id: id,
      source: TradeSource.manual,
      createdAt: now,
      tradeTime: tradeTime,
      symbol: normalizeJournalSymbol(symbol),
      side: side,
      plannedEntry: plannedEntry,
      stopLoss: stopLoss,
      tp1: tp1,
      tp2: tp2,
      tp3: tp3,
      actualEntry: actualEntry,
      actualExit: actualExit,
      exitTime: actualExit == null ? null : exitTime ?? now,
      positionSize: positionSize,
      margin: margin,
      leverage: leverage,
      fees: fees,
      strategy: strategy.trim(),
      timeframe: timeframe.trim(),
      status: actualExit == null
          ? JournalTradeStatus.open
          : JournalTradeStatus.breakEven,
      entryReason: entryReason,
      entryReasonText: entryReasonText.trim(),
      myNotes: myNotes.trim(),
      tags: Set<TradeTag>.unmodifiable(tags),
      whatWasGood: whatWasGood.trim(),
      whatWasWrong: whatWasWrong.trim(),
      whatShouldChange: whatShouldChange.trim(),
      useForStrategyResearch: useForStrategyResearch,
      contextSnapshot: contextSnapshot,
    );
    return entry.withCalculatedStatus();
  }

  final String id;
  final TradeSource source;
  final DateTime createdAt;
  final DateTime tradeTime;
  final String symbol;
  final JournalTradeSide side;
  final double plannedEntry;
  final double stopLoss;
  final double tp1;
  final double tp2;
  final double? tp3;
  final double actualEntry;
  final double? actualExit;
  final DateTime? exitTime;
  final double positionSize;
  final double margin;
  final double leverage;
  final double fees;
  final String strategy;
  final String timeframe;
  final JournalTradeStatus status;
  final EntryReason entryReason;
  final String entryReasonText;
  final String myNotes;
  final Set<TradeTag> tags;
  final String whatWasGood;
  final String whatWasWrong;
  final String whatShouldChange;
  final bool useForStrategyResearch;
  final TradeContextSnapshot contextSnapshot;
  final double? mfeR;
  final double? maeR;
  final String screenshotReference;
  final String chartSnapshotReference;
  final String replayReference;

  bool get isClosed => actualExit != null && status != JournalTradeStatus.open;
  bool get isEditable => source == TradeSource.manual;
  double get effectiveEntry => actualEntry > 0 ? actualEntry : plannedEntry;
  double get effectivePositionSize => positionSize > 0
      ? positionSize
      : margin > 0 && leverage > 0
      ? margin * leverage
      : 0.0;
  double get quantity =>
      effectiveEntry > 0 ? effectivePositionSize / effectiveEntry : 0.0;
  double get stopDistancePercent => effectiveEntry > 0
      ? (effectiveEntry - stopLoss).abs() / effectiveEntry * 100.0
      : 0.0;
  double get plannedRiskAmount =>
      effectivePositionSize * stopDistancePercent / 100.0;
  double get plannedRiskReward {
    final double risk = (effectiveEntry - stopLoss).abs();
    if (risk <= 0) return 0.0;
    return (tp2 - effectiveEntry).abs() / risk;
  }

  double get grossPnl {
    final double? exit = actualExit;
    if (exit == null || effectiveEntry <= 0 || effectivePositionSize <= 0) {
      return 0.0;
    }
    final double move = side == JournalTradeSide.long
        ? (exit - effectiveEntry) / effectiveEntry
        : (effectiveEntry - exit) / effectiveEntry;
    return effectivePositionSize * move;
  }

  double get netPnl => isClosed ? grossPnl - fees.abs() : 0.0;
  double get pnlPercent =>
      isClosed && margin > 0 ? netPnl / margin * 100.0 : 0.0;
  double get resultR =>
      isClosed && plannedRiskAmount > 0 ? netPnl / plannedRiskAmount : 0.0;

  TradeJournalEntry withCalculatedStatus() {
    if (actualExit == null) {
      return status == JournalTradeStatus.open
          ? this
          : copyWith(status: JournalTradeStatus.open, clearExitTime: true);
    }
    final double pnl = grossPnl - fees.abs();
    final double epsilon = effectivePositionSize.abs() * 0.0000001;
    final JournalTradeStatus calculated = pnl > epsilon
        ? JournalTradeStatus.win
        : pnl < -epsilon
        ? JournalTradeStatus.loss
        : JournalTradeStatus.breakEven;
    return status == calculated ? this : copyWith(status: calculated);
  }

  TradeJournalEntry copyWith({
    String? id,
    TradeSource? source,
    DateTime? createdAt,
    DateTime? tradeTime,
    String? symbol,
    JournalTradeSide? side,
    double? plannedEntry,
    double? stopLoss,
    double? tp1,
    double? tp2,
    double? tp3,
    bool clearTp3 = false,
    double? actualEntry,
    double? actualExit,
    bool clearActualExit = false,
    DateTime? exitTime,
    bool clearExitTime = false,
    double? positionSize,
    double? margin,
    double? leverage,
    double? fees,
    String? strategy,
    String? timeframe,
    JournalTradeStatus? status,
    EntryReason? entryReason,
    String? entryReasonText,
    String? myNotes,
    Set<TradeTag>? tags,
    String? whatWasGood,
    String? whatWasWrong,
    String? whatShouldChange,
    bool? useForStrategyResearch,
    TradeContextSnapshot? contextSnapshot,
    double? mfeR,
    double? maeR,
    String? screenshotReference,
    String? chartSnapshotReference,
    String? replayReference,
  }) {
    return TradeJournalEntry(
      id: id ?? this.id,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      tradeTime: tradeTime ?? this.tradeTime,
      symbol: normalizeJournalSymbol(symbol ?? this.symbol),
      side: side ?? this.side,
      plannedEntry: plannedEntry ?? this.plannedEntry,
      stopLoss: stopLoss ?? this.stopLoss,
      tp1: tp1 ?? this.tp1,
      tp2: tp2 ?? this.tp2,
      tp3: clearTp3 ? null : tp3 ?? this.tp3,
      actualEntry: actualEntry ?? this.actualEntry,
      actualExit: clearActualExit ? null : actualExit ?? this.actualExit,
      exitTime: clearExitTime ? null : exitTime ?? this.exitTime,
      positionSize: positionSize ?? this.positionSize,
      margin: margin ?? this.margin,
      leverage: leverage ?? this.leverage,
      fees: fees ?? this.fees,
      strategy: strategy ?? this.strategy,
      timeframe: timeframe ?? this.timeframe,
      status: status ?? this.status,
      entryReason: entryReason ?? this.entryReason,
      entryReasonText: entryReasonText ?? this.entryReasonText,
      myNotes: myNotes ?? this.myNotes,
      tags: Set<TradeTag>.unmodifiable(tags ?? this.tags),
      whatWasGood: whatWasGood ?? this.whatWasGood,
      whatWasWrong: whatWasWrong ?? this.whatWasWrong,
      whatShouldChange: whatShouldChange ?? this.whatShouldChange,
      useForStrategyResearch:
          useForStrategyResearch ?? this.useForStrategyResearch,
      contextSnapshot: contextSnapshot ?? this.contextSnapshot,
      mfeR: mfeR ?? this.mfeR,
      maeR: maeR ?? this.maeR,
      screenshotReference: screenshotReference ?? this.screenshotReference,
      chartSnapshotReference:
          chartSnapshotReference ?? this.chartSnapshotReference,
      replayReference: replayReference ?? this.replayReference,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'source': source.name,
    'createdAt': createdAt.toIso8601String(),
    'tradeTime': tradeTime.toIso8601String(),
    'symbol': symbol,
    'side': side.name,
    'plannedEntry': ExchangeDecimal.canonical(plannedEntry),
    'stopLoss': ExchangeDecimal.canonical(stopLoss),
    'tp1': ExchangeDecimal.canonical(tp1),
    'tp2': ExchangeDecimal.canonical(tp2),
    'tp3': ExchangeDecimal.canonicalNullable(tp3),
    'actualEntry': ExchangeDecimal.canonical(actualEntry),
    'actualExit': ExchangeDecimal.canonicalNullable(actualExit),
    'exitTime': exitTime?.toIso8601String(),
    'positionSize': ExchangeDecimal.canonical(positionSize),
    'margin': ExchangeDecimal.canonical(margin),
    'leverage': ExchangeDecimal.canonical(leverage),
    'fees': ExchangeDecimal.canonical(fees),
    'strategy': strategy,
    'timeframe': timeframe,
    'status': status.name,
    'entryReason': entryReason.name,
    'entryReasonText': entryReasonText,
    'myNotes': myNotes,
    'tags': tags.map((TradeTag tag) => tag.name).toList(growable: false),
    'whatWasGood': whatWasGood,
    'whatWasWrong': whatWasWrong,
    'whatShouldChange': whatShouldChange,
    'useForStrategyResearch': useForStrategyResearch,
    'contextSnapshot': contextSnapshot.toJson(),
    'mfeR': ExchangeDecimal.canonicalNullable(mfeR),
    'maeR': ExchangeDecimal.canonicalNullable(maeR),
    'screenshotReference': screenshotReference,
    'chartSnapshotReference': chartSnapshotReference,
    'replayReference': replayReference,
  };

  factory TradeJournalEntry.fromJson(Map<String, dynamic> json) {
    final TradeJournalEntry entry = TradeJournalEntry(
      id: json['id']?.toString() ?? '',
      source: _enumValue(
        TradeSource.values,
        json['source'],
        TradeSource.manual,
      ),
      createdAt: _date(json['createdAt']),
      tradeTime: _date(json['tradeTime']),
      symbol: normalizeJournalSymbol(json['symbol']?.toString() ?? ''),
      side: _enumValue(
        JournalTradeSide.values,
        json['side'],
        JournalTradeSide.long,
      ),
      plannedEntry: _double(json['plannedEntry']),
      stopLoss: _double(json['stopLoss']),
      tp1: _double(json['tp1']),
      tp2: _double(json['tp2']),
      tp3: _nullableDouble(json['tp3']),
      actualEntry: _double(json['actualEntry']),
      actualExit: _nullableDouble(json['actualExit']),
      exitTime: _nullableDate(json['exitTime']),
      positionSize: _double(json['positionSize']),
      margin: _double(json['margin']),
      leverage: _double(json['leverage']),
      fees: _double(json['fees']),
      strategy: json['strategy']?.toString() ?? '',
      timeframe: json['timeframe']?.toString() ?? '',
      status: _enumValue(
        JournalTradeStatus.values,
        json['status'],
        JournalTradeStatus.open,
      ),
      entryReason: _enumValue(
        EntryReason.values,
        json['entryReason'],
        EntryReason.other,
      ),
      entryReasonText: json['entryReasonText']?.toString() ?? '',
      myNotes: json['myNotes']?.toString() ?? '',
      tags: Set<TradeTag>.unmodifiable(_enumSet(TradeTag.values, json['tags'])),
      whatWasGood: json['whatWasGood']?.toString() ?? '',
      whatWasWrong: json['whatWasWrong']?.toString() ?? '',
      whatShouldChange: json['whatShouldChange']?.toString() ?? '',
      useForStrategyResearch: json['useForStrategyResearch'] == true,
      contextSnapshot: TradeContextSnapshot.fromJson(json['contextSnapshot']),
      mfeR: _nullableDouble(json['mfeR']),
      maeR: _nullableDouble(json['maeR']),
      screenshotReference: json['screenshotReference']?.toString() ?? '',
      chartSnapshotReference: json['chartSnapshotReference']?.toString() ?? '',
      replayReference: json['replayReference']?.toString() ?? '',
    );
    return entry.withCalculatedStatus();
  }
}

class TradingNote {
  const TradingNote({
    required this.id,
    required this.createdAt,
    required this.date,
    required this.category,
    required this.text,
  });

  final String id;
  final DateTime createdAt;
  final DateTime date;
  final TradingNoteCategory category;
  final String text;

  TradingNote copyWith({
    DateTime? date,
    TradingNoteCategory? category,
    String? text,
  }) => TradingNote(
    id: id,
    createdAt: createdAt,
    date: date ?? this.date,
    category: category ?? this.category,
    text: text ?? this.text,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'date': date.toIso8601String(),
    'category': category.name,
    'text': text,
  };

  factory TradingNote.fromJson(Map<String, dynamic> json) => TradingNote(
    id: json['id']?.toString() ?? '',
    createdAt: _date(json['createdAt']),
    date: _date(json['date']),
    category: _enumValue(
      TradingNoteCategory.values,
      json['category'],
      TradingNoteCategory.other,
    ),
    text: json['text']?.toString() ?? '',
  );
}

class JournalReviewNote {
  const JournalReviewNote({
    required this.period,
    required this.periodStart,
    required this.text,
    required this.updatedAt,
  });

  final JournalReviewPeriod period;
  final DateTime periodStart;
  final String text;
  final DateTime updatedAt;

  String get id => '${period.name}:${dateKey(periodStart)}';

  Map<String, Object?> toJson() => <String, Object?>{
    'period': period.name,
    'periodStart': periodStart.toIso8601String(),
    'text': text,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory JournalReviewNote.fromJson(Map<String, dynamic> json) =>
      JournalReviewNote(
        period: _enumValue(
          JournalReviewPeriod.values,
          json['period'],
          JournalReviewPeriod.day,
        ),
        periodStart: _date(json['periodStart']),
        text: json['text']?.toString() ?? '',
        updatedAt: _date(json['updatedAt']),
      );
}

class JournalSettings {
  const JournalSettings({
    this.startingBalance = 0.0,
    this.dailyMaxLoss,
    this.weeklyMaxLoss,
    this.dailyTarget,
  });

  final double startingBalance;
  final double? dailyMaxLoss;
  final double? weeklyMaxLoss;
  final double? dailyTarget;

  JournalSettings copyWith({
    double? startingBalance,
    double? dailyMaxLoss,
    double? weeklyMaxLoss,
    double? dailyTarget,
    bool clearDailyMaxLoss = false,
    bool clearWeeklyMaxLoss = false,
    bool clearDailyTarget = false,
  }) => JournalSettings(
    startingBalance: startingBalance ?? this.startingBalance,
    dailyMaxLoss: clearDailyMaxLoss ? null : dailyMaxLoss ?? this.dailyMaxLoss,
    weeklyMaxLoss: clearWeeklyMaxLoss
        ? null
        : weeklyMaxLoss ?? this.weeklyMaxLoss,
    dailyTarget: clearDailyTarget ? null : dailyTarget ?? this.dailyTarget,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'startingBalance': ExchangeDecimal.canonical(startingBalance),
    'dailyMaxLoss': ExchangeDecimal.canonicalNullable(dailyMaxLoss),
    'weeklyMaxLoss': ExchangeDecimal.canonicalNullable(weeklyMaxLoss),
    'dailyTarget': ExchangeDecimal.canonicalNullable(dailyTarget),
  };

  factory JournalSettings.fromJson(Map<String, dynamic> json) =>
      JournalSettings(
        startingBalance: _double(json['startingBalance']),
        dailyMaxLoss: _nullableDouble(json['dailyMaxLoss']),
        weeklyMaxLoss: _nullableDouble(json['weeklyMaxLoss']),
        dailyTarget: _nullableDouble(json['dailyTarget']),
      );
}

String normalizeJournalSymbol(String raw) {
  String value = raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (value.isEmpty || value.endsWith('USDT')) return value;
  return '${value}USDT';
}

String dateKey(DateTime value) {
  final DateTime local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

T _enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
  final String name = raw?.toString() ?? '';
  for (final T value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

Set<T> _enumSet<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! List<dynamic>) return <T>{};
  return raw
      .map<T?>((dynamic item) {
        final String name = item.toString();
        for (final T value in values) {
          if (value.name == name) return value;
        }
        return null;
      })
      .whereType<T>()
      .toSet();
}

DateTime _date(Object? raw) =>
    DateTime.tryParse(raw?.toString() ?? '') ??
    DateTime.fromMillisecondsSinceEpoch(0);

DateTime? _nullableDate(Object? raw) =>
    raw == null ? null : DateTime.tryParse(raw.toString());

double _double(Object? raw) =>
    raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0.0;

double? _nullableDouble(Object? raw) {
  if (raw == null || '$raw'.trim().isEmpty) return null;
  return raw is num ? raw.toDouble() : double.tryParse('$raw');
}
