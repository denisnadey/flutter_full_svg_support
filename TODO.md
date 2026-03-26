# TODO - Animation Work Queue

**Last Updated:** March 26, 2026  
**Status Source:** `/Users/denisnadey/apps/flutter_full_svg_support/CURRENT_STATUS.md`  
**Closed Issues Registry:** `/Users/denisnadey/apps/flutter_full_svg_support/docs/RESOLVED_ISSUES.md`

**Current Status:** ~74% Blink SVG parity | 3099 tests passing | 0 analyzer warnings

This file tracks actionable implementation tasks.
For factual project status, use `CURRENT_STATUS.md` only.

## Current Sprint (P0 - Active)

- [ ] **Light Sources** - Advanced feSpecularLighting/feDiffuseLighting light source positioning
- [ ] **Component Transfer** - Extended feComponentTransfer channel functions
- [ ] **Filter Input-Graph** - Advanced non-source/background input chain semantics
- [ ] **use/symbol Inheritance** - Style and attribute inheritance edge cases
- [ ] **Advanced Clipping** - Complex clip-path compositions and interactions
- [ ] **Advanced Masking** - Luminance masks and alpha channel handling
- [ ] **Advanced Typography** - Remaining text layout edge cases for full Blink parity

## Completed Recently

- [x] **SVG `<a>` anchor element**: Parse as container (like `<g>`), support `href`/`xlink:href`/`target` attributes, `onLinkTap` callback on widget with `SvgLinkInfo`, pointer cursor, nested anchor support (inner takes precedence)
- [x] **CSS pseudo-class selectors**: `:hover`, `:active`, `:focus` state tracking with dynamic CSS rule re-evaluation
- [x] **CSS `:not()` pseudo-class**: Selector negation support with compound selectors inside :not()
- [x] **CSS structural pseudo-classes**: `:first-child`, `:last-child`, `:only-child`, `:empty`, `:root`
- [x] **SVG `<view>` element**: Parse view elements with viewBox/preserveAspectRatio, fragment identifier support, programmatic view switching via controller
- [x] **Performance caching** for render-time optimizations:
  - Gradient shader caching with proper cache key generation
  - Pattern image caching to avoid repeated `toImageSync()` calls
  - Text paragraph caching for efficient text rendering
  - Hit-test path geometry caching for faster pointer event handling
  - Smart cache invalidation when animation time changes
