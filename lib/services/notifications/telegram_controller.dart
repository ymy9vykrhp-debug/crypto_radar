import 'package:flutter/foundation.dart';

import '../../models/integration_models.dart';
import '../../models/trade_alert_models.dart';
import '../app_preferences_controller.dart';
import 'telegram_gateway.dart';

class TelegramController extends ChangeNotifier {
  TelegramController({required this.preferences, required this.gateway});

  final AppPreferencesController preferences;
  final TelegramGateway gateway;

  IntegrationStatus _status = const IntegrationStatus(
    state: IntegrationConnectionState.disabled,
    message: 'DISABLED',
  );
  bool _busy = false;
  String? _lastDelivery;

  IntegrationStatus get status => _status;
  bool get busy => _busy;
  String? get lastDelivery => _lastDelivery;

  Future<void> refreshStatus() async {
    if (_busy) return;
    _busy = true;
    _status = const IntegrationStatus(
      state: IntegrationConnectionState.checking,
      message: 'CHECKING',
    );
    notifyListeners();
    _status = await gateway.check(preferences.telegramRelayConfig);
    _busy = false;
    notifyListeners();
  }

  Future<void> sendTest() async {
    if (_busy) return;
    _busy = true;
    _lastDelivery = null;
    notifyListeners();
    try {
      await gateway.sendTest(preferences.telegramRelayConfig);
      _lastDelivery = 'TEST SENT';
      _status = IntegrationStatus(
        state: IntegrationConnectionState.connected,
        message: 'CONNECTED',
        checkedAt: DateTime.now(),
      );
    } on Object catch (error) {
      _lastDelivery = 'FAILED: ${_clean(error)}';
      _status = IntegrationStatus(
        state: IntegrationConnectionState.unavailable,
        message: 'DELIVERY FAILED',
        checkedAt: DateTime.now(),
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> deliver(TradeAlert alert) async {
    if (!preferences.telegramRelayConfig.enabled) return;
    try {
      await gateway.sendTradeAlert(preferences.telegramRelayConfig, alert);
      _lastDelivery = 'SENT ${alert.signal.id}';
      _status = IntegrationStatus(
        state: IntegrationConnectionState.connected,
        message: 'CONNECTED',
        checkedAt: DateTime.now(),
      );
    } on Object catch (error) {
      _lastDelivery = 'FAILED: ${_clean(error)}';
      _status = IntegrationStatus(
        state: IntegrationConnectionState.unavailable,
        message: 'DELIVERY FAILED',
        checkedAt: DateTime.now(),
      );
    }
    notifyListeners();
  }

  String _clean(Object error) => error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('FormatException: ', '');
}
