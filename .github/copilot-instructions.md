# flutter_svg Development Guide for AI Agents

## Project Overview

This package renders SVG files in Flutter with **two distinct rendering pipelines**:

1. **Static SVG Pipeline** (production): SVG → `vector_graphics_compiler` → binary `.vec` format → `VectorGraphic` widget
2. **Animated SVG Pipeline** (experimental): SVG → custom XML parser → DOM tree → SMIL engine → `AnimatedSvgPicture` widget

**Critical**: These pipelines are **intentionally separate**. The static pipeline delegates to `vector_graphics_compiler` and loses DOM structure. Animated SVG requires custom parsing to preserve `<animate>`, `<animateTransform>`, and `<animateMotion>` elements.

## Architecture: Why Two Pipelines?

The `vector_graphics` backend compiles SVG to optimized drawing commands, discarding:
- DOM tree structure
- Element IDs and hierarchy  
- SMIL animation elements (`<animate>`, `<animateTransform>`)
- CSS `<style>` blocks

**Solution**: `lib/src/animation/` implements a parallel path with lightweight XML parsing (`svg_parser.dart` → `svg_dom.dart`) that preserves animation metadata. See `ARCHITECTURE.md` for design rationale.

## Reference Implementation

**Blink Source Code** (`blink-b87d44f-Source-core-svg/`): Chromium's SVG implementation from the Blink rendering engine. This directory contains reference C++ code for:
- SMIL animation elements (`SVGAnimateElement.cpp`, `SVGAnimateTransformElement.cpp`, `SVGAnimateMotionElement.cpp`)
- Complex behaviors like `SVGSMILElement.cpp` timing model
- Use as reference when implementing advanced SMIL features or debugging spec-compliant behavior
- **Not compiled into the package** - purely for developer reference

## Test-First Development Workflow

**MANDATORY**: Run tests after every code change:

```bash
# Run all animation tests (recommended after changes)
flutter test test/animation/

# Run specific test file
flutter test test/animation/smil_test.dart

# Run with verbose output
flutter test test/animation/ --reporter expanded

# All tests (includes static SVG tests)
flutter test

# Run example app to verify visual behavior
cd example && flutter run

# Check for compilation errors without running tests
flutter analyze
```

### Test Categories

- **Unit tests** (`*_test.dart`): Logic verification (parsers, interpolators, timeline)
- **Integration tests** (`*_integration_test.dart`): End-to-end animation flows
- **Golden tests** (`*_golden_test.dart`): Visual regression with baseline images
- **Visual tests** (`visual_*_test.dart`): Pixel analysis for geometric validation

### Running Subset of Tests

```bash
# Only SMIL core tests
flutter test test/animation/smil_test.dart

# Only path tests
flutter test test/animation/ --name "path"

# Exclude golden tests (useful in headless CI)
flutter test test/animation/ --exclude-tags golden
```

### Visual Testing Requirements

Standard unit tests verify **logic**, not **rendering**. Use pixel analysis for geometric validation:

```dart
// ✅ CORRECT: Verify actual pixels render
final pixels = await tester.runAsync(() async {
  final boundary = find.byType(RepaintBoundary).first;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return byteData!.buffer.asUint8List();
});

final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);
expect(analysis.pixelCount, greaterThan(0)); // Verify rendering happened
```

**Critical gotchas** (see `VISUAL_TESTING_GUIDELINES.md`):
- ✅ Wrap `toImage()` in `tester.runAsync()` to prevent test hangs
- ✅ `autoPlay: false` now works correctly (bug fixed in P0-1)
- ❌ Never use `pumpAndSettle()` with infinite animations (hangs forever)
- ❌ Don't trust golden tests alone in headless environments (canvas transforms may not render)

### Test File Organization

**329 total tests across 31 test files** in `test/animation/`:

**Core SMIL Tests:**
- `smil_test.dart` - SMIL parser/engine (28 unit tests)
- `smil_edge_cases_test.dart` - Error handling (25 tests)
- `smil_keypoints_timing_test.dart` - Timing functions
- `timing_parser_test.dart` - Duration/begin/end parsing
- `syncbase_timing_test.dart` - Syncbase timing features

