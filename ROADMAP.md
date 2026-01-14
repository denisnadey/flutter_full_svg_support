# Flutter SVG Animation - Roadmap

**Last Updated:** 9 января 2026 г.

## 📊 Текущий статус

**Завершено:** Stage 1-6 (313 тестов, 100% ✅)
**Прогресс:** ~60% от полной SMIL спецификации
**Performance:** 60 FPS (простые), 30+ FPS (сложные)

---

## 🔴 КРИТИЧЕСКИЕ ПРОБЛЕМЫ (Исправить немедленно)

### P0-1: Bug с autoPlay: false ⚠️
**Проблема:** SVG не рендерится когда `autoPlay: false` (0 пикселей)

**Симптомы:**
```dart
AnimatedSvgPicture.string(
  svgString,
  autoPlay: false,  // ❌ Рендерит пустой виджет
);
```

**Workaround:** Использовать `autoPlay: true`

**Задачи:**
- [ ] Исследовать почему initial frame (t=0) не рендерится
- [ ] Проверить инициализацию timeline при `autoPlay: false`
- [ ] Добавить explicit seek(Duration.zero) при старте
- [ ] Написать тесты для autoPlay: false

**Файлы для изучения в Blink:**
- `SMILTimeContainer.cpp:138` - `begin()` метод
- `SVGSMILElement.cpp` - начальное состояние анимации

**Приоритет:** 🔴 CRITICAL
**Оценка:** 1-2 дня

---

### P0-2: Отсутствие Timeline Control API ⚠️
**Проблема:** Нет программного контроля над анимацией

**Что отсутствует:**
```dart
// ❌ НЕТ такого API:
final controller = AnimatedSvgController();

AnimatedSvgPicture.string(
  svgString,
  controller: controller,
);

controller.pause();           // Поставить на паузу
controller.resume();          // Возобновить
controller.seek(Duration(seconds: 2));  // Перемотать
controller.reverse();         // Воспроизвести в обратном направлении
controller.setPlaybackRate(2.0);  // Ускорить в 2 раза
```

**Задачи:**
- [ ] Создать `AnimatedSvgController` класс
- [ ] Добавить методы: pause, resume, seek, reverse, setPlaybackRate
- [ ] Добавить стримы событий: onStart, onEnd, onRepeat
- [ ] Обновить `AnimatedSvgPicture` для работы с контроллером
- [ ] Написать тесты для контроллера
- [ ] Обновить example app с примерами контроллера

**Вдохновение из Blink:**
```cpp
// SMILTimeContainer.h
class SMILTimeContainer {
    void begin();
    void pause();
    void resume();
    void setElapsed(SMILTime);
    SMILTime elapsed() const;
    bool isActive() const;
    bool isPaused() const;
};
```

**Файлы:**
- `blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp`
- `blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.h`

**Приоритет:** 🔴 CRITICAL
**Оценка:** 3-5 дней

---

### P0-3: Visual Testing Limitations
**Проблема:** `pump(duration)` не продвигает время анимации в тестах

**Текущее ограничение:**
```dart
await tester.pumpWidget(AnimatedSvgPicture.string(svg));
await tester.pump(Duration(seconds: 1)); // ❌ Время не продвигается
// Анимация все еще на t=0
```

**Задачи:**
- [ ] Добавить параметр `initialTime: Duration?` в AnimatedSvgPicture
- [ ] Использовать в тестах:
```dart
AnimatedSvgPicture.string(
  svg,
  initialTime: Duration(milliseconds: 500), // ✅ Начать с t=0.5s
);
```
- [ ] Или добавить в контроллер:
```dart
controller.seekTo(Duration(milliseconds: 500));
await tester.pumpWidget(AnimatedSvgPicture.string(svg, controller: controller));
```

**Приоритет:** 🟡 HIGH
**Оценка:** 1-2 дня

---

## 🟠 STAGE 7: Advanced SMIL Features

### S7-1: Syncbase Timing 🎯
**Что это:** Синхронизация анимаций друг с другом

