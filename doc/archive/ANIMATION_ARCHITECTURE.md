# Architectural Plan for Adding SMIL/CSS Animations to flutter_svg

## 📊 CURRENT ARCHITECTURE ANALYSIS

### Current Pipeline (flutter_svg 2.2.2)

```
SVG Source (asset/network/string/bytes)
         ↓
   SvgLoader (SvgAssetLoader, SvgNetworkLoader, etc.)
         ↓
   prepareMessage() — loading raw data
         ↓
   provideSvg() — obtaining the XML string
         ↓
   compute() in isolate:
      vector_graphics_compiler.encodeSvg()
         ↓
   ByteData (binary .vec format)
         ↓
   Cache (svg.cache)
         ↓
   vector_graphics: createCompatVectorGraphic()
         ↓
   VectorGraphic widget
         ↓
   RenderObject renders Picture/Image
```

### Key Findings

1. **Full parsing delegation**: `flutter_svg` does **NOT** parse SVG itself, it delegates to `vector_graphics_compiler.encodeSvg()`
2. **DOM loss**: After `encodeSvg()` the result is a binary `.vec` format that contains only drawing commands (paths, fills, strokes), **WITHOUT** the DOM structure
3. **No Drawable classes**: The current version has no old `DrawableRoot`/`DrawableShape` — everything goes through `vector_graphics`
4. **Stable public API**: `SvgPicture.asset/network/string/memory` + `BytesLoader` are well isolated

### What Is Lost in the Current Pipeline

❌ **DOM tree** of elements (`<g>`, `<rect>`, `<circle>`, `<path>`)  
❌ **Element IDs** and their hierarchy  
❌ **SMIL elements** (`<animate>`, `<animateTransform>`, `<animateMotion>`)  
❌ **CSS `<style>` blocks** and `@keyframes`  
❌ **Events** (though they are hard to implement in Flutter anyway)  
❌ **Dynamic attributes** — after compilation everything is "baked" into commands  

---

## 🎯 INTEGRATION STRATEGY

### Option A: Fork vector_graphics_compiler (❌ Not recommended)

**Pros:**
- Full control over parsing
- Can extend the .vec format for animations

**Cons:**
- Enormous amount of work
- Need to maintain the fork
- Syncing with upstream
- Dependency on vector_graphics internals

### Option B: Parallel Animation Pipeline ⭐ **RECOMMENDED**

**Concept:**
- For static SVGs — keep the current fast path through `vector_graphics`
- For SVGs with animations — a new path with its own parser and DOM tree
- Auto-detection or explicit `hasAnimations` flag

**Pros:**
- ✅ Does not break the existing API
- ✅ Does not depend on vector_graphics for animations
- ✅ Can be introduced iteratively
- ✅ Optimal performance choice

**Cons:**
- Some duplication of parsing logic (but minimal)
- Two rendering code paths

---

## 🏗️ SOLUTION ARCHITECTURE (Option B)

### New Modules

```
lib/src/
├── animation/
│   ├── svg_dom.dart              # SVG DOM model
│   ├── smil/
│   │   ├── smil_animation.dart   # Base SMIL animation classes
│   │   ├── smil_parser.dart      # Parser for <animate>, <animateTransform>, etc.
│   │   ├── smil_timeline.dart    # Time management and ticking
│   │   ├── interpolators.dart    # Value interpolation (number, color, transform, path)
│   │   └── timing.dart           # begin/end/dur/repeatCount logic
│   ├── css/
│   │   ├── css_animation.dart    # CSS @keyframes animations
│   │   ├── css_parser.dart       # Minimal CSS parser
│   │   └── css_transition.dart   # CSS transitions
│   ├── svg_parser.dart           # Lightweight XML→DOM parser for animations
│   ├── animated_renderer.dart    # CustomPainter for animated SVGs
│   └── animation_detector.dart   # Detects whether an SVG contains animations
└── loaders.dart                  # (extend)
```

### Public API

#### New Widget: `AnimatedSvgPicture`

