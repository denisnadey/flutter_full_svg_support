# Архитектурный план добавления SMIL/CSS анимаций в flutter_svg

## 📊 АНАЛИЗ ТЕКУЩЕЙ АРХИТЕКТУРЫ

### Текущий Pipeline (flutter_svg 2.2.2)

```
SVG Source (asset/network/string/bytes)
         ↓
   SvgLoader (SvgAssetLoader, SvgNetworkLoader, etc.)
         ↓
   prepareMessage() — загрузка сырых данных
         ↓
   provideSvg() — получение строки XML
         ↓
   compute() в isolate:
      vector_graphics_compiler.encodeSvg()
         ↓
   ByteData (бинарный .vec формат)
         ↓
   Cache (svg.cache)
         ↓
   vector_graphics: createCompatVectorGraphic()
         ↓
   VectorGraphic widget
         ↓
   RenderObject рендерит Picture/Image
```

### Ключевые находки

1. **Полная делегация парсинга**: `flutter_svg` **НЕ** парсит SVG сам, он делегирует это `vector_graphics_compiler.encodeSvg()`
2. **Потеря DOM**: После `encodeSvg()` получается бинарный формат `.vec`, который содержит только команды рисования (paths, fills, strokes), **БЕЗ** DOM-структуры
3. **Нет Drawable классов**: В текущей версии нет старых `DrawableRoot`/`DrawableShape` — всё через `vector_graphics`
4. **Публичный API стабилен**: `SvgPicture.asset/network/string/memory` + `BytesLoader` хорошо изолированы

### Что теряется в текущем pipeline

❌ **DOM-дерево** элементов (`<g>`, `<rect>`, `<circle>`, `<path>`)  
❌ **ID элементов** и их иерархия  
❌ **SMIL элементы** (`<animate>`, `<animateTransform>`, `<animateMotion>`)  
❌ **CSS `<style>` блоки** и `@keyframes`  
❌ **События** (хотя их в Flutter всё равно сложно реализовать)  
❌ **Динамические атрибуты** — после компиляции всё "запечено" в commands  

---

## 🎯 СТРАТЕГИЯ ИНТЕГРАЦИИ

### Вариант A: Форк vector_graphics_compiler (❌ Не рекомендую)

**Плюсы:**
- Полный контроль над парсингом
- Можно расширить .vec формат для анимаций

**Минусы:**
- Огромный объём работы
- Необходимость поддерживать форк
- Синхронизация с upstream
- Зависимость от внутренних деталей vector_graphics

### Вариант B: Параллельный анимационный pipeline ⭐ **РЕКОМЕНДУЮ**

**Суть:**
- Для статичных SVG — оставить текущий быстрый путь через `vector_graphics`
- Для SVG с анимациями — новый путь с собственным парсером и DOM-деревом
- Автоопределение или явный флаг `hasAnimations`

**Плюсы:**
- ✅ Не ломает существующий API
- ✅ Не зависит от vector_graphics для анимаций
- ✅ Можно внедрять итеративно
- ✅ Оптимальный выбор производительности

**Минусы:**
- Дублирование некоторой логики парсинга (но минимальное)
- Две кодовые ветки рендеринга

---

## 🏗️ АРХИТЕКТУРА РЕШЕНИЯ (Вариант B)

### Новые модули

```
lib/src/
├── animation/
│   ├── svg_dom.dart              # SVG DOM модель
│   ├── smil/
│   │   ├── smil_animation.dart   # Базовые классы SMIL анимаций
│   │   ├── smil_parser.dart      # Парсер <animate>, <animateTransform>, etc.
│   │   ├── smil_timeline.dart    # Управление временем и тиканием
│   │   ├── interpolators.dart    # Интерполяция значений (число, цвет, transform, path)
│   │   └── timing.dart           # begin/end/dur/repeatCount логика
│   ├── css/
│   │   ├── css_animation.dart    # CSS @keyframes анимации
│   │   ├── css_parser.dart       # Минимальный CSS парсер
│   │   └── css_transition.dart   # CSS transitions
│   ├── svg_parser.dart           # Облегчённый XML→DOM парсер для анимаций
│   ├── animated_renderer.dart    # CustomPainter для анимированных SVG
│   └── animation_detector.dart   # Определяет наличие анимаций в SVG
└── loaders.dart                  # (расширить)
```