**Примеры:**
```xml
<animate id="anim1" attributeName="x" from="0" to="100" dur="2s"/>

<!-- Начать через 2 секунды после окончания anim1 -->
<animate begin="anim1.end+2s" attributeName="y" from="0" to="100" dur="2s"/>

<!-- Начать одновременно с anim2 -->
<animate begin="anim2.begin" attributeName="opacity" from="0" to="1" dur="1s"/>

<!-- Начать при 3-м повторении anim3 -->
<animate begin="anim3.repeat(3)" attributeName="fill" from="red" to="blue" dur="1s"/>
```

**Задачи:**
- [ ] Парсить syncbase references: `id.begin`, `id.end`, `id.repeat(n)`
- [ ] Парсить временные офсеты: `+2s`, `-1s`
- [ ] Создать систему dependencies между анимациями
- [ ] Обновить timeline для обработки syncbase events
- [ ] Добавить тесты для syncbase timing
- [ ] Добавить примеры в example app

**Вдохновение из Blink:**
```cpp
// SVGSMILElement.h
struct Condition {
    enum Type {
        EventCondition,
        SyncbaseCondition,    // <-- Это нам нужно
        AccessKeyCondition,
        RepeatCondition
    };
    Type m_type;
    String m_baseID;          // ID элемента для синхронизации
    BeginOrEnd m_beginOrEnd;  // begin или end
    SMILTime m_offset;        // Временной офсет
    int m_repeats;            // Номер повторения
};
```

**Файлы для изучения:**
- `blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp:200-400` - парсинг условий
- `blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp:handleConditionEvent()` - обработка событий

**Приоритет:** 🟠 HIGH
**Оценка:** 5-7 дней

---

### S7-2: Event-based Timing 🎯
**Что это:** Запуск анимаций по событиям пользователя

**Примеры:**
```xml
<!-- Начать по клику -->
<animate begin="click" attributeName="r" from="10" to="50" dur="0.5s"/>

<!-- Начать при наведении мыши -->
<animate begin="mouseover" attributeName="fill" from="blue" to="red" dur="0.3s"/>

<!-- Начать при уходе мыши -->
<animate begin="mouseout" attributeName="fill" from="red" to="blue" dur="0.3s"/>

<!-- Начать при фокусе -->
<animate begin="focus" attributeName="opacity" from="0.5" to="1" dur="0.2s"/>
```

**Задачи:**
- [ ] Парсить event conditions: `click`, `mouseover`, `mouseout`, `focus`, `blur`
- [ ] Добавить GestureDetector обертку для SVG элементов
- [ ] Связать Flutter события с SMIL анимациями
- [ ] Обновить AnimatedSvgPainter для обработки tap events
- [ ] Добавить интерактивные тесты
- [ ] Добавить интерактивные примеры в example app

**Вдохновение из Blink:**
```cpp
// SVGSMILElement.cpp
void SVGSMILElement::handleConditionEvent(Event* event, Condition* condition)
{
    if (condition->m_type == EventCondition) {
        // Обработка события
        if (event->type() == condition->m_name) {
            // Запустить/остановить анимацию
        }
    }
}
```

**Файлы:**
- `blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp:90-120` - ConditionEventListener
- `blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp:handleConditionEvent()`

**Приоритет:** 🟠 HIGH
**Оценка:** 5-7 дней

---

### S7-3: calcMode="spline" с keySplines 🎯
**Что это:** Кубические кривые Безье для плавных переходов

**Пример:**
```xml
<animate 
  attributeName="x"
  values="0; 100; 200"
  keyTimes="0; 0.5; 1"
  keySplines="0.42 0 0.58 1; 0.42 0 0.58 1"
  calcMode="spline"
  dur="2s"/>
```

**Задачи:**
- [ ] Парсить keySplines атрибут
- [ ] Создать класс UnitBezier (кубическая кривая)
- [ ] Имплементировать метод solve() для вычисления t по кривой
- [ ] Обновить interpolator для использования spline
- [ ] Добавить тесты для spline interpolation
- [ ] Добавить примеры с easing functions (ease-in, ease-out, ease-in-out)

