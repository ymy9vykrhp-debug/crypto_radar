import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../models/trading_journal_models.dart';
import '../../services/journal_controller.dart';
import '../../widgets/product_components.dart';
import 'journal_ui_helpers.dart';
import 'manual_trade_dialog.dart';

class JournalTradesView extends StatefulWidget {
  const JournalTradesView({
    super.key,
    required this.controller,
    required this.trades,
  });

  final JournalController controller;
  final List<TradeJournalEntry> trades;

  @override
  State<JournalTradesView> createState() => _JournalTradesViewState();
}

class _JournalTradesViewState extends State<JournalTradesView> {
  int _sortColumn = 0;
  bool _ascending = false;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final List<TradeJournalEntry> trades = List<TradeJournalEntry>.of(
      widget.trades,
    );
    trades.sort(_compare);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        SectionHeading(
          title: strings.pick('Сделки', 'Trades'),
          subtitle: strings.pick(
            'MANUAL можно изменять и удалять. PAPER/DEMO факты защищены.',
            'MANUAL records are editable. PAPER/DEMO execution facts are protected.',
          ),
          icon: Icons.swap_horiz_rounded,
          trailing: FilledButton.icon(
            onPressed: () =>
                openManualTradeEditor(context, controller: widget.controller),
            icon: const Icon(Icons.add_rounded),
            label: Text(strings.pick('Добавить сделку', 'Add Trade')),
          ),
        ),
        const SizedBox(height: 14),
        if (trades.isEmpty)
          ProductEmptyState(
            icon: Icons.receipt_long_outlined,
            title: strings.pick('Сделок пока нет', 'No trades yet'),
            message: strings.pick(
              'Добавьте ручную сделку. Открытую позицию можно закрыть позже.',
              'Add a manual trade. An open position can be closed later.',
            ),
            action: FilledButton.icon(
              onPressed: () =>
                  openManualTradeEditor(context, controller: widget.controller),
              icon: const Icon(Icons.add_rounded),
              label: Text(strings.pick('Добавить сделку', 'Add Trade')),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex: _sortColumn,
                sortAscending: _ascending,
                columns: <DataColumn>[
                  _column(strings.pick('Дата', 'Date'), 0),
                  const DataColumn(label: Text('Time')),
                  _column('Symbol', 2),
                  _column('Side', 3),
                  _column('Source', 4),
                  _column('Strategy', 5),
                  const DataColumn(label: Text('Entry'), numeric: true),
                  const DataColumn(label: Text('Exit'), numeric: true),
                  _column('PnL', 8, numeric: true),
                  _column('R', 9, numeric: true),
                  _column('Status', 10),
                ],
                rows: trades
                    .map<DataRow>(
                      (TradeJournalEntry trade) => DataRow(
                        onSelectChanged: (_) => openTradeDetail(
                          context,
                          controller: widget.controller,
                          trade: trade,
                        ),
                        cells: <DataCell>[
                          DataCell(Text(journalDate(trade.tradeTime))),
                          DataCell(Text(journalTime(trade.tradeTime))),
                          DataCell(
                            Text(
                              trade.symbol,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          DataCell(Text(trade.side.name.toUpperCase())),
                          DataCell(Text(tradeSourceLabel(trade.source))),
                          DataCell(
                            Text(trade.strategy.isEmpty ? '—' : trade.strategy),
                          ),
                          DataCell(Text(journalPrice(trade.effectiveEntry))),
                          DataCell(
                            Text(
                              trade.actualExit == null
                                  ? '—'
                                  : journalPrice(trade.actualExit!),
                            ),
                          ),
                          DataCell(
                            Text(
                              journalMoney(trade.netPnl, signed: true),
                              style: TextStyle(
                                color: tradeResultColor(context, trade.netPnl),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          DataCell(Text(journalR(trade.resultR))),
                          DataCell(Text(tradeStatusLabel(trade.status))),
                        ],
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
      ],
    );
  }

  DataColumn _column(String label, int index, {bool numeric = false}) =>
      DataColumn(
        label: Text(label),
        numeric: numeric,
        onSort: (int column, bool ascending) {
          setState(() {
            _sortColumn = column;
            _ascending = ascending;
          });
        },
      );

  int _compare(TradeJournalEntry first, TradeJournalEntry second) {
    final int result = switch (_sortColumn) {
      0 => first.tradeTime.compareTo(second.tradeTime),
      2 => first.symbol.compareTo(second.symbol),
      3 => first.side.index.compareTo(second.side.index),
      4 => first.source.index.compareTo(second.source.index),
      5 => first.strategy.compareTo(second.strategy),
      8 => first.netPnl.compareTo(second.netPnl),
      9 => first.resultR.compareTo(second.resultR),
      10 => first.status.index.compareTo(second.status.index),
      _ => first.tradeTime.compareTo(second.tradeTime),
    };
    return _ascending ? result : -result;
  }
}
