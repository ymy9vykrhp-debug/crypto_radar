import 'package:flutter/widgets.dart';

import '../models/navigation_models.dart';
import '../services/app_preferences_controller.dart';

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  bool get isRussian => language == AppLanguage.ru;

  String pick(String ru, String en) => isRussian ? ru : en;

  String appSection(AppSection section) {
    switch (section) {
      case AppSection.home:
        return pick('Главная', 'Home');
      case AppSection.market:
        return pick('Рынок', 'Market');
      case AppSection.signals:
        return pick('Сигналы', 'Signals');
      case AppSection.journal:
        return pick('Журнал', 'Journal');
      case AppSection.research:
        return pick('Исследование', 'Research');
      case AppSection.news:
        return pick('Новости', 'News');
      case AppSection.help:
        return pick('Помощь', 'Help');
      case AppSection.integrations:
        return pick('Интеграции', 'Integrations');
      case AppSection.settings:
        return pick('Настройки', 'Settings');
    }
  }

  String workspaceSection(WorkspaceSection section) {
    switch (section) {
      case WorkspaceSection.overview:
        return pick('Обзор', 'Overview');
      case WorkspaceSection.chart:
        return pick('График', 'Chart');
      case WorkspaceSection.structure:
        return pick('Структура', 'Structure');
      case WorkspaceSection.levels:
        return pick('Уровни', 'Levels');
      case WorkspaceSection.volume:
        return pick('Объём / Кластеры', 'Volume / Clusters');
      case WorkspaceSection.signal:
        return pick('Сигнал', 'Signal');
      case WorkspaceSection.why:
        return pick('Почему?', 'Why?');
      case WorkspaceSection.journal:
        return pick('Журнал', 'Journal');
      case WorkspaceSection.news:
        return pick('Новости', 'News');
    }
  }

  String get instrument => pick('Инструмент', 'Instrument');
  String get autoRefresh =>
      pick('Автообновление каждые 15 секунд', 'Auto refresh every 15 seconds');
  String get refreshNow => pick('Обновить сейчас', 'Refresh now');
  String get loadingMarket =>
      pick('Загружаю данные рынка…', 'Loading market data…');
  String get selectAsset => pick('Выберите актив', 'Select an asset');
  String get search => pick('Поиск', 'Search');
  String get all => pick('Все', 'All');
  String get details => pick('Подробности', 'Details');
  String get close => pick('Закрыть', 'Close');
  String get noData => pick('Пока нет данных', 'No data yet');
  String get localOnly =>
      pick('Данные хранятся локально', 'Data is stored locally');
  String get notConnected => pick('Не подключено', 'Not connected');
  String get planned => pick('Запланировано', 'Planned');
  String get disabled => pick('Отключено', 'Disabled');
  String get active => pick('Активно', 'Active');
}

class AppLocalization extends InheritedWidget {
  const AppLocalization({
    super.key,
    required this.strings,
    required super.child,
  });

  final AppStrings strings;

  static AppStrings of(BuildContext context) {
    final AppLocalization? result = context
        .dependOnInheritedWidgetOfExactType<AppLocalization>();
    assert(result != null, 'AppLocalization is missing above this context.');
    return result!.strings;
  }

  @override
  bool updateShouldNotify(AppLocalization oldWidget) =>
      oldWidget.strings.language != strings.language;
}

extension AppStringsContext on BuildContext {
  AppStrings get strings => AppLocalization.of(this);
}
