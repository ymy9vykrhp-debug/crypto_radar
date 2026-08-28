import 'package:crypto_radar/localization/app_strings.dart';
import 'package:crypto_radar/models/decision_models.dart';
import 'package:crypto_radar/models/execution_models.dart';
import 'package:crypto_radar/models/position_calculator_models.dart';
import 'package:crypto_radar/models/signal_models.dart';
import 'package:crypto_radar/services/app_preferences_controller.dart';
import 'package:crypto_radar/services/storage/local_storage_base.dart';
import 'package:crypto_radar/theme/app_theme.dart';
import 'package:crypto_radar/widgets/smart_position_calculator_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('calculator opens responsively and exposes the full risk plan', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final AppPreferencesController preferences = AppPreferencesController(
      storage: _MemoryStorage(),
    );
    await tester.pumpWidget(
      AppLocalization(
        strings: const AppStrings(AppLanguage.ru),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => Center(
                child: FilledButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => SmartPositionCalculatorDialog(
                      initialInput: _input(),
                      preferences: preferences,
                    ),
                  ),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('BTCUSDT — LONG'), findsOneWidget);
    expect(find.text('РЕКОМЕНДУЕМОЕ ПЛЕЧО'), findsOneWidget);
    expect(find.text('МОЯ СУММА И ПЛАН'), findsOneWidget);
    expect(find.text('TRADE ACCEPTABLE'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(find.text('ЦЕЛИ И NET R:R'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

SmartPositionInput _input() => const SmartPositionInput(
  symbol: 'BTCUSDT',
  direction: SignalDirection.long,
  decisionAction: DecisionAction.long,
  signalStage: SignalStage.entryConfirmed,
  currentPrice: 100,
  entryZoneLow: 99.9,
  entryZoneHigh: 100.1,
  entry: 100,
  stop: 99.35,
  tp1: 101,
  tp2: 102.5,
  confidence: 88,
  atr: 0.3,
  volatilityPercent: 5,
  marketRegime: MarketRegimeHint.trendUp,
  setupType: 'TEST_SETUP',
  allocatedMargin: 100,
  riskPercent: 3,
  assetRiskClass: AssetRiskClass.major,
  quantityStep: 0.001,
  minOrderQuantity: 0.001,
  minNotional: 5,
  tickSize: 0.01,
);

class _MemoryStorage implements LocalStorageBackend {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}
