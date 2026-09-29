import 'package:crypto_radar/utils/exchange_decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExchangeDecimal', () {
    test('floors and ceils by decimal steps without binary drift', () {
      expect(ExchangeDecimal.floorToStep(0.3, 0.1), 0.3);
      expect(ExchangeDecimal.floorToStep(1.239, 0.01), 1.23);
      expect(ExchangeDecimal.ceilToStep(1.231, 0.01), 1.24);
    });

    test('keeps very small exchange prices as plain canonical decimals', () {
      expect(ExchangeDecimal.canonical(0.00000012), '0.00000012');
      expect(ExchangeDecimal.floorToStep(0.000000129, 0.00000001), 0.00000012);
      expect(ExchangeDecimal.ceilToStep(0.000000121, 0.00000001), 0.00000013);
    });
  });
}
