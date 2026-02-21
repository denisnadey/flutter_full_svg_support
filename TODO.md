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

## P0 - Blink Parity Foundations

- [x] Implement actual `<path>` painting in animated renderer.
- [x] Add `<polygon>` and `<polyline>` rendering.
- [x] Add gradient paint servers (`<linearGradient>`, `<radialGradient>`, `<stop>`).
- [x] Add `<use>`/`<symbol>` + `<defs>` baseline reference resolution.
- [x] Add baseline `<clipPath>` support.
- [x] Add baseline `<mask>` support.

## P1 - Core Feature Gaps

- [ ] Add text pipeline (`<text>`, `<tspan>`, `<textPath>` at minimum baseline).
- [ ] Add `<image>` support in animated pipeline.
- [x] Add `animateMotion` support for `<mpath xlink:href="...">` references.
- [ ] Expand element hit-testing to advanced semantics (`clipPath`/`mask`/`use`/text-aware hit regions).

## P2 - Filters (Blink FE coverage)

- [ ] Improve `feDropShadow` to full composition behavior.
- [x] Implement `feOffset`.
- [x] Implement `feBlend`.
- [x] Implement `feComposite`.
- [x] Implement `feFlood`.
- [x] Implement baseline `feMerge` / `feMergeNode` parsing.
- [ ] Upgrade `feMerge` / `feMergeNode` to full input-graph composition semantics.
- [ ] Evaluate and prioritize remaining FE primitives from Blink list.

## P3 - CSS/Timing Parity

- [ ] CSS `transform` parsing in CSS->SMIL converter.
- [ ] CSS `cubic-bezier(...)` to spline conversion.
- [ ] CSS direction `alternate` / `alternate-reverse`.
- [ ] Full color parsing parity (`rgb/rgba/hsl/hsla` in parser path).

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
