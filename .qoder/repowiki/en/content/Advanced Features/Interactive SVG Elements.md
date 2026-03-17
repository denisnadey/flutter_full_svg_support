# Interactive SVG Elements

<cite>
**Referenced Files in This Document**
- [svg.dart](file://lib/svg.dart)
- [animated_svg_picture.dart](file://lib/src/animation/animated_svg_picture.dart)
- [animated_svg_picture_pointer_events.dart](file://lib/src/animation/animated_svg_picture_pointer_events.dart)
- [animated_svg_picture_hit_test_traversal.dart](file://lib/src/animation/animated_svg_picture_hit_test_traversal.dart)
- [animated_svg_picture_hit_test_geometry.dart](file://lib/src/animation/animated_svg_picture_hit_test_geometry.dart)
- [animated_svg_picture_hit_test_text_runs.dart](file://lib/src/animation/animated_svg_picture_hit_test_text_runs.dart)
- [animated_svg_picture_hit_test_text_layout.dart](file://lib/src/animation/animated_svg_picture_hit_test_text_layout.dart)
- [animated_svg_picture_hit_test_text_path_segments.dart](file://lib/src/animation/animated_svg_picture_hit_test_text_path_segments.dart)
- [animated_svg_painter_clip_mask.dart](file://lib/src/animation/animated_svg_painter_clip_mask.dart)
- [animated_svg_painter_clip_mask_geometry.dart](file://lib/src/animation/animated_svg_painter_clip_mask_geometry.dart)
- [animated_svg_picture_events.dart](file://lib/src/animation/animated_svg_picture_events.dart)
- [animated_svg_picture_utils.dart](file://lib/src/animation/animated_svg_picture_utils.dart)
- [animated_svg_painter_use.dart](file://lib/src/animation/animated_svg_painter_use.dart)
- [animated_svg_picture_test.dart](file://test/animation/animated_svg_picture_test.dart)
- [svg_anchor_element_test.dart](file://test/animation/svg_anchor_element_test.dart)
- [svg_accessibility_test.dart](file://test/animation/svg_accessibility_test.dart)
- [smil_event_timing_widget.dart](file://example/lib/widgets/smil_event_timing_widget.dart)
- [ARCHITECTURE.md](file://ARCHITECTURE.md)
- [svg_dom.dart](file://lib/src/animation/svg_dom.dart)
</cite>

## Update Summary
**Changes Made**
- Added comprehensive anchor element system with link handling capabilities
- Introduced SvgLinkInfo structures for passing link information to callbacks
- Implemented onLinkTap callbacks for handling user interactions with SVG anchors
- Enhanced accessibility integration with Flutter's Semantics system for screen reader support
- Added support for both href and xlink:href attributes in anchor elements
- Integrated anchor information into hit testing traversal system
- Implemented accessibility properties (accessibleName, accessibleDescription, accessibleRole) for SVG documents

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [Enhanced Text Hit Testing System](#enhanced-text-hit-testing-system)
7. [Advanced Clip-Path and Mask Processing](#advanced-clip-path-and-mask-processing)
8. [Sophisticated Stroke-Width Expansion Algorithms](#sophisticated-stroke-width-expansion-algorithms)
9. [Anchor Element System and Link Handling](#anchor-element-system-and-link-handling)
10. [Accessibility Integration with Semantics](#accessibility-integration-with-semantics)
11. [Dependency Analysis](#dependency-analysis)
12. [Performance Considerations](#performance-considerations)
13. [Troubleshooting Guide](#troubleshooting-guide)
14. [Conclusion](#conclusion)
15. [Appendices](#appendices)

## Introduction
This document explains how interactive SVG elements are implemented in the repository, focusing on hit testing, pointer events, and user interaction patterns. It covers how clickable regions, hover effects, and event-driven animations work, and how to implement animated interactive elements such as buttons and clickable map regions. It also documents the hit test traversal system, pointer event handling, gesture recognition, and performance considerations for complex interactive SVGs.

**Updated** Enhanced with comprehensive anchor element system supporting link handling, SvgLinkInfo structures, onLinkTap callbacks, and accessibility integration with Flutter's Semantics system for screen reader support.

## Project Structure
The interactive SVG functionality centers around a specialized widget that parses SVG content, builds a DOM-like structure, and supports SMIL-based animations. Pointer events and hit testing are integrated via a traversal system that respects SVG's pointer-events model and visibility constraints. The new anchor element system provides seamless link handling with comprehensive accessibility support.

```mermaid
graph TB
subgraph "Public API"
A["svg.dart<br/>Exports and Svg utility"]
end
subgraph "Interactive Widgets"
B["AnimatedSvgPicture<br/>(widget)"]
C["SvgPicture<br/>(static image)"]
end
subgraph "Hit Testing & Events"
D["Hit Test Traversal<br/>(hit_test_traversal.dart)"]
E["Pointer Events Mode<br/>(pointer_events.dart)"]
F["Geometry Tests<br/>(hit_test_geometry.dart)"]
G["Text Hit Testing<br/>(hit_test_text_runs.dart)"]
H["Mouse & Tap Handlers<br/>(events.dart)"]
I["Anchor Element System<br/>(SvgLinkInfo, onLinkTap)"]
end
subgraph "Advanced Rendering"
J["Clip-Path Processing<br/>(painter_clip_mask_geometry.dart)"]
K["Mask Processing<br/>(painter_clip_mask.dart)"]
L["Text Layout<br/>(hit_test_text_layout.dart)"]
M["Text Path Segments<br/>(hit_test_text_path_segments.dart)"]
end
subgraph "Accessibility"
N["Semantics Integration<br/>(Flutter Semantics)"]
O["Accessibility Properties<br/>(accessibleName, Role)"]
end
subgraph "Utilities"
P["Stroke Tolerance<br/>(utils.dart)"]
Q["Painter (use/paint helpers)<br/>(animated_svg_painter_use.dart)"]
end
subgraph "Examples & Tests"
R["Event Timing Examples<br/>(smil_event_timing_widget.dart)"]
S["Interaction Tests<br/>(animated_svg_picture_test.dart)"]
T["Anchor Element Tests<br/>(svg_anchor_element_test.dart)"]
U["Accessibility Tests<br/>(svg_accessibility_test.dart)"]
end
A --> B
B --> D
B --> E
B --> F
B --> G
B --> H
B --> I
B --> J
B --> K
B --> L
B --> M
B --> N
B --> O
B --> P
B --> Q
R --> B
S --> B
T --> B
U --> B
```

**Diagram sources**
- [svg.dart:1-627](file://lib/svg.dart#L1-L627)
- [animated_svg_picture.dart:108-295](file://lib/src/animation/animated_svg_picture.dart#L108-L295)
- [animated_svg_picture_hit_test_traversal.dart:1-181](file://lib/src/animation/animated_svg_picture_hit_test_traversal.dart#L1-L181)
- [animated_svg_picture_pointer_events.dart:1-124](file://lib/src/animation/animated_svg_picture_pointer_events.dart#L1-L124)
- [animated_svg_picture_hit_test_geometry.dart:18-362](file://lib/src/animation/animated_svg_picture_hit_test_geometry.dart#L18-L362)
- [animated_svg_picture_hit_test_text_runs.dart:1-523](file://lib/src/animation/animated_svg_picture_hit_test_text_runs.dart#L1-L523)
- [animated_svg_painter_clip_mask_geometry.dart:1-175](file://lib/src/animation/animated_svg_painter_clip_mask_geometry.dart#L1-L175)
- [animated_svg_painter_clip_mask.dart:1-152](file://lib/src/animation/animated_svg_painter_clip_mask.dart#L1-L152)
- [animated_svg_picture_hit_test_text_layout.dart:1-252](file://lib/src/animation/animated_svg_picture_hit_test_text_layout.dart#L1-L252)
- [animated_svg_picture_hit_test_text_path_segments.dart:1-144](file://lib/src/animation/animated_svg_picture_hit_test_text_path_segments.dart#L1-L144)
- [animated_svg_picture_utils.dart:15-35](file://lib/src/animation/animated_svg_picture_utils.dart#L15-L35)
- [animated_svg_picture_events.dart:35-82](file://lib/src/animation/animated_svg_picture_events.dart#L35-L82)
- [animated_svg_painter_use.dart:87-150](file://lib/src/animation/animated_svg_painter_use.dart#L87-L150)
- [animated_svg_picture.dart:96-110](file://lib/src/animation/animated_svg_picture.dart#L96-L110)
- [animated_svg_picture.dart:184-186](file://lib/src/animation/animated_svg_picture.dart#L184-L186)
- [svg_accessibility_test.dart:281-449](file://test/animation/svg_accessibility_test.dart#L281-L449)
- [svg_dom.dart:491-503](file://lib/src/animation/svg_dom.dart#L491-L503)

**Section sources**
- [svg.dart:1-627](file://lib/svg.dart#L1-L627)
- [animated_svg_picture.dart:108-295](file://lib/src/animation/animated_svg_picture.dart#L108-L295)

## Core Components
- AnimatedSvgPicture: A StatefulWidget that parses SVG, constructs a timeline for SMIL animations, and wraps the rendered content with gesture detectors for pointer events and hover. Now includes comprehensive anchor element support with onLinkTap callbacks.
- Hit testing extensions: Traverse the SVG DOM, transform coordinates, and determine which element is under the pointer considering pointer-events modes, visibility, clipping, masking, and foreignObject constraints. Enhanced with anchor information tracking.
- Pointer events resolution: Computes effective pointer-events mode per node, inheriting from parents and normalizing values.
- Geometry tests: Implements shape-specific hit testing for rect, circle, ellipse, path, polygon, polyline, line, image, text, tspan, textPath, and foreignObject.
- Advanced text hit testing: Provides per-character precision for text elements with comprehensive positioning attribute support including x, y, dx, dy, and rotate lists.
- Sophisticated clip-path processing: Handles complex geometric intersections and advanced path construction for clip-path elements.
- Alpha-based mask assessment: Implements pixel-perfect visibility evaluation for mask elements using alpha channel analysis.
- Enhanced stroke-width algorithms: Uses precise stroke-width/2 tolerance calculation without artificial clamping for improved hit detection accuracy.
- Gesture handlers: Translate mouse enter/exit/hover and tap-down into timeline events (e.g., mouseover, mouseout, click) that drive SMIL animations.
- **New**: Anchor element system: Extracts link information from anchor elements and passes it through onLinkTap callbacks.
- **New**: Accessibility integration: Wraps SVG content with Flutter Semantics for screen reader support with accessibleName, accessibleDescription, and accessibleRole properties.

**Section sources**
- [animated_svg_picture.dart:108-295](file://lib/src/animation/animated_svg_picture.dart#L108-L295)
- [animated_svg_picture_pointer_events.dart:1-124](file://lib/src/animation/animated_svg_picture_pointer_events.dart#L1-L124)
- [animated_svg_picture_hit_test_traversal.dart:1-181](file://lib/src/animation/animated_svg_picture_hit_test_traversal.dart#L1-L181)
- [animated_svg_picture_hit_test_geometry.dart:18-362](file://lib/src/animation/animated_svg_picture_hit_test_geometry.dart#L18-L362)
- [animated_svg_picture_hit_test_text_runs.dart:1-523](file://lib/src/animation/animated_svg_picture_hit_test_text_runs.dart#L1-L523)
- [animated_svg_painter_clip_mask_geometry.dart:1-175](file://lib/src/animation/animated_svg_painter_clip_mask_geometry.dart#L1-L175)
- [animated_svg_painter_clip_mask.dart:1-152](file://lib/src/animation/animated_svg_painter_clip_mask.dart#L1-L152)
- [animated_svg_picture_utils.dart:15-35](file://lib/src/animation/animated_svg_picture_utils.dart#L15-L35)
- [animated_svg_picture_events.dart:35-82](file://lib/src/animation/animated_svg_picture_events.dart#L35-L82)
- [animated_svg_picture.dart:96-110](file://lib/src/animation/animated_svg_picture.dart#L96-L110)
- [animated_svg_picture.dart:184-186](file://lib/src/animation/animated_svg_picture.dart#L184-L186)

## Architecture Overview
The interactive flow integrates gesture input with SVG DOM traversal and SMIL timelines, now enhanced with advanced geometric processing and comprehensive anchor element support:

```mermaid
sequenceDiagram
participant U as "User"
participant W as "AnimatedSvgPicture.build"
participant G as "GestureDetector/MouseRegion"
participant S as "_AnimatedSvgPictureState"
participant T as "Hit Test Traversal"
participant P as "Pointer Events Resolver"
participant V as "Visibility/Clipping/Mask"
participant A as "Anchor System"
participant SE as "Semantics"
U->>W : "Tap/Hover/Mouse move"
W->>G : "Wrap with GestureDetector/MouseRegion"
G->>S : "onTapDown/onHover/onEnter/onExit"
S->>T : "_hitTestWithAnchorInfo(localPosition)"
T->>P : "_resolvePointerEventsMode(node)"
P-->>T : "effective mode"
T->>V : "_isPointVisibleInNodeSpace(...)"
V->>A : "Track anchor context"
A->>A : "_extractAnchorInfo(node)"
V-->>T : "visible?"
T->>TE : "_textRunsContainPoint(...)"
TE->>ST : "Sophisticated stroke-width expansion"
TE-->>T : "hit?"
T-->>S : "element id + anchor info"
alt "Click with anchor"
S->>SE : "Check accessibility info"
SE-->>S : "Semantics wrapper"
S->>CB : "widget.onLinkTap(anchorInfo)"
CB-->>S : "callback executed"
S->>TL : "triggerEvent(id, 'click')"
else "Hover"
S->>TL : "triggerEvent(id, 'mouseover'/'mouseout')"
end
TL-->>S : "animations update"
S-->>W : "repaint"
```

**Diagram sources**
- [animated_svg_picture.dart:246-269](file://lib/src/animation/animated_svg_picture.dart#L246-L269)
- [animated_svg_picture_events.dart:35-82](file://lib/src/animation/animated_svg_picture_events.dart#L35-L82)
- [animated_svg_picture_hit_test_traversal.dart:54-151](file://lib/src/animation/animated_svg_picture_hit_test_traversal.dart#L54-L151)
- [animated_svg_picture_pointer_events.dart:5-25](file://lib/src/animation/animated_svg_picture_pointer_events.dart#L5-L25)
- [animated_svg_painter_clip_mask_geometry.dart:4-91](file://lib/src/animation/animated_svg_painter_clip_mask_geometry.dart#L4-L91)
- [animated_svg_painter_clip_mask.dart:33-60](file://lib/src/animation/animated_svg_painter_clip_mask.dart#L33-L60)
- [animated_svg_picture_hit_test_text_runs.dart:5-50](file://lib/src/animation/animated_svg_picture_hit_test_text_runs.dart#L5-L50)
- [animated_svg_picture_utils.dart:15-20](file://lib/src/animation/animated_svg_picture_utils.dart#L15-L20)
- [animated_svg_picture_hit_test_traversal.dart:42-56](file://lib/src/animation/animated_svg_picture_hit_test_traversal.dart#L42-L56)
- [animated_svg_picture_events.dart:20-23](file://lib/src/animation/animated_svg_picture_events.dart#L20-L23)

## Detailed Component Analysis

### Hit Test Traversal System
The traversal walks the SVG DOM in visual order (children processed last-first) and applies transforms and visibility checks. It resolves pointer-events mode and delegates to geometry tests for shape-specific containment. Special handling exists for switch, use, and definition-only tags. **Updated** Enhanced with anchor context tracking that maintains and propagates anchor information through the traversal.

```mermaid
flowchart TD
Start(["Start _hitTestWithAnchorInfo"]) --> ComputeDoc["Compute document point from local"]
ComputeDoc --> Traverse["_hitTestNodeWithAnchor(root, docPoint, identity)"]
Traverse --> DefCheck{"Definition-only tag?"}
DefCheck --> |Yes| ReturnNull1["Return null"]
DefCheck --> |No| DisplayNone{"display:none?"}
DisplayNone --> |Yes| ReturnNull2["Return null"]
DisplayNone --> |No| ApplyXform["Apply node transform and child transform"]
ApplyXform --> Visible{"Point visible in node space?"}
Visible --> |No| ReturnNull3["Return null"]
Visible --> |Yes| AnchorCheck{"Is anchor element?"}
AnchorCheck --> |Yes| ExtractInfo["_extractAnchorInfo(node)"]
ExtractInfo --> UpdateAnchor["Update currentAnchor"]
AnchorCheck --> |No| SwitchCase{"tagName == 'switch'?"}
UpdateAnchor --> SwitchCase
SwitchCase --> |Yes| ActiveChild["Resolve active child and recurse"]
SwitchCase --> |No| ChildrenLoop["Iterate children backwards"]
ChildrenLoop --> ChildHit{"Child hit?"}
ChildHit --> |Yes| ReturnChild["Return child id + anchor info"]
ChildHit --> |No| UseCheck{"tagName == 'use'?"}
UseCheck --> |Yes| UseHit["_hitTestUseReferenceWithAnchor(...)"]
UseHit --> |Hit| ReturnUse["Return referenced id + anchor info"]
UseHit --> |Miss| FinalCheck{"pointer-events none<br/>or not hit-testable?"}
UseCheck --> |No| FinalCheck
FinalCheck --> |Yes| ReturnNull4["Return null"]
FinalCheck --> |No| Geometry["_nodeContainsPoint(...)"]
Geometry --> Hit{"Hit?"}
Hit --> |Yes| ReturnId["Return node.id + currentAnchor"]
Hit --> |No| ReturnNull5["Return null"]
```

**Diagram sources**
- [animated_svg_picture_hit_test_traversal.dart:17-40](file://lib/src/animation/animated_svg_picture_hit_test_traversal.dart#L17-L40)
- [animated_svg_picture_hit_test_traversal.dart:186-299](file://lib/src/animation/animated_svg_picture_hit_test_traversal.dart#L186-L299)
- [animated_svg_picture_hit_test_traversal.dart:42-56](file://lib/src/animation/animated_svg_picture_hit_test_traversal.dart#L42-L56)

**Section sources**
- [animated_svg_picture_hit_test_traversal.dart:1-181](file://lib/src/animation/animated_svg_picture_hit_test_traversal.dart#L1-L181)

### Pointer Events Resolution
Pointer events mode is resolved by walking up the DOM and normalizing inherited values. The effective mode determines whether fill, stroke, or bounding-box regions are considered for hit testing.

```mermaid
flowchart TD
StartPE(["Start _resolvePointerEventsMode"]) --> Inherit["_resolveInheritedPointerEvents(node)"]
Inherit --> Empty{"Mode empty/null?"}
Empty --> |Yes| Default["Return 'visiblepainted'"]
Empty --> |No| Normalize["Normalize and validate"]
Normalize --> Valid{"Known mode?"}
Valid --> |Yes| ReturnMode["Return mode"]
Valid --> |No| Default
```

**Diagram sources**
- [animated_svg_picture_pointer_events.dart:5-25](file://lib/src/animation/animated_svg_picture_pointer_events.dart#L5-L25)
- [animated_svg_picture_pointer_events.dart:105-122](file://lib/src/animation/animated_svg_picture_pointer_events.dart#L105-L122)

**Section sources**
- [animated_svg_picture_pointer_events.dart:1-124](file://lib/src/animation/animated_svg_picture_pointer_events.dart#L1-L124)

### Geometry-Based Hit Testing
Shape-specific logic determines whether a point falls inside fill or stroke, or within a bounding box, depending on the pointer-events mode and visibility.

```mermaid
flowchart TD
StartGeom(["Start _nodeContainsPoint"]) --> GetMode["_resolvePointerEventsMode(node)"]
GetMode --> Hidden{"visibility='hidden'?"}
Hidden --> |Yes| FillAllowed{"Mode allows fill/stroke?"}
Hidden --> |No| Proceed["Proceed"]
FillAllowed --> |No| ReturnFalse["Return false"]
FillAllowed --> |Yes| Proceed
Proceed --> Shape{"tagName"}
Shape --> Rect["rect: rectPath.contains(point) or stroke"]
Shape --> Circle["circle: ovalPath.contains(point) or stroke"]
Shape --> Ellipse["ellipse: rect-based bounds or stroke"]
Shape --> Line["line: distance to segment or endpoints"]
Shape --> PathPoly["path/polygon/polyline: path.contains(point) or stroke"]
Shape --> ImageText["image/foreignObject/text/tspan/textPath: special cases"]
Rect --> ReturnBool["Return true/false"]
Circle --> ReturnBool
Ellipse --> ReturnBool
Line --> ReturnBool
PathPoly --> ReturnBool
ImageText --> ReturnBool
```

**Diagram sources**
- [animated_svg_picture_hit_test_geometry.dart:18-362](file://lib/src/animation/animated_svg_picture_hit_test_geometry.dart#L18-L362)

**Section sources**
- [animated_svg_picture_hit_test_geometry.dart:18-362](file://lib/src/animation/animated_svg_picture_hit_test_geometry.dart#L18-L362)

### Visibility, Clipping, Masking, and ForeignObject Constraints
Hit testing enforces clipping, masking, and foreignObject viewport boundaries before geometry tests. Clip-path and mask are resolved using container transforms and computed paths with advanced geometric intersection calculations.

```mermaid
flowchart TD
StartVis(["Start _isPointVisibleInNodeSpace"]) --> Clip["clip-path present?"]
Clip --> |Yes| ClipPath["Advanced clip-path geometry processing"]
Clip --> |No| Mask["mask present?"]
ClipPath --> Mask
Mask --> |Yes| MaskPath["Alpha-based mask assessment"]
Mask --> |No| FO["foreignObject viewport?"]
MaskPath --> FO
FO --> |Yes| FOCheck["Rect.contains(point)"]
FO --> |No| True["Visible=true"]
FOCheck --> Visible{"Visible?"}
ClipPath --> Visible
MaskPath --> Visible
Visible --> |No| ReturnFalse["Return false"]
Visible --> |Yes| ReturnTrue["Return true"]
```

**Diagram sources**
- [animated_svg_painter_clip_mask_geometry.dart:4-91](file://lib/src/animation/animated_svg_painter_clip_mask_geometry.dart#L4-L91)
- [animated_svg_painter_clip_mask.dart:33-60](file://lib/src/animation/animated_svg_painter_clip_mask.dart#L33-L60)

**Section sources**
- [animated_svg_painter_clip_mask_geometry.dart:1-175](file://lib/src/animation/animated_svg_painter_clip_mask_geometry.dart#L1-L175)
- [animated_svg_painter_clip_mask.dart:1-152](file://lib/src/animation/animated_svg_painter_clip_mask.dart#L1-L152)

### Gesture Recognition and Event Handling
MouseRegion and GestureDetector capture hover, enter/exit, and tap-down events. The state updates the hovered element and triggers timeline events that drive SMIL animations. **Updated** Enhanced with anchor information extraction and onLinkTap callback execution.

```mermaid
sequenceDiagram
participant MR as "MouseRegion"
participant GS as "_AnimatedSvgPictureState"
participant TL as "Timeline"
MR->>GS : "onEnter(localPosition)"
GS->>GS : "_handleMouseEnter(position)"
GS->>GS : "_updateHoveredElement(position)"
GS->>TL : "triggerEvent(id, 'mouseover')"
MR->>GS : "onHover(localPosition)"
GS->>GS : "_handleMouseHover(position)"
GS->>GS : "_updateHoveredElement(position)"
MR->>GS : "onExit()"
GS->>GS : "_handleMouseExit()"
GS->>TL : "triggerEvent(null, 'mouseout')"
MR->>GS : "onTapDown(details)"
GS->>GS : "_hitTestWithAnchorInfo(localPosition)"
GS->>GS : "Extract anchor info if present"
GS->>TL : "triggerEvent(id, 'click')"
alt "Anchor present"
GS->>GS : "widget.onLinkTap(anchorInfo)"
end
```

**Diagram sources**
- [animated_svg_picture.dart:246-269](file://lib/src/animation/animated_svg_picture.dart#L246-L269)
- [animated_svg_picture_events.dart:35-82](file://lib/src/animation/animated_svg_picture_events.dart#L35-L82)
- [animated_svg_picture_events.dart:20-23](file://lib/src/animation/animated_svg_picture_events.dart#L20-L23)

**Section sources**
- [animated_svg_picture_events.dart:35-82](file://lib/src/animation/animated_svg_picture_events.dart#L35-L82)
- [animated_svg_picture.dart:246-269](file://lib/src/animation/animated_svg_picture.dart#L246-L269)

### Implementing Clickable Regions, Hover Effects, and Touch Interactions
- Clickable regions: Use pointer-events modes to define hit areas. Tests demonstrate pointer-events none disabling clicks, child overrides restoring hit testing, fill-only hits even with no fill paint, stroke-only hits, bounding-box hits, and visibility-hidden elements not responding to pointer-events visiblepainted.
- Hover effects: Mouse enter/exit and hover events trigger mouseover/mouseout on the timeline, enabling SMIL animations.
- Touch interactions: Tap-down events are captured and mapped to click events on the targeted element.
- **New**: Anchor elements: Clickable regions within anchor elements trigger onLinkTap callbacks with SvgLinkInfo containing href and target information.

Practical examples:
- Interactive button with click feedback and ripple effect.
- Hover-triggered animations for scaling and color changes.
- Chain reactions using event timing conditions.
- **New**: Clickable SVG maps with external link navigation.
- **New**: Accessible SVG elements with proper screen reader support.

**Section sources**
- [animated_svg_picture_test.dart:2090-2442](file://test/animation/animated_svg_picture_test.dart#L2090-L2442)
- [smil_event_timing_widget.dart:235-315](file://example/lib/widgets/smil_event_timing_widget.dart#L235-L315)
- [smil_event_timing_widget.dart:510-534](file://example/lib/widgets/smil_event_timing_widget.dart#L510-L534)
- [svg_anchor_element_test.dart:69-200](file://test/animation/svg_anchor_element_test.dart#L69-L200)

## Enhanced Text Hit Testing System

### Per-Character Hit Testing Precision
The new text hit testing system provides unprecedented precision for text elements by implementing per-character hit detection with comprehensive positioning attribute support.

```mermaid
flowchart TD
StartText(["Start _textRunsContainPoint"]) --> BuildRuns["_buildTextHitRuns(textRoot)"]
BuildRuns --> CheckModes{"Allow fill/stroke/bounds?"}
CheckModes --> |No| ReturnFalse["Return false"]
CheckModes --> |Yes| IterateRuns["Iterate text hit runs"]
IterateRuns --> CheckBounds{"Bounding box hit?"}
CheckBounds --> |Yes| ReturnTrue1["Return true"]
CheckBounds --> |No| CheckFill{"Fill hit?"}
CheckFill --> |Yes| ReturnTrue2["Return true"]
CheckFill --> |No| CheckStroke{"Stroke hit?"}
CheckStroke --> |Yes| ReturnTrue3["Return true"]
CheckStroke --> |No| NextRun["Next run"]
NextRun --> IterateRuns
ReturnFalse --> End["Return false"]
ReturnTrue1 --> End
ReturnTrue2 --> End
ReturnTrue3 --> End
```

**Diagram sources**
- [animated_svg_picture_hit_test_text_runs.dart:5-50](file://lib/src/animation/animated_svg_picture_hit_test_text_runs.dart#L5-L50)

### Advanced Text Positioning Attributes
The system now supports comprehensive text positioning with sophisticated attribute handling:

- **x, y lists**: Multiple coordinate values for individual character positioning
- **dx, dy lists**: Relative adjustments for character spacing
- **rotate lists**: Character-specific rotation angles
- **tspan absolute positioning**: Support for absolute X/Y coordinates in child elements
- **Text anchor handling**: Proper alignment for start, middle, and end positions

**Section sources**
- [animated_svg_picture_hit_test_text_runs.dart:150-276](file://lib/src/animation/animated_svg_picture_hit_test_text_runs.dart#L150-L276)
- [animated_svg_picture_hit_test_text_layout.dart:55-224](file://lib/src/animation/animated_svg_picture_hit_test_text_layout.dart#L55-L224)

### Text Path Segment Processing
Advanced text-on-path rendering with precise segment-based hit testing:

```mermaid
flowchart TD
StartPath(["Start _appendTextPathSegmentRuns"]) --> MeasureGlyphs["Measure glyph metrics"]
MeasureGlyphs --> CalcAdvances["Calculate display advances"]
CalcAdvances --> ApplyLengthAdjust["Apply textLength adjustments"]
ApplyLengthAdjust --> CalcOffsets["Calculate offset positions"]
CalcOffsets --> ExtractPath["Extract path segments"]
ExtractPath --> CreateHitRuns["Create text hit runs"]
CreateHitRuns --> ReturnConsumed["Return consumed width"]
```

**Diagram sources**
- [animated_svg_picture_hit_test_text_path_segments.dart:5-142](file://lib/src/animation/animated_svg_picture_hit_test_text_path_segments.dart#L5-L142)

**Section sources**
- [animated_svg_picture_hit_test_text_path_segments.dart:1-144](file://lib/src/animation/animated_svg_picture_hit_test_text_path_segments.dart#L1-L144)

## Advanced Clip-Path and Mask Processing

### Sophisticated Clip-Path Geometry Construction
The enhanced clip-path processing system handles complex geometric intersections and advanced path construction:

- **Recursive use stack management**: Prevents infinite recursion with depth limiting
- **Transform chain application**: Properly applies nested transformations through the use hierarchy
- **Switch element handling**: Resolves active children in switch containers
- **Viewport-aware geometry**: Supports both objectBoundingBox and userSpaceOnUse units
- **Advanced path combination**: Uses geometric operations for complex clip-path compositions

**Section sources**
- [animated_svg_painter_clip_mask_geometry.dart:4-91](file://lib/src/animation/animated_svg_painter_clip_mask_geometry.dart#L4-L91)
- [animated_svg_painter_clip_mask_geometry.dart:126-161](file://lib/src/animation/animated_svg_painter_clip_mask_geometry.dart#L126-L161)

### Alpha-Based Mask Assessment
The new mask processing system implements pixel-perfect visibility evaluation:

- **Alpha channel analysis**: Evaluates mask opacity for precise visibility determination
- **Content units support**: Handles both objectBoundingBox and userSpaceOnUse maskContentUnits
- **Region intersection**: Combines mask path with effective region bounds
- **Geometric optimization**: Uses efficient path operations for mask computation

**Section sources**
- [animated_svg_painter_clip_mask.dart:33-60](file://lib/src/animation/animated_svg_painter_clip_mask.dart#L33-L60)
- [animated_svg_painter_clip_mask.dart:103-150](file://lib/src/animation/animated_svg_painter_clip_mask.dart#L103-L150)

## Sophisticated Stroke-Width Expansion Algorithms

### Precise Stroke Tolerance Calculation
The enhanced stroke-width algorithms provide improved hit detection accuracy:

- **Actual stroke-width/2 calculation**: Uses precise division without artificial clamping
- **Minimum tolerance enforcement**: Ensures hairline strokes remain hittable with minimum 0.5 tolerance
- **Linecap tolerance integration**: Adds extra hit area for round and square linecaps
- **Path sampling optimization**: Uses adaptive sampling based on path length for efficient stroke detection

**Section sources**
- [animated_svg_picture_utils.dart:15-35](file://lib/src/animation/animated_svg_picture_utils.dart#L15-L35)
- [animated_svg_picture_hit_test_geometry.dart:150-173](file://lib/src/animation/animated_svg_picture_hit_test_geometry.dart#L150-L173)

### Advanced Path Stroke Containment
Sophisticated algorithms for determining stroke containment:

- **Metric-based sampling**: Samples path metrics at adaptive intervals based on path length
- **Tangent-based detection**: Uses path tangents to identify critical points
- **Segment distance calculation**: Computes distances to line segments for accurate stroke detection
- **Corner detection**: Identifies path corners for enhanced hit testing precision

**Section sources**
- [animated_svg_picture_hit_test_geometry.dart:150-173](file://lib/src/animation/animated_svg_picture_hit_test_geometry.dart#L150-L173)

## Anchor Element System and Link Handling

### SvgLinkInfo Structure
The SvgLinkInfo class encapsulates link information extracted from SVG anchor elements, providing a structured interface for onLinkTap callbacks.

```mermaid
classDiagram
class SvgLinkInfo {
+String href
+String target
+SvgLinkInfo(href, target)
}
class AnimatedSvgPicture {
+SvgLinkTapCallback? onLinkTap
+_handleTapDown(TapDownDetails)
}
class _AnimatedSvgPictureState {
+SvgLinkInfo? _hoveredAnchorInfo
+_hitTestWithAnchorInfo(Offset)
+_extractAnchorInfo(SvgNode)
}
SvgLinkInfo --> AnimatedSvgPicture : callback parameter
AnimatedSvgPicture --> _AnimatedSvgPictureState : manages
_AnimatedSvgPictureState --> SvgLinkInfo : creates
```

**Diagram sources**
- [animated_svg_picture.dart:96-110](file://lib/src/animation/animated_svg_picture.dart#L96-L110)
- [animated_svg_picture.dart:184-186](file://lib/src/animation/animated_svg_picture.dart#L184-L186)
- [animated_svg_picture.dart:199](file://lib/src/animation/animated_svg_picture.dart#L199)
- [animated_svg_picture_hit_test_traversal.dart:42-56](file://lib/src/animation/animated_svg_picture_hit_test_traversal.dart#L42-L56)

### Anchor Element Extraction and Processing
The anchor element system extracts link information from SVG anchor elements and maintains anchor context during hit testing traversal.

```mermaid
flowchart TD
StartAnchor(["Start _extractAnchorInfo"]) --> CheckTag{"tagName == 'a'?"}
CheckTag --> |No| ReturnNull["Return null"]
CheckTag --> |Yes| GetHref["Get href or xlink:href attribute"]
GetHref --> CheckHref{"Href exists and not empty?"}
CheckHref --> |No| ReturnNull
CheckHref --> |Yes| GetTarget["Get target attribute"]
GetTarget --> CreateInfo["Create SvgLinkInfo(href, target)"]
CreateInfo --> ReturnInfo["Return anchor info"]
```

**Diagram sources**
- [animated_svg_picture_hit_test_traversal.dart:42-56](file://lib/src/animation/animated_svg_picture_hit_test_traversal.dart#L42-L56)

### OnLinkTap Callback Implementation
The onLinkTap callback system provides a clean interface for handling user interactions with anchor elements, enabling navigation, analytics, or custom actions.

```mermaid
sequenceDiagram
participant User as "User"
participant Widget as "AnimatedSvgPicture"
participant State as "_AnimatedSvgPictureState"
participant Callback as "onLinkTap"
User->>Widget : "Tap on anchor element"
Widget->>State : "_handleTapDown(details)"
State->>State : "_hitTestWithAnchorInfo(position)"
State->>State : "Extract anchor info"
alt "Anchor with href"
State->>Callback : "onLinkTap(linkInfo)"
Callback-->>State : "Handle link action"
end
State->>State : "Clear active states"
```

**Diagram sources**
- [animated_svg_picture_events.dart:20-23](file://lib/src/animation/animated_svg_picture_events.dart#L20-L23)
- [animated_svg_picture.dart:184-186](file://lib/src/animation/animated_svg_picture.dart#L184-L186)

### Anchor Element Support Features
The anchor element system supports comprehensive SVG anchor functionality:

- **Multiple anchor types**: Works with rect, circle, ellipse, path, polygon, polyline, image, text, tspan, textPath, and foreignObject children
- **Nested anchor structures**: Supports anchors containing other anchors with proper context propagation
- **Use element references**: Handles anchors that reference definitions via use elements
- **XLink compatibility**: Supports both href and xlink:href attributes for backward compatibility
- **Target attribute support**: Passes target information (e.g., _blank, _self) to callbacks
- **Event integration**: Integrates with SMIL timeline events alongside link handling

**Section sources**
- [svg_anchor_element_test.dart:69-560](file://test/animation/svg_anchor_element_test.dart#L69-L560)
- [animated_svg_picture_hit_test_traversal.dart:42-56](file://lib/src/animation/animated_svg_picture_hit_test_traversal.dart#L42-L56)
- [animated_svg_picture_events.dart:20-23](file://lib/src/animation/animated_svg_picture_events.dart#L20-L23)

## Accessibility Integration with Semantics

### Semantics Wrapper Implementation
The AnimatedSvgPicture widget now automatically wraps SVG content with Flutter Semantics when accessibility information is present, providing comprehensive screen reader support.

```mermaid
flowchart TD
StartSem(["Start build method"]) --> CheckAccess["Check accessibleName/accessibleDescription"]
CheckAccess --> HasInfo{"Accessibility info present?"}
HasInfo --> |No| ReturnWidget["Return widget without Semantics"]
HasInfo --> |Yes| WrapSem["Wrap with Semantics widget"]
WrapSem --> SetProps["Set semantics properties"]
SetProps --> ReturnSem["Return wrapped widget"]
ReturnWidget --> End["End"]
ReturnSem --> End
```

**Diagram sources**
- [animated_svg_picture.dart:308-326](file://lib/src/animation/animated_svg_picture.dart#L308-L326)

### Accessibility Properties Extraction
The system extracts accessibility information from SVG elements and maps it to Flutter Semantics properties.

```mermaid
classDiagram
class SvgDocument {
+String? accessibleName
+String? accessibleDescription
+String accessibleRole
+SvgNode root
}
class SvgNode {
+String? titleText
+String? descText
+String? ariaLabel
+String? ariaDescribedby
+String? ariaRole
}
SvgDocument --> SvgNode : contains
```

**Diagram sources**
- [svg_dom.dart:491-503](file://lib/src/animation/svg_dom.dart#L491-L503)
- [svg_dom.dart:137-152](file://lib/src/animation/svg_dom.dart#L137-L152)

### Screen Reader Support Features
The accessibility integration provides comprehensive screen reader support:

- **Accessible name extraction**: Uses aria-label if present, otherwise falls back to title text
- **Accessible description extraction**: Uses aria-describedby if present, otherwise falls back to desc text  
- **ARIA role mapping**: Defaults to 'img' role, supports custom roles like 'button', 'link'
- **Semantics property mapping**: Maps to Flutter Semantics label, hint, image, button, link properties
- **Automatic wrapping**: Only wraps with Semantics when accessibility information is present
- **Role-based semantics**: Sets appropriate semantics based on extracted role information

**Section sources**
- [svg_accessibility_test.dart:281-449](file://test/animation/svg_accessibility_test.dart#L281-L449)
- [svg_dom.dart:491-503](file://lib/src/animation/svg_dom.dart#L491-L503)
- [animated_svg_picture.dart:308-326](file://lib/src/animation/animated_svg_picture.dart#L308-L326)

## Dependency Analysis
The interactive system composes several modules with clear separation of concerns, now enhanced with advanced geometric processing and comprehensive anchor element support:

```mermaid
graph LR
AP["animated_svg_picture.dart"] --> HT["hit_test_traversal.dart"]
AP --> PE["pointer_events.dart"]
AP --> HG["hit_test_geometry.dart"]
AP --> HTR["hit_test_text_runs.dart"]
AP --> HTL["hit_test_text_layout.dart"]
AP --> HTPS["hit_test_text_path_segments.dart"]
AP --> CG["painter_clip_mask_geometry.dart"]
AP --> MP["painter_clip_mask.dart"]
AP --> ST["utils.dart"]
AP --> EV["events.dart"]
AP --> PU["animated_svg_painter_use.dart"]
AP --> SD["svg_dom.dart"]
EV --> AP
PE --> HT
HG --> HT
HTR --> HT
HTL --> HTR
HTPS --> HTR
CG --> HT
MP --> HT
ST --> HG
ST --> HTR
SD --> HT
SD --> AP
```

**Diagram sources**
- [animated_svg_picture.dart:108-295](file://lib/src/animation/animated_svg_picture.dart#L108-L295)
- [animated_svg_picture_hit_test_traversal.dart:1-181](file://lib/src/animation/animated_svg_picture_hit_test_traversal.dart#L1-L181)
- [animated_svg_picture_pointer_events.dart:1-124](file://lib/src/animation/animated_svg_picture_pointer_events.dart#L1-L124)
- [animated_svg_picture_hit_test_geometry.dart:18-362](file://lib/src/animation/animated_svg_picture_hit_test_geometry.dart#L18-L362)
- [animated_svg_picture_hit_test_text_runs.dart:1-523](file://lib/src/animation/animated_svg_picture_hit_test_text_runs.dart#L1-L523)
- [animated_svg_picture_hit_test_text_layout.dart:1-252](file://lib/src/animation/animated_svg_picture_hit_test_text_layout.dart#L1-L252)
- [animated_svg_picture_hit_test_text_path_segments.dart:1-144](file://lib/src/animation/animated_svg_picture_hit_test_text_path_segments.dart#L1-L144)
- [animated_svg_painter_clip_mask_geometry.dart:1-175](file://lib/src/animation/animated_svg_painter_clip_mask_geometry.dart#L1-L175)
- [animated_svg_painter_clip_mask.dart:1-152](file://lib/src/animation/animated_svg_painter_clip_mask.dart#L1-L152)
- [animated_svg_picture_utils.dart:15-35](file://lib/src/animation/animated_svg_picture_utils.dart#L15-L35)
- [animated_svg_picture_events.dart:35-82](file://lib/src/animation/animated_svg_picture_events.dart#L35-L82)
- [animated_svg_painter_use.dart:87-150](file://lib/src/animation/animated_svg_painter_use.dart#L87-L150)
- [svg_dom.dart:393-524](file://lib/src/animation/svg_dom.dart#L393-L524)

**Section sources**
- [animated_svg_picture.dart:108-295](file://lib/src/animation/animated_svg_picture.dart#L108-L295)

## Performance Considerations
- Static subtree caching: Nodes without animations are cached as Picture objects and reused to avoid re-rendering.
- Dirty tracking: Only re-render subtrees whose animated attributes change.
- Path optimization: Paths are normalized once and reused; Path.reset is preferred over recreating objects.
- ViewBox transform: Efficiently converts local widget coordinates to document coordinates using a precomputed matrix.
- Gesture wrapping: Minimal overhead by wrapping only when animations are present or onLinkTap callback is provided.
- **Enhanced**: Advanced geometric processing uses optimized sampling algorithms and efficient path operations.
- **Enhanced**: Text hit testing employs per-character precision only when necessary, falling back to bounding box optimization for performance.
- **Enhanced**: Clip-path and mask processing uses geometric optimizations to minimize computational overhead.
- **New**: Anchor element processing adds minimal overhead with efficient anchor info extraction and caching.
- **New**: Accessibility integration only adds overhead when accessibility information is present.

**Section sources**
- [ARCHITECTURE.md:174-193](file://ARCHITECTURE.md#L174-L193)
- [animated_svg_picture.dart:35-86](file://lib/src/animation/animated_svg_picture.dart#L35-L86)

## Troubleshooting Guide
Common issues and resolutions:
- Clicks not registering:
  - Ensure pointer-events mode is not none and that the element is not visibility hidden.
  - Verify the click target is within the element's fill or stroke geometry as configured by pointer-events.
  - Confirm the element is not clipped or masked out.
- Hover effects not triggering:
  - Check that MouseRegion is wrapping the widget and that pointer-events modes allow visible or visiblepainted.
  - Ensure the element is not display:none or definition-only.
- Complex shapes not responding:
  - For stroke-only pointer-events, clicks near the stroke outline will trigger; for fill-only, clicks must be inside the filled area.
  - For bounding-box pointer-events, only the element's bounding rectangle counts.
- **Enhanced**: Text elements not responding to clicks:
  - Verify per-character hit testing is enabled for multi-position text elements.
  - Check that text positioning attributes (x, y, dx, dy, rotate) are properly configured.
  - Ensure textLength and lengthAdjust properties are compatible with per-character positioning.
- **Enhanced**: Clip-path and mask issues:
  - Verify clip-path and mask units are correctly set (objectBoundingBox vs userSpaceOnUse).
  - Check for proper use stack recursion limits and infinite loops.
  - Ensure mask alpha channels are properly calculated for visibility assessment.
- **Enhanced**: Stroke hit detection problems:
  - Adjust stroke-width values to ensure proper tolerance calculation.
  - Verify linecap settings for endpoint hit area inclusion.
  - Check path complexity and sampling thresholds for stroke detection.
- **New**: Anchor elements not triggering callbacks:
  - Ensure the anchor element has a valid href or xlink:href attribute.
  - Verify the onLinkTap callback is provided in the widget configuration.
  - Check that the tap occurs within an anchor element's child content.
  - Confirm the anchor element is not disabled by pointer-events or visibility constraints.
- **New**: Accessibility not working:
  - Ensure the SVG contains title, desc, aria-label, or aria-describedby elements.
  - Verify the widget is wrapped with Semantics when accessibility information is present.
  - Check that the extracted accessibility properties are not null or empty.

Validation and examples:
- Tests cover pointer-events none, child overrides, fill/stroke/bounding-box modes, and visibility-hidden behavior.
- Example widgets demonstrate interactive buttons and hover-triggered animations.
- **Enhanced**: Comprehensive text positioning and hit testing validation scenarios.
- **New**: Anchor element tests validate href extraction, target attribute handling, and callback execution.
- **New**: Accessibility tests verify semantics wrapping and property extraction.

**Section sources**
- [animated_svg_picture_test.dart:2090-2442](file://test/animation/animated_svg_picture_test.dart#L2090-L2442)
- [animated_svg_picture_pointer_events.dart:27-103](file://lib/src/animation/animated_svg_picture_pointer_events.dart#L27-L103)
- [animated_svg_painter_clip_mask_geometry.dart:4-91](file://lib/src/animation/animated_svg_painter_clip_mask_geometry.dart#L4-L91)
- [animated_svg_painter_clip_mask.dart:33-60](file://lib/src/animation/animated_svg_painter_clip_mask.dart#L33-L60)
- [animated_svg_picture_utils.dart:15-35](file://lib/src/animation/animated_svg_picture_utils.dart#L15-L35)
- [svg_anchor_element_test.dart:69-560](file://test/animation/svg_anchor_element_test.dart#L69-L560)
- [svg_accessibility_test.dart:281-449](file://test/animation/svg_accessibility_test.dart#L281-L449)

## Conclusion
The repository provides a robust, extensible system for interactive SVGs with significant enhancements:
- A precise hit test traversal that respects SVG's pointer-events model and visibility constraints.
- Integrated gesture handling that translates user input into SMIL-driven animations.
- **Enhanced**: Advanced per-character text hit testing with comprehensive positioning attribute support.
- **Enhanced**: Sophisticated clip-path and mask processing with geometric intersection calculations.
- **Enhanced**: Alpha-based visibility assessment for precise mask element evaluation.
- **Enhanced**: Sophisticated stroke-width expansion algorithms for improved hit detection accuracy.
- **New**: Comprehensive anchor element system with link handling capabilities and onLinkTap callbacks.
- **New**: Full accessibility integration with Flutter Semantics for screen reader support.
- Practical examples and tests validating click, hover, and chained event behaviors.
- Strong performance foundations leveraging caching, dirty tracking, and efficient transforms.

This enables developers to build animated interactive UI components such as buttons, clickable maps, and rich visual feedback systems with unprecedented precision, accessibility, and user experience.

## Appendices

### Best Practices for Responsive Interactive SVGs
- Define explicit pointer-events modes to control hit areas precisely.
- Prefer bounding-box for large clickable backgrounds; use fill or stroke for precise shapes.
- Keep hover and click targets visually distinct to improve UX.
- Use SMIL begin conditions (click, mouseover, mouseout) to orchestrate animations.
- Leverage viewBox transforms and sizing to maintain consistent hit testing across devices.
- **Enhanced**: Utilize per-character text hit testing for complex text interactions requiring precise character-level targeting.
- **Enhanced**: Implement appropriate clip-path and mask units based on design requirements and performance considerations.
- **Enhanced**: Configure stroke-width tolerances appropriately for different interaction scenarios and device densities.
- **New**: Use anchor elements for creating clickable regions within SVG graphics with proper accessibility support.
- **New**: Provide meaningful aria-label and desc attributes for screen reader accessibility.
- **New**: Implement onLinkTap callbacks for handling external navigation and custom link actions.
- **New**: Test accessibility features with screen readers and keyboard navigation for inclusive design.