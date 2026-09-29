import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../localization/app_strings.dart';
import '../../models/trading_journal_models.dart';
import '../../services/journal_controller.dart';
import '../../theme/app_theme.dart';
import 'journal_ui_helpers.dart';

Future<void> openManualTradeEditor(
  BuildContext context, {
  required JournalController controller,
  TradeJournalEntry? existing,
}) async {
  final TradeJournalEntry? result = await showDialog<TradeJournalEntry>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => _ManualTradeDialog(existing: existing),
  );
  if (result == null) return;
  if (existing == null) {
    await controller.addManualTrade(result);
  } else {
    await controller.updateManualTrade(result);
  }
}

Future<void> openTradeDetail(
  BuildContext context, {
  required JournalController controller,
  required TradeJournalEntry trade,
}) async {
  await showDialog<void>(
    context: context,
    builder: (BuildContext context) =>
        _TradeDetailDialog(trade: trade, controller: controller),
  );
}

Future<void> openTradeReviewEditor(
  BuildContext context, {
  required JournalController controller,
  required TradeJournalEntry trade,
}) async {
  final TextEditingController notes = TextEditingController(
    text: trade.myNotes,
  );
  final TextEditingController good = TextEditingController(
    text: trade.whatWasGood,
  );
  final TextEditingController wrong = TextEditingController(
    text: trade.whatWasWrong,
  );
  final TextEditingController change = TextEditingController(
    text: trade.whatShouldChange,
  );
  final Set<TradeTag> tags = Set<TradeTag>.of(trade.tags);
  bool useForResearch = trade.useForStrategyResearch;
  final bool? save = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setDialogState) =>
          AlertDialog(
            title: Text(
              context.strings.pick('Заметки и разбор', 'Notes & Review'),
            ),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      controller: notes,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: context.strings.pick(
                          'Мои заметки',
                          'My Notes',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: TradeTag.values
                          .map<Widget>(
                            (TradeTag tag) => FilterChip(
                              label: Text(tradeTagLabel(tag)),
                              selected: tags.contains(tag),
                              onSelected: (bool selected) {
                                setDialogState(() {
                                  selected ? tags.add(tag) : tags.remove(tag);
                                });
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: good,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'What was good?',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: wrong,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'What was wrong?',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: change,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'What should change?',
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Use for Strategy Research'),
                      value: useForResearch,
                      onChanged: (bool value) =>
                          setDialogState(() => useForResearch = value),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.strings.pick('Отмена', 'Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.strings.pick('Сохранить', 'Save')),
              ),
            ],
          ),
    ),
  );
  if (save == true) {
    await controller.updateTradeReview(
      id: trade.id,
      myNotes: notes.text,
      tags: tags,
      whatWasGood: good.text,
      whatWasWrong: wrong.text,
      whatShouldChange: change.text,
      useForStrategyResearch: useForResearch,
    );
  }
  notes.dispose();
  good.dispose();
  wrong.dispose();
  change.dispose();
}

class _ManualTradeDialog extends StatefulWidget {
  const _ManualTradeDialog({this.existing});

  final TradeJournalEntry? existing;

  @override
  State<_ManualTradeDialog> createState() => _ManualTradeDialogState();
}

