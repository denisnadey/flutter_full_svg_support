# Use Element Symbol Inheritance

<cite>
**Referenced Files in This Document**
- [use_symbol_inheritance_test.dart](file://test/animation/use_symbol_inheritance_test.dart)
- [symbol_animation_test.dart](file://test/animation/symbol_animation_test.dart)
- [use_symbol_advanced_test.dart](file://test/animation/use_symbol_advanced_test.dart)
- [css_cascade.dart](file://lib/src/animation/css_cascade.dart)
- [css_variables_calc.dart](file://lib/src/animation/css_variables_calc.dart)
- [animated_svg_painter_use.dart](file://lib/src/animation/animated_svg_painter_use.dart)
- [animated_svg_painter_tree.dart](file://lib/src/animation/animated_svg_painter_tree.dart)
- [animated_svg_picture_hit_test_use.dart](file://lib/src/animation/animated_svg_picture_hit_test_use.dart)
- [svg_parser.dart](file://lib/src/animation/svg_parser.dart)
- [svg_dom.dart](file://lib/src/animation/svg_dom.dart)
- [svg_parser_elements.dart](file://lib/src/animation/svg_parser_elements.dart)
- [animated_svg_painter.dart](file://lib/src/animation/animated_svg_painter.dart)
- [smil_parser.dart](file://lib/src/animation/smil/smil_parser.dart)
- [animated_svg_painter_use_constants.dart](file://lib/src/animation/animated_svg_painter_use_constants.dart)
- [animated_svg_painter_use_context.dart](file://lib/src/animation/animated_svg_painter_use_context.dart)
- [animated_svg_painter_use_foreign_object.dart](file://lib/src/animation/animated_svg_painter_use_foreign_object.dart)
- [css_cascade_specificity.dart](file://lib/src/animation/css_cascade_specificity.dart)
- [css_cascade_selector_matching.dart](file://lib/src/animation/css_cascade_selector_matching.dart)
- [css_cascade_resolution.dart](file://lib/src/animation/css_cascade_resolution.dart)
</cite>

## Update Summary
**Changes Made**
- Enhanced use element system with new specialized modules for constants, context management, and foreign object handling
- Improved CSS cascade resolution with better !important declaration handling in use contexts
- Enhanced selector matching with comprehensive shadow DOM boundary awareness
- Expanded CSS variable resolution system with proper inheritance tracking through use boundaries
- Added comprehensive foreign object viewport handling within use contexts

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [Enhanced CSS Cascade System](#enhanced-css-cascade-system)
7. [Use Element Inheritance Context](#use-element-inheritance-context)
8. [Comprehensive Symbol Animation Support](#comprehensive-symbol-animation-support)
9. [CSS Custom Properties Through Use Boundaries](#css-custom-properties-through-use-boundaries)
10. [Advanced Symbol Resolution](#advanced-symbol-resolution)
11. [Specialized Module Enhancements](#specialized-module-enhancements)
12. [Dependency Analysis](#dependency-analysis)
13. [Performance Considerations](#performance-considerations)
14. [Troubleshooting Guide](#troubleshooting-guide)
15. [Conclusion](#conclusion)

## Introduction
This document explains how the Flutter SVG library implements enhanced element symbol inheritance through the `<use>` element and `<symbol>` references with comprehensive animation support. The system now provides advanced symbol resolution, improved inheritance chain handling, and comprehensive symbol animation support that flows through use boundaries. It covers the parsing pipeline, rendering behavior, attribute propagation rules, CSS property inheritance, viewport transformations, recursion limits, animation coordinate inheritance, and hit-testing mechanics with enhanced CSS cascade behavior including class rules, ID rules, element type rules, specificity calculations, and inheritance patterns.

## Project Structure
The relevant implementation spans the animation pipeline, CSS cascade system, SMIL animation support, and extensive testing:
- Tests validate attribute propagation, symbol scaling, nested use recursion, CSS cascade behavior, hit testing, and comprehensive animation scenarios.
- The painter handles rendering of `<use>` and `<symbol>` references, applying transforms and clipping with animation coordinate inheritance.
- The DOM model stores parsed attributes and enables traversal and lookup with enhanced symbol resolution.
- The parser converts XML into a typed DOM with animatable attributes and SMIL animation support.
- The CSS cascade system provides comprehensive specificity calculations, inheritance resolution, and shadow DOM boundary respect.
- Custom properties support enables variables to flow through use boundaries with proper inheritance.
- SMIL animation parser provides comprehensive animation support including coordinate inheritance for animated elements within symbols.

```mermaid
graph TB
subgraph "Tests"
T1["use_symbol_inheritance_test.dart"]
T2["symbol_animation_test.dart"]
T3["use_symbol_advanced_test.dart"]
end
subgraph "CSS System"
C1["css_cascade.dart"]
C2["css_variables_calc.dart"]
C3["css_cascade_specificity.dart"]
C4["css_cascade_selector_matching.dart"]
C5["css_cascade_resolution.dart"]
end
subgraph "Animation System"
A1["smil_parser.dart"]
A2["animated_svg_painter_use.dart"]
A3["animated_svg_painter_tree.dart"]
A4["animated_svg_painter_use_constants.dart"]
A5["animated_svg_painter_use_context.dart"]
A6["animated_svg_painter_use_foreign_object.dart"]
end
subgraph "Parser"
P1["svg_parser.dart"]
P2["svg_parser_elements.dart"]
D1["svg_dom.dart"]
end
subgraph "Renderer"
R1["animated_svg_painter.dart"]
H1["animated_svg_picture_hit_test_use.dart"]
end
T1 --> C1
T2 --> A1
T3 --> C1
C1 --> R1
C2 --> R1
A1 --> R1
A2 --> R1
A3 --> R1
A4 --> R1
A5 --> R1
A6 --> R1
P1 --> D1
P2 --> D1
D1 --> R1
R1 --> H1
```

**Diagram sources**
- [use_symbol_inheritance_test.dart:1-1202](file://test/animation/use_symbol_inheritance_test.dart#L1-L1202)
- [symbol_animation_test.dart:1-74](file://test/animation/symbol_animation_test.dart#L1-L74)
- [use_symbol_advanced_test.dart:1-872](file://test/animation/use_symbol_advanced_test.dart#L1-L872)
- [css_cascade.dart:1-267](file://lib/src/animation/css_cascade.dart#L1-L267)
- [css_variables_calc.dart:1-1080](file://lib/src/animation/css_variables_calc.dart#L1-L1080)
- [smil_parser.dart:1-43](file://lib/src/animation/smil/smil_parser.dart#L1-L43)
- [animated_svg_painter_use.dart:1-809](file://lib/src/animation/animated_svg_painter_use.dart#L1-L809)
- [svg_parser.dart:27-65](file://lib/src/animation/svg_parser.dart#L27-L65)
- [svg_parser_elements.dart:3-138](file://lib/src/animation/svg_parser_elements.dart#L3-L138)
- [svg_dom.dart:123-332](file://lib/src/animation/svg_dom.dart#L123-L332)
- [animated_svg_painter.dart:48-136](file://lib/src/animation/animated_svg_painter.dart#L48-L136)
- [animated_svg_picture_hit_test_use.dart:1-339](file://lib/src/animation/animated_svg_picture_hit_test_use.dart#L1-L339)
- [animated_svg_painter_use_constants.dart:1-101](file://lib/src/animation/animated_svg_painter_use_constants.dart#L1-L101)
- [animated_svg_painter_use_context.dart:1-415](file://lib/src/animation/animated_svg_painter_use_context.dart#L1-L415)
- [animated_svg_painter_use_foreign_object.dart:1-127](file://lib/src/animation/animated_svg_painter_use_foreign_object.dart#L1-L127)
- [css_cascade_specificity.dart:1-74](file://lib/src/animation/css_cascade_specificity.dart#L1-L74)
- [css_cascade_selector_matching.dart:1-487](file://lib/src/animation/css_cascade_selector_matching.dart#L1-L487)
- [css_cascade_resolution.dart:1-140](file://lib/src/animation/css_cascade_resolution.dart#L1-L140)

**Section sources**
- [use_symbol_inheritance_test.dart:1-1202](file://test/animation/use_symbol_inheritance_test.dart#L1-L1202)
- [symbol_animation_test.dart:1-74](file://test/animation/symbol_animation_test.dart#L1-L74)
- [use_symbol_advanced_test.dart:1-872](file://test/animation/use_symbol_advanced_test.dart#L1-L872)
- [css_cascade.dart:1-267](file://lib/src/animation/css_cascade.dart#L1-L267)
- [css_variables_calc.dart:1-1080](file://lib/src/animation/css_variables_calc.dart#L1-L1080)
- [animated_svg_painter_use.dart:1-809](file://lib/src/animation/animated_svg_painter_use.dart#L1-L809)
- [smil_parser.dart:1-43](file://lib/src/animation/smil/smil_parser.dart#L1-L43)

## Core Components
- DOM Model: Stores parsed attributes, supports lookup by ID/class, and tracks animation presence with enhanced symbol resolution capabilities.
- Parser: Converts XML to DOM nodes, infers attribute types, preserves raw values for CSS matching, and extracts SMIL animations.
- CSS Cascade System: Implements comprehensive specificity calculations, inheritance resolution, shadow DOM boundary respect, and property precedence.
- SMIL Animation Parser: Extracts and processes SMIL animations including coordinate inheritance for elements within symbols.
- Painter: Renders the document, applies viewBox transforms, handles `<use>` and `<symbol>` references with inheritance context and animation coordinate inheritance.
- Hit Test: Performs pointer hit detection across `<use>` chains with recursion limits, pointer-events inheritance, and animation coordinate handling.
- CSS Variables: Supports custom properties flowing through use boundaries with proper inheritance and variable resolution.
- Tests: Validate attribute propagation, symbol scaling, nested references, CSS cascade behavior, circular reference protection, animation inheritance, and comprehensive symbol scenarios.

**Section sources**
- [svg_dom.dart:123-332](file://lib/src/animation/svg_dom.dart#L123-L332)
- [css_cascade.dart:277-396](file://lib/src/animation/css_cascade.dart#L277-L396)
- [css_variables_calc.dart:44-98](file://lib/src/animation/css_variables_calc.dart#L44-L98)
- [animated_svg_painter_use.dart:107-243](file://lib/src/animation/animated_svg_painter_use.dart#L107-L243)
- [animated_svg_picture_hit_test_use.dart:8-22](file://lib/src/animation/animated_svg_picture_hit_test_use.dart#L8-L22)
- [use_symbol_inheritance_test.dart:1-1202](file://test/animation/use_symbol_inheritance_test.dart#L1-L1202)
- [symbol_animation_test.dart:1-74](file://test/animation/symbol_animation_test.dart#L1-L74)

## Architecture Overview
The system parses SVG XML into a typed DOM with SMIL animation support, then renders it using a custom painter with enhanced CSS cascade support. The `<use>` element references another element by ID and inherits CSS properties from the referencing element with comprehensive animation coordinate inheritance. The CSS cascade system provides comprehensive specificity calculations, inheritance resolution, shadow DOM boundary respect, and animation support that flows through use boundaries.

```mermaid
sequenceDiagram
participant Test as "Test Suite"
participant Parser as "SvgParser"
participant SMIL as "SmilParser"
participant DOM as "SvgDocument/SvgNode"
participant CSS as "CssCascadeResolver"
participant SMILAnim as "SmilAnimation"
participant Painter as "AnimatedSvgPainter"
participant UseExt as "_paintUse/_paintSymbolReference"
Test->>Parser : parse(svgXml)
Parser->>DOM : create nodes and attributes
Test->>SMIL : parseAnimations(document)
SMIL->>SMILAnim : extract SMIL animations
Test->>CSS : resolveProperty(node, property)
CSS->>DOM : resolve specificity and inheritance with shadow boundaries
Test->>Painter : paint(document)
Painter->>UseExt : traverse use/symbol references with animation context
UseExt->>DOM : resolve hrefId and apply transforms
UseExt->>CSS : resolve inherited properties with cascade
UseExt->>SMILAnim : apply animation coordinate inheritance
UseExt-->>Painter : render referenced subtree with animation
```

**Diagram sources**
- [svg_parser.dart:31-63](file://lib/src/animation/svg_parser.dart#L31-L63)
- [smil_parser.dart:21-41](file://lib/src/animation/smil/smil_parser.dart#L21-L41)
- [css_cascade.dart:295-396](file://lib/src/animation/css_cascade.dart#L295-L396)
- [animated_svg_painter_use.dart:159-233](file://lib/src/animation/animated_svg_painter_use.dart#L159-L233)

## Detailed Component Analysis

### DOM Model and Attribute Types
- Nodes store tag, id, class, and a map of animatable attributes with types (number, length, color, transform, path, points, string, list, url).
- Raw attribute values are preserved for CSS selector matching with enhanced symbol resolution.
- Lookup helpers enable finding elements by id/class/tag recursively with SMIL animation support.
- CSS custom properties are stored using a weak map pattern via attribute storage for inheritance.

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
+CssCustomProperties cssCustomProperties
+findById(id) SvgNode
+findByClass(className) SvgNode[]
+findByTag(tagName) SvgNode[]
+getRawAttributeValue(name) String
+parseAndSetCustomProperties(styleString)
}
class SvgDocument {
+SvgNode root
+Rect viewBox
+double width
+double height
+CssSelectorRule[] cssSelectorRules
+getElementById(id) SvgNode
+getElementsByClass(className) SvgNode[]
+getElementsByTag(tagName) SvgNode[]
}
class CssCustomProperties {
+Map~String, String~ _properties
+get(name) String
+set(name, value)
+has(name) bool
+all Map~String, String~
+copy() CssCustomProperties
}
SvgDocument --> SvgNode : "root"
SvgNode --> SvgNode : "children"
SvgNode --> CssCustomProperties : "cssCustomProperties"
```

**Diagram sources**
- [svg_dom.dart:123-332](file://lib/src/animation/svg_dom.dart#L123-L332)
- [css_variables_calc.dart:37-89](file://lib/src/animation/css_variables_calc.dart#L37-L89)

**Section sources**
- [svg_dom.dart:123-332](file://lib/src/animation/svg_dom.dart#L123-L332)
- [css_variables_calc.dart:37-89](file://lib/src/animation/css_variables_calc.dart#L37-L89)

### Parser Pipeline
- Parses XML into DOM nodes, infers attribute types, extracts direct text content for text nodes, and captures SMIL animations.
- Skips style elements during element parsing; CSS is handled separately with comprehensive rule extraction.
- Root attributes (viewBox, width, height) are captured for viewport calculations.
- SMIL animations are extracted from both element attributes and CSS keyframe animations.

```mermaid
flowchart TD
Start(["XML Input"]) --> ParseDoc["Parse XmlDocument"]
ParseDoc --> FindSvg["Find root <svg>"]
FindSvg --> ParseFilters["Parse <filter> in <defs>"]
ParseFilters --> ParseCSS["@keyframes and selectors"]
ParseCSS --> ParseSMIL["Extract SMIL animations"]
ParseSMIL --> ParseRoot["Parse root <svg> element"]
ParseRoot --> ExtractAttrs["Infer attribute types<br/>and raw values"]
ExtractAttrs --> RecurseChildren["Recursively parse children"]
RecurseChildren --> BuildDoc["Build SvgDocument with viewBox/size<br/>and animation support"]
BuildDoc --> End(["DOM Ready with SMIL"])
```

**Diagram sources**
- [svg_parser.dart:31-63](file://lib/src/animation/svg_parser.dart#L31-L63)
- [svg_parser_elements.dart:3-49](file://lib/src/animation/svg_parser_elements.dart#L3-L49)
- [smil_parser.dart:21-41](file://lib/src/animation/smil/smil_parser.dart#L21-L41)

**Section sources**
- [svg_parser.dart:27-65](file://lib/src/animation/svg_parser.dart#L27-L65)
- [svg_parser_elements.dart:3-138](file://lib/src/animation/svg_parser_elements.dart#L3-L138)
- [smil_parser.dart:21-41](file://lib/src/animation/smil/smil_parser.dart#L21-L41)

### Use Element Rendering and Attribute Propagation
- The painter resolves the referenced element by ID from the `href` attribute with enhanced symbol resolution.
- For `<symbol>` references, it computes a viewport transform based on `width/height` and `preserveAspectRatio`, then clips and transforms the canvas before rendering children with animation coordinate inheritance.
- For `<svg>` references, it applies similar viewport logic and then paints the referenced SVG subtree with animation context.
- For other referenced tags, it paints the referenced node directly after translating by `x/y` with proper animation inheritance.

```mermaid
sequenceDiagram
participant Canvas as "ui.Canvas"
participant Painter as "AnimatedSvgPainter"
participant UseExt as "_paintUse"
participant SymExt as "_paintSymbolReference"
participant SvgExt as "_paintSvgUseReference"
participant AnimCtx as "Animation Coordinate Context"
Painter->>UseExt : _paintUse(node, useStack, useContext)
UseExt->>UseExt : extractHrefId(node)
UseExt->>UseExt : check recursion depth
UseExt->>DOM : document.root.findById(hrefId)
alt referenced is symbol
UseExt->>SymExt : _paintSymbolReference(...)
SymExt->>AnimCtx : getUseTransform() for coordinate inheritance
AnimCtx->>Canvas : apply transform with animation context
SymExt->>Canvas : apply viewport transform and clip
SymExt->>Painter : paint symbol children with animation
else referenced is svg
UseExt->>SvgExt : _paintSvgUseReference(...)
SvgExt->>AnimCtx : getUseTransform() for coordinate inheritance
AnimCtx->>Canvas : apply transform with animation context
SvgExt->>Canvas : apply viewport transform and clip
SvgExt->>Painter : paint referenced svg subtree
else other tag
UseExt->>Canvas : translate by x,y with animation context
UseExt->>Painter : paint referenced node
end
```

**Diagram sources**
- [animated_svg_painter_use.dart:159-253](file://lib/src/animation/animated_svg_painter_use.dart#L159-L253)
- [animated_svg_painter_use.dart:358-386](file://lib/src/animation/animated_svg_painter_use.dart#L358-L386)

**Section sources**
- [animated_svg_painter_use.dart:159-253](file://lib/src/animation/animated_svg_painter_use.dart#L159-L253)
- [animated_svg_painter_use.dart:358-386](file://lib/src/animation/animated_svg_painter_use.dart#L358-L386)

### Symbol ViewBox and PreserveAspectRatio
- When referencing a `<symbol>`, the use element defines the viewport (`width/height`) and the symbol defines the `viewBox` and `preserveAspectRatio`.
- The renderer computes a destination rectangle and applies a scale and translate transform, optionally clipping to the viewport with animation coordinate inheritance.

```mermaid
flowchart TD
A["Use node with width/height"] --> B["Symbol node with viewBox and preserveAspectRatio"]
B --> C["Compute destination rect from preserveAspectRatio"]
C --> D["Calculate scaleX/scaleY and translateX/translateY"]
D --> E["Apply transform to canvas with animation context"]
E --> F["Optionally clip to viewport"]
F --> G["Paint symbol children with animation inheritance"]
```

**Diagram sources**
- [animated_svg_painter_use.dart:213-233](file://lib/src/animation/animated_svg_painter_use.dart#L213-L233)

**Section sources**
- [animated_svg_painter_use.dart:213-233](file://lib/src/animation/animated_svg_painter_use.dart#L213-L233)

### Nested Use References and Recursion Limits
- The implementation enforces a maximum recursion depth (matching Blink) to prevent infinite loops and excessive resource usage.
- Circular references are detected by tracking visited IDs in the use stack and shadow root boundaries.
- Tests verify correct behavior for up to 12 levels of nesting and protection against cycles with comprehensive animation support.

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
Allowed --> |Yes| CreateContext["Create _UseInheritanceContext with shadow root"]
CreateContext --> Paint["Paint referenced node with transforms and animation context"]
```

**Diagram sources**
- [animated_svg_painter_use.dart:159-172](file://lib/src/animation/animated_svg_painter_use.dart#L159-L172)
- [animated_svg_picture_hit_test_use.dart:9-23](file://lib/src/animation/animated_svg_picture_hit_test_use.dart#L9-L23)

**Section sources**
- [animated_svg_painter_use.dart:3-5](file://lib/src/animation/animated_svg_painter_use.dart#L3-L5)
- [animated_svg_picture_hit_test_use.dart:3-5](file://lib/src/animation/animated_svg_picture_hit_test_use.dart#L3-L5)

### Hit Testing Across Use References
- Hit testing mirrors rendering: it resolves the referenced element, applies the same viewport transforms, and checks whether the pointer falls within the transformed viewport with animation coordinate handling.
- It traverses symbol children in reverse order (top-most first) and recurses into the referenced subtree with the same use stack protections and animation context.
- Pointer-events inheritance is tracked through use boundaries for proper event handling with animation support.

```mermaid
sequenceDiagram
participant HT as "_AnimatedSvgPictureState"
participant UseHT as "_hitTestUseReference"
participant SymHT as "_applyUseViewportTransform"
participant AnimCtx as "Animation Coordinate Context"
HT->>UseHT : _hitTestUseReference(useNode, point, transform, useStack)
UseHT->>UseHT : extractHrefId and check recursion
UseHT->>DOM : find referenced node
UseHT->>SymHT : compute viewport transform and clip
alt symbol reference
UseHT->>AnimCtx : getUseTransform() for coordinate inheritance
AnimCtx->>HT : transform point with animation context
HT->>HT : traverse symbol children (reverse)
HT-->>UseHT : return first matching child
else svg or other
UseHT->>AnimCtx : getUseTransform() for coordinate inheritance
AnimCtx->>HT : transform point with animation context
UseHT->>HT : recurse into referenced node
end
```

**Diagram sources**
- [animated_svg_picture_hit_test_use.dart:9-91](file://lib/src/animation/animated_svg_picture_hit_test_use.dart#L9-L91)

**Section sources**
- [animated_svg_picture_hit_test_use.dart:9-91](file://lib/src/animation/animated_svg_picture_hit_test_use.dart#L9-L91)

### Attribute Propagation Rules Verified by Tests
- Fill/stroke/opacity/font properties on `<use>` propagate to referenced elements with comprehensive animation support.
- Explicit attributes on referenced elements override inherited attributes from `<use>` with proper animation inheritance.
- Style attribute on `<use>` overrides inline attributes with CSS cascade precedence.
- Transform on `<use>` composes with referenced element transforms with animation coordinate inheritance.
- Nested `<use>` chains render correctly up to the recursion limit with comprehensive animation support.
- Circular references are prevented without crashing with proper animation context handling.
- CSS class rules, ID rules, and element type rules are properly resolved through use boundaries with shadow DOM respect.
- Inheritance patterns follow CSS cascade specifications with proper specificity calculations and animation support.
- Animation inheritance flows correctly through use boundaries with coordinate transformation.

```mermaid
flowchart TD
U["Use node"] --> |propagate| Ref["Referenced element"]
Ref --> |explicit| Override["Explicit attributes on referenced element"]
U --> |style| Priority["Style attribute takes precedence"]
U --> |transform| Compose["Compose with referenced transform<br/>and animation coordinate inheritance"]
U --> |nested| Depth["Respect recursion depth limit<br/>with animation context"]
U --> |CSS cascade| Cascade["Proper specificity resolution<br/>with shadow DOM boundaries"]
U --> |animations| AnimInherit["Animation inheritance through boundaries"]
```

**Diagram sources**
- [use_symbol_inheritance_test.dart:11-159](file://test/animation/use_symbol_inheritance_test.dart#L11-L159)

**Section sources**
- [use_symbol_inheritance_test.dart:11-159](file://test/animation/use_symbol_inheritance_test.dart#L11-L159)

## Enhanced CSS Cascade System

### Comprehensive Specificity Calculations
The CSS cascade system implements full CSS specificity calculations including:
- ID selectors (#id) with highest priority
- Class selectors (.class) and attribute selectors ([attr]) with proper shadow DOM boundary respect
- Element type selectors (rect, circle) and pseudo-class selectors (:hover, :active)
- Universal selector (*) with zero specificity
- Compound selectors combined with proper specificity arithmetic
- Complex selectors with combinators that respect shadow DOM boundaries (use/symbol)

### Shadow DOM Boundary Respect
The system respects shadow DOM boundaries for CSS selector matching:
- Combinator selectors (descendant, child, sibling) do not pierce through use/symbol boundaries
- CSS rules defined inside symbols apply only within that symbol scope
- CSS rules defined inside use elements apply only within that use scope
- Proper selector matching with shadow boundary awareness for complex selectors

### CSS Property Inheritance Tracking
The system maintains comprehensive inheritance tracking for:
- Color properties (color, fill, stroke) with animation support
- Font properties (font-family, font-size, font-weight) with animation support
- Text properties (text-align, white-space, word-spacing) with animation support
- SVG-specific properties (stroke-width, stroke-linecap, paint-order) with animation support
- Visibility properties (visibility, pointer-events, cursor) with animation support
- Text decoration and emphasis properties with animation support

### CSS Variable Resolution Through Use Boundaries
Custom properties (CSS variables) flow through use boundaries with:
- Proper inheritance from use elements to referenced content with animation context
- Support for var(--variable-name) syntax with fallback values and nested fallbacks
- Resolution order: use element variables > parent variables > referenced element variables
- Infinite recursion prevention with iteration limits and animation coordinate inheritance
- Integration with SMIL animation system for variable-based animations

**Section sources**
- [css_cascade.dart:18-267](file://lib/src/animation/css_cascade.dart#L18-L267)
- [css_variables_calc.dart:101-173](file://lib/src/animation/css_variables_calc.dart#L101-L173)

## Use Element Inheritance Context

### Inheritance Context Management
The `_UseInheritanceContext` class manages CSS property inheritance across use boundaries with comprehensive animation support:
- Captures use element properties for inheritance to referenced content with animation coordinate context
- Maintains parent context for nested use chains with proper animation inheritance
- Provides CSS rules from document for proper class/id resolution with shadow DOM respect
- Handles CSS custom property lookup through use boundaries with variable resolution
- Manages shadow root boundaries for circular reference detection and animation context

### Inherited Property Resolution
Properties that flow through use boundaries include:
- All CSS inheritable properties (color, font, stroke, fill, visibility) with animation support
- CSS custom properties (starting with --) with variable resolution and fallback handling
- Presentation attributes on use elements with animation coordinate inheritance
- Style attribute values on use elements with CSS cascade precedence
- Animation properties that inherit through use boundaries with proper coordinate transformation

Properties that do NOT flow through use boundaries:
- Non-inherited properties (opacity, transform, display, clip-path, mask, filter) with animation context
- Positioning properties (x, y coordinates) with animation coordinate inheritance
- Structural properties affecting use element itself with animation support

### CSS Rule Resolution Through Use Boundaries
The system resolves CSS rules for referenced elements with comprehensive animation support:
- Inline styles on referenced elements take highest precedence with animation context
- Document CSS rules matching referenced element (class, id, element type) with shadow DOM respect
- Presentation attributes on referenced elements with animation inheritance
- Inherited values from use element chain with proper animation coordinate transformation
- Parent element inherited values for non-inherited properties with animation context

**Section sources**
- [animated_svg_painter_use_context.dart:33-415](file://lib/src/animation/animated_svg_painter_use_context.dart#L33-L415)
- [animated_svg_painter_tree.dart:27-226](file://lib/src/animation/animated_svg_painter_tree.dart#L27-L226)

## Comprehensive Symbol Animation Support

### Animation Coordinate Inheritance
The system provides comprehensive animation coordinate inheritance for elements within symbols:
- Animation transforms are calculated relative to the use element's coordinate system
- Nested use elements provide proper coordinate hierarchy for animation inheritance
- Transform composition includes use element transforms, symbol viewport transforms, and animation transforms
- Animation timing and interpolation respect the use element's animation context

### Animation Target Resolution
Animation targets within symbols are resolved with proper coordinate context:
- Animation targets reference elements within the symbol scope with animation inheritance
- Animation transforms are applied in the correct coordinate space with use element context
- Animation properties inherit through use boundaries with proper coordinate transformation
- SMIL animations work correctly with symbol references and use element transforms

### Animation State Management
The system manages animation state across use boundaries:
- Animation instances maintain proper coordinate context when referenced through use elements
- Animation timing respects use element positioning and symbol viewport transformations
- Animation inheritance preserves animation state across nested use elements
- Animation cleanup properly handles use element lifecycle and symbol references

**Section sources**
- [symbol_animation_test.dart:1-74](file://test/animation/symbol_animation_test.dart#L1-L74)
- [use_symbol_advanced_test.dart:278-357](file://test/animation/use_symbol_advanced_test.dart#L278-L357)
- [animated_svg_painter_use.dart:358-386](file://lib/src/animation/animated_svg_painter_use.dart#L358-L386)

## CSS Custom Properties Through Use Boundaries

### Variable Resolution Mechanism
CSS variables can flow through use boundaries through:
- Direct use element custom properties (style attribute) with animation context
- Parent element custom properties in the use chain with variable resolution
- Referenced element custom properties for non-inherited properties with animation support
- Proper fallback value resolution when variables are undefined with nested fallback support
- Integration with SMIL animation system for variable-based animations

### Variable Resolution Order
The system resolves CSS variables in this order:
1. Use element custom properties (highest priority) with animation context
2. Parent element custom properties in use chain with variable resolution
3. Referenced element custom properties with animation inheritance
4. CSS variable fallback values with nested fallback support
5. Empty string if no resolution possible with animation context

### Variable Storage and Access
Custom properties are stored using:
- Node-level custom property stores for inheritance with animation support
- Weak map pattern via attribute storage with proper cleanup
- Integration with CSS cascade system for rule-based variable lookup
- Support for nested use element chains with proper variable resolution

**Section sources**
- [css_variables_calc.dart:44-98](file://lib/src/animation/css_variables_calc.dart#L44-L98)
- [css_variables_calc.dart:101-173](file://lib/src/animation/css_variables_calc.dart#L101-L173)

## Advanced Symbol Resolution

### Enhanced Symbol Reference Resolution
The system provides advanced symbol reference resolution with comprehensive animation support:
- Symbol references resolve to proper viewport and preserveAspectRatio contexts
- Symbol content is properly clipped and transformed according to use element specifications
- Symbol references support nested use elements with proper coordinate inheritance
- Symbol references handle animation inheritance with proper coordinate transformation

### Shadow DOM Boundary Handling
The system respects shadow DOM boundaries for symbol references:
- CSS selectors within symbols do not affect elements outside the symbol
- CSS selectors outside symbols do not affect elements inside symbols
- Animation targets within symbols are properly scoped to symbol boundaries
- Custom properties flow through symbol boundaries with proper context

### ID Namespace Collision Prevention
The system prevents ID namespace collisions in symbol references:
- Internal IDs within symbols are scoped to use element instances
- Multiple use references to the same symbol content use unique ID namespaces
- Filter, gradient, and clip-path references are properly scoped within symbol instances
- Animation references within symbols use proper coordinate context

**Section sources**
- [animated_svg_painter_use_context.dart:331-335](file://lib/src/animation/animated_svg_painter_use_context.dart#L331-L335)
- [use_symbol_advanced_test.dart:527-644](file://test/animation/use_symbol_advanced_test.dart#L527-L644)

## Specialized Module Enhancements

### Use Constants Module
The new `animated_svg_painter_use_constants.dart` module centralizes constant definitions for use element handling:
- Maximum recursion depth constants matching Blink implementation
- Comprehensive inheritable property sets for CSS and foreign object handling
- Global CSS rule storage for document-wide styling
- Foreign object inheritable property definitions

### Use Context Module
The `animated_svg_painter_use_context.dart` module provides enhanced context management:
- Complete CSS cascade resolution with !important handling in use contexts
- Shadow boundary-aware property resolution
- Transform composition for nested use elements
- Scoped ID generation for symbol instance isolation
- Animation coordinate inheritance support

### Foreign Object Handling Module
The `animated_svg_painter_use_foreign_object.dart` module extends foreign object support:
- Foreign object viewport application with clipping and overflow handling
- Nested SVG viewport transforms within foreign objects
- Foreign object required extensions validation
- Proper coordinate system management for mixed content

**Section sources**
- [animated_svg_painter_use_constants.dart:1-101](file://lib/src/animation/animated_svg_painter_use_constants.dart#L1-L101)
- [animated_svg_painter_use_context.dart:1-415](file://lib/src/animation/animated_svg_painter_use_context.dart#L1-L415)
- [animated_svg_painter_use_foreign_object.dart:1-127](file://lib/src/animation/animated_svg_painter_use_foreign_object.dart#L1-L127)

## Dependency Analysis
- Tests depend on the parser, CSS cascade system, SMIL animation parser, and animation pipeline to validate rendering behavior and comprehensive animation scenarios.
- The painter depends on the DOM model, CSS cascade resolver, SMIL animation system, and use extension for reference resolution with animation context.
- The hit-test extension mirrors the painter's logic for pointer events with use context inheritance and animation coordinate handling.
- CSS cascade system provides specificity calculations, inheritance resolution, shadow DOM boundary respect, and animation support for all rendering operations.
- SMIL animation parser provides comprehensive animation extraction and processing with coordinate inheritance support.

```mermaid
graph LR
Tests["use_symbol_inheritance_test.dart<br/>symbol_animation_test.dart<br/>use_symbol_advanced_test.dart"] --> Parser["svg_parser.dart"]
Tests --> SMIL["smil_parser.dart"]
Tests --> CSS["css_cascade.dart"]
Tests --> DOM["svg_dom.dart"]
Parser --> DOM
SMIL --> DOM
DOM --> CSS
CSS --> Painter["animated_svg_painter.dart"]
Painter --> UseExt["animated_svg_painter_use.dart"]
Painter --> TreeExt["animated_svg_painter_tree.dart"]
Painter --> HitExt["animated_svg_picture_hit_test_use.dart"]
Painter --> UseConst["animated_svg_painter_use_constants.dart"]
Painter --> UseCtx["animated_svg_painter_use_context.dart"]
Painter --> FOExt["animated_svg_painter_use_foreign_object.dart"]
```

**Diagram sources**
- [use_symbol_inheritance_test.dart:1-1202](file://test/animation/use_symbol_inheritance_test.dart#L1-L1202)
- [symbol_animation_test.dart:1-74](file://test/animation/symbol_animation_test.dart#L1-L74)
- [use_symbol_advanced_test.dart:1-872](file://test/animation/use_symbol_advanced_test.dart#L1-L872)
- [css_cascade.dart:1-267](file://lib/src/animation/css_cascade.dart#L1-L267)
- [css_variables_calc.dart:1-1080](file://lib/src/animation/css_variables_calc.dart#L1-L1080)
- [smil_parser.dart:1-43](file://lib/src/animation/smil/smil_parser.dart#L1-L43)
- [svg_parser.dart:27-65](file://lib/src/animation/svg_parser.dart#L27-L65)
- [svg_dom.dart:123-332](file://lib/src/animation/svg_dom.dart#L123-L332)
- [animated_svg_painter.dart:48-136](file://lib/src/animation/animated_svg_painter.dart#L48-L136)
- [animated_svg_painter_use.dart:1-809](file://lib/src/animation/animated_svg_painter_use.dart#L1-L809)
- [animated_svg_painter_tree.dart:1-457](file://lib/src/animation/animated_svg_painter_tree.dart#L1-L457)
- [animated_svg_picture_hit_test_use.dart:1-339](file://lib/src/animation/animated_svg_picture_hit_test_use.dart#L1-L339)
- [animated_svg_painter_use_constants.dart:1-101](file://lib/src/animation/animated_svg_painter_use_constants.dart#L1-L101)
- [animated_svg_painter_use_context.dart:1-415](file://lib/src/animation/animated_svg_painter_use_context.dart#L1-L415)
- [animated_svg_painter_use_foreign_object.dart:1-127](file://lib/src/animation/animated_svg_painter_use_foreign_object.dart#L1-L127)

**Section sources**
- [use_symbol_inheritance_test.dart:1-1202](file://test/animation/use_symbol_inheritance_test.dart#L1-L1202)
- [symbol_animation_test.dart:1-74](file://test/animation/symbol_animation_test.dart#L1-L74)
- [use_symbol_advanced_test.dart:1-872](file://test/animation/use_symbol_advanced_test.dart#L1-L872)
- [css_cascade.dart:1-267](file://lib/src/animation/css_cascade.dart#L1-L267)
- [css_variables_calc.dart:1-1080](file://lib/src/animation/css_variables_calc.dart#L1-L1080)
- [animated_svg_painter_use.dart:1-809](file://lib/src/animation/animated_svg_painter_use.dart#L1-L809)
- [animated_svg_picture_hit_test_use.dart:1-339](file://lib/src/animation/animated_svg_picture_hit_test_use.dart#L1-L339)
- [smil_parser.dart:1-43](file://lib/src/animation/smil/smil_parser.dart#L1-L43)

## Performance Considerations
- Recursion depth is capped to prevent excessive memory and CPU usage during nested `<use>` chains with animation support.
- The DOM caches raw attribute values for efficient CSS selector matching with shadow DOM boundary respect.
- Static subtrees may be cached as pictures when animations are absent, reducing repaint costs with animation context.
- CSS cascade resolver uses caching for matching rules to improve performance with shadow DOM boundary respect.
- Custom property resolution includes iteration limits to prevent infinite recursion with animation coordinate handling.
- Use inheritance context is managed efficiently to minimize memory overhead with comprehensive animation support.
- SMIL animation system provides optimized animation processing with coordinate inheritance and transform composition.

## Troubleshooting Guide
- If a `<use>` does not render, verify the `href` attribute references an allowed tag and exists in the document with proper symbol resolution.
- Circular references or deep nesting beyond the limit will be silently aborted; simplify the structure or reduce nesting with animation context.
- Attribute precedence: explicit attributes on the referenced element override `<use>` attributes; style on `<use>` overrides inline attributes with CSS cascade precedence.
- For symbol scaling issues, ensure the `<use>` specifies `width/height` and the `<symbol>` has a valid `viewBox` and `preserveAspectRatio` with animation support.
- CSS cascade issues: verify specificity calculations and inheritance patterns are working correctly with shadow DOM boundary respect.
- Custom property resolution: check that variables are properly defined in the use chain or referenced element with variable resolution support.
- Pointer-events inheritance: ensure use element pointer-events are properly inherited by referenced content with animation context.
- Animation inheritance issues: verify that animation coordinates are properly inherited through use boundaries with transform composition.
- SMIL animation problems: check that animation targets are properly resolved within symbol scopes with coordinate context.

**Section sources**
- [animated_svg_painter_use.dart:159-172](file://lib/src/animation/animated_svg_painter_use.dart#L159-L172)
- [animated_svg_picture_hit_test_use.dart:9-23](file://lib/src/animation/animated_svg_picture_hit_test_use.dart#L9-L23)
- [use_symbol_inheritance_test.dart:126-159](file://test/animation/use_symbol_inheritance_test.dart#L126-L159)
- [symbol_animation_test.dart:7-41](file://test/animation/symbol_animation_test.dart#L7-L41)

## Conclusion
The Flutter SVG library implements robust and comprehensive element symbol inheritance by resolving `<use>` references, applying symbol-specific viewport transforms, enforcing strict recursion limits, and providing advanced animation support. The enhanced CSS cascade system provides comprehensive specificity calculations, inheritance resolution, shadow DOM boundary respect, and custom property support that flows through use boundaries with animation context. The system now supports comprehensive symbol animation with coordinate inheritance, transform composition, and proper animation state management. Attribute propagation follows predictable precedence rules with animation support, and both rendering and hit testing mirror these behaviors with proper use context inheritance and animation coordinate handling. The extensive test suite validates correctness across common scenarios, nested references, CSS cascade behavior, edge cases like circular dependencies, custom property resolution, and comprehensive animation inheritance through use boundaries.