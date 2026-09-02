# Migration from flutter_svg

`full_svg_flutter` is designed as a migration path from `flutter_svg`. For static SVGs the change is a single import line. For animated SVGs you switch to `FSvgPicture`.

---

## Step 1 — Update pubspec.yaml

```yaml
# Before
dependencies:
  flutter_svg: ^2.x.x

# After
dependencies:
  full_svg_flutter: ^1.5.1
```

You can remove `flutter_svg` entirely; `full_svg_flutter` re-exports the same `SvgPicture` API.

---

## Step 2 — Update imports

```dart
// Before
import 'package:flutter_svg/flutter_svg.dart';

// After
import 'package:full_svg_flutter/full_svg_flutter.dart';
```

That's it for static SVGs. `SvgPicture.asset()`, `SvgPicture.network()`, `SvgPicture.string()`, `SvgPicture.memory()`, `ColorMapper`, and all loaders have identical signatures.

---

## Step 3 — Switch animated SVGs to FSvgPicture

If any SVG file contains animations (SMIL, CSS keyframes, animated transforms), switch to `FSvgPicture`:

```dart
// Static SVG — SvgPicture still works
SvgPicture.asset('assets/icon.svg')

// Animated SVG — use FSvgPicture
FSvgPicture.asset('assets/spinner.svg')
FSvgPicture.asset('assets/hero.svg', autoPlay: true, playbackRate: 1.0)
```

`FSvgPicture` detects animation markers at parse time and auto-routes to the correct renderer. No manual switching needed.

---

## Step 4 — Optional: add playback control

If you need programmatic control over animation:

```dart
final controller = AnimatedSvgController();

AnimatedSvgPicture.asset(
  'assets/loader.svg',
  controller: controller,
  autoPlay: false,
)

// later:
controller.resume();
controller.pause();
controller.seek(const Duration(seconds: 2));
controller.setPlaybackRate(0.5);
controller.reverse();

controller.dispose(); // in State.dispose()
```

---

## API surface comparison

| flutter_svg | full_svg_flutter | Notes |
|---|---|---|
| `SvgPicture.asset()` | `SvgPicture.asset()` | Identical |
| `SvgPicture.network()` | `SvgPicture.network()` | Identical |
| `SvgPicture.string()` | `SvgPicture.string()` | Identical |
| `SvgPicture.memory()` | `SvgPicture.memory()` | Identical |
| `SvgPicture.file()` | `SvgPicture.file()` | Identical |
| `ColorMapper` | `ColorMapper` | Identical |
| `SvgStringLoader` | `SvgStringLoader` | Identical |
| `SvgAssetLoader` | `SvgAssetLoader` | Identical |
| `SvgNetworkLoader` | `SvgNetworkLoader` | Identical |
| `SvgFileLoader` | `SvgFileLoader` | Identical |
| — | `FSvgPicture` | New: auto-routing, animated SVG |
| — | `AnimatedSvgPicture` | New: controller-based |
| — | `AnimatedSvgController` | New: play/pause/seek/speed |

---

## Common migration issues

**Q: My static SVG looks different after migration.**

The rendering pipeline differs slightly. Open an issue with the SVG file.

**Q: My animated SVG still doesn't animate.**

Make sure you're using `FSvgPicture` (not `SvgPicture`) for animated files.

**Q: I'm using `flutter_svg`'s `BytesLoader` subclass.**

The loader protocol is compatible. Your subclass can be passed directly to `SvgPicture`.
