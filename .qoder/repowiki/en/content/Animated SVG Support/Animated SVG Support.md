# Animated SVG Support

<cite>
**Referenced Files in This Document**
- [ANIMATION.md](file://ANIMATION.md)
- [ARCHITECTURE.md](file://ARCHITECTURE.md)
- [lib/src/animation.dart](file://lib/src/animation.dart)
- [lib/src/animation/animated_svg_picture.dart](file://lib/src/animation/animated_svg_picture.dart)
- [lib/src/animation/animated_svg_controller.dart](file://lib/src/animation/animated_svg_controller.dart)
- [lib/src/animation/smil/smil_timeline.dart](file://lib/src/animation/smil/smil_timeline.dart)
- [lib/src/animation/smil/smil_animation.dart](file://lib/src/animation/smil/smil_animation.dart)
- [lib/src/animation/smil/smil_parser.dart](file://lib/src/animation/smil/smil_parser.dart)
- [lib/src/animation/smil/interpolators.dart](file://lib/src/animation/smil/interpolators.dart)
- [lib/src/animation/smil/motion_path.dart](file://lib/src/animation/smil/motion_path.dart)
- [lib/src/animation/css_to_smil_converter.dart](file://lib/src/animation/css_to_smil_converter.dart)
- [lib/src/animation/svg_dom.dart](file://lib/src/animation/svg_dom.dart)
- [lib/src/animation/animated_svg_picture_utils.dart](file://lib/src/animation/animated_svg_picture_utils.dart)
- [lib/src/animation/animated_svg_picture_utils_attrs.dart](file://lib/src/animation/animated_svg_picture_utils_attrs.dart)
- [lib/src/animation/animated_svg_picture_utils_style.dart](file://lib/src/animation/animated_svg_picture_utils_style.dart)
- [lib/src/animation/animated_svg_picture_utils_transform.dart](file://lib/src/animation/animated_svg_picture_utils_transform.dart)
- [lib/src/animation/animated_svg_picture_hit_test_text_layout.dart](file://lib/src/animation/animated_svg_picture_hit_test_text_layout.dart)
- [lib/src/animation/animated_svg_painter_text_style.dart](file://lib/src/animation/animated_svg_painter_text_style.dart)
- [lib/src/animation/animated_svg_painter_text_paint.dart](file://lib/src/animation/animated_svg_painter_text_paint.dart)
- [lib/src/animation/animated_svg_picture_hit_test_text_path_segments.dart](file://lib/src/animation/animated_svg_picture_hit_test_text_path_segments.dart)
- [lib/src/animation/animated_svg_picture_hit_test_text_runs.dart](file://lib/src/animation/animated_svg_picture_hit_test_text_runs.dart)
- [lib/src/animation/animated_svg_painter.dart](file://lib/src/animation/animated_svg_painter.dart)
- [lib/src/animation/animated_svg_painter_gradients.dart](file://lib/src/animation/animated_svg_painter_gradients.dart)
- [lib/src/animation/animated_svg_painter_patterns.dart](file://lib/src/animation/animated_svg_painter_patterns.dart)
- [lib/src/animation/animated_svg_painter_paint_order.dart](file://lib/src/animation/animated_svg_painter_paint_order.dart)
- [lib/src/animation/animated_svg_painter_markers.dart](file://lib/src/animation/animated_svg_painter_markers.dart)
- [test/animation/paint_order_test.dart](file://test/animation/paint_order_test.dart)
- [test/animation/marker_test.dart](file://test/animation/marker_test.dart)
- [test/animation/pattern_test.dart](file://test/animation/pattern_test.dart)
</cite>

## Update Summary
**Changes Made**
- Added comprehensive documentation for new paint order system with fill, stroke, and markers layer control
- Documented complete marker support system including marker resolution, positioning, and orientation
- Added extensive pattern implementation documentation with pattern units, inheritance, and caching
- Enhanced gradient and paint handling with new utility classes and caching mechanisms
- Updated paint server resolution to support both gradients and patterns
- Added performance considerations for new caching systems

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [Paint Order System](#paint-order-system)
7. [Marker Support](#marker-support)
8. [Pattern Implementation](#pattern-implementation)
9. [Enhanced Gradient and Paint Handling](#enhanced-gradient-and-paint-handling)
10. [Utility Classes and Parsing Mechanisms](#utility-classes-and-parsing-mechanisms)
11. [Enhanced Text Rendering and Hit-Testing](#enhanced-text-rendering-and-hit-testing)
12. [Dependency Analysis](#dependency-analysis)
13. [Performance Considerations](#performance-considerations)
14. [Troubleshooting Guide](#troubleshooting-guide)
15. [Conclusion](#conclusion)
16. [Appendices](#appendices)

## Introduction
This document explains the animated SVG support built around the experimental SMIL animation system. It covers the animation architecture, SMIL specification compliance, animation control mechanisms, and CSS animation conversion capabilities. It documents the AnimatedSvgPicture widget, animation timeline management, controller system, and real-time playback controls. Both conceptual overviews for beginners and technical details for experienced developers are included, with terminology aligned to the codebase. Practical examples demonstrate animation creation, control, and optimization, along with public interfaces, animation parameters, and controller methods. Limitations, debugging approaches, and migration paths from CSS animations are also addressed.

**Updated** Added comprehensive documentation for new paint order system, marker support, pattern implementation, and enhanced gradient and paint handling capabilities. These additions provide complete SVG paint server support with caching mechanisms for optimal performance.

## Project Structure
The animated SVG pipeline is implemented as a separate, parallel system from the production static SVG renderer. It parses SVG to a DOM, extracts SMIL and CSS animations, manages timelines, and renders via a CustomPainter. The new paint system extends the rendering pipeline with comprehensive support for paint servers, markers, and pattern fills with caching mechanisms.

```mermaid
graph TB
subgraph "Parsing"
A["SvgParser<br/>XML → DOM"] --> B["SvgDocument<br/>root, idMap, cssKeyframes"]
end
subgraph "Animation Extraction"
B --> C["SmilParser<br/>parseAnimations()"]
C --> D["List<SmilAnimation>"]
C --> E["CSS → SMIL Converter<br/>CssToSmilConverter.convert()"]
E --> D
end
subgraph "Timeline & Control"
D --> F["SvgTimeline<br/>tick(), seek(), triggerEvent()"]
G["AnimatedSvgController<br/>pause/resume/seek/rate/reverse"] --> F
H["AnimatedSvgPicture<br/>widget + CustomPainter"] --> F
end
subgraph "Enhanced Rendering Pipeline"
F --> I["AnimatedSvgPainter<br/>reads effective values"]
I --> J["Paint Server Resolution<br/>Gradients + Patterns"]
J --> K["Marker Placement<br/>Position + Orientation"]
K --> L["Pattern Application<br/>Caching + Tiling"]
L --> M["Canvas rendering"]
end
subgraph "Utility Layer"
N["animated_svg_picture_utils_attrs.dart<br/>Attribute parsing & resolution"] --> I
O["animated_svg_picture_utils_style.dart<br/>Style parsing & font handling"] --> I
P["animated_svg_picture_utils_transform.dart<br/>Transform parsing & application"] --> I
Q["animated_svg_picture_utils.dart<br/>Core utilities & helpers"] --> I
end
```

**Diagram sources**
- [lib/src/animation/smil/smil_parser.dart:17-37](file://lib/src/animation/smil/smil_parser.dart#L17-L37)
- [lib/src/animation/css_to_smil_converter.dart:17-66](file://lib/src/animation/css_to_smil_converter.dart#L17-L66)
- [lib/src/animation/smil/smil_timeline.dart:22-29](file://lib/src/animation/smil/smil_timeline.dart#L22-L29)
- [lib/src/animation/animated_svg_controller.dart:25-131](file://lib/src/animation/animated_svg_controller.dart#L25-L131)
- [lib/src/animation/animated_svg_picture.dart:108-164](file://lib/src/animation/animated_svg_picture.dart#L108-L164)
- [lib/src/animation/svg_dom.dart:266-317](file://lib/src/animation/svg_dom.dart#L266-L317)
- [lib/src/animation/animated_svg_painter_gradients.dart:1-44](file://lib/src/animation/animated_svg_painter_gradients.dart#L1-L44)
- [lib/src/animation/animated_svg_painter_patterns.dart:1-183](file://lib/src/animation/animated_svg_painter_patterns.dart#L1-L183)
- [lib/src/animation/animated_svg_painter_markers.dart:1-449](file://lib/src/animation/animated_svg_painter_markers.dart#L1-L449)
- [lib/src/animation/animated_svg_painter_paint_order.dart:1-90](file://lib/src/animation/animated_svg_painter_paint_order.dart#L1-L90)

**Section sources**
- [ARCHITECTURE.md:6-58](file://ARCHITECTURE.md#L6-L58)
- [lib/src/animation.dart:21-31](file://lib/src/animation.dart#L21-L31)

## Core Components
- AnimatedSvgPicture: The public widget that loads and renders animated SVGs, integrates with AnimationController/Ticker, and exposes playback controls and tracing.
- AnimatedSvgController: A ChangeNotifier-based controller enabling programmatic control of playback (pause/resume, seek, playback rate, direction).
- SvgTimeline: Manages global time, resolves timing conditions (including syncbase and event-based), and updates all animations.
- SmilAnimation: Encapsulates SMIL animation semantics (types, calc modes, fill modes, additive/accumulate behavior, values/keyframes).
- SmilParser: Extracts SMIL animations from DOM and converts CSS animations to SMIL equivalents.
- Interpolators: Provides type-aware interpolation for numbers, colors, transforms, paths, and lists.
- MotionPath: Computes positions and angles along SVG paths for animateMotion with keyPoints support.
- SvgDom: Defines the DOM model with AnimatableSvgAttribute and SvgNode for attribute mutation and tree traversal.
- **Enhanced Rendering System**: AnimatedSvgPainter with comprehensive paint server support, marker placement, pattern application, and paint order control.
- **New Utility Classes**: Centralized parsing and resolution mechanisms for consistent attribute, style, and transform handling.

**Section sources**
- [lib/src/animation/animated_svg_picture.dart:108-164](file://lib/src/animation/animated_svg_picture.dart#L108-L164)
- [lib/src/animation/animated_svg_controller.dart:25-131](file://lib/src/animation/animated_svg_controller.dart#L25-L131)
- [lib/src/animation/smil/smil_timeline.dart:20-67](file://lib/src/animation/smil/smil_timeline.dart#L20-L67)
- [lib/src/animation/smil/smil_animation.dart:80-131](file://lib/src/animation/smil/smil_animation.dart#L80-L131)
- [lib/src/animation/smil/smil_parser.dart:17-37](file://lib/src/animation/smil/smil_parser.dart#L17-L37)
- [lib/src/animation/smil/interpolators.dart:14-42](file://lib/src/animation/smil/interpolators.dart#L14-L42)
- [lib/src/animation/smil/motion_path.dart:22-52](file://lib/src/animation/smil/motion_path.dart#L22-L52)
- [lib/src/animation/svg_dom.dart:124-161](file://lib/src/animation/svg_dom.dart#L124-L161)
- [lib/src/animation/animated_svg_painter.dart:46-135](file://lib/src/animation/animated_svg_painter.dart#L46-L135)

## Architecture Overview
The animated pipeline follows a clear separation of concerns with enhanced utility layer and comprehensive paint server support:
- Parsing: XML → DOM preserved for runtime mutation and SMIL discovery.
- Extraction: SMIL and CSS animations parsed into typed SmilAnimation instances.
- Timeline: Global time management with begin/end conditions, repeat counts, and event-driven activation.
- Rendering: CustomPainter reads effective attribute values and draws the scene with enhanced paint server support.
- **Enhanced Rendering Pipeline**: Paint server resolution, marker placement, pattern application, and paint order control.
- **Utility Layer**: Centralized parsing and resolution mechanisms for consistent attribute, style, and transform handling.

```mermaid
sequenceDiagram
participant App as "App"
participant Widget as "AnimatedSvgPicture"
participant Utils as "Utility Classes"
participant Parser as "SmilParser"
participant Timeline as "SvgTimeline"
participant Controller as "AnimatedSvgController"
participant Painter as "AnimatedSvgPainter"
App->>Widget : Build widget with SVG
Widget->>Utils : Parse attributes/styles/transforms
Utils-->>Widget : Resolved values
Widget->>Parser : parseAnimations(document)
Parser-->>Widget : List<SmilAnimation>
Widget->>Timeline : new SvgTimeline(animations, rootNode)
Widget->>Controller : optional controller
loop Ticker/AnimationController
Widget->>Timeline : tick(delta)
Timeline->>Timeline : update animations
Timeline-->>Widget : active state
Widget->>Painter : repaint with document
Painter->>Painter : Resolve paint servers
Painter->>Painter : Place markers
Painter->>Painter : Apply patterns
Painter-->>App : Canvas draw
end
```

**Diagram sources**
- [lib/src/animation/smil/smil_parser.dart:17-37](file://lib/src/animation/smil/smil_parser.dart#L17-L37)
- [lib/src/animation/smil/smil_timeline.dart:82-98](file://lib/src/animation/smil/smil_timeline.dart#L82-L98)
- [lib/src/animation/animated_svg_picture.dart:166-220](file://lib/src/animation/animated_svg_picture.dart#L166-L220)
- [lib/src/animation/animated_svg_controller.dart:25-131](file://lib/src/animation/animated_svg_controller.dart#L25-L131)
- [lib/src/animation/animated_svg_painter_gradients.dart:1-44](file://lib/src/animation/animated_svg_painter_gradients.dart#L1-L44)
- [lib/src/animation/animated_svg_painter_patterns.dart:1-183](file://lib/src/animation/animated_svg_painter_patterns.dart#L1-L183)
- [lib/src/animation/animated_svg_painter_markers.dart:1-449](file://lib/src/animation/animated_svg_painter_markers.dart#L1-L449)
- [lib/src/animation/animated_svg_painter_paint_order.dart:1-90](file://lib/src/animation/animated_svg_painter_paint_order.dart#L1-L90)

**Section sources**
- [ARCHITECTURE.md:146-154](file://ARCHITECTURE.md#L146-L154)

## Detailed Component Analysis

### AnimatedSvgPicture Widget
- Purpose: Loads and renders animated SVGs, integrates with Flutter's Ticker/AnimationController, and exposes playback controls.
- Key behaviors:
  - Detects presence of animations and wraps with gesture detectors for event-based triggers.
  - Supports autoPlay, initialTime, playbackRate, and controller injection.
  - Exposes play(), pause(), reset(), seekTo().
  - Emits structured trace events via onTrace with configurable frame tick verbosity.
- Lifecycle:
  - Initializes DOM, parses animations, constructs timeline, and starts/stops AnimationController based on autoPlay and playbackRate changes.
  - Updates controller listener when widget controller changes.
  - **Enhanced**: Utilizes new utility classes for consistent parsing and resolution of attributes, styles, and transforms.

```mermaid
classDiagram
class AnimatedSvgPicture {
+double? width
+double? height
+FitBox fit
+Alignment alignment
+Color? backgroundColor
+double playbackRate
+bool autoPlay
+Duration? initialTime
+AnimatedSvgController? controller
+SvgTraceCallback? onTrace
+bool traceFrameTicks
+play()
+pause()
+reset()
+seekTo(time)
}
class _AnimatedSvgPictureState {
-SvgDocument _document
-SvgTimeline? _timeline
-AnimationController? _controller
-bool _hasAnimations
-bool _isReversed
}
class UtilityClasses {
<<extensions>>
+_AnimatedSvgPictureStateAttrsExtension
+_AnimatedSvgPictureStateStyleExtension
+_AnimatedSvgPictureStateTransformExtension
+_AnimatedSvgPictureStateCoreUtilsExtension
}
AnimatedSvgPicture --> _AnimatedSvgPictureState : "creates"
_AnimatedSvgPictureState --> AnimatedSvgController : "listens to"
_AnimatedSvgPictureState --> SvgTimeline : "owns"
_AnimatedSvgPictureState --> UtilityClasses : "uses"
```

**Diagram sources**
- [lib/src/animation/animated_svg_picture.dart:108-164](file://lib/src/animation/animated_svg_picture.dart#L108-L164)
- [lib/src/animation/animated_svg_picture.dart:166-220](file://lib/src/animation/animated_svg_picture.dart#L166-L220)
- [lib/src/animation/animated_svg_picture_utils.dart:1-69](file://lib/src/animation/animated_svg_picture_utils.dart#L1-L69)
- [lib/src/animation/animated_svg_picture_utils_attrs.dart:1-132](file://lib/src/animation/animated_svg_picture_utils_attrs.dart#L1-L132)
- [lib/src/animation/animated_svg_picture_utils_style.dart:1-88](file://lib/src/animation/animated_svg_picture_utils_style.dart#L1-L88)
- [lib/src/animation/animated_svg_picture_utils_transform.dart:1-84](file://lib/src/animation/animated_svg_picture_utils_transform.dart#L1-L84)

**Section sources**
- [lib/src/animation/animated_svg_picture.dart:108-164](file://lib/src/animation/animated_svg_picture.dart#L108-L164)
- [lib/src/animation/animated_svg_picture.dart:166-220](file://lib/src/animation/animated_svg_picture.dart#L166-L220)
- [lib/src/animation/animated_svg_picture.dart:271-295](file://lib/src/animation/animated_svg_picture.dart#L271-L295)

### AnimatedSvgController
- Purpose: Programmatic control surface for playback.
- Methods:
  - pause(), resume(), togglePlayPause()
  - seek(time), setPlaybackRate(rate), reverse(), forward(), toggleDirection(), restart()
  - Observability: isPaused, playbackRate, isReversed, pendingSeek
- Notes:
  - Validates playbackRate > 0.
  - Notifies listeners on state changes.

```mermaid
classDiagram
class AnimatedSvgController {
-bool _isPaused
-double _playbackRate
-Duration? _seekTarget
-bool _isReversed
+bool isPaused
+double playbackRate
+bool isReversed
+Duration? pendingSeek
+pause()
+resume()
+togglePlayPause()
+seek(time)
+setPlaybackRate(rate)
+reverse()
+forward()
+toggleDirection()
+restart()
+clearPendingSeek()
}
```

**Diagram sources**
- [lib/src/animation/animated_svg_controller.dart:25-131](file://lib/src/animation/animated_svg_controller.dart#L25-L131)

**Section sources**
- [lib/src/animation/animated_svg_controller.dart:25-131](file://lib/src/animation/animated_svg_controller.dart#L25-L131)

### SvgTimeline
- Purpose: Central time manager for all animations.
- Responsibilities:
  - Tick advancement with playbackRate scaling.
  - Seek to absolute time with boundary checks.
  - Reset timeline and dependent state.
  - Event-based activation via triggerEvent(elementId?, eventType).
  - Syncbase timing resolution and begin/end computation.
  - Total duration calculation across animations.
- Active state inspection via getActiveAnimations() and hasActiveAnimations().

```mermaid
flowchart TD
Start(["tick(delta)"]) --> Scale["Compute effectiveDelta = delta * playbackRate"]
Scale --> AddTime["currentTime += effectiveDelta"]
AddTime --> Update["updateAnimations(currentTime)"]
Update --> End(["done"])
style Start fill:#fff,stroke:#333,color:#000
style End fill:#fff,stroke:#333,color:#000
```

**Diagram sources**
- [lib/src/animation/smil/smil_timeline.dart:82-86](file://lib/src/animation/smil/smil_timeline.dart#L82-L86)

**Section sources**
- [lib/src/animation/smil/smil_timeline.dart:20-67](file://lib/src/animation/smil/smil_timeline.dart#L20-L67)
- [lib/src/animation/smil/smil_timeline.dart:82-98](file://lib/src/animation/smil/smil_timeline.dart#L82-L98)
- [lib/src/animation/smil/smil_timeline.dart:100-126](file://lib/src/animation/smil/smil_timeline.dart#L100-L126)
- [lib/src/animation/smil/smil_timeline.dart:128-158](file://lib/src/animation/smil/smil_timeline.dart#L128-L158)
- [lib/src/animation/smil/smil_timeline.dart:201-231](file://lib/src/animation/smil/smil_timeline.dart#L201-L231)

### SmilAnimation
- Purpose: Encapsulates SMIL semantics and value computation.
- Types:
  - animate, animateTransform, animateMotion, set, animateColor
- Modes:
  - calcMode: linear, discrete, paced, spline
  - fillMode: freeze, remove
  - additive: replace, sum
  - playbackDirection: normal, reverse, alternate, alternateReverse
- Key computations:
  - Values-based vs from/to/by vs discrete
  - Paced keyTimes generation via distance metrics
  - Local time and iteration calculation
  - Final value application with accumulate/additive
- Motion-specific:
  - animateMotion uses MotionPath for position/angle computation.

```mermaid
classDiagram
class SmilAnimation {
+String? id
+SmilAnimationType type
+SvgNode targetNode
+String attributeName
+SvgAttributeType attributeType
+String? transformType
+Object? from
+Object? to
+Object? by
+Object[]? values
+double[]? keyTimes
+CubicBezier[]? keySplines
+StepTiming[]? keySteps
+Duration dur
+Duration begin
+Duration? end
+double repeatCount
+Duration? repeatDur
+TimingCondition[] beginConditions
+TimingCondition[] endConditions
+SmilFillMode fillMode
+SmilCalcMode calcMode
+SmilPlaybackDirection playbackDirection
+SmilAdditiveMode additive
+bool accumulate
+bool isActive
+int currentIteration
+Duration localTime
+getEffectiveBeginTime()
+getEffectiveEndTime()
+computeValue(t, completedRepeats)
+updateForTime(globalTime)
+reset()
}
```

**Diagram sources**
- [lib/src/animation/smil/smil_animation.dart:80-131](file://lib/src/animation/smil/smil_animation.dart#L80-L131)
- [lib/src/animation/smil/smil_animation.dart:325-365](file://lib/src/animation/smil/smil_animation.dart#L325-L365)
- [lib/src/animation/smil/smil_animation.dart:367-431](file://lib/src/animation/smil/smil_animation.dart#L367-L431)

**Section sources**
- [lib/src/animation/smil/smil_animation.dart:13-29](file://lib/src/animation/smil/smil_animation.dart#L13-L29)
- [lib/src/animation/smil/smil_animation.dart:31-44](file://lib/src/animation/smil/smil_animation.dart#L31-L44)
- [lib/src/animation/smil/smil_animation.dart:79-131](file://lib/src/animation/smil/smil_animation.dart#L79-L131)
- [lib/src/animation/smil/smil_animation.dart:325-431](file://lib/src/animation/smil/smil_animation.dart#L325-L431)

### SmilParser and CSS-to-SMIL Conversion
- SmilParser:
  - Extracts SMIL animations from DOM nodes and CSS keyframes/style attributes.
  - Delegates CSS extraction and selector-based rules.
- CssToSmilConverter:
  - Converts CSS @keyframes and animation properties into typed SmilAnimation instances.
  - Handles compound transform decomposition for SVG transform normalization.
  - Infers attribute types and maps CSS properties to SMIL-equivalent attributes.

```mermaid
sequenceDiagram
participant Doc as "SvgDocument"
participant Parser as "SmilParser"
participant CSS as "CssToSmilConverter"
participant Out as "List<SmilAnimation>"
Doc->>Parser : parseAnimations(root)
Parser->>Parser : _extractAnimations(DOM)
Parser->>CSS : _extractCssAnimations(...)
CSS-->>Out : List<SmilAnimation>
Parser-->>Out : List<SmilAnimation>
```

**Diagram sources**
- [lib/src/animation/smil/smil_parser.dart:17-37](file://lib/src/animation/smil/smil_parser.dart#L17-L37)
- [lib/src/animation/css_to_smil_converter.dart:17-66](file://lib/src/animation/css_to_smil_converter.dart#L17-L66)

**Section sources**
- [lib/src/animation/smil/smil_parser.dart:17-37](file://lib/src/animation/smil/smil_parser.dart#L17-L37)
- [lib/src/animation/css_to_smil_converter.dart:17-66](file://lib/src/animation/css_to_smil_converter.dart#L17-L66)

### Interpolators and MotionPath
- Interpolators:
  - Type-aware interpolation for numbers, colors, transforms, paths, and lists.
  - Additive arithmetic for numeric and list types.
- MotionPath:
  - Parses SVG path data and computes position/angle along the path.
  - Supports keyPoints with optional keyTimes for variable-speed motion.

```mermaid
flowchart TD
A["Interpolators.interpolate(from,to,t,type)"] --> B{"type?"}
B --> |number/length| N["interpolateNumber"]
B --> |color| C["interpolateColor"]
B --> |transform| T["interpolateTransform"]
B --> |path| P["interpolatePath"]
B --> |points/list| L["interpolateList"]
B --> |string/url| D["discrete select"]
M["MotionPath.getPointAtTime(t)"] --> R["PathMetrics<br/>tangent + position"]
K["MotionPath.getPointWithKeyPoints(t, keyPoints, keyTimes)"] --> R
```

**Diagram sources**
- [lib/src/animation/smil/interpolators.dart:18-42](file://lib/src/animation/smil/interpolators.dart#L18-L42)
- [lib/src/animation/smil/motion_path.dart:97-145](file://lib/src/animation/smil/motion_path.dart#L97-L145)
- [lib/src/animation/smil/motion_path.dart:147-217](file://lib/src/animation/smil/motion_path.dart#L147-L217)

**Section sources**
- [lib/src/animation/smil/interpolators.dart:14-42](file://lib/src/animation/smil/interpolators.dart#L14-L42)
- [lib/src/animation/smil/interpolators.dart:118-146](file://lib/src/animation/smil/interpolators.dart#L118-L146)
- [lib/src/animation/smil/motion_path.dart:22-52](file://lib/src/animation/smil/motion_path.dart#L22-L52)
- [lib/src/animation/smil/motion_path.dart:97-145](file://lib/src/animation/smil/motion_path.dart#L97-L145)
- [lib/src/animation/smil/motion_path.dart:147-217](file://lib/src/animation/smil/motion_path.dart#L147-L217)

### DOM Model and Effective Values
- SvgNode holds AnimatableSvgAttribute entries with baseValue and animatedValue.
- Effective value selection prefers animatedValue when an animation is active.
- Tree-level flags (hasAnimations, cachedPicture) enable subtree caching and dirty tracking.

```mermaid
classDiagram
class SvgDocument {
+SvgNode root
+Rect? viewBox
+double? width
+double? height
+CssKeyframes[]? cssKeyframes
+CssSelectorRule[]? cssSelectorRules
}
class SvgNode {
+String tagName
+String? id
+String? className
+Map~String,AnimatableSvgAttribute~ attributes
+SvgNode[] children
+SvgNode? parent
+bool hasAnimations
+Picture? cachedPicture
}
class AnimatableSvgAttribute {
+String name
+Object baseValue
+SvgAttributeType type
+Object? _animatedValue
+bool _isAnimated
+effectiveValue
+setAnimatedValue(value)
+clearAnimation()
}
SvgDocument --> SvgNode : "root"
SvgNode --> AnimatableSvgAttribute : "attributes"
```

**Diagram sources**
- [lib/src/animation/svg_dom.dart:124-161](file://lib/src/animation/svg_dom.dart#L124-L161)
- [lib/src/animation/svg_dom.dart:266-317](file://lib/src/animation/svg_dom.dart#L266-L317)

**Section sources**
- [lib/src/animation/svg_dom.dart:124-161](file://lib/src/animation/svg_dom.dart#L124-L161)
- [lib/src/animation/svg_dom.dart:266-317](file://lib/src/animation/svg_dom.dart#L266-L317)

## Paint Order System

The paint order system provides comprehensive control over the rendering order of different paint layers in SVG shapes. It allows precise control over whether fill, stroke, and markers are drawn in specific orders.

### Paint Order Layers
The system defines three paint layers with specific rendering priorities:
- **fill**: Primary fill area of shapes
- **stroke**: Outline/border of shapes  
- **markers**: Arrowheads and decorative markers placed along paths

### Paint Order Parsing and Resolution
The paint order system parses the `paint-order` attribute and determines the rendering sequence:

```mermaid
flowchart TD
A["paint-order attribute parsing"] --> B{"Attribute value?"}
B --> |null/empty| C["Default order: fill → stroke → markers"]
B --> |"normal"| C
B --> |custom| D["Parse space-separated tokens"]
D --> E["Validate tokens (fill/stroke/markers)"]
E --> F["Remove duplicates while preserving order"]
F --> G["Add missing layers in default order"]
G --> H["Return final paint order list"]
```

**Diagram sources**
- [lib/src/animation/animated_svg_painter_paint_order.dart:9-64](file://lib/src/animation/animated_svg_painter_paint_order.dart#L9-L64)

### Paint Order Implementation
The `_paintWithOrder` method executes the paint order sequence:

```mermaid
sequenceDiagram
participant Node as "SvgNode"
participant Order as "_parsePaintOrder"
participant Renderer as "_paintWithOrder"
participant Fill as "paintFill()"
participant Stroke as "paintStroke()"
participant Markers as "paintMarkers()"
Node->>Order : Parse paint-order attribute
Order-->>Renderer : Return ordered layers
loop For each layer in order
Renderer->>Fill : Execute if layer == fill
Renderer->>Stroke : Execute if layer == stroke
Renderer->>Markers : Execute if layer == markers
end
```

**Diagram sources**
- [lib/src/animation/animated_svg_painter_paint_order.dart:69-89](file://lib/src/animation/animated_svg_painter_paint_order.dart#L69-L89)

**Section sources**
- [lib/src/animation/animated_svg_painter_paint_order.dart:1-90](file://lib/src/animation/animated_svg_painter_paint_order.dart#L1-L90)
- [test/animation/paint_order_test.dart:1-232](file://test/animation/paint_order_test.dart#L1-L232)

## Marker Support

The marker system provides comprehensive support for arrowheads and decorative markers along SVG paths. It handles marker resolution, positioning, orientation, and scaling.

### Marker Definition Resolution
Markers are resolved from the SVG DOM using their IDs and support inheritance through the `href` attribute:

```mermaid
flowchart TD
A["Marker resolution process"] --> B["Check marker cache"]
B --> |hit| C["Return cached marker"]
B --> |miss| D["Find marker node by ID"]
D --> |found| E["Parse marker attributes"]
D --> |not found| F["Cache null and return"]
E --> G["Resolve markerUnits (userSpaceOnUse/strokeWidth)"]
G --> H["Parse orient (auto/auto-start-reverse/angle)"]
H --> I["Parse viewBox if present"]
I --> J["Store in cache"]
J --> K["Return resolved marker"]
```

**Diagram sources**
- [lib/src/animation/animated_svg_painter_markers.dart:5-69](file://lib/src/animation/animated_svg_painter_markers.dart#L5-L69)

### Marker Placement and Orientation
The system calculates marker positions along paths and applies appropriate rotations:

```mermaid
sequenceDiagram
participant Path as "Path geometry"
participant Vertices as "Vertex extraction"
participant Marker as "Marker placement"
participant Canvas as "Canvas operations"
Path->>Vertices : Extract path vertices
Vertices-->>Marker : Return vertex positions
loop For each marker position
Marker->>Marker : Calculate tangent angle
Marker->>Marker : Determine effective orientation
Marker->>Canvas : Save canvas state
Canvas->>Canvas : Translate to position
Canvas->>Canvas : Rotate by calculated angle
Canvas->>Canvas : Apply scale based on markerUnits
Canvas->>Canvas : Translate by -refX, -refY
Canvas->>Canvas : Draw marker content
Canvas->>Canvas : Restore state
end
```

**Diagram sources**
- [lib/src/animation/animated_svg_painter_markers.dart:139-217](file://lib/src/animation/animated_svg_painter_markers.dart#L139-L217)
- [lib/src/animation/animated_svg_painter_markers.dart:236-286](file://lib/src/animation/animated_svg_painter_markers.dart#L236-L286)

### Marker Attributes and Units
The marker system supports comprehensive SVG marker attributes:
- **refX/refY**: Reference point for marker positioning
- **markerWidth/markerHeight**: Size specifications
- **markerUnits**: `userSpaceOnUse` or `strokeWidth` scaling
- **orient**: `auto`, `auto-start-reverse`, or fixed angle
- **viewBox**: Custom coordinate system for marker content

**Section sources**
- [lib/src/animation/animated_svg_painter_markers.dart:1-449](file://lib/src/animation/animated_svg_painter_markers.dart#L1-L449)
- [test/animation/marker_test.dart:1-223](file://test/animation/marker_test.dart#L1-L223)

## Pattern Implementation

The pattern system provides complete SVG pattern support with advanced features including pattern units, inheritance, and caching mechanisms.

### Pattern Definition Resolution
Patterns are resolved with comprehensive inheritance support and caching:

```mermaid
flowchart TD
A["Pattern resolution process"] --> B["Check pattern cache"]
B --> |hit| C["Return cached pattern"]
B --> |miss| D["Find pattern node by ID"]
D --> |found| E["Check for href inheritance"]
E --> |inherit| F["Resolve inherited pattern"]
E --> |direct| G["Parse pattern attributes"]
F --> H["Merge attributes with inheritance"]
G --> H
H --> I["Parse patternUnits (userSpaceOnUse/objectBoundingBox)"]
I --> J["Parse patternContentUnits"]
J --> K["Parse viewBox if present"]
K --> L["Parse patternTransform"]
L --> M["Store in cache"]
M --> N["Return resolved pattern"]
```

**Diagram sources**
- [lib/src/animation/animated_svg_painter_patterns.dart:5-103](file://lib/src/animation/animated_svg_painter_patterns.dart#L5-L103)

### Pattern Application and Tiling
The system generates ImageShaders for pattern fills with sophisticated tiling logic:

```mermaid
sequenceDiagram
participant Pattern as "Pattern definition"
participant Shader as "Pattern shader"
participant Canvas as "Canvas operations"
Pattern->>Shader : Create pattern shader
Shader->>Shader : Calculate tile dimensions
alt patternUnits = objectBoundingBox
Shader->>Shader : Apply percentage of target bounds
else patternUnits = userSpaceOnUse
Shader->>Shader : Use absolute coordinates
end
Shader->>Shader : Render pattern content to Picture
Shader->>Shader : Convert to Image (toImageSync)
Shader->>Shader : Create ImageShader with TileMode
Shader->>Canvas : Apply shader to fill/stroke
```

**Diagram sources**
- [lib/src/animation/animated_svg_painter_patterns.dart:106-183](file://lib/src/animation/animated_svg_painter_patterns.dart#L106-L183)

### Pattern Attributes and Units
The pattern system supports comprehensive SVG pattern attributes:
- **x/y/width/height**: Position and size specifications
- **patternUnits**: `userSpaceOnUse` or `objectBoundingBox` coordinate system
- **patternContentUnits**: `userSpaceOnUse` or `objectBoundingBox` for content
- **patternTransform**: Matrix transformations for pattern orientation
- **viewBox**: Custom coordinate system for pattern content

**Section sources**
- [lib/src/animation/animated_svg_painter_patterns.dart:1-184](file://lib/src/animation/animated_svg_painter_patterns.dart#L1-L184)
- [test/animation/pattern_test.dart:1-189](file://test/animation/pattern_test.dart#L1-L189)

## Enhanced Gradient and Paint Handling

The enhanced gradient system provides comprehensive paint server support with caching mechanisms for optimal performance.

### Paint Server Resolution
The system resolves paint servers (gradients and patterns) with priority-based selection:

```mermaid
flowchart TD
A["Paint server resolution"] --> B["Extract paint server ID from paint value"]
B --> |found| C["Try gradient resolution"]
C --> |success| D["Return gradient shader"]
C --> |fail| E["Try pattern resolution"]
E --> |success| F["Return pattern shader"]
E --> |fail| G["Return null"]
B --> |not found| H["Return null"]
```

**Diagram sources**
- [lib/src/animation/animated_svg_painter_gradients.dart:4-29](file://lib/src/animation/animated_svg_painter_gradients.dart#L4-L29)

### Gradient Implementation
The gradient system supports both linear and radial gradients with advanced features:

```mermaid
flowchart TD
A["Gradient shader creation"] --> B["Normalize paint bounds"]
B --> C["Parse gradientUnits (userSpaceOnUse)"]
C --> D["Parse spreadMethod (TileMode)"]
D --> E["Parse gradientTransform matrix"]
E --> F{"Gradient type?"}
F --> |linear| G["Parse x1,y1,x2,y2 coordinates"]
F --> |radial| H["Parse cx,cy,radius,focal points"]
G --> I["Create ui.Gradient.linear"]
H --> J["Create ui.Gradient.radial"]
I --> K["Apply linearRGB interpolation if enabled"]
J --> K
K --> L["Return gradient shader"]
```

**Diagram sources**
- [lib/src/animation/animated_svg_painter_gradients.dart:31-158](file://lib/src/animation/animated_svg_painter_gradients.dart#L31-L158)

### Paint Cache Management
The system implements comprehensive caching for paint servers:

```mermaid
classDiagram
class PaintServerCaches {
<<caches>>
+Map~String, _ResolvedGradientDefinition?~ _gradientCache
+Map~String, _ResolvedMarkerDefinition?~ _markerCache
+Map~String, _ResolvedPatternDefinition?~ _patternCache
+Map~String, ui.Image?~ _patternTileCache
}
class CacheOperations {
+getOrSet(key, factory)
+invalidate(key)
+clearAll()
}
PaintServerCaches --> CacheOperations : "manages"
```

**Diagram sources**
- [lib/src/animation/animated_svg_painter.dart:63-69](file://lib/src/animation/animated_svg_painter.dart#L63-L69)

**Section sources**
- [lib/src/animation/animated_svg_painter_gradients.dart:1-160](file://lib/src/animation/animated_svg_painter_gradients.dart#L1-L160)
- [lib/src/animation/animated_svg_painter.dart:63-69](file://lib/src/animation/animated_svg_painter.dart#L63-L69)

## Utility Classes and Parsing Mechanisms

### Core Utility Extensions
The new utility classes provide centralized parsing and resolution mechanisms for consistent attribute handling across the animation system:

#### Attribute Resolution Utilities
- `_AnimatedSvgPictureStateAttrsExtension`: Handles attribute extraction, parsing, and inheritance resolution
- Supports href ID extraction, style attribute parsing, number parsing with unit cleanup, and inherited value resolution
- Provides consistent parsing for numbers, number lists, and text content extraction

#### Style and Font Utilities  
- `_AnimatedSvgPictureStateStyleExtension`: Manages font weight/size parsing, style resolution, and geometric calculations
- Includes comprehensive font weight mapping (100-900 range), font style resolution, and point parsing for polygons/polylines
- Provides distance calculations for hit-testing and geometric operations

#### Transform Utilities
- `_AnimatedSvgPictureStateTransformExtension`: Handles SVG transform parsing and matrix application
- Supports translate, scale, rotate (with center point), skewX/Y, and custom matrix transformations
- Includes foreignObject child transform handling for proper coordinate system management

#### Core Utilities
- `_AnimatedSvgPictureStateCoreUtilsExtension`: Provides fundamental utility functions for visibility, pointer events, painting, and tracing
- Handles display/visibility checking, stroke tolerance calculations, paint value validation, and structured tracing

```mermaid
classDiagram
class _AnimatedSvgPictureStateAttrsExtension {
+String? _extractHrefId(node)
+String? _extractStyleValue(node, property)
+double? _getNumber(node, attributeName)
+double[] _getNumberList(node, attributeName)
+Object? _getInheritedAttributeValue(node, attributeName)
+String? _getInheritedString(node, attributeName)
+double? _getInheritedNumber(node, attributeName)
+String? _extractTextContent(node)
}
class _AnimatedSvgPictureStateStyleExtension {
+FontWeight _resolveFontWeight(fontWeight)
+FontStyle _resolveFontStyle(fontStyle)
+double _distanceToSegment(p, a, b)
+Offset[] _parsePoints(node)
}
class _AnimatedSvgPictureStateTransformExtension {
+void _applyForeignObjectChildTransform(matrix, node)
+void _applyNodeTransform(matrix, node)
}
class _AnimatedSvgPictureStateCoreUtilsExtension {
+bool _isFillEnabled(node)
+bool _hasStroke(node)
+double _strokeTolerance(node)
+bool _isPaintNone(value)
+bool _isPointerEventsNone(node)
+bool _isVisibilityHidden(node)
+bool _isDisplayNone(node)
+void _trace(category, message, level, data, error, stackTrace)
}
```

**Diagram sources**
- [lib/src/animation/animated_svg_picture_utils_attrs.dart:1-132](file://lib/src/animation/animated_svg_picture_utils_attrs.dart#L1-L132)
- [lib/src/animation/animated_svg_picture_utils_style.dart:1-88](file://lib/src/animation/animated_svg_picture_utils_style.dart#L1-L88)
- [lib/src/animation/animated_svg_picture_utils_transform.dart:1-84](file://lib/src/animation/animated_svg_picture_utils_transform.dart#L1-L84)
- [lib/src/animation/animated_svg_picture_utils.dart:1-69](file://lib/src/animation/animated_svg_picture_utils.dart#L1-L69)

**Section sources**
- [lib/src/animation/animated_svg_picture_utils_attrs.dart:1-132](file://lib/src/animation/animated_svg_picture_utils_attrs.dart#L1-L132)
- [lib/src/animation/animated_svg_picture_utils_style.dart:1-88](file://lib/src/animation/animated_svg_picture_utils_style.dart#L1-L88)
- [lib/src/animation/animated_svg_picture_utils_transform.dart:1-84](file://lib/src/animation/animated_svg_picture_utils_transform.dart#L1-L84)
- [lib/src/animation/animated_svg_picture_utils.dart:1-69](file://lib/src/animation/animated_svg_picture_utils.dart#L1-L69)

## Enhanced Text Rendering and Hit-Testing

### TextPath Spacing Functionality
The text rendering system now supports enhanced spacing control for textPath elements with two distinct modes:

#### Spacing Modes
- **auto mode**: Applies CSS letter-spacing and word-spacing inherited from style attributes
- **exact mode**: Ignores CSS spacing and uses exact glyph spacing for precise text fitting

#### Implementation Details
- Spacing resolution respects the `spacing` attribute on textPath elements
- Letter and word spacing are applied conditionally based on spacing mode
- Text length adjustment supports both spacing-only and spacing+glyphs modes
- Hit-testing maintains separate spacing calculations for accurate text selection

```mermaid
flowchart TD
A["TextPath Rendering"] --> B{"spacing='auto'?"}
B --> |Yes| C["Apply CSS letter-spacing<br/>+ word-spacing"]
B --> |No| D["Use exact glyph spacing"]
C --> E["Calculate display advances<br/>+ widths"]
D --> E
E --> F{"textLength specified?"}
F --> |Yes| G["Apply lengthAdjust<br/>spacing or spacingAndGlyphs"]
F --> |No| H["Render with natural spacing"]
G --> I["Final positioned text"]
H --> I
```

**Diagram sources**
- [lib/src/animation/animated_svg_picture_hit_test_text_layout.dart:86-96](file://lib/src/animation/animated_svg_picture_hit_test_text_layout.dart#L86-L96)
- [lib/src/animation/animated_svg_painter_text_style.dart:192-205](file://lib/src/animation/animated_svg_painter_text_style.dart#L192-L205)
- [lib/src/animation/animated_svg_picture_hit_test_text_path_segments.dart:27-40](file://lib/src/animation/animated_svg_picture_hit_test_text_path_segments.dart#L27-L40)

### Writing-Mode Support
The system now supports comprehensive vertical text rendering through writing-mode attributes:

#### Writing Modes
- **horizontal-tb** (default): Traditional horizontal text rendering
- **vertical-rl**: Vertical text flowing right-to-left
- **vertical-lr**: Vertical text flowing left-to-right
- **Legacy support**: Backward compatibility with SVG 1.1 writing modes

#### Implementation Features
- Comprehensive writing-mode resolution with fallback to horizontal-tb
- Proper baseline calculation for vertical text rendering
- Support for vertical text decoration and spacing adjustments
- Consistent behavior across textPath and regular text elements

```mermaid
classDiagram
class _SvgWritingMode {
<<enumeration>>
+horizontalTb
+verticalRl
+verticalLr
}
class TextRenderingSystem {
+_resolveWritingMode(value)
+_resolveTextTopFromBaseline(node, baselineY, metrics)
+_resolveBaselineReference(dominantBaseline, metrics)
+_textPathSpacingAfterGlyph(glyph, isLast, style)
}
TextRenderingSystem --> _SvgWritingMode : "uses"
```

**Diagram sources**
- [lib/src/animation/animated_svg_painter_text_style.dart:70-87](file://lib/src/animation/animated_svg_painter_text_style.dart#L70-L87)
- [lib/src/animation/animated_svg_painter_text_style.dart:207-230](file://lib/src/animation/animated_svg_painter_text_style.dart#L207-L230)
- [lib/src/animation/animated_svg_picture_hit_test_text_layout.dart:138-167](file://lib/src/animation/animated_svg_picture_hit_test_text_layout.dart#L138-L167)

**Section sources**
- [lib/src/animation/animated_svg_picture_hit_test_text_layout.dart:86-96](file://lib/src/animation/animated_svg_picture_hit_test_text_layout.dart#L86-L96)
- [lib/src/animation/animated_svg_painter_text_style.dart:70-87](file://lib/src/animation/animated_svg_painter_text_style.dart#L70-L87)
- [lib/src/animation/animated_svg_painter_text_style.dart:192-205](file://lib/src/animation/animated_svg_painter_text_style.dart#L192-L205)
- [lib/src/animation/animated_svg_picture_hit_test_text_path_segments.dart:27-40](file://lib/src/animation/animated_svg_picture_hit_test_text_path_segments.dart#L27-L40)

### Text Decoration and Baseline Support
Enhanced text rendering includes comprehensive support for text decorations and baseline positioning:

#### Text Decorations
- Underline, overline, and line-through support
- Inheritance from parent text elements
- Color customization for decorations
- Combined decoration effects

#### Baseline Management
- Dominant baseline support (alphabetic, central, text-before-edge, text-after-edge)
- Baseline shift calculations with percentage and numeric values
- Proper vertical alignment for mixed text orientations
- Compatibility with writing-mode changes

**Section sources**
- [lib/src/animation/animated_svg_painter_text_style.dart:89-126](file://lib/src/animation/animated_svg_painter_text_style.dart#L89-L126)
- [lib/src/animation/animated_svg_painter_text_style.dart:232-277](file://lib/src/animation/animated_svg_painter_text_style.dart#L232-L277)
- [lib/src/animation/animated_svg_picture_hit_test_text_layout.dart:138-195](file://lib/src/animation/animated_svg_picture_hit_test_text_layout.dart#L138-L195)

## Dependency Analysis
- Module boundaries:
  - Core animation exports define the public API surface.
  - SMIL engine depends on DOM and interpolators.
  - CSS converter depends on CSS parsing and SMIL types.
  - Widget depends on timeline and controller.
  - **Enhanced**: Utility classes provide centralized parsing mechanisms with low coupling to core systems.
  - **New**: Paint server extensions extend the rendering pipeline with comprehensive paint support.
- Coupling:
  - Low coupling between parsing, timeline, and rendering via typed SmilAnimation and DOM attribute mutation.
  - Controlled coupling via ChangeNotifier and Ticker integration.
  - **Enhanced**: Utility classes reduce code duplication and provide consistent parsing across the entire system.
  - **New**: Paint server extensions maintain clean separation while extending functionality.

```mermaid
graph LR
Export["lib/src/animation.dart"] --> Widget["animated_svg_picture.dart"]
Export --> Controller["animated_svg_controller.dart"]
Export --> Timeline["smil_timeline.dart"]
Export --> Animation["smil_animation.dart"]
Export --> Parser["smil_parser.dart"]
Export --> Interp["interpolators.dart"]
Export --> Motion["motion_path.dart"]
Export --> Dom["svg_dom.dart"]
Export --> CssConv["css_to_smil_converter.dart"]
Export --> Utils["Utility Classes"]
Export --> PaintServers["Paint Server Extensions"]
PaintServers --> Gradients["animated_svg_painter_gradients.dart"]
PaintServers --> Patterns["animated_svg_painter_patterns.dart"]
PaintServers --> Markers["animated_svg_painter_markers.dart"]
PaintServers --> PaintOrder["animated_svg_painter_paint_order.dart"]
Utils --> Attrs["animated_svg_picture_utils_attrs.dart"]
Utils --> Style["animated_svg_picture_utils_style.dart"]
Utils --> Transform["animated_svg_picture_utils_transform.dart"]
Utils --> Core["animated_svg_picture_utils.dart"]
```

**Diagram sources**
- [lib/src/animation.dart:21-31](file://lib/src/animation.dart#L21-L31)

**Section sources**
- [lib/src/animation.dart:21-31](file://lib/src/animation.dart#L21-L31)

## Performance Considerations
- Static subtrees: If a node has no animations, cache rendered output as Picture and reuse to avoid re-traversals.
- Dirty tracking: Mark nodes dirty when animated values change; only re-render dirty subtrees.
- Path optimization: Normalize paths once during parsing; reuse Path objects and reset rather than recreate.
- **Enhanced**: Utility classes provide cached parsing results to reduce redundant computations.
- **New**: Paint server caching reduces repeated pattern and gradient resolution overhead.
- **New**: Pattern tile caching prevents expensive toImageSync operations for identical patterns.
- **New**: Marker caching prevents repeated marker resolution and vertex extraction.
- **Future optimizations (stage goals)**: layer caching for independent animations, GPU-accelerated path morphing, reduced allocations in hot paths, improved text rendering performance.
- Baseline performance targets are documented in the project's animation guide.

**Section sources**
- [ARCHITECTURE.md:174-193](file://ARCHITECTURE.md#L174-L193)
- [ANIMATION.md:172-178](file://ANIMATION.md#L172-L178)
- [lib/src/animation/animated_svg_painter_patterns.dart:10-14](file://lib/src/animation/animated_svg_painter_patterns.dart#L10-L14)
- [lib/src/animation/animated_svg_painter_markers.dart:6-9](file://lib/src/animation/animated_svg_painter_markers.dart#L6-L9)

## Troubleshooting Guide
- Tracing:
  - Use onTrace callback to receive structured SvgTraceEvent messages with timestamps, categories, and optional error/stack traces.
  - Enable traceFrameTicks to emit per-frame tick events (disabled by default due to volume).
- Playback control:
  - Verify controller is attached to the widget; use pause/resume/seek/setPlaybackRate/toggleDirection/restart.
  - For event-based animations, ensure triggerEvent(elementId?, eventType) is called at the appropriate time.
- **Enhanced**: Utility class troubleshooting:
  - Check attribute parsing with `_getInheritedAttributeValue()` for style inheritance issues.
  - Verify transform parsing with `_applyNodeTransform()` for coordinate system problems.
  - Use `_resolveTextPathSpacing()` to debug textPath spacing issues.
- **New**: Paint server troubleshooting:
  - Verify paint server resolution with `_resolvePaintServerShader()` for gradient/pattern issues.
  - Check pattern caching with `_patternCache` for repeated pattern resolution problems.
  - Validate marker resolution with `_markerCache` for marker placement issues.
- Common issues:
  - autoPlay false rendering: addressed by tests; confirm initialTime and controller state.
  - Path morphing compatibility: requires normalized path structures; ensure paths share topology.
  - **New**: Text rendering issues: verify writing-mode support and spacing calculations.
  - **New**: Paint order issues: verify paint-order attribute syntax and layer ordering.
  - **New**: Pattern rendering issues: check patternUnits, viewBox, and tile dimension calculations.
  - **New**: Marker placement issues: verify markerUnits, orient values, and vertex extraction.
- Validation:
  - Use getInfo() on SvgTimeline to inspect active animations, total duration, and playback rate.
  - Check widget state transitions and controller notifications.
  - **Enhanced**: Validate utility class results for consistent parsing behavior.
  - **New**: Monitor paint server caches for proper caching and invalidation.

**Section sources**
- [lib/src/animation/animated_svg_picture.dart:37-86](file://lib/src/animation/animated_svg_picture.dart#L37-L86)
- [lib/src/animation/animated_svg_picture.dart:156-160](file://lib/src/animation/animated_svg_picture.dart#L156-L160)
- [lib/src/animation/smil/smil_timeline.dart:234-244](file://lib/src/animation/smil/smil_timeline.dart#L234-L244)
- [ANIMATION.md:207-213](file://ANIMATION.md#L207-L213)

## Conclusion
The animated SVG system provides a robust, experimental SMIL pipeline alongside the production static renderer. It supports a wide range of SMIL elements and attributes, CSS animation conversion, precise timing control, and real-time playback. The architecture cleanly separates parsing, animation extraction, timeline management, and rendering, enabling future optimizations and parity improvements.

**Updated**: The new paint order system, marker support, pattern implementation, and enhanced gradient handling significantly expand the system's capabilities. The comprehensive paint server support with caching mechanisms ensures optimal performance while maintaining full SVG specification compliance. These additions provide complete paint server functionality including fill/stroke ordering control, marker placement along paths, pattern fills with advanced tiling, and sophisticated gradient rendering.

Developers can leverage AnimatedSvgPicture and AnimatedSvgController for programmatic control, while the underlying SmilAnimation and interpolators ensure spec-aligned behavior and extensibility. The utility classes streamline attribute, style, and transform parsing, reducing code duplication and improving reliability. The new paint server extensions enable complex visual effects while maintaining performance through intelligent caching strategies.

## Appendices

### Public Interfaces and Parameters
- AnimatedSvgPicture:
  - Constructors: string, asset, network, memory
  - Parameters: width, height, fit, alignment, backgroundColor, playbackRate, autoPlay, initialTime, controller, onTrace, traceFrameTicks
  - Methods: play, pause, reset, seekTo
- AnimatedSvgController:
  - Properties: isPaused, playbackRate, isReversed, pendingSeek
  - Methods: pause, resume, togglePlayPause, seek, setPlaybackRate, reverse, forward, toggleDirection, restart
- SvgTimeline:
  - Properties: currentTime, totalDuration, playbackRate
  - Methods: tick, seek, reset, triggerEvent, getActiveAnimations, hasActiveAnimations, getInfo
- SmilAnimation:
  - Types: animate, animateTransform, animateMotion, set, animateColor
  - Modes: calcMode, fillMode, additive, playbackDirection
  - Methods: computeValue, updateForTime, reset
- Interpolators:
  - interpolate, interpolateNumber, interpolateColor, interpolateTransform, interpolatePath, interpolateList, add
- MotionPath:
  - getPointAtTime, getPointWithKeyPoints, totalLength
- **Enhanced Rendering System**:
  - Paint server resolution: `_resolvePaintServerShader`, `_createGradientShader`, `_createPatternShader`
  - Paint order control: `_parsePaintOrder`, `_paintWithOrder`
  - Marker support: `_resolveMarkerDefinition`, `_paintMarkers`, `_paintMarker`
  - Pattern implementation: `_resolvePatternDefinition`, `_createPatternShader`
  - Utility classes: `_extractHrefId`, `_extractStyleValue`, `_getNumber`, `_getNumberList`, `_getInheritedAttributeValue`, `_getInheritedString`, `_getInheritedNumber`, `_extractTextContent`
  - Style parsing: `_resolveFontWeight`, `_resolveFontStyle`, `_distanceToSegment`, `_parsePoints`
  - Transform parsing: `_applyForeignObjectChildTransform`, `_applyNodeTransform`
  - Core utilities: `_isFillEnabled`, `_hasStroke`, `_strokeTolerance`, `_isPaintNone`, `_isPointerEventsNone`, `_isVisibilityHidden`, `_isDisplayNone`, `_trace`

**Section sources**
- [lib/src/animation/animated_svg_picture.dart:108-164](file://lib/src/animation/animated_svg_picture.dart#L108-L164)
- [lib/src/animation/animated_svg_controller.dart:25-131](file://lib/src/animation/animated_svg_controller.dart#L25-L131)
- [lib/src/animation/smil/smil_timeline.dart:20-67](file://lib/src/animation/smil/smil_timeline.dart#L20-L67)
- [lib/src/animation/smil/smil_animation.dart:80-131](file://lib/src/animation/smil/smil_animation.dart#L80-L131)
- [lib/src/animation/smil/interpolators.dart:14-42](file://lib/src/animation/smil/interpolators.dart#L14-L42)
- [lib/src/animation/smil/motion_path.dart:22-52](file://lib/src/animation/smil/motion_path.dart#L22-L52)
- [lib/src/animation/animated_svg_painter_gradients.dart:4-29](file://lib/src/animation/animated_svg_painter_gradients.dart#L4-L29)
- [lib/src/animation/animated_svg_painter_paint_order.dart:9-64](file://lib/src/animation/animated_svg_painter_paint_order.dart#L9-L64)
- [lib/src/animation/animated_svg_painter_markers.dart:5-69](file://lib/src/animation/animated_svg_painter_markers.dart#L5-L69)
- [lib/src/animation/animated_svg_painter_patterns.dart:5-103](file://lib/src/animation/animated_svg_painter_patterns.dart#L5-L103)
- [lib/src/animation/animated_svg_picture_utils_attrs.dart:1-132](file://lib/src/animation/animated_svg_picture_utils_attrs.dart#L1-L132)
- [lib/src/animation/animated_svg_picture_utils_style.dart:1-88](file://lib/src/animation/animated_svg_picture_utils_style.dart#L1-L88)
- [lib/src/animation/animated_svg_picture_utils_transform.dart:1-84](file://lib/src/animation/animated_svg_picture_utils_transform.dart#L1-L84)
- [lib/src/animation/animated_svg_picture_utils.dart:1-69](file://lib/src/animation/animated_svg_picture_utils.dart#L1-L69)

### Practical Examples
- Basic movement, rotation, color animation, path morphing, and motion path are demonstrated in the project's animation guide.
- Widget API usage and demo app invocation are documented for quick start and exploration.
- **New**: Paint order examples with fill/stroke/markers layer control
- **New**: Marker examples with various orientations and marker units
- **New**: Pattern examples with different units, inheritance, and transformations
- **New**: TextPath spacing examples with both auto and exact spacing modes
- **New**: Writing-mode examples for vertical text rendering (vertical-rl, vertical-lr)

**Section sources**
- [ANIMATION.md:5-194](file://ANIMATION.md#L5-L194)

### Migration from CSS Animations
- CSS @keyframes and animation properties are parsed and converted to SMIL equivalents.
- Compound transforms are decomposed into individual SmilAnimation instances for accurate SVG transform semantics.
- Remaining gaps include advanced edge-case CSS shorthand/transform semantics; baseline conversion remains functional.
- **Enhanced**: Utility classes improve consistency in CSS-to-SMIL conversion and attribute resolution.
- **New**: Paint server support enables migration from CSS background-image patterns to native SVG patterns.

**Section sources**
- [ANIMATION.md:54-66](file://ANIMATION.md#L54-L66)
- [lib/src/animation/css_to_smil_converter.dart:35-48](file://lib/src/animation/css_to_smil_converter.dart#L35-L48)

### Text Rendering Enhancements
- **TextPath Spacing**: Two modes (auto/exact) with CSS spacing support in auto mode
- **Writing Mode**: Complete support for horizontal-tb, vertical-rl, vertical-lr with legacy SVG 1.1 compatibility
- **Text Decorations**: Underline, overline, line-through with inheritance and color support
- **Baseline Management**: Comprehensive dominant-baseline and baseline-shift calculations
- **Hit-Testing**: Enhanced accuracy for textPath segments with proper spacing calculations

**Section sources**
- [lib/src/animation/animated_svg_painter_text_style.dart:70-87](file://lib/src/animation/animated_svg_painter_text_style.dart#L70-L87)
- [lib/src/animation/animated_svg_painter_text_style.dart:89-126](file://lib/src/animation/animated_svg_painter_text_style.dart#L89-L126)
- [lib/src/animation/animated_svg_picture_hit_test_text_layout.dart:86-96](file://lib/src/animation/animated_svg_picture_hit_test_text_layout.dart#L86-L96)
- [lib/src/animation/animated_svg_picture_hit_test_text_path_segments.dart:27-40](file://lib/src/animation/animated_svg_picture_hit_test_text_path_segments.dart#L27-L40)

### Paint Server Features
- **Paint Order Control**: Fill, stroke, and markers layer ordering with inheritance
- **Marker Support**: Comprehensive marker resolution with orientation and scaling
- **Pattern Implementation**: Advanced pattern fills with units, inheritance, and caching
- **Gradient Handling**: Linear and radial gradients with advanced coordinate systems
- **Caching Mechanisms**: Intelligent caching for paint servers to optimize performance
- **Href Inheritance**: Pattern and marker inheritance through href attributes

**Section sources**
- [lib/src/animation/animated_svg_painter_paint_order.dart:1-90](file://lib/src/animation/animated_svg_painter_paint_order.dart#L1-L90)
- [lib/src/animation/animated_svg_painter_markers.dart:1-449](file://lib/src/animation/animated_svg_painter_markers.dart#L1-L449)
- [lib/src/animation/animated_svg_painter_patterns.dart:1-184](file://lib/src/animation/animated_svg_painter_patterns.dart#L1-L184)
- [lib/src/animation/animated_svg_painter_gradients.dart:1-160](file://lib/src/animation/animated_svg_painter_gradients.dart#L1-L160)
- [lib/src/animation/animated_svg_painter.dart:63-69](file://lib/src/animation/animated_svg_painter.dart#L63-L69)