### Публичный API

#### Новый виджет: `AnimatedSvgPicture`

```dart
/// lib/src/animated_svg_picture.dart

class AnimatedSvgPicture extends StatefulWidget {
  const AnimatedSvgPicture(
    this.bytesLoader, {
    super.key,
    
    // Все существующие параметры SvgPicture
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.colorFilter,
    this.semanticsLabel,
    this.clipBehavior = Clip.hardEdge,
    // ... etc
    
    // ⭐ НОВЫЕ параметры для анимаций
    this.enableSmilAnimations = true,
    this.enableCssAnimations = true,
    this.autoPlay = true,
    this.loop = true,
    this.controller,
    this.onAnimationStart,
    this.onAnimationEnd,
  });
  
  final BytesLoader bytesLoader;
  final bool enableSmilAnimations;
  final bool enableCssAnimations;
  final bool autoPlay;
  final bool loop;
  final SvgAnimationController? controller;
  final VoidCallback? onAnimationStart;
  final VoidCallback? onAnimationEnd;
  
  // Именованные конструкторы как у SvgPicture
  AnimatedSvgPicture.asset(...);
  AnimatedSvgPicture.network(...);
  AnimatedSvgPicture.string(...);
  AnimatedSvgPicture.memory(...);
}
```

#### Контроллер анимаций

```dart
/// lib/src/animation/svg_animation_controller.dart

class SvgAnimationController extends ChangeNotifier {
  SvgAnimationController({
    this.duration,
    this.vsync,
  });
  
  final Duration? duration;
  final TickerProvider? vsync;
  
  void play();
  void pause();
  void stop();
  void seek(Duration time);
  void setSpeed(double speed);
  
  bool get isPlaying;
  Duration get currentTime;
  Duration get totalDuration;
}
```

### Внутренние структуры данных

#### SVG DOM

```dart
/// lib/src/animation/svg_dom.dart

/// Узел SVG DOM дерева
class SvgNode {
  SvgNode({
    required this.tagName,
    this.id,
    this.className,
    required this.attributes,
    this.children = const [],
    this.parent,
  });
  
  final String tagName; // 'svg', 'g', 'rect', 'circle', 'path', etc.
  final String? id;
  final String? className;
  final Map<String, SvgAttribute> attributes;
  final List<SvgNode> children;
  SvgNode? parent;
  
  /// Список анимаций, привязанных к этому узлу
  final List<SmilAnimation> animations = [];
  
  /// Для оптимизации: флаг, есть ли анимации в поддереве
  bool hasAnimations = false;
  
  /// Кэшированный Picture для статичных поддеревьев
  ui.Picture? cachedPicture;
}

/// Атрибут SVG элемента (может быть анимирован)
class SvgAttribute {
  SvgAttribute({
    required this.name,
    required this.baseValue,
  });
  
  final String name; // 'x', 'y', 'fill', 'transform', etc.
  
  /// Базовое значение из XML
  Object baseValue; // String, double, Color, Transform, etc.
  
  /// Текущее анимированное значение (если есть активная анимация)
  Object? animatedValue;
  
  /// Флаг: активна ли анимация в данный момент
  bool isAnimated = false;
  
  /// Получить эффективное значение (animatedValue если есть, иначе baseValue)
  Object get effectiveValue => isAnimated ? animatedValue! : baseValue;
}
```

#### SMIL Анимация

