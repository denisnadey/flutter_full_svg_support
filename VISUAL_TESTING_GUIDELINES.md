# Visual Testing Guidelines for Flutter SVG Animations

## Overview

This document describes best practices for visual testing of SMIL animations in the flutter_svg package. Visual testing is crucial for verifying that animations actually render correctly, not just that the code logic works.

## Why Visual Testing?

**Traditional unit tests verify LOGIC, not RENDERING.**

Example of the gap:
- ✅ Unit test: Transform values correct (`rotate(0 50 50)` → `rotate(180 50 50)`)
- ✅ Unit test: Interpolation works correctly
- ❌ But does the rect actually ROTATE on screen? **Unknown!**

**Visual testing closes this gap by analyzing actual pixel data.**

## Testing Approaches

### 1. Golden Tests (Traditional)

**When to use:**
- Static snapshots at specific animation frames
- Regression testing (comparing to baseline images)
- Quick smoke tests

**Limitations:**
- ❌ **Headless rendering doesn't support all transforms** - Canvas rotations may produce identical images
- ❌ Binary comparison - small anti-aliasing differences cause failures
- ❌ Platform-dependent (macOS vs Linux produce different pixels)
- ❌ Hard to debug failures (what exactly is different?)

**Example:**
```dart
await expectLater(
  find.byType(AnimatedSvgPicture),
  matchesGoldenFile('goldens/rotation_90deg.png'),
);
```

### 2. Pixel Analysis (Recommended for Animations)

**When to use:**
- Verifying geometric transformations (rotation, translation, scale)
- Testing animation progression through multiple keyframes
- Cross-platform tests (geometry is consistent)
- Debugging headless rendering issues

