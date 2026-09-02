# 🧠 Adaptive Signal Brain System

## Обзор

**Adaptive Signal Brain** — это интеллектуальная саморазвивающаяся система анализа торговых сигналов в Crypto Radar. Система автоматически:

- 📊 Отслеживает производительность каждого фильтра/индикатора
- 🧮 Рассчитывает продвинутые метрики (Win Rate, Sharpe Ratio, Sortino Ratio)
- ⚖️ Адаптирует веса фильтров в реальном времени
- 💡 Даёт рекомендации по включению/отключению фильтров
- 📈 Показывает красные флаги для плохо работающих стратегий

---

## Архитектура

### Основные компоненты:

```
┌─────────────────────────────────────────┐
│  AdaptiveSignalBrain                    │
│  - Главный мозг системы                 │
│  - Хранит метрики всех фильтров        │
│  - Пересчитывает веса                  │
└────────────┬────────────────────────────┘
			 │
	  ┌──────┼──────┐
	  │      │      │
	  ▼      ▼      ▼
  ┌────┐ ┌────┐ ┌────────┐
  │Filter│ Market│ Signal  │
  │Perf. │ Data  │ Audit   │
  │Metrics│      │ Log     │
  └────┘ └────┘ └────────┘
```

### Ключевые файлы:

| Файл | Описание |
|------|---------|
| `adaptive_signal_brain.dart` | Главный мозг (320 строк) |
| `filter_performance_models.dart` | Модели метрик (полный расчёт Sharpe, Sortino) |
| `signal_audit_models.dart` | Логирование сигналов и результатов |
| `signal_component_detector.dart` | Определение активных компонентов |
| `adaptive_filter_manager.dart` | Управление включением/отключением |
| `brain_journal_integration.dart` | Интеграция в торговый журнал |
| `adaptive_system_analytics_screen.dart` | UI для аналитики (4 вкладки) |

---

## Как работает система

### 1️⃣ Разделение на компоненты

Когда система генерирует сигнал, она **определяет какие компоненты его создали**:

```dart
// Компоненты сигнала
enum SignalComponent {
  priceActionPattern,    // Паттерны свечей
  fibonacci38Level,      // Отскок на Fib 38.2%
  volumeSpike,          // Объём выше среднего
  rsiOversold,          // RSI выход из OS
  trendAbove200ma,      // Цена выше 200MA
  // ... и так далее
}
```

### 2️⃣ Логирование каждого сигнала

При создании сигнала:

```dart
brain.recordSignal(
  id: 'BTCUSDT:long:1234567890',
  symbol: 'BTCUSDT',
  direction: 'LONG',
  activeComponents: [
	SignalComponent.priceActionPattern,
	SignalComponent.fibonacci38Level,
	SignalComponent.volumeSpike,  // 3 компонента совпали!
  ],
  entryPrice: 42000.0,
  stopLoss: 41500.0,
  targetPrice: 43500.0,
  confidence: 85.0,
);
```

### 3️⃣ Обновление метрик при закрытии сделки

Когда сделка закрыта в журнале:

```dart
brain.recordTradeResult(
  signalId: 'BTCUSDT:long:1234567890',
  result: TradeResult.success,      // Цена пошла на +0.4%+
  finalPrice: 42500.0,
  profitPercent: 1.19,              // +1.19%
  rMultiple: 0.95,                  // 0.95R прибыли
  notes: 'Good signal, closed at TP1',
);
```

### 4️⃣ Мозг анализирует результат

Система **автоматически обновляет метрики** для КАЖДОГО компонента из этого сигнала:

```
Signal ID: BTCUSDT:long:1234567890
  ✅ Price Action Pattern
	 signalCount++
	 successCount++
	 winRate = 45/50 = 90% ✅

  ✅ Fibonacci 38.2%
	 signalCount++
	 successCount++
	 winRate = 42/50 = 84% ✅

  ✅ Volume Spike
	 signalCount++
	 successCount++
	 winRate = 41/50 = 82% ✅

🎯 Пересчитаны веса всех фильтров!
```

### 5️⃣ Адаптивная регулировка confidence

Теперь НА ЛЕТУ для новых сигналов confidence рассчитывается с учётом весов:

```dart
// Было:
baseConfidence = 80%

// Теперь (адаптивно):
adaptiveConfidence =
  (Price Action: 80% × 1.3x weight) +
  (Fibonacci: 80% × 1.2x weight) +
  (Volume: 80% × 1.1x weight)
  + bias correct factor

Result = 85% (улучшилось!)
```

---

## API Reference

### Инициализация

