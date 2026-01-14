# Architecture Overview

## Dual Pipeline Design

flutter_svg uses **two completely separate rendering pipelines**:

### 1. Static SVG Pipeline (Production)

```
SVG Source
    ↓
vector_graphics_compiler.encodeSvg()
    ↓
Binary .vec format
    ↓
VectorGraphic widget
    ↓
Optimized rendering
```

**Characteristics:**
- ✅ Fast, pre-compiled binary format
- ✅ Production-ready, battle-tested
- ❌ Loses DOM structure, IDs, hierarchy
- ❌ No animation support

**Use:** `SvgPicture.asset()`, `SvgPicture.network()`

### 2. Animated SVG Pipeline (Experimental)

```
SVG Source
    ↓
SvgParser (XML → DOM)
    ↓
DOM Tree (SvgDocument)
    ↓
SmilParser (extract animations)
    ↓
SvgTimeline (time management)
    ↓
AnimatedSvgPainter (CustomPainter)
    ↓
Canvas rendering
```

**Characteristics:**
- ✅ Full DOM preservation
- ✅ SMIL animation support
- ✅ Runtime control (seek, playback rate)
- ⚠️ Slower than static pipeline
- ⚠️ Experimental status

**Use:** `AnimatedSvgPicture.string()`, `AnimatedSvgPicture.asset()`

## Why Two Pipelines?

The `vector_graphics_compiler` backend optimizes SVG by:
1. Converting to drawing commands
2. Discarding element structure
3. Removing IDs, classes, animations
4. Pre-computing transforms

**Result:** Fast rendering, but animations are impossible.

**Solution:** Parallel pipeline with lightweight XML parsing that preserves:
- DOM tree structure
- Element IDs and hierarchy
- SMIL animation elements
- Animatable attributes

## Core Components

### DOM Model (`lib/src/animation/svg_dom.dart`)

```dart
class SvgDocument {
  SvgNode root;
  Map<String, SvgNode> idMap;
}

class SvgNode {
  String tagName;
  String? id;
  Map<String, SvgAttribute> attributes;
  List<SvgNode> children;
  List<SmilAnimation> animations;
}

class SvgAttribute {
  Object baseValue;      // Original value
  Object? animatedValue; // Current animated value
  bool isAnimated;
  
  Object get effectiveValue => isAnimated ? animatedValue! : baseValue;
}
```

### SMIL Engine (`lib/src/animation/smil/`)

```dart
class SmilAnimation {
  String attributeName;
  Object? from, to;
  List<Object>? values;
  Duration dur, begin;
  double repeatCount;
  SmilCalcMode calcMode;
  
  Object? getValue(double t); // Interpolate at time t ∈ [0, 1]
}

class SvgTimeline {
  List<SmilAnimation> animations;
  Duration currentTime;
  
  void tick(Duration delta);     // Advance time
  void seek(Duration time);      // Jump to time
  void _updateAnimations();      // Apply to attributes
}
```

### Rendering (`lib/src/animation/animated_svg_painter.dart`)

```dart
class AnimatedSvgPainter extends CustomPainter {
  SvgNode rootNode;
  SvgTimeline timeline;
  
  void paint(Canvas canvas, Size size) {
    _paintNode(canvas, rootNode);
  }
  
  void _paintNode(Canvas canvas, SvgNode node) {
    // Get effective (animated) attribute values
    // Apply transforms, styles
    // Draw geometry
    // Recurse to children
  }
}
```

## Animation Flow

1. **Parse SVG** → `SvgParser.parse()` creates DOM tree
2. **Extract Animations** → `SmilParser.parseAnimations()` finds `<animate>` elements
3. **Initialize Timeline** → Create `SvgTimeline` with all animations
4. **Tick Loop** → Flutter Ticker calls `timeline.tick(delta)` at 60 FPS
5. **Update Attributes** → Timeline computes values, sets `attribute.animatedValue`
6. **Render** → Painter reads `attribute.effectiveValue` for drawing

## Interpolation System

All value interpolation happens in `lib/src/animation/smil/interpolators.dart`:

```dart
class Interpolators {
  // Basic types
  static double interpolateNumber(double from, double to, double t);
  static Color interpolateColor(Color from, Color to, double t);
  
  // Advanced types
  static SvgTransform interpolateTransform(SvgTransform from, SvgTransform to, double t);
  static PathData interpolatePath(PathData from, PathData to, double t);
  
  // With easing
  static T interpolate<T>(T from, T to, double t, SmilCalcMode calcMode, List<CubicBezier>? splines);
}
```

## Performance Strategy

### Static Subtrees
- If `node.hasAnimations == false`, cache rendering to `Picture`
- Reuse cached `Picture` instead of re-rendering

### Dirty Tracking
- Mark nodes dirty when animations change values
- Only re-render dirty subtrees

### Path Optimization
- Normalize paths once during parsing
- Reuse `Path` objects where possible
- Use `Path.reset()` instead of creating new

### Future Optimizations (Stage 10)
- Layer caching for independent animations
- GPU-accelerated path morphing
- Reduce allocations in hot paths

## Decision Rationale

### Why not fork vector_graphics_compiler?

**Pros of forking:**
- Could extend .vec format for animations
- Single unified pipeline

**Cons:**
- Massive maintenance burden
- Must sync with upstream
- Breaks compatibility
- Couples to internal APIs

**Decision:** Parallel pipeline is cleaner, more maintainable.

### Why CustomPainter instead of RenderObject?

**RenderObject pros:**
- More Flutter-native
- Better integration with layout

**CustomPainter pros:**
- Simpler to implement
- Direct Canvas access
- Easier testing
- Proven pattern (flutter_svg already uses)

**Decision:** CustomPainter for Stage 1-6, consider RenderObject in Stage 10.

### Why preserve DOM instead of compiled format?

Animations require:
- Element identity (IDs)
- Attribute mutation
- Tree traversal (for inheritance)
- Runtime introspection

Compiled format throws this away for performance.

**Decision:** DOM preservation is mandatory for SMIL support.

## File Organization

```
lib/src/animation/
├── Core
│   ├── animated_svg_picture.dart    # Public widget
│   ├── animated_svg_painter.dart    # CustomPainter
│   ├── svg_parser.dart              # XML → DOM
│   └── svg_dom.dart                 # DOM model
├── SMIL
│   ├── smil_animation.dart          # Animation classes
│   ├── smil_parser.dart             # Extract from DOM
│   ├── smil_timeline.dart           # Time management
│   ├── interpolators.dart           # Value interpolation
│   ├── motion_path.dart             # AnimateMotion
│   └── timing.dart                  # Duration parsing
├── Utilities
│   ├── path_parser.dart             # SVG path → PathData
│   ├── path_normalizer.dart         # Normalize for morphing
│   ├── path_interpolation.dart      # Path morphing
│   └── svg_transform.dart           # Transform parsing
└── Future (Stage 8-9)
    └── css/                          # CSS animations
```

## Design Principles

1. **Separation of Concerns** - Each module has single responsibility
2. **Testability** - All components independently testable
3. **Performance** - Optimize hot paths, lazy evaluation
4. **Flutter Patterns** - Use Ticker, CustomPainter, ChangeNotifier
5. **Graceful Degradation** - Invalid SVG → empty box, no crashes
6. **Minimal Dependencies** - Only `xml` package added

## References

- Original plan: `docs/archive/ANIMATION_ARCHITECTURE.md`
- Implementation stages: `docs/archive/STAGE_*_SUMMARY.md`
- Development guide: `docs/DEVELOPMENT.md`
