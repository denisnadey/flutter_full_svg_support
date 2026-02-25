# TODO - Animation Work Queue

**Last Updated:** February 21, 2026  
**Status Source:** `/Users/denisnadey/apps/flutter_full_svg_support/CURRENT_STATUS.md`

This file tracks actionable implementation tasks.
For factual project status, use `CURRENT_STATUS.md` only.

## Completed Recently

- [x] Element-level hit-testing for event timing (`click/mouseover/mouseout`) on `rect/circle/ellipse/line`
- [x] Target-specific event parser support (`id.click`)
- [x] SVG Playground with runtime traces/logs/problems/checklist
- [x] Runtime trace callback API in `AnimatedSvgPicture`
- [x] `<polygon>` and `<polyline>` rendering + hit-testing
- [x] `<path>` hit-testing for element-targeted events (`target.click`)
- [x] Gradient paint servers (`<linearGradient>`, `<radialGradient>`, `<stop>`) for fill/stroke
- [x] Baseline `<use href="#...">` + `<defs>` reference rendering
- [x] Baseline `<symbol>` rendering via `<use>` (`viewBox` + `use width/height`)
- [x] Baseline `<clipPath>` support
- [x] Baseline `<mask>` support
- [x] Filter primitives: `feFlood`, `feBlend`, `feComposite` (baseline approximation)
- [x] Baseline `feMerge`/`feMergeNode` parsing support
- [x] `animateMotion` path reference support via `<mpath href="#...">` / `<mpath xlink:href="#...">`
- [x] Baseline `<text>` / `<tspan>` rendering and text-target hit-testing
- [x] Baseline `<textPath>` rendering (`href`/`xlink:href`, `startOffset`) and hit-testing
- [x] Baseline `<image>` rendering (`href`/`xlink:href`, data URI decoding) and image-target hit-testing
- [x] Baseline use-referenced and `clipPath`/`mask`-aware hit-testing improvements
- [x] CSS->SMIL parity block: baseline CSS transform normalization + `cubic-bezier`->`keySplines` + `alternate*` direction runtime behavior
- [x] Full parser color formats: `rgb/rgba/hsl/hsla` and hex alpha variants (`#RGBA`, `#RRGGBBAA`)
- [x] Filter composition baseline upgrade: `feDropShadow` source+shadow multi-pass and `feMerge` named-result multi-pass resolution
- [x] Baseline `<foreignObject>` viewport support (`x/y` offset + clip) with aligned child hit-testing semantics

## P0 - Blink Parity Foundations

- [x] Implement actual `<path>` painting in animated renderer.
- [x] Add `<polygon>` and `<polyline>` rendering.
- [x] Add gradient paint servers (`<linearGradient>`, `<radialGradient>`, `<stop>`).
- [x] Add `<use>`/`<symbol>` + `<defs>` baseline reference resolution.
- [x] Add baseline `<clipPath>` support.
- [x] Add baseline `<mask>` support.

## P1 - Core Feature Gaps

- [ ] Complete text pipeline parity (`<text>`, `<tspan>`, `<textPath>` advanced semantics).
- [ ] Extend `<foreignObject>` parity beyond baseline viewport/container semantics.
- [x] Add `animateMotion` support for `<mpath xlink:href="...">` references.
- [ ] Expand element hit-testing to advanced semantics (`clipPath`/`mask`/`use`/text-aware hit regions).

## P2 - Filters (Blink FE coverage)

- [ ] Extend `feDropShadow` to advanced parity semantics beyond source-based composition paths.
- [x] Implement `feOffset`.
- [x] Implement `feBlend`.
- [x] Implement `feComposite`.
- [x] Implement `feFlood`.
- [x] Implement baseline `feMerge` / `feMergeNode` parsing.
- [ ] Extend `feMerge` / `feMergeNode` to advanced non-source input-graph composition semantics.
- [ ] Evaluate and prioritize remaining FE primitives from Blink list.

## P3 - CSS/Timing Parity

- [x] CSS `transform` parsing in CSS->SMIL converter.
- [x] CSS `cubic-bezier(...)` to spline conversion.
- [x] CSS direction `alternate` / `alternate-reverse`.
- [x] Full color parsing parity (`rgb/rgba/hsl/hsla` in parser path).

## P4 - Quality

- [ ] Add parity regression suite based on Blink-style fixtures.
- [ ] Reduce analyzer info-level deprecations in package/example/tests.
- [ ] Add performance benchmarks for new renderer coverage.
- [x] Add playground import of exported JSON report bundles.
- [x] Add playground analyzer/trace-store unit tests in `test/playground/**`.
- [ ] Add playground widget tests for log filters/search and problem grouping UI behavior.

## Notes

- Full Blink parity reference and scope are documented in:  
  `/Users/denisnadey/apps/flutter_full_svg_support/docs/BLINK_PARITY_AUDIT.md`
