import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/crypto_universe_models.dart';
import '../services/crypto_universe_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/product_components.dart';

class MarketScannerScreen extends StatelessWidget {
  const MarketScannerScreen({
    super.key,
    required this.controller,
    required this.onSelect,
  });

  final CryptoUniverseController controller;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final AppStrings strings = context.strings;
        final List<CryptoAsset> liquid = CryptoUniverseRules.selectCategory(
          assets: controller.assets,
          category: AssetCategory.topLiquid,
          favorites: controller.favorites,
        ).take(10).toList(growable: false);
        final List<CryptoAsset> volatile = CryptoUniverseRules.selectCategory(
          assets: controller.assets,
          category: AssetCategory.highVolatility,
          favorites: controller.favorites,
        ).take(10).toList(growable: false);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: <Widget>[
            SectionHeading(
              title: 'Scanner · FAST SCAN',
              subtitle: strings.pick(
                'Лёгкий обзор цены, объёма, волатильности и изменения. Deep Analysis запускается только после выбора актива.',
                'Lightweight price, volume, volatility and change scan. Deep Analysis starts only after asset selection.',
              ),
              icon: Icons.radar_rounded,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final List<Widget> panels = <Widget>[
                  _ScannerList(
                    title: 'Top Liquid',
                    assets: liquid,
                    onSelect: onSelect,
                  ),
                  _ScannerList(
                    title: 'High Volatility',
                    assets: volatile,
                    onSelect: onSelect,
                  ),
                ];
                if (constraints.maxWidth >= 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: panels[0]),
                      const SizedBox(width: 12),
                      Expanded(child: panels[1]),
                    ],
                  );
                }
                return Column(
                  children: <Widget>[
                    panels[0],
                    const SizedBox(height: 12),
                    panels[1],
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            ProductExpandableSection(
              title: 'Opportunity Queue',
              icon: Icons.format_list_numbered_rounded,
              child: Text(
                strings.pick(
                  'READY NOW / SETUP FORMING / WATCH появятся в Phase 10 после scheduler, throttling и приоритетного Deep Analysis.',
                  'READY NOW / SETUP FORMING / WATCH will arrive in Phase 10 after scheduler, throttling and prioritized Deep Analysis.',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScannerList extends StatelessWidget {
  const _ScannerList({
    required this.title,
    required this.assets,
    required this.onSelect,
  });

  final String title;
  final List<CryptoAsset> assets;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (assets.isEmpty)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(context.strings.noData),
              )
            else
              ...assets.asMap().entries.map<Widget>(
                (MapEntry<int, CryptoAsset> entry) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onTap: () => onSelect(entry.value.symbol),
                  leading: CircleAvatar(
                    radius: 15,
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  title: Text(
                    entry.value.symbol,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    'Turnover ${_compact(entry.value.turnover24h)} · '
                    'Vol ${entry.value.volatilityPercent.toStringAsFixed(1)}%',
                  ),
                  trailing: _Change(value: entry.value.change24hPercent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Change extends StatelessWidget {
  const _Change({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final RadarSemanticColors semantic = Theme.of(context)
        .extension<RadarSemanticColors>()!;
    return Text(
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}%',
      style: TextStyle(
        color: value >= 0 ? semantic.bullish : semantic.bearish,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

String _compact(double value) {
  if (value >= 1000000000) {
    return '\$${(value / 1000000000).toStringAsFixed(1)}B';
  }
  if (value >= 1000000) return '\$${(value / 1000000).toStringAsFixed(0)}M';
  return '\$${(value / 1000).toStringAsFixed(0)}K';
}
