# Unified Examples System

## Обзор

Создана единая система примеров с вкладками, FPS-мониторингом и унифицированным дизайном.

## Архитектура

### 1. Главная Страница (`UnifiedExamplesPage`)

**Файл**: `example/lib/pages/unified_examples_page.dart`

#### Функции:
- **Вкладки (TabBar)**: 4 категории примеров
  1. SMIL Animations - базовые SMIL анимации
  2. Path Morphing - морфинг путей
  3. Metrics - демо с метриками
  4. Custom - пользовательские примеры

- **FPS Monitor**: Встроенный монитор производительности
  - Показывает текущий FPS
  - График FPS за последние 60 кадров
  - Цветовая индикация (зеленый ≥55, оранжевый ≥30, красный <30)
  - Счетчик кадров
  - Переключается кнопкой в AppBar

- **Плавающий FPS виджет**: Позиционируется поверх контента

### 2. Переиспользуемые Виджеты

#### PathMorphingWidget
**Файл**: `example/lib/widgets/path_morphing_widget.dart`

**Примеры:**
- Square ↔ Circle
- Star ↔ Heart  
- Triangle ↔ Hexagon

**Функции:**
- Segmented button для выбора примера
- Интерполяция цвета
- AnimationController с воспроизведением/паузой
- Использует AnimationControlPanel

#### MetricsWidget
**Файл**: `example/lib/widgets/metrics_widget.dart`

**Функции:**
- Отображение SVG анимации
- Панель с метриками (элементы, анимации, длительность)
- Подсказка об использовании FPS monitor

### 3. Унифицированная Тема

**AnimationTheme** (`example/lib/widgets/animation_theme.dart`)

#### Константы:
```dart
// Colors
primaryColor = Color(0xFF2196F5)
secondaryColor = Color(0xFF4CAF50)

// Spacing
spacingSmall = 8.0
spacingMedium = 16.0
spacingLarge = 24.0
spacingXLarge = 32.0

// Border Radius
radiusSmall = 8.0
radiusMedium = 12.0
radiusLarge = 16.0

// Size Constraints
animationDisplayMinHeight = 300.0
animationDisplayMaxWidth = 600.0
controlPanelMinHeight = 180.0
```

#### Компоненты:
- **AnimationControlPanel**: Панель управления с progress slider, кнопками play/pause/reset
- **AnimationExampleLayout**: Обертка для страниц примеров
- **getLightTheme()**: Светлая тема
- **getDarkTheme()**: Темная тема

### 4. FPS Monitor

**Компоненты:**
- `FPSMonitor` widget - основной виджет
- `_FPSMonitorState` - состояние с расчетом FPS
- `_FPSGraphPainter` - рисование графика

**Метрики:**
- Текущий FPS (среднее за 60 кадров)
- График истории FPS
- Счетчик кадров
- Цветовая индикация производительности

**Технические детали:**
```dart
// Расчет FPS
fps = 1000000 / deltaTime.inMicroseconds

// Хранение истории
_fpsHistory (max 60 значений)

// Цвета
green: fps >= 55
orange: fps >= 30 && fps < 55
red: fps < 30
```

## Структура Файлов

```
example/lib/
├── main.dart (обновлен - использует AnimationTheme)
├── pages/
│   ├── home_page.dart (обновлен - один путь к UnifiedExamplesPage)
│   └── unified_examples_page.dart (НОВЫЙ - главная страница с вкладками)
├── widgets/
│   ├── animation_theme.dart (существующий - унифицированная тема)
│   ├── path_morphing_widget.dart (НОВЫЙ - виджет морфинга)
│   └── metrics_widget.dart (НОВЫЙ - виджет метрик)
└── l10n/
    └── app_localizations.dart (обновлен - добавлены строки)
```

## Использование

### Запуск приложения:

```bash
cd example
flutter run
```

### Навигация:

1. Главная страница → кнопка "View Examples"
2. Откроется UnifiedExamplesPage с вкладками
3. Нажмите иконку скорости (справа вверху) для FPS monitor
4. Переключайтесь между вкладками для разных примеров

### Добавление нового примера:

**Вариант 1: Новая вкладка**