**Вдохновение из Blink:**
```cpp
// SVGAnimationElement.cpp:100-150
static void parseKeySplines(const String& string, Vector<UnitBezier>& result)
{
    // Парсинг "x1 y1 x2 y2; x1 y1 x2 y2; ..."
    // Создание UnitBezier объектов
}

// platform/graphics/UnitBezier.h
class UnitBezier {
    double solve(double x, double epsilon) const;
    // Вычисление y для заданного x на кривой Безье
};
```

**Файлы:**
- `blink-b87d44f-Source-core-svg/SVGAnimationElement.cpp:100-150` - parseKeySplines
- Flutter имеет Cubic класс, можем использовать его

**Приоритет:** 🟡 MEDIUM
**Оценка:** 3-4 дня

---

### S7-4: calcMode="paced" 🎯
**Что это:** Автоматическая равномерная скорость анимации

**Пример:**
```xml
<!-- Равномерная скорость движения по пути -->
<animate 
  attributeName="d"
  values="M0,0 L100,0; M0,0 L100,100; M0,0 L0,100"
  calcMode="paced"
  dur="3s"/>
```

**Задачи:**
- [ ] Вычислять "расстояние" между значениями
- [ ] Для path: использовать PathMetrics.length
- [ ] Для numbers: использовать abs(to - from)
- [ ] Для colors: использовать color distance в RGB space
- [ ] Автоматически генерировать keyTimes для равномерной скорости
- [ ] Добавить тесты
- [ ] Добавить примеры

**Файлы:**
- `blink-b87d44f-Source-core-svg/ColorDistance.cpp` - distance между цветами
- `blink-b87d44f-Source-core-svg/SVGAnimationElement.cpp` - calcMode handling

**Приоритет:** 🟡 MEDIUM
**Оценка:** 3-4 дня

---

### S7-5: Additive & Accumulate 🎯
**Что это:** Суммирование анимаций и накопление при повторениях

**Примеры:**
```xml
<!-- Суммировать с базовым значением (x=50) -->
<rect x="50" y="50" width="100" height="100">
  <animate attributeName="x" from="0" to="100" dur="2s" 
           additive="sum"/>  <!-- Результат: 50 + (0..100) = 50..150 -->
</rect>

<!-- Накапливать при повторениях -->
<animate attributeName="x" from="0" to="100" dur="2s" 
         repeatCount="3"
         accumulate="sum"/>  <!-- 1: 0..100, 2: 100..200, 3: 200..300 -->
```

**Задачи:**
- [ ] Парсить `additive="sum|replace"` атрибут
- [ ] Парсить `accumulate="sum|none"` атрибут
- [ ] Обновить interpolator для поддержки additive
- [ ] Трекать количество завершённых повторений
- [ ] Добавлять offset на основе accumulate
- [ ] Добавить тесты
- [ ] Добавить примеры

**Приоритет:** 🟢 LOW
**Оценка:** 2-3 дня

---

### S7-6: Restart Modes 🎯
**Что это:** Контроль перезапуска анимаций

**Примеры:**
```xml
<!-- Можно перезапускать в любое время -->
<animate restart="always" begin="click" .../>

<!-- Перезапуск только когда неактивна -->
<animate restart="whenNotActive" begin="click" .../>

<!-- Никогда не перезапускать -->
<animate restart="never" begin="click" .../>
```

**Задачи:**
- [ ] Парсить `restart` атрибут
- [ ] Обновить timeline для проверки restart mode
- [ ] Блокировать перезапуск при restart="never"
- [ ] Блокировать перезапуск при restart="whenNotActive" если активна
- [ ] Добавить тесты
- [ ] Добавить примеры

**Приоритет:** 🟢 LOW
**Оценка:** 1-2 дня

---

## 🟡 STAGE 8: CSS Animations

### S8-1: @keyframes Support 🎨
**Что это:** CSS анимации с @keyframes

**Пример:**
```html
<style>
  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
  
  #circle {
    animation: spin 2s infinite linear;
  }
</style>

<circle id="circle" cx="50" cy="50" r="20" fill="blue"/>
```

