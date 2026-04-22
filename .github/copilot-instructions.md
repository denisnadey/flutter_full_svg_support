# flutter_svg AI Development Guide

**Last Updated:** March 16, 2026

## CRITICAL: Read These First

Before ANY work, check these authoritative files:

| File | Purpose | Check When |
|------|---------|------------|
| `CURRENT_STATUS.md` | **Single source of truth** for project state | ALWAYS first |
| `doc/RESOLVED_ISSUES.md` | Closed bugs - DO NOT reopen | Before fixing any bug |
| `TODO.md` | Active work queue with priorities | Before starting new work |
| `NEXT_STEPS.md` | Execution order | For task prioritization |

## Project Overview

**flutter_svg** - Flutter SVG rendering with full SMIL and CSS animation support.

### Dual Pipeline Architecture

```
Pipeline 1: STATIC (Production)
SVG → vector_graphics_compiler → .vec binary → VectorGraphic widget
✅ Fast, optimized  ❌ No animations, no DOM

Pipeline 2: ANIMATED (Experimental)  
SVG → SvgParser → DOM tree → SmilParser → SvgTimeline → AnimatedSvgPainter
✅ Full SMIL/CSS animations  ⚠️ Slower than static
```

**Critical**: Pipelines are INTENTIONALLY separate. Static pipeline discards DOM structure needed for animations.

## Current State (March 2026)

- **Tests:** 691+ passing
- **Analyze:** 26 info (deprecations), 0 errors, 0 warnings
- **Flutter SDK:** 3.38.1 (via FVM)

### What's Implemented

| Feature | Status |
|---------|--------|
| SMIL: `<animate>`, `<animateTransform>`, `<animateMotion>`, `<set>` | ✅ Full |
| CSS: `@keyframes`, `animation-*` properties | ✅ Baseline |
| SVG Filters: 17 primitives | ✅ Baseline |
| Gradients, clipPath, mask | ✅ Full |
| Hit-testing & events | ✅ Baseline |
| `calcMode`: linear, discrete, spline, paced | ✅ Full |
| Syncbase timing: `begin="anim.end+2s"` | ✅ Full |

### Current Priorities (P0-P3)

From `TODO.md` - work on these in order:

1. **P0:** Advanced filter graph semantics
2. **P0:** Advanced hit-testing (clipPath/mask/use/text)
3. **P1:** Advanced text typography parity
4. **P1:** Advanced `<use>`/`<symbol>` inheritance
5. **P2:** CSS/SMIL edge-case regression fixtures

## Commands

```bash
# ALWAYS use FVM Flutter:
./.fvm/flutter_sdk/bin/flutter test
./.fvm/flutter_sdk/bin/flutter analyze

# Targeted tests
./.fvm/flutter_sdk/bin/flutter test test/animation/

# Example app
cd example && ../.fvm/flutter_sdk/bin/flutter run
```

## Code Organization

```
lib/src/animation/
├── animated_svg_picture*.dart   # Main widget (359 lines + 10 part files)
├── animated_svg_painter*.dart   # Renderer (19 files)
├── svg_parser*.dart             # XML→DOM (5 files)
├── svg_dom.dart                 # DOM model
├── css_animations*.dart         # CSS parsing (5 files)
├── css_to_smil_converter*.dart  # CSS→SMIL (7 files)
├── path_*.dart                  # Path processing (8 files)
├── svg_filters*.dart            # Filter pipeline (8 files)
└── smil/                        # SMIL engine (20 files)
    ├── smil_animation*.dart
    ├── smil_parser*.dart
    ├── smil_timeline*.dart
    ├── interpolators*.dart
    └── ...
```

## Development Workflow

### Before Starting Any Task

1. **Check `doc/RESOLVED_ISSUES.md`** - Is this already fixed?
2. **Check `CURRENT_STATUS.md`** - Current implementation state
3. **Check `TODO.md`** - Is this in the queue? What priority?

### Making Changes

1. Write/update test FIRST
2. Implement change
3. Run: `./.fvm/flutter_sdk/bin/flutter test`
4. Run: `./.fvm/flutter_sdk/bin/flutter analyze`
5. Update docs if factual state changed

