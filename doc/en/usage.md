# full_svg_flutter usage guide

`full_svg_flutter` lets Flutter apps render real SVG files directly. It is
designed for both ordinary static SVGs and complex animated SVGs: SMIL,
CSS `@keyframes`, path morphing, filters, masks, rich text, and SVGator
JavaScript exports.

Use this guide when you want to add the package to an app, migrate from
`flutter_svg`, decide which widget to use, control animation playback, or debug
an SVG that does not look right.

## 1. Installation

Add the package:

```bash
flutter pub add full_svg_flutter
```

Or edit `pubspec.yaml` manually:

```yaml
dependencies:
  full_svg_flutter: ^1.4.4
```

Import it in Dart:

```dart
import 'package:full_svg_flutter/full_svg_flutter.dart';
```

For local SVG assets, register the files or folder:

```yaml
flutter:
  assets:
    - assets/icons/
    - assets/animations/logo.svg
```

Then run:

```bash
flutter pub get
```

## 2. Which widget should I use?

| Use case | Widget | Why |
|---|---|---|
| Static icons, logos, illustrations | `SvgPicture` | Compatible with the familiar `flutter_svg` API |
| You do not know whether the file is static or animated | `FSvgPicture` | Auto-detects animation markers and chooses the correct renderer |
| Animated SVG with programmatic play, pause, seek, speed, reverse, or view switching | `AnimatedSvgPicture` + `AnimatedSvgController` | Gives direct control over the animation runtime |
| Migrating a static app from `flutter_svg` | `SvgPicture` | Usually only the import changes |
| SVGator JS export or custom inline SVG script | `FSvgPicture` or `AnimatedSvgPicture` | Runs SVG JavaScript through the embedded QuickJS bridge |

Recommended default:

```dart
FSvgPicture.asset('assets/graphic.svg')
```

`FSvgPicture` is the safest everyday choice because it works for static and
animated SVGs. If the SVG has no animation markers, it renders through the
static `SvgPicture` path. If it contains SMIL, CSS animation, or script-driven
animation, it renders through `AnimatedSvgPicture`.

## 3. Quick start examples

### Asset

```dart
FSvgPicture.asset(
  'assets/animations/flutter_logo_animated.svg',
  width: 210,
  height: 210,
  fit: BoxFit.contain,
  semanticsLabel: 'Animated Flutter logo',
)
```

### Network

```dart
FSvgPicture.network(
  'https://example.com/hero.svg',
  width: 320,
  placeholderBuilder: (context) => const SizedBox(
    width: 48,
    height: 48,
    child: CircularProgressIndicator(),
  ),
  errorBuilder: (context, error, stackTrace) {
    return const Icon(Icons.broken_image);
  },
)
```

### Raw SVG string

```dart
const rawSvg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <circle cx="50" cy="50" r="40" fill="#1976d2"/>
</svg>
''';

FSvgPicture.string(rawSvg, width: 100, height: 100)
```

### Memory bytes

```dart
final bytes = utf8.encode(rawSvg);

FSvgPicture.memory(
  Uint8List.fromList(bytes),
  width: 100,
  height: 100,
)
```

### File

```dart
FSvgPicture.file(
  file,
  width: 240,
  height: 240,
)
```

`FSvgPicture.file` is intended for non-web platforms because browser security
rules restrict direct `file://` access.

## 4. Static SVG rendering

If you only need static SVG support, use `SvgPicture`. It keeps the same public
shape as `flutter_svg`:

```dart
SvgPicture.asset(
  'assets/icons/settings.svg',
  width: 24,
  height: 24,
  colorFilter: const ColorFilter.mode(
    Color(0xff333333),
    BlendMode.srcIn,
  ),
  semanticsLabel: 'Settings',
)
```

Common constructors:

```dart
SvgPicture.asset('assets/icon.svg')
SvgPicture.network('https://example.com/icon.svg')
SvgPicture.string(rawSvg)
SvgPicture.memory(bytes)
SvgPicture.file(file)
```

The `renderingStrategy` argument is retained for API compatibility. The package
uses its own DOM-preserving renderer and caches painted output internally.

## 5. Animated SVG rendering

For most animated SVG files:

```dart
FSvgPicture.asset(
  'assets/animations/spinner.svg',
  width: 64,
  height: 64,
  autoPlay: true,
  playbackRate: 1.0,
)
```

Animation-related arguments on `FSvgPicture`:

| Argument | Meaning |
|---|---|
| `autoPlay` | Start animation automatically. Defaults to `true` |
| `playbackRate` | Speed multiplier. `1.0` is normal, `0.5` is half speed, `2.0` is double speed |
| `initialTime` | Start the animation at a specific timeline position |
| `backgroundColor` | Background behind animated rendering |

These arguments are harmless for static SVG files.

## 6. Playback control

Use `AnimatedSvgPicture` directly when the app needs buttons, sliders, scrubbing,
reverse playback, or named SVG `<view>` switching.

