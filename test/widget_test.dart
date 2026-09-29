import 'package:crypto_radar/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [430.0, 800.0, 1440.0]) {
    testWidgets('terminal layout and navigation at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const CryptoRadarApp(autoStart: false));
      await tester.pumpAndSettle();
      expect(find.text('CRYPTO RADAR'), findsOneWidget);
      expect(find.text('WAIT'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width >= 1100) {
        expect(
          tester.getTopLeft(find.text('FARTCOINUSDT')).dx,
          lessThan(tester.getTopLeft(find.text('Что делать сейчас?')).dx),
        );
        expect(
          tester.getTopLeft(find.text('Что делать сейчас?')).dx,
          lessThan(tester.getTopLeft(find.text('Управление позицией')).dx),
        );
      }
      await tester.tap(find.byKey(const ValueKey('live-switch')));
      await tester.pumpAndSettle();
      expect(
        find.text('ПАУЗА. Обновите данные перед решением.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Отметить свой вход'));
      await tester.tap(find.text('Отметить свой вход'));
      await tester.pumpAndSettle();
      expect(find.text('Моя фактическая позиция'), findsOneWidget);
      if (width >= 1100) {
        await tester.tap(find.widgetWithText(TextButton, 'Grid'));
        await tester.pumpAndSettle();
        expect(
          find.text('Adaptive Futures Grid · анализ без ордеров'),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(TextButton, 'Настройки'));
        await tester.pumpAndSettle();
        expect(find.text('Расчёт риска'), findsOneWidget);
      }
      await tester.ensureVisible(find.widgetWithText(TextButton, 'Торговля'));
      await tester.tap(find.widgetWithText(TextButton, 'Торговля'));
      await tester.pumpAndSettle();
      expect(find.text('Что делать сейчас?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
