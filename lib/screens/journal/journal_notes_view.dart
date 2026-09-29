import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../models/trading_journal_models.dart';
import '../../services/journal_controller.dart';
import '../../widgets/product_components.dart';
import 'journal_ui_helpers.dart';

class JournalNotesView extends StatelessWidget {
  const JournalNotesView({super.key, required this.controller});

  final JournalController controller;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        SectionHeading(
          title: strings.pick('Торговые заметки', 'Trading Notes'),
          subtitle: strings.pick(
            'Идеи и наблюдения, которые не обязаны относиться к конкретной сделке',
            'Ideas and observations that do not have to belong to a trade',
          ),
          icon: Icons.note_alt_outlined,
          trailing: FilledButton.icon(
            onPressed: () => _editNote(context),
            icon: const Icon(Icons.add_rounded),
            label: Text(strings.pick('Добавить заметку', 'Add Note')),
          ),
        ),
        const SizedBox(height: 14),
        if (controller.notes.isEmpty)
          ProductEmptyState(
            icon: Icons.sticky_note_2_outlined,
            title: strings.pick('Заметок пока нет', 'No notes yet'),
            message: strings.pick(
              'Сохраняйте наблюдения, идеи, ошибки и улучшения стратегии.',
              'Save observations, ideas, mistakes and strategy improvements.',
            ),
          )
        else
          ...controller.notes.map<Widget>(
            (TradingNote note) => Card(
              child: ListTile(
                leading: const Icon(Icons.notes_rounded),
                title: Text(
                  note.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${journalDate(note.date)} · '
                  '${noteCategoryLabel(strings, note.category).toUpperCase()}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (String value) async {
                    if (value == 'edit') {
                      await _editNote(context, existing: note);
                    } else if (value == 'delete') {
                      await controller.deleteTradingNote(note.id);
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text(strings.pick('Изменить', 'Edit')),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text(strings.pick('Удалить', 'Delete')),
                        ),
                      ],
                ),
                onTap: () => _editNote(context, existing: note),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _editNote(BuildContext context, {TradingNote? existing}) async {
    TradingNoteCategory category =
        existing?.category ?? TradingNoteCategory.observation;
    DateTime date = existing?.date ?? DateTime.now();
    final TextEditingController text = TextEditingController(
      text: existing?.text ?? '',
    );
    final TradingNote? result = await showDialog<TradingNote>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
              title: Text(
                existing == null
                    ? context.strings.pick('Новая заметка', 'New Note')
                    : context.strings.pick('Изменить заметку', 'Edit Note'),
              ),
              content: SizedBox(
                width: 580,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<TradingNoteCategory>(
                            initialValue: category,
                            decoration: InputDecoration(
                              labelText: context.strings.pick(
                                'Категория',
                                'Category',
                              ),
                            ),
                            items: TradingNoteCategory.values
                                .map<DropdownMenuItem<TradingNoteCategory>>(
                                  (TradingNoteCategory value) =>
                                      DropdownMenuItem<TradingNoteCategory>(
                                        value: value,
                                        child: Text(
                                          noteCategoryLabel(
                                            context.strings,
                                            value,
                                          ),
                                        ),
                                      ),
                                )
                                .toList(growable: false),
                            onChanged: (TradingNoteCategory? value) {
                              if (value != null) {
                                setDialogState(() => category = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final DateTime? selected = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(
                                const Duration(days: 1),
                              ),
                              initialDate: date,
                            );
                            if (selected != null) {
                              setDialogState(() => date = selected);
                            }
                          },
                          icon: const Icon(Icons.event_outlined),
                          label: Text(journalDate(date)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: text,
                      autofocus: true,
                      minLines: 5,
                      maxLines: 10,
                      decoration: InputDecoration(
                        labelText: context.strings.pick('Текст', 'Text'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.strings.pick('Отмена', 'Cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    if (text.text.trim().isEmpty) return;
                    final DateTime now = DateTime.now();
                    Navigator.of(context).pop(
                      TradingNote(
                        id:
                            existing?.id ??
                            'note-${now.microsecondsSinceEpoch}',
                        createdAt: existing?.createdAt ?? now,
                        date: date,
                        category: category,
                        text: text.text.trim(),
                      ),
                    );
                  },
                  child: Text(context.strings.pick('Сохранить', 'Save')),
                ),
              ],
            ),
      ),
    );
    text.dispose();
    if (result != null) await controller.saveTradingNote(result);
  }
}