```dart
/// lib/src/animated_svg_picture.dart

class AnimatedSvgPicture extends StatefulWidget {
  const AnimatedSvgPicture(
    this.bytesLoader, {
    super.key,
    
    // All existing SvgPicture parameters
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.colorFilter,
    this.semanticsLabel,
    this.clipBehavior = Clip.hardEdge,
    // ... etc
    
    // ⭐ NEW parameters for animations
    this.enableSmilAnimations = true,
    this.enableCssAnimations = true,
    this.autoPlay = true,
    this.loop = true,
    this.controller,
    this.onAnimationStart,
    this.onAnimationEnd,
  });
  
  final BytesLoader bytesLoader;
  final bool enableSmilAnimations;
  final bool enableCssAnimations;
  final bool autoPlay;
  final bool loop;
  final SvgAnimationController? controller;
  final VoidCallback? onAnimationStart;
  final VoidCallback? onAnimationEnd;
  
  // Named constructors like SvgPicture
  AnimatedSvgPicture.asset(...);
  AnimatedSvgPicture.network(...);
  AnimatedSvgPicture.string(...);
  AnimatedSvgPicture.memory(...);
}
```

#### Animation Controller

```dart
/// lib/src/animation/svg_animation_controller.dart

class SvgAnimationController extends ChangeNotifier {
  SvgAnimationController({
    this.duration,
    this.vsync,
  });
  
  final Duration? duration;
  final TickerProvider? vsync;
  
  void play();
  void pause();
  void stop();
  void seek(Duration time);
  void setSpeed(double speed);
  
  bool get isPlaying;
  Duration get currentTime;
  Duration get totalDuration;
}
```

### Internal Data Structures

#### SVG DOM

```dart
/// lib/src/animation/svg_dom.dart

/// An SVG DOM tree node
class SvgNode {
  SvgNode({
    required this.tagName,
    this.id,
    this.className,
    required this.attributes,
    this.children = const [],
    this.parent,
  });
  
  final String tagName; // 'svg', 'g', 'rect', 'circle', 'path', etc.
  final String? id;
  final String? className;
  final Map<String, SvgAttribute> attributes;
  final List<SvgNode> children;
  SvgNode? parent;
  
  /// List of animations attached to this node
  final List<SmilAnimation> animations = [];
  
  /// Optimization flag: whether there are animations in the subtree
  bool hasAnimations = false;
  
  /// Cached Picture for static subtrees
  ui.Picture? cachedPicture;
}

/// An SVG element attribute (can be animated)
class SvgAttribute {
  SvgAttribute({
    required this.name,
    required this.baseValue,
  });
  
  final String name; // 'x', 'y', 'fill', 'transform', etc.
  
  /// Base value from XML
  Object baseValue; // String, double, Color, Transform, etc.
  
  /// Current animated value (if there is an active animation)
  Object? animatedValue;
  
  /// Flag: whether an animation is currently active
  bool isAnimated = false;
  
  /// Get the effective value (animatedValue if present, otherwise baseValue)
  Object get effectiveValue => isAnimated ? animatedValue! : baseValue;
}
```

#### SMIL Animation

