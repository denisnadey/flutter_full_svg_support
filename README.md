# flutter_svg

[![Pub](https://img.shields.io/pub/v/flutter_svg.svg)](https://pub.dartlang.org/packages/flutter_svg)

<!-- markdownlint-disable MD033 -->
<img src="https://raw.githubusercontent.com/dnfield/flutter_svg/7d374d7107561cbd906d7c0ca26fef02cc01e7c8/example/assets/flutter_logo.svg?sanitize=true" width="200px" alt="Flutter Logo which can be rendered by this package!">
<!-- markdownlint-enable MD033 -->

The most comprehensive SVG rendering library for Flutter. Two pipelines: a battle-tested **static renderer** (`SvgPicture`) for production, and a full-featured **animated renderer** (`AnimatedSvgPicture`) with DOM preservation, SMIL animations, CSS interop, SVG filters, interactive hit-testing, and accessibility.

**~89-90% Blink SVG parity** | **4,145+ tests** | **0 analyzer warnings** | **200+ source modules**

## Parity Snapshot (March 2026)

| Category | Coverage | Key Details |
|---|---|---|
| Geometry Rendering | ~95% | All 8 shapes + markers + patterns + gradients |
| Text & Typography | **~99%** | Full positioning, textPath, writing-mode, decorations, bidi, emphasis, shadow, font-variant, paint-order stroke, hanging punctuation, deep baseline alignment, ligature shaping, per-character hit-testing |
| SMIL Animation | ~95% | 5 elements, full timing/interpolation, paced/spline/event-based, advanced animateMotion |
| CSS Animation Interop | ~90% | Selectors, cascade, structural pseudo-classes, variables, calc(), 3D transforms, @media |
| SVG Filters | **~97%** | 17/17 FE primitives with actual math (lighting, convolution, displacement, turbulence) |
| Clipping & Masking | **~100%** | Full Blink parity: clipPathUnits, nested clip-paths, maskUnits, luminance/alpha modes |
| Interaction & Events | ~85% | Hit-testing (12 element types), pointer-events, `<a>`, `<view>` |
| Accessibility | ~80% | title/desc, ARIA attributes, Flutter Semantics integration |
| Structural Elements | ~85% | use/symbol/defs/view/a/switch/foreignObject with full CSS cascade |
| External Content | ~70% | image (data/network/bundle), foreignObject viewport |

## Feature Highlights

### SMIL Animation Engine
`<animate>`, `<animateTransform>`, `<animateMotion>`, `<set>`, `<animateColor>` with offset/syncbase/event timing (`id.click`, `id.mouseover+200ms`), `calcMode` (linear/discrete/spline/paced), additive/accumulate, `keyPoints`/`rotate`, `<mpath>` references.

### CSS Animation & Keyframes
`@keyframes`, `animation-*` properties, CSS transitions, 3D transforms (`translate3d`, `rotate3d`, `matrix3d`, `perspective`), `calc()`, CSS custom properties (`var()`), `@media` queries (prefers-color-scheme, viewport).

### CSS Selectors & Cascade
Combinators (descendant/child/sibling), attribute selectors, pseudo-classes (`:hover`, `:active`, `:focus`, `:not()`, `:first-child`, `:last-child`, `:only-child`, `:nth-child`, `:nth-of-type`, `:empty`, `:root`), full specificity resolution, `!important`, shorthand expansion.

### 17/17 SVG Filter Primitives (~97% Parity)
feGaussianBlur, feColorMatrix, feBlend (SVG2 modes), feComposite (arithmetic), feMorphology, feDisplacementMap (bilinear interpolation), feDiffuseLighting (Lambertian per-pixel), feSpecularLighting (Blinn-Phong per-pixel), feConvolveMatrix (actual kernel), feTurbulence, feComponentTransfer (all 5 function types), feOffset, feFlood, feMerge, feTile, feDropShadow, feImage.

### Clipping & Masking (Full Blink Parity)
clipPathUnits (objectBoundingBox, userSpaceOnUse), nested clip-paths, clip-rule (nonzero, evenodd), maskUnits, maskContentUnits, luminance/alpha modes, layer compositing, hit-testing through clip/mask regions.

### Geometry & Paint Servers
All 8 SVG shapes. Linear/radial gradients (`gradientUnits`, focal point, stop animation), patterns (`patternUnits`/`patternContentUnits`/`patternTransform`), markers (`orient`/`markerUnits`/`viewBox`).

### Text & Typography (~99% Blink Parity)
Multi-position `x`/`y`/`dx`/`dy` lists, per-character `rotate`, `textLength`/`lengthAdjust`, `writing-mode`, `text-decoration`/`text-emphasis`/`text-shadow`, `textPath`, per-chunk `text-anchor`, `font-variant`/`font-feature-settings`/`font-variation-settings`, `unicode-bidi`, `font-stretch`, `paint-order` stroke, NFC normalization, grapheme cluster segmentation, hanging punctuation, deep baseline alignment, complex ligature shaping.

### Interactive Hit-Testing
`pointer-events` attribute (fill/stroke/painted/all/bounding-box/none), `<a>` anchor links with `onLinkTap`, `<view>` element with fragment identifiers, per-character text hit regions, stroke-width expansion.

### Accessibility
`<title>`/`<desc>` mapped to Semantics label/hint, ARIA (`aria-label`, `aria-describedby`, `role`) integrated with Flutter Semantics flags.

### Performance Caching
Gradient shaders, pattern images, text paragraphs, hit-test geometry - all cached with smart invalidation on animation time change.

### 30+ CSS/SVG Presentation Attributes
`paint-order`, `vector-effect`, `shape-rendering`, `overflow`, `mix-blend-mode`, `currentColor`, `transform-origin`, `color-interpolation`, `font-variant`, `xml:space`, `direction`, `pathLength`, `cursor`, `white-space`, `unicode-bidi`, `font-stretch`, and more.

## Remaining Work (Q2 2026)

Active P0 priorities to reach 95%+ Blink parity:

1. **Remaining filter primitive edge cases** - feMorphology advanced modes, feTurbulence stitchTiles refinements
2. **Performance benchmarking suite** - Comprehensive render benchmarks, cache profiling, memory analysis
3. **Code modularization** - Remaining large files (`animated_svg_painter_shapes.dart`, `animated_svg_picture.dart`)
4. **Golden test coverage expansion** - Additional regression fixtures for edge cases

Execution plan for current W3C closure work:

- [docs/W3C_GAP_CLOSURE_PLAN.md](docs/W3C_GAP_CLOSURE_PLAN.md) - Chromium-driven case-by-case closure algorithm, priority waves, and threshold policy

See [CURRENT_STATUS.md](CURRENT_STATUS.md) for factual status and [docs/BLINK_PARITY_AUDIT.md](docs/BLINK_PARITY_AUDIT.md) for the Blink gap matrix.

## Chromium/Blink Source Notes (Local Dev)

Reference locations used for parity debugging in this workspace:

- Active Chromium tree (downloaded snapshot): `/Users/denisnadey/Downloads/chromium-main/third_party/blink`
- Historical pinned Blink snapshot in repo: `/Users/denisnadey/apps/flutter_full_svg_support/blink-b87d44f-Source-core-svg`
- Skia location expected by Blink lighting/filter paths: `/Users/denisnadey/Downloads/chromium-main/third_party/skia`

Important: if Chromium was downloaded from `https://github.com/chromium/chromium/tree/main` as a zip, it is not a git repo, so `git submodule update --init --recursive` will not work there.

### How To "Hydrate" Missing Submodules In Zip Snapshot

If a submodule path is empty (for example `third_party/skia`), clone it directly using URL from `.gitmodules`:

```bash
cd /Users/denisnadey/Downloads/chromium-main

# Example: hydrate one missing submodule
SUB=third_party/skia
URL=$(awk -v p="$SUB" '$1=="path" && $3==p {f=1;next} f&&$1=="url"{print $3;exit}' .gitmodules)
rm -rf "$SUB"
git clone --depth 1 --filter=blob:none "$URL" "$SUB"
```

Repeat with another `SUB=...` path as needed.

### Full Git Checkout Option (If Needed Later)

If you want native submodule commands, use a real git checkout instead of zip snapshot:

```bash
git clone --depth 1 --filter=blob:none https://github.com/chromium/chromium.git /Users/denisnadey/Downloads/chromium-main-git
cd /Users/denisnadey/Downloads/chromium-main-git
git submodule sync --recursive
git submodule update --init --recursive --depth 1 --jobs 8
```

## Getting Started

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_svg: ^2.2.2
```

### Basic Usage

Create an SVG rendering widget from an asset:

<?code-excerpt "example/lib/readme_excerpts.dart (SimpleAsset)"?>
```dart
const String assetName = 'assets/dart.svg';
final Widget svg = SvgPicture.asset(assetName, semanticsLabel: 'Dart Logo');
```

You can color/tint the image like so:

<?code-excerpt "example/lib/readme_excerpts.dart (ColorizedAsset)"?>
```dart
const String assetName = 'assets/simple/dash_path.svg';
final Widget svgIcon = SvgPicture.asset(
  assetName,
  colorFilter: const ColorFilter.mode(Colors.red, BlendMode.srcIn),
  semanticsLabel: 'Red dash paths',
);
```

For more advanced color manipulation, you can use the `colorMapper` property.
This allows you to define a custom mapping function that will be called for
every color encountered during SVG parsing, enabling you to substitute colors
based on various criteria like the color value itself, the element name, or the
attribute name.

To use this feature, you need to create a class that extends `ColorMapper` and
override the `substitute` method.

Here's an example of how to implement a `ColorMapper` to replace specific colors in an SVG:

<?code-excerpt "example/lib/readme_excerpts.dart (ColorMapper)"?>
```dart
class _MyColorMapper extends ColorMapper {
  const _MyColorMapper();

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (color == const Color(0xFFFF0000)) {
      return Colors.blue;
    }
    if (color == const Color(0xFF00FF00)) {
      return Colors.yellow;
    }
    return color;
  }
}
// ···
  const String svgString = '''
<svg viewBox="0 0 100 100">
  <rect width="50" height="50" fill="#FF0000" />
  <circle cx="75" cy="75" r="25" fill="#00FF00" />
</svg>
''';
  final Widget svgIcon = SvgPicture.string(
    svgString,
    colorMapper: const _MyColorMapper(),
  );
```

In this example, all red colors in the SVG will be rendered as blue, and all green colors will be rendered as yellow. You can customize the `substitute` method to implement more complex color mapping logic based on your requirements.

The default placeholder is an empty box (`LimitedBox`) - although if a `height`
or `width` is specified on the `SvgPicture`, a `SizedBox` will be used instead
(which ensures better layout experience). There is currently no way to show an
Error visually, however errors will get properly logged to the console in debug
mode.

You can also specify a placeholder widget. The placeholder will display during
parsing/loading (normally only relevant for network access).

<?code-excerpt "example/lib/readme_excerpts.dart (MissingAsset)"?>
```dart
// Will print error messages to the console.
const String assetName = 'assets/image_that_does_not_exist.svg';
final Widget svg = SvgPicture.asset(assetName);
```

<?code-excerpt "example/lib/readme_excerpts.dart (AssetWithPlaceholder)"?>
```dart
final Widget networkSvg = SvgPicture.network(
  'https://site-that-takes-a-while.com/image.svg',
  semanticsLabel: 'A shark?!',
  placeholderBuilder: (BuildContext context) => Container(
    padding: const EdgeInsets.all(30.0),
    child: const CircularProgressIndicator(),
  ),
);
```

If you'd like to render the SVG to some other canvas, you can do something like:

<?code-excerpt "example/lib/readme_excerpts.dart (OutputConversion)"?>
```dart
import 'dart:ui' as ui;

// ···
  const String rawSvg = '''<svg ...>...</svg>''';
  final PictureInfo pictureInfo = await vg.loadPicture(
    const SvgStringLoader(rawSvg),
    null,
  );

  // You can draw the picture to a canvas:
  canvas.drawPicture(pictureInfo.picture);

  // Or convert the picture to an image:
  final ui.Image image = await pictureInfo.picture.toImage(width, height);

  pictureInfo.picture.dispose();
```

The `SvgPicture` helps to automate this logic, and it provides some convenience
wrappers for getting assets from multiple sources.

This package now supports a render strategy setting, allowing certain
applications to achieve better performance when needed. By default, the
rendering uses the original `picture` mode, which retains full flexibility in
scaling. Alternatively, when using the `raster` strategy, the SVG data is
rendered into an `Image`, which is then drawn using drawImage. This approach may
sacrifice some flexibility—especially around resolution scaling—but can
significantly improve rendering performance in specific use cases.

## Precompiling and Optimizing SVGs

The vector_graphics backend supports SVG compilation which produces a binary
format that is faster to parse and can optimize SVGs to reduce the amount of
clipping, masking, and overdraw. The SVG compilation is provided by
[`package:vector_graphics_compiler`](https://pub.dev/packages/vector_graphics_compiler).

```sh
dart run vector_graphics_compiler -i assets/foo.svg -o assets/foo.svg.vec
```

The output `foo.svg.vec` can be loaded using the default constructor of
`SvgPicture`.

<?code-excerpt "example/lib/readme_excerpts.dart (PrecompiledAsset)"?>
```dart
import 'package:vector_graphics/vector_graphics.dart';
// ···
  const Widget svg = SvgPicture(AssetBytesLoader('assets/foo.svg.vec'));
```

### Check SVG compatibility

An SVG can be tested for compatibility with the vector graphics backend by
running the compiler locally to see if any errors are thrown.

```sh
dart run vector_graphics_compiler -i $SVG_FILE -o $TEMPORARY_OUTPUT_TO_BE_DELETED --no-optimize-masks --no-optimize-clips --no-optimize-overdraw --no-tessellate
```

## Recommended Adobe Illustrator SVG Configuration
- In Styling: choose Presentation Attributes instead of Inline CSS because CSS is not fully supported.
- In Images: choose Embded not Linked to other file to get a single svg with no dependency to other files.
- In Objects IDs: choose layer names to add every layer name to svg tags or you can use minimal,it is optional.
![Export configuration](https://user-images.githubusercontent.com/2842459/62599914-91de9c00-b8fe-11e9-8fb7-4af57d5100f7.png)

## Contributing

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for development guidelines, testing workflows, and architecture details.

### Project Navigation

| Document | Purpose |
|---|---|
| [CURRENT_STATUS.md](CURRENT_STATUS.md) | Single source of truth for project state |
| [ROADMAP.md](ROADMAP.md) | Living roadmap with priorities and milestones |
| [NEXT_STEPS.md](NEXT_STEPS.md) | P0/P1/P2 priorities and execution order |
| [TODO.md](TODO.md) | Active work queue (P0-P4 items) |
| [ANIMATION.md](ANIMATION.md) | SMIL/CSS animation usage guide with examples |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Dual pipeline design rationale |
| [docs/BLINK_PARITY_AUDIT.md](docs/BLINK_PARITY_AUDIT.md) | Gap matrix vs Blink SVG features |
| [docs/W3C_GAP_CLOSURE_PLAN.md](docs/W3C_GAP_CLOSURE_PLAN.md) | Active W3C closure plan (Chromium-guided + diff-measured thresholds) |
| [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md) | Full documentation navigation |

## SVG sample attribution

SVGs in `/assets/w3samples` pulled from [W3 sample files](https://dev.w3.org/SVG/tools/svgweb/samples/svg-files/)

SVGs in `/assets/deborah_ufw` provided by @deborah-ufw

SVGs in `/assets/simple` are pulled from trivial examples or generated to test
basic functionality - some of them come directly from the SVG 1.1 spec. Some
have also come or been adapted from issues raised in this repository.

SVGs in `/assets/wikimedia` are pulled from [Wikimedia Commons](https://commons.wikimedia.org/wiki/Main_Page)

Android Drawables in `/assets/android_vd` are pulled from Android Documentation
and examples.

The Flutter Logo created based on the Flutter Logo Widget © Google.

The Dart logo is from
[dartlang.org](https://github.com/dart-lang/site-shared/blob/master/src/_assets/images/dart/logo%2Btext/horizontal/original.svg)
© Google

SVGs in `/assets/noto-emoji` are from [Google i18n noto-emoji](https://github.com/googlei18n/noto-emoji),
licensed under the Apache license.

Please submit SVGs that can't render properly (e.g. that don't render here the
way they do in chrome), as long as they're not using anything "probably out of
scope" (above).

## Commemoration

This package was originally authored by
[Dan Field](https://github.com/dnfield) and has been forked here
from [dnfield/flutter_svg](https://github.com/dnfield/flutter_svg).
Dan was a member of the Flutter team at Google from 2018 until his death
in 2024. Dan’s impact and contributions to Flutter were immeasurable, and we
honor his memory by continuing to publish and maintain this package.
