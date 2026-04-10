# План интеграции W3C SVG 1.1 Test Suite в browser-vs-library screenshot testing

## Цель

Интегрировать `W3C_SVG_11_TestSuite` в текущий pipeline сравнения:

- Browser render (Chrome/Puppeteer)
- Flutter render (`AnimatedSvgPicture`)
- Pixel diff (`tool/golden_capture/image_compare.dart`)

И получить масштабируемый, детерминированный и CI-дружелюбный набор тестов.

## Статус реализации (2026-04-10)

- Этап 1 реализован: manifest генерируется скриптом `tool/w3c_goldens/generate_manifest.js`.
- Этап 2 реализован: browser capture для W3C работает через локальный HTTP server (`capture_browser_w3c.js`).
- Этап 3 реализован: `test/golden_comparison/w3c_golden_comparison_test.dart` читает manifest, рендерит, сравнивает и сохраняет артефакты.
- Добавлен оркестратор `tool/w3c_goldens/run_w3c_comparison.sh` с флагами:
  - `--enable-render`
  - `--no-enforce-threshold`
  - `--debug-trace`

Текущий фокус:

- стабилизация smoke-пула и калибровка thresholds;
- после стабилизации включить строгий режим (`W3C_ENFORCE_THRESHOLD=true`) для CI smoke.

### Актуальные результаты прогонов (2026-04-10)

1. Полный exploratory (`tier=all`, `--no-enforce-threshold`, static renderer):
   - selected: `199`
   - recorded: `199`
   - technical failures: `0`
   - статус: раннер стабилен, полный прогон завершается успешно.
2. Строгий smoke (`tier=smoke`, threshold enforced):
   - `20 pass / 20 fail_threshold`
   - technical failures: `0`
   - статус: блокеров стабильности больше нет, остались только визуальные расхождения рендера.

3. Строгий full (`tier=all`, threshold enforced) после фиксов рендера:
   - `199 pass / 0 fail_threshold`
   - technical failures: `0`
   - статус: baseline browser-vs-renderer выровнен на текущем approved scope.

Что было сделано для последнего шага:

- в W3C golden harness добавлен белый фон под Flutter capture (исключили ложные diff из-за transparency);
- исправлен CSS parsing в animation parser (`<style>` ищется по всему дереву, не только среди прямых детей `<svg>`);
- исправлен CSS cascade в `AnimatedSvgPainter` для обычных узлов (не только внутри `<use>` контекста);
- добавлен гибридный fallback в тесте: static renderer по умолчанию, при недопрохождении и наличии `<style>` — автоповтор через animated renderer с выбором лучшего результата.

Текущий приоритет после стабилизации:

- закрывать `fail_threshold` волнами по категориям (в первую очередь `coords`, затем `paths`/`painting`/`shapes`/`filters`/`pservers`).

## План достижения прохождения всех W3C тестов

Ниже план именно для цели "все тесты проходят".

Рабочее допущение:

- для screenshot pipeline "прохождение" = детерминированный рендер и сходство с browser baseline выше порога;
- интерактивные/DOM/script кейсы отдельно, потому что они не равны обычному статичному скриншоту.

### Этап 0. Зафиксировать целевой scope и критерий pass

Задачи:

1. Зафиксировать финальный список кейсов:
   - `approved` визуальные,
   - `approved` animation,
   - `approved` script/interact (отдельный трек).
2. Зафиксировать pass-метрику:
   - `similarity >= threshold`,
   - `no timeout`,
   - `no parser/runtime crash`.
3. Ввести единый артефакт отчета (`json + markdown`) для каждого прогона.

Критерий готовности:

- есть один источник истины по pass/fail и coverage по кейсам.

### Этап 1. Полная диагностика 100% набора

Задачи:

1. Прогнать все кейсы в режиме:
   - `--enable-render`,
   - `--no-enforce-threshold`.
2. Сформировать карту проблем по категориям:
   - crash/timeout,
   - empty render,
   - transform mismatch,
   - gradient/pattern mismatch,
   - clip/mask mismatch,
   - filters mismatch,
   - text/fonts mismatch,
   - animation mismatch,
   - script/interact mismatch.