### After Completing Work

Update these files:
- `CURRENT_STATUS.md` - If factual state changed
- `TODO.md` - Mark tasks complete
- `doc/RESOLVED_ISSUES.md` - If closing a bug class

## Testing Patterns

### Critical Rules

```dart
// ❌ NEVER use pumpAndSettle with infinite animations (hangs forever)
await tester.pumpAndSettle();

// ✅ Use explicit pump
await tester.pump();
await tester.pump(Duration(milliseconds: 500));

// ✅ Wrap toImage in runAsync
final pixels = await tester.runAsync(() async {
  final image = await boundary.toImage(pixelRatio: 1.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose(); // Always dispose!
  return byteData!.buffer.asUint8List();
});
```

### Test Organization

```
test/animation/           # 40+ test files
├── smil_*.dart          # SMIL engine tests
├── css_*.dart           # CSS animation tests
├── path_*.dart          # Path processing tests
├── filter_*.dart        # Filter tests
├── *_golden_test.dart   # Visual regression (50 baselines)
└── visual_*.dart        # Pixel analysis tests
```

## Common Patterns

### Adding New Feature

1. Parse in `svg_parser*.dart` or `smil/smil_parser*.dart`
2. Add interpolation in `smil/interpolators*.dart`
3. Render in `animated_svg_painter*.dart`
4. Add tests in `test/animation/`

### Debugging Animation Issues

Check in order:
1. `AnimationDetector.hasAnimations()` returns true?
2. `SmilParser.parseAnimations()` creates animation objects?
3. `SvgTimeline.tick()` advancing?
4. `SmilAnimation.computeValue()` interpolating?
5. `AnimatedSvgPainter.paint()` applying values?

## File Modularization Pattern

Large files are split using Dart `part`/`part of`:

```dart
// Main file: animated_svg_painter.dart
part 'animated_svg_painter_shapes.dart';
part 'animated_svg_painter_gradients.dart';
// ...

// Part file: animated_svg_painter_shapes.dart
part of 'animated_svg_painter.dart';
// Implementation...
```

When splitting files:
1. Keep public API stable
2. Run full regression after each split
3. Update `doc/RESOLVED_ISSUES.md` with closed milestone

## Reference Implementation

`blink-b87d44f-Source-core-svg/` contains Chromium's SVG implementation. Use for:
- Understanding spec-compliant behavior
- Debugging complex SMIL features
- Reference when implementing Blink parity

See `doc/BLINK_PARITY_AUDIT.md` for gap analysis.

## Documentation Map

```
Essential (check frequently):
├── CURRENT_STATUS.md          # Single source of truth
├── TODO.md                    # Work queue
├── NEXT_STEPS.md              # Execution order
└── doc/RESOLVED_ISSUES.md    # Closed issues registry

Reference:
├── ARCHITECTURE.md            # Design rationale
├── ANIMATION.md               # User guide
├── VISUAL_TESTING_GUIDELINES.md
├── doc/DEVELOPMENT.md        # Dev workflow
├── doc/BLINK_PARITY_AUDIT.md # Blink gap matrix
└── doc/archive/              # Historical docs
```

## Critical Don'ts

1. **Don't reopen closed issues** without failing regression test
2. **Don't mix pipelines** - `SvgPicture` cannot render SMIL
3. **Don't use system Flutter** - Always use `./.fvm/flutter_sdk/bin/flutter`
4. **Don't skip tests** - Run full suite after changes
5. **Don't guess** - Check authoritative docs first

## Quick Reference

| Need | File |
|------|------|
| Current state | `CURRENT_STATUS.md` |
| What to work on | `TODO.md` → `NEXT_STEPS.md` |
| Is this fixed? | `doc/RESOLVED_ISSUES.md` |
| How does X work? | `ARCHITECTURE.md` |
| Blink gaps | `doc/BLINK_PARITY_AUDIT.md` |
| Testing patterns | `VISUAL_TESTING_GUIDELINES.md` |
| Dev workflow | `doc/DEVELOPMENT.md` |
