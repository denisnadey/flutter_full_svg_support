# Improved SMIL Animation Runtime

<cite>
**Referenced Files in This Document**
- [SMILTime.cpp](file://blink-b87d44f-Source-core-svg/animation/SMILTime.cpp)
- [SMILTime.h](file://blink-b87d44f-Source-core-svg/animation/SMILTime.h)
- [SMILTimeContainer.cpp](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp)
- [SMILTimeContainer.h](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.h)
- [SVGSMILElement.cpp](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp)
- [SVGSMILElement.h](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.h)
- [SVGAnimationElement.cpp](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.cpp)
- [SVGAnimateElement.cpp](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp)
- [SVGSetElement.cpp](file://blink-b87d44f-Source-core-svg/SVGSetElement.cpp)
- [SVGAnimatedNumber.cpp](file://blink-b87d44f-Source-core-svg/SVGAnimatedNumber.cpp)
- [smil_test.dart](file://test/animation/smil_test.dart)
- [smil_timeline.dart](file://lib/src/animation/smil/smil_timeline.dart)
- [smil_timeline_runtime.dart](file://lib/src/animation/smil/smil_timeline_runtime.dart)
- [smil_timeline_syncbase.dart](file://lib/src/animation/smil/smil_timeline_syncbase.dart)
- [timing_parser.dart](file://lib/src/animation/smil/timing_parser.dart)
- [timing_condition.dart](file://lib/src/animation/smil/timing_condition.dart)
- [smil_animation.dart](file://lib/src/animation/smil/smil_animation.dart)
- [smil_animation_value_computation.dart](file://lib/src/animation/smil/smil_animation_value_computation.dart)
- [smil_animation_curves.dart](file://lib/src/animation/smil/smil_animation_curves.dart)
- [interpolators.dart](file://lib/src/animation/smil/interpolators.dart)
- [motion_path.dart](file://lib/src/animation/smil/motion_path.dart)
- [distance_calculator.dart](file://lib/src/animation/smil/distance_calculator.dart)
</cite>

## Update Summary
**Changes Made**
- Enhanced SMIL animation runtime with circular dependency detection, multi-pass timing resolution, and graceful error recovery mechanisms
- Added _kMaxResolutionPasses constant and _ResolvedTiming class for tiebreaking scenarios
- Implemented sophisticated dependency graph construction with forward reference support
- Enhanced syncbase timing resolution with document order tiebreaking
- Added comprehensive circular dependency detection using DFS with path tracking
- Implemented multi-pass resolution algorithm with configurable pass limits
- Added graceful error recovery for unresolved animations with fallback to indefinite timing

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Enhanced Event System](#enhanced-event-system)
6. [Advanced Animation Value Computation](#advanced-animation-value-computation)
7. [Discrete CalcMode Support](#discrete-calcmode-support)
8. [Per-Segment Spline Easing](#per-segment-spline-easing)
9. [Enhanced Motion Animation Features](#enhanced-motion-animation-features)
10. [Advanced Distance Calculation System](#advanced-distance-calculation-system)
11. [Enhanced Timing Resolution System](#enhanced-timing-resolution-system)
12. [Circular Dependency Detection](#circular-dependency-detection)
13. [Multi-Pass Resolution Algorithm](#multi-pass-resolution-algorithm)
14. [Graceful Error Recovery](#graceful-error-recovery)
15. [Detailed Component Analysis](#detailed-component-analysis)
16. [DOM Event Dispatching](#dom-event-dispatching)
17. [Dependency Analysis](#dependency-analysis)
18. [Performance Considerations](#performance-considerations)
19. [Troubleshooting Guide](#troubleshooting-guide)
20. [Conclusion](#conclusion)

## Introduction
This document describes the significantly enhanced SMIL (Synchronized Multimedia Integration Language) animation runtime implemented in the Blink engine core and integrated with the Flutter SVG package. The runtime provides precise timing control, flexible begin/end conditions, repeat semantics, and **comprehensive DOM event dispatching capabilities** including beginEvent, endEvent, and repeatEvent triggering for external listeners and event-driven animations. It supports multiple animation elements (<animate>, <set>, <animateMotion>, <animateTransform>, <animateColor>) and integrates with the broader SVG rendering pipeline. The enhanced runtime now features advanced animation value computation for complex interpolations, improved timeline synchronization, sophisticated event model handling, **specialized support for discrete calcMode, per-segment spline easing, accumulate='sum' for motion animations, enhanced rotate modes**, and **robust circular dependency detection with multi-pass timing resolution and graceful error recovery mechanisms**.

## Project Structure
The SMIL animation runtime spans several core modules with enhanced event handling, advanced interpolation capabilities, and sophisticated timing resolution:
- Timing primitives and containers: SMILTime, SMILTimeContainer
- Animation element base and concrete implementations: SVGSMILElement, SVGAnimationElement, SVGAnimateElement, SVGSetElement
- **Enhanced timing system**: Event-based conditions, DOM event dispatching, external listener support, circular dependency detection
- **Advanced property animation infrastructure**: SVGAnimatedType, SVGAnimatedTypeAnimator, specific animators (e.g., SVGAnimatedNumberAnimator)
- **Complex interpolation system**: Path morphing, transform interpolation, color interpolation, and advanced easing functions
- **Enhanced motion animation system**: Per-segment spline easing, discrete calcMode support, accumulate='sum' handling, and improved rotate modes
- **Advanced distance calculation system**: Specialized calculators for different attribute types supporting paced calcMode
- **Enhanced timing resolution system**: Multi-pass syncbase resolution with circular dependency detection and document order tiebreaking
- **Test coverage**: Dart-based tests for interpolators, SMIL animation logic, event-driven scenarios, circular dependency handling, and edge cases

```mermaid
graph TB
subgraph "Timing Layer"
A["SMILTime<br/>Time values and operators"]
B["SMILTimeContainer<br/>Scheduler and frame loop"]
E["TimingParser<br/>DOM event parsing"]
F["SvgTimeline<br/>Enhanced timing resolution"]
G["_kMaxResolutionPasses<br/>Pass limit constant"]
H["_ResolvedTiming<br/>Tiebreaking class"]
end
subgraph "Animation Elements"
C["SVGSMILElement<br/>Base SMIL timing model"]
D["SVGAnimationElement<br/>Shared animation attributes"]
F1["SVGAnimateElement<br/>Concrete property animators"]
F2["SVGSetElement<br/>Immediate value setter"]
end
subgraph "Event System"
I["SvgTimeline<br/>Event-based timing"]
J["_dispatchAnimationDOMEvent<br/>DOM event dispatching"]
K["EventCondition<br/>External listener support"]
end
subgraph "Property Types"
L["SVGAnimatedType<br/>Typed animated values"]
M["SVGAnimatedTypeAnimator<br/>Base animator interface"]
N["SVGAnimatedNumberAnimator<br/>Number interpolation"]
end
subgraph "Advanced Interpolation"
O["Interpolators<br/>Multi-type interpolation"]
P["CubicBezier<br/>Easing functions"]
Q["Path Morphing<br/>SVG path interpolation"]
R["DistanceCalculator<br/>Paced calcMode support"]
S["MotionPath<br/>Enhanced path computation"]
end
subgraph "Enhanced Timing Resolution"
T["Circular Dependency Detection<br/>DFS with path tracking"]
U["Multi-Pass Resolution<br/>Configurable pass limits"]
V["Graceful Error Recovery<br/>Fallback to indefinite timing"]
W["Document Order Tiebreaking<br/>Priority resolution"]
end
A --> B
B --> C
C --> D
D --> F1
F1 --> L
L --> M
M --> N
E --> I
I --> J
J --> K
O --> P
O --> Q
R --> S
F --> T
F --> U
F --> V
F --> W
```

**Diagram sources**
- [SMILTime.h:34-55](file://blink-b87d44f-Source-core-svg/animation/SMILTime.h#L34-L55)
- [SMILTimeContainer.h:45-98](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.h#L45-L98)
- [SVGSMILElement.h:38-131](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.h#L38-L131)
- [SVGAnimationElement.cpp:50-64](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.cpp#L50-L64)
- [SVGAnimateElement.cpp:38-44](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L38-L44)
- [SVGSetElement.cpp:27-33](file://blink-b87d44f-Source-core-svg/SVGSetElement.cpp#L27-L33)
- [SVGAnimatedNumber.cpp:31-34](file://blink-b87d44f-Source-core-svg/SVGAnimatedNumber.cpp#L31-L34)
- [timing_parser.dart:96-147](file://lib/src/animation/smil/timing_parser.dart#L96-L147)
- [smil_timeline.dart:55-61](file://lib/src/animation/smil/smil_timeline.dart#L55-L61)
- [smil_timeline_runtime.dart:41-69](file://lib/src/animation/smil/smil_timeline_runtime.dart#L41-L69)
- [timing_condition.dart:126-161](file://lib/src/animation/smil/timing_condition.dart#L126-L161)
- [interpolators.dart:18-42](file://lib/src/animation/smil/interpolators.dart#L18-L42)
- [smil_animation_curves.dart:24-44](file://lib/src/animation/smil/smil_animation_curves.dart#L24-L44)
- [smil_animation_value_computation.dart:80-100](file://lib/src/animation/smil/smil_animation_value_computation.dart#L80-L100)
- [motion_path.dart:19-22](file://lib/src/animation/smil/motion_path.dart#L19-L22)
- [distance_calculator.dart:8-14](file://lib/src/animation/smil/distance_calculator.dart#L8-L14)
- [smil_timeline_syncbase.dart:3](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L3-L4)
- [smil_timeline_syncbase.dart:6](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L6-L25)

**Section sources**
- [SMILTime.cpp:34-66](file://blink-b87d44f-Source-core-svg/animation/SMILTime.cpp#L34-L66)
- [SMILTimeContainer.cpp:40-53](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L40-L53)
- [SVGSMILElement.cpp:109-131](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L109-L131)
- [SVGAnimationElement.cpp:50-64](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.cpp#L50-L64)
- [SVGAnimateElement.cpp:38-44](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L38-L44)
- [SVGSetElement.cpp:27-33](file://blink-b87d44f-Source-core-svg/SVGSetElement.cpp#L27-L33)
- [SVGAnimatedNumber.cpp:31-34](file://blink-b87d44f-Source-core-svg/SVGAnimatedNumber.cpp#L31-L34)
- [timing_parser.dart:96-147](file://lib/src/animation/smil/timing_parser.dart#L96-L147)
- [smil_timeline.dart:55-61](file://lib/src/animation/smil/smil_timeline.dart#L55-L61)
- [smil_timeline_runtime.dart:41-69](file://lib/src/animation/smil/smil_timeline_runtime.dart#L41-L69)
- [timing_condition.dart:126-161](file://lib/src/animation/smil/timing_condition.dart#L126-L161)

## Core Components
- SMILTime: Encapsulates time values with special sentinel values for unresolved/indefinite, plus arithmetic operators for addition, subtraction, and multiplication (used for duration × repeatCount).
- SMILTimeContainer: Central scheduler managing active animations, priority sorting, and frame scheduling via a timer. Handles begin/pause/resume/setElapsed lifecycle.
- SVGSMILElement: Implements the SMIL interval timing model, parsing begin/end lists, resolving intervals, restart/fill semantics, and driving per-frame progress.
- SVGAnimationElement: Shared logic for animation attributes (values, keyTimes, keyPoints, keySplines, calcMode, from/to/by), and animation mode determination.
- SVGAnimateElement: Concrete element that selects and drives property animators for specific attribute types (numbers, colors, transforms, etc.).
- SVGSetElement: Specialization that sets target values immediately without interpolation.
- **Enhanced Timing System**: Event-based conditions, DOM event parsing, external listener registration, and event-driven animation activation with circular dependency detection.
- **Advanced Property Animators**: Typed animators (e.g., SVGAnimatedNumberAnimator) compute interpolated values and handle additive composition.
- **Complex Interpolation System**: Multi-type interpolators for numbers, colors, transforms, paths, and lists with advanced easing functions and path morphing capabilities.
- **Enhanced Motion Animation System**: Specialized motion path computation with per-segment spline easing, discrete calcMode support, and accumulate='sum' handling.
- **Advanced Distance Calculation System**: Specialized calculators for different attribute types (numeric, color, length, path, transform) supporting paced calcMode.
- **Enhanced Timing Resolution System**: Multi-pass syncbase resolution with circular dependency detection, document order tiebreaking, and graceful error recovery.

**Section sources**
- [SMILTime.h:34-55](file://blink-b87d44f-Source-core-svg/animation/SMILTime.h#L34-L55)
- [SMILTimeContainer.h:45-98](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.h#L45-L98)
- [SVGSMILElement.h:38-131](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.h#L38-L131)
- [SVGAnimationElement.cpp:151-168](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.cpp#L151-L168)
- [SVGAnimateElement.cpp:55-62](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L55-L62)
- [SVGSetElement.cpp:27-33](file://blink-b87d44f-Source-core-svg/SVGSetElement.cpp#L27-L33)
- [SVGAnimatedNumber.cpp:31-34](file://blink-b87d44f-Source-core-svg/SVGAnimatedNumber.cpp#L31-L34)
- [timing_parser.dart:96-147](file://lib/src/animation/smil/timing_parser.dart#L96-L147)
- [smil_timeline.dart:55-61](file://lib/src/animation/smil/smil_timeline.dart#L55-L61)
- [smil_timeline_runtime.dart:41-69](file://lib/src/animation/smil/smil_timeline_runtime.dart#L41-L69)
- [timing_condition.dart:126-161](file://lib/src/animation/smil/timing_condition.dart#L126-L161)

## Architecture Overview
The runtime follows a layered design with enhanced event-driven capabilities, advanced interpolation systems, and sophisticated timing resolution:
- Timing layer: SMILTime and SMILTimeContainer manage absolute/relative time and scheduling.
- Element layer: SVGSMILElement encapsulates SMIL timing semantics and interval resolution.
- Property layer: SVGAnimationElement and SVGAnimateElement coordinate typed animated values and animators.
- **Event layer**: Enhanced timing system with DOM event dispatching and external listener support.
- **Interpolation layer**: Advanced interpolators handle complex value transformations including path morphing and transform interpolation.
- **Motion animation layer**: Enhanced motion path computation with per-segment spline easing and discrete calcMode support.
- **Distance calculation layer**: Specialized calculators for paced calcMode supporting different attribute types.
- **Enhanced timing resolution layer**: Multi-pass syncbase resolution with circular dependency detection and graceful error recovery.
- Application layer: Flutter integration consumes SMIL timing and applies computed values to render nodes.

```mermaid
sequenceDiagram
participant Timer as "SMILTimeContainer Timer"
participant Scheduler as "SMILTimeContainer"
participant Element as "SVGSMILElement"
participant Animator as "SVGAnimateElement"
participant Timeline as "SvgTimeline"
participant Resolver as "_resolveTimingConditionsImpl"
participant CircularDetect as "detectCircularDependencies"
participant DOM as "DOM Event System"
participant Interpolator as "Interpolators"
participant MotionPath as "MotionPath"
participant DistanceCalc as "DistanceCalculator"
participant Target as "Target SVGElement"
Timer->>Scheduler : timerFired()
Scheduler->>Scheduler : updateAnimations(elapsed)
Scheduler->>Element : progress(elapsed, resultsElement, seekToTime)
Element->>Element : resolve intervals and restart/fill
Element->>Timeline : _dispatchAnimationDOMEvent(endEvent)
Timeline->>DOM : dispatch beginEvent/endEvent
DOM->>Timeline : triggerEvent listeners
Timeline->>Element : activate dependent animations
Resolver->>CircularDetect : detectCircularDependencies()
CircularDetect->>Resolver : circularDependencies detected
Resolver->>Resolver : multi-pass resolution with _kMaxResolutionPasses
Resolver->>Timeline : setResolvedBeginTimes
Timeline->>Element : activate dependent animations
Element->>Interpolator : compute interpolated values
Element->>MotionPath : enhanced motion computation
Element->>DistanceCalc : paced calcMode distance calculation
Interpolator->>Target : apply results to animated properties
MotionPath->>Target : apply transform matrices
DistanceCalc->>Element : generate paced keyTimes
Scheduler->>Timer : startTimer(nextFireTime)
```

**Diagram sources**
- [SMILTimeContainer.cpp:221-226](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L221-L226)
- [SMILTimeContainer.cpp:262-329](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L262-L329)
- [SVGSMILElement.cpp:91-93](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L91-L93)
- [SVGAnimateElement.cpp:96-137](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L96-L137)
- [smil_timeline_runtime.dart:41-69](file://lib/src/animation/smil/smil_timeline_runtime.dart#L41-L69)
- [smil_timeline.dart:128-158](file://lib/src/animation/smil/smil_timeline.dart#L128-L158)
- [smil_timeline_syncbase.dart:206](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L206-L253)
- [smil_timeline_syncbase.dart:341](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L341-L390)

## Enhanced Event System
The enhanced SMIL animation runtime now includes comprehensive DOM event dispatching capabilities:

### DOM Event Dispatching
- **beginEvent**: Dispatched when an animation becomes active
- **endEvent**: Dispatched when an animation completes and becomes inactive
- **repeatEvent**: Dispatched when an animation enters a new iteration
- **External listeners**: Other animations can listen for these events using syncbase conditions

### Event-Based Animation Activation
- Event conditions support DOM event forms: `id.beginEvent`, `id.endEvent`, `id.repeatEvent`
- External listeners can register for animation events using event keys
- Automatic activation of dependent animations when source animations trigger events

### Enhanced Timing Parser
- Supports DOM event forms in syncbase conditions
- Normalizes `beginEvent`/`endEvent`/`repeatEvent` to standard `begin`/`end`/`repeat` types
- Maintains backward compatibility with existing syncbase syntax

**Section sources**
- [smil_timeline_runtime.dart:41-69](file://lib/src/animation/smil/smil_timeline_runtime.dart#L41-L69)
- [smil_timeline_runtime.dart:71-121](file://lib/src/animation/smil/smil_timeline_runtime.dart#L71-L121)
- [smil_timeline.dart:128-158](file://lib/src/animation/smil/smil_timeline.dart#L128-L158)
- [timing_parser.dart:96-147](file://lib/src/animation/smil/timing_parser.dart#L96-L147)
- [timing_condition.dart:126-161](file://lib/src/animation/smil/timing_condition.dart#L126-L161)

## Advanced Animation Value Computation
The runtime now features sophisticated animation value computation for complex interpolations:

### Multi-Type Interpolation System
- **Numbers and Lengths**: Linear interpolation with proper unit handling
- **Colors**: RGB color space interpolation with alpha channel support
- **Transforms**: Matrix decomposition and recomposition for smooth transform animations
- **Paths**: Complex path morphing with command normalization and curve interpolation
- **Lists**: Point and dash array interpolation for complex SVG attributes

### Advanced Easing Functions
- **Cubic Bezier Curves**: Precise timing control with Newton-Raphson solving
- **Step Functions**: CSS-like step timing for discrete animations
- **KeySplines Integration**: Per-segment easing for complex animations

### Enhanced Motion Animation Features
- **Per-Segment Spline Easing**: Different easing curves for each segment in motion animations
- **Discrete CalcMode Support**: Waypoint jumping without interpolation for motion animations
- **Accumulate='sum' Handling**: Position accumulation across motion animation repeats
- **Enhanced Rotate Modes**: Support for auto, auto-reverse, and fixed angle rotations

### Accumulate and Additive Composition
- **Accumulate="sum"**: Repeated value addition across animation cycles
- **Additive="sum"**: Multiple animation stacking with sandwich model priority
- **Nested additive animation support**: Proper ordering and precedence resolution

**Section sources**
- [smil_animation_value_computation.dart:26-77](file://lib/src/animation/smil/smil_animation_value_computation.dart#L26-L77)
- [smil_animation_value_computation.dart:102-173](file://lib/src/animation/smil/smil_animation_value_computation.dart#L102-L173)
- [smil_animation_value_computation.dart:220-270](file://lib/src/animation/smil/smil_animation_value_computation.dart#L220-L270)
- [smil_animation_curves.dart:24-44](file://lib/src/animation/smil/smil_animation_curves.dart#L24-L44)
- [interpolators.dart:18-42](file://lib/src/animation/smil/interpolators.dart#L18-L42)

## Discrete CalcMode Support
The runtime now provides comprehensive support for discrete calcMode animations:

### Discrete Animation Behavior
- **Waypoint Jumping**: For motion animations with keyPoints, discrete calcMode jumps between waypoints without interpolation
- **Segment-Based Selection**: Determines which keyPoint segment the current time falls into
- **Exact Position Retrieval**: Retrieves the exact keyPoint position without intermediate interpolation

### Implementation Details
- **Discrete Motion Value Computation**: Specialized method for discrete calcMode in motion animations
- **KeyPoints Integration**: Uses keyPoints and keyTimes arrays to determine segment boundaries
- **Accumulate Support**: Maintains accumulate='sum' functionality even in discrete mode
- **Rotate Mode Preservation**: Preserves rotate modes (auto, auto-reverse, fixed) in discrete calcMode

```mermaid
flowchart TD
Start(["Discrete CalcMode Request"]) --> CheckKeyPoints{"Check keyPoints & keyTimes"}
CheckKeyPoints --> |"Present"| FindSegment["Find keyPoint segment for time t"]
CheckKeyPoints --> |"Absent"| DefaultBehavior["Use default discrete behavior"]
FindSegment --> GetKeyPoint["Get exact keyPoint position"]
GetKeyPoint --> ApplyAccumulate["Apply accumulate='sum' if enabled"]
ApplyAccumulate --> ApplyRotate["Apply rotate mode (auto/auto-reverse/fixed)"]
DefaultBehavior --> ApplyRotate
ApplyRotate --> ReturnResult["Return discrete motion value"]
```

**Diagram sources**
- [smil_animation_value_computation.dart:190-245](file://lib/src/animation/smil/smil_animation_value_computation.dart#L190-L245)

**Section sources**
- [smil_animation_value_computation.dart:190-245](file://lib/src/animation/smil/smil_animation_value_computation.dart#L190-L245)
- [smil_animation_value_computation.dart:393-402](file://lib/src/animation/smil/smil_animation_value_computation.dart#L393-L402)

## Per-Segment Spline Easing
The runtime now supports advanced per-segment spline easing for motion animations:

### Segment-Based Easing Application
- **Multi-Segment Support**: Different keySplines can be applied to each segment of motion animations
- **Local Time Calculation**: Computes local progress within each segment for proper easing application
- **Segment Boundary Detection**: Identifies which segment contains the current global time

### Implementation Details
- **Segment Progress Calculation**: Determines local progress within the identified segment
- **Per-Segment Spline Application**: Applies the appropriate keySpline to the local progress
- **Global Progress Reconstruction**: Converts local eased progress back to global animation progress
- **Motion Path Integration**: Seamlessly integrates with motion path computation

```mermaid
flowchart TD
Start(["Motion Animation with KeySplines"]) --> FindSegment["Find segment containing time t"]
FindSegment --> CalcLocalT["Calculate local progress within segment"]
CalcLocalT --> CheckSpline{"Check if spline exists for segment"}
CheckSpline --> |"Yes"| ApplySpline["Apply keySpline to local progress"]
CheckSpline --> |"No"| UseLinear["Use linear progression"]
ApplySpline --> ReconstructGlobal["Reconstruct global eased time"]
UseLinear --> ReconstructGlobal
ReconstructGlobal --> GetPoint["Get motion path point at eased time"]
GetPoint --> ApplyTransform["Apply transform with rotate mode"]
```

**Diagram sources**
- [smil_animation_value_computation.dart:247-276](file://lib/src/animation/smil/smil_animation_value_computation.dart#L247-L276)

**Section sources**
- [smil_animation_value_computation.dart:247-276](file://lib/src/animation/smil/smil_animation_value_computation.dart#L247-L276)
- [motion_path.dart:533-603](file://lib/src/animation/smil/motion_path.dart#L533-L603)

## Enhanced Motion Animation Features
The runtime now provides enhanced motion animation capabilities:

### Accumulate='sum' for Motion Animations
- **Position Accumulation**: Adds the end position of each completed motion cycle to subsequent cycles
- **Cumulative Translation**: Maintains cumulative translation across all completed repeats
- **Motion Path Integration**: Uses motion path end positions for accurate accumulation

### Enhanced Rotate Modes
- **Auto Rotation**: Automatically rotates based on path tangent angle
- **Auto-Reverse Rotation**: Adds 180 degrees to auto rotation for reversed orientation
- **Fixed Angle Rotation**: Allows specifying custom rotation angles in degrees

### Motion Path Enhancements
- **Closed Path Detection**: Improved detection of closed paths with epsilon comparison
- **Tangent Angle Averaging**: Smooth rotation transitions at path segment boundaries
- **Boundary Handling**: Proper handling of path discontinuities and moveTo commands

**Section sources**
- [smil_animation_value_computation.dart:152-188](file://lib/src/animation/smil/smil_animation_value_computation.dart#L152-L188)
- [motion_path.dart:342-531](file://lib/src/animation/smil/motion_path.dart#L342-L531)

## Advanced Distance Calculation System
The runtime now features a sophisticated distance calculation system for paced calcMode:

### Specialized Distance Calculators
- **NumericDistanceCalculator**: Absolute difference for numeric and length values
- **ColorDistanceCalculator**: Euclidean distance in RGB color space
- **LengthDistanceCalculator**: Absolute difference for length measurements
- **PathDistanceCalculator**: Combined length and point sampling distance for path morphing
- **TransformDistanceCalculator**: Normalized Euclidean distance for transform decompositions

### Paced CalcMode Implementation
- **Distance-Based KeyTimes Generation**: Creates uniform keyTimes based on calculated distances
- **Total Distance Calculation**: Sums distances between consecutive values
- **Normalized Distribution**: Distributes keyTimes proportionally to segment distances
- **Fallback Handling**: Provides uniform distribution when distances cannot be calculated

```mermaid
flowchart TD
Start(["Paced CalcMode Request"]) --> CreateCalculator["Create distance calculator for attribute type"]
CreateCalculator --> CalculateDistances["Calculate distances between values"]
CalculateDistances --> CheckTotal{"Check total distance"}
CheckTotal --> |"Zero or invalid"| UniformDistribution["Generate uniform keyTimes"]
CheckTotal --> |"Valid"| NormalizeDistances["Normalize distances to total"]
NormalizeDistances --> GenerateKeyTimes["Generate keyTimes from cumulative distances"]
UniformDistribution --> GenerateKeyTimes
GenerateKeyTimes --> ApplyToAnimation["Apply keyTimes to animation"]
```

**Diagram sources**
- [distance_calculator.dart:10-236](file://lib/src/animation/smil/distance_calculator.dart#L10-L236)
- [smil_animation.dart:141-186](file://lib/src/animation/smil/smil_animation.dart#L141-L186)

**Section sources**
- [distance_calculator.dart:10-236](file://lib/src/animation/smil/distance_calculator.dart#L10-L236)
- [smil_animation.dart:141-186](file://lib/src/animation/smil/smil_animation.dart#L141-L186)

## Enhanced Timing Resolution System
The runtime now features a sophisticated timing resolution system with multi-pass resolution and circular dependency detection:

### Multi-Pass Syncbase Resolution
- **Iterative Resolution**: Animations are resolved through multiple passes until stable or maximum passes reached
- **Progress Tracking**: Monitors resolution progress to prevent infinite loops
- **Pass Limit Enforcement**: Configurable maximum passes via _kMaxResolutionPasses constant
- **Stability Detection**: Continues resolution until no more animations can be resolved

### Document Order Tiebreaking
- **Priority Resolution**: Uses document order as tiebreaker for simultaneous begin times
- **Sandwich Model Compliance**: Higher document order indices have higher priority per SMIL spec
- **Deterministic Ordering**: Ensures consistent behavior across different execution contexts

### Dependency Graph Construction
- **Forward Reference Support**: Handles animations that reference later-defined animations
- **Chain Dependency Resolution**: Supports multi-level dependency chains (A -> B -> C)
- **Event-Based Animation Initialization**: Sets event-only animations to "indefinite" state
- **Syncbase Condition Processing**: Extracts and processes syncbase timing conditions

```mermaid
flowchart TD
Start(["Initialize SvgTimeline"]) --> BuildGraph["Build dependency graph"]
BuildGraph --> DetectCircles["Detect circular dependencies"]
DetectCircles --> MultiPass["Multi-pass resolution loop"]
MultiPass --> CheckProgress{"Made progress?"}
CheckProgress --> |"Yes"| ResolveNext["Resolve next animation"]
CheckProgress --> |"No"| CheckPasses{"Pass count < _kMaxResolutionPasses?"}
CheckPasses --> |"Yes"| MultiPass
CheckPasses --> |"No"| HandleUnresolved["Handle unresolved animations"]
ResolveNext --> CheckProgress
HandleUnresolved --> SetInfinite["Set unresolved to infinite"]
SetInfinite --> ApplyResolved["Apply resolved begin times"]
ApplyResolved --> End(["Timeline ready"])
```

**Diagram sources**
- [smil_timeline_syncbase.dart:206](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L206-L253)
- [smil_timeline_syncbase.dart:351](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L351-L371)
- [smil_timeline_syncbase.dart:373](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L373-L390)

**Section sources**
- [smil_timeline_syncbase.dart:3](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L3-L4)
- [smil_timeline_syncbase.dart:6](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L6-L25)
- [smil_timeline_syncbase.dart:206](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L206-L253)
- [smil_timeline_syncbase.dart:351](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L351-L371)
- [smil_timeline_syncbase.dart:373](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L373-L390)

## Circular Dependency Detection
The runtime implements sophisticated circular dependency detection using depth-first search (DFS) with path tracking:

### DFS-Based Detection Algorithm
- **Path Tracking**: Maintains stack of currently visiting nodes to detect cycles
- **Visited Set**: Tracks nodes already processed to avoid redundant work
- **Cycle Identification**: Marks nodes in detected cycles for graceful breaking
- **Recursive Traversal**: Recursively explores all syncbase dependencies

### Graceful Cycle Breaking
- **Fallback Begin Times**: Uses simple begin times instead of resolved syncbase times for circular dependencies
- **Partial Resolution**: Allows other animations to resolve while breaking problematic cycles
- **Minimal Impact**: Prevents cascading failures while maintaining system stability
- **Debug Information**: Logs detection and breaking of circular dependencies

### Implementation Details
- **Detection Phase**: Single DFS traversal to identify all circular dependency chains
- **Resolution Phase**: Multi-pass algorithm continues despite detected cycles
- **Tiebreaking Integration**: Circular dependency status participates in document order tiebreaking
- **Performance Optimization**: Early termination when cycles are detected

```mermaid
flowchart TD
Start(["detectCircularDependencies"]) --> Init["Initialize visited & inStack sets"]
Init --> DFSLoop["For each animation: dfs(anim)"]
DFSLoop --> CheckVisited{"visited.contains(anim)?"}
CheckVisited --> |"Yes"| Return["Return (already processed)"]
CheckVisited --> |"No"| CheckInStack{"inStack.contains(anim)?"}
CheckInStack --> |"Yes"| MarkCircle["Add to circularDependencies"]
CheckInStack --> |"No"| MarkVisited["Add to visited & inStack"]
MarkVisited --> ExploreDeps["Explore syncbase dependencies"]
ExploreDeps --> PopStack["Remove from inStack"]
PopStack --> Return
MarkCircle --> PopStack
```

**Diagram sources**
- [smil_timeline_syncbase.dart:220](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L220-L253)

**Section sources**
- [smil_timeline_syncbase.dart:220](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L220-L253)
- [smil_timeline_syncbase.dart:341](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L341-L349)

## Multi-Pass Resolution Algorithm
The runtime implements a sophisticated multi-pass resolution algorithm designed to handle complex timing dependencies:

### Pass Management
- **Progress Monitoring**: Tracks whether any animations were successfully resolved in each pass
- **Pass Limit Enforcement**: Prevents infinite loops with configurable _kMaxResolutionPasses (default: 10)
- **Early Termination**: Stops when no more progress can be made or maximum passes reached
- **Stable State Detection**: Continues until resolution reaches a stable state

### Resolution Strategy
- **Resolvability Check**: Determines if an animation's conditions can be resolved
- **Event-Only Handling**: Treats animations with only event conditions as indefinitely delayed
- **Offset Conditions**: Always resolvable offset conditions bypass dependency checks
- **Syncbase Resolution**: Uses resolved begin times when available, fallback begin times otherwise

### Tiebreaking Mechanism
- **ResolvedTiming Class**: Encapsulates resolved times with document order metadata
- **Comparison Logic**: Earlier times win, document order as tiebreaker
- **Document Order Priority**: Lower document order numbers have higher priority
- **Consistent Ordering**: Ensures deterministic behavior for simultaneous events

```mermaid
flowchart TD
Start(["_resolveTimingConditionsImpl"]) --> DetectCircles["detectCircularDependencies()"]
DetectCircles --> InitVars["Initialize fullyResolved & circularDependencies"]
InitVars --> LoopPasses["while madeProgress && passCount < _kMaxResolutionPasses"]
LoopPasses --> CheckAnim["for each animation"]
CheckAnim --> CheckResolved{"fullyResolved.contains(anim)?"}
CheckResolved --> |"Yes"| NextAnim["continue"]
CheckResolved --> |"No"| CheckCanResolve{"canResolve(anim)?"}
CheckCanResolve --> |"No"| NextAnim
CheckCanResolve --> |"Yes"| ResolveTime["resolveBeginTime(anim)"]
ResolveTime --> CheckTime{"resolvedTime != null?"}
CheckTime --> |"No"| NextAnim
CheckTime --> |"Yes"| SetResolved["timeline._resolvedBeginTimes[anim] = resolvedTime"]
SetResolved --> AddFully["fullyResolved.add(anim)"]
AddFully --> SetProgress["madeProgress = true"]
SetProgress --> NextAnim
NextAnim --> CheckLoop{"passCount < _kMaxResolutionPasses?"}
CheckLoop --> |"Yes"| LoopPasses
CheckLoop --> |"No"| HandleUnresolved["Handle unresolved animations"]
HandleUnresolved --> SetInfinite["Set unresolved to _kTimelineInfinity"]
SetInfinite --> ApplyResolved["Apply resolved times to animations"]
ApplyResolved --> End(["Resolution complete"])
```

**Diagram sources**
- [smil_timeline_syncbase.dart:351](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L351-L371)
- [smil_timeline_syncbase.dart:373](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L373-L390)
- [smil_timeline_syncbase.dart:293](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L293-L339)

**Section sources**
- [smil_timeline_syncbase.dart:351](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L351-L371)
- [smil_timeline_syncbase.dart:373](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L373-L390)
- [smil_timeline_syncbase.dart:293](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L293-L339)

## Graceful Error Recovery
The runtime implements comprehensive error recovery mechanisms to ensure system stability:

### Unresolved Animation Handling
- **Graceful Degradation**: Treats unresolved animations as indefinitely delayed
- **Infinite Timing**: Sets unresolved begin times to _kTimelineInfinity constant
- **Progress Continuation**: Allows other animations to continue resolving despite failures
- **Debug Logging**: Provides informative debug messages about unresolved animations

### Fallback Strategies
- **Simple Begin Fallback**: Uses animation's simple begin time when syncbase resolution fails
- **Circular Dependency Break**: Uses fallback begin times for animations in circular dependencies
- **Event-Based Fallback**: Treats event-only animations as indefinitely delayed
- **Partial Success**: Allows partial success when some animations cannot be resolved

### System Stability Measures
- **Pass Limit Protection**: Prevents infinite loops with configurable maximum passes
- **Early Termination**: Stops resolution when no more progress can be made
- **Memory Management**: Cleans up temporary data structures after resolution
- **State Consistency**: Maintains consistent internal state throughout resolution process

```mermaid
flowchart TD
Start(["Handle unresolved animations"]) --> CheckUnresolved{"unresolved.isNotEmpty?"}
CheckUnresolved --> |"No"| ApplyResolved["Apply resolved times to animations"]
CheckUnresolved --> |"Yes"| LogMessage["Log debug message about unresolved"]
LogMessage --> SetInfinite["timeline._resolvedBeginTimes[anim] = _kTimelineInfinity"]
SetInfinite --> AddFully["fullyResolved.add(anim)"]
AddFully --> CheckMore{"More unresolved?"}
CheckMore --> |"Yes"| SetInfinite
CheckMore --> |"No"| ApplyResolved
ApplyResolved --> End(["Resolution complete"])
```

**Diagram sources**
- [smil_timeline_syncbase.dart:373](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L373-L390)

**Section sources**
- [smil_timeline_syncbase.dart:373](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L373-L390)
- [smil_timeline_syncbase.dart:378](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L378-L389)

## Detailed Component Analysis

### SMILTime and SMILTimeWithOrigin
SMILTime provides a compact representation of time values with three states:
- Finite time values
- Unresolved sentinel (no valid time)
- Indefinite sentinel (infinite duration)

Operators support basic arithmetic for combining durations and repeat counts. SMILTimeWithOrigin tracks whether a time was parsed from markup or injected programmatically, enabling selective clearing of dynamic origins.

```mermaid
classDiagram
class SMILTime {
+double value()
+bool isFinite()
+bool isIndefinite()
+bool isUnresolved()
+operator+(SMILTime, SMILTime)
+operator-(SMILTime, SMILTime)
+operator*(SMILTime, SMILTime)
}
class SMILTimeWithOrigin {
+enum Origin
+time() SMILTime
+originIsScript() bool
}
SMILTimeWithOrigin --> SMILTime : "wraps"
```

**Diagram sources**
- [SMILTime.h:34-55](file://blink-b87d44f-Source-core-svg/animation/SMILTime.h#L34-L55)
- [SMILTime.h:57-81](file://blink-b87d44f-Source-core-svg/animation/SMILTime.h#L57-L81)

**Section sources**
- [SMILTime.cpp:34-66](file://blink-b87d44f-Source-core-svg/animation/SMILTime.cpp#L34-L66)
- [SMILTime.h:34-55](file://blink-b87d44f-Source-core-svg/animation/SMILTime.h#L34-L55)
- [SMILTime.h:57-81](file://blink-b87d44f-Source-core-svg/animation/SMILTime.h#L57-L81)

### SMILTimeContainer: Scheduling and Frame Loop
SMILTimeContainer manages:
- Scheduled animations grouped by target element and attribute
- Priority sorting based on begin time and document order
- Timer-driven frame updates
- Lifecycle operations: begin, pause, resume, setElapsed

Key behaviors:
- Asynchronous notification of interval changes to coalesce updates
- Sorting by priority to resolve timing conflicts
- Applying results to targets and rescheduling based on next fire time

```mermaid
flowchart TD
Start(["Begin/Resume/NotifyIntervalsChanged"]) --> Collect["Collect scheduled animations"]
Collect --> Sort["Sort by priority (begin time, document order)"]
Sort --> Progress["Call progress(elapsed) on each animation"]
Progress --> NextFire["Compute earliest next fire time"]
NextFire --> Apply["Apply results to target elements"]
Apply --> Schedule["Start timer for next fire time"]
Schedule --> End(["Idle until next tick"])
```

**Diagram sources**
- [SMILTimeContainer.cpp:255-260](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L255-L260)
- [SMILTimeContainer.cpp:262-329](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L262-L329)

**Section sources**
- [SMILTimeContainer.cpp:40-53](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L40-L53)
- [SMILTimeContainer.cpp:100-105](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L100-L105)
- [SMILTimeContainer.cpp:133-148](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L133-L148)
- [SMILTimeContainer.cpp:150-169](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L150-L169)
- [SMILTimeContainer.cpp:171-207](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L171-L207)
- [SMILTimeContainer.cpp:209-219](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L209-L219)
- [SMILTimeContainer.cpp:221-226](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L221-L226)
- [SMILTimeContainer.cpp:228-236](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L228-L236)
- [SMILTimeContainer.cpp:255-260](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L255-L260)
- [SMILTimeContainer.cpp:262-329](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L262-L329)

### SVGSMILElement: SMIL Interval Timing Model
SVGSMILElement implements:
- Parsing begin/end lists supporting offsets, clocks, and conditions
- Condition resolution for event-base and syncbase timing
- Interval computation (begin/end, active duration, min/max clamping)
- Restart and fill semantics
- Progress calculation and next progress time estimation

```mermaid
classDiagram
class SVGSMILElement {
+parseClockValue(String) SMILTime
+parseOffsetValue(String) SMILTime
+parseBeginOrEnd(String, BeginOrEnd)
+progress(SMILTime, SVGSMILElement*, bool) bool
+nextProgressTime() SMILTime
+restart() Restart
+fill() FillMode
+dur() SMILTime
+repeatCount() SMILTime
+minValue() SMILTime
+maxValue() SMILTime
}
class Condition {
+Type
+BeginOrEnd
+String baseID
+String name
+SMILTime offset
+int repeats
}
SVGSMILElement --> Condition : "manages"
```

**Diagram sources**
- [SVGSMILElement.h:38-131](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.h#L38-L131)
- [SVGSMILElement.h:147-166](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.h#L147-L166)
- [SVGSMILElement.cpp:283-337](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L283-L337)
- [SVGSMILElement.cpp:419-437](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L419-L437)
- [SVGSMILElement.cpp:626-643](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L626-L643)
- [SVGSMILElement.cpp:645-697](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L645-L697)
- [SVGSMILElement.cpp:704-718](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L704-L718)
- [SVGSMILElement.cpp:725-765](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L725-L765)
- [SVGSMILElement.cpp:767-778](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L767-L778)
- [SVGSMILElement.cpp:780-800](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L780-L800)

**Section sources**
- [SVGSMILElement.cpp:99-107](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L99-L107)
- [SVGSMILElement.cpp:109-131](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L109-L131)
- [SVGSMILElement.cpp:283-337](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L283-L337)
- [SVGSMILElement.cpp:419-437](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L419-L437)
- [SVGSMILElement.cpp:626-643](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L626-L643)
- [SVGSMILElement.cpp:645-697](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L645-L697)
- [SVGSMILElement.cpp:704-718](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L704-L718)
- [SVGSMILElement.cpp:725-765](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L725-L765)
- [SVGSMILElement.cpp:767-778](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L767-L778)
- [SVGSMILElement.cpp:780-800](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L780-L800)

### SVGAnimationElement: Shared Animation Attributes
Provides shared parsing and validation for animation attributes:
- values, keyTimes, keyPoints, keySplines
- calcMode (linear, discrete, paced, spline)
- from/to/by attribute handling
- animation mode detection (To/By/Add)

```mermaid
flowchart TD
Parse["Parse values/keyTimes/keyPoints"] --> Mode["Update animation mode"]
Mode --> Validate["Validate calcMode and keySplines"]
Validate --> Ready["Ready for per-frame evaluation"]
```

**Diagram sources**
- [SVGAnimationElement.cpp:170-200](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.cpp#L170-L200)
- [SVGAnimationElement.cpp:66-89](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.cpp#L66-L89)
- [SVGAnimationElement.cpp:140-149](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.cpp#L140-L149)

**Section sources**
- [SVGAnimationElement.cpp:151-168](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.cpp#L151-L168)
- [SVGAnimationElement.cpp:170-200](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.cpp#L170-L200)
- [SVGAnimationElement.cpp:66-89](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.cpp#L66-L89)
- [SVGAnimationElement.cpp:140-149](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.cpp#L140-L149)

### SVGAnimateElement and SVGSetElement
- SVGAnimateElement: Determines animated property type for the target, ensures appropriate animator, computes animated values per frame, and supports additive composition.
- SVGSetElement: Forces ToAnimation mode and sets target values immediately without interpolation.

```mermaid
classDiagram
class SVGAnimateElement {
+hasValidAttributeType() bool
+calculateFromAndToValues(...)
+calculateFromAndByValues(...)
+calculateAnimatedValue(...)
+resetAnimatedType()
}
class SVGSetElement {
+updateAnimationMode()
}
SVGSetElement --|> SVGAnimateElement : "extends"
```

**Diagram sources**
- [SVGAnimateElement.cpp:55-62](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L55-L62)
- [SVGAnimateElement.cpp:96-137](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L96-L137)
- [SVGAnimateElement.cpp:147-174](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L147-L174)
- [SVGAnimateElement.cpp:195-200](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L195-L200)
- [SVGSetElement.cpp:27-33](file://blink-b87d44f-Source-core-svg/SVGSetElement.cpp#L27-L33)
- [SVGSetElement.cpp:40-44](file://blink-b87d44f-Source-core-svg/SVGSetElement.cpp#L40-L44)

**Section sources**
- [SVGAnimateElement.cpp:55-62](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L55-L62)
- [SVGAnimateElement.cpp:96-137](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L96-L137)
- [SVGAnimateElement.cpp:147-174](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L147-L174)
- [SVGAnimateElement.cpp:195-200](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L195-L200)
- [SVGSetElement.cpp:27-33](file://blink-b87d44f-Source-core-svg/SVGSetElement.cpp#L27-L33)
- [SVGSetElement.cpp:40-44](file://blink-b87d44f-Source-core-svg/SVGSetElement.cpp#L40-L44)

### Property Animators: SVGAnimatedNumberAnimator
Handles numeric interpolation and additive composition:
- Construct animated types from strings
- Compute distances for path morphing
- Apply CSS inheritance adjustments
- Support additive animation modes

```mermaid
classDiagram
class SVGAnimatedTypeAnimator {
<<interface>>
+calculateAnimatedValue(...)
+constructFromString(...)
+startAnimValAnimation(...)
+stopAnimValAnimation(...)
+resetAnimValToBaseVal(...)
+animValWillChange(...)
+animValDidChange(...)
+addAnimatedTypes(...)
}
class SVGAnimatedNumberAnimator {
+calculateAnimatedValue(...)
+calculateDistance(...)
}
SVGAnimatedNumberAnimator --|> SVGAnimatedTypeAnimator : "implements"
```

**Diagram sources**
- [SVGAnimatedNumber.cpp:31-34](file://blink-b87d44f-Source-core-svg/SVGAnimatedNumber.cpp#L31-L34)
- [SVGAnimatedNumber.cpp:85-100](file://blink-b87d44f-Source-core-svg/SVGAnimatedNumber.cpp#L85-L100)
- [SVGAnimatedNumber.cpp:102-110](file://blink-b87d44f-Source-core-svg/SVGAnimatedNumber.cpp#L102-L110)

**Section sources**
- [SVGAnimatedNumber.cpp:31-34](file://blink-b87d44f-Source-core-svg/SVGAnimatedNumber.cpp#L31-L34)
- [SVGAnimatedNumber.cpp:85-100](file://blink-b87d44f-Source-core-svg/SVGAnimatedNumber.cpp#L85-L100)
- [SVGAnimatedNumber.cpp:102-110](file://blink-b87d44f-Source-core-svg/SVGAnimatedNumber.cpp#L102-L110)

## DOM Event Dispatching

### Event Dispatch System
The enhanced SMIL animation runtime includes a comprehensive DOM event dispatching system:

#### Event Types
- **beginEvent**: Fired when an animation becomes active
- **endEvent**: Fired when an animation completes and becomes inactive  
- **repeatEvent**: Fired when an animation enters a new iteration

#### Event Registration and Activation
- Event listeners are registered using event keys in the format `"elementId:eventType"`
- External animations can listen for animation events using syncbase conditions
- Automatic activation of dependent animations when source animations trigger events

#### Implementation Details
- `_dispatchAnimationDOMEvent`: Core function for dispatching DOM animation events
- Event times are tracked and stored for future reference
- External listeners are notified and activated automatically

```mermaid
flowchart TD
Start(["Animation State Change"]) --> Check{"Check Animation State"}
Check --> |"Became Active"| Begin["Dispatch beginEvent"]
Check --> |"Completed"| End["Dispatch endEvent"]
Check --> |"New Iteration"| Repeat["Dispatch repeatEvent"]
Begin --> StoreBegin["Store beginEvent time"]
End --> StoreEnd["Store endEvent time"]
Repeat --> StoreRepeat["Store repeatEvent time"]
StoreBegin --> NotifyBegin["Notify beginEvent listeners"]
StoreEnd --> NotifyEnd["Notify endEvent listeners"]
StoreRepeat --> NotifyRepeat["Notify repeatEvent listeners"]
NotifyBegin --> ActivateBegin["Activate dependent animations"]
NotifyEnd --> ActivateEnd["Activate dependent animations"]
NotifyRepeat --> ActivateRepeat["Activate dependent animations"]
ActivateBegin --> Update["Update animation state"]
ActivateEnd --> Update
ActivateRepeat --> Update
```

**Diagram sources**
- [smil_timeline_runtime.dart:41-69](file://lib/src/animation/smil/smil_timeline_runtime.dart#L41-L69)
- [smil_timeline_runtime.dart:71-121](file://lib/src/animation/smil/smil_timeline_runtime.dart#L71-L121)
- [smil_timeline.dart:128-158](file://lib/src/animation/smil/smil_timeline.dart#L128-L158)

**Section sources**
- [smil_timeline_runtime.dart:41-69](file://lib/src/animation/smil/smil_timeline_runtime.dart#L41-L69)
- [smil_timeline_runtime.dart:71-121](file://lib/src/animation/smil/smil_timeline_runtime.dart#L71-L121)
- [smil_timeline.dart:128-158](file://lib/src/animation/smil/smil_timeline.dart#L128-L158)
- [timing_parser.dart:96-147](file://lib/src/animation/smil/timing_parser.dart#L96-L147)
- [timing_condition.dart:126-161](file://lib/src/animation/smil/timing_condition.dart#L126-L161)

## Dependency Analysis
The following diagram shows key dependencies among core components with enhanced event handling, advanced interpolation, and sophisticated timing resolution:

```mermaid
graph LR
SMILTime["SMILTime"] --> SMILTimeContainer["SMILTimeContainer"]
SMILTimeContainer --> SVGSMILElement["SVGSMILElement"]
SVGSMILElement --> SVGAnimationElement["SVGAnimationElement"]
SVGAnimationElement --> SVGAnimateElement["SVGAnimateElement"]
SVGAnimateElement --> SVGAnimatedType["SVGAnimatedType"]
SVGAnimatedType --> SVGAnimatedTypeAnimator["SVGAnimatedTypeAnimator"]
SVGAnimatedTypeAnimator --> SVGAnimatedNumberAnimator["SVGAnimatedNumberAnimator"]
TimingParser["TimingParser"] --> SvgTimeline["SvgTimeline"]
SvgTimeline --> DOMEventSystem["DOM Event System"]
DOMEventSystem --> EventCondition["EventCondition"]
DOMEventSystem --> ExternalListeners["External Listeners"]
Interpolators["Interpolators"] --> CubicBezier["CubicBezier"]
Interpolators --> PathMorphing["Path Morphing"]
Interpolators --> TransformInterpolation["Transform Interpolation"]
MotionPath["MotionPath"] --> DistanceCalculator["DistanceCalculator"]
DistanceCalculator --> NumericDistance["NumericDistanceCalculator"]
DistanceCalculator --> ColorDistance["ColorDistanceCalculator"]
DistanceCalculator --> LengthDistance["LengthDistanceCalculator"]
DistanceCalculator --> PathDistance["PathDistanceCalculator"]
DistanceCalculator --> TransformDistance["TransformDistanceCalculator"]
SvgTimeline --> CircularDependencyDetector["_kMaxResolutionPasses<br/>_ResolvedTiming"]
SvgTimeline --> MultiPassResolver["Multi-pass resolution algorithm"]
SvgTimeline --> ErrorRecovery["Graceful error recovery"]
```

**Diagram sources**
- [SMILTime.h:34-55](file://blink-b87d44f-Source-core-svg/animation/SMILTime.h#L34-L55)
- [SMILTimeContainer.h:45-98](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.h#L45-L98)
- [SVGSMILElement.h:38-131](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.h#L38-L131)
- [SVGAnimationElement.cpp:50-64](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.cpp#L50-L64)
- [SVGAnimateElement.cpp:38-44](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L38-L44)
- [SVGAnimatedNumber.cpp:31-34](file://blink-b87d44f-Source-core-svg/SVGAnimatedNumber.cpp#L31-L34)
- [timing_parser.dart:96-147](file://lib/src/animation/smil/timing_parser.dart#L96-L147)
- [smil_timeline.dart:55-61](file://lib/src/animation/smil/smil_timeline.dart#L55-L61)
- [timing_condition.dart:126-161](file://lib/src/animation/smil/timing_condition.dart#L126-L161)
- [interpolators.dart:18-42](file://lib/src/animation/smil/interpolators.dart#L18-L42)
- [smil_animation_curves.dart:24-44](file://lib/src/animation/smil/smil_animation_curves.dart#L24-L44)
- [motion_path.dart:19-22](file://lib/src/animation/smil/motion_path.dart#L19-L22)
- [distance_calculator.dart:207-236](file://lib/src/animation/smil/distance_calculator.dart#L207-236)
- [smil_timeline_syncbase.dart:3](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L3-L4)
- [smil_timeline_syncbase.dart:6](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L6-L25)

**Section sources**
- [SMILTimeContainer.h:45-98](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.h#L45-L98)
- [SVGSMILElement.h:38-131](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.h#L38-L131)
- [SVGAnimationElement.cpp:50-64](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.cpp#L50-L64)
- [SVGAnimateElement.cpp:38-44](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L38-L44)
- [SVGAnimatedNumber.cpp:31-34](file://blink-b87d44f-Source-core-svg/SVGAnimatedNumber.cpp#L31-L34)
- [timing_parser.dart:96-147](file://lib/src/animation/smil/timing_parser.dart#L96-L147)
- [smil_timeline.dart:55-61](file://lib/src/animation/smil/smil_timeline.dart#L55-L61)
- [timing_condition.dart:126-161](file://lib/src/animation/smil/timing_condition.dart#L126-L161)

## Performance Considerations
- Coalesced updates: SMILTimeContainer defers expensive updates by aggregating interval changes and scheduling a single asynchronous update per frame.
- Priority sorting: Animations are sorted by begin time and document order to minimize contention and ensure deterministic evaluation order.
- Cached durations: SVGSMILElement caches parsed durations and repeat values to avoid repeated parsing and recalculation.
- Efficient timers: Uses a one-shot timer with minimum delays to reduce CPU wake-ups and frame jitter.
- Additive composition: Property animators support additive composition to avoid recomputing base values each frame.
- **Event optimization**: DOM event dispatching uses efficient event key lookup and minimal memory allocation for event tracking.
- **Advanced interpolation caching**: Complex interpolations (paths, transforms) are computed efficiently with proper caching strategies.
- **Animation sandwich model**: Priority resolution prevents redundant computations by applying animations in document order.
- **Distance calculation optimization**: Specialized calculators avoid expensive geometric computations when possible.
- **Motion path caching**: MotionPath instances can be cached for repeated use in motion animations.
- **Per-segment spline optimization**: Local time calculations are performed efficiently for segment-based easing.
- **Circular dependency detection**: DFS algorithm runs in O(V+E) time complexity for dependency graph traversal.
- **Multi-pass resolution**: Configurable pass limits prevent excessive computational overhead while ensuring convergence.
- **Graceful error recovery**: Fallback mechanisms ensure system stability without impacting performance of working animations.

## Troubleshooting Guide
Common issues and diagnostics:
- Unresolved begin/end times: If parsing fails or conditions are not met, SMILTime resolves to unresolved/indefinite sentinel values. Verify attribute syntax and condition references.
- Pause/resume anomalies: Ensure begin() is called before pause()/resume(). Check accumulated active time and last resume time calculations.
- Target element changes: Changing target elements clears animated types and unschedules animations; re-scheduling occurs automatically when the element is re-inserted.
- Condition listeners: Event-based conditions require valid event bases and names; ensure event listeners are connected/disconnected properly.
- **DOM event issues**: Verify that animation IDs are properly set and that event listeners are registered correctly for beginEvent, endEvent, and repeatEvent dispatching.
- **Interpolation errors**: Complex path morphing requires compatible path structures; check for invalid SVG path data and ensure proper path normalization.
- **Easing function issues**: Cubic bezier curves require valid control points; verify keySplines format and range constraints.
- **Memory leaks**: Ensure proper cleanup of event listeners and animation references when elements are removed from the DOM.
- **Discrete calcMode issues**: Verify that keyPoints and keyTimes arrays are properly synchronized for discrete motion animations.
- **Per-segment spline problems**: Ensure that keySplines array length equals values.length - 1 for proper segment-based easing.
- **Accumulate='sum' behavior**: Remember that accumulate adds final values from completed repeats, not ongoing progress.
- **Rotate mode issues**: Verify that rotate modes are properly formatted (auto, auto-reverse, or numeric degrees).
- **Circular dependency issues**: Complex dependency chains may require multiple passes to resolve; check for circular references in syncbase conditions.
- **Multi-pass resolution problems**: Animations with unresolved dependencies may require additional passes; verify _kMaxResolutionPasses configuration.
- **Timing resolution failures**: Graceful error recovery treats unresolved animations as indefinitely delayed; check for missing referenced animations.

**Section sources**
- [SVGSMILElement.cpp:141-146](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L141-L146)
- [SVGSMILElement.cpp:517-542](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L517-L542)
- [SVGSMILElement.cpp:544-571](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L544-L571)
- [SMILTimeContainer.cpp:150-169](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L150-L169)
- [SMILTimeContainer.cpp:171-207](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L171-L207)
- [smil_timeline_runtime.dart:41-69](file://lib/src/animation/smil/smil_timeline_runtime.dart#L41-L69)
- [timing_parser.dart:96-147](file://lib/src/animation/smil/timing_parser.dart#L96-L147)
- [smil_timeline_syncbase.dart:341](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L341-L349)
- [smil_timeline_syncbase.dart:378](file://lib/src/animation/smil/smil_timeline_syncbase.dart#L378-L389)

## Conclusion
The significantly enhanced SMIL animation runtime delivers robust timing semantics, flexible begin/end conditions, and **comprehensive DOM event dispatching capabilities** including beginEvent, endEvent, and repeatEvent triggering for external listeners and event-driven animations. Its modular design enables extensibility for new animation elements and property types while maintaining high performance through coalesced updates, priority sorting, and cached computations. The enhanced event system allows for sophisticated animation choreography and external listener integration, making it suitable for complex interactive SVG applications. The advanced interpolation system provides sophisticated value computation for complex animations including path morphing, transform interpolation, and multi-type easing functions. **The runtime now features specialized support for discrete calcMode with waypoint jumping, per-segment spline easing for motion animations, accumulate='sum' handling for motion animations, and enhanced rotate modes (auto, auto-reverse, fixed angle)**. **Most significantly, the runtime now includes robust circular dependency detection using DFS with path tracking, multi-pass timing resolution with configurable pass limits via _kMaxResolutionPasses constant, and graceful error recovery mechanisms that treat unresolved animations as indefinitely delayed**. Integration with Flutter's SVG package allows precise control over animated attributes and seamless rendering updates with full support for DOM event-driven animation workflows, sophisticated animation sandwich model priority resolution, and comprehensive timing resolution with document order tiebreaking for simultaneous events.