```dart
class ControlledSvgDemo extends StatefulWidget {
  const ControlledSvgDemo({super.key});

  @override
  State<ControlledSvgDemo> createState() => _ControlledSvgDemoState();
}

class _ControlledSvgDemoState extends State<ControlledSvgDemo> {
  final AnimatedSvgController controller = AnimatedSvgController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSvgPicture.asset(
          'assets/animations/loader.svg',
          controller: controller,
          autoPlay: false,
          width: 160,
          height: 160,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: controller.resume,
            ),
            IconButton(
              icon: const Icon(Icons.pause),
              onPressed: controller.pause,
            ),
            IconButton(
              icon: const Icon(Icons.restart_alt),
              onPressed: controller.restart,
            ),
          ],
        ),
      ],
    );
  }
}
```

Controller API:

```dart
controller.pause();
controller.resume();
controller.togglePlayPause();

controller.seek(const Duration(seconds: 2));
controller.restart();

controller.setPlaybackRate(0.5);
controller.setPlaybackRate(2.0);

controller.reverse();
controller.forward();
controller.toggleDirection();

controller.switchToView('detail');
controller.switchToView(null);
```

Useful controller state:

```dart
final paused = controller.isPaused;
final rate = controller.playbackRate;
final reversed = controller.isReversed;
final views = controller.availableViews;
final timeMs = controller.currentTimeMs;
```

Call `controller.addListener` if your UI needs to update when playback state
changes.

## 7. SVGator and JavaScript SVGs

SVGator can export animations as declarative SMIL/CSS or as JavaScript-driven
SVG files. `full_svg_flutter` supports both.

```dart
FSvgPicture.asset(
  'assets/svgator/character.svg',
  width: 300,
  height: 300,
)
```

When an SVG contains `<script>`, the package starts an embedded QuickJS runtime
and exposes a polyfilled SVG DOM. Common APIs such as `document.getElementById`,
`setAttribute`, `requestAnimationFrame`, timers, `addEventListener`,
`getTotalLength`, and `getPointAtLength` are available.

Important boundaries:

- The runtime is an SVG DOM bridge, not a full browser.
- Browser APIs such as `window.location`, History, IndexedDB, WebGL, and HTML
  layout are not available.
- SVGator player scripts and simple custom SVG scripts are the intended use
  case.
- SVG files without `<script>` do not pay the JavaScript runtime cost.

## 8. Styling, colors, and themes

### `colorFilter`

Use `colorFilter` when the entire SVG should be tinted:

```dart
FSvgPicture.asset(
  'assets/icons/bell.svg',
  colorFilter: const ColorFilter.mode(
    Colors.red,
    BlendMode.srcIn,
  ),
)
```

This is best for single-color icons. It is usually not correct for detailed
illustrations because it affects every painted pixel.

### `ColorMapper`

Use `ColorMapper` when only specific source colors should change:

```dart
class BrandColorMapper extends ColorMapper {
  const BrandColorMapper(this.primary);

  final Color primary;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (color == const Color(0xff0057ff)) {
      return primary;
    }
    return color;
  }
}

FSvgPicture.asset(
  'assets/logo.svg',
  colorMapper: BrandColorMapper(Theme.of(context).colorScheme.primary),
)
```

### `currentColor`

If your SVG uses `currentColor`, pass an `SvgTheme`:

```dart
FSvgPicture.asset(
  'assets/icon-current-color.svg',
  theme: const SvgTheme(currentColor: Colors.green),
)
```

## 9. Layout and accessibility

Use Flutter's normal layout tools around SVG widgets:

```dart
SizedBox.square(
  dimension: 48,
  child: FSvgPicture.asset(
    'assets/icons/profile.svg',
    fit: BoxFit.contain,
    semanticsLabel: 'Profile',
  ),
)
```

Important layout arguments:

| Argument | Meaning |
|---|---|
| `width`, `height` | Requested render size |
| `fit` | How the SVG fits into its box, for example `BoxFit.contain` |
| `alignment` | Alignment inside the allocated box |
| `matchTextDirection` | Horizontal flip in RTL contexts |
| `allowDrawingOutsideViewBox` | Allows paint outside the SVG viewBox |
| `clipBehavior` / `clipToViewBox` | Controls clipping behavior |

Accessibility:

```dart
FSvgPicture.asset(
  'assets/illustrations/success.svg',
  semanticsLabel: 'Payment completed',
)
```

For decorative SVGs:

```dart
FSvgPicture.asset(
  'assets/background-shape.svg',
  excludeFromSemantics: true,
)
```

## 10. External images, fonts, links, and foreignObject

Animated SVGs support advanced hooks through `AnimatedSvgPicture`.

### Custom image loading

```dart
AnimatedSvgPicture.asset(
  'assets/composite.svg',
  imageLoader: (href) async {
    if (href.startsWith('app://')) {
      return loadBytesFromYourStore(href);
    }
    return null; // fall back to default loading
  },
)
```

### Links