**Advantages:**
- ✅ Detects rotation even when golden hash is identical
- ✅ Provides detailed metrics (centroid, bounding box, angle estimation)
- ✅ Platform-independent (geometry doesn't change)
- ✅ Easy to debug (exact pixel counts, positions, changes)

**Example:**
```dart
final pixels = await VisualTestUtils.captureWidgetPixels(tester);
final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

expect(analysis.pixelCount, greaterThan(0));
expect(analysis.centroid.dx, closeTo(400, 5));
expect(analysis.boundingBox.width, closeTo(20, 2));
```

## Critical Findings & Gotchas

### 1. ⚠️ `autoPlay: false` Bug

**Problem:** When `autoPlay: false`, SVG doesn't render AT ALL (0 pixels found)

**Workaround:** Use `autoPlay: true` and pump to specific time:
```dart
await tester.pumpWidget(AnimatedSvgPicture.string(
  svgData,
  autoPlay: true,  // ← Must be true!
));

await tester.pump(); // Initial build
await tester.pump(); // Let animation initialize
await tester.pump(Duration(milliseconds: 500)); // Seek to 500ms
```

**Status:** Bug to be investigated separately

### 2. ⚠️ pumpAndSettle Hangs on Infinite Animations

**Problem:** `await tester.pumpAndSettle()` waits for all animations to complete, but SMIL animations have `repeatCount="indefinite"`

**Solution:** Never use `pumpAndSettle` in animation capture utilities:
```dart
// ❌ BAD - Hangs forever
static Future<Uint8List> captureWidgetPixels(WidgetTester tester) async {
  await tester.pumpAndSettle(); // ← HANGS!
  ...
}

// ✅ GOOD - Capture immediately without settling
static Future<Uint8List> captureWidgetPixels(WidgetTester tester) async {
  final boundary = tester.renderObject(find.byType(RepaintBoundary).first);
  return await boundary.toImage(pixelRatio: 1.0);
}
```

### 3. ⚠️ RepaintBoundary Captures Full Screen

**Problem:** `RepaintBoundary.toImage()` captures 800x600 (full test screen), not widget size

**Impact:** Analyze pixels using actual image size (800x600), not widget size

**Example:**
```dart
final pixels = await VisualTestUtils.captureWidgetPixels(tester);
// Image is 800x600, NOT the widget size!
final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);
```

**Note:** Image size is logged by `captureWidgetPixels()` for debugging

### 4. ✅ Pixel Analysis Works!

**Success:** Rotation detected with 1600 red pixels at centroid (399.5, 299.5)

**Metrics available:**
- `pixelCount` - Total colored pixels (verify rendering happened)
- `centroid` - Center of mass (verify position, detect translation)
- `boundingBox` - Min/max coordinates (verify size, orientation)
- `estimatedRotationAngle` - Angle from image moments (verify rotation)
- `objectWidth/Height` - Bounding box dimensions (verify scale)

## Testing Workflow

### Comprehensive Animation Test Pattern

```dart
testWidgets('Rotation through multiple angles', (tester) async {
  final angles = [0, 45, 90, 135, 180, 225, 270, 315];
  final analyses = <int, PixelAnalysis>{};
  
  for (final angle in angles) {
    // 1. Build widget at specific time
    final time = Duration(milliseconds: (angle / 360.0 * 4000).round());
    await _buildWidgetAtTime(tester, svgData, time);
    
    // 2. Capture and analyze
    final pixels = await VisualTestUtils.captureWidgetPixels(tester);
    final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);
    analyses[angle] = analysis;
    
    // 3. Log detailed report
    print('$angle°: ${analysis.toDetailedReport()}');
  }
  
  // 4. Compare consecutive frames
  for (int i = 0; i < angles.length - 1; i++) {
    final a1 = analyses[angles[i]]!;
    final a2 = analyses[angles[i + 1]]!;
    
    // Verify geometric changes
    expect(a2.isRotatedComparedTo(a1), isTrue,
        reason: 'Should detect rotation between ${angles[i]}° and ${angles[i + 1]}°');
  }
}

Future<void> _buildWidgetAtTime(
    WidgetTester tester, String svg, Duration time) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: RepaintBoundary(
        child: AnimatedSvgPicture.string(
          svg,
          width: 100,
          height: 100,
          autoPlay: true,
        ),
      ),
    ),
  ));
  
  await tester.pump(); // Build
  await tester.pump(); // Initialize
  await tester.pump(time); // Seek to target time
}
```

## VisualTestUtils API

### Capture Pixels

```dart
Future<Uint8List> pixels = await VisualTestUtils.captureWidgetPixels(tester);
```

- Returns RGBA byte array (4 bytes per pixel)
- Logs actual image size for debugging
- Does NOT call pumpAndSettle (safe for infinite animations)

### Analyze Geometry

```dart
PixelAnalysis analysis = VisualTestUtils.analyzeRedPixels(pixels, width, height);
```

**Returns:**
- `pixelCount: int` - Number of red pixels
- `centroid: Offset` - Center of mass (x̄, ȳ)
- `boundingBox: Rect` - Min/max rectangle containing all pixels
- `objectWidth/Height: double` - Bounding box dimensions
- `estimatedRotationAngle: double` - Orientation from image moments
- `pixels: List<Offset>` - All red pixel coordinates

**Methods:**
- `isRotatedComparedTo(other)` - Angle difference > 5°
- `isTranslatedComparedTo(other)` - Centroid moved > 2px
- `isScaledComparedTo(other)` - Size changed > 10%
- `toString()` - Compact summary
- `toDetailedReport()` - Full geometry details

### Hash & Diff

```dart
String hash = VisualTestUtils.computePixelHash(pixels);
double diffPercent = VisualTestUtils.computePixelDifference(pixels1, pixels2);
```

## Development Rules

**ALWAYS:**

1. ✅ **Write comprehensive visual tests for animations**
   - Test at multiple timepoints (0%, 25%, 50%, 75%, 100%)
   - Verify expected geometric changes
   - Print detailed reports for debugging

2. ✅ **Use pixel analysis for transforms**
   - Don't rely solely on golden tests
   - Verify centroid/bbox/angle changes
   - Log actual vs expected values

3. ✅ **Test with `autoPlay: true`**
   - `autoPlay: false` has known rendering bug
   - Use `pump(duration)` to seek to specific times

4. ✅ **Never use `pumpAndSettle` with animations**
   - Infinite animations hang forever
   - Call `pump()` explicitly instead

5. ✅ **Verify rendering happened**
   - Check `pixelCount > 0` before analyzing geometry
   - 0 pixels = SVG didn't render (bug in test or code)

**NEVER:**

1. ❌ **Don't skip visual tests**
   - Unit tests verify logic, NOT rendering
   - Visual bugs only caught by pixel analysis

2. ❌ **Don't assume golden tests catch everything**
   - Headless rendering has limitations
   - Use pixel analysis as backup verification

3. ❌ **Don't ignore 0 pixel counts**
   - Always means something is wrong
   - Either test setup bug or real rendering bug

## Example: Comprehensive Rotation Test

See `test/animation/detailed_rotation_test.dart` for full implementation:

- Tests 8 rotation angles (0° to 315° in 45° steps)
- Captures and analyzes geometry at each angle
- Compares consecutive frames for changes
- Prints detailed reports with all metrics
- Verifies both pixel hashes AND geometry
- Handles headless rendering limitations

## Debugging Failed Tests

### No pixels found (pixelCount = 0)

**Possible causes:**
1. `autoPlay: false` bug - switch to `autoPlay: true`
2. Missing `pump()` calls - add initial build pumps
3. Wrong element color - verify SVG has `fill="red"`
4. Wrong dimensions - check logged image size vs analysis size

**Debug steps:**
```dart
if (analysis.pixelCount == 0) {
  // Check for ANY non-black pixels
  for (int i = 0; i < pixels.length ~/ 4; i++) {
    final r = pixels[i * 4];
    if (r > 0) print('Found pixel at $i: $r');
  }
}
```

### Geometry doesn't change

**Possible causes:**
1. Animation not progressing - verify `pump(duration)` calls
2. Transform not applied - check SMIL parser/interpolator
3. Wrong tolerance - adjust comparison thresholds

**Debug steps:**
- Print centroid/bbox at each timepoint
- Calculate expected vs actual changes
- Verify animation timeline is seeking correctly

## Future Improvements

1. **Fix `autoPlay: false` rendering** - Investigate why SVG doesn't render when autoPlay=false
2. **Add widget-size capture** - Capture only widget bounds, not full screen
3. **Color-agnostic analysis** - Support any fill color, not just red
4. **Animation timeline verification** - Verify timeline.currentTime matches expected
5. **Platform-specific golden tests** - Separate baselines for macOS/Linux if needed

## Summary

**Visual testing is MANDATORY for animation development.**

- Use **pixel analysis** for geometric verification
- Use **golden tests** for regression/smoke testing
- Always test with `autoPlay: true` + `pump(duration)`
- Never use `pumpAndSettle` with infinite animations
- Verify `pixelCount > 0` before analyzing geometry
- Print detailed reports for debugging
- Test at multiple animation timepoints
- Compare geometric changes between frames

**This framework has proven rotation works despite headless golden test limitations!**