```dart
/// lib/src/animation/smil/smil_animation.dart

enum SmilAnimationType {
  animate,           // <animate>
  animateTransform,  // <animateTransform>
  animateMotion,     // <animateMotion>
  set,               // <set>
}

enum SmilCalcMode {
  discrete,
  linear,
  paced,
  spline,
}

enum SmilFillMode {
  freeze,   // сохранить последнее значение
  remove,   // вернуться к base value
}

enum SmilAdditiveMode {
  replace,  // заменить базовое значение
  sum,      // добавить к базовому
}

class SmilAnimation {
  SmilAnimation({
    required this.type,
    required this.targetNode,
    required this.attributeName,
    required this.attributeType,
    this.from,
    this.to,
    this.by,
    this.values,
    this.keyTimes,
    this.keySplines,
    required this.dur,
    this.begin = Duration.zero,
    this.end,
    this.repeatCount = 1.0,
    this.repeatDur,
    this.fillMode = SmilFillMode.remove,
    this.calcMode = SmilCalcMode.linear,
    this.additive = SmilAdditiveMode.replace,
    this.accumulate = false,
  });
  
  final SmilAnimationType type;
  final SvgNode targetNode;
  final String attributeName; // 'x', 'y', 'fill', etc.
  final SvgAttributeType attributeType;
  
  // Значения анимации
  final Object? from;
  final Object? to;
  final Object? by;
  final List<Object>? values; // для keyframe анимаций
  final List<double>? keyTimes; // [0.0, 0.5, 1.0]
  final List<CubicBezier>? keySplines; // для spline интерполяции
  
  // Тайминг
  final Duration dur;
  final Duration begin;
  final Duration? end;
  final double repeatCount; // double.infinity для 'indefinite'
  final Duration? repeatDur;
  
  // Поведение
  final SmilFillMode fillMode;
  final SmilCalcMode calcMode;
  final SmilAdditiveMode additive;
  final bool accumulate;
  
  // Runtime состояние
  bool isActive = false;
  int currentIteration = 0;
  Duration localTime = Duration.zero;
  
  /// Вычислить значение анимации в момент времени t ∈ [0, 1] внутри итерации
  Object? computeValue(double t);
}

/// Тип атрибута для корректной интерполяции
enum SvgAttributeType {
  number,        // x, y, width, height, opacity, stroke-width
  length,        // с единицами: px, em, %
  color,         // fill, stroke
  transform,     // transform attribute
  path,          // d attribute для <path>
  points,        // points для <polygon>, <polyline>
  string,        // для discrete анимаций
  list,          // stroke-dasharray и подобные
}
```

#### Timeline (управление временем)

```dart
/// lib/src/animation/smil/smil_timeline.dart

class SvgTimeline {
  SvgTimeline({
    required this.animations,
    required this.rootNode,
  });
  
  final List<SmilAnimation> animations;
  final SvgNode rootNode;
  
  Duration _currentTime = Duration.zero;
  Duration get currentTime => _currentTime;
  
  /// Продвинуть время на delta
  void tick(Duration delta) {
    _currentTime += delta;
    _updateAnimations(_currentTime);
  }
  
  /// Перепрыгнуть на конкретное время
  void seek(Duration time) {
    _currentTime = time;
    _updateAnimations(_currentTime);
  }
  
  /// Обновить все анимации для текущего времени
  void _updateAnimations(Duration time) {
    for (final animation in animations) {
      _updateAnimation(animation, time);
    }
  }
  
  void _updateAnimation(SmilAnimation anim, Duration globalTime) {
    // Проверить, активна ли анимация
    final effectiveEnd = anim.end ?? 
        (anim.begin + anim.dur * anim.repeatCount);
    
    if (globalTime < anim.begin || globalTime >= effectiveEnd) {
      // Не активна или закончилась
      if (anim.isActive && anim.fillMode == SmilFillMode.freeze) {
        // Оставить последнее значение
        anim.isActive = false;
        // Значение уже установлено
      } else {
        // Убрать анимацию
        anim.isActive = false;
        final attr = anim.targetNode.attributes[anim.attributeName];
        if (attr != null) {
          attr.isAnimated = false;
          attr.animatedValue = null;
        }
      }
      return;
    }
    
    // Анимация активна
    anim.isActive = true;
    
    // Вычислить локальное время внутри повтора
    final timeSinceBegin = globalTime - anim.begin;
    anim.currentIteration = (timeSinceBegin.inMicroseconds / 
                             anim.dur.inMicroseconds).floor();
    final iterationProgress = (timeSinceBegin.inMicroseconds % 
                               anim.dur.inMicroseconds) / 
                              anim.dur.inMicroseconds;
    
    // Вычислить значение
    final value = anim.computeValue(iterationProgress);
    
    // Применить к атрибуту
    final attr = anim.targetNode.attributes[anim.attributeName];
    if (attr != null) {
      attr.isAnimated = true;
      attr.animatedValue = value;
    }
  }
  
  /// Получить общую длительность всех анимаций
  Duration getTotalDuration() {
    Duration max = Duration.zero;
    for (final anim in animations) {
      final end = anim.begin + anim.dur * anim.repeatCount;
      if (end > max) max = end;
    }
    return max;
  }
}
```

