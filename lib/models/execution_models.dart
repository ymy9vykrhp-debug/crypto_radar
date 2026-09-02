import 'market_models.dart';

enum SignalStage {
  setupFound,
  waitForZone,
  waitForTrigger,
  entryConfirmed,
  inPosition,
  tp1Hit,
  tp2Hit,
  stopped,
  cancelled,
  expired,
}

extension SignalStageText on SignalStage {
  String get code {
    switch (this) {
      case SignalStage.setupFound:
        return 'SETUP_FOUND';
      case SignalStage.waitForZone:
        return 'WAIT_FOR_ZONE';
      case SignalStage.waitForTrigger:
        return 'WAIT_FOR_TRIGGER';
      case SignalStage.entryConfirmed:
        return 'ENTRY_CONFIRMED';
      case SignalStage.inPosition:
        return 'IN_POSITION';
      case SignalStage.tp1Hit:
        return 'TP1_HIT';
      case SignalStage.tp2Hit:
        return 'TP2_HIT';
      case SignalStage.stopped:
        return 'STOPPED';
      case SignalStage.cancelled:
        return 'CANCELLED';
      case SignalStage.expired:
        return 'EXPIRED';
    }
  }

  bool get isWaiting =>
      this == SignalStage.setupFound ||
      this == SignalStage.waitForZone ||
      this == SignalStage.waitForTrigger ||
      this == SignalStage.entryConfirmed;
}

enum EntryMode { aggressive, confirmed }

extension EntryModeText on EntryMode {
  String get label =>
      this == EntryMode.aggressive ? 'AGGRESSIVE ENTRY' : 'CONFIRMED ENTRY';
}

enum EntryVariant {
  immediate,
  zone,
  correctionEnd,
  bosConfirmation,
  falseBreakoutReclaim,
  falseBreakoutBosRetest,
}

extension EntryVariantText on EntryVariant {
  String get label {
    switch (this) {
      case EntryVariant.immediate:
        return 'Immediate Entry';
      case EntryVariant.zone:
        return 'Entry at Zone';
      case EntryVariant.correctionEnd:
        return 'Wait Correction End';
      case EntryVariant.bosConfirmation:
        return 'BOS Confirmation';
      case EntryVariant.falseBreakoutReclaim:
        return 'False Breakout + Reclaim';
      case EntryVariant.falseBreakoutBosRetest:
        return 'False Breakout + BOS + Retest';
    }
  }

  EntryMode get mode =>
      this == EntryVariant.immediate || this == EntryVariant.zone
      ? EntryMode.aggressive
      : EntryMode.confirmed;
}

enum StopVariant { structural, structuralAtr, structuralWick }

extension StopVariantText on StopVariant {
  String get label {
    switch (this) {
      case StopVariant.structural:
        return 'Structural Stop';
      case StopVariant.structuralAtr:
        return 'Structural + ATR Buffer';
      case StopVariant.structuralWick:
        return 'Structural + Wick Buffer';
    }
  }
}

class ExecutionProfile {
  const ExecutionProfile({
    required this.id,
    required this.label,
    required this.entryVariant,
    required this.stopVariant,
    this.isPrimary = false,
  });

  final String id;
  final String label;
  final EntryVariant entryVariant;
  final StopVariant stopVariant;
  final bool isPrimary;

  static const List<ExecutionProfile> backtestProfiles = <ExecutionProfile>[
    ExecutionProfile(
      id: 'immediate_atr',
      label: 'Immediate Entry',
      entryVariant: EntryVariant.immediate,
      stopVariant: StopVariant.structuralAtr,
    ),
    ExecutionProfile(
      id: 'zone_atr',
      label: 'Entry at Zone',
      entryVariant: EntryVariant.zone,
      stopVariant: StopVariant.structuralAtr,
    ),
    ExecutionProfile(
      id: 'correction_atr',
      label: 'Wait Correction End',
      entryVariant: EntryVariant.correctionEnd,
      stopVariant: StopVariant.structuralAtr,
    ),
    ExecutionProfile(
      id: 'bos_atr',
      label: 'BOS Confirmation',
      entryVariant: EntryVariant.bosConfirmation,
      stopVariant: StopVariant.structuralAtr,
      isPrimary: true,
    ),
    ExecutionProfile(
      id: 'false_breakout_reclaim_atr',
      label: 'False Breakout + Reclaim',
      entryVariant: EntryVariant.falseBreakoutReclaim,
      stopVariant: StopVariant.structuralAtr,
    ),
    ExecutionProfile(
      id: 'false_breakout_bos_retest_atr',
      label: 'False Breakout + BOS + Retest',
      entryVariant: EntryVariant.falseBreakoutBosRetest,
      stopVariant: StopVariant.structuralAtr,
    ),
    ExecutionProfile(
      id: 'bos_structural',
      label: 'BOS + Structural Stop',
      entryVariant: EntryVariant.bosConfirmation,
      stopVariant: StopVariant.structural,
    ),
    ExecutionProfile(
      id: 'bos_wick',
      label: 'BOS + Wick Buffer',
      entryVariant: EntryVariant.bosConfirmation,
      stopVariant: StopVariant.structuralWick,
    ),
  ];
}

