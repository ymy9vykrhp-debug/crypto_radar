import 'decision_models.dart';

class HelpArticle {
  const HelpArticle({
    required this.id,
    required this.titleRu,
    required this.titleEn,
    required this.summaryRu,
    required this.summaryEn,
    required this.bodyRu,
    required this.bodyEn,
  });

  final String id;
  final String titleRu;
  final String titleEn;
  final String summaryRu;
  final String summaryEn;
  final List<String> bodyRu;
  final List<String> bodyEn;
}

class ContextHelpSnapshot {
  const ContextHelpSnapshot({
    required this.decision,
    required this.summary,
    required this.supporting,
    required this.risks,
    required this.nextSteps,
    required this.riskNotice,
  });

  final DecisionSnapshot decision;
  final String summary;
  final List<String> supporting;
  final List<String> risks;
  final List<String> nextSteps;
  final String riskNotice;
}
