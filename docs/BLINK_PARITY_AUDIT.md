# Blink Parity Audit (Animated Pipeline)

**Date:** March 13, 2026  
**Scope:** `AnimatedSvgPicture` pipeline only (`lib/src/animation/**`)  
**Reference baseline:** `blink-b87d44f-Source-core-svg/svgtags.in`

## Why This Document Exists

`flutter_svg` has two pipelines:
1. static production pipeline (`SvgPicture` + vector_graphics)
2. animated pipeline (`AnimatedSvgPicture` + custom DOM/painter)

This audit tracks the second pipeline versus Blink SVG behavior.

## Method Used

- Blink tag baseline extracted from: `blink-b87d44f-Source-core-svg/svgtags.in`
- Current implementation inspected in:
  - `lib/src/animation/animated_svg_painter.dart`
  - `lib/src/animation/animated_svg_picture.dart`
  - `lib/src/animation/svg_parser.dart`
  - `lib/src/animation/smil/*.dart`
  - `lib/src/animation/css_to_smil_converter*.dart`

## Quantitative Snapshot

- Blink SVG tag baseline in local snapshot: **81 tags**
- Tags currently recognized in animated painter switch: **15** (`svg`, `g`, `rect`, `circle`, `ellipse`, `line`, `path`, `polygon`, `polyline`, `image`, `foreignObject`, `text`, `tspan`, `textPath`, `use`)
- Tags currently painted as visible geometry: **10** (`rect`, `circle`, `ellipse`, `line`, `path`, `polygon`, `polyline`, `image`, `text`, `textPath` via text flow)
- Blink FE primitives in baseline: **25** (`fe*`)
- FE primitives with baseline implementation in animated pipeline: **17**

## Current Coverage Matrix

### 1) Geometry Rendering

Implemented:
- `rect`, `circle`, `ellipse`, `line`, `path`, `polygon`, `polyline`, `image`
- basic fill/stroke/opacity, per-node transform

Missing:
- marker handling

### 2) Structural / Reuse Elements

Partial:
- `svg`, `g`, `defs` are parsed into DOM
- baseline `<use href="#id">` rendering
- baseline `<symbol>` rendering via `<use>` (`viewBox` + `use width/height` scaling)

Missing:
- advanced `<symbol>` semantics and advanced `<use>` inheritance behavior
- complete semantics for `switch` and conditional processing

### 3) Paint Servers

Implemented:
- `linearGradient`, `radialGradient`, `stop`

Missing:
- `pattern`

### 4) Clipping / Masking

Implemented:
- baseline `clipPath` rendering via `clip-path="url(#... )"`
- baseline `mask` rendering via `mask="url(#... )"` geometry clipping

Missing:
- advanced mask composition semantics
- advanced clipPath semantics

### 5) Text & Typography

Partial:
- baseline `text`, `tspan`, `textPath`
- spacing and baseline-related baseline semantics (`letter-spacing`, `word-spacing`, `dominant-baseline`, `baseline-shift`)
- `textLength` / `lengthAdjust` baseline support

Missing:
- advanced text positioning/typography parity

### 6) External Content

Partial:
- baseline `image` rendering (`href`/`xlink:href`, data/network/bundle sources)
- baseline `foreignObject` viewport/container behavior

Missing:
- advanced image semantics parity
- advanced `foreignObject` semantics parity

### 7) Filter Effects

Implemented baseline primitives:
- `feGaussianBlur`
- `feMorphology`
- `feDisplacementMap`
- `feImage`
- `feConvolveMatrix`
- `feTurbulence`
- `feComponentTransfer`
- `feDiffuseLighting`
- `feSpecularLighting`
- `feOffset`
- `feFlood`
- `feBlend`
- `feComposite`
- `feMerge` / `feMergeNode`
- `feTile`
- `feDropShadow`
- `feColorMatrix`

Missing high-priority semantics:
- advanced non-source input-graph behavior and composition parity for complex chains
- advanced `feDropShadow` / `feMerge` behavior beyond baseline semantics

### 8) SMIL Animation

Implemented:
- `animate`, `animateTransform`, `animateMotion`, `set`, `animateColor`
- timing: offset/syncbase/event-based (`id.click` etc.)
- `calcMode`: `linear` / `discrete` / `spline` / `paced`
- additive / accumulate
- paced distance calculators include `number`/`length`/`color`/`path`/`transform`

Partial:
- `animateMotion` supports inline path and `<mpath>` references with baseline `keyPoints`/`rotate`, but not full Blink parity

### 9) Interaction & Event Dispatch

Implemented:
- document-level click/mouseover/mouseout
- element-level click/mouseover/mouseout for main painted elements
- baseline use-referenced hit-testing
- baseline clip/mask-aware visibility gating

Missing:
- advanced hit-testing semantics (`clipPath`/`mask`/`use` regions and full text parity)
- broader DOM event parity

### 10) CSS Animation Interop

Implemented:
- `@keyframes` extraction and `animation` / `animation-*` parsing
- CSS→SMIL conversion
- baseline transform normalization
- `cubic-bezier(...)` + `ease*` mapping to SMIL `keySplines`
- runtime direction parity: `reverse`, `alternate`, `alternate-reverse`

Missing:
- advanced CSS shorthand edge cases and high-fidelity transform semantics

## Prioritized Backlog (Execution)

### P0: Foundation
1. Improve advanced `<use>` / `<symbol>` inheritance semantics.
2. Expand hit-testing semantics for complex painted geometry.
3. Expand advanced filter input-graph semantics.

### P1: Core Feature Expansion
1. Complete advanced text parity.
2. Expand advanced `foreignObject` and `image` semantics.
3. Extend `animateMotion` beyond baseline path-reference support.

### P2: Filter Parity
1. Upgrade `feDropShadow` to advanced composition behavior.
2. Upgrade `feMerge`/`feMergeNode` to advanced graph semantics.
3. Add remaining FE primitives by impact.

### P3: CSS/Timing Parity
1. Expand CSS transform/unit fidelity beyond baseline normalization.
2. Add regression fixtures for CSS edge semantics.

### P4: Validation/Quality
1. Add Blink-style fixture test pack (parse + render + animation).
2. Expand playground diagnostics for unsupported-tag warnings.
3. Performance baselines for each newly added feature cluster.

## Definition of Done for "Blink Gap Closed"

For each feature cluster:
- parser support exists,
- renderer behavior exists in animated pipeline,
- interaction/animation path is covered where relevant,
- tests include positive + negative + visual checks,
- playground can surface diagnostics for the feature.