**Widget & Rendering Tests:**
- `animated_svg_picture_test.dart` - Widget integration (15 tests)
- `rotation_golden_test.dart` - Visual regression (50 golden tests)
- `canvas_rotation_test.dart` - Canvas rendering verification
- `controller_test.dart` - Timeline control API (13 tests)

**Visual Verification Tests:**
- `visual_rotation_test.dart` - Pixel analysis for rotation
- `visual_translation_test.dart` - Translation geometry verification
- `visual_scale_test.dart` - Scale geometry verification
- `interpolation_coords_test.dart` - Coordinate system verification

**Feature-Specific Tests:**
- `color_animation_test.dart` - Color interpolation
- `transform_animation_test.dart` - Transform animations
- `smil_path_interpolation_test.dart` - Path morphing (14 integration tests)
- `smil_animate_motion_integration_test.dart` - Motion paths (13 tests)
- `path_morphing_test.dart` - Path algorithm tests
- `path_parser_test.dart` - SVG path parsing
- `path_morphing_correctness_test.dart` - Algorithm validation
- `path_integration_test.dart` - End-to-end path tests

**Advanced Tests:**
- `autoplay_false_test.dart` - autoPlay parameter validation
- `initial_time_test.dart` - Animation initialization
- `advanced_transform_test.dart` - Complex transforms
- `arc_debug_test.dart` - Arc command debugging
- `square_circle_debug_test.dart` - Path morphing edge cases

## Key Code Locations

### Static SVG (Core Package)
- **Entry point**: `lib/svg.dart` → `SvgPicture.asset/network/string()`
- **Loaders**: `lib/src/loaders.dart` (delegates to `vector_graphics_compiler.encodeSvg()`)
- **Cache**: `lib/src/cache.dart`
- **Theme**: `lib/src/default_theme.dart` - Default SVG styling

### Animated SVG (Experimental)
- **Public API**: `lib/src/animation.dart` (exported symbols)
- **Widget**: `lib/src/animation/animated_svg_picture.dart`
- **Controller**: `lib/src/animation/animated_svg_controller.dart` - Timeline control (play/pause/seek/rate)
- **Parser**: `lib/src/animation/svg_parser.dart` (lightweight XML → DOM)
- **DOM Model**: `lib/src/animation/svg_dom.dart` (SvgDocument, SvgNode, SvgAttribute)
- **SMIL Engine**: `lib/src/animation/smil/smil_animation.dart`
- **Rendering**: `lib/src/animation/animated_svg_painter.dart` (CustomPainter)
- **Path handling**: `lib/src/animation/path_*.dart` (parser, interpolation, normalizer)
- **Transforms**: `lib/src/animation/svg_transform.dart`

### SMIL Animation Components
- **Timeline**: `lib/src/animation/smil/smil_timeline.dart` - Time management and ticking
- **Parser**: `lib/src/animation/smil/smil_parser.dart` - Extract animations from DOM
- **Interpolators**: `lib/src/animation/smil/interpolators.dart` - Value interpolation
- **Motion**: `lib/src/animation/smil/motion_path.dart` - AnimateMotion path following
- **Timing**: `lib/src/animation/smil/timing.dart` - Duration/begin/end parsing

### SMIL Implementation
```dart
// Core interpolation types in lib/src/animation/smil/interpolators.dart:
Interpolators.interpolateNumber(from, to, t);
Interpolators.interpolateColor(from, to, t);
Interpolators.interpolateTransform(from, to, t);
Interpolators.interpolatePath(fromPath, toPath, t); // Stage 6
```

**Supported SMIL features**:
- `<animate>` - numeric attributes, colors, transforms, paths
- `<animateTransform>` - translate, rotate, scale, skewX, skewY
- `<animateMotion>` - movement along SVG paths with auto-rotation
- Path morphing - smooth interpolation between different path shapes
- **Timing**: `dur`, `begin`, `end`, `repeatCount` (including `indefinite`)
  - **Syncbase timing** (experimental): `begin="anim1.begin+2s"`, `begin="anim1.end"`, `begin="anim1.repeat(2)"`
  - See `lib/src/animation/smil/timing_condition.dart` and `syncbase_timing_test.dart` for implementation