```dart
// В UnifiedExamplesPage добавить:
TabController(length: 5, vsync: this) // увеличить count

Tab(
  icon: const Icon(Icons.your_icon),
  text: 'Your Tab',
)

// Создать новый Tab виджет
class _YourTab extends StatelessWidget {
  const _YourTab({required this.showFPS});
  final bool showFPS;
  
  @override
  Widget build(BuildContext context) {
    return YourWidget();
  }
}
```

**Вариант 2: Добавить в существующий виджет**

```dart
// Например, в PathMorphingWidget добавить новый пример:
_MorphingExample(
  name: 'Your Shape',
  path1: 'M...',
  path2: 'M...',
  color1: Colors.color1,
  color2: Colors.color2,
)
```

## Преимущества

### 1. Единый стиль
- Все примеры используют AnimationTheme
- Консистентные цвета, отступы, радиусы
- Light/Dark mode support

### 2. FPS Monitoring
- Встроен во все вкладки
- Не требует отдельной страницы
- Реальное время, визуальный график

### 3. Организация
- Вкладки вместо множества страниц
- Легко добавлять новые примеры
- Переиспользуемые компоненты

### 4. UX
- Быстрое переключение между примерами
- Одна точка входа
- Понятная навигация

### 5. Производительность
- FPS graph показывает плавность
- Легко тестировать разные примеры
- Визуальная обратная связь

## Локализация

Добавлены новые строки в `app_localizations.dart`:

**English:**
- `smil_animations`: "SMIL Animations"
- `metrics`: "Metrics"

**Russian:**
- `smil_animations`: "SMIL Анимации"
- `metrics`: "Метрики"

## Технические Детали

### FPS Calculation

```dart
void _onFrame(Duration timestamp) {
  if (_lastFrameTime != Duration.zero) {
    final delta = timestamp - _lastFrameTime;
    final fps = 1000000 / delta.inMicroseconds;
    
    // Add to history (max 60)
    _fpsHistory.add(fps);
    if (_fpsHistory.length > 60) {
      _fpsHistory.removeAt(0);
    }
  }
  _lastFrameTime = timestamp;
  SchedulerBinding.instance.addPostFrameCallback(_onFrame);
}
```

### FPS Graph Painter

```dart
class _FPSGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final maxFPS = 60.0;
    final stepX = size.width / (history.length - 1);
    
    for (int i = 0; i < history.length; i++) {
      final x = i * stepX;
      final y = size.height - (history[i] / maxFPS * size.height);
      // Draw line path
    }
    
    // Draw filled area + line + 60fps reference
  }
}
```

### Theme Application

```dart
// main.dart
MaterialApp(
  theme: AnimationTheme.getLightTheme(),
  darkTheme: AnimationTheme.getDarkTheme(),
  themeMode: ThemeMode.system,
)
```

## Следующие Шаги

### Возможные улучшения:

1. **Больше примеров**
   - AnimateMotion examples
   - Complex path morphing
   - Color animations showcase

2. **Расширенные метрики**
   - Memory usage
   - Paint time
   - Build time

3. **Сохранение настроек**
   - FPS monitor on/off state
   - Последняя выбранная вкладка
   - Theme preference

4. **Export/Share**
   - Screenshot текущей анимации
   - Экспорт SVG кода
   - Share examples

5. **Performance Profiling**
   - Detailed frame timeline
   - Jank detection
   - Optimization suggestions

## Статус

- ✅ Создана UnifiedExamplesPage с вкладками
- ✅ Интегрирован FPS Monitor
- ✅ Созданы переиспользуемые виджеты
- ✅ Применена единая тема
- ✅ Обновлена локализация
- ✅ Подключены все примеры
- ✅ Все файлы компилируются без ошибок

## Тестирование

```bash
# Analyze
cd example
flutter analyze

# Run
flutter run -d macos

# Test FPS Monitor
# 1. Открыть примеры
# 2. Нажать иконку speed
# 3. Проверить отображение FPS
# 4. Переключить вкладки
# 5. Проверить что FPS обновляется
```

---

**Дата**: 21 ноября 2025  
**Статус**: ✅ Завершено  
**Файлов создано**: 3  
**Файлов обновлено**: 3  
**Строк кода**: ~700