```dart
// Создать мозг
final brain = AdaptiveSignalBrain();

// Инициализировать все фильтры
brain.initializeDefaultFilters();

// Создать менеджер
final filterManager = FilterManager(brain);
```

### Запись сигналов

```dart
// Записать новый сигнал
brain.recordSignal(
  id: signal.id,
  symbol: signal.symbol,
  direction: signal.direction.label,
  activeComponents: signal.activeSignalComponents,
  entryPrice: signal.entryPrice,
  stopLoss: signal.stop,
  targetPrice: signal.tp1,
  confidence: 85.0,
);

// Записать результат сделки
brain.recordTradeResult(
  signalId: signalId,
  result: TradeResult.success,  // или .partial, .stopped, .cancelled
  finalPrice: exitPrice,
  profitPercent: 1.2,
  rMultiple: 0.95,
  notes: 'Good entry, hit target',
);
```

### Аналитика

```dart
// Получить все фильтры ранжированные по win rate
final ranked = brain.getFiltersRankedByPerformance();

// Получить горячие фильтры (>75% win rate)
final hot = brain.getHotFilters();

// Получить холодные фильтры (<45% win rate)
final cold = brain.getColdFilters();

// Получить адаптивное доверие
final adaptive = brain.calculateAdaptiveConfidence(
  baseConfidence: 80.0,
  activeComponents: [SignalComponent.priceActionPattern],
);

// Получить рекомендацию для фильтра
final recommendation = filterManager.getRecommendationForFilter(
  SignalComponent.priceActionPattern.code,
);
// → "❌ DISABLE: Win rate 35% is too low"
```

### Управление фильтрами

```dart
// Переключить фильтр
filterManager.toggleFilter(SignalComponent.rsiOversold.code);

// Включить все
filterManager.enableAllFilters();

// Отключить все
filterManager.disableAllFilters();

// Автоматическая оптимизация
filterManager.applyAutoOptimization(
  hotThreshold: 75.0,    // Включить если win rate > 75%
  coldThreshold: 45.0,   // Отключить если win rate < 45%
  minSignals: 10,        // Минимум 10 сделок для рекомендации
);

// Сохранить конфигурацию
filterManager.saveConfiguration('aggressive_mode');

// Загрузить конфигурацию
filterManager.loadConfiguration('aggressive_mode');
```

### Статистика

```dart
// Общая статистика
print('Total signals: ${brain.totalSignalsRecorded}');
print('Successful: ${brain.totalSuccessfulSignals}');
print('Win rate: ${brain.overallWinRate.toStringAsFixed(2)}%');

// Метрики конкретного фильтра
final metrics = brain.getFilterMetrics(SignalComponent.volumeSpike.code);
print('Win rate: ${metrics?.winRate}%');
print('Sharpe ratio: ${metrics?.sharpeRatio.toStringAsFixed(2)}');
print('Sortino ratio: ${metrics?.sortinoRatio.toStringAsFixed(2)}');
print('Max drawdown: ${metrics?.maxDrawdown.toStringAsFixed(2)}%');
print('Weight: ${metrics?.weight.toStringAsFixed(2)}x');

// Экспорт и импорт
final config = brain.exportFilterConfiguration();
saveToDisk(config);

// Позже...
final config = loadFromDisk();
brain.importFilterConfiguration(config);
```

---

## Метрики, которые рассчитывает система

### Win Rate (%)
Процент успешных сигналов из всех сделок с этим фильтром.

```
Win Rate = (успешных сделок / всех сделок) × 100%
```

### Average R
Среднее значение R-multiple (отношение прибыли к риску).

```
R = прибыль / риск
Average R = сумма всех R / кол-во сделок
```

### Sharpe Ratio
Соотношение доходности к волатильности (риску).

```
Sharpe = (средний доход - безрисковая ставка) / стандартное отклонение × √252
Выше — лучше (>1 отлично, >2 превосходно)
```

### Sortino Ratio
Как Sharpe, но штрафует только за вниз-волатильность (убытки).

```
Sortino = (средний доход) / вниз-волатильность × √252
Более честный показатель нежели Sharpe
```

### Max Drawdown (%)
Самая большая просадка капитала за весь период.

```
Max DD = (пик - минимум) / пик × 100%
```

### Profit Factor
Отношение суммы прибыльных сделок к сумме убыточных.

```
PF = сумма прибыльных / сумма убыточных
PF > 1.5 — отличный результат
```

### Weight (0.5 - 1.5x)
Динамический множитель, определяющий вклад фильтра в confidence.

```
Weight = 0.5 + (winRate - 50%) × 0.02
Чем выше win rate, тем выше вес
```

