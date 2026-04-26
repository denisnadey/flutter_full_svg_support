# Stage 8: Advanced SMIL Features - Plan

> Historical planning document (January 2026 context).  
> For current execution order and status, use:
> - `/Users/denisnadey/apps/flutter_full_svg_support/CURRENT_STATUS.md`
> - `/Users/denisnadey/apps/flutter_full_svg_support/NEXT_STEPS.md`
> - `/Users/denisnadey/apps/flutter_full_svg_support/TODO.md`

**Estimated Duration:** 2-3 weeks  
**Priority:** Medium  
**Prerequisites:** Stage 7 (Syncbase Timing) ✅

## Overview

Stage 8 implements advanced SMIL animation features:
1. Event-based timing (begin="click")
2. calcMode="spline" with keySplines
3. calcMode="paced" for equal velocity
4. Additive and accumulate attributes

## Tasks Breakdown

### S8-1: Event-based Timing (5-7 days)

#### Goal
Enable animations to start/stop based on user interaction events.

#### Features
- `begin="click"` - Start on click
- `begin="mouseover+1s"` - Start 1s after mouseover
- `begin="click+2s; 5s"` - Multiple triggers
- Supported events: click, mousedown, mouseup, mouseover, mouseout, focusin, focusout

#### Implementation Steps

1. **Update EventCondition class** (1 day)
   ```dart
   // File: lib/src/animation/smil/timing_condition.dart
   class EventCondition extends TimingCondition {
     final String eventType;
     final Duration offset;
     final String? targetId;
     
     bool _hasTriggered = false;
     Duration? _triggeredTime;
     
     void trigger(Duration currentTime) {
       _hasTriggered = true;
       _triggeredTime = currentTime + offset;
     }
     
     @override
     bool isMet(Duration currentTime) {
       return _hasTriggered && 
              _triggeredTime != null && 
              currentTime >= _triggeredTime!;
     }
   }
   ```

2. **Add event handling to AnimatedSvgPainter** (2 days)
   ```dart
   // File: lib/src/animation/animated_svg_painter.dart
   void _handlePointerEvent(PointerEvent event, SvgNode node) {
     // Map Flutter events to SMIL event names
     final eventName = _getEventName(event);
     
     // Find animations targeting this node
     for (final anim in timeline.animations) {
       if (anim.targetNode == node) {
         for (final condition in anim.beginConditions) {
           if (condition is EventCondition && 
               condition.eventType == eventName) {
             condition.trigger(timeline.currentTime);
           }
         }
       }
     }
   }
   ```

3. **Integrate GestureDetector** (2 days)
   ```dart
   // File: lib/src/animation/animated_svg_picture.dart
   Widget build(BuildContext context) {
     return GestureDetector(
       onTap: () => _handleEvent('click'),
       onLongPress: () => _handleEvent('longpress'),
       onDoubleTap: () => _handleEvent('dblclick'),
       child: CustomPaint(painter: _painter),
     );
   }
   ```

4. **Tests and Examples** (1 day)
   - `test/animation/event_timing_test.dart` (10+ tests)
   - Example widget with clickable SVG elements

#### Files to Create/Modify
- Modify: `lib/src/animation/smil/timing_condition.dart`
- Modify: `lib/src/animation/animated_svg_picture.dart`
- Modify: `lib/src/animation/animated_svg_painter.dart`
- Create: `test/animation/event_timing_test.dart`
- Create: `example/lib/widgets/smil_event_timing_widget.dart`

---

### S8-2: calcMode="spline" (3-4 days)

#### Goal
Implement cubic bezier easing for smooth, custom interpolation curves.

#### Features
- Parse `keySplines` attribute
- Support CSS easing functions (ease, ease-in, ease-out, ease-in-out)
- Custom cubic-bezier(x1, y1, x2, y2) curves

#### Implementation Steps

1. **Create CubicBezier class** (1 day)
   ```dart
   // File: lib/src/animation/smil/cubic_bezier.dart
   class CubicBezier {
     final double x1, y1, x2, y2;
     
     CubicBezier(this.x1, this.y1, this.x2, this.y2);
     
     // Newton-Raphson method to solve for t given x
     double solve(double x, [double epsilon = 1e-6]) {
       double t = x;
       for (int i = 0; i < 8; i++) {
         final xt = _sampleCurveX(t);
         final dt = x - xt;
         if (dt.abs() < epsilon) break;
         final slope = _sampleCurveDerivativeX(t);
         if (slope.abs() < epsilon) break;
         t -= dt / slope;
       }
       return _sampleCurveY(t);
     }
     
     double _sampleCurveX(double t) {
       return ((1 - 3*x2 + 3*x1)*t*t*t + 
               (3*x2 - 6*x1)*t*t + 
               3*x1*t);
     }
     
     // CSS presets
     static final ease = CubicBezier(0.25, 0.1, 0.25, 1.0);
     static final easeIn = CubicBezier(0.42, 0, 1.0, 1.0);
     static final easeOut = CubicBezier(0, 0, 0.58, 1.0);
     static final easeInOut = CubicBezier(0.42, 0, 0.58, 1.0);
   }
   ```