```dart
/// lib/src/animation/smil/smil_animation.dart

enum SmilAnimationType {
  animate,           // <animate>
  animateTransform,  // <animateTransform>
  animateMotion,     // <animateMotion>
  set,               // <set>
}

enum SmilCalcMode {
  discrete,
  linear,
  paced,
  spline,
}

enum SmilFillMode {
  freeze,   // keep the last value
  remove,   // revert to base value
}

enum SmilAdditiveMode {
  replace,  // replace the base value
  sum,      // add to the base value
}

class SmilAnimation {
  SmilAnimation({
    required this.type,
    required this.targetNode,
    required this.attributeName,
    required this.attributeType,
    this.from,
    this.to,
    this.by,
    this.values,
    this.keyTimes,
    this.keySplines,
    required this.dur,
    this.begin = Duration.zero,
    this.end,
    this.repeatCount = 1.0,
    this.repeatDur,
    this.fillMode = SmilFillMode.remove,
    this.calcMode = SmilCalcMode.linear,
    this.additive = SmilAdditiveMode.replace,
    this.accumulate = false,
  });
  
  final SmilAnimationType type;
  final SvgNode targetNode;
  final String attributeName; // 'x', 'y', 'fill', etc.
  final SvgAttributeType attributeType;
  
  // Animation values
  final Object? from;
  final Object? to;
  final Object? by;
  final List<Object>? values; // for keyframe animations
  final List<double>? keyTimes; // [0.0, 0.5, 1.0]
  final List<CubicBezier>? keySplines; // for spline interpolation
  
  // Timing
  final Duration dur;
  final Duration begin;
  final Duration? end;
  final double repeatCount; // double.infinity for 'indefinite'
  final Duration? repeatDur;
  
  // Behavior
  final SmilFillMode fillMode;
  final SmilCalcMode calcMode;
  final SmilAdditiveMode additive;
  final bool accumulate;
  
  // Runtime state
  bool isActive = false;
  int currentIteration = 0;
  Duration localTime = Duration.zero;
  
  /// Compute the animation value at time t ∈ [0, 1] within an iteration
  Object? computeValue(double t);
}

/// Attribute type for correct interpolation
enum SvgAttributeType {
  number,        // x, y, width, height, opacity, stroke-width
  length,        // with units: px, em, %
  color,         // fill, stroke
  transform,     // transform attribute
  path,          // d attribute for <path>
  points,        // points for <polygon>, <polyline>
  string,        // for discrete animations
  list,          // stroke-dasharray and similar
}
```

#### Timeline (time management)

```dart
/// lib/src/animation/smil/smil_timeline.dart

class SvgTimeline {
  SvgTimeline({
    required this.animations,
    required this.rootNode,
  });
  
  final List<SmilAnimation> animations;
  final SvgNode rootNode;
  
  Duration _currentTime = Duration.zero;
  Duration get currentTime => _currentTime;
  
  /// Advance time by delta
  void tick(Duration delta) {
    _currentTime += delta;
    _updateAnimations(_currentTime);
  }
  
  /// Jump to a specific time
  void seek(Duration time) {
    _currentTime = time;
    _updateAnimations(_currentTime);
  }
  
  /// Update all animations for the current time
  void _updateAnimations(Duration time) {
    for (final animation in animations) {
      _updateAnimation(animation, time);
    }
  }
  
  void _updateAnimation(SmilAnimation anim, Duration globalTime) {
    // Check whether the animation is active
    final effectiveEnd = anim.end ?? 
        (anim.begin + anim.dur * anim.repeatCount);
    
    if (globalTime < anim.begin || globalTime >= effectiveEnd) {
      // Not active or finished
      if (anim.isActive && anim.fillMode == SmilFillMode.freeze) {
        // Keep the last value
        anim.isActive = false;
        // Value is already set
      } else {
        // Remove the animation
        anim.isActive = false;
        final attr = anim.targetNode.attributes[anim.attributeName];
        if (attr != null) {
          attr.isAnimated = false;
          attr.animatedValue = null;
        }
      }
      return;
    }
    
    // Animation is active
    anim.isActive = true;
    
    // Compute local time within the repeat
    final timeSinceBegin = globalTime - anim.begin;
    anim.currentIteration = (timeSinceBegin.inMicroseconds / 
                             anim.dur.inMicroseconds).floor();
    final iterationProgress = (timeSinceBegin.inMicroseconds % 
                               anim.dur.inMicroseconds) / 
                              anim.dur.inMicroseconds;
    
    // Compute value
    final value = anim.computeValue(iterationProgress);
    
    // Apply to the attribute
    final attr = anim.targetNode.attributes[anim.attributeName];
    if (attr != null) {
      attr.isAnimated = true;
      attr.animatedValue = value;
    }
  }
  
  /// Get the total duration of all animations
  Duration getTotalDuration() {
    Duration max = Duration.zero;
    for (final anim in animations) {
      final end = anim.begin + anim.dur * anim.repeatCount;
      if (end > max) max = end;
    }
    return max;
  }
}
```