### Рендеринг

#### AnimatedSvgPainter

```dart
/// lib/src/animation/animated_renderer.dart

class AnimatedSvgPainter extends CustomPainter {
  AnimatedSvgPainter({
    required this.rootNode,
    required this.timeline,
    required this.viewBox,
  });
  
  final SvgNode rootNode;
  final SvgTimeline timeline;
  final Rect viewBox;
  
  @override
  void paint(Canvas canvas, Size size) {
    // Применить viewBox transform
    final matrix = _computeViewBoxTransform(size);
    canvas.save();
    canvas.transform(matrix.storage);
    
    // Рендерить дерево рекурсивно
    _paintNode(canvas, rootNode);
    
    canvas.restore();
  }
  
  void _paintNode(Canvas canvas, SvgNode node) {
    canvas.save();
    
    // Применить трансформы узла
    _applyTransform(canvas, node);
    
    // Если узел статичен и есть кэш — использовать его
    if (!node.hasAnimations && node.cachedPicture != null) {
      canvas.drawPicture(node.cachedPicture!);
      canvas.restore();
      return;
    }
    
    // Рендерить текущий узел
    switch (node.tagName) {
      case 'rect':
        _paintRect(canvas, node);
        break;
      case 'circle':
        _paintCircle(canvas, node);
        break;
      case 'path':
        _paintPath(canvas, node);
        break;
      case 'g':
      case 'svg':
        // Только контейнер
        break;
      // ... другие элементы
    }
    
    // Рендерить детей
    for (final child in node.children) {
      _paintNode(canvas, child);
    }
    
    canvas.restore();
  }
  
  void _paintRect(Canvas canvas, SvgNode node) {
    final x = _getNumberAttr(node, 'x');
    final y = _getNumberAttr(node, 'y');
    final width = _getNumberAttr(node, 'width');
    final height = _getNumberAttr(node, 'height');
    final fill = _getColorAttr(node, 'fill');
    final stroke = _getColorAttr(node, 'stroke');
    final strokeWidth = _getNumberAttr(node, 'stroke-width', 1.0);
    final opacity = _getNumberAttr(node, 'opacity', 1.0);
    
    final rect = Rect.fromLTWH(x, y, width, height);
    final paint = Paint();
    
    if (fill != null) {
      paint.color = fill.withOpacity(fill.opacity * opacity);
      paint.style = PaintingStyle.fill;
      canvas.drawRect(rect, paint);
    }
    
    if (stroke != null) {
      paint.color = stroke.withOpacity(stroke.opacity * opacity);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = strokeWidth;
      canvas.drawRect(rect, paint);
    }
  }
  
  double _getNumberAttr(SvgNode node, String name, [double defaultValue = 0.0]) {
    final attr = node.attributes[name];
    if (attr == null) return defaultValue;
    final value = attr.effectiveValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }
  
  Color? _getColorAttr(SvgNode node, String name) {
    final attr = node.attributes[name];
    if (attr == null) return null;
    final value = attr.effectiveValue;
    if (value is Color) return value;
    if (value is String) return _parseColor(value);
    return null;
  }
  
  @override
  bool shouldRepaint(AnimatedSvgPainter oldDelegate) {
    // Перерисовывать каждый кадр для анимаций
    return true;
  }
}
```

---

## 🔄 PIPELINE ПЕРЕКЛЮЧЕНИЯ

### Логика выбора pipeline

```dart
/// lib/src/animation/animation_detector.dart

class AnimationDetector {
  /// Быстрая проверка: есть ли в SVG анимации
  static bool hasSvgAnimations(String svgXml) {
    // Простой regex поиск
    return svgXml.contains(RegExp(r'<animate[^>]*>')) ||
           svgXml.contains(RegExp(r'<animateTransform[^>]*>')) ||
           svgXml.contains(RegExp(r'<animateMotion[^>]*>')) ||
           svgXml.contains(RegExp(r'@keyframes')) ||
           svgXml.contains(RegExp(r'animation[:-]'));
  }
}
```

### Модифицированный SvgLoader