---

## Цветовая кодировка UI

| Статус | Цвет | Win Rate | Действие |
|--------|------|----------|----------|
| ✅ Excellent | 🟢 Зелёный | > 80% | Оставить как есть |
| ✅ Good | 💚 Светлозелёный | 65-80% | Оставить |
| 🟡 Acceptable | 🟡 Жёлтый | 50-65% | Мониторить |
| ⚠️ Warning | 🟠 Оранжевый | 35-50% | Пересмотреть |
| ❌ Poor | 🔴 Красный | < 35% | Отключить |

---

## Интеграция с Telegram

Каждый Telegram-сигнал теперь будет показывать:

```
🚀 BTCUSDT LONG | Confidence: 87% ⭐⭐⭐⭐

Активные компоненты:
✅ Price Action (93% win rate, вес 1.4x)
✅ Volume Spike (87% win rate, вес 1.3x)
✅ Fibonacci 38.2% (84% win rate, вес 1.1x)
⚠️ RSI Oversold (62% win rate, вес 0.8x)
❌ Trend 200MA (отключен)

Вход: 42,150-42,190 USDT
Стоп: 41,900 (-1.2%)
Цель: 43,240 (+2.6%)
```

---

## Примеры использования

### Пример 1: Запуск системы в приложении

```dart
void initBrainSystem() {
  // Инициализировать
  final brain = AdaptiveSignalBrain();
  final filterManager = FilterManager(brain);
  final integration = BrainJournalIntegration(brain: brain);

  brain.initializeDefaultFilters();

  // Когда приходит сигнал
  final signal = generateSignal(...);
  integration.recordSignalInBrain(signal);

  // Когда сделка закрывается в журнале
  final entry = tradeJournalEntry;
  integration.recordTradeResultInBrain(
	signalId: signal.id,
	entry: entry,
  );

  // Получить адаптивное доверие
  final adaptiveConfidence =
	  integration.getAdaptiveConfidenceForSignal(signal);

  // Отправить улучшенный Telegram-сигнал
  sendTelegramSignal(signal, adaptiveConfidence);
}
```

### Пример 2: Автоматическая оптимизация

```dart
void optimizeFiltersDaily() {
  // Каждый день в 21:00 UTC применить автооптимизацию
  filterManager.applyAutoOptimization(
	hotThreshold: 75.0,
	coldThreshold: 40.0,
	minSignals: 15,
  );

  // Показать отчёт
  print(filterManager.getDetailedReport());

  // Сохранить эту конфигурацию
  filterManager.saveConfiguration(
	'auto_optimized_${DateTime.now().day}_${DateTime.now().month}',
  );
}
```

### Пример 3: Просмотр аналитики

```dart
// Перейти на Analytics экран
NavigatorState.of(context).push(
  MaterialPageRoute(
	builder: (_) => AdaptiveSystemAnalyticsScreen(
	  brain: brain,
	  filterManager: filterManager,
	),
  ),
);
```

---

## Рекомендации по использованию

### ✅ ДА:
- Включить систему сразу в production
- Использовать автооптимизацию 1 раз в день
- Отслеживать Sharpe и Sortino для новых фильтров
- Сохранять конфигурации перед крупными обновлениями

### ❌ НЕТ:
- Не менять веса вручную часто (пусть система учится)
- Не отключать фильтры на основе одного неудачного сигнала
- Не верить win rate при < 10 сделок (нужна статистика)
- Не игнорировать красные флаги при Sharpe < 0.5

---

## Тестирование

```bash
# Запустить тесты Brain системы
flutter test test/adaptive_brain_test.dart

# Профилирование
flutter run --profile lib/main.dart

# Анализ кода
flutter analyze
```

---

## Известные ограничения

1. **Минимум данных**: Система нужно минимум 50-100 сделок для надёжной статистики
2. **Lookback период**: Используются только последние данные (нет исторического оптимизации)
3. **Overfitting**: При < 30 сделок есть риск переобучения на конкретные условия
4. **Рыночный режим**: Веса могут меняться при смене волатильности/режима рынка

---

## Будущие улучшения

- [ ] Machine Learning для предсказания оптимальных весов
- [ ] A/B тестирование конфигураций
- [ ] Анализ коррелций между фильтрами
- [ ] Автоматическое обнаружение нового рыночного режима
- [ ] Экспорт в Excel/CSV для внешнего анализа

---

## Поддержка

Для вопросов и предложений обратитесь в документацию Crypto Radar.

**Создано для 🎯 точных сигналов с 90%+ уверенностью**
