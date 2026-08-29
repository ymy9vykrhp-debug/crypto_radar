import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/position_calculator_models.dart';
import '../models/integration_models.dart';
import 'storage/local_storage_backend.dart';

enum AppLanguage { ru, en }

class AppPreferencesController extends ChangeNotifier {
  AppPreferencesController({LocalStorageBackend? storage})
    : _storage = storage ?? createLocalStorageBackend();

  static const String _storageKey = 'app_preferences_v2';

  final LocalStorageBackend _storage;
  ThemeMode _themeMode = ThemeMode.dark;
  AppLanguage _language = AppLanguage.ru;
  bool _soundEnabled = true;
  RiskPreset _riskPreset = RiskPreset.normal;
  double _customRiskPercent = 2.0;
  double _accountEquity = 0.0;
  double _accountRiskPercent = 0.5;
  int _personalMaxLeverage = 10;
  bool _highRiskLeverageEnabled = false;
  FeeModel _feeModel = const FeeModel();
  TelegramRelayConfig _telegramRelayConfig = const TelegramRelayConfig();
  bool _initialized = false;
  Future<void> _writeQueue = Future<void>.value();

  ThemeMode get themeMode => _themeMode;
  AppLanguage get language => _language;
  bool get soundEnabled => _soundEnabled;
  RiskPreset get riskPreset => _riskPreset;
  double get customRiskPercent => _customRiskPercent;
  double get effectiveRiskPercent => _riskPreset == RiskPreset.custom
      ? _customRiskPercent
      : _riskPreset.defaultPercent;
  double get accountEquity => _accountEquity;
  double get accountRiskPercent => _accountRiskPercent;
  int get personalMaxLeverage => _personalMaxLeverage;
  bool get highRiskLeverageEnabled => _highRiskLeverageEnabled;
  FeeModel get feeModel => _feeModel;
  TelegramRelayConfig get telegramRelayConfig => _telegramRelayConfig;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final String? raw = await _storage.read(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      _themeMode =
          ThemeMode.values
              .where((ThemeMode value) => value.name == decoded['themeMode'])
              .firstOrNull ??
          _themeMode;
      _language =
          AppLanguage.values
              .where((AppLanguage value) => value.name == decoded['language'])
              .firstOrNull ??
          _language;
      _soundEnabled = decoded['soundEnabled'] is bool
          ? decoded['soundEnabled'] as bool
          : _soundEnabled;
      _riskPreset =
          RiskPreset.values
              .where((RiskPreset value) => value.name == decoded['riskPreset'])
              .firstOrNull ??
          _riskPreset;
      final Object? customRisk = decoded['customRiskPercent'];
      final double parsedRisk = customRisk is num
          ? customRisk.toDouble()
          : double.tryParse('$customRisk') ?? _customRiskPercent;
      if (parsedRisk.isFinite && parsedRisk >= 0.1 && parsedRisk <= 20.0) {
        _customRiskPercent = parsedRisk;
      }
      final double parsedEquity =
          double.tryParse('${decoded['accountEquity']}') ?? _accountEquity;
      if (parsedEquity.isFinite && parsedEquity >= 0.0) {
        _accountEquity = parsedEquity;
      }
      final double parsedAccountRisk =
          double.tryParse('${decoded['accountRiskPercent']}') ??
          _accountRiskPercent;
      if (parsedAccountRisk.isFinite &&
          parsedAccountRisk >= 0.1 &&
          parsedAccountRisk <= 1.0) {
        _accountRiskPercent = parsedAccountRisk;
      }
      final int parsedLeverage =
          int.tryParse('${decoded['personalMaxLeverage']}') ??
          _personalMaxLeverage;
      if (parsedLeverage >= 1 && parsedLeverage <= 10) {
        _personalMaxLeverage = parsedLeverage;
      }
      _highRiskLeverageEnabled = decoded['highRiskLeverageEnabled'] is bool
          ? decoded['highRiskLeverageEnabled'] as bool
          : _highRiskLeverageEnabled;
      final Object? feeJson = decoded['feeModel'];
      if (feeJson is Map<String, dynamic>) {
        _feeModel = FeeModel.fromJson(feeJson);
      }
      final Object? telegramJson = decoded['telegramRelayConfig'];
      if (telegramJson is Map<String, dynamic>) {
        _telegramRelayConfig = TelegramRelayConfig.fromJson(telegramJson);
      }
      notifyListeners();
    } on Object {
      // Corrupt local preferences never prevent the application from opening.
    }
  }

  void setThemeMode(ThemeMode value) {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
    _scheduleSave();
  }

  void setLanguage(AppLanguage value) {
    if (_language == value) return;
    _language = value;
    notifyListeners();
    _scheduleSave();
  }

  void setSoundEnabled(bool value) {
    if (_soundEnabled == value) return;
    _soundEnabled = value;
    notifyListeners();
    _scheduleSave();
  }

  void setRiskPreset(RiskPreset value) {
    if (_riskPreset == value) return;
    _riskPreset = value;
    notifyListeners();
    _scheduleSave();
  }

  void setCustomRiskPercent(double value) {
    if (!value.isFinite || value < 0.1 || value > 20.0) return;
    if (_customRiskPercent == value) return;
    _customRiskPercent = value;
    notifyListeners();
    _scheduleSave();
  }

  void setAccountEquity(double value) {
    if (!value.isFinite || value < 0.0 || _accountEquity == value) return;
    _accountEquity = value;
    notifyListeners();
    _scheduleSave();
  }

  void setAccountRiskPercent(double value) {
    if (!value.isFinite ||
        value < 0.1 ||
        value > 1.0 ||
        _accountRiskPercent == value) {
      return;
    }
    _accountRiskPercent = value;
    notifyListeners();
    _scheduleSave();
  }

  void setPersonalMaxLeverage(int value) {
    if (value < 1 || value > 10 || _personalMaxLeverage == value) return;
    _personalMaxLeverage = value;
    notifyListeners();
    _scheduleSave();
  }

  void setHighRiskLeverageEnabled(bool value) {
    if (_highRiskLeverageEnabled == value) return;
    _highRiskLeverageEnabled = value;
    notifyListeners();
    _scheduleSave();
  }

  void setFeeModel(FeeModel value) {
    _feeModel = value;
    notifyListeners();
    _scheduleSave();
  }

  void setTelegramRelayConfig(TelegramRelayConfig value) {
    if (_telegramRelayConfig.enabled == value.enabled &&
        _telegramRelayConfig.baseUrl == value.baseUrl) {
      return;
    }
    _telegramRelayConfig = value;
    notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    final String payload = jsonEncode(<String, Object?>{
      'themeMode': _themeMode.name,
      'language': _language.name,
      'soundEnabled': _soundEnabled,
      'riskPreset': _riskPreset.name,
      'customRiskPercent': _customRiskPercent,
      'accountEquity': _accountEquity,
      'accountRiskPercent': _accountRiskPercent,
      'personalMaxLeverage': _personalMaxLeverage,
      'highRiskLeverageEnabled': _highRiskLeverageEnabled,
      'feeModel': _feeModel.toJson(),
      'telegramRelayConfig': _telegramRelayConfig.toJson(),
    });
    _writeQueue = _writeQueue
        .then<void>((_) => _storage.write(_storageKey, payload))
        .catchError((Object _) {
          // Preferences are optional local state and must never crash Radar.
        });
  }

  Future<void> flushPendingWrites() => _writeQueue;
}