```dart
/// lib/src/loaders.dart (расширение)

abstract class SvgLoader<T> extends BytesLoader {
  // ... существующий код ...
  
  /// НОВЫЙ метод: определить, нужен ли анимационный pipeline
  @protected
  bool shouldUseAnimationPipeline(String svg) {
    return AnimationDetector.hasSvgAnimations(svg);
  }
  
  /// НОВЫЙ метод: парсинг для анимаций
  @protected
  Future<SvgDomDocument> parseForAnimations(String svg, BuildContext? context) {
    // Парсим XML в DOM
    return compute((String xml) {
      return SvgParser.parse(xml);
    }, svg);
  }
}
```

---

## 📝 ПЛАН РЕАЛИЗАЦИИ ПО ЭТАПАМ

### Этап 1: Базовая инфраструктура (1-2 недели)

**Задачи:**
1. ✅ Создать `lib/src/animation/` структуру
2. ✅ Реализовать `SvgNode` и `SvgAttribute`
3. ✅ Создать `AnimationDetector`
4. ✅ Базовый XML → SvgNode парсер (`SvgParser`)
5. ✅ Тесты для парсера базовых элементов (rect, circle, path, g)

**Файлы:**
- `lib/src/animation/svg_dom.dart`
- `lib/src/animation/svg_parser.dart`
- `lib/src/animation/animation_detector.dart`
- `test/animation/svg_parser_test.dart`

**Критерий готовности:**
- Парсер может преобразовать простой SVG в дерево SvgNode
- Атрибуты корректно извлекаются

### Этап 2: SMIL Core — числовые анимации (2 недели)

**Задачи:**
1. ✅ Реализовать `SmilAnimation` базовый класс
2. ✅ Парсер `<animate>` для числовых атрибутов (x, y, width, height, opacity)
3. ✅ `SvgTimeline` с методами tick/seek
4. ✅ Интерполятор для чисел (linear, discrete)
5. ✅ Поддержка `from/to`, `values + keyTimes`
6. ✅ Юнит-тесты для тайминга и интерполяции

**Файлы:**
- `lib/src/animation/smil/smil_animation.dart`
- `lib/src/animation/smil/smil_parser.dart`
- `lib/src/animation/smil/smil_timeline.dart`
- `lib/src/animation/smil/interpolators.dart`
- `test/animation/smil_animation_test.dart`

**Пример теста:**
```dart
test('animate opacity from 0 to 1', () {
  final anim = SmilAnimation(
    type: SmilAnimationType.animate,
    attributeName: 'opacity',
    from: 0.0,
    to: 1.0,
    dur: Duration(seconds: 2),
  );
  
  expect(anim.computeValue(0.0), 0.0);
  expect(anim.computeValue(0.5), 0.5);
  expect(anim.computeValue(1.0), 1.0);
});
```

### Этап 3: Рендеринг анимированных SVG (2 недели)

**Задачи:**
1. ✅ `AnimatedSvgPainter` — CustomPainter для отрисовки SvgNode дерева
2. ✅ Рендеринг базовых фигур: rect, circle, ellipse, line
3. ✅ Применение fill, stroke, opacity из атрибутов
4. ✅ Создать `AnimatedSvgPicture` виджет
5. ✅ Интеграция с Flutter Ticker для анимации
6. ✅ Тесты: golden tests для простых анимированных SVG

**Файлы:**
- `lib/src/animation/animated_renderer.dart`
- `lib/src/animated_svg_picture.dart`
- `lib/animated_svg.dart` (новый export файл)
- `test/golden_animation/simple_opacity_test.dart`

**Пример использования:**
```dart
AnimatedSvgPicture.string(
  '''
  <svg viewBox="0 0 100 100">
    <rect x="10" y="10" width="30" height="30" fill="red">
      <animate attributeName="opacity" 
               from="0" to="1" 
               dur="2s" 
               repeatCount="indefinite"/>
    </rect>
  </svg>
  ''',
  width: 200,
  height: 200,
);
```

### Этап 4: Цветовые анимации (1 неделя)

