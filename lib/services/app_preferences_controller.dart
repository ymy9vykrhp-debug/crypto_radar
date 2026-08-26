import 'package:flutter/material.dart';

enum AppLanguage { ru, en }

class AppPreferencesController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  AppLanguage _language = AppLanguage.ru;

  ThemeMode get themeMode => _themeMode;
  AppLanguage get language => _language;

  void setThemeMode(ThemeMode value) {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
  }

  void setLanguage(AppLanguage value) {
    if (_language == value) return;
    _language = value;
    notifyListeners();
  }
}