```dart
AnimatedSvgPicture.asset(
  'assets/map.svg',
  onLinkTap: (link) {
    debugPrint('Tapped ${link.href}');
  },
)
```

### foreignObject

`<foreignObject>` is parsed, but arbitrary HTML is not rendered by default. If
your app owns the content and wants to provide a Flutter replacement, use
`foreignObjectBuilder` on `AnimatedSvgPicture`.

## 11. Performance recommendations

- Prefer `FSvgPicture.asset` for bundled SVG files. Asset loading is predictable
  and cache-friendly.
- Keep frequently repeated icons small and reuse the same asset path so the SVG
  cache can help.
- Avoid huge inline SVG strings in rebuild-heavy widgets. Store them as assets
  or memoize the string.
- Use `const` constructors where possible.
- Give large SVG widgets stable dimensions with `SizedBox`, `AspectRatio`, or
  layout constraints.
- JS-driven SVGs are more expensive than static SVGs. Use them where animation
  fidelity matters.
- Heavy filters, large paths, and hundreds of animated elements can affect
  frame rate on lower-end devices. Test on the slowest device you support.

Decoded SVGs are cached through `svg.cache`. You can tune cache size if your app
loads many unique files:

```dart
svg.cache.maximumSize = 200;
```

## 12. Migration from flutter_svg

For static SVGs, change the dependency and import:

```dart
// Before
import 'package:flutter_svg/flutter_svg.dart';

// After
import 'package:full_svg_flutter/full_svg_flutter.dart';
```

Most existing calls continue to compile:

```dart
SvgPicture.asset('assets/icon.svg')
SvgPicture.network('https://example.com/icon.svg')
SvgPicture.string(rawSvg)
SvgPicture.memory(bytes)
```

For animated SVGs, switch those call sites to `FSvgPicture`:

```dart
FSvgPicture.asset('assets/spinner.svg')
```

Use `AnimatedSvgPicture` only when you need a controller or advanced hooks.

See [migration_from_flutter_svg.md](../migration_from_flutter_svg.md) for the
dedicated migration notes.

## 13. Supported SVG features

Commonly supported areas:

- basic shapes, paths, groups, `<defs>`, `<use>`, `<symbol>`
- transforms, gradients, patterns, masks, clip paths
- all 17 SVG filter primitives
- rich text, `<tspan>`, `<textPath>`, bidi/RTL, decorations
- SMIL: `<animate>`, `<animateTransform>`, `<animateMotion>`, `<set>`
- CSS `@keyframes`, transitions, variables, `calc()`, selectors
- path morphing and motion paths
- `<image>` from assets, network, data URI, and native `file://`
- `<a>` links, hit-testing, title/desc accessibility metadata
- inline JavaScript for SVGator-style runtime animation

For the detailed matrix, see [supported_features.md](../supported_features.md).

## 14. Known limitations

`full_svg_flutter` is not a browser engine. The most important limitations are:

- JavaScript runs against a polyfilled SVG DOM, not the complete web platform.
- `<foreignObject>` content is not rendered as HTML by default.
- Cross-origin external resources depend on platform permissions.
- Some extreme filter chains or text layout cases may differ from browsers.
- Malformed SVG files may need cleanup before rendering.
- `file://` image references do not work on the web platform.

For details, see [limitations.md](../limitations.md).

## 15. Troubleshooting

### The asset does not appear

Check that the asset is listed in `pubspec.yaml`, indentation is correct, and
`flutter pub get` has been run.

```yaml
flutter:
  assets:
    - assets/logo.svg
```

### The SVG is static but should animate

Use `FSvgPicture` or `AnimatedSvgPicture`, not `SvgPicture`.

```dart
FSvgPicture.asset('assets/animated.svg')
```

### The animation should not start automatically

```dart
FSvgPicture.asset(
  'assets/animated.svg',
  autoPlay: false,
)
```

For later playback, use `AnimatedSvgPicture` with a controller.

### Network SVGs do not load

Verify the URL, HTTPS certificate, app network permissions, and CORS/security
policy on the target platform. For authenticated requests, pass headers:

```dart
FSvgPicture.network(
  url,
  headers: {'Authorization': 'Bearer $token'},
)
```

### The color is wrong

Use `colorFilter` only when you want to tint the entire SVG. For precise theme
replacement, use `ColorMapper` or author the SVG with `currentColor`.

### An SVGator file does not render correctly

Try to open the same SVG in a browser and compare. If it is a JavaScript export,
check whether it uses browser APIs outside the SVG DOM bridge. When reporting a
bug, include the original SVG file, expected browser screenshot, actual Flutter
screenshot, platform, Flutter version, and package version.

## 16. Minimal complete example

```dart
import 'package:flutter/material.dart';
import 'package:full_svg_flutter/full_svg_flutter.dart';

void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('SVG demo')),
        body: Center(
          child: FSvgPicture.asset(
            'assets/flutter_logo_animated.svg',
            width: 210,
            height: 210,
            semanticsLabel: 'Animated Flutter logo',
          ),
        ),
      ),
    );
  }
}
```
