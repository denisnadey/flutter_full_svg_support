# Advanced Animation Features

<cite>
**Referenced Files in This Document**
- [ANIMATION.md](file://ANIMATION.md)
- [ARCHITECTURE.md](file://ARCHITECTURE.md)
- [lib/src/animation.dart](file://lib/src/animation.dart)
- [lib/src/animation/animated_svg_picture.dart](file://lib/src/animation/animated_svg_picture.dart)
- [lib/src/animation/smil/smil_animation.dart](file://lib/src/animation/smil/smil_animation.dart)
- [lib/src/animation/smil/smil_timeline.dart](file://lib/src/animation/smil/smil_timeline.dart)
- [lib/src/animation/smil/interpolators.dart](file://lib/src/animation/smil/interpolators.dart)
- [lib/src/animation/path_interpolation.dart](file://lib/src/animation/path_interpolation.dart)
- [lib/src/animation/svg_filters_color_matrix.dart](file://lib/src/animation/svg_filters_color_matrix.dart)
- [lib/src/animation/svg_filters_primitives_lighting.dart](file://lib/src/animation/svg_filters_primitives_lighting.dart)
- [lib/src/animation/animated_svg_painter.dart](file://lib/src/animation/animated_svg_painter.dart)
- [lib/src/animation/animated_svg_painter_text_style.dart](file://lib/src/animation/animated_svg_painter_text_style.dart)
- [lib/src/animation/animated_svg_painter_text_paint.dart](file://lib/src/animation/animated_svg_painter_text_paint.dart)
- [example/lib/advanced_path_morphing.dart](file://example/lib/advanced_path_morphing.dart)
- [example/lib/path_morphing_example.dart](file://example/lib/path_morphing_example.dart)
- [test/animation/path_morphing_test.dart](file://test/animation/path_morphing_test.dart)
- [test/animation/font_variant_test.dart](file://test/animation/font_variant_test.dart)
- [test/animation/text_orientation_test.dart](file://test/animation/text_orientation_test.dart)
- [test/animation/text_underline_position_test.dart](file://test/animation/text_underline_position_test.dart)
- [test/animation/text_decoration_thickness_test.dart](file://test/animation/text_decoration_thickness_test.dart)
- [test/animation/text_decoration_style_test.dart](file://test/animation/text_decoration_style_test.dart)
- [test/animation/text_decoration_skip_test.dart](file://test/animation/text_decoration_skip_test.dart)
- [test/animation/text_decoration_skip_ink_test.dart](file://test/animation/text_decoration_skip_ink_test.dart)
</cite>

## Update Summary
**Changes Made**
- Added comprehensive text styling support section documenting new CSS text styling features
- Updated text rendering architecture to include advanced typography capabilities
- Added detailed coverage of underline, overline, line-through decorations
- Expanded writing-mode support for vertical text rendering
- Enhanced font variant and advanced typography features documentation
- Updated feature status to reflect complete text styling implementation

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [Text Styling and Typography Features](#text-styling-and-typography-features)
7. [Dependency Analysis](#dependency-analysis)
8. [Performance Considerations](#performance-considerations)
9. [Troubleshooting Guide](#troubleshooting-guide)
10. [Conclusion](#conclusion)
11. [Appendices](#appendices)

## Introduction
This document explains advanced animation features implemented in the codebase, focusing on:
- SVG filter animation support and runtime composition
- Color matrix transformations and blur effects
- Lighting primitives and their current baseline behavior
- Path morphing capabilities, shape interpolation, and motion animation techniques
- Advanced text styling and typography features including underline, overline, line-through, writing-mode, font variants, and advanced CSS text properties
- Advanced animation combinations, performance optimization strategies, and debugging approaches
- Known limitations, workarounds, and best practices

The implementation targets Flutter via a dedicated animated pipeline that preserves DOM structure and supports SMIL/CSS animations, plus a specialized path morphing and filter system with comprehensive text styling capabilities.

## Project Structure
The animation system is organized into:
- Public exports and entry points
- SMIL engine for time management, parsing, and interpolation
- Path morphing utilities for shape interpolation
- Filter runtime for color matrix, blur, and lighting primitives
- Advanced text styling and typography system with CSS property support
- Example apps and tests demonstrating advanced scenarios

```mermaid
graph TB
subgraph "Public API"
A["lib/src/animation.dart"]
end
subgraph "Animated Pipeline"
B["animated_svg_picture.dart"]
C["smil_animation.dart"]
D["smil_timeline.dart"]
E["interpolators.dart"]
end
subgraph "Path Morphing"
F["path_interpolation.dart"]
end
subgraph "Filters"
G["svg_filters_color_matrix.dart"]
H["svg_filters_primitives_lighting.dart"]
end
subgraph "Text Styling System"
I["animated_svg_painter_text_style.dart"]
J["animated_svg_painter_text_paint.dart"]
K["_ResolvedTextStyle"]
end
subgraph "Examples & Tests"
L["example/lib/path_morphing_example.dart"]
M["example/lib/advanced_path_morphing.dart"]
N["test/animation/path_morphing_test.dart"]
O["test/animation/font_variant_test.dart"]
P["test/animation/text_orientation_test.dart"]
Q["test/animation/text_underline_position_test.dart"]
R["test/animation/text_decoration_thickness_test.dart"]
S["test/animation/text_decoration_style_test.dart"]
T["test/animation/text_decoration_skip_test.dart"]
U["test/animation/text_decoration_skip_ink_test.dart"]
end
A --> B
B --> C
B --> D
C --> E
B --> F
B --> G
B --> H
B --> I
I --> J
I --> K
L --> F
M --> F
N --> F
O --> I
P --> I
Q --> I
R --> I
S --> I
T --> I
U --> I
```

**Diagram sources**
- [lib/src/animation.dart:1-31](file://lib/src/animation.dart#L1-L31)
- [lib/src/animation/animated_svg_picture.dart:1-359](file://lib/src/animation/animated_svg_picture.dart#L1-L359)
- [lib/src/animation/smil/smil_animation.dart:1-453](file://lib/src/animation/smil/smil_animation.dart#L1-L453)
- [lib/src/animation/smil/smil_timeline.dart:1-256](file://lib/src/animation/smil/smil_timeline.dart#L1-L256)
- [lib/src/animation/smil/interpolators.dart:1-148](file://lib/src/animation/smil/interpolators.dart#L1-L148)
- [lib/src/animation/path_interpolation.dart:1-96](file://lib/src/animation/path_interpolation.dart#L1-L96)
- [lib/src/animation/svg_filters_color_matrix.dart:1-202](file://lib/src/animation/svg_filters_color_matrix.dart#L1-L202)
- [lib/src/animation/svg_filters_primitives_lighting.dart:1-125](file://lib/src/animation/svg_filters_primitives_lighting.dart#L1-L125)
- [lib/src/animation/animated_svg_painter_text_style.dart:1-1046](file://lib/src/animation/animated_svg_painter_text_style.dart#L1-L1046)
- [lib/src/animation/animated_svg_painter_text_paint.dart:1-594](file://lib/src/animation/animated_svg_painter_text_paint.dart#L1-L594)
- [lib/src/animation/animated_svg_painter.dart:258-460](file://lib/src/animation/animated_svg_painter.dart#L258-L460)
- [example/lib/path_morphing_example.dart:1-198](file://example/lib/path_morphing_example.dart#L1-L198)
- [example/lib/advanced_path_morphing.dart:1-317](file://example/lib/advanced_path_morphing.dart#L1-L317)
- [test/animation/path_morphing_test.dart:1-431](file://test/animation/path_morphing_test.dart#L1-L431)
- [test/animation/font_variant_test.dart:1-196](file://test/animation/font_variant_test.dart#L1-L196)
- [test/animation/text_orientation_test.dart:1-85](file://test/animation/text_orientation_test.dart#L1-L85)
- [test/animation/text_underline_position_test.dart:1-100](file://test/animation/text_underline_position_test.dart#L1-L100)
- [test/animation/text_decoration_thickness_test.dart:1-100](file://test/animation/text_decoration_thickness_test.dart#L1-L100)
- [test/animation/text_decoration_style_test.dart:1-87](file://test/animation/text_decoration_style_test.dart#L1-L87)
- [test/animation/text_decoration_skip_test.dart:1-87](file://test/animation/text_decoration_skip_test.dart#L1-L87)
- [test/animation/text_decoration_skip_ink_test.dart:1-87](file://test/animation/text_decoration_skip_ink_test.dart#L1-L87)

**Section sources**
- [lib/src/animation.dart:1-31](file://lib/src/animation.dart#L1-L31)
- [ARCHITECTURE.md:236-281](file://ARCHITECTURE.md#L236-L281)

## Core Components
- AnimatedSvgPicture: Widget that parses SVG, extracts SMIL animations, manages timelines, and renders via CustomPainter.
- SmilAnimation: Encapsulates SMIL animation semantics (timing, calcMode, values/keyTimes, additive/accumulate).
- SvgTimeline: Manages global time, playback rate, begin/end conditions, and event-driven activation.
- Interpolators: Provides typed interpolation for numbers, colors, transforms, paths, and lists.
- PathInterpolator: Smoothly interpolates between normalized SVG path command sequences.
- Filter runtime: Supports color matrix, blur, and lighting primitives with baseline behavior.
- Text styling system: Comprehensive CSS text property support including underline, overline, line-through, writing-mode, font variants, and advanced typography features.

**Section sources**
- [lib/src/animation/animated_svg_picture.dart:108-359](file://lib/src/animation/animated_svg_picture.dart#L108-L359)
- [lib/src/animation/smil/smil_animation.dart:80-453](file://lib/src/animation/smil/smil_animation.dart#L80-L453)
- [lib/src/animation/smil/smil_timeline.dart:21-256](file://lib/src/animation/smil/smil_timeline.dart#L21-L256)
- [lib/src/animation/smil/interpolators.dart:14-148](file://lib/src/animation/smil/interpolators.dart#L14-L148)
- [lib/src/animation/path_interpolation.dart:15-96](file://lib/src/animation/path_interpolation.dart#L15-L96)
- [lib/src/animation/svg_filters_color_matrix.dart:56-202](file://lib/src/animation/svg_filters_color_matrix.dart#L56-L202)
- [lib/src/animation/svg_filters_primitives_lighting.dart:52-125](file://lib/src/animation/svg_filters_primitives_lighting.dart#L52-L125)
- [lib/src/animation/animated_svg_painter_text_style.dart:1-1046](file://lib/src/animation/animated_svg_painter_text_style.dart#L1-L1046)

## Architecture Overview
The animated pipeline separates concerns across parsing, animation extraction, timeline management, and rendering. It preserves DOM for SMIL support and provides a CustomPainter-based renderer with comprehensive text styling capabilities.

```mermaid
sequenceDiagram
participant App as "Flutter App"
participant Picture as "AnimatedSvgPicture"
participant Parser as "SvgParser"
participant Timeline as "SvgTimeline"
participant Anim as "SmilAnimation"
participant TextStyle as "TextStyleResolver"
participant TextPaint as "TextPainter"
participant Interp as "Interpolators"
participant Renderer as "AnimatedSvgPainter"
App->>Picture : Build widget
Picture->>Parser : Parse SVG to DOM
Parser-->>Picture : SvgDocument
Picture->>Timeline : Initialize with animations
Picture->>TextStyle : Resolve text styles
TextStyle-->>Picture : _ResolvedTextStyle
loop Every frame
Picture->>Timeline : tick(delta)
Timeline->>Anim : updateForTime(globalTime)
Anim->>Interp : interpolate(...)
Interp-->>Anim : computed value
Anim-->>Timeline : apply value to attribute
Timeline-->>Renderer : Effective values
Renderer->>TextPaint : Render styled text
TextPaint-->>Renderer : Drawn text
Renderer-->>App : Draw Canvas
end
```

**Diagram sources**
- [lib/src/animation/animated_svg_picture.dart:166-295](file://lib/src/animation/animated_svg_picture.dart#L166-L295)
- [lib/src/animation/smil/smil_timeline.dart:79-98](file://lib/src/animation/smil/smil_timeline.dart#L79-L98)
- [lib/src/animation/smil/smil_animation.dart:367-431](file://lib/src/animation/smil/smil_animation.dart#L367-L431)
- [lib/src/animation/smil/interpolators.dart:18-42](file://lib/src/animation/smil/interpolators.dart#L18-L42)
- [lib/src/animation/animated_svg_painter_text_style.dart:4-171](file://lib/src/animation/animated_svg_painter_text_style.dart#L4-L171)
- [lib/src/animation/animated_svg_painter_text_paint.dart:407-456](file://lib/src/animation/animated_svg_painter_text_paint.dart#L407-L456)

**Section sources**
- [ARCHITECTURE.md:146-193](file://ARCHITECTURE.md#L146-L193)

## Detailed Component Analysis

### SMIL Animation Engine
- Types: animate, animateTransform, animateMotion, set, animateColor
- Timing: begin, end, dur, repeatCount/repeatDur, fill modes
- Interpolation: calcMode (linear, discrete, spline, paced), keySplines/steps
- Playback direction and additive/accumulate semantics
- Event-based activation and syncbase timing resolution

```mermaid
classDiagram
class SmilAnimation {
+id
+type
+targetNode
+attributeName
+attributeType
+transformType
+from
+to
+by
+values
+keyTimes
+keySplines
+keySteps
+dur
+begin
+end
+repeatCount
+repeatDur
+fillMode
+calcMode
+playbackDirection
+additive
+accumulate
+beginConditions
+endConditions
+isActive
+currentIteration
+localTime
+computeValue(t)
+updateForTime(time)
+reset()
}
class SvgTimeline {
+animations
+rootNode
+currentTime
+totalDuration
+playbackRate
+tick(delta)
+seek(time)
+reset()
+triggerEvent(elementId,eventType)
+getActiveAnimations()
+hasActiveAnimations()
}
SvgTimeline --> SmilAnimation : "updates"
```

**Diagram sources**
- [lib/src/animation/smil/smil_animation.dart:80-453](file://lib/src/animation/smil/smil_animation.dart#L80-L453)
- [lib/src/animation/smil/smil_timeline.dart:21-256](file://lib/src/animation/smil/smil_timeline.dart#L21-L256)

**Section sources**
- [lib/src/animation/smil/smil_animation.dart:13-77](file://lib/src/animation/smil/smil_animation.dart#L13-L77)
- [lib/src/animation/smil/smil_timeline.dart:13-61](file://lib/src/animation/smil/smil_timeline.dart#L13-L61)

### Interpolation System
- Numbers, colors, transforms, paths, points/lists
- Additive arithmetic for numbers and lists
- Path interpolation via normalized cubic Beziers

```mermaid
flowchart TD
Start(["Interpolate"]) --> Type{"Attribute Type?"}
Type --> |Number| Num["interpolateNumber"]
Type --> |Color| Col["interpolateColor"]
Type --> |Transform| Tr["interpolateTransform"]
Type --> |Path| Path["interpolatePath"]
Type --> |Points/List| List["interpolateList"]
Num --> Out["Return value"]
Col --> Out
Tr --> Out
Path --> Out
List --> Out
```

**Diagram sources**
- [lib/src/animation/smil/interpolators.dart:18-146](file://lib/src/animation/smil/interpolators.dart#L18-L146)

**Section sources**
- [lib/src/animation/smil/interpolators.dart:14-148](file://lib/src/animation/smil/interpolators.dart#L14-L148)

### Path Morphing
- Normalization converts paths to equivalent cubic Bezier sequences
- Interpolator blends normalized command lists
- Example apps demonstrate shape transitions and real-time sliders

```mermaid
sequenceDiagram
participant Demo as "Demo App"
participant Parser as "PathParser"
participant Normalizer as "PathNormalizer"
participant Morph as "PathMorpher"
participant Interp as "PathInterpolator"
Demo->>Parser : parse(fromPath)
Demo->>Parser : parse(toPath)
Parser-->>Demo : fromCmds, toCmds
Demo->>Normalizer : normalize(fromCmds,toCmds)
Normalizer-->>Demo : normalized{from,to}
Demo->>Morph : construct with normalized commands
loop Animation
Demo->>Morph : getPathAt(t)
Morph->>Interp : interpolate(from,to,t)
Interp-->>Morph : Path
Morph-->>Demo : Path
end
```

**Diagram sources**
- [example/lib/path_morphing_example.dart:48-67](file://example/lib/path_morphing_example.dart#L48-L67)
- [example/lib/advanced_path_morphing.dart:94-108](file://example/lib/advanced_path_morphing.dart#L94-L108)
- [lib/src/animation/path_interpolation.dart:26-65](file://lib/src/animation/path_interpolation.dart#L26-L65)

**Section sources**
- [lib/src/animation/path_interpolation.dart:15-96](file://lib/src/animation/path_interpolation.dart#L15-L96)
- [example/lib/path_morphing_example.dart:27-168](file://example/lib/path_morphing_example.dart#L27-L168)
- [example/lib/advanced_path_morphing.dart:68-283](file://example/lib/advanced_path_morphing.dart#L68-L283)
- [test/animation/path_morphing_test.dart:1-431](file://test/animation/path_morphing_test.dart#L1-L431)

### Filter Runtime and Effects
- Color Matrix: matrix, saturate, hueRotate, luminanceToAlpha
- Blur: Gaussian blur via ImageFilter
- Lighting: Diffuse/specular primitives store parameters; baseline behavior acts as pass-through

```mermaid
classDiagram
class SvgColorMatrixFilter {
+matrixType
+values
+apply() ImageFilter?
}
class SvgDropShadowFilter {
+dx
+dy
+stdDeviationX
+stdDeviationY
+floodColor
+floodOpacity
+offset
+effectiveShadowColor
+stdDeviation
+apply() ImageFilter?
}
class SvgDiffuseLightingFilter {
+surfaceScale
+diffuseConstant
+kernelUnitLengthX
+kernelUnitLengthY
+lightingColor
+lightSource
+apply() ImageFilter?
}
class SvgSpecularLightingFilter {
+surfaceScale
+specularConstant
+specularExponent
+kernelUnitLengthX
+kernelUnitLengthY
+lightingColor
+lightSource
+apply() ImageFilter?
}
SvgColorMatrixFilter --> SvgFilter : "extends"
SvgDropShadowFilter --> SvgFilter : "extends"
SvgDiffuseLightingFilter --> SvgFilter : "extends"
SvgSpecularLightingFilter --> SvgFilter : "extends"
```

**Diagram sources**
- [lib/src/animation/svg_filters_color_matrix.dart:56-202](file://lib/src/animation/svg_filters_color_matrix.dart#L56-L202)
- [lib/src/animation/svg_filters_primitives_lighting.dart:52-125](file://lib/src/animation/svg_filters_primitives_lighting.dart#L52-L125)

**Section sources**
- [lib/src/animation/svg_filters_color_matrix.dart:56-202](file://lib/src/animation/svg_filters_color_matrix.dart#L56-L202)
- [lib/src/animation/svg_filters_primitives_lighting.dart:52-125](file://lib/src/animation/svg_filters_primitives_lighting.dart#L52-L125)

### Motion Animation Techniques
- animateMotion: path-based movement with optional rotate modes
- KeyPoints and keyTimes enable variable-speed motion along paths
- Integration with SMIL timeline and transform interpolation

```mermaid
sequenceDiagram
participant Timeline as "SvgTimeline"
participant Anim as "SmilAnimation(animateMotion)"
participant Interp as "Interpolators"
participant Renderer as "AnimatedSvgPainter"
Timeline->>Anim : updateForTime(time)
Anim->>Anim : _computeMotionValue(t)
Anim->>Interp : interpolateTransform(from,to,t)
Interp-->>Anim : transform
Anim-->>Renderer : transform applied
```

**Diagram sources**
- [lib/src/animation/smil/smil_animation.dart:320-365](file://lib/src/animation/smil/smil_animation.dart#L320-L365)
- [lib/src/animation/smil/interpolators.dart:113-116](file://lib/src/animation/smil/interpolators.dart#L113-L116)

**Section sources**
- [lib/src/animation/smil/smil_animation.dart:320-365](file://lib/src/animation/smil/smil_animation.dart#L320-L365)

## Text Styling and Typography Features

### Comprehensive CSS Text Property Support
The text styling system provides extensive CSS text property support with comprehensive resolution and application capabilities:

#### Core Text Properties
- **Text Decoration**: Underline, overline, and line-through with individual control
- **Writing Mode**: Horizontal and vertical text rendering support
- **Font Variants**: Advanced font feature support including small-caps, titling-caps, and numeric variants
- **Typography Control**: Letter spacing, word spacing, text indentation, and alignment
- **Text Transformation**: Capitalization, uppercase, lowercase, and full-width support
- **Line Breaking**: Advanced line breaking and overflow wrapping control
- **Hyphenation**: Automatic and manual hyphenation support
- **Text Orientation**: Mixed, upright, and sideways text orientation for vertical writing

#### Text Decoration System
The system implements a comprehensive text decoration framework supporting:

```mermaid
classDiagram
class _SvgTextDecoration {
<<enumeration>>
+underline
+overline
+lineThrough
}
class _ResolvedTextStyle {
+color : ui.Color
+fontSize : double
+fontFamily : String?
+fontWeight : ui.FontWeight
+fontStyle : ui.FontStyle
+textAnchor : _SvgTextAnchor
+dominantBaseline : _SvgDominantBaseline
+baselineShift : double
+letterSpacing : double
+wordSpacing : double
+decorations : Set~_SvgTextDecoration~
+decorationColor : ui.Color?
+writingMode : _SvgWritingMode
+fontFeatures : ui.FontFeature[]
+textDirection : ui.TextDirection
+glyphOrientationVertical : double?
+unicodeBidi : String?
+fontStretch : double
+fontSizeAdjust : double?
+tabSize : int
+textIndent : double
+wordBreak : String
+overflowWrap : String
+textTransform : String
+hyphens : String
+lineBreak : String
+hangingPunctuation : String
+textCombineUpright : String
+textOrientation : String
+textUnderlinePosition : String
+textUnderlineOffset : double?
+textDecorationThickness : double?
+textDecorationSkipInk : String
+textDecorationSkip : String
+textDecorationStyle : String
}
```

**Diagram sources**
- [lib/src/animation/animated_svg_painter.dart:193-197](file://lib/src/animation/animated_svg_painter.dart#L193-L197)
- [lib/src/animation/animated_svg_painter.dart:258-460](file://lib/src/animation/animated_svg_painter.dart#L258-L460)

#### Advanced Typography Features
- **Font Variant Resolution**: Converts CSS font-variant properties to Flutter FontFeatures
  - Small-caps variants: `small-caps`, `all-small-caps`, `petite-caps`, `all-petite-caps`
  - Stylistic sets: `unicase`, `titling-caps`
  - Numeric formatting: `oldstyle-nums`, `lining-nums`, `tabular-nums`, `proportional-nums`
- **Writing Mode Support**: Comprehensive vertical text rendering with proper glyph orientation
- **Text Decoration Thickness**: Support for custom decoration line thickness with unit handling
- **Text Underline Position**: Advanced underline positioning including multi-value combinations
- **Text Decoration Styles**: Solid, double, dotted, dashed, and wavy decoration line styles
- **Text Decoration Skip**: Control over what elements decorations skip over (objects, spaces, edges)
- **Text Decoration Skip Ink**: Intelligent handling of decorations around glyph ascenders and descenders

#### Text Rendering Architecture
The text rendering system consists of three main components:

```mermaid
sequenceDiagram
participant Node as "SVG Text Node"
participant Resolver as "TextStyleResolver"
participant Builder as "TextBuilder"
participant Painter as "TextPainter"
Node->>Resolver : _resolveTextStyle()
Resolver->>Resolver : Parse CSS properties
Resolver->>Resolver : Convert to Flutter types
Resolver-->>Builder : _ResolvedTextStyle
Builder->>Builder : Create ParagraphBuilder
Builder->>Painter : Build and render
Painter-->>Node : Rendered text
```

**Diagram sources**
- [lib/src/animation/animated_svg_painter_text_style.dart:4-171](file://lib/src/animation/animated_svg_painter_text_style.dart#L4-L171)
- [lib/src/animation/animated_svg_painter_text_style.dart:769-798](file://lib/src/animation/animated_svg_painter_text_style.dart#L769-L798)
- [lib/src/animation/animated_svg_painter_text_paint.dart:407-456](file://lib/src/animation/animated_svg_painter_text_paint.dart#L407-L456)

**Section sources**
- [lib/src/animation/animated_svg_painter_text_style.dart:1-1046](file://lib/src/animation/animated_svg_painter_text_style.dart#L1-L1046)
- [lib/src/animation/animated_svg_painter_text_paint.dart:400-594](file://lib/src/animation/animated_svg_painter_text_paint.dart#L400-L594)
- [lib/src/animation/animated_svg_painter.dart:193-460](file://lib/src/animation/animated_svg_painter.dart#L193-L460)

## Dependency Analysis
- AnimatedSvgPicture depends on SvgParser, SmilParser, SvgTimeline, and AnimatedSvgPainter
- SmilAnimation relies on Interpolators and DistanceCalculator for paced mode
- Path morphing depends on PathParser, PathNormalizer, and PathInterpolator
- Filters depend on Flutter's ui.ImageFilter and color matrices
- Text styling system depends on Flutter's ui.TextDirection, ui.FontFeature, and ui.ParagraphBuilder

```mermaid
graph LR
Picture["AnimatedSvgPicture"] --> Parser["SvgParser"]
Picture --> Timeline["SvgTimeline"]
Timeline --> Anim["SmilAnimation"]
Anim --> Interp["Interpolators"]
Picture --> Morph["PathMorpher"]
Morph --> InterpPath["PathInterpolator"]
Picture --> Filters["Filter Runtime"]
Filters --> CM["ColorMatrix"]
Filters --> Blur["Blur"]
Filters --> Light["Lighting Primitives"]
Picture --> TextStyle["TextStyleResolver"]
TextStyle --> TextPaint["TextPainter"]
TextStyle --> ResolvedStyle["_ResolvedTextStyle"]
```

**Diagram sources**
- [lib/src/animation/animated_svg_picture.dart:1-359](file://lib/src/animation/animated_svg_picture.dart#L1-L359)
- [lib/src/animation/smil/smil_animation.dart:1-453](file://lib/src/animation/smil/smil_animation.dart#L1-L453)
- [lib/src/animation/smil/interpolators.dart:1-148](file://lib/src/animation/smil/interpolators.dart#L1-L148)
- [lib/src/animation/path_interpolation.dart:1-96](file://lib/src/animation/path_interpolation.dart#L1-L96)
- [lib/src/animation/svg_filters_color_matrix.dart:1-202](file://lib/src/animation/svg_filters_color_matrix.dart#L1-L202)
- [lib/src/animation/svg_filters_primitives_lighting.dart:1-125](file://lib/src/animation/svg_filters_primitives_lighting.dart#L1-L125)
- [lib/src/animation/animated_svg_painter_text_style.dart:1-1046](file://lib/src/animation/animated_svg_painter_text_style.dart#L1-L1046)
- [lib/src/animation/animated_svg_painter_text_paint.dart:1-594](file://lib/src/animation/animated_svg_painter_text_paint.dart#L1-L594)
- [lib/src/animation/animated_svg_painter.dart:258-460](file://lib/src/animation/animated_svg_painter.dart#L258-L460)

**Section sources**
- [ARCHITECTURE.md:236-281](file://ARCHITECTURE.md#L236-L281)

## Performance Considerations
- Static subtree caching: reuse Picture for nodes without animations
- Dirty tracking: render only changed subtrees
- Path optimization: normalize once, reuse Path objects, reset instead of recreate
- Text styling optimization: cache resolved styles, reuse Paragraph objects
- Future optimizations: layer caching, GPU-accelerated morphing, reduced allocations

Practical tips:
- Prefer normalized paths for repeated morphing to avoid repeated normalization
- Use additive/accumulate judiciously; they increase computation per iteration
- Limit simultaneous complex animations on the same subtree
- Use playbackRate to throttle expensive scenes
- Cache frequently used text styles to avoid repeated CSS parsing

**Section sources**
- [ARCHITECTURE.md:174-193](file://ARCHITECTURE.md#L174-L193)

## Troubleshooting Guide
Common issues and resolutions:
- Path morphing fails due to incompatible structures
  - Ensure paths are normalized prior to interpolation
  - Verify equal-length normalized command lists
- Invalid SMIL timing or values
  - Confirm keyTimes length matches values for spline/discrete modes
  - For paced mode, ensure values are interpolable; otherwise fallback occurs
- Event-based animations not triggering
  - Verify event keys and element IDs
  - Check resolved begin times and syncbase conditions
- Filter effects not visible
  - Some lighting primitives act as pass-through until full shading is implemented
  - Confirm color matrix dimensions and values validity
- Text styling issues
  - Verify CSS property syntax and supported values
  - Check font feature availability in the selected font
  - Ensure proper inheritance from parent elements
  - Validate unit conversions for text-decoration-thickness and similar properties

Diagnostic utilities:
- AnimatedSvgPicture exposes trace callbacks and frame tick logging for detailed runtime insights
- Use test suites to validate normalization and interpolation correctness
- Text styling tests provide comprehensive coverage of CSS property implementations

**Section sources**
- [lib/src/animation/animated_svg_picture.dart:52-86](file://lib/src/animation/animated_svg_picture.dart#L52-L86)
- [lib/src/animation/smil/smil_animation.dart:110-130](file://lib/src/animation/smil/smil_animation.dart#L110-L130)
- [test/animation/path_morphing_test.dart:136-184](file://test/animation/path_morphing_test.dart#L136-L184)
- [test/animation/font_variant_test.dart:1-196](file://test/animation/font_variant_test.dart#L1-L196)
- [test/animation/text_orientation_test.dart:1-85](file://test/animation/text_orientation_test.dart#L1-L85)

## Conclusion
The codebase delivers a robust animated SVG pipeline with:
- Full SMIL/CSS animation support and precise timing
- Advanced interpolation for numbers, colors, transforms, paths, and lists
- Practical path morphing with normalization and morphers
- Filter runtime covering color matrix, blur, and lighting primitives
- Comprehensive text styling system with extensive CSS property support
- Advanced typography features including underline, overline, line-through, writing-mode, font variants, and text decoration controls
- Strong performance strategies and extensible architecture

Adopt the examples and tests as references for building complex, performant animations while adhering to normalization and interpolation constraints. The enhanced text styling capabilities provide professional-grade typography support for international text rendering and advanced text effects.

## Appendices

### Feature Summary and Status
- SMIL elements: animate, animateTransform, animateMotion, set, animateColor
- CSS animations: parsing and conversion to SMIL with timing and direction
- Path morphing: normalized cubic Bezier interpolation
- Filters: color matrix, blur, lighting primitives (baseline pass-through)
- Text styling: comprehensive CSS text property support including underline, overline, line-through, writing-mode, font variants, and advanced typography features

**Section sources**
- [ANIMATION.md:21-66](file://ANIMATION.md#L21-L66)
- [lib/src/animation/animated_svg_painter_text_style.dart:1-1046](file://lib/src/animation/animated_svg_painter_text_style.dart#L1-L1046)
- [lib/src/animation/animated_svg_painter_text_paint.dart:400-594](file://lib/src/animation/animated_svg_painter_text_paint.dart#L400-L594)
- [lib/src/animation/animated_svg_painter.dart:193-460](file://lib/src/animation/animated_svg_painter.dart#L193-L460)