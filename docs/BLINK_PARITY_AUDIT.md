# Blink Parity Audit (Animated Pipeline)

**Date:** February 21, 2026  
**Scope:** `AnimatedSvgPicture` pipeline only (`lib/src/animation/**`)  
**Reference baseline:** `blink-b87d44f-Source-core-svg/svgtags.in`

## Why This Document Exists

`flutter_svg` has two pipelines:
1. static production pipeline (`SvgPicture` + vector_graphics)
2. experimental animated pipeline (`AnimatedSvgPicture` + custom DOM/painter)

This audit targets the second pipeline and tracks what is still missing versus Blink SVG behavior.

## Method Used

- Blink tag baseline extracted from: `blink-b87d44f-Source-core-svg/svgtags.in`
- Current implementation inspected in:
  - `lib/src/animation/animated_svg_painter.dart`
  - `lib/src/animation/animated_svg_picture.dart`
  - `lib/src/animation/svg_parser.dart`
  - `lib/src/animation/smil/*.dart`
  - `lib/src/animation/css_to_smil_converter.dart`

## Quantitative Snapshot

- Blink SVG tag baseline in local snapshot: **81 tags**
- Tags currently recognized in animated painter switch: **10** (`svg`, `g`, `rect`, `circle`, `ellipse`, `line`, `path`, `polygon`, `polyline`, `use`)
- Tags currently painted as visible geometry: **7** (`rect`, `circle`, `ellipse`, `line`, `path`, `polygon`, `polyline`)
- Blink FE primitives in baseline: **25** (`fe*`)
- FE primitives currently implemented: **8** (`feGaussianBlur`, `feOffset`, `feFlood`, `feBlend`, `feComposite`, `feMerge` baseline, `feDropShadow` simplified, `feColorMatrix`)

## Current Coverage Matrix

### 1) Geometry Rendering

Implemented:
- `rect`, `circle`, `ellipse`, `line`, `path`, `polygon`, `polyline`
- basic fill/stroke/opacity, per-node transform

Missing:
- marker handling

### 2) Structural / Reuse Elements

Partial:
- `svg`, `g`, `defs` are parsed into DOM
- baseline `<use href="#id">` rendering
- baseline `<symbol>` rendering via `<use>` (`viewBox` with `use width/height` scaling)

Missing:
- advanced `<symbol>` semantics and advanced `<use>` inheritance behavior
- complete semantics for `switch`, conditional processing

### 3) Paint Servers

Implemented:
- `linearGradient`, `radialGradient`, `stop` for fill/stroke paint server resolution

Missing:
- `pattern`

### 4) Clipping / Masking

Implemented:
- baseline `clipPath` rendering via `clip-path="url(#...)"` references
- baseline `mask` rendering via `mask="url(#...)"` geometry clipping

Missing:
- advanced mask composition semantics
- advanced clipPath semantics

### 5) Text & Typography

Missing:
- `text`, `tspan`, `textPath`, text positioning model

### 6) External Content

Missing:
- `image`
- `foreignObject`

### 7) Filter Effects

Implemented:
- `feGaussianBlur`
- `feOffset`
- `feFlood` (baseline color replacement approximation)
- `feBlend` (baseline blend-mode approximation)
- `feComposite` (baseline operator-to-blend-mode approximation)
- `feMerge` / `feMergeNode` (baseline parsing, no full input-graph composition yet)
- `feColorMatrix`
- `feDropShadow` (simplified, not full SVG composition semantics)

Missing high-priority FE primitives:
- full `feDropShadow` composition semantics
- full `feMerge` / `feMergeNode` input-graph semantics

Missing advanced FE primitives:
- `feConvolveMatrix`, `feMorphology`, `feDisplacementMap`, lighting family, `feTurbulence`, `feImage`, etc.

### 8) SMIL Animation

Implemented:
- `animate`, `animateTransform`, `animateMotion`, `set`, `animateColor`
- timing: offset/syncbase/event-based, including `id.click`
- `calcMode`: linear/discrete/spline/paced
- additive/accumulate

Partial:
- `animateMotion` supports inline `path`, `<mpath href="#...">`, `keyPoints`, `rotate`
- paced distance for path/transform remains fallback-limited

### 9) Interaction & Event Dispatch

Implemented:
- document-level click/mouseover/mouseout
- element-level click/mouseover/mouseout for `rect/circle/ellipse/line/path/polygon/polyline`

Missing:
- hit-testing for text and advanced painted geometry semantics (`clipPath`/`mask`/`use`-aware regions)
- broader DOM event parity

### 10) CSS Animation Interop

Implemented:
- `@keyframes` extraction from `<style>`
- `animation` / `animation-*` parsing
- conversion into SMIL objects

Missing:
- transform-function parsing fidelity in CSS->SMIL
- `cubic-bezier(...)` conversion parity
- `alternate` and `alternate-reverse`

## Prioritized Backlog (Execution)

### P0: Foundation (do first)

1. Improve `<use>`/`symbol` inheritance semantics.
2. Expand hit-testing semantics for complex painted geometry (`clipPath`/`mask`/`use`, text).
3. Complete full-composition semantics for `feDropShadow` and `feMerge`/`feMergeNode`.

### P1: Core Feature Expansion

1. Add text baseline (`text`, `tspan`, `textPath`).
2. Add `image` support.
3. Extend `animateMotion` behavior parity beyond baseline path-reference support.

### P2: Filter Parity

1. Upgrade `feDropShadow` to full composition behavior.
2. Upgrade `feMerge`/`feMergeNode` from baseline parsing to full graph semantics.
3. Add remaining FE primitives by impact.

### P3: CSS/Timing Parity

1. CSS transform parser in converter.
2. `cubic-bezier(...)` to keySplines mapping.
3. `alternate*` direction behavior.

### P4: Validation/Quality

1. Add Blink-style fixture test pack (parse + render + animation).
2. Expand playground diagnostics for unsupported-tag warnings.
3. Performance baselines for each newly added feature cluster.

## Definition of Done for "Blink Gap Closed" Milestones

For each feature cluster:
- parser support exists,
- renderer behavior exists in animated pipeline,
- interaction/animation path is covered where relevant,
- tests include positive + negative + visual checks,
- playground can surface diagnostics for the feature.
