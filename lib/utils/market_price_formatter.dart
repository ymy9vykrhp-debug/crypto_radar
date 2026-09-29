String formatMarketPrice(double value, {double tickSize = 0.0}) {
  if (!value.isFinite || value <= 0.0) return '—';
  final int decimals = tickSize > 0.0
      ? _decimalPlaces(tickSize)
      : _fallbackDecimals(value);
  return value.toStringAsFixed(decimals.clamp(0, 12));
}

int _decimalPlaces(double step) {
  String normalized = step.toStringAsFixed(12);
  while (normalized.endsWith('0')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  final int separator = normalized.indexOf('.');
  return separator < 0 ? 0 : normalized.length - separator - 1;
}

int _fallbackDecimals(double value) {
  if (value >= 1000.0) return 2;
  if (value >= 1.0) return 4;
  if (value >= 0.01) return 6;
  if (value >= 0.0001) return 8;
  return 10;
}
