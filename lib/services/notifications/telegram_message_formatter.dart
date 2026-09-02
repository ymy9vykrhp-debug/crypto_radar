String formatTelegramRelayMessage(Map<String, dynamic> payload) {
  final String kind = payload['kind']?.toString() ?? '';
  if (kind == 'TEST') {
    return payload['text']?.toString() ?? 'Crypto Radar test';
  }
  final String symbol = payload['symbol']?.toString() ?? 'UNKNOWN';
  final String direction = payload['direction']?.toString() ?? 'WAIT';
  final String directionIcon = direction == 'LONG' ? '📈' : '📉';
  if (kind != 'ENTRY_READY') {
    return _formatLifecycleEvent(
      payload,
      kind: kind,
      symbol: symbol,
      direction: direction,
      directionIcon: directionIcon,
    );
  }
  if (!_completeEntryReadyPayload(payload)) {
    return <String>[
      '⚪ ДАННЫХ НЕДОСТАТОЧНО',
      '',
      '$symbol · вход не разрешён',
      'Telegram получил неполный торговый план.',
      'Действие: дождаться нового подтверждённого сигнала.',
      '',
      'Crypto Radar · LOCAL MONITOR ONLY',
      'Ордер не отправлен.',
    ].join('\n');
  }
  final String confirmed = _displayTime(payload['confirmedAt']);
  final String age = _displayAge(payload['setupAgeSeconds']);
  String probability(String key) =>
      '${double.parse(payload[key].toString()).toStringAsFixed(1)}%';
  return <String>[
    '🚨 ВХОД ПОДТВЕРЖДЁН',
    '',
    '$directionIcon $symbol · $direction',
    '',
    '⭐ Setup Quality: ${payload['score'] ?? '—'}/100',
    'Совпадение факторов, не вероятность прибыли.',
    'Режим: ${payload['tradingMode']} · ${payload['marketRegime']}',
    '',
    '🎯 Entry Zone: ${payload['entryLowText'] ?? '—'} — ${payload['entryHighText'] ?? '—'}',
    '🛑 Structural Stop: ${payload['stopText'] ?? '—'}',
    'Stop distance: ${payload['stopDistancePercentText'] ?? '—'}',
    '',
    '💰 TP1: ${payload['tp1Text'] ?? '—'}',
    'Ожидаемый ход: ${payload['expectedMovePercentText']}',
    '⚖️ Net R:R: ${payload['netRiskRewardText']}',
    '💰 TP2: ${payload['tp2Text'] ?? '—'}',
    '⚖️ Raw R:R TP2: ${payload['riskRewardTp2Text'] ?? '—'}',
    '',
    '🎯 Историческая вероятность первого движения:',
    '0.20% → ${probability('firstMoveProbability020')}',
    '0.30% → ${probability('firstMoveProbability030')}',
    '0.50% → ${probability('firstMoveProbability050')}',
    '0.75% → ${probability('firstMoveProbability075')}',
    '1.00% → ${probability('firstMoveProbability100')}',
    'Stop First → ${probability('stopFirstProbability')}',
    'Похожие наблюдения: ${payload['historicalSamples']} · ${payload['historicalConfidence']}',
    '',
    '📊 Direction: ${payload['directionQuality'] ?? '—'}/100',
    '🎯 Entry Quality: ${payload['entryQuality'] ?? '—'}/100',
    '📍 Location: ${payload['locationQuality'] ?? '—'}/100',
    '💧 Liquidity: ${payload['liquidityQuality'] ?? '—'}/100',
    '🛡 Stop Quality: ${payload['stopQuality'] ?? '—'}/100',
    '⚠️ Risk Quality: ${payload['riskQuality'] ?? '—'}/100',
    '📡 Data Quality: ${payload['dataQuality'] ?? '—'}',
    '',
    '🕒 Confirmed: $confirmed',
    '⏱ Setup age: $age',
    '',
    '✅ Все обязательные условия выполнены.',
    '⚠️ Разрешение действует, пока Safety Gate подтверждён.',
    '',
    'Crypto Radar · LOCAL MONITOR ONLY',
    'Ордер не отправлен.',
  ].join('\n');
}

