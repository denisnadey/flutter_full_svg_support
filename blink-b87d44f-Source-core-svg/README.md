# Blink SVG Core Module

## Описание проекта

Это модуль **SVG (Scalable Vector Graphics)** из движка рендеринга **Blink** - открытого браузерного движка, используемого в Google Chrome, Chromium, Opera и других браузерах на основе Chromium.

Данная директория содержит исходный код ядра (core) для обработки и рендеринга SVG-контента в веб-браузере. Код является частью проекта WebKit/Blink и написан на C++.

## Что такое Blink?

**Blink** - это форк браузерного движка WebKit, разработанный Google. Он отвечает за:
- Парсинг HTML/SVG/XML
- Применение CSS стилей
- Отрисовку веб-страниц
- Выполнение JavaScript через V8

## Структура проекта

### Основные компоненты

#### 1. **SVG Elements (Элементы SVG)** (~165 .cpp файлов)
Реализация всех SVG элементов согласно спецификации W3C:

**Базовые формы:**
- `SVGCircleElement` - круги
- `SVGRectElement` - прямоугольники
- `SVGEllipseElement` - эллипсы
- `SVGLineElement` - линии
- `SVGPolygonElement`, `SVGPolylineElement` - многоугольники
- `SVGPathElement` - пути (самый сложный элемент)

**Контейнеры и группировка:**
- `SVGSVGElement` - корневой элемент SVG документа
- `SVGGElement` - группы элементов
- `SVGDefsElement` - определения для повторного использования
- `SVGSymbolElement` - символы
- `SVGUseElement` - использование определенных элементов

**Текстовые элементы:**
- `SVGTextElement` - текст
- `SVGTSpanElement` - диапазоны текста
- `SVGTextPathElement` - текст вдоль пути

**Градиенты и паттерны:**
- `SVGLinearGradientElement` - линейные градиенты
- `SVGRadialGradientElement` - радиальные градиенты
- `SVGPatternElement` - паттерны заливки

**Фильтры (SVGFExxxElement):**
Более 20 элементов фильтров для графических эффектов:
- `SVGFEGaussianBlurElement` - размытие
- `SVGFEBlendElement` - смешивание
- `SVGFEColorMatrixElement` - цветовые преобразования
- `SVGFEDropShadowElement` - тени
- И множество других эффектов

**SVG Fonts:**
- `SVGFontElement`, `SVGGlyphElement` - поддержка SVG-шрифтов
- `SVGFontFaceElement` - метаданные шрифтов

#### 2. **Animation (Анимация)**
Директория `animation/`:
- `SVGSMILElement` - базовый класс для SMIL-анимаций
- `SMILTimeContainer` - контейнер временной шкалы
- `SVGAnimateElement` - анимация атрибутов
- `SVGAnimateTransformElement` - анимация трансформаций
- `SVGAnimateMotionElement` - анимация движения по пути
- `SVGAnimateColorElement` - анимация цвета

#### 3. **Animated Properties (Анимируемые свойства)**
Директория `properties/`:
- Система для работы с анимируемыми SVG-атрибутами
- `SVGAnimatedProperty` - базовый класс
- Различные типы свойств: Length, Number, String, Transform, Path и др.

#### 4. **Graphics (Графика)**
Директория `graphics/`:
- `SVGImageChromeClient` - интеграция SVG изображений с браузером

#### 5. **Data Types (Типы данных)**
Типы данных SVG:
- `SVGLength` - длины (px, em, %, и др.)
- `SVGAngle` - углы
- `SVGNumber` - числа
- `SVGTransform` - трансформации
- `SVGColor`, `SVGPaint` - цвета и заливки
- `SVGPreserveAspectRatio` - сохранение пропорций