- Interpolation: `calcMode` (linear, discrete, paced, spline), `keyTimes`, `keySplines`
- Fill: `freeze` (hold final value), `remove` (revert to base)
- Motion: `rotate="auto"`, `rotate="auto-reverse"`, `keyPoints` for variable speed

## Common Patterns

### Adding a New SMIL Animation Type

1. **Parse XML** in `lib/src/animation/smil/smil_parser.dart`:
```dart
// Add case to _parseAnimateElement()
if (element.name.local == 'animateNewType') {
  return _parseAnimateNewType(element, targetNode);
}
```

2. **Interpolate values** in `lib/src/animation/smil/smil_animation.dart`:
```dart
dynamic _computeNewTypeValue(double t) {
  // Use appropriate interpolator from interpolators.dart
  return Interpolators.interpolateNewType(from, to, normalizedTime);
}
```

3. **Apply to rendering** in `lib/src/animation/animated_svg_painter.dart`:
```dart
void _applyAnimations(Canvas canvas, SvgNode node, double time) {
  final value = animation.getValue(time);
  // Apply value to canvas/paint
}
```

4. **Test** in `test/animation/`:
   - Unit tests for parsing/interpolation
   - Integration tests for end-to-end animation
   - Visual tests for pixel verification

### Adding Example to Demo App

1. **Create widget** in `example/lib/widgets/smil_*_widget.dart`
2. **Add to tab** in `example/lib/pages/unified_examples_page.dart`
3. **Add SVG asset** (if needed) in `example/assets/`
4. **Update info panel** with animation description and technical details

### Debugging Animation Issues

Check in this order:
1. **XML parsing**: `AnimationDetector.hasAnimations()` returns true?
2. **SMIL parsing**: Animation objects created in `SmilParser.parseAnimations()`?
3. **Timeline**: `SvgTimeline.tick()` advancing correctly?
4. **Interpolation**: Values interpolating in `SmilAnimation.getValue()`?
5. **Rendering**: Painter applying values in `AnimatedSvgPainter.paint()`?

Enable debug logging:
```dart
// In AnimatedSvgPicture or test:
print('Animations parsed: ${timeline.animations.length}');
print('Current time: ${timeline.currentTime}');
print('Value at t=$t: ${animation.getValue(t)}');
```

## Development Stages

### Completed (329 Tests, 100% Passing ✅)

- ✅ **Stage 1**: Infrastructure - DOM, parser, detector (61 tests)
- ✅ **Stage 2**: SMIL Core - numeric animations (`<animate>`)
- ✅ **Stage 3**: Rendering - CustomPainter, widget integration
- ✅ **Stage 4**: Color animations - fill, stroke interpolation
- ✅ **Stage 5**: Transform animations - rotate, translate, scale, skewX, skewY (100+ tests)
- ✅ **Stage 6**: Path animations - morphing, animateMotion with rotation (313 tests)
- ✅ **P0-1**: autoPlay: false bug fix (verified working)
- ✅ **P0-2**: Timeline control API (`AnimatedSvgController` with 13 tests)

### Next Steps

- 🔜 **Stage 7**: Advanced SMIL (keySplines, calcMode="paced", syncbase timing)
- 🔜 **Stage 8**: CSS Animations (@keyframes)
- 🔜 **Stage 9**: CSS Transitions
- 🔜 **Stage 10**: Performance optimizations (layer caching, dirty tracking)
- 🔜 **Stage 11**: Documentation and production readiness

See `CURRENT_STATUS.md` for latest status and `docs/archive/STAGE_6_SUMMARY.md` for Stage 6 details.

## Project-Specific Conventions

### File Naming
- Animation implementation: `lib/src/animation/feature_name.dart`
- Tests mirror source: `test/animation/feature_name_test.dart`
- Integration tests suffix: `*_integration_test.dart`
- Golden tests suffix: `*_golden_test.dart`
- Visual tests prefix: `visual_*_test.dart`

### Error Handling
- Graceful degradation for invalid SVG (log to console in debug mode)
- Return empty box (`LimitedBox`) for unparseable SVG
- No visual error widgets (follows `SvgPicture` convention)