2. **Update SmilAnimation** (1 day)
   ```dart
   // File: lib/src/animation/smil/smil_animation.dart
   Object? computeValue(double t) {
     if (calcMode == SmilCalcMode.spline) {
       return _computeSplineValue(t);
     }
     // ... existing code
   }
   
   Object? _computeSplineValue(double t) {
     // Find segment
     final segmentIndex = _findSegmentIndex(t);
     final localT = _computeLocalT(t, segmentIndex);
     
     // Apply keySpline for this segment
     final spline = keySplines![segmentIndex];
     final easedT = spline.solve(localT);
     
     // Interpolate
     return _interpolateSegment(segmentIndex, easedT);
   }
   ```

3. **Parse keySplines** (1 day)
   ```dart
   // File: lib/src/animation/smil/smil_parser.dart
   List<CubicBezier>? _parseKeySplines(String value) {
     // Format: "0.1 0.2 0.3 0.4; 0.5 0.6 0.7 0.8"
     final splines = <CubicBezier>[];
     for (final part in value.split(';')) {
       final coords = part.trim().split(RegExp(r'\s+'));
       if (coords.length == 4) {
         splines.add(CubicBezier(
           double.parse(coords[0]),
           double.parse(coords[1]),
           double.parse(coords[2]),
           double.parse(coords[3]),
         ));
       }
     }
     return splines;
   }
   ```

4. **Tests and Examples** (1 day)
   - Unit tests for CubicBezier.solve()
   - Visual comparison: linear vs ease vs ease-in-out
   - Interactive demo with different easing functions

#### Files to Create/Modify
- Create: `lib/src/animation/smil/cubic_bezier.dart`
- Modify: `lib/src/animation/smil/smil_animation.dart`
- Modify: `lib/src/animation/smil/smil_parser.dart`
- Create: `test/animation/cubic_bezier_test.dart`
- Create: `test/animation/spline_calcmode_test.dart`
- Create: `example/lib/widgets/smil_easing_widget.dart`

---

### S8-3: calcMode="paced" (3-4 days)

#### Goal
Automatically adjust keyTimes to maintain equal velocity throughout animation.

#### Features
- Calculate distance between values
- Generate keyTimes for equal velocity
- Support numeric, path, and color animations

#### Implementation Steps

1. **Create distance calculators** (2 days)
   ```dart
   // File: lib/src/animation/smil/distance_calculator.dart
   abstract class DistanceCalculator {
     double distance(Object? from, Object? to);
   }
   
   class NumericDistance extends DistanceCalculator {
     @override
     double distance(Object? from, Object? to) {
       return ((to as double) - (from as double)).abs();
     }
   }
   
   class PathDistance extends DistanceCalculator {
     @override
     double distance(Object? from, Object? to) {
       final path1 = from as Path;
       final path2 = to as Path;
       final metrics1 = path1.computeMetrics().first;
       final metrics2 = path2.computeMetrics().first;
       return (metrics2.length - metrics1.length).abs();
     }
   }
   
   class ColorDistance extends DistanceCalculator {
     @override
     double distance(Object? from, Object? to) {
       final c1 = from as Color;
       final c2 = to as Color;
       // Euclidean distance in RGB space
       final dr = c2.red - c1.red;
       final dg = c2.green - c1.green;
       final db = c2.blue - c1.blue;
       return math.sqrt(dr*dr + dg*dg + db*db);
     }
   }
   ```

2. **Generate paced keyTimes** (1 day)
   ```dart
   // File: lib/src/animation/smil/smil_animation.dart
   List<double>? _generatePacedKeyTimes() {
     if (values == null || values!.length < 2) return null;
     
     // Calculate distances between consecutive values
     final distances = <double>[];
     for (int i = 0; i < values!.length - 1; i++) {
       distances.add(_calculator.distance(values![i], values![i+1]));
     }
     
     // Calculate cumulative distances
     final totalDistance = distances.reduce((a, b) => a + b);
     double cumulative = 0.0;
     final keyTimes = [0.0];
     
     for (final d in distances) {
       cumulative += d;
       keyTimes.add(cumulative / totalDistance);
     }
     
     return keyTimes;
   }
   ```