### Rendering

#### AnimatedSvgPainter

```dart
/// lib/src/animation/animated_renderer.dart

class AnimatedSvgPainter extends CustomPainter {
  AnimatedSvgPainter({
    required this.rootNode,
    required this.timeline,
    required this.viewBox,
  });
  
  final SvgNode rootNode;
  final SvgTimeline timeline;
  final Rect viewBox;
  
  @override
  void paint(Canvas canvas, Size size) {
    // Apply viewBox transform
    final matrix = _computeViewBoxTransform(size);
    canvas.save();
    canvas.transform(matrix.storage);
    
    // Render the tree recursively
    _paintNode(canvas, rootNode);
    
    canvas.restore();
  }
  
  void _paintNode(Canvas canvas, SvgNode node) {
    canvas.save();
    
    // Apply the node's transforms
    _applyTransform(canvas, node);
    
    // If the node is static and has a cached picture — use it
    if (!node.hasAnimations && node.cachedPicture != null) {
      canvas.drawPicture(node.cachedPicture!);
      canvas.restore();
      return;
    }
    
    // Render the current node
    switch (node.tagName) {
      case 'rect':
        _paintRect(canvas, node);
        break;
      case 'circle':
        _paintCircle(canvas, node);
        break;
      case 'path':
        _paintPath(canvas, node);
        break;
      case 'g':
      case 'svg':
        // Container only
        break;
      // ... other elements
    }
    
    // Render children
    for (final child in node.children) {
      _paintNode(canvas, child);
    }
    
    canvas.restore();
  }
  
  void _paintRect(Canvas canvas, SvgNode node) {
    final x = _getNumberAttr(node, 'x');
    final y = _getNumberAttr(node, 'y');
    final width = _getNumberAttr(node, 'width');
    final height = _getNumberAttr(node, 'height');
    final fill = _getColorAttr(node, 'fill');
    final stroke = _getColorAttr(node, 'stroke');
    final strokeWidth = _getNumberAttr(node, 'stroke-width', 1.0);
    final opacity = _getNumberAttr(node, 'opacity', 1.0);
    
    final rect = Rect.fromLTWH(x, y, width, height);
    final paint = Paint();
    
    if (fill != null) {
      paint.color = fill.withOpacity(fill.opacity * opacity);
      paint.style = PaintingStyle.fill;
      canvas.drawRect(rect, paint);
    }
    
    if (stroke != null) {
      paint.color = stroke.withOpacity(stroke.opacity * opacity);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = strokeWidth;
      canvas.drawRect(rect, paint);
    }
  }
  
  double _getNumberAttr(SvgNode node, String name, [double defaultValue = 0.0]) {
    final attr = node.attributes[name];
    if (attr == null) return defaultValue;
    final value = attr.effectiveValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }
  
  Color? _getColorAttr(SvgNode node, String name) {
    final attr = node.attributes[name];
    if (attr == null) return null;
    final value = attr.effectiveValue;
    if (value is Color) return value;
    if (value is String) return _parseColor(value);
    return null;
  }
  
  @override
  bool shouldRepaint(AnimatedSvgPainter oldDelegate) {
    // Repaint every frame for animations
    return true;
  }
}
```

---

## 🔄 PIPELINE SWITCHING

### Pipeline Selection Logic

```dart
/// lib/src/animation/animation_detector.dart

class AnimationDetector {
  /// Quick check: does the SVG contain animations?
  static bool hasSvgAnimations(String svgXml) {
    // Simple regex search
    return svgXml.contains(RegExp(r'<animate[^>]*>')) ||
           svgXml.contains(RegExp(r'<animateTransform[^>]*>')) ||
           svgXml.contains(RegExp(r'<animateMotion[^>]*>')) ||
           svgXml.contains(RegExp(r'@keyframes')) ||
           svgXml.contains(RegExp(r'animation[:-]'));
  }
}
```

### Modified SvgLoader

