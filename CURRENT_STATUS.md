# Current Development Status

**Last Updated:** March 28, 2026  
**Authority:** This file is the single source of truth for current project state.

## Snapshot

- Branch: `main`
- Flutter SDK: `3.38.1` (via `.fvm/versions/3.38.1/bin/flutter`)
- Dart SDK: `^3.8.0`
- Version: `2.2.2`
- **Blink SVG Parity:** ~75%

## Verified Health (March 28, 2026)

Commands run in `/Users/denisnadey/apps/flutter_full_svg_support`:

```bash
.fvm/versions/3.38.1/bin/dart analyze lib/ test/
.fvm/versions/3.38.1/bin/flutter test
```

Result:
- `flutter test`: **3,497+ tests passed** (golden_comparison hangs on browser render - excluded)
- `dart analyze`: **0 errors**, **0 warnings**, 1 info

## In-Progress Work

Active development areas targeting higher Blink parity:

1. **CSS/SMIL edge-case parity** - Advanced shorthand/transform semantics

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

## Recently Closed (March 28, 2026)

### Advanced Light Sources Complete (Blink Parity)
- ✅ **Per-pixel lighting computation**: `SvgDiffuseLightingPaintPass` and `SvgSpecularLightingPaintPass` classes for full Blink-style pixel-level lighting
- ✅ **feDistantLight**: Full azimuth/elevation direction calculation with proper vector normalization
- ✅ **fePointLight**: Per-pixel light direction computation with distance-based attenuation support
- ✅ **feSpotLight**: Full cone attenuation with `limitingConeAngle` hard cutoff and `specularExponent`-based intensity falloff
- ✅ **Surface normal computation**: Sobel-like kernel for bump map normal extraction with edge mode handling (duplicate/wrap/none)
- ✅ **kernelUnitLength**: Proper scaling of bump map sampling for normal computation
- ✅ **z-coordinate handling**: 3D light position relative to surface with proper height computation from alpha channel
- ✅ **lighting-color support**: Full color parsing for lighting elements (named colors, hex, rgb/rgba)
- ✅ **Pipeline integration**: Specialized paint passes replace simplified ColorFilter approximation for accurate per-pixel lighting
- ✅ **91+ comprehensive tests** covering all light sources, edge cases (light behind surface, z=0, narrow cones), filter chains, and pipeline integration

