# Next Steps - Quick Start Guide

**Дата:** 9 января 2026 г.

Это краткое руководство для быстрого старта работы над следующими задачами.

## 🚀 Что делать прямо сейчас

### ✅ Этап завершён: Stage 1-6
- 313 тестов проходят
- Path morphing работает
- AnimateMotion работает
- Transform animations работают

---

## 🔴 ЗАДАЧА #1: Исправить autoPlay: false bug

**Время:** 1-2 дня
**Приоритет:** CRITICAL

### Симптомы:
```dart
AnimatedSvgPicture.string(
  svgString,
  autoPlay: false,  // ❌ Рендерит 0 пикселей
);
```

### План действий:
1. Открыть `lib/src/animation/animated_svg_picture.dart`
2. Найти где инициализируется timeline
3. При `autoPlay: false` добавить:
   ```dart
   if (!widget.autoPlay) {
     _timeline.seek(Duration.zero);  // Установить начальное состояние
     setState(() {});  // Форсировать ре-рендер
   }
   ```
4. Написать тест:
   ```dart
   testWidgets('autoPlay: false renders initial frame', (tester) async {
     await tester.pumpWidget(
       AnimatedSvgPicture.string(simpleSvg, autoPlay: false)
     );
     
     final pixels = await VisualTestUtils.captureWidgetPixels(tester);
     expect(pixels.any((p) => p != 0), isTrue); // Есть пиксели
   });
   ```

### Файлы для изучения:
- `lib/src/animation/animated_svg_picture.dart` - widget
- `lib/src/animation/smil/smil_timeline.dart` - timeline
- `blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp:138` - begin() в Blink

---

## 🔴 ЗАДАЧА #2: Timeline Control API

**Время:** 3-5 дней
**Приоритет:** CRITICAL

### Цель:
```dart
final controller = AnimatedSvgController();

AnimatedSvgPicture.string(svgString, controller: controller);

controller.pause();
controller.resume();
controller.seek(Duration(seconds: 2));
controller.reverse();
```

### План действий:

#### Шаг 1: Создать контроллер (1 день)
```bash
touch lib/src/animation/animated_svg_controller.dart
```

```dart
// lib/src/animation/animated_svg_controller.dart
class AnimatedSvgController extends ChangeNotifier {
  bool _isPaused = false;
  double _playbackRate = 1.0;
  Duration? _seekTarget;
  
  bool get isPaused => _isPaused;
  double get playbackRate => _playbackRate;
  
  void pause() {
    _isPaused = true;
    notifyListeners();
  }
  
  void resume() {
    _isPaused = false;
    notifyListeners();
  }
  
  void seek(Duration time) {
    _seekTarget = time;
    notifyListeners();
  }
  
  void setPlaybackRate(double rate) {
    _playbackRate = rate;
    notifyListeners();
  }
}
```

#### Шаг 2: Интегрировать в AnimatedSvgPicture (1 день)
```dart
// lib/src/animation/animated_svg_picture.dart
class AnimatedSvgPicture extends StatefulWidget {
  final AnimatedSvgController? controller;
  
  AnimatedSvgPicture.string(
    String svgString, {
    this.controller,
    // ...
  });
}

class _AnimatedSvgPictureState extends State<AnimatedSvgPicture> {
  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onControllerUpdate);
  }
  
  void _onControllerUpdate() {
    if (widget.controller!.isPaused) {
      _ticker.stop();
    } else {
      _ticker.start();
    }
    
    if (widget.controller!._seekTarget != null) {
      _timeline.seek(widget.controller!._seekTarget!);
      widget.controller!._seekTarget = null;
      setState(() {});
    }
  }
}
```

#### Шаг 3: Тесты (1 день)
```bash
touch test/animation/controller_test.dart
```

#### Шаг 4: Пример в example app (1 день)
```bash
touch example/lib/pages/controller_demo_page.dart
```

### Файлы для изучения:
- Flutter `AnimationController` - похожая архитектура
- `blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.h` - API в Blink

---

## 🟠 ЗАДАЧА #3: Syncbase Timing

**Время:** 5-7 дней
**Приоритет:** HIGH

### Цель:
```xml
<animate id="anim1" attributeName="x" from="0" to="100" dur="2s"/>
<animate begin="anim1.end+2s" attributeName="y" from="0" to="100" dur="2s"/>
```

### План действий:

