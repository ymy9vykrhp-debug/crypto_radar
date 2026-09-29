import 'package:flutter/material.dart';

import '../engines/help_engine.dart';
import '../localization/app_strings.dart';
import '../models/decision_models.dart';
import '../models/help_models.dart';
import '../theme/app_theme.dart';
import '../widgets/product_components.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key, this.decision});

  final DecisionSnapshot? decision;

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final List<HelpArticle> articles = HelpEngine.articles
        .where((HelpArticle article) {
          final String haystack = <String>[
            article.titleRu,
            article.titleEn,
            article.summaryRu,
            article.summaryEn,
            ...article.bodyRu,
            ...article.bodyEn,
          ].join(' ').toLowerCase();
          return haystack.contains(_query.trim().toLowerCase());
        })
        .toList(growable: false);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        SectionHeading(
          title: strings.pick('Режим помощи', 'Help Center'),
          subtitle: strings.pick(
            'Объясняет текущий снимок решения и не может отправлять ордера',
            'Explains the current decision snapshot and cannot place orders',
          ),
          icon: Icons.support_agent_rounded,
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (String value) => setState(() => _query = value),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            labelText: strings.pick('Найти ответ', 'Find an answer'),
          ),
        ),
        if (widget.decision != null) ...<Widget>[
          const SizedBox(height: 12),
          _ContextCard(help: HelpEngine.contextual(widget.decision!)),
        ],
        const SizedBox(height: 12),
        ...articles.map<Widget>(
          (HelpArticle article) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ProductExpandableSection(
              title: strings.isRussian ? article.titleRu : article.titleEn,
              icon: _articleIcon(article.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    strings.isRussian ? article.summaryRu : article.summaryEn,
                  ),
                  const SizedBox(height: 8),
                  ...(strings.isRussian ? article.bodyRu : article.bodyEn)
                      .map<Widget>(
                        (String line) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('• $line'),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
        if (articles.isEmpty)
          ProductEmptyState(
            icon: Icons.search_off_rounded,
            title: strings.pick('Ответ не найден', 'No answer found'),
            message: strings.pick(
              'Попробуйте более короткий запрос.',
              'Try a shorter search query.',
            ),
          ),
      ],
    );
  }

  IconData _articleIcon(String id) => switch (id) {
    'risk' => Icons.shield_outlined,
    'telegram' => Icons.send_outlined,
    'bybit-demo' => Icons.science_outlined,
    'faq' => Icons.quiz_outlined,
    _ => Icons.help_outline_rounded,
  };
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.help});

  final ContextHelpSnapshot help;

  @override
  Widget build(BuildContext context) {
    final RadarSemanticColors semantic = Theme.of(context)
        .extension<RadarSemanticColors>()!;
    final Color color = switch (help.decision.decision) {
      DecisionAction.long => semantic.bullish,
      DecisionAction.short => semantic.bearish,
      DecisionAction.wait => semantic.warning,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeading(
              title:
                  '${help.decision.symbol} · ${help.decision.decision.label}',
              subtitle: 'READ ONLY · ${help.decision.timestamp.toLocal()}',
              icon: Icons.psychology_alt_outlined,
              trailing: ProductStatusChip(
                label: help.decision.entryDecision.label,
                color: color,
              ),
            ),
            const SizedBox(height: 10),
            Text(help.summary),
            const SizedBox(height: 10),
            _HelpList(title: 'Подтверждает', lines: help.supporting),
            _HelpList(title: 'Риски', lines: help.risks),
            _HelpList(title: 'Что ждём', lines: help.nextSteps),
            const Divider(height: 24),
            Text(help.riskNotice, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _HelpList extends StatelessWidget {
  const _HelpList({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          ...lines.take(5).map<Widget>((String line) => Text('• $line')),
        ],
      ),
    );
  }
}
