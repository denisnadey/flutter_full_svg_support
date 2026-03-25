# Use Element Symbol Inheritance

<cite>
**Referenced Files in This Document**
- [use_symbol_inheritance_test.dart](file://test/animation/use_symbol_inheritance_test.dart)
- [animated_svg_painter_use.dart](file://lib/src/animation/animated_svg_painter_use.dart)
- [animated_svg_picture_hit_test_use.dart](file://lib/src/animation/animated_svg_picture_hit_test_use.dart)
- [svg_parser.dart](file://lib/src/animation/svg_parser.dart)
- [svg_dom.dart](file://lib/src/animation/svg_dom.dart)
- [svg_parser_elements.dart](file://lib/src/animation/svg_parser_elements.dart)
- [animated_svg_painter.dart](file://lib/src/animation/animated_svg_painter.dart)
- [css_cascade.dart](file://lib/src/animation/css_cascade.dart)
- [css_selectors.dart](file://lib/src/animation/css_selectors.dart)
- [css_variables_calc.dart](file://lib/src/animation/css_variables_calc.dart)
- [animated_svg_painter_tree.dart](file://lib/src/animation/animated_svg_painter_tree.dart)
- [svg.dart](file://lib/svg.dart)
</cite>

## Update Summary
**Changes Made**
- Enhanced CSS cascade behavior with comprehensive testing for CSS class rules, ID rules, element type rules, specificity calculations, and inheritance patterns
- Improved use element symbol inheritance system with detailed CSS property inheritance tracking
- Added support for CSS custom properties flowing through use boundaries
- Expanded attribute propagation rules with proper specificity handling
- Enhanced hit testing with use context inheritance for pointer-events

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [Enhanced CSS Cascade System](#enhanced-css-cascade-system)
7. [Use Element Inheritance Context](#use-element-inheritance-context)
8. [CSS Custom Properties Through Use Boundaries](#css-custom-properties-through-use-boundaries)
9. [Dependency Analysis](#dependency-analysis)
10. [Performance Considerations](#performance-considerations)
11. [Troubleshooting Guide](#troubleshooting-guide)
12. [Conclusion](#conclusion)

## Introduction
This document explains how the Flutter SVG library implements element symbol inheritance through the `<use>` element and `<symbol>` references with enhanced CSS cascade behavior. It covers the parsing pipeline, rendering behavior, attribute propagation rules, CSS property inheritance, viewport transformations, recursion limits, and hit-testing mechanics. The system now provides comprehensive CSS cascade support including class rules, ID rules, element type rules, specificity calculations, and inheritance patterns that flow through use boundaries.

## Project Structure
The relevant implementation spans the animation pipeline, CSS cascade system, and extensive testing:
- Tests validate attribute propagation, symbol scaling, nested use recursion, CSS cascade behavior, and hit testing.
- The painter handles rendering of `<use>` and `<symbol>` references, applying transforms and clipping.
- The DOM model stores parsed attributes and enables traversal and lookup.
- The parser converts XML into a typed DOM with animatable attributes.
- The CSS cascade system provides comprehensive specificity calculations and inheritance resolution.
- Custom properties support enables variables to flow through use boundaries.

```mermaid
graph TB
subgraph "Tests"
T1["use_symbol_inheritance_test.dart"]
T2["css_cascade_specificity_test.dart"]
end
subgraph "CSS System"
C1["css_cascade.dart"]
C2["css_selectors.dart"]
C3["css_variables_calc.dart"]
end
subgraph "Parser"
P1["svg_parser.dart"]
P2["svg_parser_elements.dart"]
D1["svg_dom.dart"]
end
subgraph "Renderer"
R1["animated_svg_painter.dart"]
R2["animated_svg_painter_use.dart"]
R3["animated_svg_painter_tree.dart"]
H1["animated_svg_picture_hit_test_use.dart"]
end
T1 --> C1
T2 --> C1
C1 --> R1
C2 --> C1
C3 --> R1
P1 --> D1
P2 --> D1
D1 --> R1
R1 --> R2
R1 --> R3
R2 --> H1
```

**Diagram sources**
- [use_symbol_inheritance_test.dart:1-1202](file://test/animation/use_symbol_inheritance_test.dart#L1-L1202)
- [css_cascade_specificity_test.dart:255-489](file://test/animation/css_cascade_specificity_test.dart#L255-L489)
- [css_cascade.dart:1-675](file://lib/src/animation/css_cascade.dart#L1-L675)
- [css_selectors.dart:1-654](file://lib/src/animation/css_selectors.dart#L1-L654)
- [css_variables_calc.dart:1-595](file://lib/src/animation/css_variables_calc.dart#L1-L595)
- [svg_parser.dart:27-65](file://lib/src/animation/svg_parser.dart#L27-L65)
- [svg_parser_elements.dart:3-138](file://lib/src/animation/svg_parser_elements.dart#L3-L138)
- [svg_dom.dart:123-332](file://lib/src/animation/svg_dom.dart#L123-L332)
- [animated_svg_painter.dart:48-136](file://lib/src/animation/animated_svg_painter.dart#L48-L136)
- [animated_svg_painter_use.dart:1-625](file://lib/src/animation/animated_svg_painter_use.dart#L1-L625)
- [animated_svg_painter_tree.dart:1-457](file://lib/src/animation/animated_svg_painter_tree.dart#L1-L457)
- [animated_svg_picture_hit_test_use.dart:1-339](file://lib/src/animation/animated_svg_picture_hit_test_use.dart#L1-L339)

**Section sources**
- [use_symbol_inheritance_test.dart:1-1202](file://test/animation/use_symbol_inheritance_test.dart#L1-L1202)
- [css_cascade.dart:1-675](file://lib/src/animation/css_cascade.dart#L1-L675)
- [css_variables_calc.dart:1-595](file://lib/src/animation/css_variables_calc.dart#L1-L595)
- [animated_svg_painter_use.dart:1-625](file://lib/src/animation/animated_svg_painter_use.dart#L1-L625)

## Core Components
- DOM Model: Stores parsed attributes, supports lookup by ID/class, and tracks animation presence.
- Parser: Converts XML to DOM nodes, infers attribute types, and preserves raw values for CSS matching.
- CSS Cascade System: Implements comprehensive specificity calculations, inheritance resolution, and property precedence.
- Painter: Renders the document, applies viewBox transforms, and handles `<use>` and `<symbol>` references with inheritance context.
- Hit Test: Performs pointer hit detection across `<use>` chains with recursion limits and pointer-events inheritance.
- CSS Variables: Supports custom properties flowing through use boundaries with proper inheritance.
- Tests: Validate attribute propagation, symbol scaling, nested references, CSS cascade behavior, and circular reference protection.

**Section sources**
- [svg_dom.dart:123-332](file://lib/src/animation/svg_dom.dart#L123-L332)
- [css_cascade.dart:277-396](file://lib/src/animation/css_cascade.dart#L277-L396)
- [css_variables_calc.dart:44-98](file://lib/src/animation/css_variables_calc.dart#L44-L98)
- [animated_svg_painter_use.dart:107-243](file://lib/src/animation/animated_svg_painter_use.dart#L107-L243)
- [animated_svg_picture_hit_test_use.dart:8-22](file://lib/src/animation/animated_svg_picture_hit_test_use.dart#L8-L22)
- [use_symbol_inheritance_test.dart:1-1202](file://test/animation/use_symbol_inheritance_test.dart#L1-L1202)

## Architecture Overview
The system parses SVG XML into a typed DOM, then renders it using a custom painter with enhanced CSS cascade support. The `<use>` element references another element by ID and inherits CSS properties from the referencing element. The CSS cascade system provides comprehensive specificity calculations and inheritance resolution that flows through use boundaries.

```mermaid
sequenceDiagram
participant Test as "Test Suite"
participant Parser as "SvgParser"
participant DOM as "SvgDocument/SvgNode"
participant CSS as "CssCascadeResolver"
participant Painter as "AnimatedSvgPainter"
participant UseExt as "_paintUse/_paintSymbolReference"
Test->>Parser : parse(svgXml)
Parser->>DOM : create nodes and attributes
Test->>CSS : resolveProperty(node, property)
CSS->>DOM : resolve specificity and inheritance
Test->>Painter : paint(document)
Painter->>UseExt : traverse use/symbol references
UseExt->>DOM : resolve hrefId and apply transforms
UseExt->>CSS : resolve inherited properties
UseExt-->>Painter : render referenced subtree
```

**Diagram sources**
- [svg_parser.dart:31-63](file://lib/src/animation/svg_parser.dart#L31-L63)
- [css_cascade.dart:295-396](file://lib/src/animation/css_cascade.dart#L295-L396)
- [animated_svg_painter_use.dart:159-233](file://lib/src/animation/animated_svg_painter_use.dart#L159-L233)

## Detailed Component Analysis

### DOM Model and Attribute Types
- Nodes store tag, id, class, and a map of animatable attributes with types (number, length, color, transform, path, points, string, list, url).
- Raw attribute values are preserved for CSS selector matching.
- Lookup helpers enable finding elements by id/class/tag recursively.

```mermaid
classDiagram
class SvgNode {
+String tagName
+String id
+String className
+Map~String, AnimatableSvgAttribute~ attributes
+Map~String, String~ _rawAttributes
+SvgNode[] children
+SvgNode parent
+bool hasAnimations
+SvgDocument document
+findById(id) SvgNode
+findByClass(className) SvgNode[]
+findByTag(tagName) SvgNode[]
+getRawAttributeValue(name) String
}
class SvgDocument {
+SvgNode root
+Rect viewBox
+double width
+double height
+getElementById(id) SvgNode
+getElementsByClass(className) SvgNode[]
+getElementsByTag(tagName) SvgNode[]
}
SvgDocument --> SvgNode : "root"
SvgNode --> SvgNode : "children"
```

**Diagram sources**
- [svg_dom.dart:123-332](file://lib/src/animation/svg_dom.dart#L123-L332)

**Section sources**
- [svg_dom.dart:123-332](file://lib/src/animation/svg_dom.dart#L123-L332)

### Parser Pipeline
- Parses XML into DOM nodes, infers attribute types, and extracts direct text content for text nodes.
- Skips style elements during element parsing; CSS is handled separately.
- Root attributes (viewBox, width, height) are captured for viewport calculations.

```mermaid
flowchart TD
Start(["XML Input"]) --> ParseDoc["Parse XmlDocument"]
ParseDoc --> FindSvg["Find root <svg>"]
FindSvg --> ParseFilters["Parse <filter> in <defs>"]
ParseFilters --> ParseCSS["@keyframes and selectors"]
ParseCSS --> ParseRoot["Parse root <svg> element"]
ParseRoot --> ExtractAttrs["Infer attribute types<br/>and raw values"]
ExtractAttrs --> RecurseChildren["Recursively parse children"]
RecurseChildren --> BuildDoc["Build SvgDocument with viewBox/size"]
BuildDoc --> End(["DOM Ready"])
```

**Diagram sources**
- [svg_parser.dart:31-63](file://lib/src/animation/svg_parser.dart#L31-L63)
- [svg_parser_elements.dart:3-49](file://lib/src/animation/svg_parser_elements.dart#L3-L49)

**Section sources**
- [svg_parser.dart:27-65](file://lib/src/animation/svg_parser.dart#L27-L65)
- [svg_parser_elements.dart:3-138](file://lib/src/animation/svg_parser_elements.dart#L3-L138)

### Use Element Rendering and Attribute Propagation
- The painter resolves the referenced element by ID from the `href` attribute.
- For `<symbol>` references, it computes a viewport transform based on `width/height` and `preserveAspectRatio`, then clips and transforms the canvas before rendering children.
- For `<svg>` references, it applies similar viewport logic and then paints the referenced SVG subtree.
- For other referenced tags, it paints the referenced node directly after translating by `x/y`.

```mermaid
sequenceDiagram
participant Canvas as "ui.Canvas"
participant Painter as "AnimatedSvgPainter"
participant UseExt as "_paintUse"
participant SymExt as "_paintSymbolReference"
participant SvgExt as "_paintSvgUseReference"
Painter->>UseExt : _paintUse(node, useStack)
UseExt->>UseExt : extractHrefId(node)
UseExt->>UseExt : check recursion depth
UseExt->>DOM : document.root.findById(hrefId)
alt referenced is symbol
UseExt->>SymExt : _paintSymbolReference(...)
SymExt->>Canvas : apply viewport transform and clip
SymExt->>Painter : paint symbol children
else referenced is svg
UseExt->>SvgExt : _paintSvgUseReference(...)
SvgExt->>Canvas : apply viewport transform and clip
SvgExt->>Painter : paint referenced svg subtree
else other tag
UseExt->>Canvas : translate by x,y
UseExt->>Painter : paint referenced node
end
```

**Diagram sources**
- [animated_svg_painter_use.dart:159-253](file://lib/src/animation/animated_svg_painter_use.dart#L159-L253)

**Section sources**
- [animated_svg_painter_use.dart:159-253](file://lib/src/animation/animated_svg_painter_use.dart#L159-L253)

### Symbol ViewBox and PreserveAspectRatio
- When referencing a `<symbol>`, the use element defines the viewport (`width/height`) and the symbol defines the `viewBox` and `preserveAspectRatio`.
- The renderer computes a destination rectangle and applies a scale and translate transform, optionally clipping to the viewport.

```mermaid
flowchart TD
A["Use node with width/height"] --> B["Symbol node with viewBox and preserveAspectRatio"]
B --> C["Compute destination rect from preserveAspectRatio"]
C --> D["Calculate scaleX/scaleY and translateX/translateY"]
D --> E["Apply transform to canvas"]
E --> F["Optionally clip to viewport"]
F --> G["Paint symbol children"]
```

**Diagram sources**
- [animated_svg_painter_use.dart:213-233](file://lib/src/animation/animated_svg_painter_use.dart#L213-L233)

**Section sources**
- [animated_svg_painter_use.dart:213-233](file://lib/src/animation/animated_svg_painter_use.dart#L213-L233)

### Nested Use References and Recursion Limits
- The implementation enforces a maximum recursion depth (matching Blink) to prevent infinite loops and excessive resource usage.
- Circular references are detected by tracking visited IDs in the use stack.
- Tests verify correct behavior for up to 10 levels of nesting and protection against cycles.

```mermaid
flowchart TD
Start(["_paintUse called"]) --> CheckHref["Extract hrefId and validate"]
CheckHref --> CheckCycle{"useStack contains hrefId?"}
CheckCycle --> |Yes| Abort["Abort rendering"]
CheckCycle --> |No| CheckDepth{"useStack size >= 10?"}
CheckDepth --> |Yes| Abort
CheckDepth --> |No| Resolve["document.root.findById(hrefId)"]
Resolve --> Allowed{"Allowed tag?"}
Allowed --> |No| Abort
Allowed --> |Yes| Paint["Paint referenced node with transforms"]
```

**Diagram sources**
- [animated_svg_painter_use.dart:159-172](file://lib/src/animation/animated_svg_painter_use.dart#L159-L172)
- [animated_svg_picture_hit_test_use.dart:9-23](file://lib/src/animation/animated_svg_picture_hit_test_use.dart#L9-L23)

**Section sources**
- [animated_svg_painter_use.dart:3-5](file://lib/src/animation/animated_svg_painter_use.dart#L3-L5)
- [animated_svg_picture_hit_test_use.dart:3-5](file://lib/src/animation/animated_svg_picture_hit_test_use.dart#L3-L5)

### Hit Testing Across Use References
- Hit testing mirrors rendering: it resolves the referenced element, applies the same viewport transforms, and checks whether the pointer falls within the transformed viewport.
- It traverses symbol children in reverse order (top-most first) and recurses into the referenced subtree with the same use stack protections.
- Pointer-events inheritance is tracked through use boundaries for proper event handling.

```mermaid
sequenceDiagram
participant HT as "_AnimatedSvgPictureState"
participant UseHT as "_hitTestUseReference"
participant SymHT as "_applyUseViewportTransform"
HT->>UseHT : _hitTestUseReference(useNode, point, transform, useStack)
UseHT->>UseHT : extractHrefId and check recursion
UseHT->>DOM : find referenced node
UseHT->>SymHT : compute viewport transform and clip
alt symbol reference
UseHT->>HT : traverse symbol children (reverse)
HT-->>UseHT : return first matching child
else svg or other
UseHT->>HT : recurse into referenced node
end
```

**Diagram sources**
- [animated_svg_picture_hit_test_use.dart:9-91](file://lib/src/animation/animated_svg_picture_hit_test_use.dart#L9-L91)

**Section sources**
- [animated_svg_picture_hit_test_use.dart:9-91](file://lib/src/animation/animated_svg_picture_hit_test_use.dart#L9-L91)

### Attribute Propagation Rules Verified by Tests
- Fill/stroke/opacity/font properties on `<use>` propagate to referenced elements.
- Explicit attributes on referenced elements override inherited attributes from `<use>`.
- Style attribute on `<use>` overrides inline attributes.
- Transform on `<use>` composes with referenced element transforms.
- Nested `<use>` chains render correctly up to the recursion limit.
- Circular references are prevented without crashing.
- CSS class rules, ID rules, and element type rules are properly resolved through use boundaries.
- Inheritance patterns follow CSS cascade specifications with proper specificity calculations.

```mermaid
flowchart TD
U["Use node"] --> |propagate| Ref["Referenced element"]
Ref --> |explicit| Override["Explicit attributes on referenced element"]
U --> |style| Priority["Style attribute takes precedence"]
U --> |transform| Compose["Compose with referenced transform"]
U --> |nested| Depth["Respect recursion depth limit"]
U --> |CSS cascade| Cascade["Proper specificity resolution"]
```

**Diagram sources**
- [use_symbol_inheritance_test.dart:11-159](file://test/animation/use_symbol_inheritance_test.dart#L11-L159)

**Section sources**
- [use_symbol_inheritance_test.dart:11-159](file://test/animation/use_symbol_inheritance_test.dart#L11-L159)

## Enhanced CSS Cascade System

### Comprehensive Specificity Calculations
The CSS cascade system implements full CSS specificity calculations including:
- ID selectors (#id) with highest priority
- Class selectors (.class) and attribute selectors ([attr])
- Element type selectors (rect, circle) and pseudo-class selectors (:hover, :active)
- Universal selector (*) with zero specificity
- Compound selectors combined with proper specificity arithmetic

### CSS Property Inheritance Tracking
The system maintains comprehensive inheritance tracking for:
- Color properties (color, fill, stroke)
- Font properties (font-family, font-size, font-weight)
- Text properties (text-align, white-space, word-spacing)
- SVG-specific properties (stroke-width, stroke-linecap, paint-order)
- Visibility properties (visibility, pointer-events, cursor)
- Text decoration and emphasis properties

### CSS Variable Resolution Through Use Boundaries
Custom properties (CSS variables) flow through use boundaries with:
- Proper inheritance from use elements to referenced content
- Support for var(--variable-name) syntax with fallback values
- Resolution order: use element variables > parent variables > referenced element variables
- Infinite recursion prevention with iteration limits

**Section sources**
- [css_cascade.dart:18-667](file://lib/src/animation/css_cascade.dart#L18-L667)
- [css_variables_calc.dart:101-173](file://lib/src/animation/css_variables_calc.dart#L101-L173)

## Use Element Inheritance Context

### Inheritance Context Management
The `_UseInheritanceContext` class manages CSS property inheritance across use boundaries:
- Captures use element properties for inheritance to referenced content
- Maintains parent context for nested use chains
- Provides CSS rules from document for proper class/id resolution
- Handles CSS custom property lookup through use boundaries

### Inherited Property Resolution
Properties that flow through use boundaries include:
- All CSS inheritable properties (color, font, stroke, fill, visibility)
- CSS custom properties (starting with --)
- Presentation attributes on use elements
- Style attribute values on use elements

Properties that do NOT flow through use boundaries:
- Non-inherited properties (opacity, transform, display, clip-path, mask, filter)
- Positioning properties (x, y coordinates)
- Structural properties affecting use element itself

### CSS Rule Resolution Through Use Boundaries
The system resolves CSS rules for referenced elements:
- Inline styles on referenced elements take highest precedence
- Document CSS rules matching referenced element (class, id, element type)
- Presentation attributes on referenced elements
- Inherited values from use element chain
- Parent element inherited values for non-inherited properties

**Section sources**
- [animated_svg_painter_use.dart:107-243](file://lib/src/animation/animated_svg_painter_use.dart#L107-L243)
- [animated_svg_painter_tree.dart:27-226](file://lib/src/animation/animated_svg_painter_tree.dart#L27-L226)

## CSS Custom Properties Through Use Boundaries

### Variable Resolution Mechanism
CSS variables can flow through use boundaries through:
- Direct use element custom properties (style attribute)
- Parent element custom properties in the use chain
- Referenced element custom properties for non-inherited properties
- Proper fallback value resolution when variables are undefined

### Variable Resolution Order
The system resolves CSS variables in this order:
1. Use element custom properties (highest priority)
2. Parent element custom properties in use chain
3. Referenced element custom properties
4. CSS variable fallback values
5. Empty string if no resolution possible

### Variable Storage and Access
Custom properties are stored using:
- Node-level custom property stores for inheritance
- Weak map pattern via attribute storage
- Proper cleanup and disposal of property stores
- Support for nested use element chains

**Section sources**
- [css_variables_calc.dart:44-98](file://lib/src/animation/css_variables_calc.dart#L44-L98)
- [css_variables_calc.dart:101-173](file://lib/src/animation/css_variables_calc.dart#L101-L173)

## Dependency Analysis
- Tests depend on the parser, CSS cascade system, and animation pipeline to validate rendering behavior.
- The painter depends on the DOM model, CSS cascade resolver, and use extension for reference resolution.
- The hit-test extension mirrors the painter's logic for pointer events with use context inheritance.
- CSS cascade system provides specificity calculations and inheritance resolution for all rendering operations.

```mermaid
graph LR
Tests["use_symbol_inheritance_test.dart"] --> Parser["svg_parser.dart"]
Tests --> CSS["css_cascade.dart"]
Tests --> DOM["svg_dom.dart"]
Parser --> DOM
DOM --> CSS
CSS --> Painter["animated_svg_painter.dart"]
Painter --> UseExt["animated_svg_painter_use.dart"]
Painter --> TreeExt["animated_svg_painter_tree.dart"]
Painter --> HitExt["animated_svg_picture_hit_test_use.dart"]
```

**Diagram sources**
- [use_symbol_inheritance_test.dart:1-1202](file://test/animation/use_symbol_inheritance_test.dart#L1-L1202)
- [css_cascade.dart:1-675](file://lib/src/animation/css_cascade.dart#L1-L675)
- [svg_parser.dart:27-65](file://lib/src/animation/svg_parser.dart#L27-L65)
- [svg_dom.dart:123-332](file://lib/src/animation/svg_dom.dart#L123-L332)
- [animated_svg_painter.dart:48-136](file://lib/src/animation/animated_svg_painter.dart#L48-L136)
- [animated_svg_painter_use.dart:1-625](file://lib/src/animation/animated_svg_painter_use.dart#L1-L625)
- [animated_svg_painter_tree.dart:1-457](file://lib/src/animation/animated_svg_painter_tree.dart#L1-L457)
- [animated_svg_picture_hit_test_use.dart:1-339](file://lib/src/animation/animated_svg_picture_hit_test_use.dart#L1-L339)

**Section sources**
- [use_symbol_inheritance_test.dart:1-1202](file://test/animation/use_symbol_inheritance_test.dart#L1-L1202)
- [css_cascade.dart:1-675](file://lib/src/animation/css_cascade.dart#L1-L675)
- [animated_svg_painter_use.dart:1-625](file://lib/src/animation/animated_svg_painter_use.dart#L1-L625)
- [animated_svg_picture_hit_test_use.dart:1-339](file://lib/src/animation/animated_svg_picture_hit_test_use.dart#L1-L339)

## Performance Considerations
- Recursion depth is capped to prevent excessive memory and CPU usage during nested `<use>` chains.
- The DOM caches raw attribute values for efficient CSS selector matching.
- Static subtrees may be cached as pictures when animations are absent, reducing repaint costs.
- CSS cascade resolver uses caching for matching rules to improve performance.
- Custom property resolution includes iteration limits to prevent infinite recursion.
- Use inheritance context is managed efficiently to minimize memory overhead.

## Troubleshooting Guide
- If a `<use>` does not render, verify the `href` attribute references an allowed tag and exists in the document.
- Circular references or deep nesting beyond the limit will be silently aborted; simplify the structure or reduce nesting.
- Attribute precedence: explicit attributes on the referenced element override `<use>` attributes; style on `<use>` overrides inline attributes.
- For symbol scaling issues, ensure the `<use>` specifies `width/height` and the `<symbol>` has a valid `viewBox` and `preserveAspectRatio`.
- CSS cascade issues: verify specificity calculations and inheritance patterns are working correctly.
- Custom property resolution: check that variables are properly defined in the use chain or referenced element.
- Pointer-events inheritance: ensure use element pointer-events are properly inherited by referenced content.

**Section sources**
- [animated_svg_painter_use.dart:159-172](file://lib/src/animation/animated_svg_painter_use.dart#L159-L172)
- [animated_svg_picture_hit_test_use.dart:9-23](file://lib/src/animation/animated_svg_picture_hit_test_use.dart#L9-L23)
- [use_symbol_inheritance_test.dart:126-159](file://test/animation/use_symbol_inheritance_test.dart#L126-L159)

## Conclusion
The Flutter SVG library implements robust element symbol inheritance by resolving `<use>` references, applying symbol-specific viewport transforms, and enforcing strict recursion limits. The enhanced CSS cascade system provides comprehensive specificity calculations, inheritance resolution, and custom property support that flows through use boundaries. Attribute propagation follows predictable precedence rules, and both rendering and hit testing mirror these behaviors with proper use context inheritance. The extensive test suite validates correctness across common scenarios, nested references, CSS cascade behavior, and edge cases like circular dependencies and custom property resolution.