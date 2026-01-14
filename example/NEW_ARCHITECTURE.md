# Example App - Новая архитектура

## Обзор

Полностью переработанное example приложение с чистым кодом, простым state management и максимальной переиспользуемостью компонентов.

## Структура проекта

```
example/lib/
├── main.dart                           # Точка входа
├── state/
│   └── app_state.dart                 # State management (ChangeNotifier)
├── models/
│   └── svg_example.dart               # Модель примера SVG
├── data/
│   └── examples_data.dart             # Коллекция всех примеров
├── pages/
│   └── examples_page.dart             # Главная страница
└── widgets/
    ├── animated_svg_viewer.dart       # Просмотрщик SVG с параметрами
    ├── parameters_panel.dart          # Панель настройки параметров
    └── fps_monitor.dart               # FPS монитор
```

## Основные компоненты

### 1. State Management (`app_state.dart`)

Простой ChangeNotifier для управления состоянием:

**Параметры AnimatedSvgPicture:**
- `width` / `height` - размеры виджета
- `fit` - BoxFit (contain, cover, fill, etc.)
- `alignment` - выравнивание (topLeft, center, etc.)
- `backgroundColor` - фоновый цвет
- `playbackRate` - скорость воспроизведения (0.1 - 5.0x)
- `autoPlay` - автоматический старт
- `initialTime` - начальное время

**UI параметры:**
- `showFPS` - показать FPS монитор
- `showParameters` - показать панель параметров
- `selectedExampleIndex` - текущий пример

### 2. Модель данных (`svg_example.dart`)

```dart
class SvgExample {
  final String id;
  final String title;
  final String description;
  final String svgContent;
  final IconData icon;
  final String category;
  final List<String> tags;
}
```

**Категории:**
- Basic - базовые анимации (движение, пульсация, затухание)
- Transform - трансформации (rotation, translate, scale)
- Color - цветовые анимации
- Path - морфинг путей
- Motion - движение по пути (animateMotion)
- Advanced - сложные комбинации

### 3. Примеры (`examples_data.dart`)

**13+ готовых примеров:**

**Basic:**
- Moving Rectangle - горизонтальное движение
- Pulsing Circle - пульсирующий круг
- Fading Square - затухание прозрачности

**Transform:**
- Rotating Square - вращение
- Bouncing Ball - перемещение с easing
- Scaling Heart - масштабирование

**Color:**
- Rainbow Circle - радужная заливка
- Colorful Border - цветная обводка

**Path:**
- Square to Circle - морфинг квадрата в круг
- Star to Pentagon - морфинг звезды

**Motion:**
- Circle Path - движение по кругу
- Car on Track - автомобиль с авто-поворотом

**Advanced:**
- Animated Clock - часы с несколькими стрелками
- Loading Spinner - спиннер загрузки

### 4. Виджеты

**AnimatedSvgViewer** - показывает AnimatedSvgPicture с текущими параметрами из AppState

**ParametersPanel** - интерактивная панель:
- Слайдеры для width/height/playbackRate
- Переключатель autoPlay
- Dropdown для fit/alignment
- Цветовые чипы для backgroundColor
- Кнопка сброса к дефолтным значениям

**FPSMonitor** - мониторинг производительности:
- Текущий FPS
- График истории (60 кадров)
- Цветовая индикация (зеленый >55, оранжевый >30, красный <30)

### 5. Главная страница (`examples_page.dart`)

**Desktop layout:**
- Левая панель (280px) - список примеров по категориям
- Центральная область - SVG с описанием и тегами
- Правая панель (320px) - параметры (опционально)

**Mobile layout:**
- Горизонтальный скролл примеров сверху
- Центральная область - SVG
- Сворачиваемая панель параметров снизу

## Использование

### Добавление нового примера

```dart
// В examples_data.dart
SvgExample(
  id: 'my_example',
  title: 'My Example',
  description: 'Description of my animation',
  category: ExampleCategory.basic,
  icon: Icons.animation,
  tags: ['animate', 'custom'],
  svgContent: '''
<svg viewBox="0 0 100 100">
  <!-- Your SVG here -->
</svg>
  ''',
),
```

### Добавление новой категории

```dart
// В svg_example.dart
class ExampleCategory {
  static const String myCategory = 'My Category';
}
```

### Управление состоянием

```dart
// Глобальный state доступен в main.dart
final _appState = AppState();

// Изменение параметров
state.setWidth(400);
state.setPlaybackRate(2.0);
state.toggleFPS();
state.resetToDefaults();
```

## Особенности реализации

### Адаптивный дизайн
- Брейкпоинт: 900px
- Mobile < 900: вертикальный layout
- Desktop ≥ 900: трехколоночный layout

### Performance
- ListenableBuilder для минимальных перерисовок
- FPS монитор с 60-frame буфером
- Оптимизированные слайдеры с divisions

### UX
- Визуальная обратная связь (выбранный пример)
- Цветовая индикация FPS
- Интуитивные иконки для категорий
- Теги для быстрого поиска функций

## Доступные параметры AnimatedSvgPicture

Все параметры доступны в интерактивной панели:

| Параметр | Тип | Диапазон | Описание |
|----------|-----|----------|----------|
| width | double | 100-600 | Ширина виджета |
| height | double | 100-600 | Высота виджета |
| fit | BoxFit | 7 вариантов | Как вписать SVG |
| alignment | Alignment | 9 позиций | Выравнивание |
| backgroundColor | Color? | 6 пресетов | Фон контейнера |
| playbackRate | double | 0.1-5.0 | Скорость анимации |
| autoPlay | bool | true/false | Автостарт |
| initialTime | Duration? | - | Начальное время |

## Команды разработки

```bash
# Запуск на macOS
cd example && flutter run -d macos

# Запуск на Chrome
cd example && flutter run -d chrome

# Запуск на iOS симуляторе
cd example && flutter run -d ios

# Hot reload
r

# Hot restart
R
```

## Архитектурные преимущества

✅ **Простота** - 5 файлов вместо 15+
✅ **Переиспользование** - все компоненты универсальны
✅ **Масштабируемость** - легко добавлять примеры
✅ **Чистота кода** - один паттерн для всех примеров
✅ **State management** - простой ChangeNotifier без зависимостей
✅ **Производительность** - минимальные перерисовки
✅ **UX** - адаптивный дизайн для mobile/desktop
✅ **Визуализация** - все параметры доступны в UI
