# Development Guide

Complete guide for developing animated SVG features in flutter_svg.

## Quick Start

```bash
# Run tests after changes
./.fvm/flutter_sdk/bin/flutter test test/animation/

# Run example app
cd example && ../.fvm/flutter_sdk/bin/flutter run

# Run all tests
./.fvm/flutter_sdk/bin/flutter test
```

## Architecture

This package uses **two separate rendering pipelines**:

### 1. Static SVG (Production)
- Path: SVG → `vector_graphics_compiler` → `.vec` binary → `VectorGraphic` widget
- Fast, optimized, no DOM tree
- Use: `SvgPicture.asset()`, `SvgPicture.network()`

### 2. Animated SVG (Experimental)
- Path: SVG → XML parser → DOM tree → SMIL engine → `AnimatedSvgPicture`
- Preserves structure for animations
- Use: `AnimatedSvgPicture.string()`

**Why separate?** The `vector_graphics` compiler discards DOM structure, IDs, and animation elements for optimization. Animated SVG needs full DOM.

## Development Progress

Current stage/progress numbers can change quickly.
Use `/Users/denisnadey/apps/flutter_full_svg_support/CURRENT_STATUS.md` as the
single source of truth for:

- what is completed,
- what is currently broken or partial,
- and the current execution plan.

## Code Organization

```
lib/src/animation/
├── animated_svg_picture*.dart   # Main widget + feature modules
├── animated_svg_painter*.dart   # CustomPainter renderer + feature modules
├── svg_parser*.dart             # XML → DOM parser modules
├── svg_dom.dart                 # DOM model
├── svg_transform.dart           # Transform handling
├── path_*.dart                  # Path parsing/interpolation
├── css_to_smil_converter*.dart  # CSS -> SMIL conversion modules
└── smil/
    ├── smil_animation*.dart     # Animation engine modules
    ├── smil_parser*.dart        # Extract animations from DOM modules
    ├── smil_timeline*.dart      # Time management modules
    ├── interpolators.dart       # Value interpolation
    ├── motion_path.dart         # AnimateMotion
    ├── timing_condition.dart    # Timing condition model
    └── timing_parser.dart       # begin/end timing parser
```

## Testing Strategy

### Test Categories

1. **Unit tests** - Logic verification (parsers, interpolators)
2. **Integration tests** - End-to-end animation flows
3. **Golden tests** - Visual regression (50 baseline images)
4. **Visual tests** - Pixel analysis for geometry

### Running Tests

```bash
# All animation tests
./.fvm/flutter_sdk/bin/flutter test test/animation/

# Specific feature
./.fvm/flutter_sdk/bin/flutter test test/animation/smil_test.dart

# Verbose output
./.fvm/flutter_sdk/bin/flutter test test/animation/ --reporter expanded

# Skip golden tests (CI)
./.fvm/flutter_sdk/bin/flutter test test/animation/ --exclude-tags golden
```

### Visual Testing Pattern

```dart
testWidgets('animation renders correctly', (tester) async {
  await tester.pumpWidget(AnimatedSvgPicture.string(svgData));
  await tester.pump(); // Build
  await tester.pump(); // Initialize
  
  // Capture pixels (MUST use runAsync!)
  final pixels = await tester.runAsync(() async {
    final boundary = find.byType(RepaintBoundary).first;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose(); // Always dispose!
    return byteData!.buffer.asUint8List();
  });
  
  // Analyze geometry
  final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);
  expect(analysis.pixelCount, greaterThan(0));
  expect(analysis.centroid.dx, closeTo(400, 5));
});
```

**Critical Rules:**
- ✅ Wrap `toImage()` in `tester.runAsync()` (prevents hangs)
- ❌ Never use `pumpAndSettle()` with infinite animations (hangs forever)
- ✅ Always `dispose()` images

## Adding Features

### New SMIL Animation Type

1. **Parse XML** in `smil/smil_parser.dart`:
```dart
if (element.name.local == 'animateNewType') {
  return _parseAnimateNewType(element, targetNode);
}
```

2. **Interpolate** in `smil/smil_animation.dart`:
```dart
dynamic computeValue(double t) {
  return Interpolators.interpolateNewType(from, to, t);
}
```

3. **Render** in `animated_svg_painter.dart`:
```dart
void _applyAnimations(Canvas canvas, SvgNode node) {
  final value = animation.computeValue(time);
  // Apply to canvas
}
```

4. **Test** - unit, integration, visual tests

### Adding Example

1. Create `example/lib/widgets/smil_*_widget.dart`
2. Add tab to `example/lib/pages/unified_examples_page.dart`
3. Add SVG asset to `example/assets/`
4. Update info panel with description

## Debugging

### Animation Not Working?

Check in order:
1. `AnimationDetector.hasAnimations()` returns true?
2. Animations parsed in `SmilParser.parseAnimations()`?
3. Timeline ticking in `SvgTimeline.tick()`?
4. Values interpolating in `SmilAnimation.computeValue()`?
5. Painter applying in `AnimatedSvgPainter.paint()`?

### Enable Logging

```dart
print('Animations: ${timeline.animations.length}');
print('Time: ${timeline.currentTime}');
print('Value at t=$t: ${animation.computeValue(t)}');
```

## Performance Targets

From production testing:
- Path interpolation: <1ms
- AnimateMotion: 60 updates in <100ms
- Simple animations: 60 FPS
- Complex animations: 30+ FPS

## Common Pitfalls

1. **Pipeline mixing**: `SvgPicture` cannot render SMIL (compiled away)
2. **Path morphing**: Requires normalized path structures
3. **RepaintBoundary**: Captures 800x600, not widget size
4. **Memory leaks**: Always dispose images in tests

## Dependencies

- `vector_graphics` ^1.1.13 - Static rendering
- `vector_graphics_compiler` ^1.1.14 - SVG compiler
- `xml` ^6.0.0 - XML parsing

## Resources

- `.github/copilot-instructions.md` - AI agent guide
- `VISUAL_TESTING_GUIDELINES.md` - Testing details
- `docs/archive/ANIMATION_ARCHITECTURE.md` - Original architectural plan
- `docs/archive/STAGE_*` - Completed stage reports
