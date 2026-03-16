# Development and Contributing

<cite>
**Referenced Files in This Document**
- [README.md](file://README.md)
- [ROADMAP.md](file://ROADMAP.md)
- [NEXT_STEPS.md](file://NEXT_STEPS.md)
- [CURRENT_STATUS.md](file://CURRENT_STATUS.md)
- [TODO.md](file://TODO.md)
- [docs/DEVELOPMENT.md](file://docs/DEVELOPMENT.md)
- [ARCHITECTURE.md](file://ARCHITECTURE.md)
- [ANIMATION.md](file://ANIMATION.md)
- [VISUAL_TESTING_GUIDELINES.md](file://VISUAL_TESTING_GUIDELINES.md)
- [pubspec.yaml](file://pubspec.yaml)
- [example/pubspec.yaml](file://example/pubspec.yaml)
- [example/lib/main.dart](file://example/lib/main.dart)
- [lib/svg.dart](file://lib/svg.dart)
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
9. [Contribution Workflow](#contribution-workflow)
10. [Roadmap and Community Engagement](#roadmap-and-community-engagement)
11. [Conclusion](#conclusion)

## Introduction
This document provides a comprehensive guide for developing and contributing to the flutter_svg project. It covers the development environment setup, build processes, architectural decisions, contribution workflow, code review expectations, testing requirements, and practical examples for local development, debugging, and feature development. It also outlines the roadmap, future plans, and community engagement guidelines, with terminology consistent with the codebase.

## Project Structure
The repository is organized into:
- Core library: public API and widgets in lib/
- Animation subsystem: experimental SMIL pipeline under lib/src/animation/
- Example application: example/ demonstrating features and usage
- Documentation: docs/, ROADMAP.md, NEXT_STEPS.md, CURRENT_STATUS.md, TODO.md
- Tests: test/ with animation tests and visual testing utilities
- Tooling and configuration: pubspec.yaml, dart_test.yaml, .fvm configuration

```mermaid
graph TB
subgraph "Library"
A["lib/svg.dart<br/>Public API"]
B["lib/src/animation/<br/>SMIL + DOM + Filters"]
end
subgraph "Example App"
C["example/lib/main.dart<br/>Demo app"]
D["example/assets/<br/>SVG samples"]
end
subgraph "Docs & Plans"
E["docs/DEVELOPMENT.md<br/>Dev guide"]
F["ROADMAP.md / NEXT_STEPS.md<br/>Roadmap"]
G["CURRENT_STATUS.md / TODO.md<br/>Status & queue"]
end
subgraph "Tests"
H["test/animation/<br/>Animation tests"]
I["VISUAL_TESTING_GUIDELINES.md<br/>Visual testing"]
end
A --> B
C --> A
D --> C
E --> B
F --> G
H --> I
```

**Diagram sources**
- [lib/svg.dart](file://lib/svg.dart)
- [docs/DEVELOPMENT.md](file://docs/DEVELOPMENT.md)
- [ROADMAP.md](file://ROADMAP.md)
- [NEXT_STEPS.md](file://NEXT_STEPS.md)
- [CURRENT_STATUS.md](file://CURRENT_STATUS.md)
- [TODO.md](file://TODO.md)
- [VISUAL_TESTING_GUIDELINES.md](file://VISUAL_TESTING_GUIDELINES.md)
- [example/lib/main.dart](file://example/lib/main.dart)

**Section sources**
- [README.md](file://README.md)
- [pubspec.yaml](file://pubspec.yaml)
- [example/pubspec.yaml](file://example/pubspec.yaml)

## Core Components
- Public API surface: Svg, SvgPicture, and related loaders are exposed from lib/svg.dart.
- Widgets: SvgPicture supports asset, network, file, memory, and string sources, plus rendering strategy selection.
- Animation subsystem: AnimatedSvgPicture and supporting modules implement DOM parsing, SMIL extraction, timeline management, interpolators, and CustomPainter-based rendering.
- Example app: Demonstrates usage patterns and showcases features.

Key responsibilities:
- SvgPicture: decoding, caching, and rendering via vector_graphics backend.
- AnimatedSvgPicture: DOM parsing, SMIL engine, timeline, and painter orchestration.
- Tests and visual testing utilities: ensure correctness and regressions for animations.

**Section sources**
- [lib/svg.dart](file://lib/svg.dart)
- [ANIMATION.md](file://ANIMATION.md)
- [docs/DEVELOPMENT.md](file://docs/DEVELOPMENT.md)

## Architecture Overview
The project maintains two rendering pipelines:
- Static SVG pipeline: vector_graphics_compiler-based binary (.vec) for fast production rendering.
- Animated SVG pipeline: XML parsing to DOM, SMIL extraction, timeline-driven animation, and CustomPainter rendering.

```mermaid
graph TB
S["SVG Source"] --> P1["Static Pipeline<br/>vector_graphics_compiler.encodeSvg() → .vec → VectorGraphic"]
S --> P2["Animated Pipeline<br/>XML → DOM → SMIL → Timeline → Painter"]
P1 --> R1["Fast rendering"]
P2 --> R2["Full DOM + SMIL + runtime control"]
```

**Diagram sources**
- [ARCHITECTURE.md](file://ARCHITECTURE.md)
- [docs/DEVELOPMENT.md](file://docs/DEVELOPMENT.md)

**Section sources**
- [ARCHITECTURE.md](file://ARCHITECTURE.md)
- [docs/DEVELOPMENT.md](file://docs/DEVELOPMENT.md)

## Detailed Component Analysis

### Animation Engine Flow
The animation pipeline parses SVG to a DOM, extracts SMIL animations, manages time, interpolates values, and renders via CustomPainter.

```mermaid
sequenceDiagram
participant U as "User Code"
participant W as "AnimatedSvgPicture"
participant P as "SvgParser"
participant D as "DOM (SvgDocument)"
participant SP as "SmilParser"
participant TL as "SvgTimeline"
participant IP as "Interpolators"
participant PA as "AnimatedSvgPainter"
U->>W : "Provide SVG string/asset"
W->>P : "parse()"
P-->>D : "DOM tree"
W->>SP : "parseAnimations(dom)"
SP-->>TL : "animations list"
loop "Ticker-driven"
W->>TL : "tick(delta)"
TL->>IP : "computeValue(t)"
IP-->>TL : "interpolated values"
TL-->>D : "set animated values"
end
W->>PA : "paint(canvas, size)"
PA->>D : "read effective values"
PA-->>U : "rendered frame"
```

**Diagram sources**
- [docs/DEVELOPMENT.md](file://docs/DEVELOPMENT.md)
- [ARCHITECTURE.md](file://ARCHITECTURE.md)

**Section sources**
- [docs/DEVELOPMENT.md](file://docs/DEVELOPMENT.md)
- [ARCHITECTURE.md](file://ARCHITECTURE.md)

### Visual Testing Pattern
Visual testing validates actual pixel output for animations, complementing unit tests.

```mermaid
flowchart TD
Start(["Start test"]) --> Build["Build widget at time t"]
Build --> Capture["Capture RGBA pixels"]
Capture --> Analyze["Analyze geometry<br/>(count, centroid, bbox, angle)"]
Analyze --> Assert["Assert expected changes"]
Assert --> End(["End"])
```

**Diagram sources**
- [VISUAL_TESTING_GUIDELINES.md](file://VISUAL_TESTING_GUIDELINES.md)

**Section sources**
- [VISUAL_TESTING_GUIDELINES.md](file://VISUAL_TESTING_GUIDELINES.md)

### Example Application
The example app demonstrates usage patterns and showcases features.

```mermaid
graph TB
M["example/lib/main.dart<br/>MaterialApp"] --> Home["HomePage"]
Home --> Widgets["Widgets using SvgPicture / AnimatedSvgPicture"]
Assets["example/assets/<br/>SVG samples"] --> Widgets
```

**Diagram sources**
- [example/lib/main.dart](file://example/lib/main.dart)
- [example/pubspec.yaml](file://example/pubspec.yaml)

**Section sources**
- [example/lib/main.dart](file://example/lib/main.dart)
- [example/pubspec.yaml](file://example/pubspec.yaml)

## Dependency Analysis
Primary dependencies:
- vector_graphics: Static rendering backend
- vector_graphics_compiler: Precompilation to .vec
- xml: XML parsing for animated pipeline
- http: Network loading for SvgPicture.network

```mermaid
graph LR
App["flutter_svg"] --> VG["vector_graphics"]
App --> VGC["vector_graphics_compiler"]
App --> XML["xml"]
App --> HTTP["http"]
```

**Diagram sources**
- [pubspec.yaml](file://pubspec.yaml)

**Section sources**
- [pubspec.yaml](file://pubspec.yaml)

## Performance Considerations
- Static pipeline: optimized binary format yields fast rendering.
- Animated pipeline: DOM preservation enables SMIL but adds overhead.
- Hot-path optimizations: path normalization, dirty tracking, subtree caching, and reusable Path objects.
- Performance targets: path interpolation under 1ms, animate motion updates within 100ms for 60 updates, aiming for 60 FPS for simple animations and 30+ FPS for complex ones.

**Section sources**
- [ARCHITECTURE.md](file://ARCHITECTURE.md)
- [docs/DEVELOPMENT.md](file://docs/DEVELOPMENT.md)

## Troubleshooting Guide
Common pitfalls and debugging tips:
- Pipeline mixing: SvgPicture cannot render SMIL; use AnimatedSvgPicture for animations.
- Path morphing: requires normalized path structures.
- RepaintBoundary captures full screen (800x600), not widget size.
- Memory leaks: always dispose images in tests.
- Deterministic timelines: prefer autoPlay=false + initialTime or explicit pump durations.
- Use structured traces and playground diagnostics for runtime insights.

**Section sources**
- [docs/DEVELOPMENT.md](file://docs/DEVELOPMENT.md)
- [VISUAL_TESTING_GUIDELINES.md](file://VISUAL_TESTING_GUIDELINES.md)
- [CURRENT_STATUS.md](file://CURRENT_STATUS.md)

## Contribution Workflow
- Development quick start: run example app and animation tests locally.
- Code organization: follow lib/src/animation/ structure for animation features.
- Adding a new SMIL animation type: parse XML, interpolate values, render via painter, and add comprehensive tests.
- Adding examples: create widget, add tab, asset, and update info panel.
- Testing strategy: unit, integration, golden, and visual tests; use visual testing guidelines for animations.
- Debugging: enable logging, use trace callbacks, and leverage playground diagnostics.
- Validation gate: behavior + tests + analyze + docs updates.

```mermaid
flowchart TD
A["Fork & branch"] --> B["Implement feature<br/>(parser/interpolator/painter/test)"]
B --> C["Run tests<br/>(unit/integration/golden/visual)"]
C --> D{"All green?"}
D --> |No| B
D --> |Yes| E["Update docs<br/>(CURRENT_STATUS, TODO, RESOLVED_ISSUES)"]
E --> F["Open PR & CI checks"]
F --> G["Review & merge"]
```

**Section sources**
- [docs/DEVELOPMENT.md](file://docs/DEVELOPMENT.md)
- [ROADMAP.md](file://ROADMAP.md)
- [NEXT_STEPS.md](file://NEXT_STEPS.md)
- [CURRENT_STATUS.md](file://CURRENT_STATUS.md)
- [TODO.md](file://TODO.md)

## Roadmap and Community Engagement
- Roadmap items are prioritized and validated with behavior, tests, analyze passes, and documentation updates.
- Current priorities focus on parity foundations (filters, hit-testing, use/symbol inheritance), core feature expansion (text, foreignObject, animateMotion), CSS/timing fidelity, and quality/stability.
- Community engagement: use issue tracker for the package, refer to roadmap and status documents for authoritative state, and follow validation gate requirements before considering items complete.

**Section sources**
- [ROADMAP.md](file://ROADMAP.md)
- [NEXT_STEPS.md](file://NEXT_STEPS.md)
- [CURRENT_STATUS.md](file://CURRENT_STATUS.md)
- [TODO.md](file://TODO.md)
- [README.md](file://README.md)

## Conclusion
This guide consolidates development practices, architecture, testing, and contribution workflows for flutter_svg. Contributors should align with the dual-pipeline design, follow the validation gate, prioritize visual testing for animations, and engage with the roadmap and status documents for current priorities and expectations.