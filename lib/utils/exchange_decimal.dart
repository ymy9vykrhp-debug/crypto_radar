import 'package:decimal/decimal.dart';

/// Decimal-safe primitives for exchange prices, quantities and costs.
///
/// UI and legacy market models still expose [double], but every exchange-step
/// operation enters and leaves this boundary through a canonical decimal
/// representation. This prevents binary floating-point drift from changing an
/// order step and gives persisted values a stable round-trip representation.
class ExchangeDecimal {
  const ExchangeDecimal._();

  static Decimal fromDouble(double value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'must be finite');
    }
    return Decimal.parse(_plainDecimal(value.toString()));
  }

  static Decimal fromPercent(double percent) => fromDouble(percent).shift(-2);

  static double multiply(double first, double second) =>
      (fromDouble(first) * fromDouble(second)).toDouble();

  static double add(double first, double second) =>
      (fromDouble(first) + fromDouble(second)).toDouble();

  static double subtract(double first, double second) =>
      (fromDouble(first) - fromDouble(second)).toDouble();

  static double percentOf(double value, double percent) =>
      (fromDouble(value) * fromPercent(percent)).toDouble();

  static double applyPercent(
    double value,
    double percent, {
    required bool increase,
  }) {
    final Decimal multiplier = increase
        ? Decimal.one + fromPercent(percent)
        : Decimal.one - fromPercent(percent);
    return (fromDouble(value) * multiplier).toDouble();
  }

  static double divide(double numerator, double denominator, {int scale = 24}) {
    if (!numerator.isFinite || !denominator.isFinite || denominator == 0) {
      return 0.0;
    }
    return (fromDouble(numerator) / fromDouble(denominator))
        .toDecimal(scaleOnInfinitePrecision: scale)
        .toDouble();
  }

  static double floorToStep(double value, double step) {
    if (!value.isFinite || value <= 0) return 0.0;
    if (!step.isFinite || step <= 0) return value;
    final Decimal amount = fromDouble(value);
    final Decimal increment = fromDouble(step);
    final BigInt units = amount ~/ increment;
    return (increment * Decimal.fromBigInt(units)).toDouble();
  }

  static double ceilToStep(double value, double step) {
    if (!value.isFinite || value <= 0) return 0.0;
    if (!step.isFinite || step <= 0) return value;
    final Decimal amount = fromDouble(value);
    final Decimal increment = fromDouble(step);
    BigInt units = amount ~/ increment;
    if (amount.remainder(increment) > Decimal.zero) {
      units += BigInt.one;
    }
    return (increment * Decimal.fromBigInt(units)).toDouble();
  }

  static String canonical(double value) => fromDouble(value).toString();

  static String? canonicalNullable(double? value) =>
      value == null ? null : canonical(value);

  static String _plainDecimal(String source) {
    final int marker = source.indexOf(RegExp('[eE]'));
    if (marker < 0) return source;

    final String coefficient = source.substring(0, marker);
    final int exponent = int.parse(source.substring(marker + 1));
    final bool negative = coefficient.startsWith('-');
    final String unsigned = coefficient.replaceFirst(RegExp(r'^[+-]'), '');
    final List<String> parts = unsigned.split('.');
    final String whole = parts.first;
    final String fraction = parts.length == 1 ? '' : parts.last;
    final String digits = '$whole$fraction';
    final int decimalPosition = whole.length + exponent;

    final String plain;
    if (decimalPosition <= 0) {
      plain = '0.${'0' * -decimalPosition}$digits';
    } else if (decimalPosition >= digits.length) {
      plain = '$digits${'0' * (decimalPosition - digits.length)}';
    } else {
      plain =
          '${digits.substring(0, decimalPosition)}.'
          '${digits.substring(decimalPosition)}';
    }
    return negative ? '-$plain' : plain;
  }
}
