# Current Development Status

**Last Updated:** March 16, 2026  
**Authority:** This file is the single source of truth for current project state.

## Snapshot

- Branch: `main`
- Flutter SDK: `3.38.1` (via `./.fvm/flutter_sdk/bin/flutter`)
- Dart SDK: `3.10.0`

## Verified Health (March 16, 2026)

Commands run in `/Users/denisnadey/apps/flutter_full_svg_support`:

```bash
./.fvm/flutter_sdk/bin/flutter test
./.fvm/flutter_sdk/bin/flutter analyze
```

Result:
- `flutter test`: **All tests passed** (`+1171 ~1`)
- `flutter analyze`: **26 info**, **0 errors**, **0 warnings** (deprecations/minor lint only)

## Documentation Cleanup (March 16, 2026)

Removed redundant documentation files:
- `DOCS.md` (duplicate of DOCUMENTATION_INDEX.md)
- `FVM_SETUP.md` (local dev notes)
- `CSS_ANIMATIONS_FILTERS.md` (info exists in CURRENT_STATUS.md and BLINK_PARITY_AUDIT.md)
- `PLAN_SUMMARY.md` (duplicated CURRENT_STATUS.md content)
- `QUICK_START.md` (redundant info)
- `docs/REORGANIZATION.md` (historical)

Moved to archive:
- `docs/SESSION_2026_01_09.md`
- `docs/STAGE_7_SUMMARY.md`
- `docs/STAGE_8_PLAN.md`

## Recently Closed (March 12-13, 2026)

### Functional Closures
- ✅ `calcMode="paced"` distance support for `path` and `transform` is implemented and covered by tests.
- ✅ `autoPlay: false` rendering issue remains closed and regression-covered.

### Refactor Closures (API preserved)
- ✅ `smil_animation.dart` split into focused part files.
- ✅ `smil_parser.dart` split into focused part files.
- ✅ `smil_timeline.dart` split into focused part files.
- ✅ `css_to_smil_converter.dart` split into focused part files.
- ✅ `path_data.dart` split into focused part files.
- ✅ `path_parser.dart` split into focused part files.
- ✅ `path_normalizer.dart` split into focused part files.
- ✅ `path_interpolation.dart` split into focused part files.
- ✅ `css_animations.dart` split into focused part files.
- ✅ `svg_parser_filters_primitives.dart` split into focused part files.
- ✅ `svg_filters_registry_pipeline.dart` split into focused part files.
- ✅ `svg_filters_registry_pipeline_primitives.dart` further split into focused part files.
- ✅ `animated_svg_painter.dart` tree/filter traversal split into focused part files.
- ✅ `animated_svg_painter_gradients.dart` split into focused part files.
- ✅ `animated_svg_painter_clip_mask.dart` split into focused part files.
- ✅ `smil/interpolators.dart` split into focused part files.
- ✅ `css_to_smil_converter_transforms.dart` further split into focused part files.
- ✅ Full regression runs completed after refactors.

See: `/Users/denisnadey/apps/flutter_full_svg_support/docs/RESOLVED_ISSUES.md`

## What Is Implemented

### SMIL Engine
- `<animate>`, `<animateTransform>`, `<animateMotion>`, `<set>`, `<animateColor>` parsing
- `animateMotion`: inline `path` and `<mpath href="#...">` / `<mpath xlink:href="#...">` references
- Timing conditions: offset, syncbase, event-based
- Event target syntax support: `id.click`, `id.mouseover+200ms`
- `calcMode="spline"`, `calcMode="paced"`
- `additive="sum"`, `accumulate="sum"`
- `AnimatedSvgController`: pause/resume/seek/playbackRate/restart/reverse

### CSS Animation Interop
- `@keyframes` extraction and `animation` / `animation-*` parsing
- CSS->SMIL timing conversion with `cubic-bezier(...)` and `ease*` mapped to SMIL `keySplines`
- CSS `animation-direction`: `reverse`, `alternate`, `alternate-reverse` runtime behavior
- Baseline CSS transform-function normalization in converter (`deg/rad/turn`, `px`, aliases like `translateX`)

### Color Parsing (Parser Path)
- `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`
- `rgb(...)` / `rgba(...)` (comma and CSS Color 4 space/slash variants)
- `hsl(...)` / `hsla(...)` with angle units (`deg/rad/turn/grad`)

