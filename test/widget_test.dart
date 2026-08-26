import 'package:crypto_radar/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Crypto Radar opens with product navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CryptoRadarApp(autoStart: false));
    await tester.pumpAndSettle();

    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('FARTCOIN / USDT'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Crypto Radar'), findsOneWidget);
    expect(find.text('Рынок'), findsOneWidget);
    expect(find.text('Сигналы'), findsOneWidget);
    expect(find.text('Журнал'), findsOneWidget);
    expect(find.text('Исследование'), findsOneWidget);
    expect(find.text('Новости'), findsOneWidget);
    expect(find.text('Интеграции'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);
  });

  testWidgets('product shell adapts to a narrow screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CryptoRadarApp(autoStart: false));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('FARTCOIN / USDT'), findsOneWidget);
  });
}
