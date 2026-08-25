import 'package:flutter/material.dart';

import '../engines/decision_engine.dart';
import '../engines/explanation_engine.dart';
import '../models/decision_models.dart';
import '../models/market_models.dart';

class WhyNowScreen extends StatelessWidget {
  const WhyNowScreen({super.key, required this.marketSnapshot});

  final MarketSnapshot marketSnapshot;

  @override
  Widget build(BuildContext context) {
    final DecisionSnapshot decision = DecisionEngine.build(marketSnapshot);
    final DecisionExplanation explanation = ExplanationEngine.explain(decision);
    final Color decisionColor = _decisionColor(decision.decision);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: decisionColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: decisionColor.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'ПОЧЕМУ СЕЙЧАС?',
                style: TextStyle(
                  color: Colors.white60,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    decision.decision.label,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: decisionColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  _StatusPill(
                    label: decision.entryDecision.label,
                    color: _entryColor(decision.entryDecision),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _Metric(
                    label: 'Signal Strength',
                    value: '${decision.signalScore}/100',
                  ),
                  _Metric(
                    label: 'Режим (предв.)',
                    value: decision.marketRegime.label,
                  ),
                  _Metric(label: 'Стратегия', value: decision.selectedStrategy),
                  _Metric(
                    label: 'Data Quality',
                    value: decision.dataQuality.label,
                  ),
                  _Metric(label: 'News Risk', value: decision.newsRisk),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ExplanationSection(
          title: 'Что происходит',
          icon: Icons.public_rounded,
          child: Text(explanation.whatIsHappening),
        ),
        const SizedBox(height: 10),
        _ExplanationSection(
          title: 'Почему такое решение',
          icon: Icons.psychology_alt_rounded,
          child: Text(explanation.whyDecision),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth >= 820;
            final Widget supports = _ExplanationSection(
              title: 'Подтверждает',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF62E6A7),
              child: _ReasonList(
                reasons: explanation.supporting,
                emptyText: 'Сильные подтверждения пока не выделены.',
              ),
            );
            final Widget warnings = _ExplanationSection(
              title: 'Против / риски',
              icon: Icons.warning_amber_rounded,
              color: Colors.amberAccent,
              child: _ReasonList(
                reasons: explanation.opposing,
                emptyText: 'Явных встречных факторов сейчас нет.',
              ),
            );
            if (!wide) {
              return Column(
                children: <Widget>[
                  supports,
                  const SizedBox(height: 10),
                  warnings,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: supports),
                const SizedBox(width: 10),
                Expanded(child: warnings),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        _ExplanationSection(
          title: 'Что ждём',
          icon: Icons.hourglass_top_rounded,
          child: _BulletList(items: explanation.whatWeWaitFor),
        ),
        const SizedBox(height: 10),
        _ExplanationSection(
          title: 'Entry',
          icon: Icons.login_rounded,
          child: Text(explanation.entryExplanation),
        ),
        const SizedBox(height: 10),
        _ExplanationSection(
          title: 'Stop',
          icon: Icons.shield_outlined,
          color: Colors.redAccent,
          child: Text(explanation.stopExplanation),
        ),
        const SizedBox(height: 10),
        _ExplanationSection(
          title: 'Targets',
          icon: Icons.flag_outlined,
          child: Text(explanation.targetExplanation),
        ),
        const SizedBox(height: 10),
        _ExplanationSection(
          title: 'Что отменит сценарий',
          icon: Icons.cancel_outlined,
          color: Colors.redAccent,
          child: _BulletList(items: explanation.invalidation),
        ),
        const SizedBox(height: 10),
        _ExplanationSection(
          title: 'Что изменит решение радара',
          icon: Icons.change_circle_outlined,
          color: Colors.amberAccent,
          child: _BulletList(items: explanation.whatChangesMind),
        ),
        const SizedBox(height: 12),
        Text(
          explanation.riskNotice,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Colors.white54),
        ),
      ],
    );
  }
}

class _ExplanationSection extends StatelessWidget {
  const _ExplanationSection({
    required this.title,
    required this.icon,
    required this.child,
    this.color = const Color(0xFF62E6A7),
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ReasonList extends StatelessWidget {
  const _ReasonList({required this.reasons, required this.emptyText});

  final List<DecisionReason> reasons;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (reasons.isEmpty) {
      return Text(emptyText, style: const TextStyle(color: Colors.white54));
    }
    return Column(
      children: <Widget>[
        for (int index = 0; index < reasons.length; index++) ...<Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                reasons[index].severity == ReasonSeverity.supporting
                    ? '✓'
                    : '⚠',
                style: TextStyle(
                  color: reasons[index].severity == ReasonSeverity.supporting
                      ? const Color(0xFF62E6A7)
                      : Colors.amberAccent,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      reasons[index].title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reasons[index].detail,
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      reasons[index].code.code,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (index < reasons.length - 1) const Divider(height: 20),
        ],
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map<Widget>(
            (String item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('•', style: TextStyle(color: Colors.white60)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 145),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

Color _decisionColor(DecisionAction action) {
  switch (action) {
    case DecisionAction.long:
      return const Color(0xFF44E0A2);
    case DecisionAction.short:
      return const Color(0xFFFF5E7D);
    case DecisionAction.wait:
      return Colors.amberAccent;
  }
}

Color _entryColor(EntryDecision entry) {
  switch (entry) {
    case EntryDecision.enterNow:
      return const Color(0xFF44E0A2);
    case EntryDecision.waitForZone:
      return Colors.amberAccent;
    case EntryDecision.tooLate:
      return const Color(0xFFFF5E7D);
  }
}