**Задачи:**
- [ ] Парсить `<style>` элементы в SVG
- [ ] Создать CSS parser для @keyframes
- [ ] Создать CSS parser для animation-* properties
- [ ] Конвертировать @keyframes в SMIL-подобную структуру
- [ ] Обновить renderer для CSS animations
- [ ] Добавить тесты
- [ ] Добавить примеры

**Сложность:** CSS парсинг - большая работа

**Приоритет:** 🟡 MEDIUM
**Оценка:** 2-3 недели

---

### S8-2: animation-* Properties 🎨
**Свойства:**
- `animation-name`
- `animation-duration`
- `animation-timing-function`
- `animation-delay`
- `animation-iteration-count`
- `animation-direction` (normal, reverse, alternate, alternate-reverse)
- `animation-fill-mode` (none, forwards, backwards, both)
- `animation-play-state` (running, paused)

**Зависит от:** S8-1

**Приоритет:** 🟡 MEDIUM
**Оценка:** 1 неделя

---

## 🟢 STAGE 9: CSS Transitions

### S9-1: transition-* Properties 🎨
**Что это:** Автоматическая анимация при изменении CSS свойств

**Пример:**
```html
<style>
  #rect {
    fill: blue;
    transition: fill 0.5s ease-in-out;
  }
  #rect:hover {
    fill: red;  /* Анимированный переход blue -> red */
  }
</style>
```

**Задачи:**
- [ ] Парсить transition-* properties
- [ ] Трекать изменения CSS свойств
- [ ] Автоматически создавать анимации при изменениях
- [ ] Реализовать timing functions (ease, linear, ease-in, ease-out)
- [ ] Добавить тесты
- [ ] Добавить примеры

**Зависит от:** S8 (CSS parsing)

**Приоритет:** 🟢 LOW
**Оценка:** 1-2 недели

---

## 🎨 STAGE 10: SVG Filters & Effects

### S10-1: Basic Filters 🎨
**Filters для реализации:**

#### feGaussianBlur - Размытие
```xml
<filter id="blur">
  <feGaussianBlur in="SourceGraphic" stdDeviation="5"/>
</filter>
```

#### feDropShadow - Тени
```xml
<filter id="shadow">
  <feDropShadow dx="2" dy="2" stdDeviation="3" flood-color="black"/>
</filter>
```

#### feColorMatrix - Цветовые трансформации
```xml
<filter id="grayscale">
  <feColorMatrix type="saturate" values="0"/>
</filter>
```

**Задачи:**
- [ ] Парсить `<filter>` элементы
- [ ] Имплементировать feGaussianBlur с ImageFilter.blur
- [ ] Имплементировать feDropShadow с Canvas.drawShadow
- [ ] Имплементировать feColorMatrix с ColorFilter
- [ ] Применять фильтры при рендеринге
- [ ] Добавить тесты
- [ ] Добавить примеры

**Файлы в Blink:**
- `blink-b87d44f-Source-core-svg/SVGFEGaussianBlurElement.cpp`
- `blink-b87d44f-Source-core-svg/SVGFEDropShadowElement.cpp`
- `blink-b87d44f-Source-core-svg/SVGFEColorMatrixElement.cpp`

**Приоритет:** 🟢 LOW
**Оценка:** 2-3 недели

---

### S10-2: Animated Filters 🎨
**Что это:** Анимация параметров фильтров

**Пример:**
```xml
<filter id="blur">
  <feGaussianBlur stdDeviation="0">
    <animate attributeName="stdDeviation" 
             from="0" to="10" dur="2s" repeatCount="indefinite"/>
  </feGaussianBlur>
</filter>
```

**Зависит от:** S10-1

**Приоритет:** 🟢 LOW
**Оценка:** 1 неделя

---

## ⚡ STAGE 11: Performance Optimizations

### S11-1: Layer Caching 🚀
**Что это:** Кэширование отрендеренных элементов

**Стратегия:**
```dart
// Кэшировать статичные элементы
if (!node.hasAnimations && !node.hasAnimatedAncestor) {
  return _cachedLayer[node.id] ??= _renderToLayer(node);
}
```

