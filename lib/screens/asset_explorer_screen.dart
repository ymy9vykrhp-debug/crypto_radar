import 'package:flutter/material.dart';

import '../engines/decision_engine.dart';
import '../engines/phase_a_engine.dart';
import '../engines/signal_engine.dart';
import '../localization/app_strings.dart';
import '../models/crypto_universe_models.dart';
import '../models/decision_models.dart';
import '../models/execution_models.dart';
import '../models/market_models.dart';
import '../models/signal_models.dart';
import '../services/crypto_universe_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/product_components.dart';

class AssetExplorerScreen extends StatefulWidget {
  const AssetExplorerScreen({
    super.key,
    required this.controller,
    required this.selectedSymbol,
    required this.onSelect,
    this.selectedSnapshot,
  });

  final CryptoUniverseController controller;
  final String selectedSymbol;
  final MarketSnapshot? selectedSnapshot;
  final ValueChanged<String> onSelect;

  @override
  State<AssetExplorerScreen> createState() => _AssetExplorerScreenState();
}

class _AssetExplorerScreenState extends State<AssetExplorerScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final AppStrings strings = context.strings;
        final List<CryptoAsset> assets = widget.controller.visibleAssets;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: <Widget>[
            SectionHeading(
              title: 'Asset Explorer',
              subtitle: strings.pick(
                'Динамический список торгуемых Bybit USDT Perpetual инструментов',
                'Dynamic list of tradable Bybit USDT Perpetual instruments',
              ),
              icon: Icons.travel_explore_rounded,
              trailing: IconButton.filledTonal(
                tooltip: strings.refreshNow,
                onPressed: widget.controller.loading
                    ? null
                    : () => widget.controller.refresh(force: true),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            const SizedBox(height: 12),
            _CategoryBar(controller: widget.controller),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _searchController,
                    onChanged: widget.controller.setQuery,
                    decoration: InputDecoration(
                      labelText: strings.search,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                widget.controller.setQuery('');
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 230,
                  child: DropdownButtonFormField<AssetSort>(
                    initialValue: widget.controller.sort,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: strings.pick('Сортировка', 'Sorting'),
                      prefixIcon: const Icon(Icons.sort_rounded),
                    ),
                    items: AssetSort.values
                        .map<DropdownMenuItem<AssetSort>>(
                          (AssetSort sort) => DropdownMenuItem<AssetSort>(
                            value: sort,
                            child: Text(
                              _sortLabel(strings, sort),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (AssetSort? value) {
                      if (value != null) widget.controller.setSort(value);
                    },
                  ),
                ),
                Text(
                  '${strings.pick('Инструменты', 'Instruments')}: ${widget.controller.assets.length} · '
                  '${strings.pick('Показано', 'Shown')}: ${assets.length}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            if (widget.controller.loading) ...<Widget>[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (widget.controller.error != null) ...<Widget>[
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.cloud_off_outlined),
                  title: Text(
                    strings.pick(
                      'Ошибка обновления universe',
                      'Universe refresh error',
                    ),
                  ),
                  subtitle: Text(widget.controller.error!),
                  trailing: TextButton(
                    onPressed: () => widget.controller.refresh(force: true),
                    child: Text(strings.pick('Повторить', 'Retry')),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (assets.isEmpty && !widget.controller.loading)
              ProductEmptyState(
                icon: Icons.manage_search_rounded,
                title: strings.noData,
                message: strings.pick(
                  'Измените категорию или строку поиска.',
                  'Change the category or search query.',
                ),
              )
            else
              _AssetResults(
                assets: assets,
                selectedSymbol: widget.selectedSymbol,
                selectedSnapshot: widget.selectedSnapshot,
                controller: widget.controller,
                onSelect: widget.onSelect,
              ),
            const SizedBox(height: 10),
            Text(
              strings.pick(
                'FAST SCAN показывает только публичные market metrics. Полный Radar State и Signal Strength рассчитываются после открытия workspace актива.',
                'FAST SCAN shows public market metrics only. Full Radar State and Signal Strength are calculated after opening the asset workspace.',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.controller});

  final CryptoUniverseController controller;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AssetCategory.values
            .map<Widget>(
              (AssetCategory category) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: controller.category == category,
                  avatar: Icon(_categoryIcon(category), size: 16),
                  label: Text(_categoryLabel(strings, category)),
                  onSelected: (_) => controller.setCategory(category),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _AssetResults extends StatelessWidget {
  const _AssetResults({
    required this.assets,
    required this.selectedSymbol,
    required this.selectedSnapshot,
    required this.controller,
    required this.onSelect,
  });

  final List<CryptoAsset> assets;
  final String selectedSymbol;
  final MarketSnapshot? selectedSnapshot;
  final CryptoUniverseController controller;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 820) {
          return Column(
            children: assets
                .map<Widget>(
                  (CryptoAsset asset) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AssetMobileCard(
                      asset: asset,
                      selected: asset.symbol == selectedSymbol,
                      favorite: controller.isFavorite(asset.symbol),
                      deepState: _deepState(asset.symbol, selectedSnapshot),
                      onFavorite: () => controller.toggleFavorite(asset.symbol),
                      onTap: () => onSelect(asset.symbol),
                    ),
                  ),
                )
                .toList(growable: false),
          );
        }
        return Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columns: <DataColumn>[
                const DataColumn(label: SizedBox(width: 30)),
                const DataColumn(label: Text('Symbol')),
                const DataColumn(label: Text('Price'), numeric: true),
                const DataColumn(label: Text('24h'), numeric: true),
                const DataColumn(label: Text('Volume'), numeric: true),
                const DataColumn(label: Text('Turnover'), numeric: true),
                const DataColumn(label: Text('Volatility'), numeric: true),
                const DataColumn(label: Text('Radar State')),
                const DataColumn(label: Text('Strength')),
                const DataColumn(label: Text('Setup Stage')),
              ],
              rows: assets
                  .map<DataRow>((CryptoAsset asset) {
                    final _AssetDeepState? deep = _deepState(
                      asset.symbol,
                      selectedSnapshot,
                    );
                    final _FastState fast = _fastState(asset);
                    final bool selected = asset.symbol == selectedSymbol;
                    return DataRow(
                      selected: selected,
                      onSelectChanged: (_) => onSelect(asset.symbol),
                      cells: <DataCell>[
                        DataCell(
                          IconButton(
                            tooltip: controller.isFavorite(asset.symbol)
                                ? 'Remove favorite'
                                : 'Add favorite',
                            onPressed: () =>
                                controller.toggleFavorite(asset.symbol),
                            icon: Icon(
                              controller.isFavorite(asset.symbol)
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: controller.isFavorite(asset.symbol)
                                  ? Theme.of(context).colorScheme.secondary
                                  : null,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            asset.symbol,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        DataCell(Text(_price(asset.lastPrice))),
                        DataCell(_ChangeText(value: asset.change24hPercent)),
                        DataCell(Text(_quantity(asset.volume24h))),
                        DataCell(Text(_compact(asset.turnover24h))),
                        DataCell(
                          Text(
                            '${asset.volatilityPercent.toStringAsFixed(1)}%',
                          ),
                        ),
                        DataCell(
                          _StateText(
                            label: deep?.state ?? fast.label,
                            bias: deep?.bias ?? fast.bias,
                          ),
                        ),
                        DataCell(
                          Text(deep == null ? '—' : '${deep.strength}/100'),
                        ),
                        DataCell(Text(deep?.stage ?? 'FAST_SCAN')),
                      ],
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        );
      },
    );
  }
}

class _AssetMobileCard extends StatelessWidget {
  const _AssetMobileCard({
    required this.asset,
    required this.selected,
    required this.favorite,
    required this.deepState,
    required this.onFavorite,
    required this.onTap,
  });

  final CryptoAsset asset;
  final bool selected;
  final bool favorite;
  final _AssetDeepState? deepState;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final _FastState fast = _fastState(asset);
    return Card(
      color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: IconButton(
          onPressed: onFavorite,
          icon: Icon(favorite ? Icons.star_rounded : Icons.star_border_rounded),
        ),
        title: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                asset.symbol,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            _ChangeText(value: asset.change24hPercent),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '\$${_price(asset.lastPrice)} · Vol ${_quantity(asset.volume24h)} · '
            '${_compact(asset.turnover24h)} · '
            '${deepState?.stage ?? 'FAST_SCAN'}',
          ),
        ),
        trailing: _StateText(
          label: deepState?.state ?? fast.label,
          bias: deepState?.bias ?? fast.bias,
        ),
      ),
    );
  }
}

class _ChangeText extends StatelessWidget {
  const _ChangeText({required this.value});

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

class _StateText extends StatelessWidget {
  const _StateText({required this.label, required this.bias});

  final String label;
  final Bias bias;

  @override
  Widget build(BuildContext context) {
    final RadarSemanticColors semantic = Theme.of(context)
        .extension<RadarSemanticColors>()!;
    final Color color = switch (bias) {
      Bias.bullish => semantic.bullish,
      Bias.bearish => semantic.bearish,
      Bias.neutral => semantic.neutral,
    };
    return Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
    );
  }
}

class _AssetDeepState {
  const _AssetDeepState({
    required this.state,
    required this.bias,
    required this.strength,
    required this.stage,
  });

  final String state;
  final Bias bias;
  final int strength;
  final String stage;
}

class _FastState {
  const _FastState(this.label, this.bias);

  final String label;
  final Bias bias;
}

_AssetDeepState? _deepState(String symbol, MarketSnapshot? snapshot) {
  if (snapshot == null || snapshot.symbol != symbol) return null;
  final RadarSignal? raw = SignalEngine.createSignal(snapshot);
  final RadarSignal? execution = raw == null
      ? null
      : PhaseAEngine.preview(market: snapshot, signal: raw);
  final DecisionSnapshot decision = DecisionEngine.build(
    snapshot,
    executionSignal: execution,
  );
  return _AssetDeepState(
    state: decision.decision.label,
    bias: switch (decision.decision) {
      DecisionAction.long => Bias.bullish,
      DecisionAction.short => Bias.bearish,
      DecisionAction.wait => Bias.neutral,
    },
    strength: decision.signalScore,
    stage: decision.signalStage.code,
  );
}

_FastState _fastState(CryptoAsset asset) {
  if (asset.change24hPercent >= 2) {
    return const _FastState('FAST UP', Bias.bullish);
  }
  if (asset.change24hPercent <= -2) {
    return const _FastState('FAST DOWN', Bias.bearish);
  }
  return const _FastState('FAST NEUTRAL', Bias.neutral);
}

String _categoryLabel(AppStrings strings, AssetCategory category) {
  return switch (category) {
    AssetCategory.favorites => strings.pick('Избранное', 'Favorites'),
    AssetCategory.topLiquid => 'Top Liquid',
    AssetCategory.topAlts => 'Top Alts',
    AssetCategory.memeCoins => 'Meme Coins',
    AssetCategory.highVolatility => 'High Volatility',
    AssetCategory.all => strings.all,
  };
}

IconData _categoryIcon(AssetCategory category) {
  return switch (category) {
    AssetCategory.favorites => Icons.star_outline_rounded,
    AssetCategory.topLiquid => Icons.water_drop_outlined,
    AssetCategory.topAlts => Icons.token_outlined,
    AssetCategory.memeCoins => Icons.rocket_launch_outlined,
    AssetCategory.highVolatility => Icons.bolt_outlined,
    AssetCategory.all => Icons.apps_rounded,
  };
}

String _sortLabel(AppStrings strings, AssetSort sort) {
  return switch (sort) {
    AssetSort.turnover => 'Turnover 24h',
    AssetSort.volume => 'Volume 24h',
    AssetSort.change => strings.pick('Изменение 24h', '24h Change'),
    AssetSort.volatility => strings.pick('Волатильность', 'Volatility'),
    AssetSort.price => strings.pick('Цена', 'Price'),
    AssetSort.symbol => 'Symbol A–Z',
  };
}

String _price(double value) {
  if (value >= 1000) return value.toStringAsFixed(2);
  if (value >= 1) return value.toStringAsFixed(4);
  return value.toStringAsFixed(6);
}

String _compact(double value) {
  if (value >= 1000000000) {
    return '\$${(value / 1000000000).toStringAsFixed(2)}B';
  }
  if (value >= 1000000) return '\$${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '\$${(value / 1000).toStringAsFixed(1)}K';
  return '\$${value.toStringAsFixed(0)}';
}

String _quantity(double value) {
  if (value >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(2)}B';
  }
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value.toStringAsFixed(1);
}
