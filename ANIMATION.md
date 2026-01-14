# SMIL Animation Support

**Status**: Experimental - Full SMIL animation support for SVG files.

## Quick Start

```dart
import 'package:flutter_svg/src/animation.dart';

AnimatedSvgPicture.string(
  '''<svg viewBox="0 0 100 100">
    <rect x="0" y="0" width="20" height="20" fill="blue">
      <animate attributeName="x" from="0" to="80" dur="2s" repeatCount="indefinite"/>
    </rect>
  </svg>''',
  width: 200,
  height: 200,
)
```

## Supported Features

### ✅ Fully Supported

**SMIL Elements:**
- `<animate>` - Animate any numeric, color, or transform attribute
- `<animateTransform>` - Specialized transform animations (translate, rotate, scale, skewX, skewY)
- `<animateMotion>` - Move elements along SVG paths with auto-rotation

**Attributes:**
- Numeric: `x`, `y`, `width`, `height`, `r`, `opacity`, `stroke-width`, etc.
- Colors: `fill`, `stroke`, `stop-color`, `flood-color`, `lighting-color`
- Transforms: `translate(x y)`, `rotate(angle [cx cy])`, `scale(x [y])`
- Paths: Path morphing between different shapes

**Timing:**
- `dur` - Duration ("2s", "500ms")
- `begin` - Start time (default: 0s)
- `end` - End time
- `repeatCount` - Number of repeats or "indefinite"
- `fill` - "freeze" (hold last value) or "remove" (revert)

**Interpolation:**
- `from/to/by` - Simple animations
- `values` + `keyTimes` - Keyframe animations
- `calcMode` - "linear", "discrete", "spline", "paced"
- `keySplines` - Cubic bezier easing

**Motion:**
- `path` - SVG path to follow
- `rotate` - "auto", "auto-reverse", or fixed angle
- `keyPoints` - Variable speed control

### 🚧 Coming Soon

- CSS Animations (@keyframes)
- CSS Transitions
- Advanced optimizations
- Production readiness

## Examples

### Basic Movement

```dart
AnimatedSvgPicture.string(
  '''<svg viewBox="0 0 100 100">
    <circle cx="20" cy="50" r="10" fill="red">
      <animate attributeName="cx" from="20" to="80" dur="2s" repeatCount="indefinite"/>
    </circle>
  </svg>''',
)
```

### Rotation

```dart
AnimatedSvgPicture.string(
  '''<svg viewBox="0 0 100 100">
    <rect x="40" y="40" width="20" height="20" fill="blue">
      <animateTransform
        attributeName="transform"
        type="rotate"
        from="0 50 50"
        to="360 50 50"
        dur="3s"
        repeatCount="indefinite"/>
    </rect>
  </svg>''',
)
```

### Color Animation

```dart
AnimatedSvgPicture.string(
  '''<svg viewBox="0 0 100 100">
    <rect x="25" y="25" width="50" height="50" fill="red">
      <animate 
        attributeName="fill" 
        values="#ff0000;#00ff00;#0000ff;#ff0000" 
        keyTimes="0;0.33;0.66;1"
        dur="4s" 
        repeatCount="indefinite"/>
    </rect>
  </svg>''',
)
```

### Path Morphing

```dart
AnimatedSvgPicture.string(
  '''<svg viewBox="0 0 100 100">
    <path fill="purple" d="M 20,20 L 80,20 L 80,80 L 20,80 Z">
      <animate
        attributeName="d"
        from="M 20,20 L 80,20 L 80,80 L 20,80 Z"
        to="M 50,10 A 40,40 0 1,1 49,10 Z"
        dur="2s"
        repeatCount="indefinite"/>
    </path>
  </svg>''',
)
```

### Motion Path

```dart
AnimatedSvgPicture.string(
  '''<svg viewBox="0 0 200 200">
    <path id="motionPath" d="M 20,100 Q 100,20 180,100" fill="none" stroke="#ddd"/>
    <circle r="8" fill="red">
      <animateMotion 
        dur="3s" 
        repeatCount="indefinite"
        rotate="auto"
        path="M 20,100 Q 100,20 180,100"/>
    </circle>
  </svg>''',
)
```

## Widget API

```dart
AnimatedSvgPicture.string(
  String svgString,
  {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Alignment alignment = Alignment.center,
    Color? backgroundColor,
    double playbackRate = 1.0,  // Animation speed multiplier
    bool autoPlay = true,       // Start automatically
  }
)
```

**Also available:**
- `AnimatedSvgPicture.asset()` - Load from assets
- `AnimatedSvgPicture.network()` - Load from URL
- `AnimatedSvgPicture.memory()` - Load from bytes

## Performance

Current benchmarks (313 tests, all passing):
- Path interpolation: <1ms for typical paths
- AnimateMotion: 60 position updates in <100ms
- Target: 60 FPS for simple animations, 30+ FPS for complex

## Demo App

Run the example app to see all supported animations:

```bash
cd example
flutter run
```

Features:
- 6 animation categories (Basic, Transform, Colors, Timing, Path Morphing, Motion)
- 20+ interactive examples
- FPS monitor
- Technical descriptions

## Architecture

This package uses **two separate pipelines**:

1. **Static SVG** - Fast, optimized binary format (no animations)
   - Use: `SvgPicture.asset()`, `SvgPicture.network()`

2. **Animated SVG** - DOM-based with full SMIL support
   - Use: `AnimatedSvgPicture.string()`, `AnimatedSvgPicture.asset()`

**Why separate?** The static pipeline compiles SVG to optimized drawing commands, discarding DOM structure needed for animations.

## Known Limitations

- `autoPlay: false` has rendering bug - use `autoPlay: true` as workaround
- Path morphing requires compatible path structures (normalized automatically)
- CSS animations not yet supported (Stage 8)
- Some advanced SMIL features pending (Stage 7)

## Development

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for:
- Development workflow
- Testing guidelines
- Architecture details
- Contributing guide

## Resources

- [VISUAL_TESTING_GUIDELINES.md](VISUAL_TESTING_GUIDELINES.md) - Visual testing patterns
- [ANIMATION_ARCHITECTURE.md](ANIMATION_ARCHITECTURE.md) - Original architectural plan
- [Example App](example/) - Interactive demos
- [Tests](test/animation/) - 313 tests covering all features
