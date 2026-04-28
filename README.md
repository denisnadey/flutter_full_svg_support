# full_svg_flutter

[![Pub](https://img.shields.io/pub/v/full_svg_flutter.svg)](https://pub.dev/packages/full_svg_flutter)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.32-blue.svg)](https://flutter.dev)

**The most complete SVG renderer for Flutter.** Not a subset. Not an approximation.

---

<div align="center">

| Spinner (SMIL) | Heartbeat (dash animation) | Path morphing | Filter stack |
|:-:|:-:|:-:|:-:|
| <img src="assets/demo_spinner.svg" width="80" alt="Spinner"/> | <img src="assets/demo_pulse.svg" width="160" alt="Pulse"/> | <img src="assets/demo_morph.svg" width="80" alt="Morph"/> | <img src="assets/demo_filters.svg" width="200" alt="Filters"/> |

*All four are live SVG files — no GIFs, no Lottie, no third-party runtimes.*

</div>

---

## The main widget: `FSvgPicture`

`FSvgPicture` is the recommended entry point. It loads any SVG, detects animation markers at runtime (`<animate>`, `<animateTransform>`, CSS `animation`, `@keyframes`, etc.), and automatically routes to the right renderer — no manual switching required.

```dart
import 'package:full_svg_flutter/full_svg_flutter.dart';

// Works for both static and animated SVGs — same widget, zero config
FSvgPicture.asset('assets/logo.svg')
FSvgPicture.asset('assets/spinner.svg')   // auto-detects animations, plays them
FSvgPicture.network('https://example.com/chart.svg')
FSvgPicture.string(rawSvgString)
FSvgPicture.file(file)
FSvgPicture.memory(bytes)
```

Animation control parameters are always available, no-op when the SVG has no animations:

```dart
FSvgPicture.asset(
  'assets/hero.svg',
  autoPlay: false,
  playbackRate: 0.5,        // half speed
  initialTime: Duration(milliseconds: 300),
  width: 200,
  height: 200,
  fit: BoxFit.contain,
  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
  semanticsLabel: 'Hero illustration',
  placeholderBuilder: (context) => const CircularProgressIndicator(),
)
```

---

## Drop-in replacement for `flutter_svg`

`SvgPicture` is also exported with the identical API to `flutter_svg`. One-line migration:

```dart
// Before
import 'package:flutter_svg/flutter_svg.dart';

// After
import 'package:full_svg_flutter/full_svg_flutter.dart';
```

`SvgPicture.asset()`, `SvgPicture.network()`, `SvgPicture.string()`, `SvgPicture.memory()`, `ColorMapper`, all loaders — signatures unchanged.

---

## Playback control: `AnimatedSvgController`

When you need programmatic control over animation — use `AnimatedSvgPicture` directly (not `FSvgPicture`) and attach a controller.

```dart
final controller = AnimatedSvgController();

@override
void dispose() {
  controller.dispose(); // AnimatedSvgController extends ChangeNotifier
  super.dispose();
}
```

```dart
AnimatedSvgPicture.asset(
  'assets/loader.svg',
  controller: controller,
  autoPlay: false,      // start paused
  playbackRate: 1.0,
)
```

### Play / pause

```dart
controller.pause();
controller.resume();
controller.togglePlayPause();  // flip current state

bool isPaused = controller.isPaused;
```

### Seek

```dart
controller.seek(const Duration(seconds: 2));
controller.restart();  // seek to zero + unpause
```

### Speed

```dart
controller.setPlaybackRate(2.0);   // 2× speed
controller.setPlaybackRate(0.25);  // slow motion
double rate = controller.playbackRate;
```

### Direction

```dart
controller.reverse();          // play backwards
controller.forward();          // back to normal
controller.toggleDirection();  // flip
bool isReversed = controller.isReversed;
```

### SVG `<view>` navigation

SVG files can define named viewports via the `<view>` element. The controller can switch between them at runtime:

```dart
// After the widget renders, available views are populated
print(controller.availableViews); // ['intro', 'loop', 'outro']

controller.switchToView('loop');
controller.switchToView(null);  // back to root viewBox
```

### Listening to state changes

`AnimatedSvgController` extends `ChangeNotifier`, so you can react to state changes:

```dart
controller.addListener(() {
  setState(() {}); // rebuild when paused/resumed/seeked
});
```

---

## Installation

```yaml
dependencies:
  full_svg_flutter: ^1.0.0
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

## Coverage

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

> **250+ unit test files. W3C SVG 1.1 conformance suite. Visual golden regression. Animation integration tests.**

| Layer | What it covers |
|---|---|
| **Unit** | Every parser, interpolator, filter primitive, CSS property, text layout algorithm, hit-test geometry — individually |
| **W3C conformance** | Official W3C SVG 1.1 test suite golden comparisons — the same tests browsers run |
| **Visual goldens** | Pixel-level regression for complex renders: filters, blend modes, clipping, text on path |
| **Animation integration** | Full SMIL timing engine: syncbase, event offsets, calcMode, accumulate, `<mpath>` path follow |

Selected test coverage (from `test/unit/`):

- **SMIL**: `smil_test.dart`, `smil_timing_precision_test.dart`, `smil_keypoints_timing_test.dart`, `smil_path_morphing_integration_test.dart`, `animate_motion_advanced_test.dart`
- **CSS**: `css_animations_test.dart`, `css_3d_transforms_test.dart`, `css_variables_calc_test.dart`, `css_cascade_specificity_test.dart`, `css_nth_selectors_test.dart`
- **Filters**: `filters_test.dart`, `fe_lighting_test.dart`, `fe_convolve_matrix_test.dart`, `filter_displacement_tile_test.dart`, `turbulence_edge_cases_test.dart`
- **Text**: `text_typography_parity_test.dart`, `text_bidi_complex_scripts_test.dart`, `text_ligature_shaping_test.dart`, `text_path_precision_test.dart`
- **Clipping/Masking**: `advanced_clip_mask_composition_test.dart`, `mask_pipeline_test.dart`, `clip_path_advanced_test.dart`
- **Geometry**: `path_morphing_correctness_test.dart`, `geometry_edge_cases_test.dart`, `gradient_pattern_units_test.dart`, `marker_test.dart`
- **Hit-testing**: `hit_test_advanced_features_test.dart`, `hit_test_precision_test.dart`, `hit_test_deep_nesting_test.dart`
- **Regression**: `regression_animation_edge_cases_test.dart`, `regression_filter_edge_cases_test.dart`, `regression_text_edge_cases_test.dart`

---

## Performance

Gradient shaders, pattern images, text paragraphs, and hit-test geometry are all cached with smart invalidation tied to animation frame change.

Optional `raster` render strategy for `drawImage` performance:

```dart
FSvgPicture.asset('assets/icon.svg', renderingStrategy: RenderingStrategy.raster)
```

---

## Precompiled SVGs (optional)

The `vector_graphics` backend supports binary compilation for faster parsing and overdraw optimization:

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

## SVG attribution

SVGs in `/assets/w3samples` — [W3 sample files](https://dev.w3.org/SVG/tools/svgweb/samples/svg-files/)

SVGs in `/assets/wikimedia` — [Wikimedia Commons](https://commons.wikimedia.org/wiki/Main_Page)

Android Drawables in `/assets/android_vd` — Android Documentation

The Flutter Logo is based on the Flutter Logo Widget © Google.

The Dart logo — [dartlang.org](https://github.com/dart-lang/site-shared/blob/master/src/_assets/images/dart/logo%2Btext/horizontal/original.svg) © Google

SVGs in `/assets/noto-emoji` — [Google i18n noto-emoji](https://github.com/googlei18n/noto-emoji), Apache license.

---

## Performance benchmarks

We maintain a reproducible benchmark suite in [`benchmarks/`](benchmarks/) that measures frame stability, parse speed, memory usage, and SVG feature compatibility against `flutter_svg`.

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

See [`benchmarks/README.md`](benchmarks/README.md) for the full methodology, scenario descriptions, and how to interpret UI-thread vs raster-thread numbers.

---

## Commemoration

This package was originally authored by [Dan Field](https://github.com/dnfield) and forked from [dnfield/flutter_svg](https://github.com/dnfield/flutter_svg). Dan was a member of the Flutter team at Google from 2018 until his death in 2024. His impact on Flutter was immeasurable. We honor his memory by continuing to develop and publish this package.