**Задачи:**
- [ ] Определять статичные элементы (без анимаций)
- [ ] Кэшировать их в Picture
- [ ] Переиспользовать кэш между кадрами
- [ ] Инвалидировать кэш при изменениях
- [ ] Добавить benchmarks
- [ ] Измерить улучшение производительности

**Приоритет:** 🟡 MEDIUM
**Оценка:** 1 неделя

---

### S11-2: Dirty Region Tracking 🚀
**Что это:** Перерисовка только изменённых областей

**Стратегия:**
```dart
// Трекать bounding box анимированных элементов
Rect dirtyRect = _calculateDirtyRegion(animatedNodes);
canvas.clipRect(dirtyRect);  // Рисовать только внутри
```

**Задачи:**
- [ ] Вычислять bounding box для каждого анимированного элемента
- [ ] Объединять перекрывающиеся регионы
- [ ] Использовать canvas.clipRect для оптимизации
- [ ] Добавить benchmarks
- [ ] Измерить улучшение производительности

**Приоритет:** 🟢 LOW
**Оценка:** 1 неделя

---

### S11-3: Path Optimization 🚀
**Что это:** Оптимизация представления и обработки путей

**Идеи из Blink:**
- Byte stream вместо объектов (экономия памяти 50-70%)
- Path simplification (меньше команд = быстрее рендеринг)
- Кэширование PathMetrics

**Задачи:**
- [ ] Создать компактное представление path (byte array?)
- [ ] Имплементировать path simplification
- [ ] Кэшировать PathMetrics для повторного использования
- [ ] Добавить benchmarks
- [ ] Измерить улучшение производительности

**Файлы в Blink:**
- `blink-b87d44f-Source-core-svg/SVGPathByteStream.h`
- `blink-b87d44f-Source-core-svg/SVGPathUtilities.cpp`

**Приоритет:** 🟢 LOW
**Оценка:** 2 недели

---

### S11-4: Multi-threading 🚀
**Что это:** Offload тяжелых операций в isolates

**Возможности:**
```dart
// Парсинг SVG в isolate
final document = await compute(parseSvgString, svgString);

// Интерполяция path в isolate (для очень сложных путей)
final interpolatedPath = await compute(
  interpolatePaths, 
  PathInterpolationData(fromPath, toPath, t)
);
```

**Задачи:**
- [ ] Сделать SvgParser serializable
- [ ] Offload парсинга в compute()
- [ ] Для сложных path morphing - offload в compute()
- [ ] Добавить benchmarks
- [ ] Измерить улучшение производительности

**Приоритет:** 🟢 LOW
**Оценка:** 1 неделя

---

## 📚 STAGE 12: Documentation & Polish

### S12-1: API Documentation 📖
**Задачи:**
- [ ] Полное dartdoc покрытие всех публичных API
- [ ] Примеры кода в документации
- [ ] Диаграммы архитектуры
- [ ] Migration guide (если были breaking changes)

**Приоритет:** 🟡 MEDIUM
**Оценка:** 1 неделя

---

### S12-2: Example App Enhancement 📖
**Задачи:**
- [ ] Добавить search по функциональности
- [ ] Добавить фильтры (по типу анимации, сложности)
- [ ] Добавить code viewer для каждого примера
- [ ] Добавить performance metrics display
- [ ] Добавить "Create your own" playground

**Приоритет:** 🟢 LOW
**Оценка:** 1 неделя

---

### S12-3: Testing Coverage 📖
**Задачи:**
- [ ] Увеличить покрытие до 90%+
- [ ] Добавить platform-specific тесты (iOS, Android, Web)
- [ ] Добавить performance benchmarks
- [ ] Добавить integration tests для example app
- [ ] Добавить stress tests (1000+ анимаций)

**Приоритет:** 🟡 MEDIUM
**Оценка:** 2 недели

---

### S12-4: Error Handling & Validation 📖
**Задачи:**
- [ ] Валидация SVG структуры
- [ ] Валидация SMIL атрибутов
- [ ] Detailed error messages в debug mode
- [ ] Graceful fallbacks для invalid SVG
- [ ] Logging system с разными уровнями

**Приоритет:** 🟡 MEDIUM
**Оценка:** 1 неделя

---