enum FalseBreakoutState { none, possible, confirmed }

extension FalseBreakoutStateText on FalseBreakoutState {
  String get code {
    switch (this) {
      case FalseBreakoutState.none:
        return 'NONE';
      case FalseBreakoutState.possible:
        return 'FALSE_BREAKOUT_POSSIBLE';
      case FalseBreakoutState.confirmed:
        return 'FALSE_BREAKOUT_CONFIRMED';
    }
  }
}

class SignalQualityScores {
  const SignalQualityScores({
    required this.direction,
    required this.entry,
    required this.stop,
    required this.risk,
    this.location = 0,
    this.liquidity = 0,
    this.data = 0,
    this.setup = 0,
  });

  static const SignalQualityScores unrated = SignalQualityScores(
    direction: 0,
    entry: 0,
    stop: 0,
    risk: 0,
  );

  final int direction;
  final int entry;
  final int stop;
  final int risk;
  final int location;
  final int liquidity;
  final int data;
  final int setup;

  String get riskLabel {
    if (risk >= 75) {
      return 'GOOD';
    }
    if (risk >= 55) {
      return 'ACCEPTABLE';
    }
    return 'POOR';
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'direction': direction,
    'entry': entry,
    'stop': stop,
    'risk': risk,
    'location': location,
    'liquidity': liquidity,
    'data': data,
    'setup': setup,
  };

  factory SignalQualityScores.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return unrated;
    }
    return SignalQualityScores(
      direction: _asInt(raw['direction']),
      entry: _asInt(raw['entry']),
      stop: _asInt(raw['stop']),
      risk: _asInt(raw['risk']),
      location: _asInt(raw['location']),
      liquidity: _asInt(raw['liquidity']),
      data: _asInt(raw['data']),
      setup: _asInt(raw['setup']),
    );
  }
}

class FalseBreakoutAnalysis {
  const FalseBreakoutAnalysis({
    required this.state,
    required this.level,
    required this.levelLabel,
    required this.direction,
    required this.score,
    required this.pierced,
    required this.closedBackInside,
    required this.reclaimed,
    required this.rejectionWick,
    required this.volumeConfirmed,
    required this.structureConfirmed,
    required this.liquiditySweepConfirmed,
    required this.overshoot,
    required this.overshootPercent,
    required this.overshootAtr,
    this.eventTime,
  });

  static const FalseBreakoutAnalysis none = FalseBreakoutAnalysis(
    state: FalseBreakoutState.none,
    level: 0.0,
    levelLabel: 'Нет уровня',
    direction: Bias.neutral,
    score: 0,
    pierced: false,
    closedBackInside: false,
    reclaimed: false,
    rejectionWick: false,
    volumeConfirmed: false,
    structureConfirmed: false,
    liquiditySweepConfirmed: false,
    overshoot: 0.0,
    overshootPercent: 0.0,
    overshootAtr: 0.0,
  );

  final FalseBreakoutState state;
  final double level;
  final String levelLabel;
  final Bias direction;
  final int score;
  final bool pierced;
  final bool closedBackInside;
  final bool reclaimed;
  final bool rejectionWick;
  final bool volumeConfirmed;
  final bool structureConfirmed;
  final bool liquiditySweepConfirmed;
  final double overshoot;
  final double overshootPercent;
  final double overshootAtr;
  final DateTime? eventTime;
}

class StopPlan {
  const StopPlan({
    required this.variant,
    required this.invalidationPrice,
    required this.stopPrice,
    required this.buffer,
    required this.bufferAtr,
    required this.bufferPercent,
    required this.riskReward,
    required this.safe,
    required this.quality,
    required this.reasonCodes,
    this.structuralStopFound = true,
    this.bufferComplete = true,
    this.tooTight = false,
  });

  final StopVariant variant;
  final double invalidationPrice;
  final double stopPrice;
  final double buffer;
  final double bufferAtr;
  final double bufferPercent;
  final double riskReward;
  final bool safe;
  final int quality;
  final List<String> reasonCodes;
  final bool structuralStopFound;
  final bool bufferComplete;
  final bool tooTight;
}

class EntryAssessment {
  const EntryAssessment({
    required this.stage,
    required this.zoneReached,
    required this.localStructureConfirmed,
    required this.bosConfirmed,
    required this.chochConfirmed,
    required this.confirmationCandle,
    required this.volumeConfirmed,
    required this.retestConfirmed,
    required this.falseBreakout,
    required this.entryQuality,
    required this.action,
    required this.reasonCodes,
  });

  final SignalStage stage;
  final bool zoneReached;
  final bool localStructureConfirmed;
  final bool bosConfirmed;
  final bool chochConfirmed;
  final bool confirmationCandle;
  final bool volumeConfirmed;
  final bool retestConfirmed;
  final FalseBreakoutAnalysis falseBreakout;
  final int entryQuality;
  final String action;
  final List<String> reasonCodes;
}

T enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  final String name = raw?.toString() ?? '';
  for (final T value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}

int _asInt(Object? raw) => int.tryParse(raw?.toString() ?? '') ?? 0;
