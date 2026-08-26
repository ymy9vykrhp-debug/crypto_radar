import 'package:crypto_radar/localization/app_strings.dart';
import 'package:crypto_radar/services/app_preferences_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preferences switch theme and language deterministically', () {
    final AppPreferencesController controller = AppPreferencesController();

    expect(controller.themeMode, ThemeMode.dark);
    expect(controller.language, AppLanguage.ru);
    expect(const AppStrings(AppLanguage.ru).instrument, 'Инструмент');

    controller.setThemeMode(ThemeMode.light);
    controller.setLanguage(AppLanguage.en);

    expect(controller.themeMode, ThemeMode.light);
    expect(controller.language, AppLanguage.en);
    expect(const AppStrings(AppLanguage.en).instrument, 'Instrument');
  });
}