- [x] CSS combinator selectors: descendant (space), child (`>`), adjacent sibling (`+`), general sibling (`~`)
- [x] CSS attribute selectors: `[attr]`, `[attr=value]`, `[attr~=value]`, `[attr|=value]`, `[attr^=value]`, `[attr$=value]`, `[attr*=value]`, case-insensitive flag
- [x] Compound selectors with combinators: `g.container > rect[fill=red].item`
- [x] `calcMode="paced"` distance support completed for `path` and `transform` + regression coverage
- [x] Refactor milestone: split `smil_animation.dart` into focused part files (API preserved)
- [x] Refactor milestone: split `smil_parser.dart` into focused part files (API preserved)
- [x] Refactor milestone: split `smil_timeline.dart` into focused part files (API preserved)
- [x] Refactor milestone: split `css_to_smil_converter.dart` into focused part files (API preserved)
- [x] Refactor milestone: split `path_data.dart` into focused part files (API preserved)
- [x] Refactor milestone: split `path_parser.dart` into focused part files (API preserved)
- [x] Refactor milestone: split `path_normalizer.dart` into focused part files (API preserved)
- [x] Refactor milestone: split `path_interpolation.dart` into focused part files (API preserved)
- [x] Refactor milestone: split `css_animations.dart` into focused part files (API preserved)
- [x] Refactor milestone: split `svg_parser_filters_primitives.dart` into focused part files (API preserved)
- [x] Refactor milestone: split `svg_filters_registry_pipeline.dart` into focused part files (API preserved)
- [x] Refactor milestone: further split `svg_filters_registry_pipeline_primitives.dart` into focused part files (API preserved)
- [x] Refactor milestone: split `animated_svg_painter.dart` tree/filter traversal into focused part files (API preserved)
- [x] Refactor milestone: split `animated_svg_painter_gradients.dart` into focused part files (API preserved)
- [x] Refactor milestone: split `animated_svg_painter_clip_mask.dart` into focused part files (API preserved)
- [x] Refactor milestone: split `smil/interpolators.dart` into focused part files (API preserved)
- [x] Refactor milestone: further split `css_to_smil_converter_transforms.dart` into focused part files (API preserved)
- [x] Full regression run after refactor milestones (`flutter test`, `flutter analyze`)
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
- [x] Text multi-position attributes: `x`, `y`, `dx`, `dy` as space/comma-separated lists for per-character positioning in paint + hit-testing
- [x] Text `rotate` attribute: per-character rotation support (single value or list) in paint + hit-testing
- [x] textPath `spacing` attribute: `exact` (default) vs `auto` for character spacing control in paint + hit-testing
- [x] `text-decoration` attribute: `underline`, `overline`, `line-through` support with inheritance and color
- [x] `writing-mode` attribute: `horizontal-tb`, `vertical-rl`, `vertical-lr` (+ legacy `tb`/`tb-rl`) for vertical text rendering
- [x] `<marker>` element support: `marker-start`, `marker-mid`, `marker-end` attributes with `orient`, `markerUnits`, `viewBox` support
- [x] `<pattern>` paint server: fill/stroke patterns with `patternUnits`, `patternContentUnits`, `viewBox`, `patternTransform`, and inheritance
- [x] Gradient/pattern coordinate units: `gradientUnits="objectBoundingBox"`, `gradientUnits="userSpaceOnUse"`, `patternContentUnits="objectBoundingBox"`, radial gradient focal point, gradient stop offset animation via SMIL, pattern edge cases (width/height=0, negative values)
- [x] Group `opacity` compositing: proper `saveLayer` handling for `<g>`, `<svg>`, `<foreignObject>` with `opacity < 1`
- [x] `paint-order` attribute: control fill/stroke/markers paint order (`stroke fill`, `markers stroke fill`, etc.)
- [x] `vector-effect: non-scaling-stroke`: stroke width remains constant regardless of transform scale
- [x] `stroke-linecap`: line cap styling (`butt`, `round`, `square`)
- [x] `stroke-linejoin`: line join styling (`miter`, `round`, `bevel`)
- [x] `stroke-miterlimit`: miter limit for sharp corners
- [x] `shape-rendering`: anti-aliasing control (`auto`, `optimizeSpeed`, `crispEdges`, `geometricPrecision`)
- [x] `overflow`: viewport clipping control (`visible`, `hidden`, `auto`, `scroll`)
- [x] `image-rendering`: image scaling quality (`auto`, `pixelated`, `optimizeSpeed`, `optimizeQuality`, `smooth`)
- [x] `mix-blend-mode`: CSS blend modes for elements (`multiply`, `screen`, `overlay`, `darken`, `lighten`, etc.)
- [x] `currentColor`: keyword support for fill/stroke referencing inherited `color` property
- [x] `transform-origin`: CSS property for setting the origin point of transformations
- [x] `color-interpolation`: gradient color space control (`sRGB`, `linearRGB`)
- [x] `font-variant`: text styling with OpenType features (`small-caps`, `oldstyle-nums`, `tabular-nums`, etc.)
- [x] `xml:space`: whitespace handling (`default`, `preserve`) for text content
- [x] `direction`: text direction for RTL/LTR support (`ltr`, `rtl`)
- [x] `text-rendering`: text quality hints (`auto`, `optimizeSpeed`, `optimizeLegibility`, `geometricPrecision`)
- [x] `pathLength`: scales stroke-dasharray/dashoffset proportionally on shapes
- [x] `color-rendering`: gradient/color interpolation quality hints (`auto`, `optimizeSpeed`, `optimizeQuality`)
- [x] `glyph-orientation-vertical`: vertical text glyph rotation (`auto`, `0deg`, `90deg`, etc.)
- [x] `unicode-bidi`: bidirectional text handling (`normal`, `embed`, `isolate`, `bidi-override`, etc.)
- [x] `font-stretch`: text width control (`ultra-condensed` to `ultra-expanded`, percentages)
- [x] `white-space`: CSS whitespace handling (`normal`, `pre`, `pre-wrap`, `nowrap`, `pre-line`, `break-spaces`)
- [x] `cursor`: CSS cursor style (`default`, `pointer`, `text`, `move`, `crosshair`, `grab`, etc.)
- [x] `font-size-adjust`: maintain x-height consistency across fallback fonts
- [x] Advanced text typography: tspan absolute positioning creates new text chunks with proper cursor reset
- [x] Advanced text typography: text-anchor applies independently per text chunk (when tspan has absolute x/y)
- [x] textLength conflict resolution: ignored when explicit per-character x/y positions exist (per SVG spec)
- [x] CSS cascade and specificity resolution: proper specificity calculation, cascade order, !important handling, and inheritable property support
- [x] CSS shorthand property expansion: font, animation (multiple), transition, margin/padding, marker (SVG), border shorthands
- [x] CSS 3D transforms: `translate3d`, `translateZ`, `rotateX`, `rotateY`, `rotateZ`, `rotate3d`, `scale3d`, `scaleZ`, `perspective`, `matrix3d` with 3D→2D projection and `backface-visibility`
- [x] CSS animation edge cases: multiple animations per element, animation-play-state (paused/running), negative animation-delay, fill-mode (backwards/both)
- [x] CSS transitions support: transition shorthand parsing, transition-property/duration/timing-function/delay, multiple transitions
- [x] @media queries in SVG style blocks: prefers-color-scheme (dark/light), viewport queries (min-width/max-width/min-height/max-height)
- [x] CSS custom properties (variables) and calc() support: `var(--name)`, `var(--name, fallback)`, calc() arithmetic with units, nested calc(), var() inside calc()
- [x] SVG accessibility: `<title>` and `<desc>` elements exposed as Semantics label/hint, ARIA attributes (`aria-label`, `aria-describedby`, `role`) integrated with Flutter Semantics