```dart
/// lib/src/loaders.dart (extension)

abstract class SvgLoader<T> extends BytesLoader {
  // ... existing code ...
  
  /// NEW method: determine whether the animation pipeline is needed
  @protected
  bool shouldUseAnimationPipeline(String svg) {
    return AnimationDetector.hasSvgAnimations(svg);
  }
  
  /// NEW method: parsing for animations
  @protected
  Future<SvgDomDocument> parseForAnimations(String svg, BuildContext? context) {
    // Parse XML into DOM
    return compute((String xml) {
      return SvgParser.parse(xml);
    }, svg);
  }
}
```

---

## 📝 IMPLEMENTATION PLAN BY STAGES

### Stage 1: Basic Infrastructure (1-2 weeks)

**Tasks:**
1. ✅ Create `lib/src/animation/` structure
2. ✅ Implement `SvgNode` and `SvgAttribute`
3. ✅ Create `AnimationDetector`
4. ✅ Basic XML → SvgNode parser (`SvgParser`)
5. ✅ Tests for parser of basic elements (rect, circle, path, g)

**Files:**
- `lib/src/animation/svg_dom.dart`
- `lib/src/animation/svg_parser.dart`
- `lib/src/animation/animation_detector.dart`
- `test/animation/svg_parser_test.dart`

**Readiness criterion:**
- Parser can convert a simple SVG into an SvgNode tree
- Attributes are correctly extracted

### Stage 2: SMIL Core — Numeric Animations (2 weeks)

**Tasks:**
1. ✅ Implement `SmilAnimation` base class
2. ✅ Parser for `<animate>` for numeric attributes (x, y, width, height, opacity)
3. ✅ `SvgTimeline` with tick/seek methods
4. ✅ Interpolator for numbers (linear, discrete)
5. ✅ Support for `from/to`, `values + keyTimes`
6. ✅ Unit tests for timing and interpolation

**Files:**
- `lib/src/animation/smil/smil_animation.dart`
- `lib/src/animation/smil/smil_parser.dart`
- `lib/src/animation/smil/smil_timeline.dart`
- `lib/src/animation/smil/interpolators.dart`
- `test/animation/smil_animation_test.dart`

**Example test:**
```dart
test('animate opacity from 0 to 1', () {
  final anim = SmilAnimation(
    type: SmilAnimationType.animate,
    attributeName: 'opacity',
    from: 0.0,
    to: 1.0,
    dur: Duration(seconds: 2),
  );
  
  expect(anim.computeValue(0.0), 0.0);
  expect(anim.computeValue(0.5), 0.5);
  expect(anim.computeValue(1.0), 1.0);
});
```

### Stage 3: Rendering Animated SVGs (2 weeks)

**Tasks:**
1. ✅ `AnimatedSvgPainter` — CustomPainter for rendering the SvgNode tree
2. ✅ Rendering of basic shapes: rect, circle, ellipse, line
3. ✅ Applying fill, stroke, opacity from attributes
4. ✅ Create `AnimatedSvgPicture` widget
5. ✅ Integration with Flutter Ticker for animation
6. ✅ Tests: golden tests for simple animated SVGs

**Files:**
- `lib/src/animation/animated_renderer.dart`
- `lib/src/animated_svg_picture.dart`
- `lib/animated_svg.dart` (new export file)
- `test/golden_animation/simple_opacity_test.dart`

**Usage example:**
```dart
AnimatedSvgPicture.string(
  '''
  <svg viewBox="0 0 100 100">
    <rect x="10" y="10" width="30" height="30" fill="red">
      <animate attributeName="opacity" 
               from="0" to="1" 
               dur="2s" 
               repeatCount="indefinite"/>
    </rect>
  </svg>
  ''',
  width: 200,
  height: 200,
);
```

### Stage 4: Color Animations (1 week)