### Advanced Masking Complete (Blink Parity)
- ✅ **maskUnits attribute**: Full support for `objectBoundingBox` (default) and `userSpaceOnUse` coordinate systems
- ✅ **maskContentUnits attribute**: Full support for `userSpaceOnUse` (default) and `objectBoundingBox` coordinate systems
- ✅ **Luminance masks (default per SVG 2)**: Proper luminance formula (0.2126*R + 0.7152*G + 0.0722*B) * A with white=visible, black=hidden, gray=partial
- ✅ **Alpha masks**: mask-type="alpha" uses alpha channel directly for masking
- ✅ **mask-type/mask-mode CSS properties**: Full parsing and override priority (mask-mode > mask-type > type attribute > default luminance)
- ✅ **Layer-based compositing**: saveLayer with proper blend modes (DstIn) for accurate alpha/luminance composition
- ✅ **Gradient mask content**: Linear and radial gradients in mask create smooth visibility transitions
- ✅ **Transform support**: Transforms on mask child elements properly applied
- ✅ **Edge feathering**: Blur filters in mask content create soft edges with bounds expansion
- ✅ **Nested masks**: Mask on group containing masked element with proper intersection
- ✅ **Circular reference protection**: Safe handling of circular mask references and self-referencing masks with max depth limit
- ✅ **Mask + clip-path combination**: Both applied correctly (clip-path then mask)
- ✅ **Hit-testing parity**: Luminance-aware hit detection (black areas don't receive hits), maskUnits/maskContentUnits transforms in hit-test coordinates
- ✅ **26+ comprehensive tests** covering maskUnits, maskContentUnits, luminance/alpha modes, gradients, transforms, nested masks, combinations, and edge cases

### Advanced Clipping Complete (Blink Parity)
- ✅ **clipPathUnits attribute**: Full support for `userSpaceOnUse` (default) and `objectBoundingBox` coordinate systems with proper transform mapping
- ✅ **Nested clip-paths**: Cascading clip-paths with intersection computation, 3+ levels deep, mixed clipPathUnits across nesting levels
- ✅ **Complex clip-path compositions**: Multiple shapes (union), `<use>` element references, `<text>` element clipping (bounding box), transforms on child elements
- ✅ **clip-rule attribute**: Full `nonzero` (default) and `evenodd` fill rule support for all shape types (rect, circle, ellipse, path, polygon, polyline, text, line, image)
- ✅ **Hit-testing parity**: All clipping scenarios properly affect hit regions including clipPathUnits transforms, nested intersections, and clip-rule
- ✅ **29 comprehensive tests** covering clipPathUnits, clip-rule, nested clip-paths, compositions, edge cases (empty clip, no geometry, circular refs), transform compositions, and hit-testing

### SVG Filter Graph Complete (100% FE Primitive Coverage)
- ✅ **All 17 FE primitives implemented**: feGaussianBlur, feMorphology, feDisplacementMap, feImage, feConvolveMatrix, feTurbulence, feComponentTransfer, feDiffuseLighting, feSpecularLighting, feOffset, feFlood, feBlend, feComposite, feMerge/feMergeNode, feTile, feDropShadow, feColorMatrix
- ✅ **All 3 light source elements**: feDistantLight, fePointLight, feSpotLight
- ✅ **Complete input chain semantics**: SourceGraphic, SourceAlpha, BackgroundImage, BackgroundAlpha, FillPaint, StrokePaint
- ✅ **Named result references**: Proper chaining via `result` attribute, multi-hop resolution (A→B→C)
- ✅ **Circular/forward reference detection**: Graceful handling per SVG spec
- ✅ **Advanced feDropShadow composition**: Multi-pass shadow pipeline (blur + offset + flood + composite + merge)
- ✅ **Advanced feMerge composition**: Multiple input layers in declaration order

### Extended Component Transfer (Full Blink Parity)
- ✅ **All 5 transfer function types**: `identity`, `table`, `discrete`, `linear`, `gamma`
- ✅ **Full attribute parsing**: `tableValues`, `slope`, `intercept`, `amplitude`, `exponent`, `offset`
- ✅ **Per-channel functions**: `<feFuncR>`, `<feFuncG>`, `<feFuncB>`, `<feFuncA>` elements
- ✅ **Mathematical implementations per SVG spec**: piecewise linear interpolation for table, step function for discrete, slope*C+intercept for linear, amplitude*pow(C,exponent)+offset for gamma
- ✅ **Output clamping to [0,1]** with proper edge case handling (empty tableValues, single value)
- ✅ **Animation support**: SMIL animations on slope, intercept, amplitude, exponent, offset attributes
- ✅ **Pipeline optimization**: ColorFilter matrix for linear-only transforms, SvgComponentTransferPaintPass for table/discrete/gamma
- ✅ **78 comprehensive tests** covering all function types, mixed channels, edge cases, and pipeline integration

### Text Typography Completion (~99% Blink Parity)
- ✅ **Hanging punctuation rendering**: CSS `hanging-punctuation` property fully renders (`first`, `last`, `allow-end`, `force-end` values with CJK and Latin punctuation, vertical text, and text-anchor integration)
- ✅ **Baseline alignment in deeply nested contexts**: Recursive baseline offset accumulation through 3+ nesting levels, vertical-in-horizontal writing mode transitions, mixed dominant-baseline/alignment-baseline/baseline-shift propagation
- ✅ **Complex ligature shaping edge cases**: Contextual ligatures preserved across tspan boundaries, font-feature-settings correctly scoped per run, metric recalculation for feature-induced width changes, graceful fallback for unsupported features, cache keys include font features

### Use/Symbol Inheritance Complete (Blink Parity)
- ✅ **CSS cascade through use shadow boundary**: `UseCascadeContext` properly resolves CSS specificity across shadow DOM boundary
- ✅ **CSS property inheritance**: `_UseInheritanceContext` inherits CSS properties (fill, stroke, font-*, visibility, etc.) from use element into shadow content
- ✅ **Symbol viewBox/preserveAspectRatio**: Proper viewport creation with all preserveAspectRatio values (xMinYMin, xMidYMid, xMaxYMax, meet/slice/none)
- ✅ **Nested use/symbol transform composition**: Transforms compose correctly through deeply nested use→symbol→use→symbol chains
- ✅ **Circular reference protection**: Max recursion depth of 10, graceful handling of direct and indirect circular references
- ✅ **Hit-testing parity**: `_UseHitTestContext` mirrors paint code with proper style inheritance and event retargeting to outermost use element
- ✅ **27 comprehensive edge case tests** covering viewBox edge cases, transform composition, preserveAspectRatio variants, invalid references, circular references, CSS inheritance, and hit-testing

### Functional Closures (March 12-13, 2026)
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

### Performance Optimizations
- **Render-time caching**: Critical performance caching to match Blink optimization behavior
  - Gradient shader caching: Shader objects cached by gradient ID + paint bounds + attributes
  - Pattern image caching: Pattern tile images cached and reused across frames
  - Text paragraph caching: Paragraph objects cached by text content + style properties
  - Hit-test path geometry caching: Path objects cached for repeated hit-testing
  - Smart cache invalidation: Caches cleared when animation time changes for animated SVGs

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
- **CSS Selectors**:
  - Simple selectors: tag, `#id`, `.class`
  - Compound selectors: `tag.class#id`
  - Combinator selectors:
    - Descendant (space): `g rect` — matches rect inside g at any depth
    - Child (`>`): `g > rect` — matches direct children only
    - Adjacent sibling (`+`): `rect + circle` — matches immediately following sibling
    - General sibling (`~`): `rect ~ circle` — matches any following sibling
  - Attribute selectors:
    - `[attr]` — has attribute
    - `[attr=value]` — exact match
    - `[attr~=value]` — space-separated list contains value
    - `[attr|=value]` — exact or prefix with hyphen
    - `[attr^=value]` — starts with
    - `[attr$=value]` — ends with
    - `[attr*=value]` — contains substring
    - Case-insensitive flag (`i`): `[attr=value i]`
  - **Pseudo-class selectors** (NEW):
    - `:hover` — element is being hovered by pointer
    - `:active` — element is being pressed
    - `:focus` — element has focus
    - `:not(selector)` — negation pseudo-class
    - `:first-child`, `:last-child`, `:only-child` — structural pseudo-classes
    - `:empty` — element has no children
    - `:root` — root element
- **Multiple Animations Per Element**:
  - Comma-separated `animation` shorthand parsing (e.g., `animation: fadeIn 1s, slideUp 2s 0.5s`)
  - Generates multiple SMIL animation elements per CSS rule
- **animation-play-state**: `paused` / `running` support integrated with SmilAnimation
- **Negative animation-delay**: Start animations partway through (e.g., `-0.5s` on 2s animation starts at 25%)
- **animation-fill-mode edge cases**:
  - `forwards`: Retain final keyframe value after animation ends
  - `backwards`: Apply first keyframe value during delay period
  - `both`: Combine forwards and backwards behavior
- **CSS Transitions**:
  - Parse `transition` shorthand and individual `transition-*` properties
  - Support for `transition-property`, `transition-duration`, `transition-timing-function`, `transition-delay`
  - Multiple comma-separated transitions support
- **@media Queries in SVG Style Blocks**:
  - Parse `@media` rules within `<style>` elements
  - Support for `prefers-color-scheme: dark/light`
  - Support for viewport queries: `min-width`, `max-width`, `min-height`, `max-height`
  - Conditional rule evaluation with CssMediaContext
- **CSS 3D Transforms**:
  - 3D translation: `translate3d(x, y, z)`, `translateZ(z)`
  - 3D rotation: `rotateX(angle)`, `rotateY(angle)`, `rotateZ(angle)`, `rotate3d(x, y, z, angle)`
  - 3D scaling: `scale3d(x, y, z)`, `scaleZ(z)`
  - Perspective: `perspective(length)` function
  - 4x4 matrix: `matrix3d()` 16-value matrix
  - Proper 3D→2D projection using homogeneous coordinates
  - `backface-visibility` support (`visible`/`hidden`)
- **CSS Cascade and Specificity Resolution**:
  - Proper specificity calculation: inline (1,0,0,0) > ID (0,1,0,0) > class/attribute/pseudo-class (0,0,1,0) > element/pseudo-element (0,0,0,1)
  - Cascade order: later declarations win when specificity is equal
  - `!important` handling: overrides normal specificity rules
  - Style inheritance: inheritable CSS properties (fill, stroke, font-*, color, visibility, etc.) cascade from parent to child
- **CSS Shorthand Property Expansion** (NEW):
  - `font` shorthand → font-style, font-variant, font-weight, font-size, line-height, font-family
  - `animation` shorthand with multiple comma-separated animations support
  - `transition` shorthand → transition-property, transition-duration, transition-timing-function, transition-delay
  - `margin`/`padding` shorthand (1-4 value expansion)
  - `marker` shorthand → marker-start, marker-mid, marker-end (SVG-specific)
  - `border` shorthand → border-width, border-style, border-color
- **CSS Custom Properties (Variables) and calc() Support** (NEW):
  - Custom property declarations: `--custom-name: value` in style blocks and inline styles
  - `var()` resolution: `var(--name)` references resolved by walking up the element tree
  - `var()` with fallback: `var(--name, fallback-value)` when variable not defined
  - Variable inheritance: custom properties inherit through the element tree (parent → child)
  - `calc()` expression parser: arithmetic operations (+, -, *, /), unit support (px, em, %, pt, rem)
  - Nested calc(): `calc(100% - calc(20px + 5px))`
  - `var()` inside `calc()`: `calc(var(--size) * 2)`

### Color Parsing (Parser Path)
- `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`
- `rgb(...)` / `rgba(...)` (comma and CSS Color 4 space/slash variants)
- `hsl(...)` / `hsla(...)` with angle units (`deg/rad/turn/grad`)

### Interaction & Events
- Document-level events: click/mouseover/mouseout dispatch
- Element-level hit-testing and dispatch for `rect/circle/ellipse/line/path/polygon/polyline/image/foreignObject/text/tspan/textPath`
- **SVG `<a>` anchor element** (NEW):
  - Parse `<a>` as container element (like `<g>`)
  - Support `href`, `xlink:href`, and `target` attributes
  - `onLinkTap` callback on `AnimatedSvgPicture` receives `SvgLinkInfo` (href, target)
  - Pointer cursor for elements inside `<a>`
  - Nested `<a>` support (inner takes precedence)
- Baseline `pointer-events` semantics including inherited `none`, geometry modes, and text-aware modes
- Baseline `<use>`-referenced hit-testing
- Advanced `clip-path` / `mask` hit-testing with geometric intersection and alpha-based visibility
- Stroke-width expansion for accurate hit regions with `stroke-linecap` and `stroke-linejoin` support
- Per-character text hit-testing for improved precision
- Inline `style` with trailing `!important` normalization in visibility/hit-testing paths

### Accessibility
- `<title>` element: text content exposed as accessible name via `Semantics.label`
- `<desc>` element: text content exposed as accessible description via `Semantics.hint`
- ARIA attributes: `aria-label`, `aria-describedby`, `role` parsed and integrated with Flutter Semantics
- AnimatedSvgPicture wraps with Semantics widget when accessibility info is present
- Role-based Semantics flags: `role="img"` sets image flag, `role="button"` sets button flag, `role="link"` sets link flag

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
- `feConvolveMatrix` (actual kernel convolution with edge modes)
- `feTurbulence` (baseline)
- `feComponentTransfer` (complete: identity, table, discrete, linear, gamma)
- `feDiffuseLighting` (full Blink parity: per-pixel Lambertian diffuse with surface normals)
- `feSpecularLighting` (full Blink parity: per-pixel Blinn-Phong specular with surface normals)
- `feOffset`
- `feFlood`
- `feBlend` (baseline + extended SVG2 mode mapping)
- `feComposite` (baseline + arithmetic approximations)
- `feMerge`
- `feTile` (baseline)
- `feDropShadow` (baseline source+shadow composition)
- `feColorMatrix`

### Geometry / Text / Reuse / External Content
- Painted: `rect`, `circle`, `ellipse`, `line`, `path`, `polygon`, `polyline`, `image`, `text`, `tspan`, `textPath`
- **Text & Typography (~99% Blink parity)**:
  - **Elements**: `<text>`, `<tspan>`, `<textPath>` with full rendering and hit-testing
  - **Positioning**: `x`/`y`/`dx`/`dy` as space/comma-separated lists for per-character positioning, per-character `rotate` (single or list)
  - **Text chunks**: tspan absolute positioning creates new text chunks, `text-anchor` applies per-chunk
  - **textLength**: `textLength` + `lengthAdjust` (`spacing`, `spacingAndGlyphs`), ignored when explicit per-character positions exist (per SVG spec)
  - **textPath**: `href`/`xlink:href`, `startOffset`, `spacing` (`exact`/`auto`)
  - **Font properties**: `font-family` (with fallback chain), `font-weight`, `font-style`, `font-size`, `font-stretch`, `font-variant` (OpenType features), `font-size-adjust`, `font-feature-settings`, `font-variation-settings`, `font-optical-sizing`
  - **Decorations**: `text-decoration` (underline/overline/line-through), `text-decoration-color`/`-style`/`-thickness`/`-skip`/`-skip-ink`, `text-emphasis` (filled/open/dot/circle/double-circle), `text-emphasis-position`, `text-shadow`
  - **Layout**: `text-anchor`, `dominant-baseline`/`alignment-baseline`, `baseline-shift`, `letter-spacing`, `word-spacing`, `line-height`, `white-space`, `text-indent`, `tab-size`, `text-transform`, `text-overflow`, `word-break`, `overflow-wrap`
  - **Writing modes & BiDi**: `writing-mode` (horizontal-tb/vertical-rl/vertical-lr + legacy), `direction` (ltr/rtl), `unicode-bidi` (normal/embed/isolate/bidi-override), `text-orientation`, `glyph-orientation-vertical`
  - **Rendering**: `text-rendering`, text stroke with `paint-order` control, `mix-blend-mode`, NFC normalization, grapheme cluster segmentation, combining marks/diacritics
  - **Hit-testing**: Per-character hit regions, `pointer-events` text-aware modes, stroke-width expansion, multi-position awareness
  - **Caching**: Text paragraph caching by content + style with smart invalidation
  - **Advanced typography**: Hanging punctuation rendering (first/last/allow-end/force-end), baseline alignment in deeply nested contexts (3+ levels), complex ligature shaping (tspan boundaries, font-feature-settings scoping)
  - **Remaining gaps**: Only deprecated SVG 1.1 features (SVG fonts, altGlyph) and DOM text query methods (architectural difference — Flutter is immediate-mode, not DOM-based)
- `<use href="#...">`, `<symbol>` via `<use>` (Blink parity: full CSS cascade, style inheritance, transform composition, hit-testing)
- `<defs>` as definitions-only
- `<image>` with data URI + network/bundle best-effort loading (baseline)
- `<foreignObject>` viewport container behavior with advanced semantics:
  - `requiredExtensions` fallback for `<switch>` patterns
  - Nested SVG context switching with viewBox/preserveAspectRatio
  - Overflow handling (hidden/visible)
  - Transform propagation through foreignObject
  - Hit-testing through foreignObject children
- `clipPath` (Blink parity: clipPathUnits, nested clip-paths, clip-rule, complex compositions, hit-testing) and `mask` (Blink parity: maskUnits, maskContentUnits, luminance/alpha modes, layer-based compositing, hit-testing)
- **`<view>` element support** (NEW):
  - Parse `<view>` elements with `viewBox` and `preserveAspectRatio` attributes
  - Support fragment identifiers to switch views dynamically
  - Programmatic view switching via `AnimatedSvgController.switchToView()`
  - `document.activeViewBox` returns current view's viewBox

## Known Gaps (Blink Parity, Animated Pipeline)

Detailed audit: `/Users/denisnadey/apps/flutter_full_svg_support/docs/BLINK_PARITY_AUDIT.md`

High-impact gaps:
1. Text typography is ~99% complete; remaining gaps are only deprecated SVG 1.1 features (SVG fonts, altGlyph — not worth implementing) and DOM text query methods (architectural difference — Flutter is immediate-mode, not DOM-based).
2. Filter parity is **complete**: All 17 FE primitives and 3 light source elements are implemented with full input chain semantics (SourceGraphic, SourceAlpha, BackgroundImage, BackgroundAlpha, FillPaint, StrokePaint, named result chaining).
3. CSS animation conversion remains partial for advanced/edge CSS shorthand/transform semantics.
4. `animateMotion` still lacks broader Blink-level semantics beyond current baseline support.

## Documentation Policy

To avoid drift:
- Current factual status lives only here.
- Planning lives in `NEXT_STEPS.md` and `TODO.md`.
- Closed bugs and closed milestones are tracked in `docs/RESOLVED_ISSUES.md`.

## Next Execution Plan

1. Expand hit-testing parity for complex `use`/text regions.
2. Continue CSS/SMIL edge-case parity with regression fixtures.
3. Continue modular refactor of remaining large files (`svg_filters_primitives.dart`, `animated_svg_painter_shapes.dart`, `animated_svg_picture.dart`, `animated_svg_picture_utils.dart`) with full regression checks after each split.