class _ManualTradeDialogState extends State<_ManualTradeDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late DateTime _tradeTime;
  DateTime? _exitTime;
  late JournalTradeSide _side;
  late EntryReason _entryReason;
  late Set<TradeTag> _tags;
  late bool _useForResearch;
  late final TextEditingController _symbol;
  late final TextEditingController _plannedEntry;
  late final TextEditingController _actualEntry;
  late final TextEditingController _stop;
  late final TextEditingController _tp1;
  late final TextEditingController _tp2;
  late final TextEditingController _tp3;
  late final TextEditingController _actualExit;
  late final TextEditingController _positionSize;
  late final TextEditingController _margin;
  late final TextEditingController _leverage;
  late final TextEditingController _fees;
  late final TextEditingController _strategy;
  late final TextEditingController _timeframe;
  late final TextEditingController _reasonText;
  late final TextEditingController _notes;
  late final TextEditingController _good;
  late final TextEditingController _wrong;
  late final TextEditingController _change;

  @override
  void initState() {
    super.initState();
    final TradeJournalEntry? trade = widget.existing;
    _tradeTime = trade?.tradeTime ?? DateTime.now();
    _exitTime = trade?.exitTime;
    _side = trade?.side ?? JournalTradeSide.long;
    _entryReason = trade?.entryReason ?? EntryReason.manualAnalysis;
    _tags = Set<TradeTag>.of(trade?.tags ?? const <TradeTag>{});
    _useForResearch = trade?.useForStrategyResearch ?? false;
    _symbol = TextEditingController(text: trade?.symbol ?? '');
    _plannedEntry = _numberController(trade?.plannedEntry);
    _actualEntry = _numberController(trade?.actualEntry);
    _stop = _numberController(trade?.stopLoss);
    _tp1 = _numberController(trade?.tp1);
    _tp2 = _numberController(trade?.tp2);
    _tp3 = _numberController(trade?.tp3);
    _actualExit = _numberController(trade?.actualExit);
    _positionSize = _numberController(trade?.positionSize);
    _margin = _numberController(trade?.margin);
    _leverage = _numberController(trade?.leverage ?? 1);
    _fees = _numberController(trade?.fees ?? 0);
    _strategy = TextEditingController(text: trade?.strategy ?? '');
    _timeframe = TextEditingController(text: trade?.timeframe ?? '5m');
    _reasonText = TextEditingController(text: trade?.entryReasonText ?? '');
    _notes = TextEditingController(text: trade?.myNotes ?? '');
    _good = TextEditingController(text: trade?.whatWasGood ?? '');
    _wrong = TextEditingController(text: trade?.whatWasWrong ?? '');
    _change = TextEditingController(text: trade?.whatShouldChange ?? '');
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _symbol,
      _plannedEntry,
      _actualEntry,
      _stop,
      _tp1,
      _tp2,
      _tp3,
      _actualExit,
      _positionSize,
      _margin,
      _leverage,
      _fees,
      _strategy,
      _timeframe,
      _reasonText,
      _notes,
      _good,
      _wrong,
      _change,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 820),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.add_chart_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.existing == null
                          ? strings.pick('Добавить сделку', 'Add Trade')
                          : strings.pick('Изменить сделку', 'Edit Trade'),
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _sectionTitle(strings.pick('Общее', 'General')),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          _field(
                            _symbol,
                            'Symbol',
                            width: 220,
                            validator: _required,
                            capitalization: TextCapitalization.characters,
                          ),
                          SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<JournalTradeSide>(
                              isExpanded: true,
                              initialValue: _side,
                              decoration: const InputDecoration(
                                labelText: 'Side',
                              ),
                              items: JournalTradeSide.values
                                  .map<DropdownMenuItem<JournalTradeSide>>(
                                    (JournalTradeSide value) =>
                                        DropdownMenuItem<JournalTradeSide>(
                                          value: value,
                                          child: Text(value.name.toUpperCase()),
                                        ),
                                  )
                                  .toList(growable: false),
                              onChanged: (JournalTradeSide? value) {
                                if (value != null) {
                                  setState(() => _side = value);
                                }
                              },
                            ),
                          ),
                          _dateButton(
                            label: strings.pick(
                              'Дата и время',
                              'Date and Time',
                            ),
                            value: _tradeTime,
                            onPressed: () => _pickDateTime(exit: false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle(strings.pick('План', 'Plan')),
                      _priceFields(),
                      const SizedBox(height: 20),
                      _sectionTitle(strings.pick('Исполнение', 'Execution')),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          _numeric(
                            _actualEntry,
                            'Actual Entry',
                            required: true,
                          ),
                          _numeric(_actualExit, 'Actual Exit'),
                          _dateButton(
                            label: strings.pick('Время выхода', 'Exit Time'),
                            value: _exitTime,
                            onPressed: () => _pickDateTime(exit: true),
                            allowClear: true,
                          ),
                          _numeric(_positionSize, 'Position Size'),
                          _numeric(_margin, 'Margin'),
                          _numeric(_leverage, 'Leverage', required: true),
                          _numeric(_fees, 'Fees'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle(strings.pick('Анализ', 'Analysis')),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          _field(_strategy, 'Strategy', width: 260),
                          _field(_timeframe, 'Timeframe', width: 160),
                          SizedBox(
                            width: 260,
                            child: DropdownButtonFormField<EntryReason>(
                              isExpanded: true,
                              initialValue: _entryReason,
                              decoration: InputDecoration(
                                labelText: strings.pick(
                                  'Причина входа',
                                  'Entry Reason',
                                ),
                              ),
                              items: EntryReason.values
                                  .map<DropdownMenuItem<EntryReason>>(
                                    (EntryReason value) =>
                                        DropdownMenuItem<EntryReason>(
                                          value: value,
                                          child: Text(
                                            entryReasonLabel(strings, value),
                                          ),
                                        ),
                                  )
                                  .toList(growable: false),
                              onChanged: (EntryReason? value) {
                                if (value != null) {
                                  setState(() => _entryReason = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _field(
                        _reasonText,
                        strings.pick(
                          'Причина входа — текст',
                          'Entry reason details',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Tags',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: TradeTag.values
                            .map<Widget>(
                              (TradeTag tag) => FilterChip(
                                label: Text(tradeTagLabel(tag)),
                                selected: _tags.contains(tag),
                                onSelected: (bool selected) {
                                  setState(() {
                                    selected
                                        ? _tags.add(tag)
                                        : _tags.remove(tag);
                                  });
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle(
                        strings.pick('Заметки и разбор', 'Notes and Review'),
                      ),
                      _field(
                        _notes,
                        strings.pick('Мои заметки', 'My Notes'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 10),
                      _field(_good, 'What was good?', maxLines: 2),
                      const SizedBox(height: 10),
                      _field(_wrong, 'What was wrong?', maxLines: 2),
                      const SizedBox(height: 10),
                      _field(_change, 'What should change?', maxLines: 2),
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Use for Strategy Research'),
                        subtitle: Text(
                          strings.pick(
                            'По умолчанию выключено: ручная сделка может быть не по правилам Radar.',
                            'Off by default: a manual trade may not follow Radar rules.',
                          ),
                        ),
                        value: _useForResearch,
                        onChanged: (bool value) =>
                            setState(() => _useForResearch = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(strings.pick('Отмена', 'Cancel')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(strings.pick('Сохранить', 'Save')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceFields() => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: <Widget>[
      _numeric(_plannedEntry, 'Planned Entry', required: true),
      _numeric(_stop, 'Stop Loss', required: true),
      _numeric(_tp1, 'TP1', required: true),
      _numeric(_tp2, 'TP2', required: true),
      _numeric(_tp3, 'TP3'),
    ],
  );

  Widget _numeric(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) => _field(
    controller,
    label,
    width: 170,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]')),
    ],
    validator: required ? _positive : null,
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    double? width,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    TextCapitalization capitalization = TextCapitalization.sentences,
  }) {
    final Widget child = TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      textCapitalization: capitalization,
    );
    return width == null ? child : SizedBox(width: width, child: child);
  }

  Widget _dateButton({
    required String label,
    required DateTime? value,
    required VoidCallback onPressed,
    bool allowClear = false,
  }) => SizedBox(
    width: 220,
    child: InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              value == null
                  ? '—'
                  : '${journalDate(value)} ${journalTime(value)}',
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onPressed,
            icon: const Icon(Icons.event_outlined, size: 19),
          ),
          if (allowClear && value != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _exitTime = null),
              icon: const Icon(Icons.clear_rounded, size: 19),
            ),
        ],
      ),
    ),
  );

  Widget _sectionTitle(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
  );

  Future<void> _pickDateTime({required bool exit}) async {
    final DateTime initial = exit ? _exitTime ?? _tradeTime : _tradeTime;
    final DateTime? date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDate: initial,
    );
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final DateTime result = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (exit) {
        _exitTime = result;
      } else {
        _tradeTime = result;
      }
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final double plannedEntry = _parse(_plannedEntry.text);
    final double actualEntry = _parse(_actualEntry.text);
    final double stop = _parse(_stop.text);
    final double tp1 = _parse(_tp1.text);
    final double tp2 = _parse(_tp2.text);
    final double? exit = _optional(_actualExit.text);
    final double referenceEntry = actualEntry > 0 ? actualEntry : plannedEntry;
    final bool levelsValid = _side == JournalTradeSide.long
        ? stop < referenceEntry && tp1 > referenceEntry && tp2 > referenceEntry
        : stop > referenceEntry && tp1 < referenceEntry && tp2 < referenceEntry;
    if (!levelsValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.pick(
              'Проверьте направление Stop и Take Profit относительно Entry.',
              'Check Stop and Take Profit direction relative to Entry.',
            ),
          ),
        ),
      );
      return;
    }
    final TradeJournalEntry? existing = widget.existing;
    final DateTime now = DateTime.now();
    TradeJournalEntry result = TradeJournalEntry.manual(
      id: existing?.id ?? 'manual-${now.microsecondsSinceEpoch}',
      now: existing?.createdAt ?? now,
      tradeTime: _tradeTime,
      symbol: _symbol.text,
      side: _side,
      plannedEntry: plannedEntry,
      stopLoss: stop,
      tp1: tp1,
      tp2: tp2,
      tp3: _optional(_tp3.text),
      actualEntry: actualEntry,
      actualExit: exit,
      exitTime: exit == null ? null : _exitTime ?? now,
      positionSize: _parse(_positionSize.text),
      margin: _parse(_margin.text),
      leverage: _parse(_leverage.text),
      fees: _parse(_fees.text),
      strategy: _strategy.text,
      timeframe: _timeframe.text,
      entryReason: _entryReason,
      entryReasonText: _reasonText.text,
      myNotes: _notes.text,
      tags: _tags,
      whatWasGood: _good.text,
      whatWasWrong: _wrong.text,
      whatShouldChange: _change.text,
      useForStrategyResearch: _useForResearch,
      contextSnapshot:
          existing?.contextSnapshot ??
          const TradeContextSnapshot(
            strategyVersion: 'manual-v1',
            signalEngineVersion: 'not-used',
            dataEngineVersion: 'manual-entry',
          ),
    );
    if (existing != null && exit == null) {
      result = result.copyWith(clearActualExit: true, clearExitTime: true);
    }
    Navigator.of(context).pop(result.withCalculatedStatus());
  }
}

class _TradeDetailDialog extends StatelessWidget {
  const _TradeDetailDialog({required this.trade, required this.controller});

  final TradeJournalEntry trade;
  final JournalController controller;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final RadarSemanticColors semantic = Theme.of(context)
        .extension<RadarSemanticColors>()!;
    final Color resultColor = tradeResultColor(context, trade.netPnl);
    return AlertDialog(
      title: Row(
        children: <Widget>[
          Expanded(
            child: Text('${trade.symbol} · ${trade.side.name.toUpperCase()}'),
          ),
          Text(
            tradeStatusLabel(trade.status),
            style: TextStyle(color: resultColor, fontWeight: FontWeight.w900),
          ),
        ],
      ),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _detailSection(
                context,
                strings.pick('Общее', 'General'),
                <String, String>{
                  'Date': journalDate(trade.tradeTime),
                  'Time': journalTime(trade.tradeTime),
                  'Source': tradeSourceLabel(trade.source),
                  'Strategy': trade.strategy.isEmpty ? '—' : trade.strategy,
                  'Timeframe': trade.timeframe.isEmpty ? '—' : trade.timeframe,
                },
              ),
              _detailSection(
                context,
                strings.pick('План', 'Plan'),
                <String, String>{
                  'Planned Entry': journalPrice(trade.plannedEntry),
                  'Stop': journalPrice(trade.stopLoss),
                  'TP1': journalPrice(trade.tp1),
                  'TP2': journalPrice(trade.tp2),
                  'TP3': trade.tp3 == null ? '—' : journalPrice(trade.tp3!),
                  'Planned R:R':
                      '1:${trade.plannedRiskReward.toStringAsFixed(2)}',
                },
              ),
              _detailSection(
                context,
                strings.pick('Исполнение', 'Execution'),
                <String, String>{
                  'Actual Entry': journalPrice(trade.actualEntry),
                  'Actual Exit': trade.actualExit == null
                      ? '—'
                      : journalPrice(trade.actualExit!),
                  'Position Size': journalMoney(trade.effectivePositionSize),
                  'Quantity': trade.quantity.toStringAsFixed(6),
                  'Margin': journalMoney(trade.margin),
                  'Leverage': '${trade.leverage.toStringAsFixed(1)}x',
                  'Fees': journalMoney(trade.fees),
                },
              ),
              _detailSection(
                context,
                strings.pick('Результат', 'Result'),
                <String, String>{
                  'PnL': journalMoney(trade.netPnl, signed: true),
                  'PnL %': journalPercent(trade.pnlPercent),
                  'Result R': journalR(trade.resultR),
                  'MFE': trade.mfeR == null ? '—' : journalR(trade.mfeR!),
                  'MAE': trade.maeR == null ? '—' : journalR(trade.maeR!),
                },
              ),
              _detailSection(
                context,
                strings.pick('Анализ', 'Analysis'),
                <String, String>{
                  'Entry Reason': entryReasonLabel(strings, trade.entryReason),
                  'Details': trade.entryReasonText.isEmpty
                      ? '—'
                      : trade.entryReasonText,
                  'Radar Decision': trade.contextSnapshot.radarDecision.isEmpty
                      ? '—'
                      : trade.contextSnapshot.radarDecision,
                  'Setup Stage': trade.contextSnapshot.setupStage.isEmpty
                      ? '—'
                      : trade.contextSnapshot.setupStage,
                  'Strategy Version': trade.contextSnapshot.strategyVersion,
                },
              ),
              _textBlock(
                context,
                strings.pick('Мои заметки', 'My Notes'),
                trade.myNotes,
              ),
              if (trade.tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: trade.tags
                      .map<Widget>(
                        (TradeTag tag) => Chip(label: Text(tradeTagLabel(tag))),
                      )
                      .toList(growable: false),
                ),
              _textBlock(context, 'What was good?', trade.whatWasGood),
              _textBlock(context, 'What was wrong?', trade.whatWasWrong),
              _textBlock(
                context,
                'What should change?',
                trade.whatShouldChange,
              ),
              const SizedBox(height: 8),
              Text(
                trade.useForStrategyResearch
                    ? 'Strategy Research: YES'
                    : 'Strategy Research: NO',
                style: TextStyle(
                  color: trade.useForStrategyResearch
                      ? semantic.bullish
                      : semantic.neutral,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: () async {
            await openTradeReviewEditor(
              context,
              controller: controller,
              trade: trade,
            );
            if (context.mounted) Navigator.of(context).pop();
          },
          icon: const Icon(Icons.rate_review_outlined),
          label: Text(strings.pick('Заметки / разбор', 'Notes / Review')),
        ),
        if (trade.isEditable)
          TextButton.icon(
            onPressed: () async {
              await openManualTradeEditor(
                context,
                controller: controller,
                existing: trade,
              );
              if (context.mounted) Navigator.of(context).pop();
            },
            icon: const Icon(Icons.edit_outlined),
            label: Text(strings.pick('Изменить', 'Edit')),
          ),
        if (trade.isEditable)
          TextButton.icon(
            onPressed: () async {
              final bool? confirmed = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: Text(strings.pick('Удалить сделку?', 'Delete trade?')),
                  content: Text(
                    strings.pick(
                      'Удаление ручной сделки нельзя отменить.',
                      'Deleting a manual trade cannot be undone.',
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(strings.pick('Отмена', 'Cancel')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(strings.pick('Удалить', 'Delete')),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await controller.deleteManualTrade(trade.id);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.delete_outline),
            label: Text(strings.pick('Удалить', 'Delete')),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.close),
        ),
      ],
    );
  }

  Widget _detailSection(
    BuildContext context,
    String title,
    Map<String, String> values,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          children: values.entries
              .map<Widget>(
                (MapEntry<String, String> row) => SizedBox(
                  width: 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        row.key,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        row.value,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    ),
  );

  Widget _textBlock(BuildContext context, String title, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        Text(text.trim().isEmpty ? '—' : text),
      ],
    ),
  );
}

TextEditingController _numberController(double? value) {
  if (value == null) return TextEditingController();
  return TextEditingController(text: value.toString());
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;

String? _positive(String? value) =>
    _parse(value ?? '') > 0 ? null : 'Enter a value greater than zero';

double _parse(String raw) =>
    double.tryParse(raw.trim().replaceAll(',', '.')) ?? 0.0;

double? _optional(String raw) {
  final String value = raw.trim().replaceAll(',', '.');
  return value.isEmpty ? null : double.tryParse(value);
}
