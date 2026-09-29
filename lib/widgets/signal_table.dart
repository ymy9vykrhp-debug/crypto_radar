import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/execution_models.dart';
import '../models/signal_models.dart';
import '../theme/app_theme.dart';
import 'product_components.dart';

enum SignalTableMode { signals, journal }

class SignalTable extends StatefulWidget {
  const SignalTable({
    super.key,
    required this.signals,
    this.symbol,
    this.mode = SignalTableMode.signals,
  });

  final List<RadarSignal> signals;
  final String? symbol;
  final SignalTableMode mode;

  @override
  State<SignalTable> createState() => _SignalTableState();
}

class _SignalTableState extends State<SignalTable> {
  final TextEditingController _searchController = TextEditingController();
  SignalStatus? _status;
  bool _sortAscending = false;
  int _sortColumn = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RadarSignal> get _filtered {
    final String query = _searchController.text.trim().toUpperCase();
    final List<RadarSignal> result = widget.signals
        .where((RadarSignal signal) {
          if (widget.symbol != null && signal.symbol != widget.symbol) {
            return false;
          }
          if (_status != null && signal.status != _status) {
            return false;
          }
          if (query.isNotEmpty &&
              !signal.symbol.contains(query) &&
              !signal.direction.label.contains(query) &&
              !signal.style.label.toUpperCase().contains(query) &&
              !signal.status.code.contains(query)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
    result.sort((RadarSignal a, RadarSignal b) {
      int comparison;
      switch (_sortColumn) {
        case 1:
          comparison = a.symbol.compareTo(b.symbol);
        case 5:
          comparison = a.resultR.compareTo(b.resultR);
        case 6:
          comparison = a.status.code.compareTo(b.status.code);
        default:
          comparison = a.time.compareTo(b.time);
      }
      return _sortAscending ? comparison : -comparison;
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final List<RadarSignal> signals = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 300,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: strings.search,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<SignalStatus?>(
                initialValue: _status,
                decoration: InputDecoration(
                  labelText: strings.pick('Статус', 'Status'),
                  prefixIcon: const Icon(Icons.filter_alt_outlined),
                ),
                items: <DropdownMenuItem<SignalStatus?>>[
                  DropdownMenuItem<SignalStatus?>(
                    value: null,
                    child: Text(strings.all),
                  ),
                  ...SignalStatus.values.map<DropdownMenuItem<SignalStatus?>>(
                    (SignalStatus status) => DropdownMenuItem<SignalStatus?>(
                      value: status,
                      child: Text(status.code),
                    ),
                  ),
                ],
                onChanged: (SignalStatus? value) =>
                    setState(() => _status = value),
              ),
            ),
            Text(
              '${strings.pick('Найдено', 'Found')}: ${signals.length}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (signals.isEmpty)
          ProductEmptyState(
            icon: Icons.inbox_outlined,
            title: strings.noData,
            message: strings.pick(
              'Новые уникальные сигналы появятся здесь автоматически.',
              'New unique signals will appear here automatically.',
            ),
          )
        else
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth < 760) {
                return Column(
                  children: signals
                      .map<Widget>(
                        (RadarSignal signal) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SignalMobileCard(
                            signal: signal,
                            onTap: () => _showSignalDetails(context, signal),
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
                    sortColumnIndex: _sortColumn,
                    sortAscending: _sortAscending,
                    showCheckboxColumn: false,
                    columns: <DataColumn>[
                      _column(strings.pick('Время', 'Time'), 0),
                      _column(strings.pick('Актив', 'Asset'), 1),
                      const DataColumn(label: Text('Side')),
                      DataColumn(
                        label: Text(strings.pick('Стратегия', 'Strategy')),
                      ),
                      const DataColumn(label: Text('Entry')),
                      DataColumn(
                        label: Text(strings.pick('Результат', 'Result')),
                      ),
                      _column('R', 5),
                      _column(strings.pick('Статус', 'Status'), 6),
                    ],
                    rows: signals
                        .map<DataRow>(
                          (RadarSignal signal) => DataRow(
                            onSelectChanged: (_) =>
                                _showSignalDetails(context, signal),
                            cells: <DataCell>[
                              DataCell(Text(_dateTime(signal.time))),
                              DataCell(Text(signal.symbol)),
                              DataCell(_DirectionText(signal: signal)),
                              DataCell(Text(signal.style.label)),
                              DataCell(Text(_price(signal.entryPrice))),
                              DataCell(Text(_resultLabel(signal))),
                              DataCell(Text(signal.resultR.toStringAsFixed(2))),
                              DataCell(Text(signal.status.code)),
                            ],
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  DataColumn _column(String label, int index) {
    return DataColumn(
      label: Text(label),
      onSort: (int columnIndex, bool ascending) {
        setState(() {
          _sortColumn = index;
          _sortAscending = ascending;
        });
      },
    );
  }

  Future<void> _showSignalDetails(
    BuildContext context,
    RadarSignal signal,
  ) async {
    final AppStrings strings = context.strings;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Row(
          children: <Widget>[
            Expanded(child: Text(signal.symbol)),
            _DirectionText(signal: signal),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _DetailGroup(
                  title: strings.pick('Сетап', 'Setup'),
                  icon: Icons.adjust_rounded,
                  rows: <MapEntry<String, String>>[
                    MapEntry('Time', _dateTime(signal.time)),
                    MapEntry('Strategy', signal.style.label),
                    MapEntry('Stage', signal.stage.code),
                    MapEntry('Status', signal.status.code),
                    MapEntry('Score', '${signal.score}/100'),
                  ],
                ),
                _DetailGroup(
                  title: strings.pick('План сделки', 'Trade plan'),
                  icon: Icons.route_outlined,
                  rows: <MapEntry<String, String>>[
                    MapEntry(
                      'Entry',
                      '${_price(signal.entryLow)}–${_price(signal.entryHigh)}',
                    ),
                    MapEntry('Stop', _price(signal.stop)),
                    MapEntry('TP1', _price(signal.tp1)),
                    MapEntry('TP2', _price(signal.tp2)),
                    MapEntry(
                      strings.pick('Плечо', 'Leverage'),
                      '${signal.leverage}x',
                    ),
                  ],
                ),
                _DetailGroup(
                  title: strings.pick('Результат и риск', 'Result and risk'),
                  icon: Icons.monitor_heart_outlined,
                  rows: <MapEntry<String, String>>[
                    MapEntry('Result', '${signal.resultR.toStringAsFixed(2)}R'),
                    MapEntry(
                      'MFE',
                      '${signal.mfeR.toStringAsFixed(2)}R / ${signal.mfePercent.toStringAsFixed(2)}%',
                    ),
                    MapEntry(
                      'MAE',
                      '${signal.maeR.toStringAsFixed(2)}R / ${signal.maePercent.toStringAsFixed(2)}%',
                    ),
                    MapEntry(
                      'Overshoot',
                      '${signal.overshootAtr.toStringAsFixed(2)} ATR',
                    ),
                    MapEntry('Stop→TP', signal.stopThenTarget ? 'YES' : 'NO'),
                  ],
                ),
                _DetailGroup(
                  title: strings.pick('Хронология', 'Timeline'),
                  icon: Icons.timeline_rounded,
                  rows: <MapEntry<String, String>>[
                    MapEntry('Signal', _dateTime(signal.time)),
                    MapEntry('Entry', _optionalDateTime(signal.entryTime)),
                    MapEntry('TP1', _optionalDateTime(signal.tp1Time)),
                    MapEntry('TP2', _optionalDateTime(signal.tp2Time)),
                    MapEntry('Stop', _optionalDateTime(signal.stopTime)),
                    MapEntry('Exit', _optionalDateTime(signal.exitTime)),
                  ],
                ),
                _DetailGroup(
                  title: strings.pick('Ошибки и review', 'Errors and Review'),
                  icon: Icons.rate_review_outlined,
                  rows: <MapEntry<String, String>>[
                    MapEntry('Stop→TP', signal.stopThenTarget ? 'YES' : 'NO'),
                    MapEntry('Reclaim', signal.reclaimedLevel ? 'YES' : 'NO'),
                    MapEntry(
                      strings.pick('Ручной review', 'Manual review'),
                      strings.pick('Не заполнен', 'Not filled'),
                    ),
                  ],
                ),
                ProductExpandableSection(
                  title: strings.pick(
                    'Почему и технические данные',
                    'Why and technical data',
                  ),
                  icon: Icons.help_outline_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        signal.executionAction.isEmpty
                            ? '—'
                            : signal.executionAction,
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        signal.reasonCodes.isEmpty
                            ? '—'
                            : signal.reasonCodes.join(' · '),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'RSI ${signal.rsi.toStringAsFixed(1)} · '
                        'MACD ${signal.macd.toStringAsFixed(6)} · '
                        'RVOL ${signal.relativeVolume.toStringAsFixed(2)}x',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.close),
          ),
        ],
      ),
    );
  }
}

class _SignalMobileCard extends StatelessWidget {
  const _SignalMobileCard({required this.signal, required this.onTap});

  final RadarSignal signal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          signal.direction == SignalDirection.long
              ? Icons.north_east_rounded
              : Icons.south_east_rounded,
          color: signal.direction == SignalDirection.long
              ? Theme.of(context).extension<RadarSemanticColors>()!.bullish
              : Theme.of(context).extension<RadarSemanticColors>()!.bearish,
        ),
        title: Text(
          '${signal.symbol} · ${signal.direction.label}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('${_dateTime(signal.time)} · ${signal.style.label}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(signal.status.code, style: const TextStyle(fontSize: 11)),
            Text('${signal.resultR.toStringAsFixed(2)}R'),
          ],
        ),
      ),
    );
  }
}

class _DirectionText extends StatelessWidget {
  const _DirectionText({required this.signal});

  final RadarSignal signal;

  @override
  Widget build(BuildContext context) {
    final RadarSemanticColors semantic = Theme.of(context)
        .extension<RadarSemanticColors>()!;
    final Color color = signal.direction == SignalDirection.long
        ? semantic.bullish
        : semantic.bearish;
    return Text(
      signal.direction.label,
      style: TextStyle(color: color, fontWeight: FontWeight.w800),
    );
  }
}

class _DetailGroup extends StatelessWidget {
  const _DetailGroup({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    icon,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...rows.map<Widget>(
                (MapEntry<String, String> row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: <Widget>[
                      Expanded(child: Text(row.key)),
                      const SizedBox(width: 18),
                      Flexible(
                        child: Text(
                          row.value,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _dateTime(DateTime value) {
  final DateTime local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}

String _optionalDateTime(DateTime? value) =>
    value == null ? '—' : _dateTime(value);

String _price(double value) {
  if (!value.isFinite || value == 0) return '—';
  if (value >= 1000) return value.toStringAsFixed(2);
  if (value >= 1) return value.toStringAsFixed(4);
  return value.toStringAsFixed(6);
}

String _resultLabel(RadarSignal signal) {
  if (signal.status.isActive) return 'ACTIVE';
  if (signal.status == SignalStatus.stopped) return 'LOSS';
  if (signal.status == SignalStatus.tp1Hit ||
      signal.status == SignalStatus.tp2Hit) {
    return 'WIN';
  }
  return '—';
}