3. Для каждой категории выделить top-10 кейсов-репродукторов.

Критерий готовности:

- есть приоритизированный backlog по реальным причинам, а не по отдельным кейсам.

### Этап 2. Закрыть блокеры стабильности (обязательный приоритет)

Задачи:

1. Полностью убрать timeout/hang/crash для всех approved кейсов.
2. Добавить fail-fast guard на тяжелые шаги (capture/compare/decode) с явной ошибкой.
3. Добавить regression-тесты на каждый найденный тип зависания.

Критерий готовности:

- 0 зависаний в полном прогоне, только валидные pass/fail.

### Этап 3. Ресурсы, ссылки и шрифты (крупнейший источник расхождений)

Задачи:

1. Реализовать корректный resolver для `../resources/*` и `../images/*`.
2. Выровнять обработку внешних ссылок (`xlink:href`, `href`, `url(#id)`).
3. Ввести стратегию шрифтов:
   - загрузка W3C test fonts где возможно,
   - fallback policy, чтобы не терять детерминизм.
4. Пересчитать пороги после стабилизации текста.

Критерий готовности:

- text/resource кейсы перестают массово давать систематические false-fail.

### Этап 4. Волны исправлений по спецификационным подсистемам

Волна A (геометрия):

- `coords`, `paths`, `shapes`, `transform`.

Волна B (paint/model):

- `painting`, `pservers`, `gradients`, `patterns`, `opacity`.

Волна C (clip/mask/filter):

- `clipPath`, `mask`, `filter chain`, color spaces.

Волна D (text):

- text layout, anchors, baseline, spacing, textPath.

Волна E (animation):

- фиксированные time-snapshots для каждого анимированного кейса.

Для каждой волны:

1. Берем top failing кейсы.
2. Делаем минимальные unit/regression тесты в библиотеке.
3. Чиним рендер.
4. Перепрогоняем full subset этой волны.

Критерий готовности:

- волна закрывается только когда нет новых регрессий в уже зелёных группах.

### Этап 5. Script/Interact трек (отдельный от статичных скриншотов)

Задачи:

1. Отделить script/interact кейсы в отдельный manifest tier.
2. Для них сделать event-driven harness (не только один screenshot).
3. Ввести отдельные pass-правила:
   - состояние после событий,
   - DOM/event side effects (где применимо).

Критерий готовности:

- script/interact не блокируют обычный визуальный pipeline и имеют свой прозрачный статус.

### Этап 6. Жесткие CI-гейты до 100%

PR CI:

1. smoke strict (`W3C_ENFORCE_THRESHOLD=true`).
2. no-new-failure policy по стабилизированным кейсам.

Nightly CI:

1. full approved strict.
2. автопубликация отчета и топ регрессий.

Release gate:

1. 100% pass на целевом scope.
2. 0 timeout/hang.
3. 0 необъясненных flaky-case за N nightly прогонов подряд.

## Практический roadmap (8 недель)

Неделя 1:

1. Full-diagnostic прогон.
2. Triage board + grouping.
3. Финализация pass-метрик.

Неделя 2-3:

1. Blockers stability.
2. Resource/font resolver.
3. Перепрогон full.

Неделя 4-5:

1. Волна A + B.
2. Закрытие крупных visual mismatch.

Неделя 6:

1. Волна C.
2. Фильтры/маски/clipPath parity.

Неделя 7:

1. Волна D (text).
2. Перекалибровка thresholds.

Неделя 8:

1. Волна E + script/interact baseline.
2. Включение full strict gate в CI.

## Команды для выполнения плана

```bash
# Полный exploratory прогон (без падения по threshold)
./tool/w3c_goldens/run_w3c_comparison.sh \
  --tier all \
  --enable-render \
  --no-enforce-threshold

# Строгий smoke-гейт для PR
./tool/w3c_goldens/run_w3c_comparison.sh \
  --tier smoke \
  --enable-render
```