3. **Integrate into SmilAnimation** (1 day)
   - Detect calcMode="paced"
   - Generate keyTimes at initialization
   - Use generated keyTimes for interpolation

4. **Tests and Examples** (1 day)
   - Unit tests for distance calculators
   - Visual comparison: linear vs paced
   - Path animation with equal velocity

#### Files to Create/Modify
- Create: `lib/src/animation/smil/distance_calculator.dart`
- Modify: `lib/src/animation/smil/smil_animation.dart`
- Create: `test/animation/distance_calculator_test.dart`
- Create: `test/animation/paced_calcmode_test.dart`
- Create: `example/lib/widgets/smil_paced_widget.dart`

---

### S8-4: Additive & Accumulate (2-3 days)

#### Goal
Support value composition for complex animations.

#### Features
- `additive="sum"` - Add to base value
- `accumulate="sum"` - Accumulate across repeats

#### Implementation Steps

1. **Store base value** (1 day)
   ```dart
   // File: lib/src/animation/smil/smil_animation.dart
   Object? _baseValue; // Initial value before animation
   
   void _captureBaseValue() {
     _baseValue = targetNode.getAttribute(attributeName);
   }
   ```

2. **Implement additive** (1 day)
   ```dart
   Object? _applyAdditive(Object? animValue) {
     if (additive == SmilAdditiveMode.replace) {
       return animValue;
     }
     
     // additive="sum" - add to base value
     if (_baseValue is double && animValue is double) {
       return (_baseValue as double) + animValue;
     }
     
     // Similar logic for colors, transforms, etc.
     return animValue;
   }
   ```

3. **Implement accumulate** (1 day)
   ```dart
   Object? _applyAccumulate(Object? animValue) {
     if (!accumulate || _currentIteration == 0) {
       return animValue;
     }
     
     // Multiply by iteration count
     if (animValue is double) {
       return animValue * (_currentIteration + 1);
     }
     
     return animValue;
   }
   ```

4. **Tests and Examples** (1 day)
   - Additive animation examples
   - Accumulate with repeatCount
   - Combined additive + accumulate

#### Files to Create/Modify
- Modify: `lib/src/animation/smil/smil_animation.dart`
- Create: `test/animation/additive_test.dart`
- Create: `test/animation/accumulate_test.dart`
- Create: `example/lib/widgets/smil_additive_widget.dart`

---

## Testing Strategy

### Unit Tests (~40 tests)
- CubicBezier.solve() correctness
- Distance calculators accuracy
- keyTimes generation for paced mode
- Additive/accumulate value composition

### Integration Tests (~30 tests)
- Event-triggered animations
- Spline interpolation end-to-end
- Paced animations with different value types
- Additive animations with repeats

### Visual Tests (~10 tests)
- Side-by-side linear vs spline vs paced
- Interactive event demos
- Accumulate visualization

## Example App Additions

**New Widgets:**
1. `smil_event_timing_widget.dart` - Interactive click/hover demos
2. `smil_easing_widget.dart` - Easing function comparisons
3. `smil_paced_widget.dart` - Equal velocity demonstrations
4. `smil_additive_widget.dart` - Additive/accumulate examples

**New Tab in Unified Examples:**
- "Advanced" tab with 4 sub-sections

## Success Criteria

- ✅ All 80+ new tests pass
- ✅ Event-based animations respond to clicks/hovers
- ✅ Spline interpolation produces smooth curves
- ✅ Paced mode maintains equal velocity
- ✅ Additive/accumulate work correctly
- ✅ Example app demonstrates all features
- ✅ Documentation updated

## Estimated Timeline

| Task | Duration | Days |
|------|----------|------|
| S8-1: Event-based Timing | 5-7 days | Week 1 |
| S8-2: calcMode="spline" | 3-4 days | Week 2 |
| S8-3: calcMode="paced" | 3-4 days | Week 2 |
| S8-4: Additive/Accumulate | 2-3 days | Week 3 |
| **Total** | **13-18 days** | **2-3 weeks** |

## Next Steps

After Stage 8:
- **Stage 9:** CSS Animations (@keyframes)
- **Stage 10:** CSS Transitions
- **Stage 11:** Performance optimizations
- **Stage 12:** Documentation and production readiness

## References

- [SMIL Animation Spec](https://www.w3.org/TR/smil-animation/)
- [SVG Animation](https://www.w3.org/TR/SVG11/animate.html)
- Blink: `blink-b87d44f-Source-core-svg/animation/`
- CSS Timing Functions: [MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/easing-function)