### Performance Expectations
- Path interpolation: <1ms for typical paths
- AnimateMotion updates: 60 position updates in <100ms
- Target: 60 FPS for simple animations, 30+ FPS for complex

## Dependencies

**Core**:
- `vector_graphics` ^1.1.13 - static SVG rendering backend
- `vector_graphics_compiler` ^1.1.14 - SVG → binary compiler
- `xml` ^6.0.0 - XML parsing for animated SVG

**Dev**:
- `flutter_test` - testing framework
- Golden file testing via `matchesGoldenFile()`

## Example App Structure

Located in `example/`:
- **Main**: `lib/main.dart` - MaterialApp with AnimationTheme
- **Home**: `lib/pages/home_page.dart` - navigation to examples
- **Unified Examples**: `lib/pages/unified_examples_page.dart` - 6 tabs with FPS monitor:
  1. Basic Animations (movement, pulsing, fading)
  2. Transform (rotation, translation, scale)
  3. Colors (fill, stroke, gradients)
  4. Timing (duration, keyTimes, easing)
  5. Path Morphing (rectangle→circle, star→heart, complex shapes)
  6. Motion (animateMotion with auto-rotation, keyPoints)
- **Widgets**: Reusable example widgets in `lib/widgets/`:
  - `smil_path_morphing_widget.dart` - Path morphing demonstrations
  - `smil_animate_motion_widget.dart` - Motion path animations
  - `path_morphing_widget.dart` - Additional morphing examples
  - `animated_svg_viewer.dart` - Generic SVG animation viewer
  - `fps_monitor.dart` - Performance monitoring overlay
  - `metrics_widget.dart` - Animation metrics display
  - `parameters_panel.dart` - Interactive controls
  - `animation_theme.dart` - Theme configuration
- **Assets**: `assets/` - SVG test files organized by source (w3samples, wikimedia, simple, deborah_ufw, noto-emoji)

## When to Use Each Pipeline

**Use `SvgPicture.asset()`** (static) when:
- No animations needed
- Performance critical (pre-compiled binary)
- Large production app

**Use `AnimatedSvgPicture.string()`** (animated) when:
- SVG contains SMIL elements (`<animate>`, `<animateTransform>`, `<animateMotion>`)
- Need runtime animation control (playback rate, seek)
- Experimental/demo purposes

## Common Pitfalls

1. **Don't mix pipelines**: `SvgPicture` cannot render SMIL animations (they're compiled away)
2. **RepaintBoundary captures full screen**: Visual tests analyze 800x600 images, not widget size
3. **Path morphing requires compatible structures**: Normalize paths to same command count before interpolating
4. **Memory**: Always `dispose()` images in tests: `image.dispose()`
5. **XML parsing**: Use `xml` package's `XmlDocument.parse()` - it's already a dependency
6. **Color parsing**: Reuse existing color parsers from `vector_graphics_compiler` where possible

## Critical Development Gotchas

### Testing Issues

⚠️ **Never use `pumpAndSettle()` with infinite animations** - it hangs forever waiting for animations to complete
```dart
// ❌ WRONG - hangs
await tester.pumpAndSettle();

// ✅ CORRECT - use explicit pump() calls
await tester.pump();
await tester.pump(Duration(milliseconds: 500));
```

⚠️ **Always wrap `toImage()` in `tester.runAsync()`** to prevent test hangs
```dart
// ✅ CORRECT
final pixels = await tester.runAsync(() async {
  final image = await boundary.toImage(pixelRatio: 1.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final result = byteData!.buffer.asUint8List();
  image.dispose(); // Always dispose!
  return result;
});
```

## Resources

- `README.md` - Package documentation, basic usage
- `ANIMATION.md` - User guide with SMIL examples
- `ARCHITECTURE.md` - Design rationale and dual pipeline explanation
- `docs/DEVELOPMENT.md` - Complete development workflow
- `docs/README.md` - Documentation index
- `docs/REORGANIZATION.md` - Project structure organization
- `VISUAL_TESTING_GUIDELINES.md` - Comprehensive testing guide
- `CURRENT_STATUS.md` - Latest development status (updated January 2026)
- `docs/archive/` - Historical stage reports and detailed plans
- `blink-b87d44f-Source-core-svg/README.md` - Blink reference implementation guide
