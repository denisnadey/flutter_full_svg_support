# TODO List - flutter_svg Animation

**Дата:** 9 января 2026 г.

## ✅ ЗАВЕРШЕНО: Stage 7 - Syncbase Timing

- [x] **S7-1:** Syncbase Timing - парсинг, dependency tracking, интеграция
  - [x] Парсер для syncbase conditions (begin="anim1.end+2s")
  - [x] Dependency tracking в SvgTimeline
  - [x] Topological sort для разрешения зависимостей
  - [x] 40 тестов (timing_parser_test + syncbase_timing_test)
  - [x] Примеры в example app (6 интерактивных демо)
  - **РЕЗУЛЬТАТ:** Syncbase timing полностью работает ✅

**Итого:** 369 тестов проходят, все задачи Stage 7 выполнены ✅

---

## 🟠 STAGE 8: Advanced SMIL (следующий этап)

### Syncbase Timing
- [ ] **S7-1:** Парсинг syncbase conditions
  - [ ] Парсить "anim1.end+2s" формат
  - [ ] Создать класс SyncbaseCondition
  - [ ] Обновить SmilParser
  
- [ ] **S7-1:** Dependency tracking
  - [ ] Добавить Map dependencies в SvgTimeline
  - [ ] Трекать зависимости между анимациями

### Event-based Timing
- [ ] **S8-1:** Парсинг event conditions
  - [ ] Парсить "click", "mouseover" и т.д.
  - [ ] Обновить EventCondition класс
  
- [ ] **S8-1:** Event handling в AnimatedSvgPicture
  - [ ] Добавить GestureDetector для элементов
  - [ ] Связать Flutter events с SMIL анимациями
  - [ ] Обработать tap/hover/focus events
  - [ ] Интегрировать с SvgTimeline
  
- [ ] **S8-1:** Тесты и примеры
  - [ ] Написать интерактивные тесты
  - [ ] Добавить интерактивные примеры в example app
  - [ ] Демо с кликабельными элементами

### calcMode="spline"
- [ ] **S8-2:** Парсинг keySplines
  - [ ] Парсить "x1 y1 x2 y2" формат (4 координаты)
  - [ ] Создать класс CubicBezier для cubic-bezier easing
  - [ ] Поддержка нескольких splines для values list
  
- [ ] **S8-2:** Spline interpolation
  - [ ] Имплементировать solve() метод (Newton-Raphson)
  - [ ] Интегрировать в SmilAnimation
  - [ ] Добавить CSS easing presets (ease, ease-in, ease-out, ease-in-out)
  
- [ ] **S8-2:** Тесты и примеры
  - [ ] Unit тесты для CubicBezier.solve()
  - [ ] Примеры с разными easing функциями
  - [ ] Сравнение linear vs spline

### calcMode="paced"
- [ ] **S8-3:** Distance calculation
  - [ ] Вычислять расстояние между числовыми значениями
  - [ ] Path distance через PathMetrics
  - [ ] Color distance в RGB/HSL space
  - [ ] Transform distance (сложная метрика)
  
- [ ] **S8-3:** Auto keyTimes generation
  - [ ] Генерировать keyTimes для равномерной скорости
  - [ ] Интегрировать в SmilAnimation
  - [ ] Обновить interpolation logic
  
- [ ] **S8-3:** Тесты и примеры
  - [ ] Unit тесты для distance functions
  - [ ] Integration тесты для paced mode
  - [ ] Примеры с paced анимациями
  - [ ] Визуальное сравнение linear vs paced

### Additive & Accumulate
- [ ] **S8-4:** Парсинг атрибутов
  - [ ] Уже парсятся в SmilAnimation (additive, accumulate)
  - [ ] Проверить корректность парсинга
  
- [ ] **S8-4:** Implementation
  - [ ] Суммировать с базовым значением (additive="sum")
  - [ ] Накапливать при повторениях (accumulate="sum")
  - [ ] Обновить computeValue() в SmilAnimation
  
- [ ] **S8-4:** Тесты и примеры
  - [ ] Unit тесты для additive animations
  - [ ] Unit тесты для accumulate behavior
  - [ ] Примеры в example app

---

## 🟡 STAGE 9: CSS Animations (после Stage 8)

### @keyframes Support
- [ ] **S9-1:** CSS parser
  - [ ] Парсить <style> элементы
  - [ ] Парсить @keyframes rules
  - [ ] Парсить animation-* properties
  
- [ ] **S8-1:** Конвертация в SMIL
  - [ ] Конвертировать @keyframes в анимации
  - [ ] Применять animation-* properties
  
- [ ] **S8-1:** Тесты и примеры

### CSS Transitions
- [ ] **S9-1:** Парсинг transition-*
- [ ] **S9-1:** Трекинг CSS property changes
- [ ] **S9-1:** Auto-создание анимаций
- [ ] **S9-1:** Тесты и примеры

---

## 🟢 STAGE 10-12: Advanced Features (долгосрочно)

### SVG Filters
- [ ] **S10-1:** feGaussianBlur
- [ ] **S10-1:** feDropShadow
- [ ] **S10-1:** feColorMatrix
- [ ] **S10-2:** Animated filters

### Performance
- [ ] **S11-1:** Layer caching
- [ ] **S11-2:** Dirty region tracking
- [ ] **S11-3:** Path optimization
- [ ] **S11-4:** Multi-threading

### Documentation
- [ ] **S12-1:** Полное dartdoc покрытие
- [ ] **S12-2:** Example app enhancement
- [ ] **S12-3:** Testing coverage 90%+
- [ ] **S12-4:** Error handling & validation

---

## 📝 Notes

### В процессе:
- Нет задач в процессе

### Заблокировано:
- CSS Transitions (зависит от CSS Animations)
- Animated Filters (зависит от Basic Filters)

### Завершено:
- ✅ Stage 1-6 (313 тестов)
- ✅ Infrastructure, SMIL Core, Rendering
- ✅ Color, Transform, Path animations

---

## 🎯 Ближайшие цели (1 неделя)

1. [ ] Исправить autoPlay: false bug (1 день)
2. [ ] Реализовать Timeline Control API (3 дня)
3. [ ] Добавить initialTime (1 день)
4. [ ] Начать Syncbase Timing (2-3 дня)

**Прогресс:** 0/4 задач

---

**Обновлено:** 9 января 2026 г.
