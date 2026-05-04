# full_svg_flutter

[![Pub](https://img.shields.io/pub/v/full_svg_flutter.svg)](https://pub.dev/packages/full_svg_flutter)
[![Pub Points](https://img.shields.io/pub/points/full_svg_flutter)](https://pub.dev/packages/full_svg_flutter/score)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.32-blue.svg)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios%20%7C%20macos%20%7C%20windows%20%7C%20linux%20%7C%20web-lightgrey)](https://pub.dev/packages/full_svg_flutter)

**Animated SVG renderer for Flutter** — SMIL, CSS keyframes, path morphing, filters, masks, text, and playback control.

Use animated SVG files directly in Flutter without converting them to Lottie, Rive, GIF, WebP, or rendering them inside a WebView.

`full_svg_flutter` is designed as a full SVG runtime for Flutter and a migration path from `flutter_svg`: keep the familiar `SvgPicture`-style API while gaining support for animated SVG content through `FSvgPicture`.

---

<div align="center">

| Spinner (SMIL) | Heartbeat (dash animation) | Path morphing | Filter stack |
|:-:|:-:|:-:|:-:|
| <img src="assets/demo_spinner.svg" width="80" alt="Spinner SVG animation"/> | <img src="assets/demo_pulse.svg" width="160" alt="Pulse SVG dash animation"/> | <img src="assets/demo_morph.svg" width="80" alt="SVG path morphing"/> | <img src="assets/demo_filters.svg" width="200" alt="SVG filter effects"/> |

*All four are live SVG files — no GIFs, no Lottie, no third-party runtimes.*

</div>

---

## Animated SVG in Flutter

Flutter's standard SVG packages are excellent for static vector graphics, but animated SVG is a different rendering problem. Animated SVG files may contain SMIL elements, CSS `@keyframes`, animated transforms, opacity transitions, stroke-dash animations, path morphing, masks, gradients, filters, and timeline-based sequencing.

`full_svg_flutter` focuses on rendering SVG **as SVG** inside Flutter. You can use animated SVG assets directly — the ones exported from design tools, downloaded from icon libraries, or crafted by hand — without an additional conversion step.

There are several ways to use animated vector graphics in Flutter: static SVG packages, Lottie/Rive conversion, WebView rendering, and SVG-focused animation renderers. `full_svg_flutter` focuses on keeping SVG as SVG.

---

## Quick start

```yaml
# pubspec.yaml
dependencies:
  full_svg_flutter: ^1.0.2
```

```dart
import 'package:full_svg_flutter/full_svg_flutter.dart';

// static or animated — same widget, zero config
FSvgPicture.asset('assets/logo.svg')
FSvgPicture.asset('assets/spinner.svg')        // auto-detects and plays animations
FSvgPicture.network('https://example.com/animated.svg')
FSvgPicture.string(rawSvgString)
FSvgPicture.file(file)
FSvgPicture.memory(bytes)
```

---

## Comparison

| Feature | full_svg_flutter | flutter_svg | Lottie / Rive |
|---|:---:|:---:|:---:|
| Static SVG rendering | ✅ | ✅ | ❌ needs conversion |
| Animated SVG (SMIL) | ✅ | ❌ | ❌ needs conversion |
| CSS `@keyframes` in SVG | ✅ | ❌ | ❌ needs conversion |
| Path morphing | ✅ | ❌ | ❌ needs conversion |
| SVG filters (all 17 primitives) | ✅ | ⚠️ partial | varies |
| Clipping & masking | ✅ | ✅ | varies |
| Gradients | ✅ | ✅ | varies |
| Text rendering | ✅ | ⚠️ partial | varies |
| Playback control (play/pause/seek) | ✅ | ❌ | ✅ |
| No asset conversion required | ✅ | ✅ | ❌ |
| No WebView | ✅ | ✅ | ✅ |
| flutter_svg drop-in migration | ✅ | — | ❌ |
| Desktop (macOS / Windows / Linux) | ✅ | ✅ | varies |

> "⚠️ partial" means the feature exists but coverage or fidelity may be limited.

---

## Why not just use flutter_svg?

`flutter_svg` is a solid choice for static SVG icons and illustrations. If your SVG files are static, `flutter_svg` works well and is widely used.

However, animated SVG is a broader rendering problem. Animated SVG files rely on:

- SMIL `<animate>`, `<animateTransform>`, `<animateMotion>`, `<set>` elements
- CSS `@keyframes` and `animation-*` properties
- Path interpolation (path morphing between shapes)
- Timeline control (begin/end/dur/repeatCount)
- Filter primitives that change over time
- Opacity, transform, and stroke animations

`flutter_svg` does not implement these features. `full_svg_flutter` is built for cases where SVG animation should remain SVG animation.

---

## Why not convert animated SVG to Lottie or Rive?

Converting SVG animations to Lottie or Rive can work well for many projects, but it adds an authoring step and may not preserve all SVG-specific behavior.

`full_svg_flutter` is useful when you want to:

- keep SVG as the source of truth
- load existing SVG assets directly from disk or network
- preserve SMIL/CSS animation semantics where supported
- avoid a WebView for rendering
- avoid GIF/WebP fallbacks
- use one Flutter widget for both static and animated SVG content

---

## Migration from flutter_svg

For static SVGs, migration is a one-line import change:

```dart
// Before
import 'package:flutter_svg/flutter_svg.dart';
SvgPicture.asset('assets/icon.svg');

// After
import 'package:full_svg_flutter/full_svg_flutter.dart';
SvgPicture.asset('assets/icon.svg');   // identical signature, works as-is
```

`SvgPicture` is re-exported with the same API as `flutter_svg`. `ColorMapper`, all loaders, and all constructor signatures are unchanged.

For animated SVGs, switch to `FSvgPicture`:

```dart
// Works for both static and animated SVG — same widget, no manual switching
FSvgPicture.asset('assets/spinner.svg', width: 48, height: 48)
FSvgPicture.asset('assets/hero.svg', colorFilter: ColorFilter.mode(color, BlendMode.srcIn))
```

See [`doc/migration_from_flutter_svg.md`](doc/migration_from_flutter_svg.md) for a detailed migration guide.

---

## The main widget: `FSvgPicture`

`FSvgPicture` detects animation markers at parse time (`<animate>`, `<animateTransform>`, CSS `animation`, `@keyframes`, etc.) and automatically routes to the correct renderer. No manual switching required.

```dart
FSvgPicture.asset(
  'assets/hero.svg',
  autoPlay: false,
  playbackRate: 0.5,
  initialTime: const Duration(milliseconds: 300),
  width: 200,
  height: 200,
  fit: BoxFit.contain,
  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
  semanticsLabel: 'Hero illustration',
  placeholderBuilder: (context) => const CircularProgressIndicator(),
)
```

Animation control parameters are always available and are no-ops when the SVG has no animations.

---

## Playback control: `AnimatedSvgController`

For programmatic animation control, use `AnimatedSvgPicture` directly and attach a controller.

```dart
final controller = AnimatedSvgController();

@override
void dispose() {
  controller.dispose(); // extends ChangeNotifier
  super.dispose();
}
```

```dart
AnimatedSvgPicture.asset(
  'assets/loader.svg',
  controller: controller,
  autoPlay: false,
)
```

### Play / pause

```dart
controller.pause();
controller.resume();
controller.togglePlayPause();

bool isPaused = controller.isPaused;
```

### Seek

```dart
controller.seek(const Duration(seconds: 2));
controller.restart();   // seek to zero + unpause
```

### Speed

```dart
controller.setPlaybackRate(2.0);    // 2× speed
controller.setPlaybackRate(0.25);   // slow motion
double rate = controller.playbackRate;
```

### Direction

```dart
controller.reverse();
controller.forward();
controller.toggleDirection();
bool isReversed = controller.isReversed;
```

### SVG `<view>` navigation

```dart
print(controller.availableViews);   // ['intro', 'loop', 'outro']
controller.switchToView('loop');
controller.switchToView(null);      // back to root viewBox
```

### State changes

```dart
controller.addListener(() {
  setState(() {});
});
```

---

## Supported SVG features

| SVG feature | Status |
|---|---|
| Basic shapes (rect, circle, ellipse, line, polyline, polygon) | ✅ Supported |
| Paths (`<path d="...">`) | ✅ Supported |
| Groups (`<g>`) and `<use>` / `<symbol>` / `<defs>` | ✅ Supported |
| Transforms (translate, rotate, scale, skew, matrix) | ✅ Supported |
| Linear & radial gradients (focal point, gradientUnits) | ✅ Supported |
| Patterns | ✅ Supported |
| Clip paths (`clipPathUnits`, nested, `clip-rule`) | ✅ Supported |
| Masks (`maskUnits`, `maskContentUnits`, luminance/alpha) | ✅ Supported |
| SMIL `<animate>` | ✅ Supported |
| SMIL `<animateTransform>` | ✅ Supported |
| SMIL `<animateMotion>` + `<mpath>` | ✅ Supported |
| SMIL `<set>` and `<animateColor>` | ✅ Supported |
| SMIL timing (begin/end/dur/repeatCount, syncbase, events) | ✅ Supported |
| SMIL calcMode (linear, discrete, spline, paced) | ✅ Supported |
| SMIL additive / accumulate | ✅ Supported |
| CSS `@keyframes` | ✅ Supported |
| CSS `animation-*` properties | ✅ Supported |
| CSS transitions | ✅ Supported |
| CSS 3D transforms (`translate3d`, `rotate3d`, `matrix3d`) | ✅ Supported |
| CSS `calc()` and `var()` | ✅ Supported |
| CSS `@media` queries | ✅ Supported |
| CSS selectors (combinators, attribute, `:nth-child`, `:not()`) | ✅ Supported |
| Path morphing (shape interpolation) | ✅ Supported |
| SVG filters — all 17 FE primitives | ✅ Supported |
| Text (`<text>`, `<tspan>`, `textPath`, multi-position) | ✅ Supported |
| Bidi / RTL text | ✅ Supported |
| Text decorations, writing-mode, emphasis | ✅ Supported |
| Markers | ✅ Supported |
| `<image>` (asset, http/https, data URI, file://) | ✅ Supported |
| `<foreignObject>` | ⚠️ Partial |
| `<switch>` and `systemLanguage` | ✅ Supported |
| Hit-testing across 12 element types | ✅ Supported |
| `<a>` with `onLinkTap` | ✅ Supported |
| Accessibility (`<title>`, `<desc>`, ARIA) | ✅ Supported |
| JavaScript inside SVG | ❌ Not supported |
| External cross-origin resources | ❌ Restricted by platform policy |

---

## SVGator and exported animated SVG files

Many animated SVG files exported from tools such as SVGator use SMIL, CSS keyframes, transforms, opacity animation, stroke-dash animation, or path changes. `full_svg_flutter` is designed to load these files directly where the used SVG features are within the supported subset.

SVGator export settings vary — some outputs rely heavily on JavaScript-driven animation, which is not supported. If an exported file does not render correctly, the SMIL or CSS export mode (without JavaScript) is likely to work better. Open an issue with a minimal SVG sample if you run into problems.

---

## Limitations

`full_svg_flutter` aims to cover a broad subset of browser-style SVG rendering, but it is not a full browser engine.

Known limitations:

- JavaScript inside SVG files is not executed
- External cross-origin resources follow Flutter's platform security policy
- Some advanced SVG filter combinations may render differently from browsers
- Complex text layout (especially RTL mixed with LTR in a single `<text>`) may differ from browser engines in edge cases
- `<foreignObject>` content is not rendered (the element is parsed but its content is ignored)
- Malformed SVG files may need preprocessing before use

---

## Installation

```yaml
dependencies:
  full_svg_flutter: ^1.0.2
```

```bash
flutter pub add full_svg_flutter
```

---

## Render to canvas / image

```dart
import 'dart:ui' as ui;

final PictureInfo info = await vg.loadPicture(
  const SvgStringLoader('<svg>...</svg>'),
  null,
);

canvas.drawPicture(info.picture);

final ui.Image image = await info.picture.toImage(width, height);
info.picture.dispose();
```

---

## Performance

Gradient shaders, pattern images, text paragraphs, and hit-test geometry are cached with smart invalidation tied to animation frame changes.

Optional raster render strategy for `drawImage` performance on complex static content:

```dart
FSvgPicture.asset('assets/icon.svg', renderingStrategy: RenderingStrategy.raster)
```

---

## Precompiled SVGs (optional)

The `vector_graphics` backend supports binary compilation for faster first-frame parsing:

```sh
dart run vector_graphics_compiler -i assets/foo.svg -o assets/foo.svg.vec
```

```dart
import 'package:vector_graphics/vector_graphics.dart';

const Widget svg = SvgPicture(AssetBytesLoader('assets/foo.svg.vec'));
```

---

## ColorMapper

Fine-grained color substitution for theming and dynamic branding:

```dart
class ThemeColorMapper extends ColorMapper {
  const ThemeColorMapper(this.primary);
  final Color primary;

  @override
  Color substitute(String? id, String elementName, String attributeName, Color color) {
    if (color == const Color(0xFF0057FF)) return primary;
    return color;
  }
}

FSvgPicture.asset('assets/logo.svg', colorMapper: ThemeColorMapper(Theme.of(context).primaryColor))
```

---

## SVG feature coverage

| Category | Parity | What's covered |
|---|---|---|
| Geometry | ~95% | All 8 shapes, markers, patterns, gradients (linear/radial, focal point) |
| Text & Typography | **~99%** | Multi-position x/y/dx/dy, per-char rotate, textPath, writing-mode, decorations, bidi, emphasis, shadow, font-variant, paint-order stroke, NFC, grapheme clusters, hanging punctuation, baseline alignment, ligature shaping |
| SMIL Animation | ~95% | `<animate>` `<animateTransform>` `<animateMotion>` `<set>` `<animateColor>`, full timing/interpolation, event-based sync, calcMode (linear/discrete/spline/paced), additive/accumulate, `<mpath>` |
| CSS Animation | ~90% | `@keyframes`, `animation-*`, transitions, 3D transforms (`translate3d`, `rotate3d`, `matrix3d`, `perspective`), `calc()`, `var()`, `@media` |
| CSS Selectors | ~90% | Combinators, attribute selectors, `:hover :active :not() :nth-child() :nth-of-type() :empty :root`, specificity, `!important`, shorthand expansion |
| SVG Filters | **~97%** | All 17/17 FE primitives with actual math — Lambertian lighting, Blinn-Phong specular, bilinear displacement, full convolution kernel, turbulence noise |
| Clipping & Masking | **~100%** | Full Blink parity: clipPathUnits, nested clip-paths, clip-rule, maskUnits, maskContentUnits, luminance/alpha, layer compositing |
| Interaction | ~85% | Hit-testing across 12 element types, pointer-events, `<a>` with onLinkTap, `<view>` fragment identifiers, per-character text hit regions |
| Accessibility | ~80% | `<title>`/`<desc>` → Semantics label/hint, ARIA attributes, Flutter Semantics flags |
| Structural | ~85% | `use`/`symbol`/`defs`/`view`/`a`/`switch`/`foreignObject` with full CSS cascade |

### 17/17 SVG filter primitives

`feGaussianBlur` · `feColorMatrix` · `feBlend` (all SVG2 modes) · `feComposite` (arithmetic) · `feMorphology` · `feDisplacementMap` (bilinear) · `feDiffuseLighting` (Lambertian per-pixel) · `feSpecularLighting` (Blinn-Phong per-pixel) · `feConvolveMatrix` (actual kernel math) · `feTurbulence` · `feComponentTransfer` (5 function types) · `feOffset` · `feFlood` · `feMerge` · `feTile` · `feDropShadow` · `feImage`

---

## Test suite

> **250+ test files. W3C SVG 1.1 conformance suite. Visual golden regression. Animation integration tests.**

| Layer | What it covers |
|---|---|
| **Unit** | Every parser, interpolator, filter primitive, CSS property, text layout algorithm, hit-test geometry — individually |
| **W3C conformance** | Official W3C SVG 1.1 test suite golden comparisons — the same tests browsers run |
| **Visual goldens** | Pixel-level regression for complex renders: filters, blend modes, clipping, text on path |
| **Animation integration** | Full SMIL timing engine: syncbase, event offsets, calcMode, accumulate, `<mpath>` path follow |

Selected test coverage (from `test/`):

- **SMIL**: `smil_test.dart`, `smil_timing_precision_test.dart`, `smil_keypoints_timing_test.dart`, `smil_path_morphing_integration_test.dart`, `animate_motion_advanced_test.dart`
- **CSS**: `css_animations_test.dart`, `css_3d_transforms_test.dart`, `css_variables_calc_test.dart`, `css_cascade_specificity_test.dart`, `css_nth_selectors_test.dart`
- **Filters**: `filters_test.dart`, `fe_lighting_test.dart`, `fe_convolve_matrix_test.dart`, `filter_displacement_tile_test.dart`, `turbulence_edge_cases_test.dart`
- **Text**: `text_typography_parity_test.dart`, `text_bidi_complex_scripts_test.dart`, `text_ligature_shaping_test.dart`, `text_path_precision_test.dart`
- **Clipping/Masking**: `advanced_clip_mask_composition_test.dart`, `mask_pipeline_test.dart`, `clip_path_advanced_test.dart`
- **Geometry**: `path_morphing_correctness_test.dart`, `geometry_edge_cases_test.dart`, `gradient_pattern_units_test.dart`, `marker_test.dart`
- **Hit-testing**: `hit_test_advanced_features_test.dart`, `hit_test_precision_test.dart`, `hit_test_deep_nesting_test.dart`
- **Regression**: `regression_animation_edge_cases_test.dart`, `regression_filter_edge_cases_test.dart`, `regression_text_edge_cases_test.dart`

---

## Performance benchmarks

A reproducible benchmark suite in [`benchmarks/`](benchmarks/) measures frame stability, parse speed, memory usage, and SVG feature compatibility.

Benchmarks cover:

- Cold SVG parse / warm cached render
- Static icon grids (100–500 items)
- Scroll stress tests (200 SVG items)
- SMIL / CSS animation frame stability
- Filter-heavy SVGs
- `picture` vs `raster` rendering strategy

```bash
# macOS — no device needed
./benchmarks/scripts/run_macos.sh

# Android
./benchmarks/scripts/run_android.sh

# Pure Dart parser microbenchmarks (no Flutter required)
./benchmarks/scripts/run_parser_benchmarks.sh

# Generate HTML + Markdown report from collected results
dart run benchmarks/scripts/generate_report.dart
```

See [`benchmarks/README.md`](benchmarks/README.md) for full methodology and how to interpret UI-thread vs raster-thread numbers.

---

## FAQ

### Does Flutter support animated SVG natively?

Flutter can render vector graphics, but animated SVG requires runtime support for SMIL, CSS `@keyframes`, animated transforms, and path interpolation. `full_svg_flutter` is built specifically for this use case.

### Does flutter_svg support SVG animations?

`flutter_svg` is focused on static SVG rendering. If your SVG contains SMIL or CSS animations, you need a package like `full_svg_flutter`, a Lottie/Rive conversion workflow, or a WebView.

### Can I use animated SVG in Flutter without Lottie?

Yes. `full_svg_flutter` renders SVG animation directly inside Flutter where the used SVG features are supported — no conversion step needed.

### Can I use animated SVG in Flutter without Rive?

Yes. Rive is a great animation tool, but if your asset is already SVG, `full_svg_flutter` lets you keep SVG as the source format without a roundtrip conversion.

### Can I use animated SVG in Flutter without a WebView?

Yes. `full_svg_flutter` renders inside Flutter's own painting layer. No `webview_flutter`, no platform views.

### Does this package work with SVGator exports?

It depends on the SVGator export mode. SMIL and CSS export modes generally work. JavaScript-driven animations are not supported. Use SMIL or CSS export if available.

### Is this a drop-in replacement for flutter_svg?

For static SVGs — yes, `SvgPicture` is re-exported with the same API. For animated SVGs, use `FSvgPicture` or `AnimatedSvgPicture` instead.

### Does this package use a WebView?

No. Rendering happens entirely inside Flutter's painting infrastructure.

### What platforms are supported?

Android, iOS, macOS, Windows, Linux, and Web (file:// URIs are web-only disabled; everything else works).

---

## More documentation

- [`doc/migration_from_flutter_svg.md`](doc/migration_from_flutter_svg.md) — Step-by-step migration guide
- [`doc/supported_features.md`](doc/supported_features.md) — Detailed SVG feature compatibility matrix
- [`doc/limitations.md`](doc/limitations.md) — Known limitations and workarounds
- [`benchmarks/README.md`](benchmarks/README.md) — Benchmark methodology and results

---

## SVG attribution

SVGs in `/assets/w3samples` — [W3 sample files](https://dev.w3.org/SVG/tools/svgweb/samples/svg-files/)

SVGs in `/assets/wikimedia` — [Wikimedia Commons](https://commons.wikimedia.org/wiki/Main_Page)

Android Drawables in `/assets/android_vd` — Android Documentation

The Flutter Logo is based on the Flutter Logo Widget © Google.

The Dart logo — [dartlang.org](https://github.com/dart-lang/site-shared/blob/master/src/_assets/images/dart/logo%2Btext/horizontal/original.svg) © Google

SVGs in `/assets/noto-emoji` — [Google i18n noto-emoji](https://github.com/googlei18n/noto-emoji), Apache license.
