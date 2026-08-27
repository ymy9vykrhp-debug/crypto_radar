import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/position_calculator_models.dart';
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
        ProductExpandableSection(
          title: strings.pick('Торговля и риск', 'Trading and Risk'),
          icon: Icons.shield_outlined,
          initiallyExpanded: true,
          child: _TradingRiskSettings(preferences: preferences),
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

class _TradingRiskSettings extends StatelessWidget {
  const _TradingRiskSettings({required this.preferences});

  final AppPreferencesController preferences;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final FeeModel fee = preferences.feeModel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          strings.pick('Стандартный риск', 'Default risk'),
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: RiskPreset.values
              .map<Widget>(
                (RiskPreset preset) => ChoiceChip(
                  selected: preferences.riskPreset == preset,
                  label: Text(_riskLabel(strings, preset)),
                  onSelected: (_) => preferences.setRiskPreset(preset),
                ),
              )
              .toList(growable: false),
        ),
        if (preferences.riskPreset == RiskPreset.custom) ...<Widget>[
          const SizedBox(height: 10),
          SizedBox(
            width: 210,
            child: TextFormField(
              key: ValueKey<String>(
                'custom-risk-${preferences.customRiskPercent}',
              ),
              initialValue: preferences.customRiskPercent.toStringAsFixed(2),
              decoration: InputDecoration(
                labelText: strings.pick('Свой риск', 'Custom risk'),
                suffixText: '%',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onFieldSubmitted: (String value) {
                final double? parsed = _parseNumber(value);
                if (parsed != null) preferences.setCustomRiskPercent(parsed);
              },
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          strings.pick(
            'Для 100 USDT максимальный плановый убыток: ${_money(preferences.effectiveRiskPercent)}. Маржа — это выделенная сумма, а не допустимый убыток.',
            'For 100 USDT the maximum planned loss is ${_money(preferences.effectiveRiskPercent)}. Allocated margin is not the allowed loss.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Divider(height: 28),
        Text(
          'Fee Model · USDT Perpetual',
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          strings.pick(
            'Редактируемые оценки. Фактические ставки зависят от аккаунта и региона Bybit.',
            'Editable estimates. Actual rates depend on the Bybit account and region.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _PercentSettingField(
              label: 'Maker fee',
              value: fee.makerFeePercent,
              onSubmitted: (double value) =>
                  preferences.setFeeModel(fee.copyWith(makerFeePercent: value)),
            ),
            _PercentSettingField(
              label: 'Taker fee',
              value: fee.takerFeePercent,
              onSubmitted: (double value) =>
                  preferences.setFeeModel(fee.copyWith(takerFeePercent: value)),
            ),
            _PercentSettingField(
              label: strings.pick('Spread (оценка)', 'Spread estimate'),
              value: fee.estimatedSpreadPercent,
              onSubmitted: (double value) => preferences.setFeeModel(
                fee.copyWith(estimatedSpreadPercent: value),
              ),
            ),
            _PercentSettingField(
              label: 'TP slippage',
              value: fee.targetSlippagePercent,
              onSubmitted: (double value) => preferences.setFeeModel(
                fee.copyWith(targetSlippagePercent: value),
              ),
            ),
            _PercentSettingField(
              label: 'Stop slippage',
              value: fee.stopSlippagePercent,
              onSubmitted: (double value) => preferences.setFeeModel(
                fee.copyWith(stopSlippagePercent: value),
              ),
            ),
            _PercentSettingField(
              label: strings.pick('Safety buffer', 'Safety buffer'),
              value: fee.safetyBufferPercent,
              onSubmitted: (double value) => preferences.setFeeModel(
                fee.copyWith(safetyBufferPercent: value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _OrderTypeField(
              label: strings.pick('Вход', 'Entry'),
              value: fee.entryOrderType,
              onChanged: (FeeOrderType value) =>
                  preferences.setFeeModel(fee.copyWith(entryOrderType: value)),
            ),
            _OrderTypeField(
              label: strings.pick('Выход по цели', 'Target exit'),
              value: fee.targetExitOrderType,
              onChanged: (FeeOrderType value) => preferences.setFeeModel(
                fee.copyWith(targetExitOrderType: value),
              ),
            ),
            _OrderTypeField(
              label: strings.pick('Исполнение Stop', 'Stop execution'),
              value: fee.stopOrderType,
              onChanged: (FeeOrderType value) =>
                  preferences.setFeeModel(fee.copyWith(stopOrderType: value)),
            ),
          ],
        ),
      ],
    );
  }

  String _riskLabel(AppStrings strings, RiskPreset preset) {
    switch (preset) {
      case RiskPreset.cautious:
        return strings.pick('🟢 Осторожный · 1%', '🟢 Cautious · 1%');
      case RiskPreset.normal:
        return strings.pick('🟡 Нормальный · 2%', '🟡 Normal · 2%');
      case RiskPreset.active:
        return strings.pick('🟠 Активный · 3%', '🟠 Active · 3%');
      case RiskPreset.custom:
        return strings.pick('⚙️ Свой риск', '⚙️ Custom risk');
    }
  }
}

class _PercentSettingField extends StatelessWidget {
  const _PercentSettingField({
    required this.label,
    required this.value,
    required this.onSubmitted,
  });

  final String label;
  final double value;
  final ValueChanged<double> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: TextFormField(
        key: ValueKey<String>('$label-$value'),
        initialValue: value.toStringAsFixed(3),
        decoration: InputDecoration(labelText: label, suffixText: '%'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onFieldSubmitted: (String raw) {
          final double? parsed = _parseNumber(raw);
          if (parsed != null && parsed >= 0 && parsed <= 5) {
            onSubmitted(parsed);
          }
        },
      ),
    );
  }
}

class _OrderTypeField extends StatelessWidget {
  const _OrderTypeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final FeeOrderType value;
  final ValueChanged<FeeOrderType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<FeeOrderType>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: FeeOrderType.values
            .map<DropdownMenuItem<FeeOrderType>>(
              (FeeOrderType type) => DropdownMenuItem<FeeOrderType>(
                value: type,
                child: Text(type.name.toUpperCase()),
              ),
            )
            .toList(growable: false),
        onChanged: (FeeOrderType? selected) {
          if (selected != null) onChanged(selected);
        },
      ),
    );
  }
}

double? _parseNumber(String raw) =>
    double.tryParse(raw.trim().replaceAll(',', '.'));

String _money(double value) => '\$${value.toStringAsFixed(2)}';

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
