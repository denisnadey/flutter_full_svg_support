# Enhanced CSS Variables and Calculations

<cite>
**Referenced Files in This Document**
- [css_variables_calc.dart](file://lib/src/animation/css_variables_calc.dart)
- [css_cascade.dart](file://lib/src/animation/css_cascade.dart)
- [css_selectors.dart](file://lib/src/animation/css_selectors.dart)
- [css_property_rendering_test.dart](file://test/animation/css_property_rendering_test.dart)
- [css_cascade_specificity_test.dart](file://test/animation/css_cascade_specificity_test.dart)
- [css_variables_calc_test.dart](file://test/animation/css_variables_calc_test.dart)
- [svg_dom.dart](file://lib/src/animation/svg_dom.dart)
- [animated_svg_painter_use.dart](file://lib/src/animation/animated_svg_painter_use.dart)
- [animated_svg_painter_tree.dart](file://lib/src/animation/animated_svg_painter_tree.dart)
- [smil_parser_motion.dart](file://lib/src/animation/smil/smil_parser_motion.dart)
- [smil_timeline_syncbase.dart](file://lib/src/animation/smil/smil_timeline_syncbase.dart)
- [smil_timeline_runtime.dart](file://lib/src/animation/smil/smil_timeline_runtime.dart)
- [svg_filters_registry_pipeline_primitives.dart](file://lib/src/animation/svg_filters_registry_pipeline_primitives.dart)
- [svg_filters_registry_pipeline.dart](file://lib/src/animation/svg_filters_registry_pipeline.dart)
- [svg_filters_registry_inputs.dart](file://lib/src/animation/svg_filters_registry_inputs.dart)
- [SVGElement.cpp](file://blink-b87d44f-Source-core-svg/SVGElement.cpp)
- [advanced_use_inheritance_test.dart](file://test/animation/advanced_use_inheritance_test.dart)
- [use_css_cascade_test.dart](file://test/animation/use_css_cascade_test.dart)
- [css_selectors_combinators_test.dart](file://test/animation/css_selectors_combinators_test.dart)
</cite>

## Update Summary
**Changes Made**
- Enhanced CSS cascade processing with improved selector specificity handling and shadow DOM boundary management
- Added comprehensive support for structural pseudo-classes: nth-child, nth-last-child, nth-of-type, nth-last-of-type, first-of-type, last-of-type, only-of-type
- Implemented advanced CSS selector parsing with enhanced structural pseudo-class matching algorithms
- Expanded CSS calc() evaluator with improved CSS math function support and variable resolution
- Enhanced SMIL animation support with improved motion path parsing and timeline synchronization
- Comprehensive filter primitive enhancements with advanced pipeline processing and circular reference detection
- Added advanced use context inheritance for CSS properties across <use> boundaries
- Enhanced CSS property rendering validation and advanced CSS parsing capabilities

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [Enhanced CSS Cascade Processing](#enhanced-css-cascade-processing)
7. [Advanced CSS Variables and Calculations](#advanced-css-variables-and-calculations)
8. [Structural Pseudo-Classes and Matching Algorithms](#structural-pseudo-classes-and-matching-algorithms)
9. [Modern CSS Unit Support](#modern-css-unit-support)
10. [SMIL Animation Enhancements](#smil-animation-enhancements)
11. [Filter Primitive Pipeline Improvements](#filter-primitive-pipeline-improvements)
12. [Dependency Analysis](#dependency-analysis)
13. [Performance Considerations](#performance-considerations)
14. [Troubleshooting Guide](#troubleshooting-guide)
15. [Conclusion](#conclusion)

## Introduction
This document provides comprehensive technical documentation for the Enhanced CSS Variables and Calculations system in the Flutter SVG support library. The implementation covers CSS custom properties (variables), calc() mathematical expressions, CSS math functions (min, max, clamp), structural pseudo-classes, and their integration with the SVG rendering pipeline. It includes detailed analysis of the parsing, resolution, and evaluation mechanisms, along with enhanced SMIL animation support, comprehensive filter primitive processing, and performance characteristics.

The enhanced system now provides robust CSS cascade resolution with new CSS variables cascade resolver integration, comprehensive structural pseudo-class support, advanced variable inheritance, comprehensive mathematical computation with modern CSS unit support, and seamless integration with SMIL animations and filter processing while maintaining compatibility with the existing SVG rendering pipeline.

## Project Structure
The enhanced CSS capabilities are implemented primarily in the animation module with extensive integration to the SVG DOM, rendering pipeline, SMIL animations, and filter system:

```mermaid
graph TB
subgraph "Enhanced CSS System"
CV["css_variables_calc.dart"]
CC["css_cascade.dart"]
CS["css_selectors.dart"]
AP["animated_svg_painter_use.dart"]
AT["animated_svg_painter_tree.dart"]
end
subgraph "SVG DOM & Rendering"
SD["svg_dom.dart"]
AE["animated_svg_painter_use.dart"]
end
subgraph "SMIL Animation System"
SPM["smil_parser_motion.dart"]
STS["smil_timeline_syncbase.dart"]
STR["smil_timeline_runtime.dart"]
end
subgraph "Filter Pipeline"
FRP["svg_filters_registry_pipeline_primitives.dart"]
FR["svg_filters_registry_pipeline.dart"]
FRI["svg_filters_registry_inputs.dart"]
end
subgraph "Core SVG Engine"
SE["SVGElement.cpp"]
end
subgraph "Testing Framework"
T1["css_variables_calc_test.dart"]
T2["css_property_rendering_test.dart"]
T3["css_cascade_specificity_test.dart"]
T4["advanced_use_inheritance_test.dart"]
T5["use_css_cascade_test.dart"]
T6["css_selectors_combinators_test.dart"]
end
CV --> CC
CC --> CS
CV --> AP
AP --> AT
SD --> AE
SPM --> STS
STS --> STR
FRP --> FR
FR --> FRI
SE --> SD
T1 --> CV
T2 --> CV
T3 --> CC
T4 --> CC
T5 --> CC
T6 --> CS
```

**Diagram sources**
- [css_variables_calc.dart](file://lib/src/animation/css_variables_calc.dart)
- [css_cascade.dart](file://lib/src/animation/css_cascade.dart)
- [css_selectors.dart](file://lib/src/animation/css_selectors.dart)
- [svg_dom.dart](file://lib/src/animation/svg_dom.dart)
- [animated_svg_painter_use.dart](file://lib/src/animation/animated_svg_painter_use.dart)
- [animated_svg_painter_tree.dart](file://lib/src/animation/animated_svg_painter_tree.dart)
- [smil_parser_motion.dart](file://lib/src/animation/smil/smil_parser_motion.dart)
- [smil_timeline_syncbase.dart](file://lib/src/animation/smil/smil_timeline_syncbase.dart)
- [smil_timeline_runtime.dart](file://lib/src/animation/smil/smil_timeline_runtime.dart)
- [svg_filters_registry_pipeline_primitives.dart](file://lib/src/animation/svg_filters_registry_pipeline_primitives.dart)
- [svg_filters_registry_pipeline.dart](file://lib/src/animation/svg_filters_registry_pipeline.dart)
- [svg_filters_registry_inputs.dart](file://lib/src/animation/svg_filters_registry_inputs.dart)
- [SVGElement.cpp](file://blink-b87d44f-Source-core-svg/SVGElement.cpp)

**Section sources**
- [css_variables_calc.dart](file://lib/src/animation/css_variables_calc.dart)
- [css_cascade.dart](file://lib/src/animation/css_cascade.dart)
- [css_selectors.dart](file://lib/src/animation/css_selectors.dart)
- [svg_dom.dart](file://lib/src/animation/svg_dom.dart)

## Core Components
The enhanced CSS system consists of five primary components working in concert with expanded functionality:

### Enhanced CSS Custom Properties System
The custom properties system provides variable substitution with inheritance, fallback support, and use context propagation:

```mermaid
classDiagram
class CssCustomProperties {
-Map~String, String~ _properties
+get(String) String?
+set(String, String) void
+has(String) bool
+all Map~String, String~
+copy() CssCustomProperties
}
class SvgNodeCssVariablesExtension {
<<extension>>
+cssCustomProperties CssCustomProperties
+parseAndSetCustomProperties(String) void
}
class CssVariableResolver {
+cascadeResolver CssVariablesCascadeResolver?
+resolveValue(String, SvgNode, double?) String
-_lookupVariable(String, SvgNode) String?
-_resolveVarOnce(String, SvgNode, double?) String
+useContextCustomPropertyLookup UseContextCustomPropertyLookup?
}
class CssVariablesCascadeResolver {
<<abstract>>
+resolveCustomProperty(String, SvgNode) String?
}
class CssCascadeVariablesResolver {
<<extends>>
+cascadeResolver CssCascadeResolver
+resolveCustomProperty(String, SvgNode) String?
}
CssCustomProperties --> SvgNodeCssVariablesExtension : "attached to"
CssVariableResolver --> CssCustomProperties : "uses"
CssVariableResolver --> CssVariablesCascadeResolver : "integrates with"
CssCascadeVariablesResolver --> CssCascadeResolver : "uses"
```

**Diagram sources**
- [css_variables_calc.dart](file://lib/src/animation/css_variables_calc.dart)
- [css_cascade.dart](file://lib/src/animation/css_cascade.dart)

### Advanced CSS Calc() Mathematical Evaluator
The calculator supports complex mathematical expressions with CSS functions and enhanced unit handling:

```mermaid
flowchart TD
Start(["Input Value"]) --> CheckMath{"Contains CSS math functions?"}
CheckMath --> |min()/max()/clamp()| ParseMath["Parse CSS Math Function"]
CheckMath --> |calc()| ParseCalc["Parse calc() Expression"]
CheckMath --> |None| CheckVar{"Contains var()?"}
ParseMath --> EvaluateMath["Evaluate Math Function"]
EvaluateMath --> Units["Convert Units to Pixels"]
ParseCalc --> Tokenize["Tokenize Expression"]
Tokenize --> Evaluate["Evaluate with Precedence"]
Evaluate --> Units
CheckVar --> |Yes| ResolveVar["Resolve CSS Variables"]
CheckVar --> |No| ParseSimple["Parse Simple Numeric Value"]
ResolveVar --> CheckMath
ParseSimple --> Units
Units --> Result(["Numeric Result"])
```

**Diagram sources**
- [css_variables_calc.dart](file://lib/src/animation/css_variables_calc.dart)

### Enhanced CSS Structural Pseudo-Classes System
The structural pseudo-classes provide advanced element positioning and type matching:

```mermaid
classDiagram
class CssNthPseudoClass {
+CssNthType type
+int a
+int b
+parse(type, formula) CssNthPseudoClass?
+matches(index) bool
+toString() String
}
class CssNthType {
<<enumeration>>
nthChild
nthLastChild
nthOfType
nthLastOfType
}
class CssPseudoClass {
<<enumeration>>
firstOfType
lastOfType
onlyOfType
}
CssNthPseudoClass --> CssNthType : "uses"
```

**Diagram sources**
- [css_selectors.dart](file://lib/src/animation/css_selectors.dart)

**Section sources**
- [css_variables_calc.dart](file://lib/src/animation/css_variables_calc.dart)
- [css_selectors.dart](file://lib/src/animation/css_selectors.dart)

## Architecture Overview
The enhanced CSS processing pipeline integrates seamlessly with the SVG rendering system, SMIL animations, and filter primitives:

```mermaid
sequenceDiagram
participant Parser as "SVG Parser"
participant DOM as "SvgNode Tree"
participant Resolver as "CssVariableResolver"
participant Cascade as "CssCascadeResolver"
participant NthMatcher as "NthPseudoClass Matcher"
participant Evaluator as "CssCalcEvaluator"
participant Renderer as "SVG Renderer"
Parser->>DOM : Parse SVG with CSS
DOM->>DOM : Store custom properties
DOM->>Resolver : resolveProperty()
Resolver->>Resolver : Lookup var() references
Resolver->>Cascade : resolveCustomProperty()
Cascade->>DOM : Walk up element tree
Cascade->>NthMatcher : Match structural pseudo-classes
NthMatcher->>DOM : Count siblings and types
Resolver->>Evaluator : resolveToNumber()
Evaluator->>Evaluator : Evaluate CSS math functions
Evaluator->>Evaluator : Convert units to pixels
Evaluator-->>Resolver : Numeric result
Resolver-->>Cascade : Final resolved value
Cascade-->>DOM : Cascade resolution
DOM-->>Renderer : Render with resolved values
```

**Diagram sources**
- [css_variables_calc.dart](file://lib/src/animation/css_variables_calc.dart)
- [css_cascade.dart](file://lib/src/animation/css_cascade.dart)
- [css_selectors.dart](file://lib/src/animation/css_selectors.dart)
- [svg_dom.dart](file://lib/src/animation/svg_dom.dart)

The architecture ensures proper CSS cascade resolution, variable inheritance, mathematical computation, structural pseudo-class matching, and seamless integration with SMIL animations and filter processing while maintaining compatibility with the existing SVG rendering pipeline.

**Section sources**
- [css_variables_calc.dart](file://lib/src/animation/css_variables_calc.dart)
- [css_cascade.dart](file://lib/src/animation/css_cascade.dart)
- [css_selectors.dart](file://lib/src/animation/css_selectors.dart)

## Detailed Component Analysis

### Enhanced CSS Variable Resolution Engine
The variable resolution system implements a sophisticated lookup mechanism with improved use context handling and shadow DOM boundary respect:

#### Enhanced Variable Lookup Hierarchy
The resolver follows an improved precedence order with better use context propagation:

1. **Inline Custom Properties**: Highest specificity, checked on the current node and all ancestors
2. **CSS Rule-Based Properties**: Resolved through the new CSS cascade resolver integration
3. **Use Context Properties**: Special handling for variables in `<use>` element contexts with inheritance boundaries
4. **Fallback Values**: Support for nested fallback chains with CSS math function evaluation

#### New CSS Variables Cascade Resolver Integration
- **Cascade-Based Resolution**: Custom properties now integrate with the CSS cascade system for specificity calculation
- **Rule-Based Variable Lookup**: Variables defined in CSS rules are resolved using the same cascade mechanism as regular properties
- **Enhanced Specificity**: Variables follow CSS cascade rules with proper specificity calculation and !important handling

**Section sources**
- [css_variables_calc.dart](file://lib/src/animation/css_variables_calc.dart)
- [css_cascade.dart](file://lib/src/animation/css_cascade.dart)
- [css_variables_calc_test.dart](file://test/animation/css_variables_calc_test.dart)
- [animated_svg_painter_use.dart](file://lib/src/animation/animated_svg_painter_use.dart)
- [animated_svg_painter_tree.dart](file://lib/src/animation/animated_svg_painter_tree.dart)

### Advanced CSS Calc() Mathematical Evaluator
The calculator now supports comprehensive CSS mathematical functions with enhanced error handling:

#### Enhanced Supported Operations
- **Basic Arithmetic**: Addition, subtraction, multiplication, division
- **CSS Math Functions**: `min()`, `max()`, `clamp()` with multiple arguments
- **Unit Conversions**: Enhanced px, em, rem, pt, pc, in, cm, mm, %, ex, ch, vw, vh, vmin, vmax
- **Nested Expressions**: Deep recursive evaluation of complex formulas
- **CSS Function Composition**: Nested CSS functions within calc()

#### Improved Precision and Edge Cases
- **Operator Precedence**: Correct mathematical order of operations with CSS function precedence
- **Division by Zero**: Graceful handling returning zero with enhanced error reporting
- **Percentage Calculations**: Container-relative percentage computations with fallbacks
- **Unit Compatibility**: Intelligent conversion between different unit types with precision handling

**Section sources**
- [css_variables_calc.dart](file://lib/src/animation/css_variables_calc.dart)
- [css_property_rendering_test.dart](file://test/animation/css_property_rendering_test.dart)

### Enhanced CSS Cascade Integration
The system integrates with an improved CSS cascade mechanism featuring better specificity calculation and shadow DOM handling:

#### Advanced Specificity Calculation
- **Enhanced Selector Matching**: Improved handling of complex selectors with combinators and structural pseudo-classes
- **Shadow DOM Respect**: Proper specificity calculation across `<use>` and `<symbol>` boundaries
- **Pseudo-Class State Integration**: Dynamic specificity calculation with hover, active, focus states
- **CSS Function Support**: Specificity calculation for selectors with CSS functions

#### Improved Inheritance Model
- **Selective Inheritance**: Inheritable properties limited to CSS/SVG specification compliance
- **Use Boundary Handling**: Proper inheritance across `<use>` element boundaries
- **Presentation Attribute Priority**: Enhanced handling of presentation attributes vs CSS rules
- **!important Handling**: Improved `!important` resolution with cascade precedence

**Section sources**
- [css_cascade.dart](file://lib/src/animation/css_cascade.dart)
- [css_cascade_specificity_test.dart](file://test/animation/css_cascade_specificity_test.dart)
- [advanced_use_inheritance_test.dart](file://test/animation/advanced_use_inheritance_test.dart)
- [use_css_cascade_test.dart](file://test/animation/use_css_cascade_test.dart)

### SVG DOM Integration
The CSS system maintains deep integration with the SVG DOM structure and enhanced rendering pipeline:

#### Enhanced Node Extensions
- **Custom Property Storage**: Weak-map pattern with improved memory management
- **Attribute Type System**: Enhanced typed attribute handling for animations
- **Inheritance Tracking**: Automatic propagation of CSS properties with use context
- **Shadow DOM Awareness**: Proper handling of use/symbol boundaries in property resolution

#### Advanced Rendering Pipeline
- **Dynamic Resolution**: Real-time variable and calculation evaluation with caching
- **Animation Compatibility**: Seamless integration with SMIL and CSS animations
- **Performance Optimization**: Advanced caching strategies and lazy evaluation
- **Error Recovery**: Graceful handling of malformed CSS and circular references

**Section sources**
- [svg_dom.dart](file://lib/src/animation/svg_dom.dart)
- [animated_svg_painter_use.dart](file://lib/src/animation/animated_svg_painter_use.dart)

## Enhanced CSS Cascade Processing
The CSS cascade system has been significantly enhanced with improved selector specificity handling, shadow DOM boundary management, and new CSS variables cascade resolver integration:

### Advanced Selector Specificity Calculation
The specificity calculator now handles complex selectors with enhanced accuracy:

```mermaid
flowchart TD
Start(["CSS Selector"]) --> Clean["Normalize & Clean Selector"]
Clean --> Split["Split by Combinators"]
Split --> Parts["Process Each Selector Part"]
Parts --> CountID["Count ID Selectors"]
Parts --> CountClass["Count Class/Attribute Selectors"]
Parts --> CountElement["Count Element/Pseudo-Element Selectors"]
CountID --> Combine["Combine Specificity Values"]
CountClass --> Combine
CountElement --> Combine
Combine --> Result(["CssSpecificity(a,b,c,d)"])
```

**Diagram sources**
- [css_cascade.dart](file://lib/src/animation/css_cascade.dart)

### Enhanced Shadow DOM Boundary Management
The cascade resolver now properly respects shadow DOM boundaries for complex selector matching:

- **Use Element Boundaries**: Stop selector matching at `<use>` element boundaries
- **Symbol Element Boundaries**: Respect `<symbol>` element shadow scope
- **Complex Selector Traversal**: Proper ancestor/descendant matching across boundaries
- **Pseudo-Class State Preservation**: Maintain pseudo-class state across use boundaries

### New CSS Variables Cascade Resolver
The system now includes a dedicated cascade resolver for CSS custom properties:

- **Rule-Based Variable Resolution**: Variables defined in CSS rules are resolved using cascade specificity
- **Integration with CSS Rules**: Custom properties participate in the same cascade mechanism as regular CSS properties
- **Enhanced Specificity Handling**: Variables follow CSS cascade rules with proper !important precedence

**Section sources**
- [css_cascade.dart](file://lib/src/animation/css_cascade.dart)
- [css_cascade_specificity_test.dart](file://test/animation/css_cascade_specificity_test.dart)
- [css_variables_calc.dart](file://lib/src/animation/css_variables_calc.dart)

## Advanced CSS Variables and Calculations
The CSS variables and calculations system has been comprehensively enhanced with CSS math function support, new cascade resolver integration, and improved error handling:

### CSS Math Function Support
The system now fully supports CSS mathematical functions within variable resolution:

#### Supported CSS Math Functions
- **min() Function**: Returns smallest value from multiple arguments
- **max() Function**: Returns largest value from multiple arguments  
- **clamp() Function**: Constrains value within minimum and maximum bounds
- **Nested Function Support**: CSS functions can be nested within each other

#### Enhanced Variable Resolution
- **CSS Function Evaluation**: Variables containing CSS math functions are evaluated
- **Fallback Chain Enhancement**: CSS functions in fallback chains are properly resolved
- **Unit Preservation**: Units are preserved during CSS function calculations
- **Error Recovery**: Graceful handling of invalid CSS function syntax

### Advanced Use Context Inheritance
The system now provides comprehensive use context inheritance for CSS properties:

#### Use Context Propagation
- **Inheritable Property Filtering**: Only CSS/SVG inheritable properties flow through use boundaries
- **Property Type Validation**: Ensures only appropriate properties are inherited
- **Boundary Respect**: Proper respect for use/symbol element boundaries
- **Recursive Use Handling**: Prevention of infinite recursion with depth limiting

#### Enhanced CSS Property Inheritance
- **Color Properties**: color, fill, stroke, stroke-color inheritance
- **Font Properties**: Complete font family and sizing inheritance
- **Text Properties**: Text alignment, spacing, and transformation inheritance
- **SVG-Specific Properties**: fill-opacity, stroke properties, marker inheritance

**Section sources**
- [css_variables_calc.dart](file://lib/src/animation/css_variables_calc.dart)
- [css_property_rendering_test.dart](file://test/animation/css_property_rendering_test.dart)
- [animated_svg_painter_use.dart](file://lib/src/animation/animated_svg_painter_use.dart)
- [animated_svg_painter_tree.dart](file://lib/src/animation/animated_svg_painter_tree.dart)

## Structural Pseudo-Classes and Matching Algorithms
The enhanced CSS system now provides comprehensive support for structural pseudo-classes with advanced matching algorithms:

### Enhanced Structural Pseudo-Class Support
The system now supports all major CSS structural pseudo-classes:

#### Supported Structural Pseudo-Classes
- **nth-child(an+b)**: Matches elements based on their position among siblings
- **nth-last-child(an+b)**: Matches elements based on position from the end
- **nth-of-type(an+b)**: Matches elements based on position among siblings of the same type
- **nth-last-of-type(an+b)**: Matches elements based on position from the end among siblings of the same type
- **first-of-type**: Matches the first sibling of its type
- **last-of-type**: Matches the last sibling of its type
- **only-of-type**: Matches when there is only one sibling of its type

#### Advanced Matching Algorithms
The matching algorithms implement precise CSS specification compliance:

```mermaid
flowchart TD
Start(["Element Node"]) --> CheckParent{"Has Parent?"}
CheckParent --> |No| ReturnTrue["Return True"]
CheckParent --> |Yes| GetSiblings["Get Parent Children"]
GetSiblings --> CalcIndex["Calculate Position Index"]
CalcIndex --> CheckType{"Check Pseudo-Class Type"}
CheckType --> |nth-child| UseChildIndex["Use 1-based child index"]
CheckType --> |nth-last-child| UseReverseIndex["Use reverse 1-based index"]
CheckType --> |nth-of-type| CountSameType["Count siblings of same type"]
CheckType --> |nth-last-of-type| CountSameTypeRev["Count siblings of same type from end"]
CheckType --> |first-of-type| FirstOfType["Check if first of type"]
CheckType --> |last-of-type| LastOfType["Check if last of type"]
CheckType --> |only-of-type| OnlyOfType["Check if only of type"]
UseChildIndex --> EvaluateFormula["Evaluate an+b Formula"]
UseReverseIndex --> EvaluateFormula
CountSameType --> EvaluateFormula
CountSameTypeRev --> EvaluateFormula
FirstOfType --> Result["Return Boolean"]
LastOfType --> Result
OnlyOfType --> Result
EvaluateFormula --> Result["Return Boolean"]
```

**Diagram sources**
- [css_selectors.dart](file://lib/src/animation/css_selectors.dart)
- [css_cascade.dart](file://lib/src/animation/css_cascade.dart)

#### Enhanced CSS Selector Parsing
The selector parser now handles structural pseudo-classes with comprehensive support:

- **Functional Pseudo-Classes**: Proper parsing of `:nth-child(2n+1)`, `:nth-of-type(odd)`, etc.
- **Keyword Support**: Recognition of `odd`, `even`, and direct number specifications
- **Formula Parsing**: Accurate parsing of the an+b formula with sign handling
- **Type-Specific Matching**: Distinction between child-based and type-based positioning

**Section sources**
- [css_selectors.dart](file://lib/src/animation/css_selectors.dart)
- [css_property_rendering_test.dart](file://test/animation/css_property_rendering_test.dart)
- [css_cascade.dart](file://lib/src/animation/css_cascade.dart)

### Advanced Structural Pseudo-Class Matching
The matching system implements precise CSS specification compliance:

#### Position-Based Matching
- **nth-child**: Uses 1-based indexing from the start of siblings
- **nth-last-child**: Uses 1-based indexing from the end of siblings
- **Formula Evaluation**: Proper evaluation of an+b formulas with integer solutions

#### Type-Based Matching
- **nth-of-type**: Counts only siblings with the same tag name
- **nth-last-of-type**: Counts from the end among siblings of the same type
- **Type Preservation**: Maintains type-specific counting across different element types

#### Simple Type Matching
- **first-of-type**: Matches the first sibling with the same type
- **last-of-type**: Matches the last sibling with the same type
- **only-of-type**: Matches when exactly one sibling has the same type

**Section sources**
- [css_cascade.dart](file://lib/src/animation/css_cascade.dart)
- [css_property_rendering_test.dart](file://test/animation/css_property_rendering_test.dart)

## Modern CSS Unit Support
The enhanced CSS system now provides comprehensive support for modern CSS units including ex, ch, and lh units with precise conversion algorithms:

### Enhanced Unit Conversion System
The system now supports a comprehensive range of CSS units with intelligent conversion logic:

#### Standard Units Support
- **Absolute Units**: px, pt, pc, in, cm, mm, q with precise conversion factors
- **Relative Units**: em, rem, % with proper contextual calculations
- **Viewport Units**: vw, vh, vmin, vmax (returned as-is without conversion)
- **Character Units**: ex, ch with font-specific character width calculations
- **Line Units**: lh with line-height approximation

#### Advanced Character Unit Calculations
- **ex Unit**: Width of lowercase 'x' character, approximately 0.5em
- **ch Unit**: Width of '0' character, approximately 0.5em  
- **lh Unit**: Line height of element, approximated as 1.2em
- **Font Size Context**: Proper handling of parent vs current font size context

#### Enhanced Percentage Calculations
- **Container Relative**: Percentages calculated relative to container dimensions
- **Fallback Behavior**: Graceful handling when container size is unavailable
- **Context Awareness**: Different percentage behaviors for different CSS properties

**Section sources**
- [css_variables_calc.dart](file://lib/src/animation/css_variables_calc.dart)
- [css_property_rendering_test.dart](file://test/animation/css_property_rendering_test.dart)

### Advanced Unit Conversion Algorithms
The unit conversion system implements sophisticated algorithms for modern CSS unit support:

```mermaid
flowchart TD
Start(["Unit Value"]) --> CheckUnit{"Unit Type?"}
CheckUnit --> |px/em/rem/ex/ch/lh| FontContext["Apply Font Context"]
CheckUnit --> |%| ContainerContext["Apply Container Context"]
CheckUnit --> |Absolute| DirectConvert["Direct Conversion"]
CheckUnit --> |Viewport| ReturnAsIs["Return As Is"]
FontContext --> Calculate["Calculate Based on Context"]
ContainerContext --> Calculate
DirectConvert --> Calculate
Calculate --> Result(["Converted Value"])
```

**Diagram sources**
- [css_variables_calc.dart](file://lib/src/animation/css_variables_calc.dart)

**Section sources**
- [css_variables_calc.dart](file://lib/src/animation/css_variables_calc.dart)
- [css_property_rendering_test.dart](file://test/animation/css_property_rendering_test.dart)

## SMIL Animation Enhancements
The SMIL animation system has been enhanced with improved motion path parsing and timeline synchronization:

### Enhanced Motion Path Parsing
The animateMotion parser now provides comprehensive path data resolution:

#### Multi-Source Path Resolution
- **Direct Path Data**: Support for inline path attribute values
- **MPATH Reference**: Enhanced mpath element reference resolution
- **Switch Element Support**: Conditional path selection based on system capabilities
- **Coordinate Pair Fallback**: Automatic generation of path data from coordinate values

#### Advanced Path Data Processing
- **Complex Path Commands**: Full support for SVG path syntax
- **Coordinate System Handling**: Proper coordinate transformation and scaling
- **Rotation Mode Support**: Enhanced rotate attribute processing (auto, auto-reverse, angle)
- **Key Point Integration**: Support for keyPoints, keyTimes, and keySplines timing

**Section sources**
- [smil_parser_motion.dart](file://lib/src/animation/smil/smil_parser_motion.dart)

### Enhanced Timeline Synchronization
The timeline system now provides comprehensive syncbase timing support:

#### Advanced Syncbase Event Handling
- **Begin/End Event Propagation**: Automatic triggering of dependent animations
- **Repeat Event Support**: Sophisticated repeat cycle timing with index tracking
- **Offset Condition Processing**: Precise timing offset application
- **Circular Dependency Detection**: Prevention of infinite syncbase loops

#### Enhanced Event-Based Animation
- **DOM Event Integration**: beginEvent, endEvent, repeatEvent dispatching
- **Event Listener Registration**: Dynamic animation activation based on DOM events
- **Event Time Tracking**: Accurate event timing with timestamp management
- **External Listener Support**: Integration with external animation event handlers

**Section sources**
- [smil_timeline_syncbase.dart](file://lib/src/animation/smil/smil_timeline_syncbase.dart)
- [smil_timeline_runtime.dart](file://lib/src/animation/smil/smil_timeline_runtime.dart)

## Filter Primitive Pipeline Improvements
The filter primitive system has been enhanced with comprehensive pipeline processing and circular reference detection:

### Advanced Filter Pipeline Processing
The filter registry now provides sophisticated pipeline optimization:

#### Enhanced Primitive Resolution
- **Circular Reference Detection**: Prevention of infinite filter chain loops
- **Named Result Caching**: Efficient reuse of intermediate filter results
- **Multi-Hop Chain Support**: Complex filter chains with multiple intermediate steps
- **Input Graph Hardening**: Robust input resolution with fallback mechanisms

#### Advanced Filter Primitive Support
- **Gaussian Blur**: Enhanced blur radius calculation with multi-pass optimization
- **Morphology Operations**: Advanced erosion and dilation with kernel customization
- **Displacement Mapping**: Sophisticated texture displacement with wrap modes
- **Lighting Effects**: Comprehensive lighting model with multiple light sources

**Section sources**
- [svg_filters_registry_pipeline_primitives.dart](file://lib/src/animation/svg_filters_registry_pipeline_primitives.dart)
- [svg_filters_registry_pipeline.dart](file://lib/src/animation/svg_filters_registry_pipeline.dart)
- [svg_filters_registry_inputs.dart](file://lib/src/animation/svg_filters_registry_inputs.dart)

### Enhanced Input Resolution
The input system now provides comprehensive filter input handling:

#### Advanced Input Processing
- **Built-in Input Support**: sourceGraphic, sourceAlpha, background, backgroundAlpha
- **Named Result Resolution**: Multi-hop input chain resolution with caching
- **None Input Handling**: Explicit transparent-black input processing
- **Result Reuse Optimization**: Efficient sharing of intermediate filter results

#### Input Graph Hardening
- **Circular Reference Prevention**: Detection and handling of filter chain loops
- **Result Caching Strategy**: Prevent accidental mutation of cached filter results
- **Multi-Primitive Sharing**: Support for multiple downstream primitives using same input
- **Fallback Mechanisms**: Graceful degradation when filter inputs are unavailable

**Section sources**
- [svg_filters_registry_inputs.dart](file://lib/src/animation/svg_filters_registry_inputs.dart)

## Dependency Analysis
The enhanced CSS system maintains carefully managed dependencies with improved modularity and performance:

```mermaid
graph LR
subgraph "Enhanced Core Dependencies"
A["svg_dom.dart"] --> B["css_variables_calc.dart"]
A --> C["css_cascade.dart"]
B --> D["css_calc_evaluator"]
C --> E["css_specificity"]
C --> F["css_selectors"]
B --> G["css_cascade_resolver"]
G --> C
end
subgraph "Enhanced Integration Points"
H["animated_svg_painter_use.dart"] --> B
I["animated_svg_painter_tree.dart"] --> H
J["smil_parser_motion.dart"] --> K["smil_timeline_syncbase.dart"]
K --> L["smil_timeline_runtime.dart"]
M["svg_filters_registry_pipeline_primitives.dart"] --> N["svg_filters_registry_pipeline.dart"]
N --> O["svg_filters_registry_inputs.dart"]
end
subgraph "Testing Layer"
P["css_variables_calc_test.dart"] --> B
Q["css_property_rendering_test.dart"] --> B
R["css_cascade_specificity_test.dart"] --> C
S["css_property_rendering_test.dart"] --> F
T["advanced_use_inheritance_test.dart"] --> C
U["use_css_cascade_test.dart"] --> C
V["css_selectors_combinators_test.dart"] --> F
end
```

**Diagram sources**
- [css_variables_calc.dart](file://lib/src/animation/css_variables_calc.dart)
- [css_cascade.dart](file://lib/src/animation/css_cascade.dart)
- [css_selectors.dart](file://lib/src/animation/css_selectors.dart)
- [svg_dom.dart](file://lib/src/animation/svg_dom.dart)
- [animated_svg_painter_use.dart](file://lib/src/animation/animated_svg_painter_use.dart)
- [animated_svg_painter_tree.dart](file://lib/src/animation/animated_svg_painter_tree.dart)
- [smil_parser_motion.dart](file://lib/src/animation/smil/smil_parser_motion.dart)
- [smil_timeline_syncbase.dart](file://lib/src/animation/smil/smil_timeline_syncbase.dart)
- [smil_timeline_runtime.dart](file://lib/src/animation/smil/smil_timeline_runtime.dart)
- [svg_filters_registry_pipeline_primitives.dart](file://lib/src/animation/svg_filters_registry_pipeline_primitives.dart)
- [svg_filters_registry_pipeline.dart](file://lib/src/animation/svg_filters_registry_pipeline.dart)
- [svg_filters_registry_inputs.dart](file://lib/src/animation/svg_filters_registry_inputs.dart)

The enhanced dependency graph shows improved separation of concerns with better modularization, enhanced SMIL and filter system integration, CSS variables cascade resolver integration, and minimal circular dependencies for optimal maintainability and testability.

**Section sources**
- [css_variables_calc.dart](file://lib/src/animation/css_variables_calc.dart)
- [css_cascade.dart](file://lib/src/animation/css_cascade.dart)
- [css_selectors.dart](file://lib/src/animation/css_selectors.dart)

## Performance Considerations
The enhanced implementation includes several advanced performance optimizations:

### Memory Management
- **Weak Map Pattern**: Custom property storage with automatic garbage collection
- **String Interning**: Repeated property values share memory efficiently
- **Lazy Evaluation**: Calculations performed only when needed with caching
- **Circular Reference Protection**: Prevention of memory leaks in complex filter chains

### Computational Efficiency
- **Enhanced Caching Strategies**: CSS rule matching, specificity calculations, variable resolution, and structural pseudo-class matching cached
- **Early Termination**: Variable resolution stops at first match with use context handling
- **Optimized Parsing**: Regex-based parsing with minimal backtracking and CSS function recognition
- **Pipeline Optimization**: Filter primitive output caching and result sharing

### Rendering Integration
- **Incremental Updates**: Only affected nodes re-evaluate CSS with use context awareness
- **Batch Processing**: Multiple property updates processed together with cascade optimization
- **Resource Pooling**: Reusable buffers and temporary objects with enhanced lifecycle management
- **SMIL Timeline Optimization**: Efficient dependency graph building and event propagation
- **Structural Pseudo-Class Caching**: Matching results cached based on element position and type

## Troubleshooting Guide

### Common Issues and Solutions

#### Enhanced Variable Resolution Problems
- **Issue**: Variables not resolving in `<use>` contexts with shadow DOM boundaries
- **Solution**: Verify use context is properly established and `useContextCustomPropertyLookup` is set with inheritable property filtering

#### CSS Variables Cascade Resolver Issues
- **Issue**: Custom properties not following CSS cascade rules
- **Solution**: Ensure `CssCascadeVariablesResolver` is properly configured and integrated with the main `CssCascadeResolver`

#### Structural Pseudo-Class Matching Problems
- **Issue**: Structural pseudo-classes not matching expected elements
- **Solution**: Verify element hierarchy and ensure proper tag name matching for type-based pseudo-classes

#### Advanced CSS Function Errors
- **Issue**: Unexpected results with CSS math functions in variables
- **Solution**: Ensure CSS functions are properly formatted and supported, verify unit compatibility and container size parameters

#### Modern Unit Conversion Issues
- **Issue**: Incorrect ex, ch, or lh unit calculations
- **Solution**: Verify font size context is properly passed (fontSize vs parentFontSize), check that fallback font sizes are available

#### SMIL Animation Synchronization Issues
- **Issue**: Motion animations not synchronizing with timeline events
- **Solution**: Verify syncbase conditions are properly configured, check event listener registration, and ensure circular dependency detection is not preventing animation activation

#### Filter Pipeline Performance Degradation
- **Issue**: Slow rendering with complex filter chains
- **Solution**: Simplify filter primitive combinations, reduce named result reuse complexity, and optimize filter input graph structure

#### Enhanced Testing and Validation
The comprehensive test suite covers edge cases, integration scenarios, structural pseudo-class matching, and enhanced functionality:

**Section sources**
- [css_variables_calc_test.dart](file://test/animation/css_variables_calc_test.dart)
- [css_property_rendering_test.dart](file://test/animation/css_property_rendering_test.dart)
- [css_cascade_specificity_test.dart](file://test/animation/css_cascade_specificity_test.dart)
- [advanced_use_inheritance_test.dart](file://test/animation/advanced_use_inheritance_test.dart)
- [use_css_cascade_test.dart](file://test/animation/use_css_cascade_test.dart)
- [css_selectors_combinators_test.dart](file://test/animation/css_selectors_combinators_test.dart)

## Conclusion
The Enhanced CSS Variables and Calculations system provides a robust, standards-compliant implementation that seamlessly integrates with Flutter's SVG rendering pipeline. The system successfully combines CSS custom properties, mathematical expressions, CSS math functions, structural pseudo-classes, and the cascade mechanism while maintaining excellent performance and memory efficiency. The comprehensive testing coverage, enhanced SMIL animation support, advanced filter primitive processing, improved use context inheritance, modern CSS unit support, and new CSS variables cascade resolver integration ensure reliability across diverse SVG use cases and complex styling scenarios. The system's architecture supports future enhancements while maintaining backward compatibility and optimal performance characteristics.