## P0 - Blink Parity Foundations

- [x] Implement actual `<path>` painting in animated renderer.
- [x] Add `<polygon>` and `<polyline>` rendering.
- [x] Add gradient paint servers (`<linearGradient>`, `<radialGradient>`, `<stop>`).
- [x] Add `<use>`/`<symbol>` + `<defs>` baseline reference resolution.
- [x] Add baseline `<clipPath>` support.
- [x] Add baseline `<mask>` support.

## P1 - Core Feature Gaps

- [ ] Complete text pipeline parity (`<text>`, `<tspan>`, `<textPath>` advanced semantics).
- [x] Extend `<foreignObject>` parity beyond baseline viewport/container semantics (requiredExtensions, nested SVG, overflow, transform propagation, hit-testing).
- [x] Add `animateMotion` support for `<mpath xlink:href="...">` references.
- [x] Expand element hit-testing to advanced semantics (`clipPath`/`mask`/`use`/text-aware hit regions).

## P2 - Filters (Blink FE coverage)

- [ ] Extend `feDropShadow` to advanced parity semantics beyond source-based composition paths.
- [x] Implement `feOffset`.
- [x] Implement `feMorphology` (`erode`/`dilate` baseline).
- [x] Implement `feDisplacementMap` (baseline graph pass-through).
- [x] Implement `feImage` (baseline graph pass-through + source attribute parsing).
- [x] Implement `feConvolveMatrix` (actual kernel convolution with edge modes).
- [x] Implement `feTurbulence` (baseline graph pass-through + noise attribute parsing).
- [x] Implement `feComponentTransfer` (baseline graph pass-through + channel-function parsing).
- [x] Implement `feDiffuseLighting` (actual Lambertian diffuse lighting calculation with light sources).
- [x] Implement `feSpecularLighting` (actual Blinn-Phong specular lighting calculation with light sources).
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
- Closed bugs and closed milestones must be recorded in:
  `/Users/denisnadey/apps/flutter_full_svg_support/docs/RESOLVED_ISSUES.md`