### Interaction & Events
- Document-level events: click/mouseover/mouseout dispatch
- Element-level hit-testing and dispatch for `rect/circle/ellipse/line/path/polygon/polyline/image/foreignObject/text/tspan/textPath`
- Baseline `pointer-events` semantics including inherited `none`, geometry modes, and text-aware modes
- Baseline `<use>`-referenced hit-testing
- Advanced `clip-path` / `mask` hit-testing with geometric intersection and alpha-based visibility
- Stroke-width expansion for accurate hit regions with `stroke-linecap` and `stroke-linejoin` support
- Per-character text hit-testing for improved precision
- Inline `style` with trailing `!important` normalization in visibility/hit-testing paths

### Runtime Diagnostics / Playground
- Structured trace API in `AnimatedSvgPicture`: `SvgTraceEvent`, `SvgTraceLevel`, `onTrace`
- Optional per-frame tick tracing (`traceFrameTicks`)
- Example viewer page includes trace logs, diagnostics, import/export JSON reports, filtering, grouping, and widget-test coverage

### SVG Filters (Animated Pipeline)
Implemented primitives / baseline semantics:
- `feGaussianBlur`
- `feMorphology` (baseline)
- `feDisplacementMap` (baseline + `scale=0` and `in2="none"` handling)
- `feImage` (baseline graph semantics)
- `feConvolveMatrix` (baseline)
- `feTurbulence` (baseline)
- `feComponentTransfer` (baseline)
- `feDiffuseLighting` (baseline)
- `feSpecularLighting` (baseline)
- `feOffset`
- `feFlood`
- `feBlend` (baseline + extended SVG2 mode mapping)
- `feComposite` (baseline + arithmetic approximations)
- `feMerge`
- `feTile` (baseline)
- `feDropShadow` (baseline source+shadow composition)
- `feColorMatrix`

### Geometry / Text / Reuse / External Content
- Painted: `rect`, `circle`, `ellipse`, `line`, `path`, `polygon`, `polyline`, `image`, `text`, `tspan`, `textPath` (baseline)
- Text multi-position attributes: `x`, `y`, `dx`, `dy` as space/comma-separated lists for per-character positioning
- Text advanced typography: tspan absolute positioning creates new text chunks, text-anchor applies per-chunk
- textLength conflict resolution: ignored when explicit per-character positions exist
- `<use href="#...">`, `<symbol>` via `<use>` (baseline)
- `<defs>` as definitions-only
- `<image>` with data URI + network/bundle best-effort loading (baseline)
- `<foreignObject>` viewport container behavior with advanced semantics:
  - `requiredExtensions` fallback for `<switch>` patterns
  - Nested SVG context switching with viewBox/preserveAspectRatio
  - Overflow handling (hidden/visible)
  - Transform propagation through foreignObject
  - Hit-testing through foreignObject children
- `clipPath` and `mask` baseline support

## Known Gaps (Blink Parity, Animated Pipeline)

Detailed audit: `/Users/denisnadey/apps/flutter_full_svg_support/docs/BLINK_PARITY_AUDIT.md`

High-impact gaps:
1. No full animated-pipeline text parity (advanced typography semantics beyond baseline).
2. Filter parity is partial: baseline support exists for many primitives, but advanced non-source graph semantics remain limited.
3. CSS animation conversion remains partial for advanced/edge CSS shorthand/transform semantics.
4. `animateMotion` still lacks broader Blink-level semantics beyond current baseline support.

## Documentation Policy

To avoid drift:
- Current factual status lives only here.
- Planning lives in `NEXT_STEPS.md` and `TODO.md`.
- Closed bugs and closed milestones are tracked in `docs/RESOLVED_ISSUES.md`.

## Next Execution Plan

1. Expand advanced filter graph semantics (`feDropShadow`, `feMerge`, background input parity).
2. Complete advanced text parity beyond current baseline.
3. Expand hit-testing parity for complex `clipPath`/`mask`/`use`/text regions.
4. Improve advanced `<use>`/`symbol` inheritance semantics.
5. Continue CSS/SMIL edge-case parity with regression fixtures.
6. Continue modular refactor of remaining large files (`svg_filters_primitives.dart`, `animated_svg_painter_shapes.dart`, `animated_svg_picture.dart`, `animated_svg_picture_utils.dart`) with full regression checks after each split.
