import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/app_preferences_controller.dart';
import '../widgets/product_components.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.preferences});

  final AppPreferencesController preferences;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        SectionHeading(
          title: strings.pick('Настройки', 'Settings'),
          subtitle: strings.pick(
            'Параметры разделены по понятным категориям',
            'Settings are grouped into clear categories',
          ),
          icon: Icons.settings_outlined,
        ),
        const SizedBox(height: 14),
        ProductExpandableSection(
          title: strings.pick('Язык', 'Language'),
          icon: Icons.translate_rounded,
          initiallyExpanded: true,
          child: SegmentedButton<AppLanguage>(
            segments: const <ButtonSegment<AppLanguage>>[
              ButtonSegment<AppLanguage>(
                value: AppLanguage.ru,
                label: Text('Русский'),
              ),
              ButtonSegment<AppLanguage>(
                value: AppLanguage.en,
                label: Text('English'),
              ),
            ],
            selected: <AppLanguage>{preferences.language},
            onSelectionChanged: (Set<AppLanguage> selection) =>
                preferences.setLanguage(selection.first),
          ),
        ),
        const SizedBox(height: 10),
        ProductExpandableSection(
          title: strings.pick('Внешний вид', 'Appearance'),
          icon: Icons.palette_outlined,
          initiallyExpanded: true,
          child: SegmentedButton<ThemeMode>(
            segments: <ButtonSegment<ThemeMode>>[
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                icon: const Icon(Icons.dark_mode_outlined),
                label: Text(strings.pick('Тёмная', 'Dark')),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                icon: const Icon(Icons.light_mode_outlined),
                label: Text(strings.pick('Светлая', 'Light')),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                icon: const Icon(Icons.brightness_auto_outlined),
                label: Text(strings.pick('Системная', 'System')),
              ),
            ],
            selected: <ThemeMode>{preferences.themeMode},
            onSelectionChanged: (Set<ThemeMode> selection) =>
                preferences.setThemeMode(selection.first),
          ),
        ),
        const SizedBox(height: 10),
        _PlannedSettingsGroup(
          title: strings.pick('Торговля и риск', 'Trading and Risk'),
          icon: Icons.shield_outlined,
          items: <String>[
            strings.pick('Риск', 'Risk'),
            strings.pick('Стратегии', 'Strategies'),
            strings.pick('Активы', 'Assets'),
          ],
        ),
        const SizedBox(height: 10),
        ProductExpandableSection(
          title: strings.pick('Уведомления', 'Alerts'),
          icon: Icons.notifications_outlined,
          initiallyExpanded: true,
          child: Column(
            children: <Widget>[
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.security_rounded),
                title: Text(
                  strings.pick('Торговые уведомления', 'Trade alerts'),
                ),
                subtitle: Text(
                  strings.pick(
                    'Только сильный новый ENTRY_CONFIRMED · MONITOR ONLY',
                    'Strong new ENTRY_CONFIRMED only · MONITOR ONLY',
                  ),
                ),
                trailing: ProductStatusChip(
                  label: strings.active,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  preferences.soundEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                ),
                title: Text(strings.pick('Звук сигнала', 'Alert sound')),
                subtitle: Text(
                  strings.pick(
                    'Системный звук при сильном подтверждённом входе',
                    'System sound for a strong confirmed entry',
                  ),
                ),
                value: preferences.soundEnabled,
                onChanged: preferences.setSoundEnabled,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _PlannedSettingsGroup(
          title: strings.pick('Данные и исследование', 'Data and Research'),
          icon: Icons.storage_outlined,
          items: <String>[
            strings.pick('Интеграции', 'Integrations'),
            'Backtest',
            strings.pick('Данные', 'Data'),
          ],
        ),
      ],
    );
  }
}

class _PlannedSettingsGroup extends StatelessWidget {
  const _PlannedSettingsGroup({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return ProductExpandableSection(
      title: title,
      icon: icon,
      child: Column(
        children: items
            .map<Widget>(
              (String item) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(item),
                trailing: ProductStatusChip(
                  label: context.strings.planned,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
