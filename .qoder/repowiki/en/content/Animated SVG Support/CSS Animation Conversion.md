# CSS Animation Conversion

<cite>
**Referenced Files in This Document**
- [ANIMATION.md](file://ANIMATION.md)
- [ARCHITECTURE.md](file://ARCHITECTURE.md)
- [css_animations_parser.dart](file://lib/src/animation/css_animations_parser.dart)
- [css_animations_models.dart](file://lib/src/animation/css_animations_models.dart)
- [css_cascade.dart](file://lib/src/animation/css_cascade.dart)
- [css_variables_calc.dart](file://lib/src/animation/css_variables_calc.dart)
- [css_shorthand_expansion.dart](file://lib/src/animation/css_shorthand_expansion.dart)
- [transform_3d.dart](file://lib/src/animation/transform_3d.dart)
- [css_to_smil_converter.dart](file://lib/src/animation/css_to_smil_converter.dart)
- [css_to_smil_converter_core.dart](file://lib/src/animation/css_to_smil_converter_core.dart)
- [css_to_smil_converter_timing.dart](file://lib/src/animation/css_to_smil_converter_timing.dart)
- [css_to_smil_converter_transforms.dart](file://lib/src/animation/css_to_smil_converter_transforms.dart)
- [css_to_smil_converter_transforms_values.dart](file://lib/src/animation/css_to_smil_converter_transforms_values.dart)
- [interpolators_transform.dart](file://lib/src/animation/smil/interpolators_transform.dart)
- [smil_parser.dart](file://lib/src/animation/smil/smil_parser.dart)
- [smil_parser_css_extraction.dart](file://lib/src/animation/smil/smil_parser_css_extraction.dart)
- [smil_parser_animation_parsing.dart](file://lib/src/animation/smil/smil_parser_animation_parsing.dart)
- [smil_animation.dart](file://lib/src/animation/smil/smil_animation.dart)
- [timing_parser.dart](file://lib/src/animation/smil/timing_parser.dart)
- [css_cascade_specificity_test.dart](file://test/animation/css_cascade_specificity_test.dart)
- [css_variables_calc_test.dart](file://test/animation/css_variables_calc_test.dart)
- [css_3d_transforms_test.dart](file://test/animation/css_3d_transforms_test.dart)
- [css_shorthand_expansion_test.dart](file://test/animation/css_shorthand_expansion_test.dart)
- [css_animations_test.dart](file://test/animation/css_animations_test.dart)
- [css_transform_decomposition_test.dart](file://test/animation/css_transform_decomposition_test.dart)
- [stroke_dash_stop_color_test.dart](file://test/animation/stroke_dash_stop_color_test.dart)
- [transform_animation_test.dart](file://test/animation/transform_animation_test.dart)
- [css_selectors.dart](file://lib/src/animation/css_selectors.dart)
- [css_transform_calc_test.dart](file://test/animation/css_transform_calc_test.dart)
</cite>

## Update Summary
**Changes Made**
- Enhanced CSS cascade resolver with sophisticated selector matching that respects shadow DOM boundaries
- Added comprehensive CSS selector parsing with complex combinators (descendant, child, sibling)
- Implemented proper ancestor traversal with shadow boundary detection for use/symbol elements
- Enhanced CSS transform parsing with compound transforms and calc() expressions support
- Improved CSS transform normalization with full function string preservation
- Added comprehensive unit and angle parsing with calc() expression support

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [Enhanced CSS Features](#enhanced-css-features)
7. [Transform System Enhancements](#transform-system-enhancements)
8. [Dependency Analysis](#dependency-analysis)
9. [Performance Considerations](#performance-considerations)
10. [Troubleshooting Guide](#troubleshooting-guide)
11. [Conclusion](#conclusion)
12. [Appendices](#appendices)

## Introduction
This document explains the enhanced CSS animation to SMIL conversion system implemented in the project. The system now includes comprehensive CSS cascade support with sophisticated selector matching, complex CSS selectors with combinators, shadow DOM boundary detection, and advanced transform parsing capabilities. It covers how CSS @keyframes and animation properties are parsed, converted into SMIL animation objects, and integrated into the runtime timeline with full support for modern CSS features including custom properties, calc() expressions, 3D transforms, and sophisticated selector matching.

**Updated** Enhanced CSS cascade resolver with shadow DOM boundary detection and complex selector support

## Project Structure
The CSS-to-SMIL conversion system now includes enhanced CSS processing capabilities alongside the core animation pipeline. The architecture integrates cascade resolution, selector parsing, variable substitution, shorthand expansion, and 3D transform handling into the conversion workflow with sophisticated shadow DOM awareness.

```mermaid
graph TB
subgraph "Enhanced CSS Processing"
CS["CssCascadeResolver<br/>Shadow DOM Aware & Complex Selectors"]
CV["CssVariableResolver<br/>Custom Properties & Calc()"]
CE["CssShorthandExpander<br/>Property Expansion"]
T3D["Transform3DContext<br/>3D Matrix Operations"]
SEL["CssSelectorParser<br/>Complex Combinators & Pseudo-classes"]
END
subgraph "CSS Parsing"
CP["CssParser<br/>parseAnimationFromStyle()"]
CM["CssAnimation/CssKeyframes/CssKeyframe"]
END
subgraph "Enhanced Transform Processing"
CTV["CssTransformValues<br/>Full String Preservation & Calc()"]
CTN["CssTransformNormalizer<br/>Complete Function Strings"]
IT["InterpolatorsTransform<br/>Compound Transform Interpolation"]
END
subgraph "Conversion"
CTS["CssToSmilConverter.convert()"]
CTCore["_createSmilAnimation()"]
CTTim["_convertTimingFunction()"]
END
subgraph "SMIL Runtime"
SP["SmilParser.parseAnimations()"]
SA["SmilAnimation"]
TP["TimingParser"]
END
CS --> CP
CV --> CP
CE --> CP
SEL --> CS
T3D --> CTN
CP --> CTS
CM --> CTS
CTS --> CTCore
CTS --> CTTim
CTS --> CTN
CTN --> IT
SP --> CP
SP --> CS
SP --> CV
SP --> CE
SP --> SEL
SP --> T3D
SA --> TP
```

**Diagram sources**
- [css_cascade.dart:277-396](file://lib/src/animation/css_cascade.dart#L277-L396)
- [css_variables_calc.dart:92-154](file://lib/src/animation/css_variables_calc.dart#L92-L154)
- [css_shorthand_expansion.dart:7-31](file://lib/src/animation/css_shorthand_expansion.dart#L7-L31)
- [transform_3d.dart:329-373](file://lib/src/animation/transform_3d.dart#L329-L373)
- [css_animations_parser.dart:4-96](file://lib/src/animation/css_animations_parser.dart#L4-L96)
- [css_to_smil_converter.dart:15-67](file://lib/src/animation/css_to_smil_converter.dart#L15-L67)
- [css_to_smil_converter_transforms_values.dart:64-168](file://lib/src/animation/css_to_smil_converter_transforms_values.dart#L64-L168)
- [interpolators_transform.dart:12-78](file://lib/src/animation/smil/interpolators_transform.dart#L12-L78)
- [smil_parser.dart:12-38](file://lib/src/animation/smil/smil_parser.dart#L12-L38)
- [css_selectors.dart:447-665](file://lib/src/animation/css_selectors.dart#L447-L665)

**Section sources**
- [ARCHITECTURE.md:236-282](file://ARCHITECTURE.md#L236-L282)

## Core Components
- **Enhanced CSS Cascade Resolver**: Handles CSS specificity calculation, inheritance, and !important rules with sophisticated selector matching that respects shadow DOM boundaries for use/symbol elements.
- **CSS Variable Resolver**: Processes custom properties with var() references and calc() expressions, supporting inheritance and fallback values.
- **CSS Shorthand Expander**: Expands CSS shorthand properties (font, animation, transition, margin, padding, border) into longhand equivalents.
- **3D Transform System**: Provides comprehensive 3D transform support including matrix operations, perspective projection, and backface visibility.
- **Enhanced CSS Selector Parser**: Supports complex CSS selectors with combinators (descendant, child, sibling), pseudo-classes, and structural selectors.
- **Enhanced CSS Transform Values**: Preserves complete transform function strings during normalization for accurate interpolation with calc() expression support.
- **CSS Transform Normalization**: Maintains full CSS transform syntax with proper function signatures and parameter formatting.
- **Transform Interpolation System**: Handles compound transform interpolation through decomposition while preserving original string format.
- **CSS Parser**: Parses inline style animation properties and @keyframes blocks with enhanced selector support.
- **CSS to SMIL Converter**: Converts parsed CSS keyframes and animation properties into SMIL animation objects with full 3D transform support.
- **SMIL Parser**: Extracts native SMIL elements and CSS-derived animations from the DOM and builds a unified animation list.
- **SMIL Runtime**: Manages timelines, applies values to attributes, and supports syncbase timing and playback controls.

**Section sources**
- [css_cascade.dart:277-396](file://lib/src/animation/css_cascade.dart#L277-L396)
- [css_variables_calc.dart:92-154](file://lib/src/animation/css_variables_calc.dart#L92-L154)
- [css_shorthand_expansion.dart:7-31](file://lib/src/animation/css_shorthand_expansion.dart#L7-L31)
- [transform_3d.dart:22-327](file://lib/src/animation/transform_3d.dart#L22-L327)
- [css_to_smil_converter_transforms_values.dart:64-168](file://lib/src/animation/css_to_smil_converter_transforms_values.dart#L64-L168)
- [interpolators_transform.dart:12-78](file://lib/src/animation/smil/interpolators_transform.dart#L12-L78)
- [css_animations_parser.dart:4-96](file://lib/src/animation/css_animations_parser.dart#L4-L96)
- [css_to_smil_converter.dart:15-67](file://lib/src/animation/css_to_smil_converter.dart#L15-L67)
- [smil_parser.dart:12-38](file://lib/src/animation/smil/smil_parser.dart#L12-L38)
- [css_selectors.dart:447-665](file://lib/src/animation/css_selectors.dart#L447-L665)

## Architecture Overview
The enhanced conversion pipeline integrates comprehensive CSS processing capabilities alongside the traditional CSS-to-SMIL conversion workflow with sophisticated shadow DOM awareness.

```mermaid
sequenceDiagram
participant P as "SvgParser"
participant SP as "SmilParser"
participant CS as "CssCascadeResolver"
participant CV as "CssVariableResolver"
participant CE as "CssShorthandExpander"
participant SEL as "CssSelectorParser"
participant CP as "CssParser"
participant CTV as "CssTransformValues"
participant CTS as "CssToSmilConverter"
participant IT as "InterpolatorsTransform"
participant RT as "SmilAnimation/Runtime"
P->>SP : parseAnimations(document)
SP->>SP : _extractAnimations(root, doc, out)
SP->>CS : resolveProperty(node, property)
SP->>CV : resolveValue(value, node)
SP->>CE : expandAll(properties)
SP->>SEL : parseSelector(selector)
SEL->>CS : _selectorMatchesWithPseudo(rule, node)
CS->>CS : _matchComplexSelector(parsed, node)
CS->>CS : _findMatchingAncestor(node, selector)
CS->>CS : _isShadowBoundary(current)
SP->>CP : parseAnimationFromStyle(style)
CP-->>SP : CssAnimation
SP->>CTS : convert(keyframes, cssAnim, node, doc)
CTS->>CTS : _createSmilAnimation(...)
CTS->>CTV : normalizeCssTransform(value)
CTV->>CTV : _extractFunctionArgs(input, startIndex)
CTV->>CTV : _parseTransformArgs(argsString)
CTV->>IT : interpolateTransformValue(from, to, t)
IT-->>CTS : normalized transform string
CTS-->>SP : List<SmilAnimation>
SP-->>RT : Unified animation list
RT->>RT : tick()/seek(), update attributes
```

**Diagram sources**
- [smil_parser.dart:16-37](file://lib/src/animation/smil/smil_parser.dart#L16-L37)
- [smil_parser_css_extraction.dart:3-41](file://lib/src/animation/smil/smil_parser_css_extraction.dart#L3-L41)
- [css_cascade.dart:295-396](file://lib/src/animation/css_cascade.dart#L295-L396)
- [css_variables_calc.dart:96-154](file://lib/src/animation/css_variables_calc.dart#L96-L154)
- [css_shorthand_expansion.dart:12-31](file://lib/src/animation/css_shorthand_expansion.dart#L12-L31)
- [css_selectors.dart:447-665](file://lib/src/animation/css_selectors.dart#L447-L665)
- [css_animations_parser.dart:22-43](file://lib/src/animation/css_animations_parser.dart#L22-L43)
- [css_to_smil_converter.dart:17-22](file://lib/src/animation/css_to_smil_converter.dart#L17-L22)
- [css_to_smil_converter_transforms_values.dart:64-168](file://lib/src/animation/css_to_smil_converter_transforms_values.dart#L64-L168)
- [interpolators_transform.dart:12-78](file://lib/src/animation/smil/interpolators_transform.dart#L12-L78)
- [transform_3d.dart:329-373](file://lib/src/animation/transform_3d.dart#L329-L373)

## Detailed Component Analysis

### Enhanced CSS Cascade System
The CSS cascade resolver implements comprehensive specificity calculation and inheritance resolution with sophisticated shadow DOM awareness:

- **Specificity Calculation**: Supports ID selectors (#id), class selectors (.class), attribute selectors ([attr]), pseudo-classes (:hover, :active), element types, and pseudo-elements (::before).
- **Complex Selector Support**: Handles descendant (space), child (>), adjacent sibling (+), and general sibling (~) combinators with proper ancestor traversal.
- **Shadow DOM Boundary Detection**: Respects shadow DOM boundaries for use/symbol elements, preventing selector matching across shadow boundaries.
- **Inheritance Control**: Handles inheritable properties (fill, stroke, font-family, color, visibility) and non-inheritable properties (opacity, width).
- **Priority Resolution**: Implements proper cascade order with !important override rules and source order fallback.
- **Dynamic State**: Supports pseudo-class states (hover, active, focus) for selector matching.

```mermaid
classDiagram
class CssSpecificity {
+int a
+int b
+int c
+int d
+compareTo(other) int
+operator >() bool
}
class CssCascadeResolver {
+CssSelectorRule[] cssRules
+SvgPseudoClassState pseudoClassState
+resolveProperty(node, property) String?
+resolveOwnProperty(node, property) String?
+_getMatchingRules(node) _MatchedRule[]
+_selectorMatches(node, selector) bool
+_matchComplexSelector(selector, node, tagName, id, classes) bool
+_findMatchingAncestor(node, selector) SvgNode?
+_isShadowBoundary(node) bool
}
class CssResolvedValue {
+String value
+CssSpecificity specificity
+int order
+bool isImportant
+compareCascade(other) int
+winner(other) CssResolvedValue
}
CssSpecificity <|-- CssResolvedValue
CssCascadeResolver --> CssSpecificity : "calculates"
CssCascadeResolver --> CssResolvedValue : "resolves"
```

**Diagram sources**
- [css_cascade.dart:18-107](file://lib/src/animation/css_cascade.dart#L18-L107)
- [css_cascade.dart:277-396](file://lib/src/animation/css_cascade.dart#L277-L396)
- [css_cascade.dart:404-603](file://lib/src/animation/css_cascade.dart#L404-L603)

**Section sources**
- [css_cascade.dart:18-107](file://lib/src/animation/css_cascade.dart#L18-L107)
- [css_cascade.dart:180-275](file://lib/src/animation/css_cascade.dart#L180-L275)
- [css_cascade.dart:277-396](file://lib/src/animation/css_cascade.dart#L277-L396)
- [css_cascade.dart:404-603](file://lib/src/animation/css_cascade.dart#L404-L603)

### Enhanced CSS Selector Parser
The selector parser now supports complex CSS selectors with comprehensive combinator support:

- **Complex Selectors**: Supports descendant (space), child (>), adjacent sibling (+), and general sibling (~) combinators.
- **Pseudo-classes**: Handles structural pseudo-classes (:first-child, :last-child, :only-child, :first-of-type, :last-of-type, :only-of-type) and dynamic pseudo-classes (:hover, :active, :focus).
- **Functional Pseudo-classes**: Supports nth-child, nth-last-child, nth-of-type, nth-last-of-type with calc() expression support.
- **Attribute Selectors**: Comprehensive attribute matching with equality, substring, and existence selectors.
- **Not Selectors**: Supports :not() pseudo-class for negation.
- **Compound Selectors**: Handles element.class#id combinations with proper specificity calculation.

```mermaid
classDiagram
class CssSelector {
+CssSelectorPart[] parts
+bool isSimple
+CssSelectorPart subject
+toString() String
}
class CssSelectorPart {
+CssSimpleSelector selector
+CssCombinator combinator
+toString() String
}
class CssSimpleSelector {
+String? tagName
+String? id
+Set~String~ classes
+CssAttributeSelector[] attributes
+CssPseudoClass[] pseudoClasses
+CssNthPseudoClass[] nthPseudoClasses
+CssSimpleSelector[] notSelectors
}
CssSelector --> CssSelectorPart : "contains"
CssSelectorPart --> CssSimpleSelector : "has"
```

**Diagram sources**
- [css_selectors.dart:426-441](file://lib/src/animation/css_selectors.dart#L426-L441)
- [css_selectors.dart:403-424](file://lib/src/animation/css_selectors.dart#L403-L424)
- [css_selectors.dart:637-648](file://lib/src/animation/css_selectors.dart#L637-L648)

**Section sources**
- [css_selectors.dart:426-441](file://lib/src/animation/css_selectors.dart#L426-L441)
- [css_selectors.dart:447-665](file://lib/src/animation/css_selectors.dart#L447-L665)
- [css_selectors.dart:637-648](file://lib/src/animation/css_selectors.dart#L637-L648)

### CSS Variables and Calc() Support
The variable resolver provides comprehensive support for CSS custom properties and mathematical expressions:

- **Custom Properties**: Stores variables in element attributes with inheritance through the DOM tree.
- **Variable Resolution**: Walks up the element tree to resolve var() references with fallback support.
- **Calc() Evaluation**: Parses and evaluates mathematical expressions with unit conversion (px, em, rem, pt, %) and nested calc() support.
- **Nested Expressions**: Supports nested calc() and var() combinations with recursion limits.

```mermaid
flowchart TD
Start(["CSS Value Processing"]) --> VarCheck{"Contains var()?"}
VarCheck --> |Yes| VarResolve["CssVariableResolver.resolveValue()"]
VarCheck --> |No| CalcCheck{"Contains calc()?"}
VarResolve --> CalcCheck
CalcCheck --> |Yes| CalcEval["CssCalcEvaluator.evaluate()"]
CalcCheck --> |No| Return["Return original value"]
CalcEval --> Return
```

**Diagram sources**
- [css_variables_calc.dart:96-154](file://lib/src/animation/css_variables_calc.dart#L96-L154)
- [css_variables_calc.dart:164-193](file://lib/src/animation/css_variables_calc.dart#L164-L193)

**Section sources**
- [css_variables_calc.dart:92-154](file://lib/src/animation/css_variables_calc.dart#L92-L154)
- [css_variables_calc.dart:156-206](file://lib/src/animation/css_variables_calc.dart#L156-L206)
- [css_variables_calc.dart:220-277](file://lib/src/animation/css_variables_calc.dart#L220-L277)

### CSS Shorthand Property Expansion
The shorthand expander converts CSS shorthand properties into their longhand equivalents:

- **Animation Shorthand**: Supports multiple animations with comma separation and full property expansion.
- **Transition Shorthand**: Expands transition properties into individual transition-property, duration, timing-function, and delay.
- **Box Model Properties**: Handles margin, padding, border, and border-radius with 1-4 value expansion.
- **SVG-Specific Properties**: Includes marker shorthand for SVG elements.

```mermaid
classDiagram
class CssShorthandExpander {
+static expandAll(properties) Map~String,String~
+static expandProperty(property, value) Map~String,String~
+_expandAnimation(value) Map~String,String~
+_expandTransition(value) Map~String,String~
+_expandBoxModel(property, value) Map~String,String~
+_expandMarker(value) Map~String,String~
}
class CssAnimation {
+String name
+String duration
+String timingFunction
+String delay
+String iterationCount
+String direction
+String fillMode
+String playState
}
CssShorthandExpander --> CssAnimation : "expands"
```

**Diagram sources**
- [css_shorthand_expansion.dart:7-31](file://lib/src/animation/css_shorthand_expansion.dart#L7-L31)
- [css_shorthand_expansion.dart:293-337](file://lib/src/animation/css_shorthand_expansion.dart#L293-L337)

**Section sources**
- [css_shorthand_expansion.dart:7-31](file://lib/src/animation/css_shorthand_expansion.dart#L7-L31)
- [css_shorthand_expansion.dart:293-337](file://lib/src/animation/css_shorthand_expansion.dart#L293-L337)
- [css_shorthand_expansion.dart:487-517](file://lib/src/animation/css_shorthand_expansion.dart#L487-L517)
- [css_shorthand_expansion.dart:583-629](file://lib/src/animation/css_shorthand_expansion.dart#L583-L629)

### 3D Transform System
The 3D transform system provides comprehensive support for CSS 3D transformations:

- **Matrix Operations**: Full 4x4 matrix support with translation, rotation, scale, and perspective operations.
- **3D Transform Functions**: Supports translate3d, rotateX, rotateY, rotateZ, rotate3d, scale3d, scalez, perspective, and matrix3d.
- **Projection System**: Converts 3D matrices to 2D transforms for SMIL compatibility with perspective projection.
- **Backface Detection**: Determines visibility of rotated surfaces for proper rendering.

```mermaid
classDiagram
class Matrix4x4 {
+Float64List storage
+Matrix4x4.identity()
+Matrix4x4.translation(x,y,z)
+Matrix4x4.rotationX(radians)
+Matrix4x4.rotationY(radians)
+Matrix4x4.rotationZ(radians)
+Matrix4x4.rotation3d(x,y,z,radians)
+Matrix4x4.perspective(distance)
+Matrix4x4.fromMatrix3d(values)
+Matrix4x4.from2dMatrix(values)
+transform2D(x,y,z) Offset
+extract2DMatrix() double[]
+isBackfacing() bool
}
class Transform3DContext {
+double? perspective
+double perspectiveOriginX
+double perspectiveOriginY
+Transform3DStyle transformStyle
+BackfaceVisibility backfaceVisibility
+createPerspectiveMatrix(width,height) Matrix4x4?
}
Matrix4x4 --> Transform3DContext : "used by"
```

**Diagram sources**
- [transform_3d.dart:22-327](file://lib/src/animation/transform_3d.dart#L22-L327)
- [transform_3d.dart:329-373](file://lib/src/animation/transform_3d.dart#L329-L373)

**Section sources**
- [transform_3d.dart:22-327](file://lib/src/animation/transform_3d.dart#L22-L327)
- [transform_3d.dart:329-373](file://lib/src/animation/transform_3d.dart#L329-L373)

### Enhanced CSS Transform Parsing
The transform parsing system now supports comprehensive CSS transform syntax with calc() expression support:

- **Transform Function Parsing**: Handles translate, rotate, scale, skew, matrix, and 3D transform functions with proper argument extraction.
- **Calc() Expression Support**: Parses and evaluates calc() expressions within transform function arguments.
- **Unit Conversion**: Supports px, em, rem, %, vw, vh, vmin, vmax, cm, mm, in, pt, pc, and bare numbers.
- **Angle Unit Support**: Handles deg, rad, turn, and grad units for rotation functions.
- **Nested Function Support**: Properly handles nested parentheses in complex transform expressions.

**Section sources**
- [css_to_smil_converter_transforms_values.dart:4-8](file://lib/src/animation/css_to_smil_converter_transforms_values.dart#L4-L8)
- [css_to_smil_converter_transforms_values.dart:210-303](file://lib/src/animation/css_to_smil_converter_transforms_values.dart#L210-L303)
- [css_to_smil_converter_transforms_values.dart:326-390](file://lib/src/animation/css_to_smil_converter_transforms_values.dart#L326-L390)

### Enhanced CSS to SMIL Conversion
The conversion system now handles enhanced CSS features with shadow DOM awareness:

- **Variable Substitution**: Resolves CSS variables and calc() expressions before SMIL generation.
- **Shorthand Expansion**: Expands CSS shorthand properties into SMIL-compatible formats.
- **3D Transform Handling**: Processes 3D transforms with proper matrix decomposition and 2D projection.
- **Cascade Integration**: Incorporates CSS cascade resolution with shadow DOM boundary detection into property application.
- **Selector Matching**: Uses sophisticated selector matching with complex combinator support.

**Section sources**
- [css_to_smil_converter.dart:15-67](file://lib/src/animation/css_to_smil_converter.dart#L15-L67)
- [css_to_smil_converter_core.dart:27-146](file://lib/src/animation/css_to_smil_converter_core.dart#L27-L146)

## Enhanced CSS Features

### Shadow DOM-Aware CSS Cascade Resolution
The system now implements sophisticated shadow DOM boundary detection:

- **Shadow Boundary Detection**: Recognizes use and symbol elements as shadow DOM boundaries that prevent selector matching across boundaries.
- **Ancestor Traversal**: Properly traverses ancestor nodes while respecting shadow boundaries during complex selector matching.
- **Combinator Respect**: Complex selectors with combinators (>, +, ~) respect shadow boundaries and don't pierce through shadow DOM scopes.
- **Inheritance Scope**: CSS properties flow through shadow boundaries only for inheritable properties, not for transform or opacity.

**Updated** Added shadow DOM boundary detection for use/symbol elements

**Section sources**
- [css_cascade.dart:404-603](file://lib/src/animation/css_cascade.dart#L404-L603)
- [css_cascade.dart:555-569](file://lib/src/animation/css_cascade.dart#L555-L569)
- [css_cascade.dart:598-603](file://lib/src/animation/css_cascade.dart#L598-L603)

### Complex CSS Selector Support
Full support for modern CSS selectors with combinators:

- **Descendant Combinator**: Space-separated selectors (div span) match any descendant
- **Child Combinator**: Direct child selectors (div > span) match only direct children
- **Adjacent Sibling**: Plus-separated selectors (div + p) match immediately following siblings
- **General Sibling**: Tilde-separated selectors (div ~ p) match any following siblings
- **Pseudo-classes**: Structural (:first-child, :nth-child, :first-of-type) and dynamic (:hover, :active, :focus)
- **Functional Pseudo-classes**: nth-child, nth-last-child, nth-of-type, nth-last-of-type with calc() support

**Updated** Enhanced selector parsing with complex combinator support

**Section sources**
- [css_selectors.dart:447-665](file://lib/src/animation/css_selectors.dart#L447-L665)
- [css_cascade.dart:483-553](file://lib/src/animation/css_cascade.dart#L483-L553)

### CSS Custom Properties and Calc() Support
Full support for modern CSS features:

- **Variable Declaration**: Custom properties with --prefix syntax
- **Variable Resolution**: Tree-walking resolution with fallback values
- **Calc() Evaluation**: Mathematical expressions with unit conversion and nested calc() support
- **Nested Expressions**: Complex variable and calc() combinations with recursion limits

**Section sources**
- [css_variables_calc.dart:92-154](file://lib/src/animation/css_variables_calc.dart#L92-L154)
- [css_variables_calc_test.dart:8-37](file://test/animation/css_variables_calc_test.dart#L8-L37)

### CSS Shorthand Property Expansion
Comprehensive shorthand property support:

- **Animation Shorthand**: Multiple animations with full property expansion
- **Transition Shorthand**: Individual transition property expansion
- **Box Model Properties**: Margin, padding, border, border-radius expansion
- **SVG Properties**: Marker shorthand for SVG elements

**Section sources**
- [css_shorthand_expansion.dart:293-337](file://lib/src/animation/css_shorthand_expansion.dart#L293-L337)
- [css_shorthand_expansion_test.dart:83-195](file://test/animation/css_shorthand_expansion_test.dart#L83-L195)

### 3D Transform Capabilities
Complete 3D transform support:

- **3D Transform Functions**: translate3d, rotateX, rotateY, rotateZ, rotate3d, scale3d, scalez, perspective, matrix3d
- **Matrix Operations**: Full 4x4 matrix support with proper multiplication
- **Perspective Projection**: 3D to 2D projection with perspective divide
- **Backface Visibility**: Proper detection and handling of rotated surfaces

**Section sources**
- [transform_3d.dart:22-327](file://lib/src/animation/transform_3d.dart#L22-L327)
- [css_3d_transforms_test.dart:196-317](file://test/animation/css_3d_transforms_test.dart#L196-L317)

### Enhanced Transform System
The transform system now provides comprehensive support for modern CSS transforms:

- **Full Function String Preservation**: Transform function strings maintain complete syntax for accurate interpolation
- **Calc() Expression Support**: Proper parsing and evaluation of calc() expressions within transform arguments
- **Unit Conversion**: Support for all CSS length and angle units with proper conversion
- **Angle Parsing**: Comprehensive angle unit support (deg, rad, turn, grad) with calc() expression support
- **Matrix Operations**: Full 4x4 matrix support for 3D transforms

**Updated** Enhanced transform parsing with calc() expression support

**Section sources**
- [css_to_smil_converter_transforms_values.dart:64-168](file://lib/src/animation/css_to_smil_converter_transforms_values.dart#L64-L168)
- [css_to_smil_converter_transforms_values.dart:210-303](file://lib/src/animation/css_to_smil_converter_transforms_values.dart#L210-L303)
- [css_to_smil_converter_transforms_values.dart:326-390](file://lib/src/animation/css_to_smil_converter_transforms_values.dart#L326-L390)

## Transform System Enhancements

### CSS-Compliant Single Animation Processing
The transform decomposition system has been completely replaced with CSS-compliant single-animation processing:

- **Single Animation Per Transform**: Compound transforms produce a single SMIL animation with full string preservation
- **REPLACE Semantics**: CSS transforms use additive=replace mode to match CSS semantics and prevent double-application
- **Transform Normalization**: Complete CSS transform syntax is preserved during normalization for downstream interpolation
- **Interpolation Accuracy**: Compound transforms are properly interpolated through decomposition while maintaining original string format

**Updated** Complete replacement with CSS-compliant single-animation processing

```mermaid
flowchart TD
Start(["CSS Transform Input"]) --> Parse["Parse Transform String"]
Parse --> Normalize["Normalize Transform Values"]
Normalize --> Preserve["Preserve Full Function Strings"]
Preserve --> SingleAnimation["Create Single SMIL Animation"]
SingleAnimation --> ReplaceMode["Apply REPLACE Semantics"]
ReplaceMode --> Interpolate["Interpolate Transforms"]
Interpolate --> Output["SMIL Animation Output"]
```

**Diagram sources**
- [css_to_smil_converter_transforms_values.dart:64-168](file://lib/src/animation/css_to_smil_converter_transforms_values.dart#L64-L168)
- [interpolators_transform.dart:12-78](file://lib/src/animation/smil/interpolators_transform.dart#L12-L78)
- [css_to_smil_converter_core.dart:137-164](file://lib/src/animation/css_to_smil_converter_core.dart#L137-L164)

**Section sources**
- [css_to_smil_converter_transforms_values.dart:64-168](file://lib/src/animation/css_to_smil_converter_transforms_values.dart#L64-L168)
- [interpolators_transform.dart:12-78](file://lib/src/animation/smil/interpolators_transform.dart#L12-L78)
- [css_to_smil_converter_core.dart:137-164](file://lib/src/animation/css_to_smil_converter_core.dart#L137-L164)

### Enhanced CSS Compound Transform Handling
The system now properly handles CSS compound transforms with enhanced semantics:

- **Single Animation Per Transform**: Compound transforms produce a single SMIL animation with full string preservation
- **REPLACE Semantics**: CSS transforms use additive=replace mode to match CSS semantics and prevent double-application
- **Per-Keyframe Timing**: Individual keyframes can specify timing functions while maintaining compound transform integrity
- **Transform Type Inference**: Transform type is inferred from the first value for proper SMIL animation creation

**Updated** Complete replacement of decomposition methodology with single-animation processing

**Section sources**
- [css_transform_decomposition_test.dart:19-75](file://test/animation/css_transform_decomposition_test.dart#L19-L75)
- [css_transform_decomposition_test.dart:271-330](file://test/animation/css_transform_decomposition_test.dart#L271-L330)
- [stroke_dash_stop_color_test.dart:271-296](file://test/animation/stroke_dash_stop_color_test.dart#L271-L296)

### Transform Interpolation System
Enhanced interpolation system for compound transforms:

- **Identity Transform Handling**: 'none' values are converted to identity transform ('translate(0, 0)')
- **Single Transform Optimization**: Simple transforms are interpolated directly without decomposition
- **Compound Transform Decomposition**: Complex transforms are decomposed for accurate interpolation
- **Result Reconstruction**: Interpolated transforms are reconstructed into proper CSS syntax

**Section sources**
- [interpolators_transform.dart:12-78](file://lib/src/animation/smil/interpolators_transform.dart#L12-L78)
- [transform_animation_test.dart:293-309](file://test/animation/transform_animation_test.dart#L293-L309)

### Enhanced Discrete CalcMode for String Attributes
The system now properly handles discrete calcMode for string-type attributes:

- **String-Type Attribute Detection**: Automatic detection of string-type attributes for discrete calcMode
- **SMIL Spec Compliance**: Per SMIL spec, string-type attributes must use discrete calcMode
- **Non-Interpolatable Properties**: Visibility, display, fill-rule, stroke-linecap, stroke-linejoin, pointer-events, clip-rule, text-anchor, dominant-baseline, alignment-baseline
- **Explicit Override Support**: User-specified calcMode overrides automatic detection

**Updated** Enhanced discrete calcMode support for string-type attributes

**Section sources**
- [smil_parser_animation_parsing.dart:134-147](file://lib/src/animation/smil/smil_parser_animation_parsing.dart#L134-L147)
- [smil_parser_animation_parsing.dart:465-480](file://lib/src/animation/smil/smil_parser_animation_parsing.dart#L465-L480)

## Dependency Analysis
The enhanced system introduces new dependencies while maintaining backward compatibility:

- **CssCascadeResolver** depends on:
  - CssSpecificityCalculator for specificity calculation
  - CssResolvedValue for cascade resolution results
  - SvgNode hierarchy for inheritance traversal
  - CssSelectorParser for complex selector support
- **CssVariableResolver** depends on:
  - CssCustomProperties for variable storage
  - CssCalcEvaluator for expression evaluation
  - SvgNode tree traversal for inheritance
- **CssShorthandExpander** depends on:
  - Property-specific expansion functions
  - Regular expression parsing for CSS syntax
- **CssSelectorParser** depends on:
  - CssSelector for selector representation
  - CssSimpleSelector for simple selector parsing
  - CssCombinator for combinator types
- **Transform3DContext** depends on:
  - Matrix4x4 for 3D operations
  - Transform decomposition utilities
- **CssTransformValues** depends on:
  - Transform function regex parsing
  - Unit conversion utilities
  - Number formatting functions
  - Calc evaluator for expression support
- **InterpolatorsTransform** depends on:
  - SvgTransform parsing
  - TransformDecomposition for interpolation
  - Result reconstruction utilities

```mermaid
graph LR
CS["CssCascadeResolver"] --> SC["CssSpecificityCalculator"]
CS --> RV["CssResolvedValue"]
CS --> SN["SvgNode"]
CS --> SP["CssSelectorParser"]
CV["CssVariableResolver"] --> CP["CssCustomProperties"]
CV --> CE["CssCalcEvaluator"]
CV --> SN
CE["CssShorthandExpander"] --> PE["Property Expansion Functions"]
SEL["CssSelectorParser"] --> CSel["CssSelector"]
SEL --> CSSel["CssSimpleSelector"]
SEL --> CC["CssCombinator"]
T3D["Transform3DContext"] --> M4["Matrix4x4"]
T3D --> TD["Transform Decomposition"]
CTV["CssTransformValues"] --> TF["Transform Functions"]
CTV --> UC["Unit Conversion"]
CTV --> NF["Number Formatting"]
CTV --> CEval["Calc Evaluator"]
IT["InterpolatorsTransform"] --> ST["SvgTransform"]
IT --> TD
IT --> RD["Result Decomposition"]
```

**Diagram sources**
- [css_cascade.dart:277-396](file://lib/src/animation/css_cascade.dart#L277-L396)
- [css_variables_calc.dart:92-154](file://lib/src/animation/css_variables_calc.dart#L92-L154)
- [css_shorthand_expansion.dart:7-31](file://lib/src/animation/css_shorthand_expansion.dart#L7-L31)
- [css_selectors.dart:426-441](file://lib/src/animation/css_selectors.dart#L426-L441)
- [transform_3d.dart:329-373](file://lib/src/animation/transform_3d.dart#L329-L373)
- [css_to_smil_converter_transforms_values.dart:64-168](file://lib/src/animation/css_to_smil_converter_transforms_values.dart#L64-L168)
- [interpolators_transform.dart:12-78](file://lib/src/animation/smil/interpolators_transform.dart#L12-L78)

**Section sources**
- [css_cascade.dart:277-396](file://lib/src/animation/css_cascade.dart#L277-L396)
- [css_variables_calc.dart:92-154](file://lib/src/animation/css_variables_calc.dart#L92-L154)
- [css_shorthand_expansion.dart:7-31](file://lib/src/animation/css_shorthand_expansion.dart#L7-L31)
- [css_selectors.dart:426-441](file://lib/src/animation/css_selectors.dart#L426-L441)
- [transform_3d.dart:329-373](file://lib/src/animation/transform_3d.dart#L329-L373)
- [css_to_smil_converter_transforms_values.dart:64-168](file://lib/src/animation/css_to_smil_converter_transforms_values.dart#L64-L168)
- [interpolators_transform.dart:12-78](file://lib/src/animation/smil/interpolators_transform.dart#L12-L78)

## Performance Considerations
The enhanced system maintains performance through strategic optimizations:

- **Cascade Resolution Caching**: CssCascadeResolver caches matching rules to avoid repeated selector matching
- **Shadow Boundary Optimization**: Shadow boundary detection short-circuits expensive ancestor traversal
- **Variable Resolution Limits**: Maximum iteration limits prevent infinite loops in variable resolution
- **3D Transform Optimization**: Matrix operations are optimized for common transform sequences
- **Transform String Preservation**: Preserving full transform strings avoids re-parsing overhead
- **Interpolation Efficiency**: Compound transform decomposition is optimized for common transform patterns
- **Memory Management**: Proper cleanup of temporary objects during conversion processes
- **Lazy Evaluation**: CSS variable and calc() evaluation occurs only when needed
- **Single Animation Processing**: Elimination of decomposition overhead improves performance

**Updated** Elimination of decomposition overhead improves performance

**Section sources**
- [css_cascade.dart:291-293](file://lib/src/animation/css_cascade.dart#L291-L293)
- [css_variables_calc.dart:102-109](file://lib/src/animation/css_variables_calc.dart#L102-L109)

## Troubleshooting Guide
Enhanced troubleshooting for new CSS features:

### CSS Cascade Issues
- **Property not applying**: Check specificity calculation and !important declarations
- **Inheritance problems**: Verify inheritable property lists and parent-child relationships
- **Dynamic state not working**: Ensure pseudo-class state tracking is enabled
- **Shadow boundary issues**: Verify that selectors aren't trying to pierce use/symbol boundaries
- **Complex selector not matching**: Check combinator syntax and shadow boundary constraints

### CSS Variables and Calc() Problems
- **Variable not resolving**: Check variable declaration scope and inheritance chain
- **Calc() evaluation errors**: Verify mathematical syntax and unit compatibility
- **Fallback not working**: Ensure fallback syntax is correct (var(--name, fallback))
- **Nested calc() issues**: Verify proper parentheses nesting and operator precedence

### Shorthand Expansion Issues
- **Shorthand not expanding**: Verify shorthand syntax and property names
- **Conflicting properties**: Check for explicit longhand properties overriding expansions
- **Multiple animations**: Ensure comma separation is correct for animation shorthand

### Transform System Problems
- **Transform not animating**: Check that transform values are properly normalized and preserved
- **Compound transform issues**: Verify that additive=replace mode is being used for CSS semantics
- **Interpolation artifacts**: Ensure transform decomposition is working correctly for compound transforms
- **Unit conversion errors**: Check that transform units are properly converted during normalization
- **Calc() expression parsing**: Verify calc() syntax and supported operators
- **Angle unit conversion**: Ensure proper angle unit handling (deg, rad, turn, grad)

**Updated** Added troubleshooting for shadow boundaries, complex selectors, and calc() expressions

**Section sources**
- [css_cascade_specificity_test.dart:195-496](file://test/animation/css_cascade_specificity_test.dart#L195-L496)
- [css_variables_calc_test.dart:39-124](file://test/animation/css_variables_calc_test.dart#L39-124)
- [css_transform_decomposition_test.dart:19-75](file://test/animation/css_transform_decomposition_test.dart#L19-L75)
- [stroke_dash_stop_color_test.dart:271-296](file://test/animation/stroke_dash_stop_color_test.dart#L271-L296)
- [css_transform_calc_test.dart:1-200](file://test/animation/css_transform_calc_test.dart#L1-L200)

## Conclusion
The enhanced CSS-to-SMIL conversion system now provides comprehensive support for modern CSS features including cascade resolution with shadow DOM awareness, complex selector matching with combinators, custom properties, shorthand expansion, and 3D transforms. The system maintains robust performance while extending compatibility with advanced CSS specifications. The enhanced transform decomposition system preserves full transform strings for accurate interpolation and maintains proper CSS semantics through REPLACE semantics. The integration of shadow DOM boundary detection and complex selector support enables more sophisticated animation authoring and better interoperability with contemporary web standards.

**Updated** Complete replacement with CSS-compliant single-animation processing provides better performance and accuracy

## Appendices

### Enhanced CSS Animation Properties and Timing Functions
- **Properties**: Extended to include all CSS properties with cascade resolution support and shadow DOM awareness
- **Timing Functions**: Enhanced with improved calc() evaluation for timing values
- **Direction**: Normal, reverse, alternate, alternate-reverse with proper SMIL mapping
- **Fill Mode**: None, forwards, backwards, both with cascade-aware application

**Section sources**
- [css_to_smil_converter_core.dart:180-207](file://lib/src/animation/css_to_smil_converter_core.dart#L180-L207)
- [css_to_smil_converter_timing.dart:14-42](file://lib/src/animation/css_to_smil_converter_timing.dart#L14-L42)

### Enhanced Transform Examples and Behavior
- **Full String Preservation**: Transform function strings maintain complete syntax (e.g., 'rotate(0)') for accurate interpolation
- **Single Animation Processing**: Compound transforms processed as single animations with full compound transform string
- **REPLACE Semantics**: CSS transforms use additive=replace mode to prevent double-application
- **Transform Interpolation**: Compound transforms properly interpolated through decomposition while preserving original format
- **Calc() Expression Support**: Transform arguments support calc() expressions with unit conversion

**Updated** Complete replacement with single-animation processing

**Section sources**
- [css_to_smil_converter_transforms_values.dart:64-168](file://lib/src/animation/css_to_smil_converter_transforms_values.dart#L64-L168)
- [css_transform_decomposition_test.dart:19-75](file://test/animation/css_transform_decomposition_test.dart#L19-L75)
- [interpolators_transform.dart:12-78](file://lib/src/animation/smil/interpolators_transform.dart#L12-L78)
- [css_transform_calc_test.dart:1-200](file://test/animation/css_transform_calc_test.dart#L1-L200)

### Enhanced Conversion Limitations
- **Complex CSS Edge Cases**: Some advanced CSS edge cases may require manual SMIL implementation
- **Performance Considerations**: Complex variable resolution and calc() evaluation may impact performance
- **3D Transform Complexity**: Very complex 3D transform chains may require optimization
- **Transform String Processing**: Preserving full transform strings adds minimal overhead but ensures accuracy
- **Single Animation Constraint**: Compound transforms are processed as single animations, limiting per-function timing control
- **Shadow Boundary Constraints**: Complex selectors with combinators may be limited by shadow boundary detection
- **Calc() Expression Complexity**: Very complex calc() expressions may require additional evaluation overhead

**Updated** Added limitation for shadow boundaries and calc() expression complexity

**Section sources**
- [css_cascade.dart:404-437](file://lib/src/animation/css_cascade.dart#L404-L437)
- [css_variables_calc.dart:102-109](file://lib/src/animation/css_variables_calc.dart#L102-L109)
- [css_to_smil_converter_transforms_values.dart:64-168](file://lib/src/animation/css_to_smil_converter_transforms_values.dart#L64-L168)
- [css_cascade.dart:598-603](file://lib/src/animation/css_cascade.dart#L598-L603)