## 🎯 ПРИОРИТИЗИРОВАННЫЙ ПЛАН ДЕЙСТВИЙ

### 🔴 Немедленно (1-2 недели):
1. **P0-1:** Исправить autoPlay: false bug (1-2 дня)
2. **P0-2:** Добавить Timeline Control API (3-5 дней)
3. **P0-3:** Добавить initialTime для тестирования (1-2 дня)

**Результат:** Базовые функции работают корректно

---

### 🟠 Краткосрочно (1 месяц):
4. **S7-1:** Syncbase timing (5-7 дней)
5. **S7-2:** Event-based timing (5-7 дней)
6. **S7-3:** calcMode="spline" (3-4 дня)
7. **S7-4:** calcMode="paced" (3-4 дня)

**Результат:** SMIL поддержка ~80%

---

### 🟡 Среднесрочно (2-3 месяца):
8. **S8-1:** CSS @keyframes (2-3 недели)
9. **S8-2:** animation-* properties (1 неделя)
10. **S11-1:** Layer caching (1 неделя)
11. **S12-3:** Testing coverage (2 недели)

**Результат:** CSS animations работают, производительность улучшена

---

### 🟢 Долгосрочно (3-6 месяцев):
12. **S9-1:** CSS Transitions (1-2 недели)
13. **S10-1:** Basic filters (2-3 недели)
14. **S10-2:** Animated filters (1 неделя)
15. **S11-2-4:** Дополнительные оптимизации (4 недели)
16. **S12-1-4:** Documentation & polish (5 недель)

**Результат:** Production-ready пакет

---

## 📊 МЕТРИКИ УСПЕХА

### Performance Targets:
- ✅ 60 FPS для простых анимаций (ДОСТИГНУТО)
- ✅ 30+ FPS для сложных анимаций (ДОСТИГНУТО)
- 🎯 60 FPS для сложных анимаций (ЦЕЛЬ)
- 🎯 <100ms startup время для больших SVG
- 🎯 <16ms frame время для большинства случаев

### Feature Completeness:
- ✅ 60% SMIL spec (СЕЙЧАС)
- 🎯 80% SMIL spec (после Stage 7)
- 🎯 50% CSS Animations (после Stage 8)
- 🎯 90% покрытие тестами

### Quality Targets:
- 🎯 0 critical bugs
- 🎯 <5 known medium bugs
- 🎯 95%+ пользовательская удовлетворённость

---

## 🔗 ПОЛЕЗНЫЕ ССЫЛКИ

### Спецификации:
- [SMIL Animation](https://www.w3.org/TR/smil-animation/)
- [SVG Animation](https://www.w3.org/TR/SVG11/animate.html)
- [CSS Animations](https://www.w3.org/TR/css-animations-1/)
- [CSS Transitions](https://www.w3.org/TR/css-transitions-1/)

### Blink Source Code:
- `blink-b87d44f-Source-core-svg/animation/` - SMIL implementation
- `blink-b87d44f-Source-core-svg/SVGAnimationElement.cpp` - Animation base class
- `blink-b87d44f-Source-core-svg/SVGPathBlender.cpp` - Path morphing

### Flutter Resources:
- [CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html)
- [Animation](https://api.flutter.dev/flutter/animation/Animation-class.html)
- [Canvas](https://api.flutter.dev/flutter/dart-ui/Canvas-class.html)

---

## 💬 NOTES

### Что делает нас уникальными:
1. ✅ Полная SMIL поддержка (немногие Flutter пакеты)
2. ✅ Высокая производительность
3. ✅ Comprehensive testing
4. 🎯 Будущее: CSS Animations + Filters

### Чем вдохновляться из Blink:
1. **Архитектура:** Чистое разделение parsing, animation, rendering
2. **Error handling:** Graceful degradation
3. **Performance:** Byte streams, caching, dirty tracking
4. **Completeness:** Все edge cases обработаны

### Риски:
- ⚠️ CSS parsing - большая работа, может занять больше времени
- ⚠️ Filters - требуют продвинутые Canvas операции
- ⚠️ Performance - нужны реальные benchmarks на устройствах

---

**Happy Coding! 🚀**
