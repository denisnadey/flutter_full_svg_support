# TODO - Animation Work Queue

**Last Updated:** March 12, 2026  
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
- [x] Filter primitive: `feTile` baseline graph pass-through support
- [x] Filter primitive: `feMorphology` baseline (`erode`/`dilate`) support
- [x] Filter primitive: `feDisplacementMap` baseline graph pass-through support
- [x] `feDisplacementMap` semantics increment: `scale=0` identity behavior ignores unresolved explicit `in2`
- [x] `feDisplacementMap` semantics increment: explicit `in2="none"` (case-insensitive) is treated as transparent map input and does not collapse output chain
- [x] Filter graph semantics: `feBlend` / `feComposite` explicit `in2="none"` (case-insensitive) is treated as transparent input (no unresolved collapse)
- [x] Filter graph semantics: `feComposite operator="arithmetic"` (`k2+k3`) with explicit `in2="none"` preserves additive top-input approximation
- [x] Filter primitive: `feImage` baseline graph pass-through support
- [x] Filter primitive: `feConvolveMatrix` baseline graph pass-through support
- [x] Filter primitive: `feTurbulence` baseline graph pass-through support
- [x] Filter primitive: `feComponentTransfer` baseline graph pass-through support
- [x] Filter primitive: `feDiffuseLighting` baseline graph pass-through support
- [x] Filter primitive: `feSpecularLighting` baseline graph pass-through support
- [x] Filter graph semantics: baseline `in2` layering for `feBlend` / `feComposite` (non-arithmetic)
- [x] Lighting primitives: parse `x/y/width/height` and `kernelUnitLength` for `feDiffuseLighting` / `feSpecularLighting`
- [x] Filter graph semantics: `feImage` non-source baseline (`href` without `in` starts independent placeholder output)
- [x] Filter graph semantics: baseline background input routing (`BackgroundImage` -> source placeholder, `BackgroundAlpha` -> source alpha placeholder)
- [x] Filter graph semantics: `feMerge` explicit unresolved/forward `feMergeNode in` inputs skip previous fallback (implicit missing `in` still uses previous-chain semantics)
- [x] Filter graph semantics: explicit `in="none"` resolves as empty input (no previous-output fallback) including `feMergeNode` flow
- [x] Filter graph semantics: non-merge explicit unresolved `in`/`in2` inputs are skipped (no fallback to previous)
- [x] Filter graph semantics: `feComposite operator="arithmetic"` baseline approximations (`k3-only` => `in2`, `k2+k3` => additive layering, all-zero => transparent output)
- [x] Filter graph semantics: built-in inputs (`Source*`, `Background*`, `FillPaint`, `StrokePaint`) resolve case-insensitively
- [x] Filter graph semantics: `FillPaint` / `StrokePaint` consume element paint context in animated painter flow (solid-color baseline approximation + source fallback)
- [x] Filter graph semantics: `FillPaint` / `StrokePaint` fallback preserves paint-channel scope for paint-server sources (fill-only / stroke-only source masking)
- [x] Filter graph semantics: `feDropShadow` shadow passes preserve input paint-channel scope (`FillPaint` / `StrokePaint`)
- [x] Parser semantics: `feDropShadow` supports inline `style` fallback/override for `dx`/`dy`/`stdDeviation`/`flood-color`/`flood-opacity` (`!important` normalized)
- [x] Filter graph semantics: `BackgroundImage` / `BackgroundAlpha` consume optional source context passes with source-placeholder fallback
- [x] Baseline `feMerge`/`feMergeNode` parsing support
- [x] `animateMotion` path reference support via `<mpath href="#...">` / `<mpath xlink:href="#...">`
- [x] Baseline `<text>` / `<tspan>` rendering and text-target hit-testing
- [x] Baseline `<textPath>` rendering (`href`/`xlink:href`, `startOffset`) and hit-testing
- [x] Text geometry parity increment: `letter-spacing` / `word-spacing` / `dominant-baseline` / `baseline-shift` in paint + hit-testing
- [x] Text length controls: `textLength` + `lengthAdjust` (`spacing`, `spacingAndGlyphs`) for `<text>` and `<textPath>` in paint + hit-testing
- [x] Baseline `<image>` rendering (`href`/`xlink:href`, data URI decoding) and image-target hit-testing
- [x] Baseline use-referenced and `clipPath`/`mask`-aware hit-testing improvements
- [x] Baseline `pointer-events` hit-testing semantics (`none` + descendant override)
- [x] `pointer-events` geometry mode increment for hit-testing (`fill`, `stroke`, `painted`, `all`, `bounding-box`)
- [x] `pointer-events` text-mode increment for hit-testing (`text`/`tspan`/`textPath` respect `fill`/`stroke`/`visible*` semantics)
- [x] CSS->SMIL parity block: baseline CSS transform normalization + `cubic-bezier`->`keySplines` + `alternate*` direction runtime behavior
- [x] Full parser color formats: `rgb/rgba/hsl/hsla` and hex alpha variants (`#RGBA`, `#RRGGBBAA`)
- [x] Filter composition baseline upgrade: `feDropShadow` source+shadow multi-pass and `feMerge` named-result multi-pass resolution
- [x] Baseline `<foreignObject>` viewport support (`x/y` offset + clip) with aligned child hit-testing semantics
- [x] Inline `style` fallback support for `clip-path` / `mask` / `filter` in painted output and clip/mask-aware hit-testing gates
- [x] Inline `style` normalization increment: trailing `!important` is respected for `filter`/`clip-path`/`mask`/`display` paths in paint + hit-testing
- [x] `feBlend` mode parsing parity increment: extended SVG2 blend modes (`color-dodge`/`color-burn`/`hard-light`/`soft-light`/`difference`/`exclusion`/`hue`/`saturation`/`color`/`luminosity`)
- [x] Painting parity increment: inherited `visibility` semantics for descendants (`visibility:hidden` on ancestor suppresses paint unless child overrides)

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
- [x] Implement `feMorphology` (`erode`/`dilate` baseline).
- [x] Implement `feDisplacementMap` (baseline graph pass-through).
- [x] Implement `feImage` (baseline graph pass-through + source attribute parsing).
- [x] Implement `feConvolveMatrix` (baseline graph pass-through + kernel attribute parsing).
- [x] Implement `feTurbulence` (baseline graph pass-through + noise attribute parsing).
- [x] Implement `feComponentTransfer` (baseline graph pass-through + channel-function parsing).
- [x] Implement `feDiffuseLighting` (baseline graph pass-through + light-source parsing).
- [x] Implement `feSpecularLighting` (baseline graph pass-through + light-source parsing).
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
- [x] Add playground widget tests for log filters/search and problem grouping UI behavior.

## Notes

- Full Blink parity reference and scope are documented in:  
  `/Users/denisnadey/apps/flutter_full_svg_support/docs/BLINK_PARITY_AUDIT.md`