**Задачи:**
1. ✅ Интерполятор для Color (RGB space)
2. ✅ Поддержка анимации fill, stroke
3. ✅ Парсинг CSS/SVG цветов (#RGB, rgb(), named colors)
4. ✅ Тесты

**Файлы:**
- `lib/src/animation/smil/interpolators.dart` (расширение)
- `lib/src/animation/color_parser.dart`

### Этап 5: Transform анимации (2 недели)

**Задачи:**
1. ✅ Реализовать `<animateTransform>`
2. ✅ Поддержка типов: translate, scale, rotate, skewX, skewY
3. ✅ Интерполяция трансформаций
4. ✅ Применение в рендерере
5. ✅ Тесты и goldens

**Файлы:**
- `lib/src/animation/smil/transform_animation.dart`
- `lib/src/animation/transform_parser.dart`

### Этап 6: Path анимации (2-3 недели)

**Задачи:**
1. ✅ Парсинг SVG path `d` attribute
2. ✅ Интерполяция path (требует совместимости сегментов)
3. ✅ Поддержка `<animateMotion>`
4. ✅ Тесты

**Сложности:**
- Path интерполяция работает только для совместимых path (одинаковое количество команд)
- Нужен нормализатор path

### Этап 7: Расширенный SMIL (1-2 недели)

**Задачи:**
1. ✅ `keySplines` для cubic bezier easing
2. ✅ `calcMode="paced"`
3. ✅ `additive="sum"` и `accumulate="sum"`
4. ✅ `repeatCount`, `repeatDur`
5. ✅ `<set>` элемент
6. ✅ Syncbase timing (`begin="anim1.end+2s"`)

### Этап 8: CSS Animations (3 недели)

**Задачи:**
1. ✅ Минимальный CSS парсер для `<style>` блоков
2. ✅ Парсинг `@keyframes`
3. ✅ Поддержка `animation-*` свойств
4. ✅ Интеграция с общим timeline
5. ✅ Тесты

**Файлы:**
- `lib/src/animation/css/css_parser.dart`
- `lib/src/animation/css/css_animation.dart`

### Этап 9: CSS Transitions (2 недели)

**Задачи:**
1. ✅ Отслеживание изменений стилей
2. ✅ Создание временных анимаций
3. ✅ `transition-property`, `transition-duration`, `transition-timing-function`
4. ✅ Тесты

### Этап 10: Оптимизации (2 недели)

**Задачи:**
1. ✅ Кэширование статичных поддеревьев в Picture
2. ✅ Dirty tracking — перерисовка только изменённых узлов
3. ✅ Profiling и оптимизация аллокаций
4. ✅ Ленивый парсинг CSS
5. ✅ Тесты производительности

### Этап 11: Документация и примеры (1 неделя)

**Задачи:**
1. ✅ README обновление
2. ✅ API документация
3. ✅ Пример приложения с разными анимациями
4. ✅ Migration guide
5. ✅ Таблица поддержки SMIL/CSS возможностей

---

## 🎨 ПУБЛИЧНЫЙ API (финальный вид)

### Экспорты

```dart
// lib/flutter_svg.dart (без изменений)
export 'svg.dart';

// lib/animated_svg.dart (НОВЫЙ)
export 'src/animated_svg_picture.dart';
export 'src/animation/svg_animation_controller.dart';
```

### Использование

#### Статичный SVG (старый способ, без изменений)
```dart
SvgPicture.asset('assets/logo.svg')
```

#### Анимированный SVG (новый способ)
```dart
AnimatedSvgPicture.asset(
  'assets/animated_logo.svg',
  autoPlay: true,
  loop: true,
)
```

#### С контроллером
```dart
final controller = SvgAnimationController();

AnimatedSvgPicture.network(
  'https://example.com/anim.svg',
  controller: controller,
  autoPlay: false,
)

// Управление
controller.play();
controller.pause();
controller.seek(Duration(seconds: 2));
```

---

## ⚡ ОПТИМИЗАЦИИ

### 1. Статичные поддеревья → Picture cache
```dart
// Если у узла и всех детей hasAnimations == false
if (!node.hasAnimations && node.cachedPicture == null) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  _paintNodeSubtree(canvas, node);
  node.cachedPicture = recorder.endRecording();
}
```

### 2. Dirty tracking
```dart
class SvgNode {
  bool _isDirty = false;
  
  void markDirty() {
    _isDirty = true;
    parent?.markDirty(); // bubble up
  }
}
```

### 3. Предварительный парсинг
- Все `values`, `keyTimes`, `keySplines` парсим в конструкторе SmilAnimation
- Никаких строк не парсим в `tick()`

### 4. Object pooling для Path
- Переиспользовать Path объекты где возможно
- Использовать `Path.reset()` вместо создания новых

---

## 🧪 СТРАТЕГИЯ ТЕСТИРОВАНИЯ

### Unit тесты
- `SvgParser`: парсинг разных элементов
- `SmilAnimation`: вычисление значений
- Интерполяторы: числа, цвета, transform, path
- `SvgTimeline`: тайминг и активация анимаций

### Widget тесты
- `AnimatedSvgPicture` создаётся корректно
- Контроллер работает

### Golden тесты
- Snapshots анимированных SVG в разные моменты времени
- Сравнение с эталонными изображениями

### Performance тесты
- FPS для сложных анимаций
- Memory profiling (нет утечек)

---

## 📊 ТАБЛИЦА ПОДДЕРЖКИ ВОЗМОЖНОСТЕЙ

### SMIL (целевая поддержка)

| Возможность | Статус | Приоритет | Этап |
|------------|--------|-----------|------|
| `<animate>` числа | ✅ Planned | P0 | 2 |
| `<animate>` цвета | ✅ Planned | P0 | 4 |
| `<animateTransform>` | ✅ Planned | P0 | 5 |
| `<animateMotion>` | ✅ Planned | P1 | 6 |
| `<set>` | ✅ Planned | P2 | 7 |
| `from/to/by` | ✅ Planned | P0 | 2 |
| `values` + `keyTimes` | ✅ Planned | P0 | 2 |
| `keySplines` | ✅ Planned | P1 | 7 |
| `dur`, `begin`, `end` | ✅ Planned | P0 | 2 |
| `repeatCount`, `repeatDur` | ✅ Planned | P0 | 7 |
| `fill="freeze/remove"` | ✅ Planned | P0 | 2 |
| `calcMode` (linear/discrete/paced/spline) | ✅ Planned | P1 | 7 |
| `additive`, `accumulate` | ✅ Planned | P2 | 7 |
| Syncbase timing | ✅ Planned | P2 | 7 |
| Event-based begin/end | ⚠️ Limited | P3 | - |

### CSS Animations

| Возможность | Статус | Приоритет | Этап |
|------------|--------|-----------|------|
| `@keyframes` | ✅ Planned | P1 | 8 |
| `animation-name` | ✅ Planned | P1 | 8 |
| `animation-duration` | ✅ Planned | P1 | 8 |
| `animation-timing-function` | ✅ Planned | P1 | 8 |
| `animation-iteration-count` | ✅ Planned | P1 | 8 |
| `animation-direction` | ✅ Planned | P2 | 8 |
| `animation-fill-mode` | ✅ Planned | P1 | 8 |
| `animation-delay` | ✅ Planned | P1 | 8 |
| `transition-*` | ✅ Planned | P2 | 9 |

---

## 🚀 СЛЕДУЮЩИЕ ШАГИ

1. **Создать базовую структуру модулей** (Этап 1)
2. **Написать парсер SvgNode** 
3. **Реализовать SMIL ядро для чисел** (Этап 2)
4. **Создать AnimatedSvgPicture виджет** (Этап 3)
5. **Итеративно добавлять функции** (Этапы 4-9)

---

## 💡 КЛЮЧЕВЫЕ ПРЕИМУЩЕСТВА АРХИТЕКТУРЫ

✅ **Обратная совместимость**: `SvgPicture` не меняется  
✅ **Оптимальная производительность**: статика через vector_graphics, анимации — отдельно  
✅ **Модульность**: можно включать/выключать SMIL и CSS независимо  
✅ **Расширяемость**: легко добавлять новые типы анимаций  
✅ **Тестируемость**: каждый компонент изолирован  
✅ **Flutter-native**: используем Ticker, CustomPainter, стандартные паттерны  

---

## 📚 СПРАВОЧНЫЕ МАТЕРИАЛЫ

- [SVG 1.1 Spec](https://www.w3.org/TR/SVG11/)
- [SMIL Animation](https://www.w3.org/TR/2001/REC-smil-animation-20010904/)
- [CSS Animations](https://www.w3.org/TR/css-animations-1/)
- [vector_graphics package](https://pub.dev/packages/vector_graphics)
- [vector_graphics_compiler](https://pub.dev/packages/vector_graphics_compiler)

---

**Этот документ — живой план.** По мере реализации будем обновлять статусы и детали.
