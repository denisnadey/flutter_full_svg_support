# SMIL Animation Specification

<cite>
**Referenced Files in This Document**
- [SMILTime.h](file://blink-b87d44f-Source-core-svg/animation/SMILTime.h)
- [SMILTime.cpp](file://blink-b87d44f-Source-core-svg/animation/SMILTime.cpp)
- [SMILTimeContainer.h](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.h)
- [SMILTimeContainer.cpp](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp)
- [SVGSMILElement.h](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.h)
- [SVGSMILElement.cpp](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp)
- [SVGAnimationElement.h](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.h)
- [SVGAnimationElement.cpp](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.cpp)
- [SVGAnimateElement.h](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.h)
- [SVGAnimateElement.cpp](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp)
- [SVGAnimateTransformElement.h](file://blink-b87d44f-Source-core-svg/SVGAnimateTransformElement.h)
- [SVGAnimateTransformElement.cpp](file://blink-b87d44f-Source-core-svg/SVGAnimateTransformElement.cpp)
- [SVGAnimateMotionElement.h](file://blink-b87d44f-Source-core-svg/SVGAnimateMotionElement.h)
- [SVGAnimateMotionElement.cpp](file://blink-b87d44f-Source-core-svg/SVGAnimateMotionElement.cpp)
- [SVGSetElement.h](file://blink-b87d44f-Source-core-svg/SVGSetElement.h)
- [SVGSetElement.cpp](file://blink-b87d44f-Source-core-svg/SVGSetElement.cpp)
- [SVGAnimatedString.h](file://blink-b87d44f-Source-core-svg/SVGAnimatedString.h)
- [SVGAnimatedString.cpp](file://blink-b87d44f-Source-core-svg/SVGAnimatedString.cpp)
- [SVGElement.cpp](file://blink-b87d44f-Source-core-svg/SVGElement.cpp)
- [smil_parser_animation_parsing.dart](file://lib/src/animation/smil/smil_parser_animation_parsing.dart)
- [visibility_animation_test.dart](file://test/animation/visibility_animation_test.dart)
</cite>

## Update Summary
**Changes Made**
- Enhanced discrete calcMode handling section to reflect improved SMIL animation specification compliance
- Added comprehensive coverage of non-interpolatable string-type attributes
- Updated animation semantics to match SMIL specifications for string properties
- Expanded examples and test cases demonstrating proper discrete calcMode usage

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [Dependency Analysis](#dependency-analysis)
7. [Performance Considerations](#performance-considerations)
8. [Troubleshooting Guide](#troubleshooting-guide)
9. [Conclusion](#conclusion)
10. [Appendices](#appendices)

## Introduction
This document explains the SMIL (Synchronized Multimedia Integration Language) animation implementation in the SVG engine. It covers supported animation elements, timing semantics, interpolation modes, parser architecture, timeline management, and element processing. The implementation now includes enhanced discrete calcMode handling for string-type attributes that cannot be interpolated, ensuring compliance with SMIL specifications for non-interpolatable properties.

## Project Structure
The SMIL animation stack is organized around a core timing model and a family of animation elements:
- Timing primitives and containers define time semantics and scheduling
- A base SMIL element class coordinates begin/end timing, restart/fill policies, and per-frame progression
- Concrete animation elements implement attribute/path/value animations and apply results to targets
- Specialized animators handle discrete string-type attribute animations

```mermaid
graph TB
subgraph "Timing"
T1["SMILTime<br/>SMILTime.cpp/.h"]
T2["SMILTimeContainer<br/>SMILTimeContainer.cpp/.h"]
end
subgraph "SMIL Core"
S1["SVGSMILElement<br/>SVGSMILElement.cpp/.h"]
A1["SVGAnimationElement<br/>SVGAnimationElement.cpp/.h"]
end
subgraph "Concrete Animations"
E1["SVGAnimateElement<br/>SVGAnimateElement.cpp/.h"]
E2["SVGAnimateTransformElement<br/>SVGAnimateTransformElement.cpp/.h"]
E3["SVGAnimateMotionElement<br/>SVGAnimateMotionElement.cpp/.h"]
E4["SVGSetElement<br/>SVGSetElement.cpp/.h"]
end
subgraph "String Type Handling"
ST1["SVGAnimatedStringAnimator<br/>SVGAnimatedString.cpp/.h"]
ST2["CSS Property Mapping<br/>SVGElement.cpp"]
end
T2 --> S1
S1 --> A1
A1 --> E1
A1 --> E2
A1 --> E3
A1 --> E4
E1 --> ST1
ST1 --> ST2
```

**Diagram sources**
- [SMILTime.h:34-55](file://blink-b87d44f-Source-core-svg/animation/SMILTime.h#L34-L55)
- [SMILTime.cpp:34-65](file://blink-b87d44f-Source-core-svg/animation/SMILTime.cpp#L34-L65)
- [SMILTimeContainer.h:45-98](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.h#L45-L98)
- [SMILTimeContainer.cpp:40-53](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L40-L53)
- [SVGSMILElement.h:39-130](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.h#L39-L130)
- [SVGAnimationElement.h:65-100](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.h#L65-L100)
- [SVGAnimateElement.h:36-75](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.h#L36-L75)
- [SVGAnimateTransformElement.h:33-48](file://blink-b87d44f-Source-core-svg/SVGAnimateTransformElement.h#L33-L48)
- [SVGAnimateMotionElement.h:31-72](file://blink-b87d44f-Source-core-svg/SVGAnimateMotionElement.h#L31-L72)
- [SVGSetElement.h:29-36](file://blink-b87d44f-Source-core-svg/SVGSetElement.h#L29-L36)
- [SVGAnimatedString.h:40-55](file://blink-b87d44f-Source-core-svg/SVGAnimatedString.h#L40-L55)
- [SVGElement.cpp:648-690](file://blink-b87d44f-Source-core-svg/SVGElement.cpp#L648-L690)

**Section sources**
- [SMILTime.h:34-55](file://blink-b87d44f-Source-core-svg/animation/SMILTime.h#L34-L55)
- [SMILTimeContainer.h:45-98](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.h#L45-L98)
- [SVGSMILElement.h:39-130](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.h#L39-L130)
- [SVGAnimationElement.h:65-100](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.h#L65-L100)

## Core Components
- SMILTime: Encodes absolute and special time values (finite, indefinite, unresolved) and supports arithmetic for durations and repeat counts.
- SMILTimeContainer: Central scheduler that manages active animations, sorts by begin time and document order, and applies results per frame.
- SVGSMILElement: Base for SMIL animation elements; parses begin/end lists, resolves intervals, computes progress, and integrates with the container.
- SVGAnimationElement: Adds animation modes (from/to/by/values/path), calcMode (discrete/linear/paced/spline), and interpolation utilities.
- Concrete elements:
  - SVGAnimateElement: Attribute animations supporting additive accumulation and CSS vs XML property application
  - SVGAnimateTransformElement: Transform list animations with transform type validation
  - SVGAnimateMotionElement: Motion along a path or coordinate pairs with rotate handling
  - SVGSetElement: Constant-value setter equivalent to to-animation
- SVGAnimatedStringAnimator: Specialized animator for string-type attributes that enforces discrete calcMode semantics

**Section sources**
- [SMILTime.cpp:34-65](file://blink-b87d44f-Source-core-svg/animation/SMILTime.cpp#L34-L65)
- [SMILTimeContainer.cpp:262-329](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L262-L329)
- [SVGSMILElement.cpp:411-417](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L411-L417)
- [SVGAnimationElement.h:36-59](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.h#L36-L59)
- [SVGAnimateElement.cpp:370-387](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L370-L387)
- [SVGAnimateTransformElement.cpp:45-52](file://blink-b87d44f-Source-core-svg/SVGAnimateTransformElement.cpp#L45-L52)
- [SVGAnimateMotionElement.cpp:121-131](file://blink-b87d44f-Source-core-svg/SVGAnimateMotionElement.cpp#L121-L131)
- [SVGSetElement.cpp:40-44](file://blink-b87d44f-Source-core-svg/SVGSetElement.cpp#L40-L44)
- [SVGAnimatedString.cpp:75-89](file://blink-b87d44f-Source-core-svg/SVGAnimatedString.cpp#L75-L89)

## Architecture Overview
The SMIL pipeline:
- Parse begin/end lists and conditions; resolve instance times
- Compute active intervals and next progress time
- Advance per-frame, interpolate values, accumulate/add
- Apply results to target (CSS properties or SVG DOM animated values)
- Reschedule next tick based on nearest future event
- Enforce discrete calcMode for non-interpolatable string attributes

```mermaid
sequenceDiagram
participant Doc as "Document"
participant Container as "SMILTimeContainer"
participant Element as "SVGSMILElement"
participant Animator as "SVGAnimatedStringAnimator"
participant Target as "Target Element"
Doc->>Container : begin()
Container->>Container : elapsed()
loop per frame
Container->>Element : progress(elapsed, resultElement, seekToTime?)
Element->>Element : calculate percent/repeat, calcMode
Element->>Element : interpolate values (additive/accumulated)
Element->>Animator : animateDiscreteType(percent, from, to, result)
Animator->>Animator : enforce discrete semantics
Element-->>Container : nextProgressTime
Container->>Target : applyResultsToTarget()
end
Container->>Container : startTimer(nextProgressTime)
```

**Diagram sources**
- [SMILTimeContainer.cpp:133-148](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L133-L148)
- [SMILTimeContainer.cpp:262-329](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L262-L329)
- [SVGSMILElement.h:92-93](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.h#L92-L93)
- [SVGAnimateElement.cpp:346-368](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L346-L368)
- [SVGAnimatedString.cpp:75-89](file://blink-b87d44f-Source-core-svg/SVGAnimatedString.cpp#L75-L89)

## Detailed Component Analysis

### SMIL Timing Model
- Time values:
  - Finite: regular seconds
  - Indefinite: sentinel for unbounded durations
  - Unresolved: indicates parse errors or invalid expressions
- Arithmetic:
  - Addition/subtraction supported between finite/indefinite/unresolved
  - Multiplication for duration × repeatCount semantics
- Origins:
  - Parser-origin vs script-origin times distinguish dynamic begin/end updates

```mermaid
classDiagram
class SMILTime {
+value() double
+isFinite() bool
+isIndefinite() bool
+isUnresolved() bool
+operator+(SMILTime) SMILTime
+operator-(SMILTime) SMILTime
+operator*(SMILTime) SMILTime
}
class SMILTimeWithOrigin {
+time() SMILTime
+originIsScript() bool
}
```

**Diagram sources**
- [SMILTime.h:34-55](file://blink-b87d44f-Source-core-svg/animation/SMILTime.h#L34-L55)
- [SMILTime.h:57-81](file://blink-b87d44f-Source-core-svg/animation/SMILTime.h#L57-L81)
- [SMILTime.cpp:38-65](file://blink-b87d44f-Source-core-svg/animation/SMILTime.cpp#L38-L65)

**Section sources**
- [SMILTime.h:34-55](file://blink-b87d44f-Source-core-svg/animation/SMILTime.h#L34-L55)
- [SMILTime.cpp:34-65](file://blink-b87d44f-Source-core-svg/animation/SMILTime.cpp#L34-L65)

### Timeline Management
- Scheduling:
  - Elements register per-target/attribute groups
  - Sorted by begin time and document order
- Execution:
  - One-shot timer fires at next event
  - Applies accumulated results to targets
- Controls:
  - begin/pause/resume/setElapsed
  - Tracks begin/pause/resume times and accumulated active time

```mermaid
flowchart TD
Start(["begin()"]) --> Resolve["Resolve first interval"]
Resolve --> Loop{"Active?"}
Loop --> |Yes| Tick["updateAnimations(elapsed)"]
Tick --> Sort["Sort by begin time + doc order"]
Sort --> Progress["progress() per element"]
Progress --> Apply["applyResultsToTarget()"]
Apply --> Next["startTimer(min(nextFireTime))"]
Next --> Loop
Loop --> |No| End(["Idle"])
```

**Diagram sources**
- [SMILTimeContainer.cpp:133-148](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L133-L148)
- [SMILTimeContainer.cpp:262-329](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L262-L329)
- [SMILTimeContainer.h:70-76](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.h#L70-L76)

**Section sources**
- [SMILTimeContainer.h:45-98](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.h#L45-L98)
- [SMILTimeContainer.cpp:228-260](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.cpp#L228-L260)

### SMIL Element Lifecycle and Timing Parsing
- Attribute parsing:
  - begin/end lists accept clock values and conditions (syncbase/event/accesskey)
  - Conditions parsed into typed entries with offsets and repeat counts
- Interval resolution:
  - First interval computed at insertion
  - Begin/end list changes trigger re-resolution
- Restart/fill:
  - restart policy (always/whenNotActive/never)
  - fill policy (remove/freeze)
- Progress:
  - percent and repeat calculation
  - next progress time computation

```mermaid
flowchart TD
PStart(["parseAttribute(name,value)"]) --> Check{"begin or end?"}
Check --> |begin| ParseBegin["parseClockValue/parseCondition"]
Check --> |end| ParseEnd["parseClockValue/parseCondition"]
ParseBegin --> Connect["connectConditions()"]
ParseEnd --> Connect
Connect --> Resolve["resolveFirstInterval()"]
Resolve --> Wait["wait for first interval"]
```

**Diagram sources**
- [SVGSMILElement.cpp:456-478](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L456-L478)
- [SVGSMILElement.cpp:419-437](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L419-L437)
- [SVGSMILElement.cpp:517-542](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L517-L542)

**Section sources**
- [SVGSMILElement.h:147-186](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.h#L147-L186)
- [SVGSMILElement.cpp:283-337](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L283-L337)
- [SVGSMILElement.cpp:419-437](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L419-L437)

### Animation Modes and Interpolation
- Animation modes:
  - FromTo/FromBy/To/By/Values/Path
- Calc modes:
  - Discrete, Linear, Paced, Spline
- Additive/accumulated:
  - Additive applies delta; Accumulated sums across repeats
- Values animation:
  - Supports keyTimes/keyPoints/keySplines for pacing
- **Enhanced**: Automatic discrete calcMode enforcement for non-interpolatable string attributes

```mermaid
classDiagram
class SVGAnimationElement {
+animationMode() AnimationMode
+calcMode() CalcMode
+isAdditive() bool
+isAccumulated() bool
+updateAnimation(percent, repeat, result)
+animateDiscreteType(percent, from, to, result)
}
class SVGAnimateElement
class SVGAnimateTransformElement
class SVGAnimateMotionElement
class SVGSetElement
class SVGAnimatedStringAnimator {
+calculateAnimatedValue(percentage, repeat, from, to, ...)
+calculateDistance(from, to)
}
SVGAnimateElement --> SVGAnimationElement
SVGAnimateTransformElement --> SVGAnimateElement
SVGAnimateMotionElement --> SVGAnimationElement
SVGSetElement --> SVGAnimateElement
SVGAnimatedStringAnimator --> SVGAnimationElement
```

**Diagram sources**
- [SVGAnimationElement.h:36-59](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.h#L36-L59)
- [SVGAnimationElement.h:188-199](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.h#L188-L199)
- [SVGAnimateElement.h:36-75](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.h#L36-L75)
- [SVGAnimateTransformElement.h:33-48](file://blink-b87d44f-Source-core-svg/SVGAnimateTransformElement.h#L33-L48)
- [SVGAnimateMotionElement.h:31-72](file://blink-b87d44f-Source-core-svg/SVGAnimateMotionElement.h#L31-L72)
- [SVGSetElement.h:29-36](file://blink-b87d44f-Source-core-svg/SVGSetElement.h#L29-L36)
- [SVGAnimatedString.h:40-55](file://blink-b87d44f-Source-core-svg/SVGAnimatedString.h#L40-L55)

**Section sources**
- [SVGAnimationElement.h:36-59](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.h#L36-L59)
- [SVGAnimationElement.cpp:170-200](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.cpp#L170-L200)
- [SVGAnimateElement.cpp:96-137](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L96-L137)
- [SVGAnimatedString.cpp:75-89](file://blink-b87d44f-Source-core-svg/SVGAnimatedString.cpp#L75-L89)

### Attribute Animations (animate, set)
- Property type detection:
  - Determines AnimatedPropertyType for target attribute
  - Validates against element type (e.g., transform lists require animateTransform)
- Value computation:
  - From/To/By/Values with distance calculation
  - calcMode affects sampling; discrete forces step values
- **Enhanced**: Automatic discrete calcMode enforcement for string attributes
- Application:
  - CSS property path writes to animated style properties
  - SVG DOM path updates animated values and triggers change notifications

```mermaid
sequenceDiagram
participant AE as "SVGAnimateElement"
participant AT as "SVGAnimatedTypeAnimator"
participant SA as "SVGAnimatedStringAnimator"
participant Target as "Target Element"
AE->>AE : determineAnimatedPropertyType()
AE->>AT : ensureAnimator()
AE->>AT : calculateFromAndTo/By/Values()
AE->>SA : animateDiscreteType(percent, from, to, result)
SA->>SA : enforce discrete semantics
AE->>Target : applyResultsToTarget()
```

**Diagram sources**
- [SVGAnimateElement.cpp:64-94](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L64-L94)
- [SVGAnimateElement.cpp:147-174](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L147-L174)
- [SVGAnimateElement.cpp:346-368](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L346-L368)
- [SVGAnimatedString.cpp:75-89](file://blink-b87d44f-Source-core-svg/SVGAnimatedString.cpp#L75-L89)

**Section sources**
- [SVGAnimateElement.h:41-56](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.h#L41-L56)
- [SVGAnimateElement.cpp:96-137](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L96-L137)
- [SVGAnimateElement.cpp:346-368](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L346-L368)
- [SVGAnimatedString.cpp:75-89](file://blink-b87d44f-Source-core-svg/SVGAnimatedString.cpp#L75-L89)

### Transform Animations (animateTransform)
- Validates target supports transform list
- Parses transform type (skips matrix)
- Applies transform updates to target's transform list

**Section sources**
- [SVGAnimateTransformElement.cpp:45-52](file://blink-b87d44f-Source-core-svg/SVGAnimateTransformElement.cpp#L45-L52)
- [SVGAnimateTransformElement.cpp:62-77](file://blink-b87d44f-Source-core-svg/SVGAnimateTransformElement.cpp#L62-L77)

### Motion Animations (animateMotion)
- Path-based or coordinate-based motion
- Supports rotate modes: angle/auto/auto-reverse
- Uses path geometry to compute position and normal for rotation
- Supports accumulation across repeats

**Section sources**
- [SVGAnimateMotionElement.h:54-72](file://blink-b87d44f-Source-core-svg/SVGAnimateMotionElement.h#L54-L72)
- [SVGAnimateMotionElement.cpp:243-297](file://blink-b87d44f-Source-core-svg/SVGAnimateMotionElement.cpp#L243-L297)
- [SVGAnimateMotionElement.cpp:329-340](file://blink-b87d44f-Source-core-svg/SVGAnimateMotionElement.cpp#L329-L340)

### Set Animations (set)
- Fixed-value animation equivalent to to-animation
- Mode is constant and cannot be overridden

**Section sources**
- [SVGSetElement.cpp:40-44](file://blink-b87d44f-Source-core-svg/SVGSetElement.cpp#L40-L44)

### Enhanced Discrete CalcMode Handling for String Attributes
**Updated** The implementation now automatically enforces discrete calcMode for non-interpolatable string-type attributes to match SMIL specifications.

- **Automatic Enforcement**: String-type attributes are automatically set to discrete calcMode regardless of explicit specification
- **Non-Interpolatable Properties**: Visibility, display, fill-rule, stroke-linecap, stroke-linejoin, pointer-events, clip-rule, text-anchor, dominant-baseline, alignment-baseline
- **CSS Property Mapping**: String properties are mapped to AnimatedString type for proper handling
- **Animator Behavior**: SVGAnimatedStringAnimator enforces discrete semantics through animateDiscreteType method

```mermaid
flowchart TD
StringAttr["String Attribute"] --> Check{"Is Non-Interpolatable?"}
Check --> |Yes| AutoDiscrete["Auto Set calcMode='discrete'"]
Check --> |No| ExplicitCheck{"Explicit calcMode?"}
ExplicitCheck --> |Yes| UseExplicit["Use Explicit calcMode"]
ExplicitCheck --> |No| DefaultLinear["Default calcMode='linear'"]
AutoDiscrete --> ApplyDiscrete["Apply Discrete Semantics"]
UseExplicit --> ApplyExplicit["Apply Specified calcMode"]
DefaultLinear --> ApplyLinear["Apply Linear Interpolation"]
```

**Diagram sources**
- [smil_parser_animation_parsing.dart:134-147](file://lib/src/animation/smil/smil_parser_animation_parsing.dart#L134-L147)
- [smil_parser_animation_parsing.dart:465-480](file://lib/src/animation/smil/smil_parser_animation_parsing.dart#L465-L480)
- [SVGAnimatedString.cpp:75-89](file://blink-b87d44f-Source-core-svg/SVGAnimatedString.cpp#L75-L89)
- [SVGElement.cpp:648-690](file://blink-b87d44f-Source-core-svg/SVGElement.cpp#L648-L690)

**Section sources**
- [smil_parser_animation_parsing.dart:134-147](file://lib/src/animation/smil/smil_parser_animation_parsing.dart#L134-L147)
- [smil_parser_animation_parsing.dart:465-480](file://lib/src/animation/smil/smil_parser_animation_parsing.dart#L465-L480)
- [SVGAnimatedString.cpp:75-89](file://blink-b87d44f-Source-core-svg/SVGAnimatedString.cpp#L75-L89)
- [SVGElement.cpp:648-690](file://blink-b87d44f-Source-core-svg/SVGElement.cpp#L648-L690)

## Dependency Analysis
- SVGSMILElement depends on:
  - SMILTime/SMILTimeContainer for timing
  - SVGAnimationElement for animation semantics
  - Concrete elements for specialized behaviors
- SVGAnimationElement depends on:
  - Animated property types and animators
  - CSS property mapping for CSS-application path
- **Enhanced**: String attributes depend on SVGAnimatedStringAnimator for discrete semantics
- Concrete elements specialize:
  - Value parsing and interpolation
  - Result application to target transforms or style

```mermaid
graph LR
SMILTime --> SMILTimeContainer
SMILTimeContainer --> SVGSMILElement
SVGSMILElement --> SVGAnimationElement
SVGAnimationElement --> SVGAnimateElement
SVGAnimateElement --> SVGAnimateTransformElement
SVGAnimateElement --> SVGAnimateMotionElement
SVGAnimateElement --> SVGSetElement
SVGAnimateElement --> SVGAnimatedStringAnimator
SVGAnimatedStringAnimator --> SVGElement
```

**Diagram sources**
- [SMILTimeContainer.h:41-43](file://blink-b87d44f-Source-core-svg/animation/SMILTimeContainer.h#L41-L43)
- [SVGSMILElement.h:39-42](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.h#L39-L42)
- [SVGAnimationElement.h:65-67](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.h#L65-L67)
- [SVGAnimateElement.h:36-38](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.h#L36-L38)
- [SVGAnimatedString.h:40-55](file://blink-b87d44f-Source-core-svg/SVGAnimatedString.h#L40-L55)

**Section sources**
- [SVGSMILElement.h:39-42](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.h#L39-L42)
- [SVGAnimationElement.h:65-67](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.h#L65-L67)

## Performance Considerations
- Frame scheduling:
  - One-shot timers minimize overhead; minimum delay bounds keep frames reasonable
- Sorting:
  - Priority sorting by begin time and document order ensures deterministic evaluation
- Accumulation:
  - Additive/accumulated modes avoid recomputing base values each frame
- CSS vs DOM application:
  - CSS path avoids DOM churn; DOM path notifies renderers and instances
- **Enhanced**: String attribute animations use efficient discrete semantics without complex interpolation calculations

## Troubleshooting Guide
Common issues and diagnostics:
- Invalid begin/end values:
  - Unresolved times indicate parse failures; verify time formats and condition syntax
- Conditions not firing:
  - Ensure eventBase exists and condition names match; reconnect conditions on attribute changes
- Transform animations not applied:
  - Verify target supports transform list and element type matches (animate vs animateTransform)
- Motion path not followed:
  - Confirm pathAttr/mpath availability and path validity; check rotate mode expectations
- CSS property not updating:
  - Validate attributeType and CSS property mapping; ensure target is in document and instances updated
- **Enhanced**: String attribute animations not working:
  - Verify attribute is in discrete attributes list; automatic discrete calcMode enforcement occurs for non-interpolatable string properties
- **Enhanced**: Visibility/display animations incorrect:
  - Ensure discrete calcMode is being enforced; string properties automatically use discrete semantics per SMIL spec

**Section sources**
- [SVGSMILElement.cpp:303-337](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L303-L337)
- [SVGSMILElement.cpp:517-571](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L517-L571)
- [SVGAnimateTransformElement.cpp:45-52](file://blink-b87d44f-Source-core-svg/SVGAnimateTransformElement.cpp#L45-L52)
- [SVGAnimateMotionElement.cpp:133-154](file://blink-b87d44f-Source-core-svg/SVGAnimateMotionElement.cpp#L133-L154)
- [SVGAnimateElement.cpp:237-293](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L237-L293)

## Conclusion
The implementation provides a robust SMIL timing model with comprehensive support for attribute, transform, motion, and set animations. **Enhanced** with improved discrete calcMode handling for string-type attributes, the system now fully complies with SMIL specifications for non-interpolatable properties. The automatic enforcement of discrete semantics for visibility, display, fill-rule, stroke-linecap, and other string attributes ensures predictable animation behavior. The system integrates seamlessly with both CSS and SVG DOM property systems, offering flexible interpolation and accumulation semantics while maintaining strict compliance with SMIL standards.

## Appendices

### Supported SMIL Elements and Attributes
- animate, animateTransform, animateMotion, set
- Timing attributes: begin, end, dur, repeatDur, repeatCount, min, max, fill, restart
- Animation attributes: attributeType, attributeName, calcMode, values, keyTimes, keyPoints, keySplines, from, to, by
- animateMotion-specific: path, rotate

**Section sources**
- [SVGSMILElement.h:44-44](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.h#L44-L44)
- [SVGSMILElement.cpp:439-454](file://blink-b87d44f-Source-core-svg/animation/SVGSMILElement.cpp#L439-L454)
- [SVGAnimateMotionElement.h:96-102](file://blink-b87d44f-Source-core-svg/SVGAnimateMotionElement.h#L96-L102)

### Interpolation Methods
- calcMode:
  - discrete: step at midpoint (automatically enforced for string attributes)
  - linear: linear blend
  - paced: uniform speed along path/list
  - spline: bezier curves via keySplines
- additive/accumulate:
  - additive: adds delta per frame
  - accumulate: sums across repeats
- **Enhanced**: String attributes automatically use discrete calcMode per SMIL specification

**Section sources**
- [SVGAnimationElement.h:54-59](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.h#L54-L59)
- [SVGAnimationElement.cpp:147-162](file://blink-b87d44f-Source-core-svg/SVGAnimationElement.cpp#L147-L162)
- [SVGAnimateElement.cpp:370-387](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L370-L387)

### SMIL-to-CSS Conversion Guidance
- When applying to CSS properties:
  - Use animated style properties on target and instances
  - Ensure attributeType and CSS property mapping are valid
- When applying to SVG DOM properties:
  - Update animated values and notify via change hooks
- **Enhanced**: String attributes automatically handled as CSS properties for discrete semantics

**Section sources**
- [SVGAnimateElement.cpp:237-293](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L237-L293)
- [SVGAnimateElement.cpp:346-368](file://blink-b87d44f-Source-core-svg/SVGAnimateElement.cpp#L346-L368)

### Examples Index
- Attribute animation: animate with from/to and calcMode
- Transform animation: animateTransform with type
- Motion animation: animateMotion with path or from/to coordinates and rotate
- Set animation: set to a fixed value
- **Enhanced**: String attribute animation: visibility, display, fill-rule with discrete calcMode

### Non-Interpolatable String Attributes
**New Section** The following string-type attributes automatically use discrete calcMode semantics per SMIL specification:

- visibility: visible, hidden, collapse
- display: inline, block, list-item, etc.
- fill-rule: nonzero, evenodd
- stroke-linecap: butt, round, square
- stroke-linejoin: miter, round, bevel
- pointer-events: visiblepainted, visiblefill, visiblestroke, visible, pained, fill, stroke, all, none
- clip-rule: nonzero, evenodd
- text-anchor: start, middle, end
- dominant-baseline: baseline, liddle, abovex, etc.
- alignment-baseline: baseline, liddle, abovex, etc.

**Section sources**
- [smil_parser_animation_parsing.dart:465-480](file://lib/src/animation/smil/smil_parser_animation_parsing.dart#L465-L480)
- [SVGElement.cpp:648-690](file://blink-b87d44f-Source-core-svg/SVGElement.cpp#L648-L690)

### Test Cases and Verification
**New Section** Comprehensive test coverage demonstrates proper discrete calcMode behavior:

- Visibility animation with discrete calcMode maintains step-wise transitions
- Display animation with discrete calcMode properly handles show/hide states
- Freeze fill mode preserves final discrete values
- Remove fill mode restores base values after animation completion

**Section sources**
- [visibility_animation_test.dart:40-80](file://test/animation/visibility_animation_test.dart#L40-L80)
- [visibility_animation_test.dart:180-212](file://test/animation/visibility_animation_test.dart#L180-L212)