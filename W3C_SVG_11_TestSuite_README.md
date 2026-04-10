# W3C SVG 1.1 Test Suite в этом репозитории

## Что это такое

`W3C_SVG_11_TestSuite` — это официальный набор тестов SVG 1.1 (2nd Edition) от W3C.
Он предназначен для проверки соответствия рендера спецификации: геометрия, градиенты, фильтры, текст, анимации, маски, `use`, DOM/скрипты и т.д.

В этой копии у нас есть:

- `W3C_SVG_11_TestSuite/svg` — исходные SVG тесты (525 файлов)
- `W3C_SVG_11_TestSuite/png` — эталонные PNG (544 файлов)
- `W3C_SVG_11_TestSuite/harness/*` — HTML-обвязка для запуска тестов в браузере
- `W3C_SVG_11_TestSuite/resources/*` — шрифты и вспомогательные ресурсы

По `harness` видно:

- Все тесты: 526 (`harness/htmlObject/index.html`)
- Approved subset: 433 (`harness/htmlObjectApproved/index.html`)
- В `harness/index.html` указана дата набора: **15 Jul 2011**

## Почему это полезно для нашего проекта

Ваш текущий сценарий сравнивает скриншоты **Flutter SVG рендера** с **браузерным рендером**.
Этот набор идеально подходит как большой источник реальных спецификационных кейсов для такого сравнения.

Что дает suite:

- Широкое покрытие edge-cases, которых нет в hand-made фикстурах
- Единые имена кейсов и категории (`coords`, `filters`, `masking`, `text`, `animate`, ...)
- Готовые reference PNG (можно использовать как дополнительный oracle)
- Метаданные в каждом SVG: `testDescription`, `passCriteria`, `operatorScript`

## Важные ограничения перед интеграцией

- Текущий `tool/golden_capture/capture.js` встраивает SVG inline через `page.setContent(...)`.
- Для W3C это риск: многие тесты используют относительные ссылки (`../resources/...`, `../images/...`), и inline-режим ломает базовый путь.
- Текстовые тесты будут нестабильны в Flutter test среде из-за Ahem font (это уже отражено в текущих golden тестах).
- Тесты с `script`/DOM-events/interaction плохо подходят для стабильного headless baseline.
- Для анимаций нужно фиксировать timestamp (например, `0ms` или заданный момент), иначе результат недетерминирован.

Дополнительно по локальной копии:

- `W3C_SVG_11_TestSuite/status` отсутствует
- `W3C_SVG_11_TestSuite/archives` отсутствует
- `harness/*` ссылается на `../resources/testharnessreport.js`, но `harness/resources` в копии нет

Это не мешает использовать `svg` и `png` для нашей задачи, но важно для запуска оригинального harness 1-в-1.

## Как использовать в нашем screenshot testing

Рекомендуемый путь:

1. Брать кейсы из `harness/htmlObjectApproved/index.html` как стартовый набор.
2. Рендерить их в Chrome/Puppeteer через локальный HTTP-server (не inline), чтобы работали относительные ресурсы.
3. Сохранять browser baseline в отдельный namespace, например `test/goldens/w3c/browser/`.
4. Рендерить те же SVG через Flutter (`AnimatedSvgPicture.string`) в `test/goldens/w3c/flutter/`.
5. Сравнивать текущим `tool/golden_capture/image_compare.dart` и писать diff в `test/goldens/w3c/diff/`.
6. Держать явный manifest кейсов (threshold, skip reason, категория, tier для CI).

## Быстрый ручной просмотр suite

```bash
cd /Users/denisnadey/apps/flutter_full_svg_support
python3 -m http.server 8000
```

Открыть в браузере:

- `http://localhost:8000/W3C_SVG_11_TestSuite/harness/index.html`
- или конкретный тест, например `.../harness/htmlObjectApproved/coords-trans-01-b.html`

## Что читать дальше

Подробный поэтапный план внедрения сохранен в:

- `W3C_SVG_11_TestSuite_PLAN_README.md`

Текущая рабочая реализация tooling находится в:

- `tool/w3c_goldens/README.md`
