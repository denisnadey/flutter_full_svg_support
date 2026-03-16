# Path Morphing and Shape Interpolation

<cite>
**Referenced Files in This Document**
- [svg.dart](file://lib/svg.dart)
- [path_interpolation.dart](file://lib/src/animation/path_interpolation.dart)
- [path_interpolation_morpher.dart](file://lib/src/animation/path_interpolation_morpher.dart)
- [path_normalizer.dart](file://lib/src/animation/path_normalizer.dart)
- [path_normalizer_alignment.dart](file://lib/src/animation/path_normalizer_alignment.dart)
- [path_normalizer_curves.dart](file://lib/src/animation/path_normalizer_curves.dart)
- [path_data.dart](file://lib/src/animation/path_data.dart)
- [path_data_base.dart](file://lib/src/animation/path_data_base.dart)
- [path_data_curves.dart](file://lib/src/animation/path_data_curves.dart)
- [animated_svg_picture_paths.dart](file://lib/src/animation/animated_svg_picture_paths.dart)
- [animated_svg_picture_path_parser.dart](file://lib/src/animation/animated_svg_picture_path_parser.dart)
- [animated_svg_painter_shapes_paths.dart](file://lib/src/animation/animated_svg_painter_shapes_paths.dart)
- [path_morphing_example.dart](file://example/lib/path_morphing_example.dart)
- [advanced_path_morphing.dart](file://example/lib/advanced_path_morphing.dart)
- [path_morphing_page.dart](file://example/lib/pages/path_morphing_page.dart)
- [path_morphing_widget.dart](file://example/lib/widgets/path_morphing_widget.dart)
- [smil_path_morphing_widget.dart](file://example/lib/widgets/smil_path_morphing_widget.dart)
- [path_morphing_test.dart](file://test/animation/path_morphing_test.dart)
- [path_morphing_correctness_test.dart](file://test/animation/path_morphing_correctness_test.dart)
- [smil_path_morphing_integration_test.dart](file://test/animation/smil_path_morphing_integration_test.dart)
</cite>

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
This document explains the path morphing and shape interpolation capabilities implemented in the project. It covers the path data model, SVG path parsing pipeline, normalization and alignment strategies, curve interpolation techniques, and the animation pipeline that produces smooth transitions between arbitrary SVG shapes. Practical guidance is provided for creating fluid animations, optimizing interpolation calculations, and understanding the mathematical foundations and limitations of the morphing system.

## Project Structure
The path morphing system is primarily implemented under the animation module. Key areas include:
- Path data representation and command abstractions
- Path normalization and alignment
- Curve conversion utilities
- Interpolation engine and morpher helpers
- Example widgets and tests demonstrating morphing

```mermaid
graph TB
subgraph "Animation Core"
PD["path_data.dart<br/>Base and Curve Commands"]
PN["path_normalizer.dart<br/>Normalization & Alignment"]
PI["path_interpolation.dart<br/>Interpolator & Helpers"]
PM["path_interpolation_morpher.dart<br/>PathMorpher & Extensions"]
end
subgraph "Parsing & Rendering"
PPAR["animated_svg_picture_path_parser.dart<br/>SVG Path Parser"]
PPATH["animated_svg_picture_paths.dart<br/>Path Utilities"]
PAINT["animated_svg_painter_shapes_paths.dart<br/>Painter Shapes Paths"]
end
subgraph "Examples"
EX1["path_morphing_example.dart"]
EX2["advanced_path_morphing.dart"]
PAGE["path_morphing_page.dart"]
W1["path_morphing_widget.dart"]
W2["smil_path_morphing_widget.dart"]
end
PD --> PN
PN --> PI
PI --> PM
PPAR --> PN
PPATH --> PI
PAINT --> PI
EX1 --> PM
EX2 --> PM
PAGE --> W1
PAGE --> W2
```

**Diagram sources**
- [path_data.dart:1-9](file://lib/src/animation/path_data.dart#L1-L9)
- [path_normalizer.dart:1-56](file://lib/src/animation/path_normalizer.dart#L1-L56)
- [path_interpolation.dart:1-96](file://lib/src/animation/path_interpolation.dart#L1-L96)
- [path_interpolation_morpher.dart:1-53](file://lib/src/animation/path_interpolation_morpher.dart#L1-L53)
- [animated_svg_picture_path_parser.dart](file://lib/src/animation/animated_svg_picture_path_parser.dart)
- [animated_svg_picture_paths.dart](file://lib/src/animation/animated_svg_picture_paths.dart)
- [animated_svg_painter_shapes_paths.dart](file://lib/src/animation/animated_svg_painter_shapes_paths.dart)
- [path_morphing_example.dart](file://example/lib/path_morphing_example.dart)
- [advanced_path_morphing.dart](file://example/lib/advanced_path_morphing.dart)
- [path_morphing_page.dart](file://example/lib/pages/path_morphing_page.dart)
- [path_morphing_widget.dart](file://example/lib/widgets/path_morphing_widget.dart)
- [smil_path_morphing_widget.dart](file://example/lib/widgets/smil_path_morphing_widget.dart)

**Section sources**
- [path_data.dart:1-9](file://lib/src/animation/path_data.dart#L1-L9)
- [path_normalizer.dart:1-56](file://lib/src/animation/path_normalizer.dart#L1-L56)
- [path_interpolation.dart:1-96](file://lib/src/animation/path_interpolation.dart#L1-L96)
- [path_interpolation_morpher.dart:1-53](file://lib/src/animation/path_interpolation_morpher.dart#L1-L53)
- [animated_svg_picture_path_parser.dart](file://lib/src/animation/animated_svg_picture_path_parser.dart)
- [animated_svg_picture_paths.dart](file://lib/src/animation/animated_svg_picture_paths.dart)
- [animated_svg_painter_shapes_paths.dart](file://lib/src/animation/animated_svg_painter_shapes_paths.dart)
- [path_morphing_example.dart](file://example/lib/path_morphing_example.dart)
- [advanced_path_morphing.dart](file://example/lib/advanced_path_morphing.dart)
- [path_morphing_page.dart](file://example/lib/pages/path_morphing_page.dart)
- [path_morphing_widget.dart](file://example/lib/widgets/path_morphing_widget.dart)
- [smil_path_morphing_widget.dart](file://example/lib/widgets/smil_path_morphing_widget.dart)

## Core Components
- PathCommand hierarchy: Base abstraction for SVG path commands (MoveTo, LineTo, Cubic/Quadratic Bezier, Arc, ClosePath) with absolute/relative support and parameter extraction.
- PathNormalizer: Converts paths to absolute coordinates, expands curves to cubic Beziers, and aligns command counts via padding with degenerate curves.
- PathInterpolator: Performs per-command interpolation between normalized paths, supporting MoveTo and CubicBezier with strict type matching.
- PathMorpher: A convenience wrapper that caches normalized commands and exposes time-based path retrieval.
- Examples and tests: Demonstrate morphing between shapes, integration with SMIL-style animations, and correctness validation.

**Section sources**
- [path_data_base.dart:1-281](file://lib/src/animation/path_data_base.dart#L1-L281)
- [path_data_curves.dart:1-285](file://lib/src/animation/path_data_curves.dart#L1-L285)
- [path_normalizer.dart:1-56](file://lib/src/animation/path_normalizer.dart#L1-L56)
- [path_normalizer_alignment.dart:1-68](file://lib/src/animation/path_normalizer_alignment.dart#L1-L68)
- [path_normalizer_curves.dart:1-156](file://lib/src/animation/path_normalizer_curves.dart#L1-L156)
- [path_interpolation.dart:1-96](file://lib/src/animation/path_interpolation.dart#L1-L96)
- [path_interpolation_morpher.dart:1-53](file://lib/src/animation/path_interpolation_morpher.dart#L1-L53)
- [path_morphing_example.dart](file://example/lib/path_morphing_example.dart)
- [advanced_path_morphing.dart](file://example/lib/advanced_path_morphing.dart)
- [path_morphing_test.dart](file://test/animation/path_morphing_test.dart)
- [path_morphing_correctness_test.dart](file://test/animation/path_morphing_correctness_test.dart)

## Architecture Overview
The morphing pipeline follows a clear separation of concerns:
- Parsing: Extracts raw SVG path data into structured PathCommand lists.
- Normalization: Ensures both paths share the same command types and lengths.
- Interpolation: Computes intermediate paths at time t by interpolating corresponding commands.
- Rendering: Produces Flutter Path objects suitable for painting and animation.

```mermaid
sequenceDiagram
participant User as "User Code"
participant Parser as "SVG Path Parser"
participant Normalizer as "PathNormalizer"
participant Interp as "PathInterpolator"
participant Morph as "PathMorpher"
User->>Parser : "parse(fromPathData)"
Parser-->>User : "List<PathCommand>"
User->>Parser : "parse(toPathData)"
Parser-->>User : "List<PathCommand>"
User->>Normalizer : "normalize(from, to)"
Normalizer-->>User : "NormalizedPathPair"
User->>Morph : "new PathMorpher(from, to)"
loop "for each frame"
User->>Morph : "getPathAt(t)"
Morph->>Interp : "interpolate(from, to, t)"
Interp-->>Morph : "Path"
Morph-->>User : "Path"
end
```

**Diagram sources**
- [animated_svg_picture_path_parser.dart](file://lib/src/animation/animated_svg_picture_path_parser.dart)
- [path_normalizer.dart:41-54](file://lib/src/animation/path_normalizer.dart#L41-L54)
- [path_interpolation.dart:26-65](file://lib/src/animation/path_interpolation.dart#L26-L65)
- [path_interpolation_morpher.dart:24-38](file://lib/src/animation/path_interpolation_morpher.dart#L24-L38)

## Detailed Component Analysis

### Path Data Model
The path data model defines a unified command abstraction for SVG path segments. Each command exposes:
- Type identifier (uppercase/lowercase for absolute/relative)
- Parameter list for interpolation
- Absolute conversion routine
- Equality and hashing for safe comparisons

```mermaid
classDiagram
class PathCommand {
<<abstract>>
+String type
+bool isRelative
+toAbsolute(currentX, currentY) PathCommand
+params double[]
}
class MoveToCommand {
+double x
+double y
+bool isRelative
+toString() String
}
class LineToCommand {
+double x
+double y
+bool isRelative
+toString() String
}
class CubicBezierCommand {
+double x1,y1
+double x2,y2
+double x,y
+bool isRelative
+toString() String
}
class SmoothCubicBezierCommand {
+double x2,y2
+double x,y
+bool isRelative
+toCubicBezier(...) CubicBezierCommand
}
class QuadraticBezierCommand {
+double x1,y1
+double x,y
+bool isRelative
+toCubicBezier(...) CubicBezierCommand
}
class SmoothQuadraticBezierCommand {
+double x,y
+bool isRelative
+toQuadraticBezier(...) QuadraticBezierCommand
}
class ArcCommand {
+double rx,ry
+double rotation
+bool largeArc
+bool sweep
+double x,y
+bool isRelative
+toString() String
}
class ClosePathCommand {
+toString() String
}
PathCommand <|-- MoveToCommand
PathCommand <|-- LineToCommand
PathCommand <|-- CubicBezierCommand
PathCommand <|-- SmoothCubicBezierCommand
PathCommand <|-- QuadraticBezierCommand
PathCommand <|-- SmoothQuadraticBezierCommand
PathCommand <|-- ArcCommand
PathCommand <|-- ClosePathCommand
```

**Diagram sources**
- [path_data_base.dart:3-281](file://lib/src/animation/path_data_base.dart#L3-L281)
- [path_data_curves.dart:3-285](file://lib/src/animation/path_data_curves.dart#L3-L285)

**Section sources**
- [path_data_base.dart:1-281](file://lib/src/animation/path_data_base.dart#L1-L281)
- [path_data_curves.dart:1-285](file://lib/src/animation/path_data_curves.dart#L1-L285)

### Path Normalization and Alignment
Normalization converts paths to a canonical form:
- All commands become absolute
- Curves are expanded to cubic Beziers (including arcs via subdivision)
- Command counts are aligned by inserting degenerate cubic Beziers at strategic positions

```mermaid
flowchart TD
Start(["Start"]) --> Parse["Parse raw path data<br/>into PathCommand lists"]
Parse --> Abs["Convert to absolute coordinates"]
Abs --> Curves["Expand curves to cubic Beziers"]
Curves --> Len{"Same command count?"}
Len --> |Yes| Done(["Normalized Pair"])
Len --> |No| Pad["Insert degenerate cubic Beziers<br/>after MoveTo, before ClosePath"]
Pad --> Done
```

**Diagram sources**
- [path_normalizer_curves.dart:3-156](file://lib/src/animation/path_normalizer_curves.dart#L3-L156)
- [path_normalizer_alignment.dart:3-68](file://lib/src/animation/path_normalizer_alignment.dart#L3-L68)

**Section sources**
- [path_normalizer.dart:16-55](file://lib/src/animation/path_normalizer.dart#L16-L55)
- [path_normalizer_curves.dart:1-156](file://lib/src/animation/path_normalizer_curves.dart#L1-L156)
- [path_normalizer_alignment.dart:1-68](file://lib/src/animation/path_normalizer_alignment.dart#L1-L68)

### Interpolation Engine
The interpolator:
- Validates equal length and matching command types
- Clamps t to [0, 1]
- Applies per-command interpolation:
  - MoveTo: linear interpolation of coordinates
  - CubicBezier: linear interpolation of control points and end point
  - ClosePath: preserved without modification

```mermaid
flowchart TD
S(["interpolate(from,to,t)"]) --> CheckLen{"from.length == to.length?"}
CheckLen --> |No| Err["Throw ArgumentError"]
CheckLen --> |Yes| Clamp["t = clamp(0..1)"]
Clamp --> Loop["For each index i"]
Loop --> Type{"cmdFrom.type == cmdTo.type?"}
Type --> |No| Err
Type --> MT{"Both MoveTo?"}
MT --> |Yes| LerpMT["Lerp x,y"]
MT --> |No| CB{"Both CubicBezier?"}
CB --> |Yes| LerpCB["Lerp control points + end"]
CB --> |No| Close{"ClosePath?"}
Close --> |Yes| CloseCmd["path.close()"]
Close --> |No| Err
LerpMT --> Next["next i"]
LerpCB --> Next
CloseCmd --> Next
Next --> |i < n| Loop
Next --> |done| Ret["return Path"]
```

**Diagram sources**
- [path_interpolation.dart:26-65](file://lib/src/animation/path_interpolation.dart#L26-L65)

**Section sources**
- [path_interpolation.dart:1-96](file://lib/src/animation/path_interpolation.dart#L1-L96)

### Morphing Helper and Extensions
- PathMorpher validates normalized command lists and delegates interpolation to PathInterpolator.
- Extension methods simplify interpolation and morpher creation for lists of PathCommand.

```mermaid
classDiagram
class PathMorpher {
-PathCommand[] _fromCommands
-PathCommand[] _toCommands
-PathInterpolator _interpolator
+getPathAt(t) Path
+getPathAtPercent(pct) Path
+fromPath Path
+toPath Path
}
class PathCommandListInterpolation {
+interpolateTo(other, t) Path
+morphTo(other) PathMorpher
}
PathMorpher --> PathInterpolator : "uses"
PathCommandListInterpolation --> PathMorpher : "creates"
```

**Diagram sources**
- [path_interpolation_morpher.dart:6-52](file://lib/src/animation/path_interpolation_morpher.dart#L6-L52)

**Section sources**
- [path_interpolation_morpher.dart:1-53](file://lib/src/animation/path_interpolation_morpher.dart#L1-L53)

### SVG Path Parsing Pipeline
The parsing utilities convert raw SVG path strings into structured PathCommand lists, enabling downstream normalization and interpolation.

```mermaid
sequenceDiagram
participant App as "App"
participant Parser as "SVG Path Parser"
participant Normalizer as "PathNormalizer"
participant Interp as "PathInterpolator"
App->>Parser : "parse(svgPathString)"
Parser-->>App : "List<PathCommand>"
App->>Normalizer : "normalizeSingle(commands)"
Normalizer-->>App : "List<PathCommand> (absolute, cubic)"
App->>Interp : "interpolate(from,to,t)"
Interp-->>App : "Path"
```

**Diagram sources**
- [animated_svg_picture_path_parser.dart](file://lib/src/animation/animated_svg_picture_path_parser.dart)
- [path_normalizer.dart:31-33](file://lib/src/animation/path_normalizer.dart#L31-L33)
- [path_interpolation.dart:26-65](file://lib/src/animation/path_interpolation.dart#L26-L65)

**Section sources**
- [animated_svg_picture_path_parser.dart](file://lib/src/animation/animated_svg_picture_path_parser.dart)
- [animated_svg_picture_paths.dart](file://lib/src/animation/animated_svg_picture_paths.dart)
- [animated_svg_painter_shapes_paths.dart](file://lib/src/animation/animated_svg_painter_shapes_paths.dart)

### Examples and Integration
- Basic morphing example demonstrates creating a morpher and sampling interpolated paths.
- Advanced example showcases complex animations and performance tips.
- Widgets integrate morphing into UI flows.
- Tests validate correctness and edge cases.

**Section sources**
- [path_morphing_example.dart](file://example/lib/path_morphing_example.dart)
- [advanced_path_morphing.dart](file://example/lib/advanced_path_morphing.dart)
- [path_morphing_page.dart](file://example/lib/pages/path_morphing_page.dart)
- [path_morphing_widget.dart](file://example/lib/widgets/path_morphing_widget.dart)
- [smil_path_morphing_widget.dart](file://example/lib/widgets/smil_path_morphing_widget.dart)
- [path_morphing_test.dart](file://test/animation/path_morphing_test.dart)
- [path_morphing_correctness_test.dart](file://test/animation/path_morphing_correctness_test.dart)
- [smil_path_morphing_integration_test.dart](file://test/animation/smil_path_morphing_integration_test.dart)

## Dependency Analysis
The morphing system exhibits low coupling and high cohesion:
- PathCommand is the central abstraction enabling polymorphic interpolation.
- Normalizer depends on curve conversion utilities and alignment logic.
- Interpolator depends only on normalized command semantics.
- Examples and tests depend on public APIs without touching internal details.

```mermaid
graph LR
PD["path_data_base.dart<br/>path_data_curves.dart"] --> PN["path_normalizer.dart"]
PN --> PNC["path_normalizer_curves.dart"]
PN --> PNA["path_normalizer_alignment.dart"]
PN --> PI["path_interpolation.dart"]
PI --> PM["path_interpolation_morpher.dart"]
PPAR["animated_svg_picture_path_parser.dart"] --> PN
PPATH["animated_svg_picture_paths.dart"] --> PI
PAINT["animated_svg_painter_shapes_paths.dart"] --> PI
EX["examples & tests"] --> PM
```

**Diagram sources**
- [path_data_base.dart:1-281](file://lib/src/animation/path_data_base.dart#L1-L281)
- [path_data_curves.dart:1-285](file://lib/src/animation/path_data_curves.dart#L1-L285)
- [path_normalizer.dart:1-56](file://lib/src/animation/path_normalizer.dart#L1-L56)
- [path_normalizer_curves.dart:1-156](file://lib/src/animation/path_normalizer_curves.dart#L1-L156)
- [path_normalizer_alignment.dart:1-68](file://lib/src/animation/path_normalizer_alignment.dart#L1-L68)
- [path_interpolation.dart:1-96](file://lib/src/animation/path_interpolation.dart#L1-L96)
- [path_interpolation_morpher.dart:1-53](file://lib/src/animation/path_interpolation_morpher.dart#L1-L53)
- [animated_svg_picture_path_parser.dart](file://lib/src/animation/animated_svg_picture_path_parser.dart)
- [animated_svg_picture_paths.dart](file://lib/src/animation/animated_svg_picture_paths.dart)
- [animated_svg_painter_shapes_paths.dart](file://lib/src/animation/animated_svg_painter_shapes_paths.dart)
- [path_morphing_example.dart](file://example/lib/path_morphing_example.dart)
- [advanced_path_morphing.dart](file://example/lib/advanced_path_morphing.dart)
- [path_morphing_test.dart](file://test/animation/path_morphing_test.dart)
- [path_morphing_correctness_test.dart](file://test/animation/path_morphing_correctness_test.dart)

**Section sources**
- [path_data_base.dart:1-281](file://lib/src/animation/path_data_base.dart#L1-L281)
- [path_data_curves.dart:1-285](file://lib/src/animation/path_data_curves.dart#L1-L285)
- [path_normalizer.dart:1-56](file://lib/src/animation/path_normalizer.dart#L1-L56)
- [path_interpolation.dart:1-96](file://lib/src/animation/path_interpolation.dart#L1-L96)
- [path_interpolation_morpher.dart:1-53](file://lib/src/animation/path_interpolation_morpher.dart#L1-L53)
- [animated_svg_picture_path_parser.dart](file://lib/src/animation/animated_svg_picture_path_parser.dart)
- [animated_svg_picture_paths.dart](file://lib/src/animation/animated_svg_picture_paths.dart)
- [animated_svg_painter_shapes_paths.dart](file://lib/src/animation/animated_svg_painter_shapes_paths.dart)
- [path_morphing_example.dart](file://example/lib/path_morphing_example.dart)
- [advanced_path_morphing.dart](file://example/lib/advanced_path_morphing.dart)
- [path_morphing_test.dart](file://test/animation/path_morphing_test.dart)
- [path_morphing_correctness_test.dart](file://test/animation/path_morphing_correctness_test.dart)

## Performance Considerations
- Pre-normalize paths: Use PathNormalizer.normalize() once and reuse normalized commands to avoid repeated parsing and alignment work.
- Prefer interpolate() over interpolateStrings(): Direct interpolation avoids repeated parsing and normalization overhead.
- Minimize command count: Reduce the number of path segments to improve interpolation speed; consider simplifying source paths.
- Use PathMorpher caching: Reuse the same morpher instance across frames to leverage internal caching and reduce allocations.
- Avoid frequent re-parsing: Keep parsed PathCommand lists in memory during animations.
- Limit expensive curve conversions: Arcs are subdivided into multiple cubic Beziers; fewer arcs yield better performance.

[No sources needed since this section provides general guidance]

## Troubleshooting Guide
Common issues and resolutions:
- Incompatible path structures: Ensure both paths are normalized before interpolation; mismatched command types cause errors.
- Unequal command counts: Use PathNormalizer.normalize() to align paths; manual padding is unsupported.
- Relative vs absolute coordinates: All commands must be absolute post-normalization; relative commands are converted automatically.
- Degenerate curves: Insertion of zero-length cubic Beziers preserves structure; verify alignment logic if unexpected artifacts appear.
- Edge cases in arcs: Very small or degenerate arcs are handled by fallback to straight-line interpolation.

**Section sources**
- [path_interpolation.dart:26-65](file://lib/src/animation/path_interpolation.dart#L26-L65)
- [path_normalizer_alignment.dart:3-68](file://lib/src/animation/path_normalizer_alignment.dart#L3-L68)
- [path_normalizer_curves.dart:33-42](file://lib/src/animation/path_normalizer_curves.dart#L33-L42)

## Conclusion
The path morphing system provides a robust foundation for smooth SVG shape transitions. By structuring paths into a unified command model, normalizing them into a canonical form, and interpolating per-command, it enables complex animations with predictable performance. Following the guidance on preprocessing, caching, and minimizing segment counts yields fluid, efficient morphs suitable for interactive UIs.

[No sources needed since this section summarizes without analyzing specific files]

## Appendices

### Mathematical Foundations
- Linear interpolation: Used for MoveTo and CubicBezier control points/end points.
- Arc subdivision: Elliptical arcs are approximated by up to four cubic Beziers using standard techniques.
- Coordinate transformations: Absolute conversion ensures consistent interpolation across paths.

**Section sources**
- [path_interpolation.dart:26-65](file://lib/src/animation/path_interpolation.dart#L26-L65)
- [path_normalizer_curves.dart:27-155](file://lib/src/animation/path_normalizer_curves.dart#L27-L155)

### Practical Guidance
- Start with simple shapes: Begin with basic forms (e.g., circle-to-square) to validate the pipeline.
- Use examples as templates: Adapt path_morphing_example.dart and advanced_path_morphing.dart for custom animations.
- Profile and optimize: Measure frame times and reduce path complexity or interpolation frequency as needed.
- Test edge cases: Validate with degenerate arcs, very short paths, and paths with different winding orders.

**Section sources**
- [path_morphing_example.dart](file://example/lib/path_morphing_example.dart)
- [advanced_path_morphing.dart](file://example/lib/advanced_path_morphing.dart)
- [path_morphing_test.dart](file://test/animation/path_morphing_test.dart)
- [path_morphing_correctness_test.dart](file://test/animation/path_morphing_correctness_test.dart)