# full_svg_flutter

[![Pub](https://img.shields.io/pub/v/full_svg_flutter.svg)](https://pub.dev/packages/full_svg_flutter)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.32-blue.svg)](https://flutter.dev)

**The most complete SVG renderer for Flutter.** Not a subset. Not an approximation.

Static rendering with `SvgPicture`, animated rendering with `AnimatedSvgPicture` — two pipelines, one package, one import.

---

<div align="center">

| Spinner (SMIL) | Heartbeat (dash animation) | Path morphing (SMIL) | Filter stack |
|:-:|:-:|:-:|:-:|
| <img src="assets/demo_spinner.svg" width="80" alt="Spinner"/> | <img src="assets/demo_pulse.svg" width="160" alt="Pulse"/> | <img src="assets/demo_morph.svg" width="80" alt="Morph"/> | <img src="assets/demo_filters.svg" width="200" alt="Filters"/> |

*All four are SVG files rendered by `AnimatedSvgPicture` — no GIFs, no Lottie, no third-party runtimes.*

</div>

---

## Drop-in replacement for `flutter_svg`

The API surface is intentionally identical. Migrating is a one-line change:

```dart
// Before
import 'package:flutter_svg/flutter_svg.dart';

// After — same widget, same parameters
import 'package:full_svg_flutter/full_svg_flutter.dart';
```

`SvgPicture.asset()`, `SvgPicture.network()`, `SvgPicture.string()`, `SvgPicture.memory()`, `ColorMapper`, loaders — all signatures match. Swap the import, get the rest for free.

---

## Installation

```yaml
dependencies:
  full_svg_flutter: ^1.0.0
```

---

## Basic usage

```dart
// Static SVG — identical to flutter_svg
SvgPicture.asset('assets/logo.svg')
SvgPicture.network('https://example.com/icon.svg', semanticsLabel: 'icon')
SvgPicture.string('<svg>...</svg>', width: 200)

// Tinting
SvgPicture.asset(
  'assets/icon.svg',
  colorFilter: const ColorFilter.mode(Colors.blue, BlendMode.srcIn),
)

// Custom color mapping
SvgPicture.asset('assets/branded.svg', colorMapper: const MyColorMapper())
```

## Animated SVG

```dart
// Plays SMIL/CSS animations automatically
AnimatedSvgPicture.asset('assets/spinner.svg')
AnimatedSvgPicture.network('https://example.com/chart.svg')

// Manual playback control
final controller = SvgAnimationController();

AnimatedSvgPicture.asset(
  'assets/logo.svg',
  controller: controller,
  autoplay: false,
)

controller.play();
controller.pause();
controller.seek(const Duration(milliseconds: 500));
```

## Render to canvas / image

```dart
import 'dart:ui' as ui;

final PictureInfo info = await vg.loadPicture(
  const SvgStringLoader('<svg>...</svg>'),
  null,
);

canvas.drawPicture(info.picture);

// Or export as image
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

The test suite is organized into four layers:

| Layer | What it covers |
|---|---|
| **Unit** | Every parser, interpolator, filter primitive, CSS property, text layout algorithm, hit-test geometry — individually |
| **W3C conformance** | Official W3C SVG 1.1 test suite golden comparisons — the same tests browsers run |
| **Visual goldens** | Pixel-level regression for complex renders: filters, blend modes, clipping, text on path |
| **Animation integration** | Full SMIL timing engine: syncbase, event offsets, calcMode, accumulate, `<mpath>` path follow |

Selected test coverage (from `test/unit/`):

- **SMIL**: `smil_test.dart`, `smil_edge_cases_test.dart`, `smil_timing_precision_test.dart`, `smil_keypoints_timing_test.dart`, `smil_path_morphing_integration_test.dart`, `animate_motion_advanced_test.dart`
- **CSS**: `css_animations_test.dart`, `css_3d_transforms_test.dart`, `css_variables_calc_test.dart`, `css_cascade_specificity_test.dart`, `css_nth_selectors_test.dart`, `css_selectors_combinators_test.dart`
- **Filters**: `filters_test.dart`, `fe_lighting_test.dart`, `fe_convolve_matrix_test.dart`, `filter_displacement_tile_test.dart`, `filter_input_graph_advanced_test.dart`, `turbulence_edge_cases_test.dart`
- **Text**: `text_typography_parity_test.dart`, `text_bidi_complex_scripts_test.dart`, `text_ligature_shaping_test.dart`, `text_path_precision_test.dart`, `text_advanced_typography_features_test.dart`
- **Clipping/Masking**: `advanced_clip_mask_composition_test.dart`, `mask_pipeline_test.dart`, `clip_path_advanced_test.dart`
- **Geometry**: `path_morphing_correctness_test.dart`, `geometry_edge_cases_test.dart`, `gradient_pattern_units_test.dart`, `marker_test.dart`
- **Hit-testing**: `hit_test_advanced_features_test.dart`, `hit_test_precision_test.dart`, `hit_test_deep_nesting_test.dart`
- **Regression**: `regression_animation_edge_cases_test.dart`, `regression_filter_edge_cases_test.dart`, `regression_text_edge_cases_test.dart`

---

## Performance

Gradient shaders, pattern images, text paragraphs, and hit-test geometry are all cached with smart invalidation tied to animation frame change.

Optional `raster` render strategy for `drawImage` performance:

```dart
SvgPicture.asset('assets/icon.svg', renderStrategy: RenderStrategy.raster)
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

SvgPicture.asset('assets/logo.svg', colorMapper: ThemeColorMapper(Theme.of(context).primaryColor))
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

## Commemoration

This package was originally authored by [Dan Field](https://github.com/dnfield) and forked from [dnfield/flutter_svg](https://github.com/dnfield/flutter_svg). Dan was a member of the Flutter team at Google from 2018 until his death in 2024. His impact on Flutter was immeasurable. We honor his memory by continuing to develop and publish this package.