**Tasks:**
1. ✅ Interpolator for Color (RGB space)
2. ✅ Support for animating fill, stroke
3. ✅ Parsing CSS/SVG colors (#RGB, rgb(), named colors)
4. ✅ Tests

**Files:**
- `lib/src/animation/smil/interpolators.dart` (extension)
- `lib/src/animation/color_parser.dart`

### Stage 5: Transform Animations (2 weeks)

**Tasks:**
1. ✅ Implement `<animateTransform>`
2. ✅ Support for types: translate, scale, rotate, skewX, skewY
3. ✅ Transform interpolation
4. ✅ Application in the renderer
5. ✅ Tests and goldens

**Files:**
- `lib/src/animation/smil/transform_animation.dart`
- `lib/src/animation/transform_parser.dart`

### Stage 6: Path Animations (2-3 weeks)

**Tasks:**
1. ✅ Parsing SVG path `d` attribute
2. ✅ Path interpolation (requires compatible segments)
3. ✅ Support for `<animateMotion>`
4. ✅ Tests

**Challenges:**
- Path interpolation only works for compatible paths (same number of commands)
- A path normalizer is needed

### Stage 7: Extended SMIL (1-2 weeks)

**Tasks:**
1. ✅ `keySplines` for cubic bezier easing
2. ✅ `calcMode="paced"`
3. ✅ `additive="sum"` and `accumulate="sum"`
4. ✅ `repeatCount`, `repeatDur`
5. ✅ `<set>` element
6. ✅ Syncbase timing (`begin="anim1.end+2s"`)

### Stage 8: CSS Animations (3 weeks)

**Tasks:**
1. ✅ Minimal CSS parser for `<style>` blocks
2. ✅ Parsing `@keyframes`
3. ✅ Support for `animation-*` properties
4. ✅ Integration with the common timeline
5. ✅ Tests

**Files:**
- `lib/src/animation/css/css_parser.dart`
- `lib/src/animation/css/css_animation.dart`

### Stage 9: CSS Transitions (2 weeks)

**Tasks:**
1. ✅ Tracking style changes
2. ✅ Creating transient animations
3. ✅ `transition-property`, `transition-duration`, `transition-timing-function`
4. ✅ Tests

### Stage 10: Optimizations (2 weeks)

**Tasks:**
1. ✅ Caching static subtrees in Picture
2. ✅ Dirty tracking — repaint only changed nodes
3. ✅ Profiling and allocation optimization
4. ✅ Lazy CSS parsing
5. ✅ Performance tests

### Stage 11: Documentation and Examples (1 week)

**Tasks:**
1. ✅ README update
2. ✅ API documentation
3. ✅ Example app with various animations
4. ✅ Migration guide
5. ✅ SMIL/CSS feature support table

---

## 🎨 PUBLIC API (final form)

### Exports

```dart
// lib/flutter_svg.dart (unchanged)
export 'svg.dart';

// lib/animated_svg.dart (NEW)
export 'src/animated_svg_picture.dart';
export 'src/animation/svg_animation_controller.dart';
```

### Usage

#### Static SVG (old way, unchanged)
```dart
SvgPicture.asset('assets/logo.svg')
```

#### Animated SVG (new way)
```dart
AnimatedSvgPicture.asset(
  'assets/animated_logo.svg',
  autoPlay: true,
  loop: true,
)
```

#### With a controller
```dart
final controller = SvgAnimationController();

AnimatedSvgPicture.network(
  'https://example.com/anim.svg',
  controller: controller,
  autoPlay: false,
)

// Control
controller.play();
controller.pause();
controller.seek(Duration(seconds: 2));
```

---

## ⚡ OPTIMIZATIONS

### 1. Static subtrees → Picture cache
```dart
// If a node and all its children have hasAnimations == false
if (!node.hasAnimations && node.cachedPicture == null) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  _paintNodeSubtree(canvas, node);
  node.cachedPicture = recorder.endRecording();
}
```

### 2. Dirty tracking
```dart
class SvgNode {
  bool _isDirty = false;
  
  void markDirty() {
    _isDirty = true;
    parent?.markDirty(); // bubble up
  }
}
```

### 3. Pre-parsing
- All `values`, `keyTimes`, `keySplines` are parsed in the SmilAnimation constructor
- No string parsing in `tick()`

### 4. Object pooling for Path
- Reuse Path objects where possible
- Use `Path.reset()` instead of creating new ones

---

## 🧪 TESTING STRATEGY

### Unit Tests
- `SvgParser`: parsing various elements
- `SmilAnimation`: computing values
- Interpolators: numbers, colors, transforms, paths
- `SvgTimeline`: timing and animation activation

### Widget Tests
- `AnimatedSvgPicture` is created correctly
- Controller works

### Golden Tests
- Snapshots of animated SVGs at different time points
- Comparison with reference images

### Performance Tests
- FPS for complex animations
- Memory profiling (no leaks)

---

## 📊 FEATURE SUPPORT TABLE

### SMIL (target support)

| Feature | Status | Priority | Stage |
|---------|--------|----------|-------|
| `<animate>` numbers | ✅ Planned | P0 | 2 |
| `<animate>` colors | ✅ Planned | P0 | 4 |
| `<animateTransform>` | ✅ Planned | P0 | 5 |
| `<animateMotion>` | ✅ Planned | P1 | 6 |
| `<set>` | ✅ Planned | P2 | 7 |
| `from/to/by` | ✅ Planned | P0 | 2 |
| `values` + `keyTimes` | ✅ Planned | P0 | 2 |
| `keySplines` | ✅ Planned | P1 | 7 |
| `dur`, `begin`, `end` | ✅ Planned | P0 | 2 |
| `repeatCount`, `repeatDur` | ✅ Planned | P0 | 7 |
| `fill="freeze/remove"` | ✅ Planned | P0 | 2 |
| `calcMode` (linear/discrete/paced/spline) | ✅ Planned | P1 | 7 |
| `additive`, `accumulate` | ✅ Planned | P2 | 7 |
| Syncbase timing | ✅ Planned | P2 | 7 |
| Event-based begin/end | ⚠️ Limited | P3 | - |

### CSS Animations

| Feature | Status | Priority | Stage |
|---------|--------|----------|-------|
| `@keyframes` | ✅ Planned | P1 | 8 |
| `animation-name` | ✅ Planned | P1 | 8 |
| `animation-duration` | ✅ Planned | P1 | 8 |
| `animation-timing-function` | ✅ Planned | P1 | 8 |
| `animation-iteration-count` | ✅ Planned | P1 | 8 |
| `animation-direction` | ✅ Planned | P2 | 8 |
| `animation-fill-mode` | ✅ Planned | P1 | 8 |
| `animation-delay` | ✅ Planned | P1 | 8 |
| `transition-*` | ✅ Planned | P2 | 9 |

---

## 🚀 NEXT STEPS

1. **Create the basic module structure** (Stage 1)
2. **Write the SvgNode parser** 
3. **Implement the SMIL core for numbers** (Stage 2)
4. **Create the AnimatedSvgPicture widget** (Stage 3)
5. **Iteratively add features** (Stages 4-9)

---

## 💡 KEY ARCHITECTURAL ADVANTAGES

✅ **Backward compatibility**: `SvgPicture` is unchanged  
✅ **Optimal performance**: static content via vector_graphics, animations separately  
✅ **Modularity**: SMIL and CSS can be enabled/disabled independently  
✅ **Extensibility**: easy to add new animation types  
✅ **Testability**: each component is isolated  
✅ **Flutter-native**: uses Ticker, CustomPainter, standard patterns  

---

## 📚 REFERENCE MATERIALS

- [SVG 1.1 Spec](https://www.w3.org/TR/SVG11/)
- [SMIL Animation](https://www.w3.org/TR/2001/REC-smil-animation-20010904/)
- [CSS Animations](https://www.w3.org/TR/css-animations-1/)
- [vector_graphics package](https://pub.dev/packages/vector_graphics)
- [vector_graphics_compiler](https://pub.dev/packages/vector_graphics_compiler)

---

**This document is a living plan.** It will be updated with statuses and details as implementation progresses.