#### 6. **Path Processing (Обработка путей)**
Мощная система для работы с SVG путями:
- `SVGPathParser` - парсинг path команд
- `SVGPathBuilder` - построение путей
- `SVGPathBlender` - смешивание путей (для анимации)
- `SVGPathByteStream` - оптимизированное представление
- `SVGPathUtilities` - утилиты для работы с путями

#### 7. **Attribute Processing (Обработка атрибутов)**
- `svgtags.in` - определения всех SVG тегов (99+ элементов)
- `svgattrs.in` - определения всех SVG атрибутов (252+ атрибута)
- `xlinkattrs.in` - XLink атрибуты

## Технические детали

### Языки программирования
- **C++** - основной язык реализации
- **IDL (Web IDL)** - описание JavaScript API для SVG элементов
- **Build Scripts** - конфигурационные файлы (.in)

### Статистика кода
- **~165** файлов реализации (.cpp)
- **~376** заголовочных файлов и IDL файлов (.h, .idl)
- Тысячи строк кода

### Namespace
Весь код находится в namespace `WebCore`.

### Лицензии
Проект содержит код под двумя лицензиями:
1. **BSD License** (3-clause) - код от Apple, Google
2. **GNU LGPL v2+** - код от KDE contributors (Nikolas Zimmermann, Rob Buis)

### Основные copyright holders:
- Apple Inc.
- Google Inc.
- Nikolas Zimmermann (KDE)
- Rob Buis (KDE)
- И другие контрибьюторы

## Архитектурные особенности

### 1. Интеграция с браузерным движком
- Использует систему DOM (Document Object Model)
- Интеграция с CSS для стилизации
- Поддержка JavaScript через V8 bindings
- Рендеринг через систему RenderObject

### 2. Animated Properties System
Продвинутая система для анимации любых SVG атрибутов:
```cpp
DEFINE_ANIMATED_LENGTH(SVGSVGElement, SVGNames::widthAttr, Width, width)
```

### 3. Оптимизация производительности
- Byte stream для путей (компактное представление)
- Ленивые вычисления
- Кэширование трансформаций

## Применение

Этот код используется в:
- **Google Chrome** / Chromium
- **Opera** (версии на Chromium)
- **Microsoft Edge** (новые версии на Chromium)
- **Brave Browser**
- И других браузерах на основе Blink

## SVG возможности

Модуль поддерживает полную спецификацию SVG 1.1 и частично SVG 2.0:
- ✅ Базовые формы и пути
- ✅ Текст и шрифты
- ✅ Градиенты и паттерны
- ✅ Фильтры и эффекты
- ✅ Клиппинг и маскирование
- ✅ SMIL анимации
- ✅ Трансформации
- ✅ Интерактивность (события)

## Разработка

### Требования для сборки
Для компиляции этого модуля требуется полная сборочная среда Chromium/Blink:
- Компилятор C++ (Clang предпочтителен)
- Python (для build scripts)
- depot_tools от Google
- Все зависимости Chromium

### Важные файлы
- `SVGElement.cpp/h` - базовый класс для всех SVG элементов
- `SVGSVGElement.cpp/h` - корневой `<svg>` элемент
- `SVGDocument.cpp/h` - SVG документ
- `SVGDocumentExtensions.cpp/h` - расширения для работы с SVG

## Историческая справка

Код изначально был частью WebKit (движок Safari), затем был форкнут Google в 2013 году для создания Blink. Видны следы истории в copyright notices - код от Apple, KDE (KHTML), и более поздние изменения от Google.

## Связанные технологии

- **WebKit** - оригинальный проект
- **V8** - JavaScript движок
- **Skia** - 2D графическая библиотека для рендеринга
- **CSS** - стилизация SVG элементов

## Примечание

Это не standalone проект - он является частью огромной кодовой базы Chromium и не может быть скомпилирован отдельно без соответствующей инфраструктуры сборки.

---

**Версия:** Snapshot из исходников Blink (build b87d44f)  
**Дата:** 2026  
**Лицензия:** BSD & LGPL (см. заголовки файлов)