#### Шаг 1: Парсинг (2 дня)
```dart
// lib/src/animation/smil/smil_parser.dart

class SyncbaseCondition {
  final String targetId;      // "anim1"
  final String event;         // "begin" или "end"
  final Duration offset;      // +2s
  
  static SyncbaseCondition? parse(String value) {
    // Парсить "anim1.end+2s"
    final match = RegExp(r'(\w+)\.(begin|end)([+-][\d.]+s)?').firstMatch(value);
    if (match == null) return null;
    
    return SyncbaseCondition(
      targetId: match.group(1)!,
      event: match.group(2)!,
      offset: _parseOffset(match.group(3)),
    );
  }
}
```

#### Шаг 2: Dependency tracking (2 дня)
```dart
// lib/src/animation/smil/smil_timeline.dart

class SvgTimeline {
  final Map<String, List<SmilAnimation>> _dependencies = {};
  
  void addDependency(SmilAnimation animation, SyncbaseCondition condition) {
    _dependencies.putIfAbsent(condition.targetId, () => [])
        .add(animation);
  }
  
  void notifyAnimationEvent(String animationId, String event, Duration time) {
    final dependents = _dependencies[animationId] ?? [];
    for (final anim in dependents) {
      if (anim.syncCondition?.event == event) {
        anim.start(time + anim.syncCondition!.offset);
      }
    }
  }
}
```

#### Шаг 3: Тесты (1 день)
```bash
touch test/animation/syncbase_timing_test.dart
```

#### Шаг 4: Примеры (1 день)
```bash
touch example/lib/widgets/smil_syncbase_widget.dart
```

### Файлы для изучения:
- `blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp:200-400` - парсинг
- `blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp:handleConditionEvent()`

---

## 📝 Workflow для каждой задачи

### 1. Изучение
- Прочитать relevant секцию в ROADMAP.md
- Изучить исходники Blink
- Изучить SMIL/CSS спецификацию

### 2. Планирование
- Разбить на подзадачи
- Определить затронутые файлы
- Набросать API

### 3. Реализация
- Написать failing test
- Имплементировать feature
- Test проходит ✅

### 4. Тестирование
- Unit tests
- Integration tests
- Visual tests (если нужно)
- Запустить все тесты: `flutter test test/animation/`

### 5. Примеры
- Добавить example в example app
- Обновить README.md
- Обновить ANIMATION.md (user guide)

### 6. Документация
- Добавить dartdoc комментарии
- Обновить CURRENT_STATUS.md

---

## 🛠 Полезные команды

```bash
# Запустить все тесты
flutter test test/animation/

# Запустить конкретный тест
flutter test test/animation/smil_test.dart

# Запустить тесты с verbose output
flutter test test/animation/ --reporter expanded

# Запустить example app
cd example && flutter run

# Проверить форматирование
dart format lib/ test/ example/lib/

# Проверить анализ
flutter analyze

# Обновить golden files
flutter test test/animation/ --update-goldens
```

---

## 📚 Ресурсы

### Документация:
- [ROADMAP.md](ROADMAP.md) - полный план
- [ANIMATION.md](ANIMATION.md) - user guide
- [ARCHITECTURE.md](ARCHITECTURE.md) - архитектура
- [VISUAL_TESTING_GUIDELINES.md](VISUAL_TESTING_GUIDELINES.md) - testing guide

### Спецификации:
- [SMIL Animation Spec](https://www.w3.org/TR/smil-animation/)
- [SVG Animation Spec](https://www.w3.org/TR/SVG11/animate.html)

### Исходники Blink:
- `blink-b87d44f-Source-core-svg/animation/` - SMIL implementation
- `blink-b87d44f-Source-core-svg/README.md` - обзор модуля

---

## ✅ Чеклист перед коммитом

- [ ] Все тесты проходят (`flutter test test/animation/`)
- [ ] Код отформатирован (`dart format`)
- [ ] Нет ошибок анализа (`flutter analyze`)
- [ ] Добавлены dartdoc комментарии
- [ ] Добавлены тесты для нового кода
- [ ] Обновлена документация
- [ ] Добавлен пример в example app (если применимо)

---

## 🎯 Метрики успеха

После каждой задачи проверяй:
- ✅ Все тесты проходят
- ✅ Производительность не ухудшилась
- ✅ Example app показывает новую фичу
- ✅ Документация обновлена

---

**Удачи! 🚀**

Начни с ЗАДАЧИ #1 (autoPlay: false bug) - это самое быстрое и критичное.
