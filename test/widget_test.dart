import 'package:crypto_radar/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Crypto Radar opens with six tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const CryptoRadarApp(autoStart: false));

    expect(find.text('Crypto Radar'), findsOneWidget);
    expect(find.text('ГЛАВНАЯ'), findsOneWidget);
    expect(find.text('ПОДТВЕРЖДЕНИЯ'), findsOneWidget);
    expect(find.text('ДЕТАЛИ'), findsOneWidget);
    expect(find.text('ПОЧЕМУ?'), findsOneWidget);
    expect(find.text('ГРАФИК'), findsOneWidget);
    expect(find.text('ЖУРНАЛ'), findsOneWidget);
    expect(find.text('FARTCOIN / USDT'), findsOneWidget);
  });
}