bool _completeEntryReadyPayload(Map<String, dynamic> payload) {
  final String symbol = payload['symbol']?.toString().trim() ?? '';
  final String direction = payload['direction']?.toString() ?? '';
  double? number(String key) => double.tryParse(payload[key]?.toString() ?? '');
  final int samples =
      int.tryParse(payload['historicalSamples']?.toString() ?? '') ?? 0;
  final List<String> positivePrices = <String>[
    'entryLow',
    'entryHigh',
    'stop',
    'tp1',
    'tp2',
  ];
  return symbol.isNotEmpty &&
      (direction == 'LONG' || direction == 'SHORT') &&
      positivePrices.every((String key) => (number(key) ?? 0.0) > 0.0) &&
      (number('expectedMovePercent') ?? 0.0) >= 1.0 &&
      (number('netRiskReward') ?? 0.0) >= 1.8 &&
      samples >= 50 &&
      (number('firstMoveProbability030') ?? 0.0) >= 70.0 &&
      <String>[
        'firstMoveProbability020',
        'firstMoveProbability030',
        'firstMoveProbability050',
        'firstMoveProbability075',
        'firstMoveProbability100',
        'stopFirstProbability',
      ].every((String key) => number(key) != null);
}

String _formatLifecycleEvent(
  Map<String, dynamic> payload, {
  required String kind,
  required String symbol,
  required String direction,
  required String directionIcon,
}) {
  final String title = switch (kind) {
    'SIGNAL_INVALIDATED' => '❌ СИГНАЛ ОТМЕНЁН',
    'ENTRY_SUSPENDED' => '⏸ РАЗРЕШЕНИЕ ПРИОСТАНОВЛЕНО',
    'CONDITIONS_WORSENED' => '⚠️ УСЛОВИЯ УХУДШИЛИСЬ',
    'POSITION_ACTIVE' => '✅ ВХОД СОСТОЯЛСЯ',
    'TP1_HIT' => '🎯 TP1 ДОСТИГНУТ',
    'TP2_HIT' => '🏆 TP2 ДОСТИГНУТ',
    'STOP_HIT' => '🛑 СРАБОТАЛ STOP',
    'SETUP_CANCELLED' => '🚫 СЕТАП ОТМЕНЁН',
    'SETUP_EXPIRED' => '⌛ СЕТАП УСТАРЕЛ',
    _ => 'ℹ️ Crypto Radar · $kind',
  };
  final List<String> lines = <String>[
    title,
    '',
    '$directionIcon $symbol · $direction',
  ];
  if (kind == 'SIGNAL_INVALIDATED' ||
      kind == 'ENTRY_SUSPENDED' ||
      kind == 'CONDITIONS_WORSENED') {
    final Object? rawReasons = payload['reasonCodes'];
    final String reasons = rawReasons is List<dynamic> && rawReasons.isNotEmpty
        ? rawReasons.join(', ')
        : 'Обязательные условия Safety Gate больше не выполнены.';
    lines.addAll(<String>[
      '',
      'Статус: ${payload['stage'] ?? '—'}',
      'Причины: $reasons',
      kind == 'CONDITIONS_WORSENED'
          ? 'Действие: рассмотреть фиксацию или защиту позиции. Автозакрытие отключено.'
          : 'Действие: не входить до нового ENTRY READY.',
    ]);
  } else {
    lines.addAll(<String>[
      'Статус: ${payload['trackerStatus'] ?? payload['stage'] ?? '—'}',
      'Entry: ${payload['entryLowText'] ?? '—'} — ${payload['entryHighText'] ?? '—'}',
      'Stop: ${payload['stopText'] ?? '—'}',
      'TP1: ${payload['tp1Text'] ?? '—'} · TP2: ${payload['tp2Text'] ?? '—'}',
    ]);
    if (kind == 'TP1_HIT' || kind == 'TP2_HIT' || kind == 'STOP_HIT') {
      lines.add(
        'Result: ${_number(payload['resultR'])}R · '
        'MFE ${_number(payload['mfeR'])}R · MAE ${_number(payload['maeR'])}R',
      );
    }
  }
  lines.addAll(<String>[
    '',
    'Crypto Radar · LOCAL MONITOR ONLY',
    'Ордер не отправлен.',
  ]);
  return lines.join('\n');
}

String _number(Object? raw) {
  final double? value = double.tryParse(raw?.toString() ?? '');
  return value == null ? '—' : value.toStringAsFixed(2);
}

String _displayTime(Object? raw) {
  final DateTime? parsed = DateTime.tryParse(raw?.toString() ?? '');
  if (parsed == null) return '—';
  final DateTime local = parsed.toLocal();
  final Duration offset = local.timeZoneOffset;
  final String sign = offset.isNegative ? '-' : '+';
  final int offsetMinutes = offset.inMinutes.abs();
  return '${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)} '
      'UTC$sign${_two(offsetMinutes ~/ 60)}:${_two(offsetMinutes % 60)}';
}

String _displayAge(Object? raw) {
  final int seconds = int.tryParse(raw?.toString() ?? '') ?? 0;
  if (seconds < 60) return '$seconds sec';
  final int minutes = seconds ~/ 60;
  final int remainder = seconds % 60;
  return '${minutes}m ${remainder}s';
}

String _two(int value) => value.toString().padLeft(2, '0');
