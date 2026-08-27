import '../models/decision_models.dart';
import '../models/help_models.dart';
import 'explanation_engine.dart';

/// Read-only help facade. It explains a frozen DecisionSnapshot and has no
/// dependency on market transport, preferences or any execution broker.
class HelpEngine {
  const HelpEngine._();

  static ContextHelpSnapshot contextual(DecisionSnapshot decision) {
    final DecisionExplanation explanation = ExplanationEngine.explain(decision);
    return ContextHelpSnapshot(
      decision: decision,
      summary: '${explanation.whatIsHappening}\n${explanation.whyDecision}',
      supporting: explanation.supporting
          .map<String>(
            (DecisionReason reason) => '${reason.title}: ${reason.detail}',
          )
          .toList(growable: false),
      risks: explanation.opposing
          .map<String>(
            (DecisionReason reason) => '${reason.title}: ${reason.detail}',
          )
          .toList(growable: false),
      nextSteps: explanation.whatWeWaitFor,
      riskNotice: explanation.riskNotice,
    );
  }

  static const List<HelpArticle> articles = <HelpArticle>[
    HelpArticle(
      id: 'getting-started',
      titleRu: 'Начало работы',
      titleEn: 'Getting Started',
      summaryRu: 'Как читать Главную, Рынок, Сигналы и Журнал.',
      summaryEn: 'How to read Home, Market, Signals and Journal.',
      bodyRu: <String>[
        'Выберите инструмент в Asset Explorer и дождитесь закрытых свечей.',
        'LONG/SHORT показывает сценарий, а ENTER NOW или ENTRY CONFIRMED — разрешённый этап входа.',
        'WAIT является нормальным решением: рынок пока не дал достаточного преимущества.',
      ],
      bodyEn: <String>[
        'Select an instrument in Asset Explorer and wait for closed candles.',
        'LONG/SHORT is the scenario; ENTER NOW or ENTRY CONFIRMED is the entry stage.',
        'WAIT is a valid decision when the market has no measurable edge.',
      ],
    ),
    HelpArticle(
      id: 'signals',
      titleRu: 'Как работают сигналы',
      titleEn: 'How Signals Work',
      summaryRu: 'Signal Strength, подтверждения и уникальность сигнала.',
      summaryEn: 'Signal strength, confirmations and signal uniqueness.',
      bodyRu: <String>[
        'Signal Strength измеряет совпадение факторов, а не вероятность прибыли.',
        'Новый сигнал сохраняется по уникальному ID и не дублируется каждые 15 секунд.',
        'Торговая логика одинакова для live-радара и backtest.',
      ],
      bodyEn: <String>[
        'Signal Strength measures factor alignment, not profit probability.',
        'A signal is stored by unique ID and is not duplicated every 15 seconds.',
        'The same trading logic is shared by live radar and backtest.',
      ],
    ),
    HelpArticle(
      id: 'risk',
      titleRu: 'Управление риском',
      titleEn: 'Risk Management',
      summaryRu: 'Маржа, структурный Stop, плечо, комиссии и Net R:R.',
      summaryEn: 'Margin, structural stop, leverage, costs and Net R:R.',
      bodyRu: <String>[
        'Маржа — выделенная сумма, а Risk Limit — максимальный плановый убыток.',
        'Сначала определяется структурный Stop, затем размер позиции и допустимое плечо.',
        'Smart Calculator может выдать WAIT, SKIP или BLOCKED — плечо не делает плохую сделку хорошей.',
      ],
      bodyEn: <String>[
        'Margin is allocated capital; Risk Limit is the planned maximum loss.',
        'Structural Stop comes first, followed by position size and safe leverage.',
        'The calculator can return WAIT, SKIP or BLOCKED.',
      ],
    ),
    HelpArticle(
      id: 'bybit-demo',
      titleRu: 'Подготовка Bybit Demo',
      titleEn: 'Bybit Demo Setup',
      summaryRu: 'Почему Demo будет подключён раньше реальной торговли.',
      summaryEn: 'Why Demo must precede live trading.',
      bodyRu: <String>[
        'Сейчас приложение работает MONITOR ONLY и не принимает API-ключи.',
        'Следующий безопасный этап — Paper Trading, затем отдельный Bybit Demo Broker.',
        'LIVE останется заблокирован до проверки комиссий, OOS, восстановления соединений и защитных лимитов.',
      ],
      bodyEn: <String>[
        'The application is MONITOR ONLY and does not accept API keys.',
        'Paper Trading comes first, followed by a separate Bybit Demo Broker.',
        'LIVE stays blocked until research and operational safety gates pass.',
      ],
    ),
    HelpArticle(
      id: 'telegram',
      titleRu: 'Telegram',
      titleEn: 'Telegram',
      summaryRu: 'Безопасные уведомления без токена в браузере.',
      summaryEn: 'Safe notifications without exposing a token in the browser.',
      bodyRu: <String>[
        'Flutter подключается только к локальному relay по адресу 127.0.0.1.',
        'Bot Token вводится в скрытом окне PowerShell, а Chat ID определяется после команды /start. Они не сохраняются в приложении.',
        'Telegram получает уведомления и не имеет доступа к Execution Broker.',
      ],
      bodyEn: <String>[
        'Flutter connects only to a local relay on 127.0.0.1.',
        'Bot Token is entered in a hidden PowerShell prompt; Chat ID is discovered after /start. Neither is stored by the app.',
        'Telegram can send notifications but cannot access an execution broker.',
      ],
    ),
    HelpArticle(
      id: 'faq',
      titleRu: 'FAQ и диагностика',
      titleEn: 'FAQ and Diagnostics',
      summaryRu: 'Почему WAIT, нет данных или не работает Telegram.',
      summaryEn: 'Why WAIT, missing data or Telegram is offline.',
      bodyRu: <String>[
        'WAIT — это решение алгоритма, а не зависание приложения.',
        'Если данные устарели, обновите рынок и проверьте статус Bybit.',
        'Для Telegram сначала запустите relay, затем нажмите Проверить и Отправить тест.',
      ],
      bodyEn: <String>[
        'WAIT is an algorithm decision, not an application freeze.',
        'If data is stale, refresh the market and check Bybit status.',
        'For Telegram, start the relay and then use Check and Send test.',
      ],
    ),
  ];
}
