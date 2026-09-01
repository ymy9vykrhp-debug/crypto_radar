import 'package:crypto_radar/localization/app_strings.dart';
import 'package:crypto_radar/models/integration_models.dart';
import 'package:crypto_radar/models/position_calculator_models.dart';
import 'package:crypto_radar/services/app_preferences_controller.dart';
import 'package:crypto_radar/services/storage/local_storage_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preferences switch theme and language deterministically', () {
    final AppPreferencesController controller = AppPreferencesController(
      storage: _MemoryStorage(),
    );

    expect(controller.themeMode, ThemeMode.dark);
    expect(controller.language, AppLanguage.ru);
    expect(controller.soundEnabled, isTrue);
    expect(controller.riskPreset, RiskPreset.normal);
    expect(controller.effectiveRiskPercent, 2);
    expect(controller.accountEquity, 0);
    expect(controller.accountRiskPercent, 0.5);
    expect(controller.personalMaxLeverage, 10);
    expect(controller.highRiskLeverageEnabled, isFalse);
    expect(controller.monitoredSymbols, <String>['BTCUSDT', 'FARTCOINUSDT']);
    expect(const AppStrings(AppLanguage.ru).instrument, 'Инструмент');

    controller.setThemeMode(ThemeMode.light);
    controller.setLanguage(AppLanguage.en);
    controller.setSoundEnabled(false);
    controller.setRiskPreset(RiskPreset.active);

    expect(controller.themeMode, ThemeMode.light);
    expect(controller.language, AppLanguage.en);
    expect(controller.soundEnabled, isFalse);
    expect(controller.effectiveRiskPercent, 3);
    expect(const AppStrings(AppLanguage.en).instrument, 'Instrument');
  });

  test('risk and fee defaults persist locally', () async {
    final _MemoryStorage storage = _MemoryStorage();
    final AppPreferencesController first = AppPreferencesController(
      storage: storage,
    );
    first.setRiskPreset(RiskPreset.custom);
    first.setCustomRiskPercent(2.5);
    first.setAccountEquity(5000);
    first.setAccountRiskPercent(0.7);
    first.setPersonalMaxLeverage(9);
    first.setHighRiskLeverageEnabled(false);
    first.setFeeModel(
      first.feeModel.copyWith(
        makerFeePercent: 0.01,
        entrySlippagePercent: 0.03,
        stopSlippagePercent: 0.08,
      ),
    );
    first.setTelegramRelayConfig(
      const TelegramRelayConfig(
        enabled: true,
        baseUrl: 'http://127.0.0.1:9999',
      ),
    );
    first.setSymbolMonitored('BTCUSDT', false);
    await first.flushPendingWrites();

    final AppPreferencesController restored = AppPreferencesController(
      storage: storage,
    );
    await restored.initialize();

    expect(restored.riskPreset, RiskPreset.custom);
    expect(restored.effectiveRiskPercent, 2.5);
    expect(restored.accountEquity, 5000);
    expect(restored.accountRiskPercent, 0.7);
    expect(restored.personalMaxLeverage, 9);
    expect(restored.highRiskLeverageEnabled, isFalse);
    expect(restored.feeModel.makerFeePercent, 0.01);
    expect(restored.feeModel.entrySlippagePercent, 0.03);
    expect(restored.feeModel.stopSlippagePercent, 0.08);
    expect(restored.telegramRelayConfig.enabled, isTrue);
    expect(restored.telegramRelayConfig.baseUrl, 'http://127.0.0.1:9999');
    expect(restored.monitoredSymbols, <String>['FARTCOINUSDT']);
  });

  test('monitor list stays normalized, unique and never becomes empty', () {
    final AppPreferencesController controller = AppPreferencesController(
      storage: _MemoryStorage(),
    );

    controller.setSymbolMonitored(' btc/usdt ', true);
    expect(controller.monitoredSymbols, <String>['BTCUSDT', 'FARTCOINUSDT']);

    controller.setSymbolMonitored('BTCUSDT', false);
    controller.setSymbolMonitored('FARTCOINUSDT', false);

    expect(controller.monitoredSymbols, <String>['FARTCOINUSDT']);
  });
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
