import 'package:crypto_radar/engines/backtest_engine.dart';
import 'package:crypto_radar/localization/app_strings.dart';
import 'package:crypto_radar/models/trading_journal_models.dart';
import 'package:crypto_radar/screens/journal_screen.dart';
import 'package:crypto_radar/services/bybit_service.dart';
import 'package:crypto_radar/services/app_preferences_controller.dart';
import 'package:crypto_radar/services/journal_controller.dart';
import 'package:crypto_radar/services/journal_store.dart';
import 'package:crypto_radar/services/storage/local_storage_backend.dart';
import 'package:crypto_radar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'journal exposes overview, trade editor, calendar and performance',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final JournalController controller = _controller();
      await controller.initialize();
      await controller.updateJournalSettings(
        const JournalSettings(startingBalance: 100),
      );
      await controller.addManualTrade(_closedTrade());

      await tester.pumpWidget(
        AppLocalization(
          strings: const AppStrings(AppLanguage.ru),
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(body: JournalScreen(controller: controller)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'overview must not overflow',
      );

      expect(find.text('CURRENT BALANCE'), findsOneWidget);
      expect(find.text('\$119.00'), findsOneWidget);
      expect(find.text('Календарь'), findsOneWidget);
      expect(find.text('Эффективность'), findsOneWidget);

      await tester.tap(find.text('Сделки').first);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'trades must not overflow',
      );
      expect(find.text('BTCUSDT'), findsWidgets);

      await tester.tap(find.text('Добавить сделку').first);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'editor must not overflow',
      );
      expect(find.text('Planned Entry'), findsOneWidget);
      expect(find.text('Use for Strategy Research'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Календарь'));
      await tester.pumpAndSettle();
      expect(find.text('Торговый календарь'), findsOneWidget);

      controller.dispose();
    },
  );
}

TradeJournalEntry _closedTrade() {
  final DateTime time = DateTime.now().subtract(const Duration(hours: 2));
  return TradeJournalEntry.manual(
    id: 'manual-widget',
    now: time,
    tradeTime: time,
    symbol: 'BTCUSDT',
    side: JournalTradeSide.long,
    plannedEntry: 100,
    stopLoss: 99,
    tp1: 102,
    tp2: 103,
    actualEntry: 100,
    actualExit: 102,
    exitTime: time.add(const Duration(hours: 1)),
    positionSize: 1000,
    margin: 100,
    leverage: 10,
    fees: 1,
    strategy: 'Liquidity Sweep',
    timeframe: '5m',
    entryReason: EntryReason.liquiditySweep,
  );
}

JournalController _controller() {
  final MockClient client = MockClient(
    (http.Request request) async => http.Response('{}', 500),
  );
  return JournalController(
    store: JournalStore(backend: _MemoryStorage()),
    backtestEngine: BacktestEngine(bybitService: BybitService(client)),
  );
}

class _MemoryStorage implements LocalStorageBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
