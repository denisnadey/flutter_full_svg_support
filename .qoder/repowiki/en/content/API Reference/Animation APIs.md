# Animation APIs

<cite>
**Referenced Files in This Document**
- [animated_svg_controller.dart](file://lib/src/animation/animated_svg_controller.dart)
- [animated_svg_picture.dart](file://lib/src/animation/animated_svg_picture.dart)
- [animated_svg_picture_lifecycle.dart](file://lib/src/animation/animated_svg_picture_lifecycle.dart)
- [animated_svg_painter_text_style.dart](file://lib/src/animation/animated_svg_painter_text_style.dart)
- [animated_svg_painter.dart](file://lib/src/animation/animated_svg_painter.dart)
- [smil_timeline.dart](file://lib/src/animation/smil/smil_timeline.dart)
- [smil_timeline_info.dart](file://lib/src/animation/smil/smil_timeline_info.dart)
- [smil_animation.dart](file://lib/src/animation/smil/smil_animation.dart)
- [smil_parser.dart](file://lib/src/animation/smil/smil_parser.dart)
- [css_to_smil_converter.dart](file://lib/src/animation/css_to_smil_converter.dart)
- [controller_test.dart](file://test/animation/controller_test.dart)
- [css_animations_test.dart](file://test/animation/css_animations_test.dart)
- [stroke_dash_stop_color_test.dart](file://test/animation/stroke_dash_stop_color_test.dart)
- [text_decoration_thickness_test.dart](file://test/animation/text_decoration_thickness_test.dart)
- [text_underline_position_test.dart](file://test/animation/text_underline_position_test.dart)
- [text_emphasis_test.dart](file://test/animation/text_emphasis_test.dart)
- [ruby_align_test.dart](file://test/animation/ruby_align_test.dart)
- [font_variation_settings_test.dart](file://test/animation/font_variation_settings_test.dart)
- [animation.dart](file://lib/src/animation.dart)
</cite>

## Update Summary
**Changes Made**
- Enhanced AnimatedSvgPainterTextStyleExtension with comprehensive CSS property resolution methods
- Added support for 53 CSS text styling properties including text-decoration-thickness, text-underline-position, text-emphasis, ruby-align, font-variation-settings, and comprehensive typography features
- Implemented extensive unit conversion support (px, em, %, rem) with inheritance patterns and fallback mechanisms
- Expanded text rendering capabilities with advanced typography features and internationalization support

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
This document describes the animation APIs for Flutter SVG, focusing on the AnimatedSvgController, timeline management, and animation control methods. It covers controller methods for play, pause, stop, seek, and loop control; timeline properties such as duration, position, status, and playback rate; animation state management and event callbacks; and integration with Flutter animation widgets. It also documents SMIL animation parsing, CSS animation conversion, and animation composition, with examples of programmatic control, synchronization, and custom behaviors. Finally, it addresses performance optimization, memory management, and debugging techniques.

**Updated** Enhanced text styling system now supports comprehensive CSS property resolution with advanced unit conversions and inheritance patterns, covering 53 advanced text styling properties including typography, internationalization, and accessibility features.

## Project Structure
The animation system is organized around:
- AnimatedSvgController: Programmatic control surface for playback state and direction.
- AnimatedSvgPicture: Widget that renders animated SVG and manages lifecycle, timeline, and event-driven animations.
- SvgTimeline: Central timeline orchestrating SMIL animations, timing, and event triggers.
- SmilAnimation: Individual SMIL animation definitions and runtime evaluation.
- SmilParser and CssToSmilConverter: Parsers that extract and normalize SMIL and CSS animations into a unified runtime model.
- AnimatedSvgPainterTextStyleExtension: Comprehensive CSS text styling resolution with 53 properties and advanced unit conversions.
- Tests and examples: Demonstrate controller usage, CSS-to-SMIL conversion, and synchronization.

```mermaid
graph TB
Controller["AnimatedSvgController"] --> Picture["AnimatedSvgPicture"]
Picture --> Timeline["SvgTimeline"]
Timeline --> Anim["SmilAnimation"]
Parser["SmilParser"] --> Timeline
Converter["CssToSmilConverter"] --> Timeline
Picture --> TextStyleExt["AnimatedSvgPainterTextStyleExtension"]
TextStyleExt --> ResolvedStyle["_ResolvedTextStyle"]
Picture --> Lifecycle["_AnimatedSvgPictureState lifecycle"]
Lifecycle --> Timeline
```

**Diagram sources**
- [animated_svg_controller.dart:25-131](file://lib/src/animation/animated_svg_controller.dart#L25-L131)
- [animated_svg_picture.dart:108-359](file://lib/src/animation/animated_svg_picture.dart#L108-L359)
- [animated_svg_picture_lifecycle.dart:177-220](file://lib/src/animation/animated_svg_picture_lifecycle.dart#L177-L220)
- [animated_svg_painter_text_style.dart:3-325](file://lib/src/animation/animated_svg_painter_text_style.dart#L3-L325)
- [animated_svg_painter.dart:258-700](file://lib/src/animation/animated_svg_painter.dart#L258-L700)
- [smil_timeline.dart:20-256](file://lib/src/animation/smil/smil_timeline.dart#L20-L256)
- [smil_animation.dart:80-453](file://lib/src/animation/smil/smil_animation.dart#L80-L453)
- [smil_parser.dart:13-39](file://lib/src/animation/smil/smil_parser.dart#L13-L39)
- [css_to_smil_converter.dart:15-68](file://lib/src/animation/css_to_smil_converter.dart#L15-L68)

**Section sources**
- [animation.dart:1-31](file://lib/src/animation.dart#L1-L31)

## Core Components
- AnimatedSvgController: Provides playback control (pause, resume, toggle), seek, playback rate, direction (forward/reverse), restart, and listener notifications.
- SvgTimeline: Manages global time, playback rate, activation/deactivation of animations, total duration computation, and event-based triggers.
- SmilAnimation: Encapsulates animation definition (type, attributes, values, timing, calc mode, fill mode, additive/accumulate), runtime state, and value computation.
- SmilParser: Extracts SMIL and CSS animations from the SVG DOM and converts CSS animations to SMIL equivalents.
- AnimatedSvgPainterTextStyleExtension: Comprehensive CSS text styling resolution supporting 53 properties with advanced unit conversions, inheritance patterns, and fallback mechanisms.
- AnimatedSvgPicture: Widget that parses SVG, builds the timeline, drives frame ticks via AnimationController, and exposes play/pause/reset/seek APIs.

**Section sources**
- [animated_svg_controller.dart:25-131](file://lib/src/animation/animated_svg_controller.dart#L25-L131)
- [smil_timeline.dart:20-256](file://lib/src/animation/smil/smil_timeline.dart#L20-L256)
- [smil_animation.dart:80-453](file://lib/src/animation/smil/smil_animation.dart#L80-L453)
- [smil_parser.dart:13-39](file://lib/src/animation/smil/smil_parser.dart#L13-L39)
- [animated_svg_painter_text_style.dart:3-325](file://lib/src/animation/animated_svg_painter_text_style.dart#L3-L325)
- [animated_svg_picture.dart:108-359](file://lib/src/animation/animated_svg_picture.dart#L108-L359)

## Architecture Overview
The system integrates Flutter's AnimationController with a custom SvgTimeline to synchronize widget rendering with SMIL/CSS animation evaluation. The enhanced text styling system provides comprehensive CSS property resolution with advanced unit conversions and inheritance patterns.

```mermaid
sequenceDiagram
participant Client as "Client Code"
participant Controller as "AnimatedSvgController"
participant Picture as "AnimatedSvgPicture"
participant AC as "AnimationController"
participant TL as "SvgTimeline"
participant TextStyleExt as "AnimatedSvgPainterTextStyleExtension"
participant ResolvedStyle as "_ResolvedTextStyle"
Client->>Controller : "seek()/setPlaybackRate()/reverse()/restart()"
Controller-->>Picture : "notifyListeners()"
Picture->>AC : "forward()/stop()/reset() or set value"
AC-->>Picture : "_onAnimationTick()"
Picture->>TL : "seek(elapsed)"
TL-->>Picture : "active animations updated"
Picture->>TextStyleExt : "_resolveTextStyle(node)"
TextStyleExt->>ResolvedStyle : "create resolved style"
Picture-->>Client : "repaint with new frame"
```

**Diagram sources**
- [animated_svg_controller.dart:44-122](file://lib/src/animation/animated_svg_controller.dart#L44-L122)
- [animated_svg_picture.dart:272-294](file://lib/src/animation/animated_svg_picture.dart#L272-L294)
- [animated_svg_picture_lifecycle.dart:177-220](file://lib/src/animation/animated_svg_picture_lifecycle.dart#L177-L220)
- [smil_timeline.dart:88-98](file://lib/src/animation/smil/smil_timeline.dart#L88-L98)
- [animated_svg_painter_text_style.dart:4-325](file://lib/src/animation/animated_svg_painter_text_style.dart#L4-L325)

## Detailed Component Analysis

### AnimatedSvgController API
- Purpose: Programmatic control of playback state, direction, and seeking.
- Key methods and properties:
  - isPaused: Boolean indicating paused state.
  - playbackRate: Positive multiplier for playback speed.
  - isReversed: Direction flag.
  - pendingSeek: Current seek target if set.
  - pause(), resume(), togglePlayPause(): Control playback.
  - seek(Duration): Set a pending seek target; controller notifies listeners.
  - setPlaybackRate(double): Enforces positive rate; throws on invalid values.
  - reverse(), forward(), toggleDirection(): Control direction.
  - restart(): Reset to beginning and unpause.
  - clearPendingSeek(): Internal method to clear pending seek after consumption.

Usage highlights:
- Listener pattern: Add listeners to react to state changes (pause, resume, seek, rate change).
- Integration: AnimatedSvgPicture subscribes to controller updates and adjusts playback accordingly.

**Section sources**
- [animated_svg_controller.dart:25-131](file://lib/src/animation/animated_svg_controller.dart#L25-L131)
- [controller_test.dart:121-140](file://test/animation/controller_test.dart#L121-L140)

### Timeline Management (SvgTimeline)
- Purpose: Central orchestration of time, activation of animations, and event-driven triggers.
- Properties:
  - currentTime: Current global time.
  - totalDuration: Computed maximum end time across all animations.
  - playbackRate: Positive multiplier affecting tick deltas.
- Methods:
  - tick(Duration): Advance time by delta scaled by playbackRate; update active animations.
  - seek(Duration): Clamp to [0, totalDuration]; update active animations.
  - reset(): Reset to start, clear event times and resolved begin times, reinitialize animations.
  - triggerEvent(String?, String): Fire event-based animations keyed by elementId and eventType; update animations.
  - getActiveAnimations(), hasActiveAnimations(): Query active state.
  - getInfo(): Returns TimelineInfo with current time, total duration, counts, and playback rate.
- Timing resolution:
  - Computes effective begin/end times, supports syncbase timing, and handles infinite durations gracefully.

**Section sources**
- [smil_timeline.dart:20-256](file://lib/src/animation/smil/smil_timeline.dart#L20-L256)
- [smil_timeline_info.dart:1-48](file://lib/src/animation/smil/smil_timeline_info.dart#L1-L48)

### Animation Control Methods in AnimatedSvgPicture
- Public methods:
  - play(): Forward the internal AnimationController.
  - pause(): Stop the internal AnimationController.
  - reset(): Reset controller and timeline.
  - seekTo(Duration): Convert absolute time to progress and set controller value clamped to [0,1].
- Lifecycle integration:
  - Subscribes to controller updates and toggles reverse direction if needed.
  - Converts controller progress to elapsed time and seeks the timeline on each tick.

**Section sources**
- [animated_svg_picture.dart:272-294](file://lib/src/animation/animated_svg_picture.dart#L272-L294)
- [animated_svg_picture_lifecycle.dart:177-220](file://lib/src/animation/animated_svg_picture_lifecycle.dart#L177-L220)

### Enhanced Text Styling System (AnimatedSvgPainterTextStyleExtension)
- Purpose: Comprehensive CSS text styling resolution with advanced unit conversions and inheritance patterns.
- Features:
  - Resolves 53 CSS text styling properties with advanced unit conversions (px, em, %, rem).
  - Supports inheritance patterns for cascading style application.
  - Implements fallback mechanisms for property resolution.
  - Handles complex text rendering scenarios including vertical writing modes and ruby annotations.
- Key resolution methods:
  - `_resolveTextStyle(SvgNode)`: Main entry point for comprehensive text style resolution.
  - Unit conversion support: Handles percentages, em units, pixel values, and mixed units.
  - Inheritance patterns: Resolves properties from parent nodes when not explicitly set.
  - Fallback mechanisms: Provides sensible defaults for missing or invalid values.
  - Advanced typography: Supports font features, text decorations, and complex layout properties.
- **Updated** Comprehensive coverage of advanced CSS properties including:
  - Text decoration enhancements: text-decoration-thickness, text-underline-position, text-decoration-skip-ink, text-decoration-skip
  - Typography features: font-variation-settings for variable fonts, font-variant-numeric, font-variant-ligatures, font-variant-caps
  - Internationalization: ruby-align, ruby-position, text-emphasis, text-emphasis-position, text-emphasis-color, text-emphasis-style
  - Accessibility and rendering: forced-color-adjust, print-color-adjust, will-change, content-visibility, contain-intrinsic-size
  - Advanced layout: text-wrap, text-spacing, hyphenate-character, mix-blend-mode

**Section sources**
- [animated_svg_painter_text_style.dart:3-325](file://lib/src/animation/animated_svg_painter_text_style.dart#L3-L325)
- [animated_svg_painter.dart:258-700](file://lib/src/animation/animated_svg_painter.dart#L258-L700)
- [text_decoration_thickness_test.dart:1-102](file://test/animation/text_decoration_thickness_test.dart#L1-L102)
- [text_underline_position_test.dart:1-100](file://test/animation/text_underline_position_test.dart#L1-L100)
- [text_emphasis_test.dart:1-51](file://test/animation/text_emphasis_test.dart#L1-L51)
- [ruby_align_test.dart:1-51](file://test/animation/ruby_align_test.dart#L1-L51)
- [font_variation_settings_test.dart:1-40](file://test/animation/font_variation_settings_test.dart#L1-L40)

### SMIL Animation Model (SmilAnimation)
- Types:
  - animate, animateTransform, animateMotion, set, animateColor.
- Timing and behavior:
  - begin, end, dur, repeatCount, repeatDur, fillMode, calcMode, playbackDirection, additive, accumulate.
  - Values-based or from/to/by definitions; keyTimes, keySplines, keySteps for pacing.
- Runtime:
  - isActive, currentIteration, localTime, lastValue.
  - computeValue(t): Evaluates value for a given iteration progress, supporting discrete, values-based, and simple from/to/by modes.
  - updateForTime(globalTime): Activates/deactivates animation, computes iteration and progress, applies fill mode at end.
  - reset(): Clears runtime state.

**Section sources**
- [smil_animation.dart:80-453](file://lib/src/animation/smil/smil_animation.dart#L80-L453)

### SMIL Parsing and CSS Animation Conversion
- SmilParser:
  - Extracts native SMIL animations and CSS animations from inline styles and @keyframes.
  - Supports CSS selector targeting (#id, .class).
- CssToSmilConverter:
  - Converts CSS keyframes to SMIL equivalents.
  - Decomposes compound transforms into separate SmilAnimation instances per transform function.
  - Maps timing functions (cubic-bezier) to keySplines and normalizes values.
- Validation and tests:
  - Tests confirm CSS animations convert to SMIL and that compound transforms emit per-function animations.

```mermaid
flowchart TD
Start(["Parse SVG"]) --> ExtractSMIL["Extract SMIL animations"]
Start --> ExtractCSS["@keyframes and inline CSS"]
ExtractCSS --> Convert["CssToSmilConverter.convert(...)"]
Convert --> Decompose["Decompose compound transforms"]
Decompose --> BuildSMIL["Build SmilAnimation list"]
ExtractSMIL --> BuildSMIL
BuildSMIL --> Timeline["SvgTimeline"]
```

**Diagram sources**
- [smil_parser.dart:16-37](file://lib/src/animation/smil/smil_parser.dart#L16-L37)
- [css_to_smil_converter.dart:15-68](file://lib/src/animation/css_to_smil_converter.dart#L15-L68)
- [css_animations_test.dart:204-339](file://test/animation/css_animations_test.dart#L204-L339)
- [stroke_dash_stop_color_test.dart:272-298](file://test/animation/stroke_dash_stop_color_test.dart#L272-L298)

**Section sources**
- [smil_parser.dart:13-39](file://lib/src/animation/smil/smil_parser.dart#L13-L39)
- [css_to_smil_converter.dart:15-68](file://lib/src/animation/css_to_smil_converter.dart#L15-L68)
- [css_animations_test.dart:204-339](file://test/animation/css_animations_test.dart#L204-L339)
- [stroke_dash_stop_color_test.dart:272-298](file://test/animation/stroke_dash_stop_color_test.dart#L272-L298)

### Timeline Properties and State
- Duration and Position:
  - totalDuration computed from animation effective ends.
  - currentTime updated via tick or seek.
- Status and Active Animations:
  - isActive toggled per animation during updateForTime.
  - getActiveAnimations() and hasActiveAnimations() expose runtime state.
- Playback Rate:
  - Applied to tick deltas; enforced positive in both controller and timeline.

**Section sources**
- [smil_timeline.dart:62-77](file://lib/src/animation/smil/smil_timeline.dart#L62-L77)
- [smil_timeline.dart:202-209](file://lib/src/animation/smil/smil_timeline.dart#L202-L209)
- [smil_timeline_info.dart:15-39](file://lib/src/animation/smil/smil_timeline_info.dart#L15-L39)

### Event-Driven Animations and Synchronization
- Event Triggers:
  - triggerEvent(elementId, eventType) activates animations listening for the event; offsets supported.
- Syncbase Timing:
  - Resolved begin times override explicit begin for dependent animations; dependency graph built and resolved before computing total duration.
- Chaining Examples:
  - Demonstrated via SMIL begin="other.end" chaining and tests validating chained sequences.

**Section sources**
- [smil_timeline.dart:128-158](file://lib/src/animation/smil/smil_timeline.dart#L128-L158)
- [smil_timeline.dart:106-126](file://lib/src/animation/smil/smil_timeline.dart#L106-L126)
- [smil_timeline.dart:212-231](file://lib/src/animation/smil/smil_timeline.dart#L212-L231)

### Programmatic Animation Control and Integration
- Controller-driven control:
  - Tests demonstrate pause/resume, seek, rate changes, direction toggles, and restart.
- Widget integration:
  - AnimatedSvgPicture subscribes to controller updates and starts/stops playback accordingly.
  - On each tick, converts controller progress to elapsed time and seeks the timeline.

**Section sources**
- [controller_test.dart:26-140](file://test/animation/controller_test.dart#L26-L140)
- [animated_svg_picture_lifecycle.dart:177-220](file://lib/src/animation/animated_svg_picture_lifecycle.dart#L177-L220)

### Animation Composition Patterns
- Multiple animations:
  - Timeline aggregates all SmilAnimation instances; each can target different attributes or nodes.
- Transform decomposition:
  - Compound transforms split into separate animateTransform entries per function (translate, rotate, scale, skew).
- CSS selectors:
  - Animations apply to matching nodes by id/class/tag selectors.

**Section sources**
- [css_to_smil_converter.dart:35-48](file://lib/src/animation/css_to_smil_converter.dart#L35-L48)
- [css_animations_test.dart:312-339](file://test/animation/css_animations_test.dart#L312-L339)

## Dependency Analysis
```mermaid
classDiagram
class AnimatedSvgController {
+bool isPaused
+double playbackRate
+bool isReversed
+Duration? pendingSeek
+pause()
+resume()
+togglePlayPause()
+seek(time)
+setPlaybackRate(rate)
+reverse()
+forward()
+toggleDirection()
+restart()
+clearPendingSeek()
}
class AnimatedSvgPicture {
+play()
+pause()
+reset()
+seekTo(time)
}
class SvgTimeline {
+Duration currentTime
+Duration totalDuration
+double playbackRate
+tick(delta)
+seek(time)
+reset()
+triggerEvent(id,event)
+getActiveAnimations()
+hasActiveAnimations()
+getInfo()
}
class SmilAnimation {
+bool isActive
+int currentIteration
+Duration localTime
+updateForTime(time)
+computeValue(t)
+reset()
}
class AnimatedSvgPainterTextStyleExtension {
+_resolveTextStyle(node)
+_resolveWritingMode(value)
+_resolveTextDecoration(value)
+_resolveFontVariant(value)
+_resolveTextDirection(value)
+...
}
class _ResolvedTextStyle {
+color
+fontSize
+fontFamily
+fontWeight
+fontStyle
+textAnchor
+dominantBaseline
+...
}
AnimatedSvgController --> AnimatedSvgPicture : "notifies listeners"
AnimatedSvgPicture --> SvgTimeline : "ticks and seeks"
AnimatedSvgPicture --> AnimatedSvgPainterTextStyleExtension : "resolves text styles"
AnimatedSvgPainterTextStyleExtension --> _ResolvedTextStyle : "creates resolved style"
SvgTimeline --> SmilAnimation : "updates"
```

**Diagram sources**
- [animated_svg_controller.dart:25-131](file://lib/src/animation/animated_svg_controller.dart#L25-L131)
- [animated_svg_picture.dart:272-294](file://lib/src/animation/animated_svg_picture.dart#L272-L294)
- [smil_timeline.dart:20-256](file://lib/src/animation/smil/smil_timeline.dart#L20-L256)
- [smil_animation.dart:80-453](file://lib/src/animation/smil/smil_animation.dart#L80-L453)
- [animated_svg_painter_text_style.dart:3-325](file://lib/src/animation/animated_svg_painter_text_style.dart#L3-L325)
- [animated_svg_painter.dart:258-700](file://lib/src/animation/animated_svg_painter.dart#L258-L700)

**Section sources**
- [animated_svg_controller.dart:25-131](file://lib/src/animation/animated_svg_controller.dart#L25-L131)
- [animated_svg_picture.dart:108-359](file://lib/src/animation/animated_svg_picture.dart#L108-L359)
- [smil_timeline.dart:20-256](file://lib/src/animation/smil/smil_timeline.dart#L20-L256)
- [smil_animation.dart:80-453](file://lib/src/animation/smil/smil_animation.dart#L80-L453)
- [animated_svg_painter_text_style.dart:3-325](file://lib/src/animation/animated_svg_painter_text_style.dart#L3-L325)
- [animated_svg_painter.dart:258-700](file://lib/src/animation/animated_svg_painter.dart#L258-L700)

## Performance Considerations
- Keep playbackRate positive and reasonable to avoid excessive recomputations.
- Prefer fewer, larger transform animations over many small ones where possible.
- Use freeze fill mode judiciously; it retains final values after animation end.
- Limit the number of concurrent active animations by controlling begin/end and repeat settings.
- Avoid overly dense keyframes; use calcMode spline or paced appropriately to balance quality and CPU cost.
- Use traceFrameTicks and onTrace for targeted profiling during development.
- **Updated** Text styling resolution is optimized with caching and efficient unit conversion algorithms.
- **Updated** The 53 CSS properties are resolved incrementally to minimize computational overhead.
- **Updated** Advanced typography features utilize efficient font feature application and variable font axis handling.

## Troubleshooting Guide
- Invalid playback rate:
  - AnimatedSvgController.setPlaybackRate throws on non-positive values.
- Seeking out of range:
  - SvgTimeline.seek clamps to [0, totalDuration].
- Event-based animations not triggering:
  - Ensure triggerEvent called with correct elementId and eventType; verify begin conditions and offsets.
- Direction changes not reflected:
  - AnimatedSvgPicture reacts to controller.isReversed changes; ensure controller listeners are registered.
- CSS animations not applied:
  - Confirm CSS selectors match nodes and that CssToSmilConverter successfully emits SMIL animations.
- **Updated** Text styling issues:
  - Verify CSS property values are valid and properly formatted.
  - Check inheritance patterns for missing property values.
  - Ensure unit conversions are appropriate for the current context.
  - Validate fallback mechanisms are working correctly.
  - **Updated** For advanced properties like font-variation-settings, ensure variable font support is available.
  - **Updated** For ruby and text-emphasis properties, verify proper Unicode support and font availability.
  - **Updated** For internationalization features, ensure locale-specific font fallbacks are configured.

**Section sources**
- [animated_svg_controller.dart:83-91](file://lib/src/animation/animated_svg_controller.dart#L83-L91)
- [smil_timeline.dart:88-98](file://lib/src/animation/smil/smil_timeline.dart#L88-L98)
- [animated_svg_picture_lifecycle.dart:210-220](file://lib/src/animation/animated_svg_picture_lifecycle.dart#L210-L220)
- [css_animations_test.dart:204-339](file://test/animation/css_animations_test.dart#L204-L339)
- [animated_svg_painter_text_style.dart:3-325](file://lib/src/animation/animated_svg_painter_text_style.dart#L3-L325)

## Conclusion
The Flutter SVG animation system provides a robust, SMIL-compatible pipeline with a clear separation of concerns: AnimatedSvgController for programmatic control, AnimatedSvgPicture for widget lifecycle and rendering, and SvgTimeline for orchestration and timing. CSS animations are seamlessly converted to SMIL, enabling consistent behavior across animation types. The enhanced text styling system now supports comprehensive CSS property resolution with advanced unit conversions, inheritance patterns, and fallback mechanisms for 53 text styling properties. This includes advanced typography features like font-variation-settings for variable fonts, comprehensive text decoration controls, internationalization support with ruby annotations and text emphasis, and accessibility features for forced color adjustments and content visibility optimization. With precise control over playback, direction, seeking, and event-driven triggers, developers can implement sophisticated synchronization and custom animation behaviors while maintaining strong performance and debuggability.

## Appendices

### API Reference Summary

- AnimatedSvgController
  - Properties: isPaused, playbackRate, isReversed, pendingSeek
  - Methods: pause, resume, togglePlayPause, seek, setPlaybackRate, reverse, forward, toggleDirection, restart, clearPendingSeek

- SvgTimeline
  - Properties: currentTime, totalDuration, playbackRate
  - Methods: tick, seek, reset, triggerEvent, getActiveAnimations, hasActiveAnimations, getInfo

- SmilAnimation
  - Properties: isActive, currentIteration, localTime
  - Methods: updateForTime, computeValue, reset

- AnimatedSvgPicture
  - Methods: play, pause, reset, seekTo

- **Updated** AnimatedSvgPainterTextStyleExtension
  - Methods: `_resolveTextStyle`, `_resolveWritingMode`, `_resolveTextDecoration`, `_resolveFontVariant`, `_resolveTextDirection`
  - Supports 53 CSS text styling properties with advanced unit conversions and inheritance patterns

- **Updated** _ResolvedTextStyle
  - Properties: color, fontSize, fontFamily, fontWeight, fontStyle, textAnchor, dominantBaseline, baselineShift
  - Additional properties: letterSpacing, wordSpacing, decorations, decorationColor, writingMode, fontFeatures
  - Typography properties: textDirection, glyphOrientationVertical, unicodeBidi, fontStretch, fontSizeAdjust
  - Layout properties: tabSize, textIndent, wordBreak, overflowWrap, textTransform, hyphens, lineBreak
  - Decoration properties: hangingPunctuation, textCombineUpright, textOrientation, textUnderlinePosition
  - Advanced properties: textUnderlineOffset, textDecorationThickness, textDecorationSkipInk, textDecorationSkip
  - Rendering properties: textDecorationStyle, textShadow, whiteSpace, textOverflow, verticalAlign, lineHeight
  - Font features: fontKerning, fontVariantNumeric, textJustify, fontVariantLigatures, fontVariantCaps
  - Advanced font: fontOpticalSizing, paintOrder, textAlignLast, fontSynthesis, fontVariantPosition
  - Internationalization: fontVariantEastAsian, textEmphasis, textEmphasisPosition, textEmphasisColor
  - Ruby annotations: rubyAlign, rubyPosition, textEmphasisStyle, quotes, initialLetter, textSpacing
  - Accessibility: fontLanguageOverride, fontVariantAlternates, textWrap, fontPalette, forcedColorAdjust
  - Print: printColorAdjust, textDecorationLine, fontVariationSettings, cssTextDecorationColor
  - Direction: cssDirection, contentVisibility, containIntrinsicSize, willChange, hyphenateCharacter
  - Effects: cssMixBlendMode

**Section sources**
- [animated_svg_controller.dart:25-131](file://lib/src/animation/animated_svg_controller.dart#L25-L131)
- [smil_timeline.dart:20-256](file://lib/src/animation/smil/smil_timeline.dart#L20-L256)
- [smil_animation.dart:80-453](file://lib/src/animation/smil/smil_animation.dart#L80-L453)
- [animated_svg_picture.dart:272-294](file://lib/src/animation/animated_svg_picture.dart#L272-L294)
- [animated_svg_painter_text_style.dart:3-325](file://lib/src/animation/animated_svg_painter_text_style.dart#L3-L325)
- [animated_svg_painter.dart:258-700](file://lib/src/animation/animated_svg_painter.dart#L258-L700)